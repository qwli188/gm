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
var _knockback_velocity: Vector2 = Vector2.ZERO  # 击退速度
var _knockback_decay: float = 0.0  # 击退衰减计时器

# Boss 阶段系统
var current_phase: int = 1
var phase_thresholds: Array = [0.7, 0.4]  # 70% 和 40% 血量触发转换
var skill_cooldown: float = 0.0
var _is_boss: bool = false
var attack_speed_mult: float = 1.0  # 阶段转换时提升，缩短攻击间隔
var _casting: bool = false  # 防止多个 AOE await 叠加

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

	_is_boss = enemy_data.get("rank", "normal") == "boss"
	if _is_boss:
		skill_cooldown = randf_range(8.0, 12.0)

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

	# Boss 技能循环
	if _is_boss and not _dying:
		skill_cooldown -= delta
		if skill_cooldown <= 0 and not _casting:
			# 阶段1: 优先使用区域专属技能
			if enemy_data.has("boss_skills") and not enemy_data.get("boss_skills", []).is_empty():
				_use_regional_boss_skill()
			else:
				_use_boss_skill()
			skill_cooldown = randf_range(8.0, 12.0)

	# 击退衰减(优先于 AI:被击退时不执行追击)
	if _knockback_decay > 0:
		_knockback_decay -= delta
		velocity = _knockback_velocity.lerp(Vector2.ZERO, 1.0 - (_knockback_decay / 0.15))
		if _knockback_decay <= 0:
			_knockback_velocity = Vector2.ZERO
	else:
		# 正常移动逻辑
		var distance = global_position.distance_to(player.global_position)
		if distance < ATTACK_DISTANCE:
			attack()
		elif distance < VISION_RANGE:
			chase_player(delta)
		else:
			velocity = Vector2.ZERO

	move_and_slide()

func chase_player(delta):
	# 应用减速效果和眩晕
	var effective_speed = move_speed * slow_multiplier
	if is_frozen or is_stunned:
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
	attack_cooldown = 1.0 / attack_speed_mult  # 攻速提升时间隔缩短(Boss狂暴)

func _on_attack_anim_done():
	_is_attacking = false
	if anim_sprite:
		anim_sprite.play("idle")

func take_damage(damage_amount: float, is_crit: bool = false):
	current_hp -= damage_amount
	AudioManager.play("hit")
	_flash_white()
	_squash_hit()  # B2: 挤压变形增强打击感
	_update_hp_bar()
	# 漂浮伤害数字
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -30), damage_amount, is_crit)
	# 受击火花特效
	EffectSprite.spawn(get_parent(), "hit", global_position, 1.0)

	if current_hp <= 0:
		die()
		return

	# Boss 阶段转换检查
	if _is_boss:
		_check_phase_transition()

