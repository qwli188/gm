extends Node
## 职业核心机制系统 - 战士怒气/游侠精准/法师法力连锁

signal rage_changed(current: float, maximum: float)
signal rage_skill_activated()
signal precision_changed(stacks: int, target: Node2D)
signal mana_changed(current: float, maximum: float)
signal chain_triggered(from: Node2D, to: Node2D)

# ============ 战士 - 怒气机制 ============
var rage: float = 0.0
var rage_max: float = 100.0
var rage_gain_on_hit: float = 10.0
var rage_gain_on_damaged: float = 15.0
var rage_skill_cost: float = 100.0
var rage_skill_active: bool = false
var rage_skill_duration: float = 5.0
var rage_skill_timer: float = 0.0
var rage_skill_cooldown: float = 0.0  # 职业调优: 技能CD计时
var rage_skill_cooldown_max: float = 5.0  # 职业调优: 技能CD时长(5秒)
var rage_damage_bonus: float = 0.3  # 怒气技能期间伤害+30%
var rage_damage_reduction: float = 0.2  # 怒气技能期间减伤+20%

# ============ 游侠 - 精准射击 ============
var precision_stacks: int = 0
var precision_max_stacks: int = 10
var precision_target: Node2D = null
var precision_crit_per_stack: float = 0.02  # 每层+2%暴击率
var precision_crit_dmg_per_stack: float = 0.05  # 每层+5%暴伤

# ============ 法师 - 法力连锁 ============
var mana: float = 100.0
var mana_max: float = 100.0
var mana_cost_per_cast: float = 15.0
var mana_regen_per_sec: float = 8.0
var chain_threshold: float = 0.5  # 法力>50%时触发连锁
var chain_range: float = 180.0
var chain_damage_reduction: float = 0.2  # 连锁伤害递减20%
var chain_max_targets: int = 4  # 最多弹射4次
var _is_chaining: bool = false  # 职业调优: 防止连锁递归

var _current_class_id: String = ""
var _player: Node2D = null

# ============ 刺客 - 潜行背刺 ============
var assassin_out_of_combat_timer: float = 0.0
var assassin_stealth_active: bool = false
const ASSASSIN_STEALTH_ENTER_TIME: float = 3.0
const ASSASSIN_STEALTH_CRIT_MULT: float = 1.5
var assassin_original_alpha: float = 1.0

# ============ 骑士 - 圣盾反伤 ============
var knight_shield_active: bool = false
var knight_shield_timer: float = 0.0
var knight_shield_cooldown: float = 0.0
const KNIGHT_SHIELD_DURATION: float = 5.0
const KNIGHT_SHIELD_COOLDOWN: float = 12.0
const KNIGHT_SHIELD_REFLECT_RATIO: float = 0.3
var knight_original_modulate: Color = Color.WHITE

# ============ 死灵 - 召唤亡灵+尸爆 ============
var necro_skeletons: Array = []
var necro_summon_cooldown: float = 0.0
var necro_corpses: Array = []
const NECRO_SUMMON_COOLDOWN: float = 8.0
const NECRO_MAX_SKELETONS: int = 3
const NECRO_CORPSE_EXPLODE_RADIUS: float = 120.0
const NECRO_CORPSE_EXPLODE_DAMAGE: float = 50.0

func _ready():
	print("[ClassMechanicSystem] 职业核心机制系统初始化")
	# 等待玩家初始化后读取职业
	await get_tree().process_frame
	_initialize_class()

func _initialize_class():
	if not has_node("/root/GameState"):
		return
	var cls = get_node("/root/GameState").get_current_class()
	if cls.is_empty():
		return
	_current_class_id = cls.get("id", "")
	print("[ClassMechanicSystem] 当前职业: %s" % _current_class_id)

	# 从 balance.json 读取机制参数（如果有）
	_load_mechanic_params()

	# 连接玩家信号
	await get_tree().process_frame
	_player = get_tree().get_first_node_in_group("player")

