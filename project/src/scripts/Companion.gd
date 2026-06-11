extends CharacterBody2D
## Companion - AI 控制的友方角色（随操控角色出击的"其他角色"）
##
## 设计（见领地玩法大扩展 P2）：
## - 不由键鼠驱动，由状态机驱动：FOLLOW(跟随玩家) / ATTACK(索敌攻击)。
## - 属性取自一个角色档案（RosterSystem.compute_character_stats）。
## - 复用 Enemy 的攻击/受击视觉模式，但攻击目标是 enemy 组。
## - 死亡不删档：仅本次出击倒下（downed），归来角色无损。

enum State { FOLLOW, ATTACK }

var char_id: String = ""
var character: Dictionary = {}

# 战斗属性（来自 compute_character_stats）
var max_hp: float = 100.0
var current_hp: float = 100.0
var damage: float = 10.0
var attack_speed: float = 1.0
var move_speed: float = 280.0
var crit_chance: float = 0.05
var crit_damage: float = 1.5
var armor: float = 0.0

var _state: int = State.FOLLOW
var _attack_cooldown: float = 0.0
var _player: Node2D = null
var _target: Node2D = null
var _downed: bool = false

var anim_sprite: AnimatedSprite2D
var _hp_bar: ProgressBar
var _name_label: Label
var _attacking: bool = false
var _facing_left: bool = false

# 行为参数
const FOLLOW_DISTANCE := 90.0  # 跟随时与玩家保持的距离
const VISION_RANGE := 480.0  # 索敌范围
const ATTACK_RANGE := 46.0  # 攻击距离
const LEASH_RANGE := 700.0  # 离玩家过远则强制回追，放弃目标


func setup(character_data: Dictionary):
	character = character_data
	char_id = character.get("char_id", "")


func _ready():
	add_to_group("companion")
	add_to_group("ally")
	_player = get_tree().get_first_node_in_group("player")
	_load_stats()
	_setup_visual()
	_setup_collision()
	_setup_hp_bar()
	_setup_name_label()


func _load_stats():
	var s = {}
	if has_node("/root/RosterSystem") and char_id != "":
		s = RosterSystem.compute_character_stats(char_id)
	if s.is_empty():
		# 兜底：用职业基础
		var cls = ConfigLoader.get_class_by_id(character.get("class_id", "class_warrior"))
		s = cls.get("base_stats", {})
	max_hp = float(s.get("max_hp", 100))
	current_hp = max_hp
	damage = float(s.get("damage", 10))
	attack_speed = float(s.get("attack_speed", 1.0))
	move_speed = float(s.get("move_speed", 280))
	crit_chance = float(s.get("crit_chance", 0.05))
	crit_damage = float(s.get("crit_damage", 1.5))
	armor = float(s.get("armor", 0))


func _setup_visual():
	anim_sprite = AnimatedSprite2D.new()
	anim_sprite.name = "Sprite"
	anim_sprite.scale = Vector2(2.4, 2.4)
	var class_id = character.get("class_id", "class_warrior")
	anim_sprite.sprite_frames = SpriteLibrary.get_class_frames(class_id)
	if anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation("idle"):
		anim_sprite.animation = "idle"
		anim_sprite.play("idle")
	# 友方淡蓝色调，区别于玩家
	anim_sprite.modulate = Color(0.8, 0.92, 1.1)
	add_child(anim_sprite)


func _setup_collision():
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(28, 28)
	col.shape = shape
	add_child(col)


func _setup_hp_bar():
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.max_value = max_hp
	_hp_bar.value = current_hp
	_hp_bar.custom_minimum_size = Vector2(44, 5)
	_hp_bar.size = Vector2(44, 5)
	_hp_bar.position = Vector2(-22, -40)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.3, 0.7, 1.0)  # 蓝色友方血条
	fill.set_corner_radius_all(2)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.12)
	bg.set_corner_radius_all(2)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	_hp_bar.add_theme_stylebox_override("background", bg)
	add_child(_hp_bar)


func _setup_name_label():
	_name_label = Label.new()
	_name_label.text = character.get("name", "队友")
	_name_label.position = Vector2(-30, -58)
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
	add_child(_name_label)


func _physics_process(delta):
	if _downed:
		return
	if _attack_cooldown > 0:
		_attack_cooldown -= delta

	if not _player or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")

	_update_target()

	match _state:
		State.FOLLOW:
			_do_follow(delta)
			if _target != null:
				_state = State.ATTACK
		State.ATTACK:
			_do_attack(delta)
			if _target == null:
				_state = State.FOLLOW

	move_and_slide()