## 打击感 - 受击挤压变形(B2)
func _squash_hit():
	if anim_sprite:
		var original_scale = anim_sprite.scale
		var tween = create_tween()
		tween.tween_property(anim_sprite, "scale", Vector2(original_scale.x * 1.15, original_scale.y * 0.85), 0.06)
		tween.tween_property(anim_sprite, "scale", original_scale, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 打击感 - 击退效果
func apply_knockback(attacker_pos: Vector2, is_crit: bool):
	var knockback_dir = (global_position - attacker_pos).normalized()
	var knockback_force = 600.0 if is_crit else 300.0  # 暴击更大击退力
	_knockback_velocity = knockback_dir * knockback_force
	_knockback_decay = 0.15  # 击退持续 0.15 秒
	velocity = _knockback_velocity

## ============ Boss 阶段系统 ============
func _check_phase_transition():
	var hp_percent = current_hp / max_hp
	if hp_percent <= phase_thresholds[0] and current_phase == 1:
		_enter_phase(2)
	elif hp_percent <= phase_thresholds[1] and current_phase == 2:
		_enter_phase(3)

func _enter_phase(phase: int):
	current_phase = phase
	print("[Boss] 进入第 %d 阶段" % phase)
	# 阶段转换特效：脚下爆发 + 短暂染色脉冲
	EffectSprite.spawn(get_parent(), "fire", global_position, 2.0)
	if anim_sprite:
		var tween = create_tween()
		tween.tween_property(anim_sprite, "modulate", Color(2.0, 0.6, 0.6), 0.15)
		var base_tint = SpriteLibrary.RANK_TINT.get("boss", Color.WHITE)
		tween.tween_property(anim_sprite, "modulate", base_tint, 0.3)

	if phase == 2:
		# 狂暴：攻速、移速提升
		attack_speed_mult *= 1.3
		move_speed *= 1.2
		skill_cooldown = min(skill_cooldown, 2.2)
	elif phase == 3:
		# 终焉：再次提速，召唤援军 + 缩短技能冷却
		attack_speed_mult *= 1.3
		move_speed *= 1.15
		_summon_adds(2)
		skill_cooldown = min(skill_cooldown, 2.2)

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
var slow_timer: float = 0.0
var base_move_speed: float = 0.0
var slow_multiplier: float = 1.0
var stun_timer: float = 0.0
var is_stunned: bool = false

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
	# B1 shader接线: 冰冻视觉层
	if anim_sprite:
		ShaderHelper.apply_status_overlay(anim_sprite, "freeze", 0.6)

func apply_slow(slow_percent: float, duration: float):
	slow_multiplier = 1.0 - slow_percent
	slow_timer = duration

func apply_stun(duration: float):
	is_stunned = true
	stun_timer = duration
	# 眩晕使用冰冻的停止逻辑，但不变色
	if not is_frozen:
		base_move_speed = move_speed
	move_speed = 0

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
				# B1 shader接线: 清除冰冻层
				if anim_sprite:
					ShaderHelper.remove_status_overlay(anim_sprite)
					anim_sprite.modulate = SpriteLibrary.RANK_TINT.get(enemy_data.get("rank", "normal"), Color.WHITE)

	if slow_timer > 0:
		slow_timer -= delta
		if slow_timer <= 0:
			slow_multiplier = 1.0

	if stun_timer > 0:
		stun_timer -= delta
		if stun_timer <= 0:
			is_stunned = false
			if not is_frozen:
				move_speed = base_move_speed

	_update_hp_bar()

	# 死亡检查
	if current_hp <= 0:
		die()

## 受击闪白
func _flash_white():
	# 旧代码(tween modulate闪白,注释保留):
	# if anim_sprite:
	#   anim_sprite.modulate = Color(2.5, 2.5, 2.5)
	#   var rank = enemy_data.get("rank", "normal")
	#   var base_tint = SpriteLibrary.RANK_TINT.get(rank, Color.WHITE)
	#   var tween = create_tween()
	#   tween.tween_property(anim_sprite, "modulate", base_tint, 0.12)

	# B1 shader接线: 受击闪白shader
	if anim_sprite:
		ShaderHelper.apply_hit_flash(anim_sprite, Color.WHITE, 0.12)


# ============================================================
# Boss 技能系统：AOE 冲击波 / 地刺预警 / 召唤援军
# ============================================================

## 选择并释放一个 Boss 技能（阶段越高可用技能越多）
func _use_boss_skill():
	if not player or not is_instance_valid(player):
		return
	if _casting:
		return  # 防止多个 AOE await 叠加
	var choices := ["aoe_self"]
	if current_phase >= 2:
		choices.append("aoe_target")  # 在玩家脚下落下地刺
	if current_phase >= 3:
		choices.append("summon")
	var skill = choices[randi() % choices.size()]
	match skill:
		"aoe_self":
			_boss_aoe_attack(global_position, 150.0)
		"aoe_target":
			_boss_aoe_attack(player.global_position, 150.0)
		"summon":
			_summon_adds(3)

## AOE 攻击：先显示预警圈，1.5 秒后在范围内结算伤害
func _boss_aoe_attack(center: Vector2, radius: float):
	_casting = true
	var warning = _create_warning_circle(center, radius)
	get_parent().add_child(warning)
	# 节点进入场景树后再启动闪烁 Tween（Godot 4 要求 Tween 绑定在树内节点）
	var blink = warning.create_tween().set_loops()
	blink.tween_property(warning, "modulate:a", 0.9, 0.25)
	blink.tween_property(warning, "modulate:a", 0.3, 0.25)
	# 阶段越高伤害越高
	var aoe_damage = damage * (1.0 + 0.5 * (current_phase - 1))
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self):
		if is_instance_valid(warning):
			warning.queue_free()
		return
	_deal_aoe_damage(center, radius, aoe_damage)
	EffectSprite.spawn(get_parent(), "fire", center, radius / 75.0)
	if is_instance_valid(warning):
		warning.queue_free()
	_casting = false