func _load_mechanic_params():
	var balance = ConfigLoader.get_balance_config()
	var mechanics = balance.get("class_mechanics", {})

	match _current_class_id:
		"class_warrior":
			var warrior_params = mechanics.get("warrior", {})
			rage_max = warrior_params.get("rage_max", 100.0)
			rage_gain_on_hit = warrior_params.get("rage_gain_on_hit", 10.0)
			rage_gain_on_damaged = warrior_params.get("rage_gain_on_damaged", 15.0)
			rage_damage_bonus = warrior_params.get("damage_bonus", 0.3)
			rage_damage_reduction = warrior_params.get("damage_reduction", 0.2)
			rage_skill_duration = warrior_params.get("skill_duration", 5.0)

		"class_ranger":
			var ranger_params = mechanics.get("ranger", {})
			precision_max_stacks = ranger_params.get("max_stacks", 10)
			precision_crit_per_stack = ranger_params.get("crit_per_stack", 0.02)
			precision_crit_dmg_per_stack = ranger_params.get("crit_dmg_per_stack", 0.05)

		"class_mage":
			var mage_params = mechanics.get("mage", {})
			mana_max = mage_params.get("mana_max", 100.0)
			mana_cost_per_cast = mage_params.get("mana_cost", 15.0)
			mana_regen_per_sec = mage_params.get("mana_regen", 8.0)
			chain_threshold = mage_params.get("chain_threshold", 0.5)
			chain_range = mage_params.get("chain_range", 180.0)
			chain_damage_reduction = mage_params.get("chain_damage_reduction", 0.2)
			chain_max_targets = mage_params.get("chain_max_targets", 4)

func _process(delta):
	# 确保玩家引用有效
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return
		if _current_class_id == "":
			_initialize_class()

	match _current_class_id:
		"class_warrior":
			_update_warrior(delta)
		"class_ranger":
			pass  # 游侠精准层数由命中触发，不需要逐帧更新
		"class_mage":
			_update_mage(delta)
		"class_assassin":
			_update_assassin(delta)
		"class_knight":
			_update_knight(delta)
		"class_necromancer":
			_update_necromancer(delta)

# ============ 战士机制更新 ============
func _update_warrior(delta):
	# 怒气技能持续时间
	if rage_skill_active:
		rage_skill_timer -= delta
		if rage_skill_timer <= 0:
			rage_skill_active = false
			print("[Warrior] 怒气技能结束")

	# 职业调优: 怒气技能CD递减
	if rage_skill_cooldown > 0:
		rage_skill_cooldown -= delta
		if rage_skill_cooldown < 0:
			rage_skill_cooldown = 0

# ============ 法师机制更新 ============
func _update_mage(delta):
	# 法力自动回复
	if mana < mana_max:
		mana += mana_regen_per_sec * delta
		mana = min(mana, mana_max)
		mana_changed.emit(mana, mana_max)

# ============ 战士 - 怒气增加（玩家命中时调用） ============
func on_player_hit_enemy():
	if _current_class_id != "class_warrior":
		return

	rage += rage_gain_on_hit
	rage = min(rage, rage_max)
	rage_changed.emit(rage, rage_max)

	if rage >= rage_max:
		print("[Warrior] 怒气已满！可释放怒气技能")

# ============ 战士 - 怒气增加（玩家受击时调用） ============
func on_player_damaged():
	if _current_class_id != "class_warrior":
		return

	rage += rage_gain_on_damaged
	rage = min(rage, rage_max)
	rage_changed.emit(rage, rage_max)

# ============ 战士 - 释放怒气技能 ============
func activate_rage_skill() -> bool:
	if _current_class_id != "class_warrior":
		return false

	# 职业调优: CD检测防止无限循环
	if rage_skill_cooldown > 0:
		print("[Warrior] 怒气技能冷却中 (%.1fs)" % rage_skill_cooldown)
		return false

	if rage < rage_skill_cost:
		print("[Warrior] 怒气不足")
		return false

	rage = 0.0
	rage_skill_active = true
	rage_skill_timer = rage_skill_duration
	rage_skill_cooldown = rage_skill_cooldown_max  # 职业调优: 启动CD
	rage_changed.emit(rage, rage_max)
	rage_skill_activated.emit()

	print("[Warrior] 怒气技能激活！伤害+30%，减伤+20%，持续%d秒" % rage_skill_duration)

	# 播放旋风斩特效（复用旋风斩技能）
	if _player:
		AudioManager.play("attack")
		EffectSprite.spawn(_player.get_parent(), "whirlwind", _player.global_position, 1.8)

	return true

