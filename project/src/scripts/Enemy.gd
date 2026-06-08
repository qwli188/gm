extends CharacterBody2D

var enemy_data: Dictionary
var current_hp: float
var max_hp: float
var damage: float
var move_speed: float
var enemy_armor: float
var attack_cooldown: float = 0.0
var player: Node2D

const VISION_RANGE = 600.0
const ATTACK_DISTANCE = 36.0

var anim_sprite: AnimatedSprite2D
var _hp_bar: ProgressBar
var _is_attacking: bool = false

func _ready():
	if enemy_data.is_empty():
		push_error("Enemy: enemy_data not set")
		queue_free()
		return

	var bs = enemy_data.base_stats
	max_hp = bs.get("max_hp", 20)
	current_hp = max_hp
	damage = bs.get("damage", 5)
	move_speed = bs.get("move_speed", 60)
	enemy_armor = bs.get("armor", 0)

	player = get_tree().get_first_node_in_group("player")
	add_to_group("enemy")

	_setup_visual()
	_setup_collision()
	_setup_hp_bar()

## 应用难度倍率（生成器调用）
func apply_difficulty(hp_mult: float, dmg_mult: float):
	max_hp *= hp_mult
	current_hp = max_hp
	damage *= dmg_mult

## 根据配置创建动画精灵（使用 SpriteLibrary 生成的卡通素材）
func _setup_visual():
	anim_sprite = AnimatedSprite2D.new()
	anim_sprite.name = "Sprite"
	var region = enemy_data.get("region", "field")
	anim_sprite.sprite_frames = SpriteLibrary.get_enemy_frames(region)
	anim_sprite.animation = "idle"
	anim_sprite.play("idle")

	# rank 决定缩放和染色
	var rank = enemy_data.get("rank", "normal")
	var scl = SpriteLibrary.RANK_SCALE.get(rank, 2.4)
	anim_sprite.scale = Vector2(scl, scl)
	anim_sprite.modulate = SpriteLibrary.RANK_TINT.get(rank, Color.WHITE)
	add_child(anim_sprite)

## 创建碰撞体
func _setup_collision():
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	var rank = enemy_data.get("rank", "normal")
	var sz = 32 + (16 if rank == "boss" else 0)
	shape.size = Vector2(sz, sz)
	col.shape = shape
	add_child(col)

## 敌人头顶血条
func _setup_hp_bar():
	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.max_value = max_hp
	_hp_bar.value = current_hp
	_hp_bar.custom_minimum_size = Vector2(48, 6)
	_hp_bar.size = Vector2(48, 6)
	_hp_bar.position = Vector2(-24, -42)
	# 红色填充样式
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.85, 0.25, 0.25)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.1, 0.12)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	_hp_bar.add_theme_stylebox_override("fill", fill)
	_hp_bar.add_theme_stylebox_override("background", bg)
	add_child(_hp_bar)

func _physics_process(delta):
	if not player or not is_instance_valid(player):
		return

	if attack_cooldown > 0:
		attack_cooldown -= delta

	var distance = global_position.distance_to(player.global_position)

	if distance < ATTACK_DISTANCE:
		attack()
	elif distance < VISION_RANGE:
		chase_player(delta)
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func chase_player(delta):
	# 应用减速效果
	var effective_speed = move_speed * slow_multiplier
	if is_frozen:
		effective_speed = 0

	var direction = (player.global_position - global_position).normalized()
	velocity = direction * effective_speed

	# 朝向：面向玩家时翻转精灵
	if anim_sprite and abs(direction.x) > 0.1:
		anim_sprite.flip_h = direction.x < 0
	if anim_sprite and not _is_attacking and anim_sprite.animation != "idle":
		anim_sprite.play("idle")

func attack():
	velocity = Vector2.ZERO
	if attack_cooldown > 0:
		return
	# 播放攻击动画
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		_is_attacking = true
		anim_sprite.play("attack")
		if not anim_sprite.animation_finished.is_connected(_on_attack_anim_done):
			anim_sprite.animation_finished.connect(_on_attack_anim_done, CONNECT_ONE_SHOT)
	# 攻击玩家
	if player and player.has_method("take_damage"):
		if has_node("/root/CombatSystem"):
			get_node("/root/CombatSystem").enemy_attack_player(damage, player)
		else:
			player.take_damage(damage)
	attack_cooldown = 1.0  # 每秒攻击一次

func _on_attack_anim_done():
	_is_attacking = false
	if anim_sprite:
		anim_sprite.play("idle")

func take_damage(damage_amount: float, is_crit: bool = false):
	current_hp -= damage_amount
	AudioManager.play("hit")
	_flash_white()
	_update_hp_bar()
	# 漂浮伤害数字
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -30), damage_amount, is_crit)
	# 受击火花特效
	EffectSprite.spawn(get_parent(), "hit", global_position, 1.0)

	if current_hp <= 0:
		die()