## 生成红色半透明预警圈（带闪烁动画）
func _create_warning_circle(pos: Vector2, radius: float) -> Node2D:
	var circle = ColorRect.new()
	circle.size = Vector2(radius * 2, radius * 2)
	circle.global_position = pos - circle.size / 2.0
	circle.color = Color(1.0, 0.2, 0.2, 0.35)
	circle.z_index = -1  # 画在角色脚下
	return circle

## AOE 伤害判定：用 distance_to 遍历 player 组
func _deal_aoe_damage(center: Vector2, radius: float, dmg: float):
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if not is_instance_valid(p):
			continue
		if p.global_position.distance_to(center) <= radius and p.has_method("take_damage"):
			p.take_damage(dmg)

## 召唤援军：在 Boss 周围生成普通小怪
func _summon_adds(count: int):
	print("[Boss] 召唤 %d 个援军" % count)
	var add_id = enemy_data.get("summon_id", "")
	for i in range(count):
		var offset = Vector2(randf_range(-80, 80), randf_range(-80, 80))
		var spawn_pos = global_position + offset
		var add = null
		if add_id != "":
			add = load("res://scripts/Enemy.gd").create_enemy(add_id, spawn_pos)
		# 没有指定 summon_id 时，复用本敌人的配置但降格为普通怪
		if add == null:
			add = _spawn_minion_from_self(spawn_pos)
		if add != null:
			get_parent().add_child(add)
			EffectSprite.spawn(get_parent(), "frost", spawn_pos, 1.0)

## 根据 Boss 自身配置克隆一个弱化的普通小怪
func _spawn_minion_from_self(spawn_pos: Vector2) -> Node2D:
	var minion_data = enemy_data.duplicate(true)
	minion_data["rank"] = "normal"
	# 弱化数值，避免召唤物喧宾夺主
	if minion_data.has("base_stats"):
		var bs = minion_data["base_stats"]
		bs["max_hp"] = bs.get("max_hp", 20) * 0.3
		bs["damage"] = bs.get("damage", 5) * 0.5
	var minion = CharacterBody2D.new()
	minion.set_script(load("res://scripts/Enemy.gd"))
	minion.enemy_data = minion_data
	minion.global_position = spawn_pos
	return minion


var _dying := false
func die():
	if _dying:
		return
	_dying = true

	# A2: 死灵职业 - 注册尸体(供尸爆)
	if has_node("/root/ClassMechanicSystem"):
		var cms = get_node("/root/ClassMechanicSystem")
		if cms.has_method("necro_register_corpse"):
			cms.necro_register_corpse(global_position)

	# B2: 死亡爆裂粒子
	var burst_color = Color(1.0, 0.3, 0.3)
	var rank = enemy_data.get("rank", "normal")
	if rank == "boss":
		burst_color = Color(1.0, 0.5, 0.0)  # Boss橙色
	elif rank == "elite":
		burst_color = Color(0.8, 0.2, 0.8)  # 精英紫色
	ParticleHelper.spawn_death_burst(get_parent(), global_position, burst_color)

	# B2: 击杀定格(0.05秒,增强打击感)
	Engine.time_scale = 0.0
	get_tree().create_timer(0.05, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
	)

	# B1 shader接线: 死亡溶解效果(替代瞬间消失)
	if anim_sprite:
		var dissolve_color = burst_color  # 复用爆裂颜色
		var tween = ShaderHelper.apply_dissolve(anim_sprite, "out", 0.8, dissolve_color)
		if tween:
			await tween.finished

	drop_loot()
	drop_material()

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

## 掉落区域专属材料
func drop_material():
	if not has_node("/root/GameState"):
		return
	var game_state = get_node("/root/GameState")
	var dungeon_id = game_state.selected_dungeon_id
	if dungeon_id == "":
		return

	# 从副本配置读取 material_type
	var dungeon = ConfigLoader.get_dungeon_by_id(dungeon_id)
	if dungeon.is_empty():
		return

	var material_type = dungeon.get("material_type", "")
	if material_type == "":
		return

	# 从 balance.json 读取材料掉落配置
	var materials_config = ConfigLoader.balance_data.get("region_materials", {}).get("materials", [])
	var material_data = null
	for mat in materials_config:
		if mat.get("id", "") == material_type:
			material_data = mat
			break

	if material_data == null:
		return

	# 掉落判定
	var drop_rate = material_data.get("drop_rate", 0.2)
	if randf() < drop_rate:
		var drop_min = material_data.get("drop_amount_min", 1)
		var drop_max = material_data.get("drop_amount_max", 3)
		var amount = randi_range(drop_min, drop_max)
		game_state.add_material(material_type, amount)
		print("[Enemy] 掉落材料: %s x%d" % [material_type, amount])

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