# ============ 战士 - 获取怒气伤害加成 ============
func get_warrior_damage_mult() -> float:
	if _current_class_id != "class_warrior":
		return 1.0
	if rage_skill_active:
		return 1.0 + rage_damage_bonus
	return 1.0

# ============ 战士 - 获取怒气减伤 ============
func get_warrior_damage_reduction() -> float:
	if _current_class_id != "class_warrior":
		return 0.0
	if rage_skill_active:
		return rage_damage_reduction
	return 0.0

# ============ 游侠 - 命中目标（增加精准层数） ============
func on_ranger_hit_target(target: Node2D):
	if _current_class_id != "class_ranger":
		return

	# 命中同一目标，增加层数
	if precision_target == target:
		precision_stacks = min(precision_stacks + 1, precision_max_stacks)
	else:
		# 切换目标，清空层数
		precision_target = target
		precision_stacks = 1

	precision_changed.emit(precision_stacks, precision_target)

# ============ 游侠 - 获取精准暴击加成 ============
func get_ranger_crit_bonus() -> float:
	if _current_class_id != "class_ranger":
		return 0.0
	return precision_stacks * precision_crit_per_stack

# ============ 游侠 - 获取精准暴伤加成 ============
func get_ranger_crit_damage_bonus() -> float:
	if _current_class_id != "class_ranger":
		return 0.0
	return precision_stacks * precision_crit_dmg_per_stack

# ============ 法师 - 攻击消耗法力 ============
func on_mage_cast():
	if _current_class_id != "class_mage":
		return

	mana -= mana_cost_per_cast
	mana = max(mana, 0.0)
	mana_changed.emit(mana, mana_max)

# ============ 法师 - 触发连锁（命中时调用） ============
func trigger_chain_lightning(source_enemy: Node2D, base_damage: float, player_stats: Dictionary):
	if _current_class_id != "class_mage":
		return

	# 职业调优: 防止递归调用(连锁伤害不再触发新连锁)
	if _is_chaining:
		return
	_is_chaining = true

	# 法力不足50%，不触发连锁
	if mana < mana_max * chain_threshold:
		_is_chaining = false
		return

	var all_enemies = get_tree().get_nodes_in_group("enemy")
	var chained_targets = [source_enemy]
	var current_target = source_enemy
	var current_damage = base_damage

	for i in range(chain_max_targets):
		# 查找附近未命中的敌人
		var next_target = _find_nearest_unchained_enemy(current_target, chained_targets, all_enemies)
		if next_target == null:
			break

		# 计算递减后的伤害
		current_damage *= (1.0 - chain_damage_reduction)

		# 应用伤害
		if has_node("/root/CombatSystem"):
			var target_armor = next_target.enemy_data.get("base_stats", {}).get("armor", 0)
			var result = get_node("/root/CombatSystem").calculate_damage({
				"damage": current_damage,
				"crit_chance": player_stats.get("crit_chance", 0.05),
				"crit_damage": player_stats.get("crit_damage", 1.5)
			}, target_armor)
			get_node("/root/CombatSystem").apply_damage(next_target, result.damage, player_stats, result.is_crit)

			# 连锁特效
			_spawn_chain_effect(current_target.global_position, next_target.global_position)

		chained_targets.append(next_target)
		current_target = next_target
		chain_triggered.emit(source_enemy, next_target)

	if chained_targets.size() > 1:
		print("[Mage] 法力连锁触发！弹射了 %d 个目标" % (chained_targets.size() - 1))

	# 职业调优: 连锁结束，解除递归锁
	_is_chaining = false

