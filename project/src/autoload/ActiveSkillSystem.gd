extends Node
## 主动技能系统 - 管理玩家已学主动技能的自动释放
## 投射物/召唤/光环/冲刺等技能按冷却自动触发
## 配置驱动：技能效果从 skills.json 读取

# 已激活的主动技能 [{skill_data, level, cooldown_timer}]
var active_skills: Array = []
# 召唤物列表（死灵师等）
var summons: Array = []

var player: Node2D = null

func _ready():
	print("[ActiveSkillSystem] 主动技能系统初始化")

## 重置（进入新副本时）
func reset():
	active_skills.clear()
	summons.clear()
	player = null

## 注册一个主动技能（GameManager 学习技能时调用）
func register_skill(skill_data: Dictionary, level: int):
	# 已存在则升级
	for entry in active_skills:
		if entry.skill_data.get("id") == skill_data.get("id"):
			entry.level = level
			return
	active_skills.append({
		"skill_data": skill_data,
		"level": level,
		"cooldown_timer": 0.0
	})
	print("[ActiveSkillSystem] 注册主动技能: %s Lv.%d" % [skill_data.get("display_name", "?"), level])

func _physics_process(delta):
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group("player")
		if player == null:
			return

	# 自动技能系统（原有）
	for entry in active_skills:
		entry.cooldown_timer -= delta
		if entry.cooldown_timer <= 0.0:
			_cast_skill(entry)

	# 手动技能CD更新（阶段1新增）
	_update_manual_cooldowns(delta)

## 释放技能
func _cast_skill(entry: Dictionary):
	var skill = entry.skill_data
	var level = entry.level
	var effect = skill.get("effect", {})
	var kind = effect.get("kind", "")
	var cooldown = effect.get("cooldown", 3.0)

	match kind:
		"projectile":
			_cast_projectile(effect, level)
		"melee_swing":
			_cast_melee_swing(effect, level)
		"summon":
			_cast_summon(effect, level)
		"aura":
			# 光环是持续的，首次释放后常驻，冷却设长
			_cast_aura(effect, level)
			cooldown = 999999.0
		_:
			# 被动类不在这里处理
			cooldown = 999999.0

	entry.cooldown_timer = cooldown

## 投射物技能（火球等）
func _cast_projectile(effect: Dictionary, level: int):
	var count = effect.get("projectile_count", 1)
	# 等级追加投射物
	var scaling = _get_scaling_for_level(effect, level)
	var dmg = effect.get("base_damage", 15) + scaling
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		return
	# 朝最近的敌人发射
	var target = _nearest_enemy()
	if target == null:
		return
	# 直接对目标及附近造成伤害（简化投射物为即时命中）
	var dir = (target.global_position - player.global_position).normalized()
	for i in range(count):
		_spawn_projectile(player.global_position, dir.rotated((i - count/2.0) * 0.15), dmg, effect.get("damage_type", "physical"))

## 生成投射物视觉+命中判定
func _spawn_projectile(pos: Vector2, dir: Vector2, dmg: float, dtype: String):
	var proj = Area2D.new()
	var visual = ColorRect.new()
	visual.size = Vector2(12, 12)
	visual.position = Vector2(-6, -6)
	visual.color = _damage_type_color(dtype)
	proj.add_child(visual)
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8
	col.shape = shape
	proj.add_child(col)
	proj.global_position = pos
	proj.set_meta("dir", dir)
	proj.set_meta("dmg", dmg)
	proj.set_meta("life", 1.5)
	proj.set_script(_projectile_script())
	var scene = get_tree().current_scene
	if scene:
		scene.add_child(proj)

## 内联投射物脚本
func _projectile_script() -> GDScript:
	var src = """
extends Area2D
func _ready():
	body_entered.connect(_on_hit)
	area_entered.connect(func(a): pass)
func _physics_process(delta):
	var dir = get_meta(\"dir\")
	global_position += dir * 500 * delta
	var life = get_meta(\"life\") - delta
	set_meta(\"life\", life)
	if life <= 0:
		queue_free()
	for body in get_overlapping_bodies():
		_on_hit(body)
func _on_hit(body):
	if body.is_in_group(\"enemy\") and body.has_method(\"take_damage\"):
		body.take_damage(get_meta(\"dmg\"))
		queue_free()
"""
	var gd = GDScript.new()
	gd.source_code = src
	gd.reload()
	return gd