# ============================================================
# 阶段1: 区域专属Boss技能 (模块3扩展)
# ============================================================

## 使用区域专属技能（覆盖通用技能）
func _use_regional_boss_skill():
	"""从boss_skills数组随机选择一个技能执行"""
	var skills = enemy_data.get("boss_skills", [])
	if skills.is_empty():
		_use_boss_skill()  # 回退到通用技能
		return
	
	if not player or not is_instance_valid(player):
		return
	if _casting:
		return
	
	# 根据阶段过滤可用技能（阶段越高技能越多）
	var available = []
	for skill in skills:
		var skill_index = skills.find(skill)
		if skill_index < current_phase:  # 阶段1只用第1个技能，阶段2用前2个，阶段3全部
			available.append(skill)
	
	if available.is_empty():
		available = [skills[0]]  # 至少用第1个技能
	
	var selected = available[randi() % available.size()]
	_execute_regional_skill(selected)

## 执行区域专属技能
func _execute_regional_skill(skill_name: String):
	match skill_name:
		# 简单技能组
		"熔铸之锤":
			_skill_forge_hammer()
		"永冻吐息":
			_skill_frost_breath()
		"死亡之息":
			_skill_death_breath()
		# 中等技能组
		"瘟疫脉冲":
			_skill_plague_pulse()
		"白骨旋风":
			_skill_bone_whirlwind()
		"孵化狂潮":
			_skill_spawn_frenzy()
		# 复杂技能组
		"王座审判":
			_skill_throne_judgment()
		"陨石天降":
			_skill_meteor_storm()
		"寒冰牢笼":
			_skill_ice_prison()
		"现实撕裂":
			_skill_reality_rift()
		"深渊冲锋":
			_skill_abyss_charge()
		"腐化号令":
			_skill_corruption_call()
		# 未实现的高难度技能（回退）
		_:
			print("[Boss] 未实现的技能: ", skill_name)
			_use_boss_skill()  # 回退

# ────────────────────────────────────────────────────────────
# 简单技能组
# ────────────────────────────────────────────────────────────

## 熔铸之锤：直线冲击波 + 点燃
func _skill_forge_hammer():
	_casting = true
	var direction = (player.global_position - global_position).normalized()
	
	# 1秒蓄力动画（身体发红光）
	if anim_sprite:
		anim_sprite.modulate = Color(2.0, 0.5, 0.5)
	
	# 显示冲击波预警线（5米长，宽50）
	var warning = ColorRect.new()
	warning.size = Vector2(500, 50)
	warning.color = Color(1.0, 0.3, 0.0, 0.4)
	warning.global_position = global_position
	warning.rotation = direction.angle()
	warning.z_index = -1
	get_parent().add_child(warning)
	
	var blink = warning.create_tween().set_loops()
	blink.tween_property(warning, "modulate:a", 0.7, 0.25)
	blink.tween_property(warning, "modulate:a", 0.2, 0.25)
	
	await get_tree().create_timer(1.0).timeout
	
	if not is_instance_valid(self):
		if is_instance_valid(warning):
			warning.queue_free()
		return
	
	# 恢复颜色
	if anim_sprite:
		anim_sprite.modulate = SpriteLibrary.RANK_TINT.get(enemy_data.get("rank", "normal"), Color.WHITE)
	
	# 冲击波判定（射线检测）
	var hit_player = false
	if player and is_instance_valid(player):
		var to_player = player.global_position - global_position
		var distance = to_player.length()
		if distance <= 500 and abs(to_player.angle() - direction.angle()) < 0.3:  # 锥形判定
			player.take_damage(80)
			# 点燃效果（需CombatSystem支持）
			if has_node("/root/CombatSystem"):
				get_node("/root/CombatSystem").trigger_ignite(player, 20, 5.0)
			hit_player = true
	
	# 特效
	EffectSprite.spawn(get_parent(), "fire", global_position + direction * 250, 3.0)
	AudioManager.play("attack")
	
	if is_instance_valid(warning):
		warning.queue_free()
	_casting = false