func _update_hp_bar():
	if _hp_bar:
		_hp_bar.max_value = max_hp
		_hp_bar.value = max(0, current_hp)

## 状态效果
var ignite_timer: float = 0.0
var ignite_dps: float = 0.0
var poison_timer: float = 0.0
var poison_dps: float = 0.0
var freeze_timer: float = 0.0
var is_frozen: bool = false
var base_move_speed: float = 0.0
var slow_multiplier: float = 1.0

func apply_ignite(dps: float, duration: float):
	ignite_dps = max(ignite_dps, dps)  # 取最高DPS
	ignite_timer = max(ignite_timer, duration)  # 刷新持续时间
	EffectSprite.spawn(get_parent(), "fire", global_position, 1.2)

func apply_poison(dps: float, duration: float):
	poison_dps = max(poison_dps, dps)
	poison_timer = max(poison_timer, duration)
	EffectSprite.spawn(get_parent(), "poison", global_position, 1.2)

func apply_freeze(duration: float):
	if not is_frozen:
		base_move_speed = move_speed
	is_frozen = true
	freeze_timer = duration
	move_speed = 0  # 冰冻时无法移动
	if anim_sprite:
		anim_sprite.modulate = Color(0.6, 0.8, 1.2)  # 冰冻泛蓝
	EffectSprite.spawn(get_parent(), "frost", global_position, 1.3)

func apply_slow(slow_percent: float, duration: float):
	slow_multiplier = 1.0 - slow_percent
	freeze_timer = duration  # 复用计时器

var _dot_tick: float = 0.0

func _process(delta):
	# 点燃伤害
	if ignite_timer > 0:
		ignite_timer -= delta
		current_hp -= ignite_dps * delta
		_dot_tick += delta
		if _dot_tick >= 0.5:
			_dot_tick = 0.0
			EffectSprite.spawn(get_parent(), "fire", global_position, 0.9)
		if ignite_timer <= 0:
			ignite_dps = 0

	# 中毒伤害
	if poison_timer > 0:
		poison_timer -= delta
		current_hp -= poison_dps * delta
		if poison_timer <= 0:
			poison_dps = 0

	# 冰冻/减速恢复
	if freeze_timer > 0:
		freeze_timer -= delta
		if freeze_timer <= 0:
			if is_frozen:
				move_speed = base_move_speed
				is_frozen = false
				if anim_sprite:
					anim_sprite.modulate = SpriteLibrary.RANK_TINT.get(enemy_data.get("rank", "normal"), Color.WHITE)
			slow_multiplier = 1.0

	_update_hp_bar()

	# 死亡检查
	if current_hp <= 0:
		die()

## 受击闪白
func _flash_white():
	if anim_sprite:
		anim_sprite.modulate = Color(2.5, 2.5, 2.5)
		var rank = enemy_data.get("rank", "normal")
		var base_tint = SpriteLibrary.RANK_TINT.get(rank, Color.WHITE)
		var tween = create_tween()
		tween.tween_property(anim_sprite, "modulate", base_tint, 0.12)


var _dying := false
func die():
	if _dying:
		return
	_dying = true
	drop_loot()

	# 通知玩家击杀
	if player and player.has_method("on_enemy_killed"):
		player.on_enemy_killed(enemy_data)

	queue_free()

func drop_loot():
	var drop_table = enemy_data.get("drop_table", {})
	var drop_chance = drop_table.get("equipment_drop_chance", 0.03)
	if randf() < drop_chance:
		if has_node("/root/EquipmentSystem"):
			var bonus = 0.0
			var set_bias = ""
			if has_node("/root/GameState"):
				bonus = get_node("/root/GameState").selected_drop_bonus
				set_bias = get_node("/root/GameState").selected_set_drop
			get_node("/root/EquipmentSystem").drop_random_equipment(global_position, bonus, set_bias)

func call_equipment_drop():
	# 从 equipment.json 随机掉落装备
	# 需要 EquipmentSystem 存在时调用
	if has_node("/root/EquipmentSystem"):
		get_node("/root/EquipmentSystem").drop_random_equipment(global_position)

static func load_enemy_config() -> Dictionary:
	var file_path = "res://config/enemies.json"
	if not FileAccess.file_exists(file_path):
		push_error("Enemy config not found: " + file_path)
		return {}

	var file = FileAccess.open(file_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse enemies.json")
		return {}

	return json.data

static func create_enemy(enemy_id: String, spawn_position: Vector2) -> Node2D:
	var config = load_enemy_config()
	if config.is_empty():
		return null

	var enemy_list = config.get("enemies", [])
	var enemy_data = null
	for e in enemy_list:
		if e.id == enemy_id:
			enemy_data = e
			break

	if not enemy_data:
		push_error("Enemy ID not found: " + enemy_id)
		return null

	var enemy_scene = preload("res://scripts/Enemy.gd")
	var enemy = CharacterBody2D.new()
	enemy.set_script(enemy_scene)
	enemy.enemy_data = enemy_data
	enemy.global_position = spawn_position

	return enemy