## 近战 AOE（旋风斩）
func _cast_melee_swing(effect: Dictionary, level: int):
	var scaling = _get_scaling_for_level(effect, level)
	var dmg = effect.get("damage", 20) + scaling
	var radius = effect.get("radius", 120)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy):
			continue
		if player.global_position.distance_to(enemy.global_position) <= radius:
			if enemy.has_method("take_damage"):
				enemy.take_damage(dmg)

## 召唤技能（死灵师骷髅）
func _cast_summon(effect: Dictionary, level: int):
	var max_count = effect.get("count", 1) + int(level / 2)
	# 清理失效召唤物
	summons = summons.filter(func(s): return is_instance_valid(s))
	if summons.size() >= max_count:
		return
	var minion = _create_minion(effect)
	if minion:
		var scene = get_tree().current_scene
		if scene:
			scene.add_child(minion)
			minion.global_position = player.global_position + Vector2(randf_range(-40,40), randf_range(-40,40))
			summons.append(minion)

## 创建召唤物（简化的友方单位）
func _create_minion(effect: Dictionary) -> Node2D:
	var minion = CharacterBody2D.new()
	minion.add_to_group("minion")
	var visual = ColorRect.new()
	visual.size = Vector2(20, 20)
	visual.position = Vector2(-10, -10)
	visual.color = Color(0.6, 0.9, 0.6, 0.9)
	minion.add_child(visual)
	minion.set_meta("damage", effect.get("minion_damage", 10))
	minion.set_meta("life", effect.get("duration", 15.0))
	minion.set_script(_minion_script())
	return minion

func _minion_script() -> GDScript:
	var src = """
extends CharacterBody2D
var attack_cd = 0.0
func _physics_process(delta):
	var life = get_meta(\"life\") - delta
	set_meta(\"life\", life)
	if life <= 0:
		queue_free()
		return
	attack_cd -= delta
	var target = _nearest_enemy()
	if target == null:
		return
	var dist = global_position.distance_to(target.global_position)
	if dist > 40:
		var dir = (target.global_position - global_position).normalized()
		velocity = dir * 180
		move_and_slide()
	elif attack_cd <= 0:
		if target.has_method(\"take_damage\"):
			target.take_damage(get_meta(\"damage\"))
		attack_cd = 1.0
func _nearest_enemy():
	var nearest = null
	var min_d = 99999.0
	for e in get_tree().get_nodes_in_group(\"enemy\"):
		if not is_instance_valid(e):
			continue
		var d = global_position.distance_to(e.global_position)
		if d < min_d:
			min_d = d
			nearest = e
	return nearest
"""
	var gd = GDScript.new()
	gd.source_code = src
	gd.reload()
	return gd

## 光环技能（持续范围效果）
func _cast_aura(effect: Dictionary, level: int):
	# 光环作为玩家子节点常驻
	if player.has_node("SkillAura"):
		return
	var aura = Area2D.new()
	aura.name = "SkillAura"
	var visual = ColorRect.new()
	var r = effect.get("radius", 100)
	visual.size = Vector2(r*2, r*2)
	visual.position = Vector2(-r, -r)
	visual.color = Color(_damage_type_color(effect.get("damage_type","physical")), 0.15)
	aura.add_child(visual)
	aura.set_meta("tick_damage", effect.get("tick_damage", 5))
	aura.set_meta("radius", r)
	aura.set_meta("tick_timer", 0.0)
	aura.set_script(_aura_script())
	player.add_child(aura)

func _aura_script() -> GDScript:
	var src = """
extends Area2D
func _physics_process(delta):
	var t = get_meta(\"tick_timer\") - delta
	if t <= 0:
		t = 0.5
		var r = get_meta(\"radius\")
		for e in get_tree().get_nodes_in_group(\"enemy\"):
			if is_instance_valid(e) and global_position.distance_to(e.global_position) <= r:
				if e.has_method(\"take_damage\"):
					e.take_damage(get_meta(\"tick_damage\"))
	set_meta(\"tick_timer\", t)
"""
	var gd = GDScript.new()
	gd.source_code = src
	gd.reload()
	return gd

## ============ 工具方法 ============
func _nearest_enemy() -> Node2D:
	var nearest = null
	var min_d = 99999.0
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e):
			continue
		var d = player.global_position.distance_to(e.global_position)
		if d < min_d:
			min_d = d
			nearest = e
	return nearest