## 永冻吐息：扇形180度 + 冰冻叠层
func _skill_frost_breath():
	_casting = true
	var direction = (player.global_position - global_position).normalized()
	
	# 2秒预警（扇形区域）
	var warning = _create_fan_warning(global_position, direction, 300, PI)  # 180度扇形
	get_parent().add_child(warning)
	
	var blink = warning.create_tween().set_loops()
	blink.tween_property(warning, "modulate:a", 0.8, 0.3)
	blink.tween_property(warning, "modulate:a", 0.3, 0.3)
	
	await get_tree().create_timer(2.0).timeout
	
	if not is_instance_valid(self):
		if is_instance_valid(warning):
			warning.queue_free()
		return
	
	# 扇形判定
	if player and is_instance_valid(player):
		var to_player = player.global_position - global_position
		var distance = to_player.length()
		var angle_diff = abs(to_player.angle() - direction.angle())
		
		if distance <= 300 and angle_diff < PI / 2:  # 180度内
			# 冰冻效果
			if player.has_method("apply_freeze"):
				player.apply_freeze(3.0)
			else:
				player.take_damage(60)
	
	# 冰霜特效
	EffectSprite.spawn(get_parent(), "frost", global_position + direction * 150, 2.5)
	
	if is_instance_valid(warning):
		warning.queue_free()
	_casting = false

## 死亡之息：扇形120度 + 死亡标记debuff
func _skill_death_breath():
	_casting = true
	var direction = (player.global_position - global_position).normalized()
	
	# 3秒预警（扇形120度）
	var warning = _create_fan_warning(global_position, direction, 350, PI * 0.67)  # 120度
	warning.color = Color(0.5, 0.2, 0.5, 0.4)  # 紫黑色
	get_parent().add_child(warning)
	
	var blink = warning.create_tween().set_loops()
	blink.tween_property(warning, "modulate:a", 0.9, 0.35)
	blink.tween_property(warning, "modulate:a", 0.25, 0.35)
	
	await get_tree().create_timer(3.0).timeout
	
	if not is_instance_valid(self):
		if is_instance_valid(warning):
			warning.queue_free()
		return
	
	# 扇形判定
	if player and is_instance_valid(player):
		var to_player = player.global_position - global_position
		var distance = to_player.length()
		var angle_diff = abs(to_player.angle() - direction.angle())
		
		if distance <= 350 and angle_diff < PI / 3:  # 120度内
			# 造成最大生命15%伤害
			var max_hp = player.get("max_hp", 100)
			var death_damage = max_hp * 0.15
			player.take_damage(death_damage)
			
			# TODO: 死亡标记debuff（受到伤害+30%，持续8秒）
			# 需要扩展Player.gd的debuff系统
			print("[Boss] 死亡标记命中玩家！")
	
	# 死亡特效
	EffectSprite.spawn(get_parent(), "dark", global_position + direction * 175, 2.8)
	
	if is_instance_valid(warning):
		warning.queue_free()
	_casting = false

## 辅助：创建扇形预警区域
func _create_fan_warning(pos: Vector2, dir: Vector2, radius: float, angle: float) -> Polygon2D:
	var fan = Polygon2D.new()
	fan.color = Color(0.8, 1.0, 1.0, 0.4)  # 冰蓝色半透明
	fan.z_index = -1
	
	# 生成扇形多边形顶点
	var points = [Vector2.ZERO]  # 中心点
	var segments = 16
	for i in range(segments + 1):
		var theta = -angle / 2 + (angle / segments) * i
		var point = Vector2(cos(theta), sin(theta)) * radius
		# 旋转到方向
		var rotated = point.rotated(dir.angle())
		points.append(rotated)
	
	fan.polygon = PackedVector2Array(points)
	fan.global_position = pos
	return fan

# ────────────────────────────────────────────────────────────
# 中等技能组（待实现）
# ────────────────────────────────────────────────────────────

