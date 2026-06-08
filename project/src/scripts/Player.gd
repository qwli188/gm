extends CharacterBody2D

# ============ 基础属性（角色裸装） ============
var base_max_hp: float = 100.0
var base_damage: float = 10.0
var base_attack_speed: float = 1.0
var base_move_speed: float = 300.0
var base_crit_chance: float = 0.05
var base_crit_damage: float = 1.5
var base_armor: float = 0.0

# ============ 最终属性（基础 + 装备 + 词缀，每次装备变化时重算） ============
var max_hp: float = 100.0
var current_hp: float = 100.0
var damage: float = 10.0
var attack_speed: float = 1.0
var move_speed: float = 300.0
var crit_chance: float = 0.05
var crit_damage: float = 1.5
var armor: float = 0.0
# 词缀效果属性（吸血、点燃等，传给战斗系统）
var combat_stats: Dictionary = {}

var auto_attack_enabled: bool = false
var attack_cooldown: float = 0.0

# 经验与等级
var current_level: int = 1
var current_exp: float = 0.0
var exp_to_next_level: float = 10.0

# 游戏统计
var survival_time: float = 0.0
var kills: int = 0
var gold: int = 0

signal stats_recalculated()

signal hp_changed(current: float, maximum: float)
signal auto_attack_toggled(enabled: bool)
signal level_up(new_level: int)
signal player_died(time: float, kill_count: int, gold_earned: int)

var anim_sprite: AnimatedSprite2D
var _attacking: bool = false
var _facing_left: bool = false

func _ready():
	add_to_group("player")
	_setup_visual()
	_apply_class()
	recalculate_stats()
	current_hp = max_hp
	_calculate_exp_to_next_level()

## 创建职业动画精灵
func _setup_visual():
	anim_sprite = AnimatedSprite2D.new()
	anim_sprite.name = "Sprite"
	anim_sprite.scale = Vector2(2.6, 2.6)
	add_child(anim_sprite)

## 根据选中职业设置基础属性和起手武器
func _apply_class():
	if not has_node("/root/GameState"):
		return
	var cls = get_node("/root/GameState").get_current_class()
	if cls.is_empty():
		return
	var bs = cls.get("base_stats", {})
	base_max_hp = bs.get("max_hp", 100)
	base_damage = bs.get("damage", 10)
	base_attack_speed = bs.get("attack_speed", 1.0)
	base_move_speed = bs.get("move_speed", 300)
	base_crit_chance = bs.get("crit_chance", 0.05)
	base_crit_damage = bs.get("crit_damage", 1.5)
	base_armor = bs.get("armor", 0)
	print("[Player] 职业: %s" % cls.get("display_name", "?"))

	# 装备起手武器
	var starting_weapon = cls.get("starting_weapon", "")
	if starting_weapon != "" and has_node("/root/EquipmentSystem"):
		var weapon = ConfigLoader.get_equipment_by_id(starting_weapon)
		if not weapon.is_empty():
			get_node("/root/EquipmentSystem").equip_item(weapon)

	# 加载职业动画精灵
	var class_id = cls.get("id", "class_warrior")
	if anim_sprite:
		anim_sprite.sprite_frames = SpriteLibrary.get_class_frames(class_id)
		anim_sprite.animation = "idle"
		anim_sprite.play("idle")

## 重算最终属性 = 基础 + 局外强化 + 装备 + 词缀
## 每次装备/卸下/局外升级后调用
func recalculate_stats():
	# 1. 从基础属性起步
	max_hp = base_max_hp
	damage = base_damage
	attack_speed = base_attack_speed
	move_speed = base_move_speed
	crit_chance = base_crit_chance
	crit_damage = base_crit_damage
	armor = base_armor
	combat_stats = {}

	# 2. 叠加装备属性（由 EquipmentSystem 汇总）
	if has_node("/root/EquipmentSystem"):
		var eq = get_node("/root/EquipmentSystem")
		var total = eq.get_total_stats()
		max_hp += total.get("max_hp", 0)
		damage += total.get("damage", 0)
		attack_speed *= total.get("attack_speed_mult", 1.0)
		move_speed *= total.get("move_speed_mult", 1.0)
		crit_chance += total.get("crit_chance", 0)
		crit_damage += total.get("crit_damage", 0)
		armor += total.get("armor", 0)
		# 词缀效果（吸血、点燃、毒、附加伤害等）传给战斗系统
		combat_stats = eq.get_combat_effects()

	# 3. 叠加局外永久强化（GameState 管理）
	var perm_damage = GameState.get_meta_bonus("perm_damage")
	var perm_max_hp = GameState.get_meta_bonus("perm_max_hp")
	base_damage += perm_damage
	base_max_hp += perm_max_hp

	# 上限保护
	crit_chance = min(crit_chance, 0.75)
	attack_speed = min(attack_speed, 3.0)

	stats_recalculated.emit()