## 索敌：优先保留现有目标，丢失/越界后找最近敌人
func _update_target():
	# 离玩家太远，放弃目标回追
	if _player and is_instance_valid(_player):
		if global_position.distance_to(_player.global_position) > LEASH_RANGE:
			_target = null
			return
	if _target != null and is_instance_valid(_target) and _target.is_in_group("enemy"):
		if global_position.distance_to(_target.global_position) <= VISION_RANGE:
			return
	_target = _find_nearest_enemy()


func _find_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var min_d := VISION_RANGE
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d = global_position.distance_to(e.global_position)
		if d < min_d:
			min_d = d
			nearest = e
	return nearest


## 跟随玩家：保持 FOLLOW_DISTANCE，超出则靠近
func _do_follow(_delta):
	if not _player or not is_instance_valid(_player):
		velocity = Vector2.ZERO
		_play_anim("idle")
		return
	var to_player = _player.global_position - global_position
	var dist = to_player.length()
	if dist > FOLLOW_DISTANCE:
		velocity = to_player.normalized() * move_speed
		_play_anim("walk")
		_face(to_player.x)
	else:
		velocity = Vector2.ZERO
		_play_anim("idle")


## 攻击：接近目标到 ATTACK_RANGE 后挥击
func _do_attack(_delta):
	if _target == null or not is_instance_valid(_target):
		_target = null
		velocity = Vector2.ZERO
		return
	var to_target = _target.global_position - global_position
	var dist = to_target.length()
	if dist > ATTACK_RANGE:
		velocity = to_target.normalized() * move_speed
		_play_anim("walk")
		_face(to_target.x)
	else:
		velocity = Vector2.ZERO
		_face(to_target.x)
		if _attack_cooldown <= 0:
			_perform_attack()


func _perform_attack():
	_attack_cooldown = 1.0 / max(attack_speed, 0.1)
	if (
		anim_sprite
		and anim_sprite.sprite_frames
		and anim_sprite.sprite_frames.has_animation("attack")
	):
		_attacking = true
		anim_sprite.play("attack")
		if not anim_sprite.animation_finished.is_connected(_on_attack_done):
			anim_sprite.animation_finished.connect(_on_attack_done, CONNECT_ONE_SHOT)
	# 攻击特效
	var fx_offset = Vector2(-40 if _facing_left else 40, 0)
	EffectSprite.spawn(get_parent(), "slash", global_position + fx_offset, 1.1)
	# 结算伤害（暴击判定）
	if _target and is_instance_valid(_target) and _target.has_method("take_damage"):
		var is_crit = randf() < crit_chance
		var dmg = damage * (crit_damage if is_crit else 1.0)
		# 走目标的护甲减伤（与 CombatSystem 同公式近似）
		var t_armor = 0.0
		if "enemy_data" in _target:
			t_armor = _target.enemy_data.get("base_stats", {}).get("armor", 0)
		var resist = 1.0 - (t_armor / (t_armor + 100.0))
		_target.take_damage(dmg * resist, is_crit)
		if _target.has_method("apply_knockback"):
			_target.apply_knockback(global_position, is_crit)


func _on_attack_done():
	_attacking = false
	_play_anim("idle")


func take_damage(dmg: float, _is_crit: bool = false):
	if _downed:
		return
	var resist = 1.0 - (armor / (armor + 100.0))
	current_hp -= dmg * resist
	current_hp = max(0, current_hp)
	if _hp_bar:
		_hp_bar.value = current_hp
	if anim_sprite:
		ShaderHelper.apply_hit_flash(anim_sprite, Color(1.4, 0.5, 0.5), 0.12)
	if current_hp <= 0:
		_go_down()


## 倒下：本次出击退场，不删档
func _go_down():
	_downed = true
	velocity = Vector2.ZERO
	if anim_sprite:
		anim_sprite.modulate = Color(0.4, 0.4, 0.45, 0.6)
	if _hp_bar:
		_hp_bar.visible = false
	if _name_label:
		_name_label.text = character.get("name", "队友") + " (倒下)"
		_name_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	# 关闭碰撞，避免挡路
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	print("[Companion] %s 倒下" % character.get("name", "?"))


func _play_anim(anim: String):
	if _attacking:
		return
	if anim_sprite and anim_sprite.sprite_frames and anim_sprite.sprite_frames.has_animation(anim):
		if anim_sprite.animation != anim:
			anim_sprite.play(anim)


func _face(dir_x: float):
	if abs(dir_x) > 0.1 and anim_sprite:
		_facing_left = dir_x < 0
		anim_sprite.flip_h = _facing_left