## 瘟疫脉冲：全屏DOT + 毒层叠加
func _skill_plague_pulse():
	_casting = true

	# 1.5秒预警（全屏绿色脉冲）
	var warning = ColorRect.new()
	warning.size = Vector2(2000, 2000)  # 覆盖大部分屏幕
	warning.color = Color(0.2, 0.8, 0.2, 0.25)
	warning.global_position = global_position - warning.size / 2
	warning.z_index = -2
	get_parent().add_child(warning)

	# 脉冲扩散动画
	var expand = warning.create_tween()
	expand.tween_property(warning, "scale", Vector2(1.5, 1.5), 1.5)
	expand.parallel().tween_property(warning, "modulate:a", 0.0, 1.5)

	await get_tree().create_timer(1.5).timeout

	if not is_instance_valid(self):
		if is_instance_valid(warning):
			warning.queue_free()
		return

	# 全屏判定：对所有玩家施加毒层
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p):
			# 施加毒层（需CombatSystem支持层数叠加）
			if has_node("/root/CombatSystem"):
				get_node("/root/CombatSystem").trigger_poison(p, 5.0, 8.0)  # 5 DPS持续8秒
			else:
				p.take_damage(40)  # 降级处理

	# 瘟疫特效
	EffectSprite.spawn(get_parent(), "poison", global_position, 3.0)
	print("[Boss] 瘟疫脉冲命中所有玩家！")

	if is_instance_valid(warning):
		warning.queue_free()
	_casting = false

## 白骨旋风：追踪旋风 + 持续伤害
func _skill_bone_whirlwind():
	_casting = true

	# 生成旋风实体（CharacterBody2D追踪玩家）
	var whirlwind = CharacterBody2D.new()
	whirlwind.global_position = global_position
	whirlwind.name = "BoneWhirlwind"

	# 添加视觉（旋转的骨刺精灵）
	var sprite = Sprite2D.new()
	sprite.texture = SPRITE_SHEET  # 复用敌人sprite
	sprite.region_enabled = true
	sprite.region_rect = Rect2(408, 238, 16, 16)  # 骨头精灵
	sprite.scale = Vector2(3, 3)
	sprite.modulate = Color(0.9, 0.9, 1.2)
	whirlwind.add_child(sprite)

	# 添加碰撞体
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 40
	collision.shape = shape
	whirlwind.add_child(collision)

	get_parent().add_child(whirlwind)

	# 追踪逻辑（6秒寿命）
	var lifetime = 6.0
	var speed = 120.0
	while lifetime > 0 and is_instance_valid(whirlwind) and is_instance_valid(self):
		await get_tree().create_timer(0.1).timeout
		lifetime -= 0.1

		if not is_instance_valid(player):
			break

		# 追踪玩家
		var direction = (player.global_position - whirlwind.global_position).normalized()
		whirlwind.velocity = direction * speed
		whirlwind.move_and_slide()

		# 旋转动画
		sprite.rotation += 0.3

		# 碰撞判定（接触造成伤害）
		var distance = whirlwind.global_position.distance_to(player.global_position)
		if distance < 50:
			player.take_damage(30)
			# 击退
			if player.has_method("apply_knockback"):
				player.apply_knockback(whirlwind.global_position, false)
			lifetime -= 1.0  # 命中后加速消失

	if is_instance_valid(whirlwind):
		whirlwind.queue_free()

	_casting = false
	print("[Boss] 白骨旋风结束")

## 孵化狂潮：持续召唤小怪
func _skill_spawn_frenzy():
	_casting = true

	print("[Boss] 孵化狂潮开始！8秒内每秒生成5只蛆群")

	# 8秒内每秒生成5只小怪
	var duration = 8
	for wave in range(duration):
		if not is_instance_valid(self) or _dying:
			break

		# 每波生成5只
		for i in range(5):
			_spawn_minion("swarm")

		# 特效
		EffectSprite.spawn(get_parent(), "poison", global_position, 1.5)

		await get_tree().create_timer(1.0).timeout

	_casting = false
	print("[Boss] 孵化狂潮结束，共生成", duration * 5, "只蛆群")

## 辅助：生成小怪
func _spawn_minion(minion_type: String):
	"""生成指定类型的小怪"""
	# 随机位置（Boss周围半径150）
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * randf_range(50, 150)
	var spawn_pos = global_position + offset

	# 简化版：复用现有敌人数据
	var minion_data = {
		"id": "minion_" + minion_type,
		"name": "蛆群",
		"rank": "normal",
		"base_stats": {
			"hp": 20,  # 血量减半
			"damage": 5,
			"armor": 0,
			"move_speed": 80
		},
		"sprite_region": [391, 238, 16, 16],  # 小虫精灵
		"behavior": {"ai_type": "aggressive", "attack_range": 50, "chase_range": 300}
	}

	# 生成敌人实例
	var minion = preload("res://scripts/Enemy.gd").new()
	minion.enemy_data = minion_data
	minion.global_position = spawn_pos

	# 添加到场景
	get_parent().add_child(minion)
	minion._ready()  # 手动初始化