# ============ 法师 - 查找最近未命中的敌人 ============
func _find_nearest_unchained_enemy(from: Node2D, chained: Array, all_enemies: Array) -> Node2D:
	var nearest: Node2D = null
	var min_distance = chain_range

	for enemy in all_enemies:
		if not is_instance_valid(enemy):
			continue
		if enemy in chained:
			continue
		if not enemy.has_method("take_damage"):
			continue

		var distance = from.global_position.distance_to(enemy.global_position)
		if distance < min_distance:
			min_distance = distance
			nearest = enemy

	return nearest

# ============ 法师 - 连锁闪电特效 ============
func _spawn_chain_effect(from_pos: Vector2, to_pos: Vector2):
	if not _player:
		return

	var parent = _player.get_parent()
	if not parent:
		return

	# 创建一条从 from_pos 到 to_pos 的闪电线条
	var line = Line2D.new()
	line.add_point(from_pos)
	line.add_point(to_pos)
	line.width = 3.0
	line.default_color = Color(0.5, 0.8, 1.0, 0.8)
	parent.add_child(line)

	# 0.15秒后消失
	await get_tree().create_timer(0.15).timeout
	if is_instance_valid(line):
		line.queue_free()

# ============ 重置机制状态（新游戏开始时调用） ============
func reset():
	_player = null
	_current_class_id = ""
	# 战士
	rage = 0.0
	rage_skill_active = false
	rage_skill_timer = 0.0
	rage_skill_cooldown = 0.0  # 职业调优: 重置CD
	# 游侠
	precision_stacks = 0
	precision_target = null
	# 法师
	mana = mana_max
	_is_chaining = false  # 职业调优: 重置连锁锁
	# 刺客
	assassin_out_of_combat_timer = 0.0
	assassin_stealth_active = false
	assassin_original_alpha = 1.0  # 职业调优: 重置透明度
	# 骑士
	knight_shield_active = false
	knight_shield_timer = 0.0
	knight_shield_cooldown = 0.0
	# 死灵
	# 职业调优: 强制清理骷髅和尸体节点，防止await泄漏
	for skeleton in necro_skeletons:
		if is_instance_valid(skeleton):
			skeleton.queue_free()
	necro_skeletons.clear()
	necro_summon_cooldown = 0.0
	_cleanup_all_corpses()

	_initialize_class()

# ============================================================
# 刺客/骑士/死灵 职业机制 (A2模块)
# ============================================================
func _update_assassin(delta):
	# 脱战计时
	assassin_out_of_combat_timer += delta

	# 脱战3秒进入潜行
	if not assassin_stealth_active and assassin_out_of_combat_timer >= ASSASSIN_STEALTH_ENTER_TIME:
		_assassin_enter_stealth()

	# 潜行状态视觉保持
	if assassin_stealth_active:
		_assassin_maintain_stealth_visual()

func _assassin_enter_stealth():
	"""进入潜行状态"""
	assassin_stealth_active = true
	if _player.has_node("Sprite"):
		var sprite = _player.get_node("Sprite")
		assassin_original_alpha = sprite.modulate.a
		sprite.modulate.a = 0.4  # 半透明
	print("[Assassin] 进入潜行")

func _assassin_exit_stealth():
	"""退出潜行状态"""
	assassin_stealth_active = false
	assassin_out_of_combat_timer = 0.0
	if _player.has_node("Sprite"):
		var sprite = _player.get_node("Sprite")
		sprite.modulate.a = assassin_original_alpha
	print("[Assassin] 退出潜行")

func _assassin_maintain_stealth_visual():
	"""保持潜行视觉效果(避免其他系统覆盖透明度)"""
	if _player.has_node("Sprite"):
		var sprite = _player.get_node("Sprite")
		if sprite.modulate.a > 0.5:  # 检测是否被覆盖
			sprite.modulate.a = 0.4

func assassin_on_attack():
	"""刺客攻击时调用(由CombatSystem或Player调用)"""
	if not assassin_stealth_active:
		# 非潜行攻击重置脱战计时
		assassin_out_of_combat_timer = 0.0
		return

	# 潜行首次攻击退出潜行
	_assassin_exit_stealth()

