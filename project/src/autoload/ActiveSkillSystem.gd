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

	for entry in active_skills:
		entry.cooldown_timer -= delta
		if entry.cooldown_timer <= 0.0:
			_cast_skill(entry)

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