# ────────────────────────────────────────────────────────────
# 复杂技能组 (阶段1深度实施)
# ────────────────────────────────────────────────────────────

## 王座审判：飞天无敌 + 8方位骨刺 + 召唤
func _skill_throne_judgment():
	_casting = true
	print("[Boss] 王座审判！飞至上空")

	# 飞至上空（无敌1.5秒）
	var original_pos = global_position
	if anim_sprite:
		anim_sprite.modulate = Color(1.5, 1.5, 2.0)  # 发光表示无敌
	set_collision_layer_value(1, false)  # 暂时无敌

	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self):
		return

	# 在玩家周围8方位生成骨刺预警（中心安全）
	if player and is_instance_valid(player):
		var center = player.global_position
		var warnings = []
		for i in range(8):
			var angle = (TAU / 8) * i
			var spike_pos = center + Vector2(cos(angle), sin(angle)) * 120
			var warning = _create_warning_circle(spike_pos, 60)
			get_parent().add_child(warning)
			warnings.append({node = warning, pos = spike_pos})

		# 1秒预警
		await get_tree().create_timer(1.0).timeout
		if not is_instance_valid(self):
			return

		# 爆发伤害
		for w in warnings:
			if is_instance_valid(w.node):
				_deal_aoe_damage(w.pos, 60, damage * 1.5)
				EffectSprite.spawn(get_parent(), "hit", w.pos, 1.5)
				w.node.queue_free()

	# 恢复
	if anim_sprite:
		anim_sprite.modulate = SpriteLibrary.RANK_TINT.get("boss", Color.WHITE)
	set_collision_layer_value(1, true)

	# 召唤4只骸骨骑士
	for i in range(4):
		_spawn_minion("skeleton_knight")

	_casting = false

## 陨石天降：6颗陨石随机落点 + 永久岩浆池
func _skill_meteor_storm():
	_casting = true
	print("[Boss] 陨石天降！")

	# 生成6个随机落点预警
	var meteor_positions = []
	for i in range(6):
		var offset = Vector2(randf_range(-400, 400), randf_range(-300, 300))
		var pos = global_position + offset
		var warning = _create_warning_circle(pos, 80)
		warning.color = Color(1.0, 0.4, 0.0, 0.4)  # 橙红色
		get_parent().add_child(warning)
		meteor_positions.append({pos = pos, warning = warning})

		var blink = warning.create_tween().set_loops()
		blink.tween_property(warning, "modulate:a", 0.8, 0.2)
		blink.tween_property(warning, "modulate:a", 0.3, 0.2)

	# 1.2秒预警
	await get_tree().create_timer(1.2).timeout
	if not is_instance_valid(self):
		return

	# 陨石落地
	for m in meteor_positions:
		if is_instance_valid(m.warning):
			_deal_aoe_damage(m.pos, 80, 100)
			EffectSprite.spawn(get_parent(), "fire", m.pos, 2.5)
			m.warning.queue_free()
			# TODO: 生成永久岩浆池（需要持久DOT区域系统）

	AudioManager.play("attack")
	_casting = false

## 寒冰牢笼：困住玩家 + 可破坏
func _skill_ice_prison():
	_casting = true
	print("[Boss] 寒冰牢笼！")

	if not player or not is_instance_valid(player):
		_casting = false
		return

	var target_pos = player.global_position

	# 1秒预警
	var warning = _create_warning_circle(target_pos, 50)
	warning.color = Color(0.4, 0.7, 1.0, 0.4)
	get_parent().add_child(warning)

	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self):
		if is_instance_valid(warning):
			warning.queue_free()
		return

	if is_instance_valid(warning):
		warning.queue_free()

	# 检查玩家是否还在原位（可走位躲避）
	if player.global_position.distance_to(target_pos) < 60:
		# 困住玩家（冰冻3秒）
		if player.has_method("apply_freeze"):
			player.apply_freeze(3.0)
		EffectSprite.spawn(get_parent(), "frost", player.global_position, 2.0)
		print("[Boss] 玩家被冰封！")

	_casting = false