func assassin_is_backstab() -> bool:
	"""检查是否为背刺攻击"""
	return assassin_stealth_active

func assassin_get_backstab_damage_mult() -> float:
	"""获取背刺伤害倍率"""
	if assassin_stealth_active:
		return ASSASSIN_STEALTH_CRIT_MULT
	return 1.0

# ============================================================
# 骑士(class_knight)：圣盾反伤
# ============================================================

func _update_knight(delta):
	# 盾冷却倒计时
	if knight_shield_cooldown > 0:
		knight_shield_cooldown -= delta

	# 盾持续时间
	if knight_shield_active:
		knight_shield_timer -= delta
		if knight_shield_timer <= 0:
			_knight_deactivate_shield()

	# 职业调优: 改用class_skill(R键)统一输入,不再用ui_accept避免冲突
	# 注: 实际触发由Player.gd调用activate_knight_shield()
	# if Input.is_action_just_pressed("class_skill") and knight_shield_cooldown <= 0 and not knight_shield_active:
	#     _knight_activate_shield()

## 职业调优: 骑士圣盾公共接口(供Player.gd调用)
func activate_knight_shield() -> bool:
	if _current_class_id != "class_knight":
		return false
	if knight_shield_cooldown > 0:
		print("[Knight] 圣盾冷却中 (%.1fs)" % knight_shield_cooldown)
		return false
	if knight_shield_active:
		return false
	_knight_activate_shield()
	return true

func _knight_activate_shield():
	"""激活圣盾"""
	knight_shield_active = true
	knight_shield_timer = KNIGHT_SHIELD_DURATION
	knight_shield_cooldown = KNIGHT_SHIELD_COOLDOWN

	# 视觉效果：金色光晕
	if _player.has_node("Sprite"):
		var sprite = _player.get_node("Sprite")
		knight_original_modulate = sprite.modulate
		sprite.modulate = Color(1.4, 1.3, 0.8)

	# 特效
	if has_node("/root/EffectSprite"):
		EffectSprite.spawn(_player.get_parent(), "holy", _player.global_position, 2.0)

	print("[Knight] 圣盾激活 持续%.1fs" % KNIGHT_SHIELD_DURATION)

func _knight_deactivate_shield():
	"""圣盾结束"""
	knight_shield_active = false

	# 恢复视觉
	if _player.has_node("Sprite"):
		var sprite = _player.get_node("Sprite")
		sprite.modulate = knight_original_modulate

	print("[Knight] 圣盾结束")

func knight_on_take_damage(damage_amount: float) -> float:
	"""骑士受伤时调用(由Player.take_damage调用)，返回实际承受伤害"""
	if not knight_shield_active:
		return damage_amount

	# 圣盾激活时反弹部分伤害
	var reflect_damage = damage_amount * KNIGHT_SHIELD_REFLECT_RATIO
	_knight_reflect_damage(reflect_damage)

	return damage_amount  # 骑士承受全伤，但反弹给敌人

func _knight_reflect_damage(damage: float):
	"""反弹伤害给最近敌人"""
	var nearest = _find_nearest_enemy()
	if nearest == null:
		return

	if nearest.has_method("take_damage"):
		nearest.take_damage(damage)
		# 神圣伤害特效
		if has_node("/root/EffectSprite"):
			EffectSprite.spawn(nearest.get_parent(), "holy", nearest.global_position, 1.0)
		print("[Knight] 圣盾反弹 %.1f 伤害" % damage)

func knight_is_shield_active() -> bool:
	"""检查圣盾是否激活(供UI显示用)"""
	return knight_shield_active

# ============================================================
# 死灵(class_necromancer)：召唤亡灵+尸爆
# ============================================================