func _physics_process(delta):
	survival_time += delta
	handle_movement()
	handle_attack(delta)
	move_and_slide()

func handle_movement():
	var input_dir = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()

	velocity = input_dir * move_speed

	# 动画：移动时 walk，静止时 idle（攻击动画优先）
	if anim_sprite and not _attacking:
		if input_dir.length() > 0.1:
			if anim_sprite.animation != "walk":
				anim_sprite.play("walk")
		else:
			if anim_sprite.animation != "idle":
				anim_sprite.play("idle")
	# 朝向翻转
	if anim_sprite and abs(input_dir.x) > 0.1:
		_facing_left = input_dir.x < 0
		anim_sprite.flip_h = _facing_left

func handle_attack(delta):
	if attack_cooldown > 0:
		attack_cooldown -= delta
		return

	if Input.is_action_just_pressed("toggle_auto_attack"):
		auto_attack_enabled = !auto_attack_enabled
		auto_attack_toggled.emit(auto_attack_enabled)

	var should_attack = false
	if auto_attack_enabled:
		should_attack = true
	elif Input.is_action_pressed("attack"):
		should_attack = true

	if should_attack:
		perform_attack()

func perform_attack():
	attack_cooldown = 1.0 / attack_speed
	AudioManager.play("attack")

	# 播放攻击动画
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		_attacking = true
		anim_sprite.play("attack")
		if not anim_sprite.animation_finished.is_connected(_on_attack_done):
			anim_sprite.animation_finished.connect(_on_attack_done, CONNECT_ONE_SHOT)

	# 攻击挥砍特效（朝向前方）
	var fx_offset = Vector2(-50 if _facing_left else 50, 0)
	EffectSprite.spawn(get_parent(), "slash", global_position + fx_offset, 1.4)

	var stats = {
		"damage": damage,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage,
	}
	# 合并词缀效果（吸血、附加火焰、点燃、毒等）
	for key in combat_stats:
		stats[key] = combat_stats[key]

	var attack_area = get_node_or_null("AttackArea")
	if attack_area and has_node("/root/CombatSystem"):
		get_node("/root/CombatSystem").check_player_attack(attack_area, stats)

func _on_attack_done():
	_attacking = false
	if anim_sprite:
		anim_sprite.play("idle")

func take_damage(damage: float):
	current_hp -= damage
	current_hp = clamp(current_hp, 0, max_hp)
	AudioManager.play("hit")
	hp_changed.emit(current_hp, max_hp)
	# 受击红闪
	if anim_sprite:
		anim_sprite.modulate = Color(1.6, 0.6, 0.6)
		var tween = create_tween()
		tween.tween_property(anim_sprite, "modulate", Color.WHITE, 0.15)
	# 伤害数字
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -40), damage, false)
	if current_hp <= 0:
		die()

func heal(amount: float):
	current_hp += amount
	current_hp = clamp(current_hp, 0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	# 治疗数字
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -40), amount, false, true)

func die():
	print("Player died")
	player_died.emit(survival_time, kills, gold)
	# 不要直接 queue_free，让 GameOver UI 接管

func get_stat(stat_name: String) -> float:
	match stat_name:
		"armor": return armor
		"max_hp": return max_hp
		"damage": return damage
		"move_speed": return move_speed
		_: return 0.0

## 获得经验值
func gain_exp(amount: float):
	current_exp += amount

	# 检查是否升级
	while current_exp >= exp_to_next_level and current_level < 50:
		current_exp -= exp_to_next_level
		current_level += 1
		_on_level_up()

## 计算下一级所需经验
func _calculate_exp_to_next_level():
	var base_exp = 10.0
	var growth = 1.15
	exp_to_next_level = base_exp * pow(growth, current_level - 1)

## 升级时调用
func _on_level_up():
	print("[Player] 升级到 %d 级！" % current_level)

	# 提升基础属性（每级），再重算最终属性
	base_max_hp += 8
	base_damage += 2

	recalculate_stats()
	current_hp = max_hp  # 升级回满血

	hp_changed.emit(current_hp, max_hp)
	_calculate_exp_to_next_level()
	level_up.emit(current_level)
	# 升级光环特效
	EffectSprite.spawn(get_parent(), "levelup", global_position, 2.0)

## 击杀敌人时调用
func on_enemy_killed(enemy_data: Dictionary):
	kills += 1

	# 获得经验
	var exp = enemy_data.get("drop_table", {}).get("exp", 0)
	gain_exp(exp)

	# 获得金币
	var gold_drop = enemy_data.get("drop_table", {}).get("gold", {})
	var min_gold = gold_drop.get("min", 0)
	var max_gold = gold_drop.get("max", 0)
	var gold_amount = randi_range(min_gold, max_gold)
	gold += gold_amount