## 现实撕裂：3道虚空裂隙
func _skill_reality_rift():
	_casting = true
	print("[Boss] 现实撕裂！")

	# 生成3道裂隙（横向线条）
	var rifts = []
	for i in range(3):
		var y_offset = -200 + i * 200
		var rift = ColorRect.new()
		rift.size = Vector2(800, 30)
		rift.color = Color(0.6, 0.2, 0.8, 0.5)  # 紫色
		rift.global_position = global_position + Vector2(-400, y_offset)
		rift.z_index = 5
		get_parent().add_child(rift)
		rifts.append(rift)

		var blink = rift.create_tween().set_loops()
		blink.tween_property(rift, "modulate:a", 0.9, 0.25)
		blink.tween_property(rift, "modulate:a", 0.4, 0.25)

	# 1.5秒后闭合
	await get_tree().create_timer(1.5).timeout
	if not is_instance_valid(self):
		return

	# 判定玩家是否在裂隙上
	if player and is_instance_valid(player):
		for rift in rifts:
			if is_instance_valid(rift):
				var rect = Rect2(rift.global_position, rift.size)
				if rect.has_point(player.global_position):
					player.take_damage(200)
					# 传送到场地另一侧
					player.global_position += Vector2(0, 300)
					EffectSprite.spawn(get_parent(), "void", player.global_position, 2.0)
					break

	for rift in rifts:
		if is_instance_valid(rift):
			rift.queue_free()

	_casting = false

## 深渊冲锋：锁定方向高速冲锋
func _skill_abyss_charge():
	_casting = true
	print("[Boss] 深渊冲锋蓄力...")

	if not player or not is_instance_valid(player):
		_casting = false
		return

	# 锁定玩家方向
	var charge_dir = (player.global_position - global_position).normalized()

	# 0.8秒蓄力（显示冲锋路径）
	var warning = ColorRect.new()
	warning.size = Vector2(600, 60)
	warning.color = Color(0.5, 0.1, 0.6, 0.4)
	warning.global_position = global_position
	warning.rotation = charge_dir.angle()
	warning.z_index = -1
	get_parent().add_child(warning)

	if anim_sprite:
		anim_sprite.modulate = Color(1.5, 0.5, 1.5)

	await get_tree().create_timer(0.8).timeout
	if not is_instance_valid(self):
		if is_instance_valid(warning):
			warning.queue_free()
		return

	# 高速冲锋
	var charge_distance = 600
	var charge_speed = 1500
	var start_pos = global_position
	var target_pos = start_pos + charge_dir * charge_distance

	var hit_player = false
	var tween = create_tween()
	tween.tween_property(self, "global_position", target_pos, charge_distance / charge_speed)

	# 冲锋过程检测碰撞
	while global_position.distance_to(target_pos) > 20 and is_instance_valid(self):
		await get_tree().create_timer(0.02).timeout
		if not hit_player and player and is_instance_valid(player):
			if global_position.distance_to(player.global_position) < 50:
				player.take_damage(100)
				if player.has_method("apply_knockback"):
					player.apply_knockback(global_position, true)
				hit_player = true

	if anim_sprite:
		anim_sprite.modulate = SpriteLibrary.RANK_TINT.get("boss", Color.WHITE)
	if is_instance_valid(warning):
		warning.queue_free()

	_casting = false

## 腐化号令：召唤强化怪
func _skill_corruption_call():
	_casting = true
	print("[Boss] 腐化号令！召唤援军")

	# 无敌1秒
	set_collision_layer_value(1, false)
	if anim_sprite:
		anim_sprite.modulate = Color(0.8, 0.3, 0.8)

	# 号角特效
	EffectSprite.spawn(get_parent(), "dark", global_position, 3.0)
	AudioManager.play("attack")

	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self):
		return

	# 召唤2熊+3斥候（强化版）
	for i in range(5):
		var minion_type = "bear" if i < 2 else "scout"
		_spawn_minion(minion_type)

	# 恢复
	set_collision_layer_value(1, true)
	if anim_sprite:
		anim_sprite.modulate = SpriteLibrary.RANK_TINT.get("boss", Color.WHITE)

	_casting = false