func _get_scaling_for_level(effect: Dictionary, level: int) -> float:
	return (level - 1) * effect.get("damage_per_level", 5)

func _damage_type_color(dtype: String) -> Color:
	match dtype:
		"fire": return Color(1.0, 0.4, 0.1)
		"frost", "ice": return Color(0.4, 0.7, 1.0)
		"poison": return Color(0.4, 0.9, 0.2)
		"void": return Color(0.6, 0.2, 0.8)
		"holy": return Color(1.0, 0.95, 0.6)
		_: return Color(0.9, 0.9, 0.9)


# ============================================================
# 阶段1: 手动技能系统 (模块4扩展)
# ============================================================

# 手动技能槽位 [skill_id_1, skill_id_2, skill_id_3]
var manual_skills: Array = ["", "", ""]
# 手动技能CD状态 {skill_id: cooldown_remaining}
var manual_cooldowns: Dictionary = {}

## 装备技能到槽位
func equip_manual_skill(slot_index: int, skill_id: String):
	"""装备技能到槽位0/1/2 (对应快捷键1/2/3)"""
	if slot_index < 0 or slot_index >= 3:
		push_error("[ActiveSkillSystem] 无效的槽位:", slot_index)
		return
	
	manual_skills[slot_index] = skill_id
	print("[ActiveSkillSystem] 槽位%d装备技能: %s" % [slot_index + 1, skill_id])

## 激活手动技能
func activate_manual_skill(slot_index: int) -> bool:
	"""玩家按1/2/3键时调用"""
	if slot_index < 0 or slot_index >= 3:
		return false
	
	var skill_id = manual_skills[slot_index]
	if skill_id == "":
		print("[ActiveSkillSystem] 槽位%d未装备技能" % (slot_index + 1))
		return false
	
	# 检查CD
	var cd = manual_cooldowns.get(skill_id, 0.0)
	if cd > 0:
		print("[ActiveSkillSystem] 技能CD中: %.1fs" % cd)
		return false
	
	# 读取技能数据
	var skill_data = _get_skill_data(skill_id)
	if skill_data.is_empty():
		push_error("[ActiveSkillSystem] 未找到技能:", skill_id)
		return false
	
	# 检查资源消耗
	if not _check_resource_cost(skill_data):
		print("[ActiveSkillSystem] 资源不足")
		return false
	
	# 释放技能
	_execute_manual_skill(skill_data)
	
	# 启动CD
	var cooldown = skill_data.get("cooldown", 5.0)
	manual_cooldowns[skill_id] = cooldown
	
	return true

## 更新手动技能CD
func _update_manual_cooldowns(delta: float):
	for skill_id in manual_cooldowns.keys():
		if manual_cooldowns[skill_id] > 0:
			manual_cooldowns[skill_id] -= delta
			if manual_cooldowns[skill_id] < 0:
				manual_cooldowns[skill_id] = 0

## 执行手动技能
func _execute_manual_skill(skill_data: Dictionary):
	var effect = skill_data.get("effect", {})
	var kind = effect.get("kind", "")

	match kind:
		"dash":
			_cast_dash(effect)
		"aoe":
			_cast_aoe(effect)
		"buff":
			_cast_buff(effect)
		"summon":
			_cast_summon_manual(effect)
		"channel":
			_cast_channel(effect)
		"projectile":
			_cast_projectile_manual(effect)
		"aura":
			_cast_aura_manual(effect)
		_:
			push_error("[ActiveSkillSystem] 未知的技能类型:", kind)

## 检查资源消耗
func _check_resource_cost(skill_data: Dictionary) -> bool:
	var cost = skill_data.get("resource_cost", {})
	if cost.is_empty():
		return true
	
	var type = cost.get("type", "")
	var amount = cost.get("amount", 0)
	
	# 检查职业资源（怒气/法力/能量等）
	if has_node("/root/ClassMechanicSystem"):
		var cms = get_node("/root/ClassMechanicSystem")
		match type:
			"rage":
				return cms.rage >= amount
			"mana":
				return cms.mana >= amount
			"energy":
				return true  # 刺客能量暂无实现
			_:
				return true
	
	return true

## 消耗资源
func _consume_resource(skill_data: Dictionary):
	var cost = skill_data.get("resource_cost", {})
	if cost.is_empty():
		return
	
	var type = cost.get("type", "")
	var amount = cost.get("amount", 0)
	
	if has_node("/root/ClassMechanicSystem"):
		var cms = get_node("/root/ClassMechanicSystem")
		match type:
			"rage":
				cms.rage -= amount
				cms.rage_changed.emit(cms.rage, cms.rage_max)
			"mana":
				cms.mana -= amount
				cms.mana_changed.emit(cms.mana, cms.mana_max)