func _update_necromancer(delta):
	# 召唤冷却
	if necro_summon_cooldown > 0:
		necro_summon_cooldown -= delta

	# 清理失效骷髅
	necro_skeletons = necro_skeletons.filter(func(s): return is_instance_valid(s))

	# 自动召唤骷髅(冷却好了且未满员)
	if necro_summon_cooldown <= 0 and necro_skeletons.size() < NECRO_MAX_SKELETONS:
		_necro_summon_skeleton()

	# 尸爆输入检测(按E引爆最近尸体)
	if Input.is_action_just_pressed("interact"):
		_necro_explode_nearest_corpse()

func _necro_summon_skeleton():
	"""召唤骷髅随从"""
	var skeleton = _necro_create_skeleton()
	if skeleton:
		var scene = get_tree().current_scene
		if scene:
			scene.add_child(skeleton)
			skeleton.global_position = _player.global_position + Vector2(randf_range(-50, 50), randf_range(-50, 50))
			necro_skeletons.append(skeleton)
			necro_summon_cooldown = NECRO_SUMMON_COOLDOWN

			# 召唤特效
			if has_node("/root/EffectSprite"):
				EffectSprite.spawn(scene, "poison", skeleton.global_position, 1.2)

			print("[Necromancer] 召唤骷髅 (%d/%d)" % [necro_skeletons.size(), NECRO_MAX_SKELETONS])

func _necro_create_skeleton() -> CharacterBody2D:
	"""创建骷髅召唤物(友方单位)"""
	var skeleton = CharacterBody2D.new()
	skeleton.add_to_group("necro_minion")
	skeleton.add_to_group("friendly")

	# 视觉
	var visual = ColorRect.new()
	visual.size = Vector2(24, 24)
	visual.position = Vector2(-12, -12)
	visual.color = Color(0.7, 0.7, 0.6, 0.9)  # 骨白色
	skeleton.add_child(visual)

	# 简单血条
	var hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.max_value = 40
	hp_bar.value = 40
	hp_bar.custom_minimum_size = Vector2(32, 4)
	hp_bar.size = Vector2(32, 4)
	hp_bar.position = Vector2(-16, -24)
	var fill_style = StyleBoxFlat.new()
	fill_style.bg_color = Color(0.6, 0.6, 0.5)
	hp_bar.add_theme_stylebox_override("fill", fill_style)
	skeleton.add_child(hp_bar)

	# 元数据
	skeleton.set_meta("max_hp", 40.0)
	skeleton.set_meta("current_hp", 40.0)
	skeleton.set_meta("damage", 8.0)
	skeleton.set_meta("attack_cd", 0.0)
	skeleton.set_meta("move_speed", 200.0)
	skeleton.set_meta("hp_bar", hp_bar)

	skeleton.set_script(_necro_skeleton_script())

	return skeleton

func _necro_skeleton_script() -> GDScript:
	"""骷髅AI脚本"""
	var src = """
extends CharacterBody2D

func _physics_process(delta):
	var current_hp = get_meta("current_hp")
	var max_hp = get_meta("max_hp")

	# 死亡检测
	if current_hp <= 0:
		_die()
		return

	# 更新血条
	var hp_bar = get_meta("hp_bar")
	if is_instance_valid(hp_bar):
		hp_bar.value = current_hp

	# 攻击冷却
	var attack_cd = get_meta("attack_cd") - delta
	set_meta("attack_cd", attack_cd)

	# AI：追击最近敌人
	var target = _nearest_enemy()
	if target == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var dist = global_position.distance_to(target.global_position)
	var move_speed = get_meta("move_speed")

	if dist > 40:
		# 追击
		var dir = (target.global_position - global_position).normalized()
		velocity = dir * move_speed
		move_and_slide()
	elif attack_cd <= 0:
		# 攻击
		velocity = Vector2.ZERO
		if target.has_method("take_damage"):
			target.take_damage(get_meta("damage"))
		set_meta("attack_cd", 1.2)

func _nearest_enemy():
	var nearest = null
	var min_d = 99999.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d = global_position.distance_to(e.global_position)
		if d < min_d:
			min_d = d
			nearest = e
	return nearest

func take_damage(amount: float):
	var current_hp = get_meta("current_hp") - amount
	set_meta("current_hp", current_hp)
	# 受击闪白
	if has_node("ColorRect"):
		var visual = get_node("ColorRect")
		visual.color = Color.WHITE
		await get_tree().create_timer(0.1).timeout
		if is_instance_valid(visual):
			visual.color = Color(0.7, 0.7, 0.6, 0.9)

func _die():
	# 骷髅死亡时留下尸体(死灵职业特性)
	if has_node("/root/ClassMechanicSystem"):
		get_node("/root/ClassMechanicSystem").necro_register_corpse(global_position)
	queue_free()
"""
	var gd = GDScript.new()
	gd.source_code = src
	gd.reload()
	return gd