## 获取技能数据
func _get_skill_data(skill_id: String) -> Dictionary:
	var all_skills = ConfigLoader.get_all_skills()
	for s in all_skills:
		if s.get("id") == skill_id:
			return s
	return {}

# ────────────────────────────────────────────────────────────
# 5种effect类型实现
# ────────────────────────────────────────────────────────────

## dash: 冲刺位移
func _cast_dash(effect: Dictionary):
	if not player:
		return
	
	var distance = effect.get("distance", 300)
	var damage = effect.get("damage", 25)
	
	# 获取朝向（鼠标方向或移动方向）
	var direction = Vector2.RIGHT  # 默认右
	if player.has_method("get_facing_direction"):
		direction = player.get_facing_direction()
	else:
		# 简化：根据上次移动方向
		var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_dir.length() > 0:
			direction = input_dir.normalized()
	
	# 冲刺目标位置
	var target_pos = player.global_position + direction * distance
	
	# Tween冲刺（0.2秒）
	var tween = player.create_tween()
	tween.tween_property(player, "global_position", target_pos, 0.2)
	
	# 冲刺路径上的敌人受到伤害
	var enemies = get_tree().get_nodes_in_group("enemy")
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var to_enemy = e.global_position - player.global_position
		if to_enemy.dot(direction) > 0 and to_enemy.length() < distance + 50:
			if e.has_method("take_damage"):
				e.take_damage(damage, false)
	
	# 特效
	EffectSprite.spawn(player.get_parent(), "slash", player.global_position + direction * distance / 2, 1.5)
	AudioManager.play("attack")
	
	print("[Skill] 冲刺释放: 距离%d, 伤害%d" % [distance, damage])

## aoe: 范围伤害
func _cast_aoe(effect: Dictionary):
	if not player:
		return
	
	var radius = effect.get("radius", 150)
	var damage = effect.get("damage", 40)
	var damage_type = effect.get("damage_type", "physical")
	
	# AOE判定（玩家周围）
	var enemies = get_tree().get_nodes_in_group("enemy")
	var hit_count = 0
	for e in enemies:
		if not is_instance_valid(e):
			continue
		if e.global_position.distance_to(player.global_position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(damage, false)
				hit_count += 1
	
	# 特效
	var effect_name = "fire" if damage_type == "fire" else "frost" if damage_type == "frost" else "hit"
	EffectSprite.spawn(player.get_parent(), effect_name, player.global_position, radius / 75.0)
	AudioManager.play("attack")
	
	print("[Skill] AOE释放: 半径%d, 命中%d个敌人" % [radius, hit_count])

## buff: 增益状态
func _cast_buff(effect: Dictionary):
	if not player:
		return
	
	var buff_type = effect.get("buff_type", "damage")
	var buff_value = effect.get("buff_value", 0.2)
	var duration = effect.get("duration", 5.0)
	
	# TODO: 需要扩展Player.gd的buff系统
	# 当前简化实现：直接修改属性，不支持自动恢复
	print("[Skill] Buff释放: %s +%.1f%%持续%.1fs (待实现buff系统)" % [buff_type, buff_value * 100, duration])
	
	# 特效
	EffectSprite.spawn(player.get_parent(), "holy", player.global_position, 1.8)

## summon: 召唤物（手动版本）
func _cast_summon_manual(effect: Dictionary):
	# 复用现有_cast_summon逻辑
	_cast_summon({"effect": effect}, 1)

## channel: 持续施法
func _cast_channel(effect: Dictionary):
	print("[Skill] 持续施法技能 - 待实现")
	# 需要特殊的输入锁定+持续伤害系统

## projectile: 发射投射物（手动版 - 由 1/2/3 键触发）
func _cast_projectile_manual(effect: Dictionary):
	if not player:
		return

	var projectile_count = effect.get("projectile_count", 1)
	var damage = effect.get("damage", 30)
	var speed = effect.get("speed", 400)
	var pierce = effect.get("pierce", false)
	var damage_type = effect.get("damage_type", "physical")

	# 获取射击方向（朝向最近敌人）
	var nearest = _nearest_enemy()
	var direction = Vector2.RIGHT
	if nearest:
		direction = (nearest.global_position - player.global_position).normalized()
	else:
		# 无敌人时朝向鼠标或默认右
		var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if input_dir.length() > 0:
			direction = input_dir.normalized()

	# 发射多个投射物（扇形分布）
	var angle_spread = 0.3 if projectile_count > 1 else 0.0
	for i in range(projectile_count):
		var offset_angle = 0.0
		if projectile_count > 1:
			offset_angle = -angle_spread / 2 + (angle_spread / (projectile_count - 1)) * i

		var proj_dir = direction.rotated(offset_angle)
		_spawn_projectile_manual(proj_dir, damage, speed, pierce, damage_type)

	# 特效
	AudioManager.play("attack")
	print("[Skill] 投射物释放: %d发, 伤害%d" % [projectile_count, damage])

## 生成投射物实体（手动版）
func _spawn_projectile_manual(direction: Vector2, damage: float, speed: float, pierce: bool, dtype: String):
	var projectile = Area2D.new()
	projectile.global_position = player.global_position
	projectile.name = "Projectile"

	# 视觉（简单圆形）
	var sprite = Sprite2D.new()
	sprite.texture = preload("res://icon.svg")  # 占位图标
	sprite.scale = Vector2(0.1, 0.1)
	sprite.modulate = _damage_type_color(dtype)
	projectile.add_child(sprite)

	# 碰撞体
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8
	collision.shape = shape
	projectile.add_child(collision)

	player.get_parent().add_child(projectile)

	# 飞行逻辑（3秒寿命或碰到敌人）
	var lifetime = 3.0
	var hit_enemies = []
	while lifetime > 0 and is_instance_valid(projectile):
		await get_tree().create_timer(0.05).timeout
		lifetime -= 0.05

		if not is_instance_valid(projectile):
			break

		# 移动
		projectile.global_position += direction * speed * 0.05

		# 碰撞检测
		var enemies = get_tree().get_nodes_in_group("enemy")
		for e in enemies:
			if not is_instance_valid(e) or e in hit_enemies:
				continue

			var distance = projectile.global_position.distance_to(e.global_position)
			if distance < 30:  # 碰撞半径
				if e.has_method("take_damage"):
					e.take_damage(damage, false)
					hit_enemies.append(e)

					if not pierce:
						# 非穿透，命中后消失
						if is_instance_valid(projectile):
							projectile.queue_free()
						return

	# 寿命到期
	if is_instance_valid(projectile):
		projectile.queue_free()

## aura: 光环效果（手动版 - 持续存在的范围buff/debuff）
func _cast_aura_manual(effect: Dictionary):
	if not player:
		return

	var radius = effect.get("radius", 200)
	var duration = effect.get("duration", 5.0)
	var aura_type = effect.get("aura_type", "damage_reduction")
	var aura_value = effect.get("aura_value", 0.3)

	# 创建光环视觉
	var aura = Node2D.new()
	aura.global_position = player.global_position
	aura.name = "Aura"

	var circle = Sprite2D.new()
	circle.texture = preload("res://icon.svg")
	circle.scale = Vector2(radius / 64.0, radius / 64.0)
	circle.modulate = Color(0.5, 0.8, 1.0, 0.3)
	aura.add_child(circle)

	player.get_parent().add_child(aura)

	# 脉冲动画
	var tween = aura.create_tween().set_loops()
	tween.tween_property(circle, "modulate:a", 0.5, 0.8)
	tween.tween_property(circle, "modulate:a", 0.2, 0.8)

	# 持续时间内应用效果
	var elapsed = 0.0
	while elapsed < duration and is_instance_valid(aura):
		await get_tree().create_timer(0.5).timeout
		elapsed += 0.5

		if not is_instance_valid(player):
			break

		# 跟随玩家
		aura.global_position = player.global_position

		# 对范围内敌人应用debuff（简化：直接造成持续伤害）
		if aura_type == "damage_over_time":
			var enemies = get_tree().get_nodes_in_group("enemy")
			for e in enemies:
				if not is_instance_valid(e):
					continue
				if e.global_position.distance_to(player.global_position) <= radius:
					if e.has_method("take_damage"):
						e.take_damage(aura_value * 0.5, false)  # 每0.5秒造成一次伤害

	# 光环结束
	if is_instance_valid(aura):
		aura.queue_free()

	print("[Skill] 光环结束: %s持续%.1fs" % [aura_type, duration])