func necro_register_corpse(pos: Vector2):
	"""敌人死亡时注册尸体(由Enemy.die调用)"""
	if _current_class_id != "class_necromancer":
		return

	# 创建尸体标记
	var corpse = _create_corpse_marker(pos)
	if corpse:
		var scene = get_tree().current_scene
		if scene:
			scene.add_child(corpse)
			necro_corpses.append(corpse)
			print("[Necromancer] 尸体标记 x%d" % necro_corpses.size())

func _create_corpse_marker(pos: Vector2) -> Node2D:
	"""创建尸体可视标记"""
	var marker = Node2D.new()
	marker.global_position = pos
	marker.add_to_group("necro_corpse")

	var visual = ColorRect.new()
	visual.size = Vector2(16, 16)
	visual.position = Vector2(-8, -8)
	visual.color = Color(0.3, 0.2, 0.2, 0.7)  # 暗红腐肉色
	marker.add_child(visual)

	marker.set_meta("life", 30.0)  # 尸体存续30秒
	marker.set_script(_corpse_timer_script())

	return marker

func _corpse_timer_script() -> GDScript:
	"""尸体定时消失脚本"""
	var src = """
extends Node2D
func _process(delta):
	var life = get_meta("life") - delta
	set_meta("life", life)
	if life <= 0:
		queue_free()
"""
	var gd = GDScript.new()
	gd.source_code = src
	gd.reload()
	return gd

func _necro_explode_nearest_corpse():
	"""引爆最近的尸体"""
	# 清理失效尸体
	necro_corpses = necro_corpses.filter(func(c): return is_instance_valid(c))

	if necro_corpses.is_empty():
		return

	# 找最近尸体
	var nearest_corpse = null
	var min_dist = 99999.0
	for corpse in necro_corpses:
		var dist = _player.global_position.distance_to(corpse.global_position)
		if dist < min_dist:
			min_dist = dist
			nearest_corpse = corpse

	if nearest_corpse == null:
		return

	# 尸爆效果
	var explode_pos = nearest_corpse.global_position
	_necro_corpse_explosion(explode_pos)

	# 移除尸体
	necro_corpses.erase(nearest_corpse)
	nearest_corpse.queue_free()

func _necro_corpse_explosion(pos: Vector2):
	"""尸体爆炸范围伤害"""
	var damage = NECRO_CORPSE_EXPLODE_DAMAGE
	var radius = NECRO_CORPSE_EXPLODE_RADIUS

	# AOE伤害判定
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if enemy.global_position.distance_to(pos) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage)

	# 视觉特效
	if has_node("/root/EffectSprite"):
		EffectSprite.spawn(get_tree().current_scene, "poison", pos, radius / 60.0)

	print("[Necromancer] 尸爆! 伤害:%.1f 范围:%.0f" % [damage, radius])

func _cleanup_all_corpses():
	"""清理所有尸体(重置时)"""
	for corpse in necro_corpses:
		if is_instance_valid(corpse):
			corpse.queue_free()
	necro_corpses.clear()

# ============================================================
# 工具方法(各职业共用)
# ============================================================

func _find_nearest_enemy() -> Node2D:
	"""查找最近敌人"""
	if _player == null:
		return null

	var nearest = null
	var min_d = 99999.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d = _player.global_position.distance_to(e.global_position)
		if d < min_d:
			min_d = d
			nearest = e
	return nearest
