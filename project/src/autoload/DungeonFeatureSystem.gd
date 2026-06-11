extends Node
## DungeonFeatureSystem - 副本机制系统
## 让 feature 从文本变成真生效的代码（死亡之雾、毒池、熔岩、冰面、虚空裂隙、怪物狂潮）

# ============ 状态变量 ============
var active_feature_id: String = ""
var feature_params: Dictionary = {}
var feature_timer: float = 0.0
var feature_nodes: Array = []  # 场景中生成的机制节点(毒池/冰区/裂隙等)
var arena_scene: Node = null  # 缓存Arena场景引用

# 机制全局buff字典(供Player/Enemy读取)
var active_buffs: Dictionary = {}

# 死亡之雾状态
var _fog_active: bool = false
var _fog_remaining: float = 0.0

# 毒池生成计时
var _poison_spawn_timer: float = 0.0

# 熔岩喷发计时
var _lava_timer: float = 0.0

# 虚空裂隙计时
var _rift_timer: float = 0.0

# 怪物狂潮备份（恢复用）
var _surge_backup: Dictionary = {}


func _ready():
	print("[DungeonFeatureSystem] 初始化")


## 激活机制（进入副本时调用）
func activate_feature(feature_id: String, params: Dictionary) -> void:
	if feature_id.is_empty():
		return

	active_feature_id = feature_id
	feature_params = params
	feature_timer = 0.0
	active_buffs.clear()

	print("[DungeonFeatureSystem] 激活机制: %s" % feature_id)

	# 根据机制类型进行初始化
	match feature_id:
		"death_fog":
			_init_death_fog()
		"poison_pools":
			_init_poison_pools()
		"ice_slide":
			_init_ice_slide()
		"monster_surge":
			_init_monster_surge()


## 清理机制（退出副本时调用）
func deactivate() -> void:
	if active_feature_id.is_empty():
		return

	print("[DungeonFeatureSystem] 停用机制: %s" % active_feature_id)

	# 机制特定清理
	if active_feature_id == "death_fog":
		_cleanup_death_fog()
	elif active_feature_id == "monster_surge":
		_cleanup_monster_surge()

	# 清理所有生成的节点
	for node in feature_nodes:
		if is_instance_valid(node):
			node.queue_free()
	feature_nodes.clear()

	active_feature_id = ""
	feature_params.clear()
	feature_timer = 0.0
	active_buffs.clear()
	arena_scene = null


## 主循环更新
func _process(delta: float) -> void:
	if active_feature_id.is_empty() or not is_instance_valid(arena_scene):
		return

	feature_timer += delta

	match active_feature_id:
		"death_fog":
			_process_death_fog(delta)
		"poison_pools":
			_process_poison_pools(delta)
		"lava_eruption":
			_process_lava_eruption(delta)
		"void_rift":
			_process_void_rift(delta)


# ============================================================
# 机制1: 死亡之雾 (death_fog)
# ============================================================


func _init_death_fog():
	_fog_active = false
	_fog_remaining = 0.0


func _process_death_fog(delta: float):
	var cycle = feature_params.get("cycle_duration", 30.0)
	var fog_dur = feature_params.get("fog_duration", 8.0)
	var dps = feature_params.get("damage_per_second", 5.0)
	var crit_bonus = feature_params.get("crit_bonus", 0.5)

	if not _fog_active:
		# 等待下次触发
		if feature_timer >= cycle:
			feature_timer = 0.0
			_trigger_fog(fog_dur, crit_bonus)
	else:
		# 雾中持续伤害
		_fog_remaining -= delta
		var player = _get_player()
		if is_instance_valid(player) and player.has_method("take_damage"):
			player.take_damage(dps * delta)

		if _fog_remaining <= 0:
			_end_fog()


func _trigger_fog(duration: float, crit_bonus: float):
	_fog_active = true
	_fog_remaining = duration
	active_buffs["fog_crit_bonus"] = crit_bonus

	# 视觉: 场景变暗
	if is_instance_valid(arena_scene):
		var modulate_node = arena_scene.get_node_or_null("CanvasModulate")
		if not modulate_node:
			modulate_node = CanvasModulate.new()
			modulate_node.name = "CanvasModulate"
			arena_scene.add_child(modulate_node)
			feature_nodes.append(modulate_node)

		var tween = create_tween()
		tween.tween_property(modulate_node, "color", Color(0.4, 0.4, 0.5), 0.5)

	AudioManager.play("footstep")  # 复用音效，或后续换成"fog_start"
	print("[死亡之雾] 触发！暴击率+50%")


func _end_fog():
	_fog_active = false
	active_buffs.erase("fog_crit_bonus")

	# 恢复亮度
	if is_instance_valid(arena_scene):
		var modulate_node = arena_scene.get_node_or_null("CanvasModulate")
		if modulate_node:
			var tween = create_tween()
			tween.tween_property(modulate_node, "color", Color.WHITE, 0.5)

	print("[死亡之雾] 结束")


func _cleanup_death_fog():
	_end_fog()


# ============================================================
# 机制2: 毒池 (poison_pools)
# ============================================================


func _init_poison_pools():
	_poison_spawn_timer = 0.0
	var count = feature_params.get("pool_count", 5)
	var radius = feature_params.get("pool_radius", 80.0)

	# 初始生成
	for i in range(count):
		_spawn_poison_pool(radius)


func _process_poison_pools(delta: float):
	var interval = feature_params.get("spawn_interval", 12.0)
	var radius = feature_params.get("pool_radius", 80.0)

	_poison_spawn_timer += delta
	if _poison_spawn_timer >= interval:
		_poison_spawn_timer = 0.0
		# 限制最多8个
		if feature_nodes.size() < 8:
			_spawn_poison_pool(radius)


func _spawn_poison_pool(radius: float):
	if not is_instance_valid(arena_scene):
		return

	# 随机位置（Arena 600x400范围）
	var pos = Vector2(randf_range(-300, 300), randf_range(-200, 200))

	# 创建毒池节点
	var pool = Node2D.new()
	pool.global_position = arena_scene.global_position + pos
	pool.set_script(load("res://autoload/DungeonFeatureSystem.gd").get_script())

	# 视觉: 绿色半透明圆
	var visual = ColorRect.new()
	visual.size = Vector2(radius * 2, radius * 2)
	visual.position = -visual.size / 2.0
	visual.color = Color(0.2, 0.8, 0.3, 0.4)
	visual.z_index = -1
	pool.add_child(visual)

	# 碰撞检测
	var area = Area2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	var collision = CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)
	pool.add_child(area)

	# 周期毒伤
	var poison_dps = feature_params.get("poison_dps", 8.0)
	var poison_dur = feature_params.get("poison_duration", 3.0)
	var tick_timer = 0.0
	area.body_entered.connect(
		func(body):
			if body.is_in_group("player") and body.has_method("take_damage"):
				# 应用持续毒伤(简化实现: 直接伤害)
				body.take_damage(poison_dps * 0.5)
				if is_instance_valid(pool):
					EffectSprite.spawn(arena_scene, "poison", pool.global_position, 1.0)
	)

	arena_scene.add_child(pool)
	feature_nodes.append(pool)

	# 生成特效
	EffectSprite.spawn(arena_scene, "poison", pool.global_position, 1.2)


# ============================================================
# 机制3: 熔岩喷发 (lava_eruption)
# ============================================================


func _process_lava_eruption(delta: float):
	var interval = feature_params.get("eruption_interval", 6.0)

	_lava_timer += delta
	if _lava_timer >= interval:
		_lava_timer = 0.0
		_trigger_lava_eruption()


func _trigger_lava_eruption():
	if not is_instance_valid(arena_scene):
		return

	var radius = feature_params.get("eruption_radius", 100.0)
	var damage = feature_params.get("eruption_damage", 35.0)
	var warning_dur = feature_params.get("warning_duration", 1.5)

	# 随机位置
	var pos = arena_scene.global_position + Vector2(randf_range(-300, 300), randf_range(-200, 200))

	# 预警圈
	var warning = _create_warning_circle(pos, radius)
	arena_scene.add_child(warning)

	# 闪烁动画
	var blink = warning.create_tween().set_loops()
	blink.tween_property(warning, "modulate:a", 0.9, 0.25)
	blink.tween_property(warning, "modulate:a", 0.3, 0.25)

	# 延迟爆发
	await get_tree().create_timer(warning_dur).timeout

	if is_instance_valid(warning):
		warning.queue_free()

	# AOE伤害
	_deal_aoe_damage(pos, radius, damage)

	# 爆炸特效
	if is_instance_valid(arena_scene):
		EffectSprite.spawn(arena_scene, "fire", pos, radius / 75.0)
		AudioManager.play("hit")  # 复用音效，或后续换成"explosion"


func _create_warning_circle(pos: Vector2, radius: float) -> Node2D:
	var circle = ColorRect.new()
	circle.size = Vector2(radius * 2, radius * 2)
	circle.global_position = pos - circle.size / 2.0
	circle.color = Color(1.0, 0.2, 0.2, 0.35)
	circle.z_index = -1
	return circle


func _deal_aoe_damage(center: Vector2, radius: float, dmg: float):
	var player = _get_player()
	if is_instance_valid(player) and player.has_method("take_damage"):
		if player.global_position.distance_to(center) <= radius:
			player.take_damage(dmg)


# ============================================================
# 机制4: 冰面打滑 (ice_slide)
# ============================================================


func _init_ice_slide():
	var count = feature_params.get("ice_zone_count", 3)
	var zone_size = feature_params.get("ice_zone_size", {"x": 200, "y": 150})

	active_buffs["ice_slide_zones"] = []

	for i in range(count):
		_spawn_ice_zone(Vector2(zone_size.x, zone_size.y))


func _spawn_ice_zone(size: Vector2):
	if not is_instance_valid(arena_scene):
		return

	# 随机位置
	var pos = arena_scene.global_position + Vector2(randf_range(-250, 250), randf_range(-150, 150))

	var zone = Node2D.new()
	zone.global_position = pos

	# 视觉: 淡蓝半透明矩形
	var visual = ColorRect.new()
	visual.size = size
	visual.position = -size / 2.0
	visual.color = Color(0.6, 0.8, 1.0, 0.25)
	visual.z_index = -1
	zone.add_child(visual)

	# 碰撞区域
	var area = Area2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	var collision = CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)
	zone.add_child(area)

	arena_scene.add_child(zone)
	feature_nodes.append(zone)
	active_buffs["ice_slide_zones"].append(area)

	# 特效
	EffectSprite.spawn(arena_scene, "frost", pos, 1.0)


# ============================================================
# 机制5: 虚空裂隙 (void_rift)
# ============================================================


func _process_void_rift(delta: float):
	var interval = feature_params.get("rift_spawn_interval", 20.0)

	_rift_timer += delta
	if _rift_timer >= interval:
		_rift_timer = 0.0
		_spawn_void_rift()


func _spawn_void_rift():
	if not is_instance_valid(arena_scene):
		return

	var radius = feature_params.get("teleport_radius", 250.0)
	var duration = feature_params.get("rift_duration", 5.0)
	var elite_count = feature_params.get("elite_spawn_count", 2)

	# 随机位置
	var pos = arena_scene.global_position + Vector2(randf_range(-300, 300), randf_range(-200, 200))

	var rift = Node2D.new()
	rift.global_position = pos

	# 视觉: 紫色漩涡
	var visual = ColorRect.new()
	visual.size = Vector2(80, 80)
	visual.position = -visual.size / 2.0
	visual.color = Color(0.5, 0.2, 0.8, 0.6)
	visual.z_index = -1
	rift.add_child(visual)

	# 碰撞检测传送
	var area = Area2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 40
	var collision = CollisionShape2D.new()
	collision.shape = shape
	area.add_child(collision)
	rift.add_child(area)

	area.body_entered.connect(
		func(body):
			if body.is_in_group("player"):
				_teleport_player(body, pos, radius)
	)

	arena_scene.add_child(rift)
	feature_nodes.append(rift)

	# 周围特效
	EffectSprite.spawn(arena_scene, "frost", pos, 1.5)

	# 召唤精英
	_spawn_void_elites(pos, elite_count)

	# 持续时间后消失
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(rift):
		rift.queue_free()
		feature_nodes.erase(rift)


func _teleport_player(player: Node2D, _rift_pos: Vector2, max_dist: float):
	if not is_instance_valid(arena_scene):
		return

	# 传送前特效
	EffectSprite.spawn(arena_scene, "frost", player.global_position, 1.2)

	# 随机新位置
	var offset = Vector2(
		randf_range(-max_dist, max_dist), randf_range(-max_dist * 0.7, max_dist * 0.7)
	)
	player.global_position = arena_scene.global_position + offset

	# 传送后特效
	EffectSprite.spawn(arena_scene, "frost", player.global_position, 1.2)
	AudioManager.play("footstep")


func _spawn_void_elites(pos: Vector2, count: int):
	if not is_instance_valid(arena_scene):
		return

	# 从当前waveset获取精英池(简化: 随机生成基础敌人)
	var waveset_id = ""
	if has_node("/root/GameState"):
		waveset_id = get_node("/root/GameState").selected_waveset

	for i in range(count):
		var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
		var spawn_pos = pos + offset

		# 简化实现: 直接创建默认敌人(实际应从配置读取)
		var enemy_script = load("res://scripts/Enemy.gd")
		if enemy_script and enemy_script.has_method("create_enemy"):
			var enemy = enemy_script.create_enemy("enemy_skeleton", spawn_pos)
			if enemy:
				arena_scene.add_child(enemy)
				EffectSprite.spawn(arena_scene, "frost", spawn_pos, 1.0)


# ============================================================
# 机制6: 怪物狂潮 (monster_surge)
# ============================================================


func _init_monster_surge():
	var spawn_mult = feature_params.get("spawn_rate_multiplier", 2.0)
	var density = feature_params.get("density_bonus", 1.5)
	var loot_mult = feature_params.get("loot_drop_mult", 1.2)

	active_buffs["monster_surge_loot_mult"] = loot_mult

	# 场景变红调(紧张氛围)
	if is_instance_valid(arena_scene):
		var modulate_node = arena_scene.get_node_or_null("CanvasModulate")
		if not modulate_node:
			modulate_node = CanvasModulate.new()
			modulate_node.name = "CanvasModulate"
			arena_scene.add_child(modulate_node)
			feature_nodes.append(modulate_node)
		modulate_node.color = Color(1.1, 0.95, 0.95)

	print("[怪物狂潮] 刷怪密度x%.1f，掉落率x%.1f" % [density, loot_mult])


func _cleanup_monster_surge():
	# 恢复颜色
	if is_instance_valid(arena_scene):
		var modulate_node = arena_scene.get_node_or_null("CanvasModulate")
		if modulate_node:
			modulate_node.color = Color.WHITE


# ============================================================
# 辅助方法
# ============================================================


func _get_player() -> Node2D:
	var player = get_tree().get_first_node_in_group("player")
	if is_instance_valid(player):
		return player
	return null


func _get_enemies() -> Array:
	return get_tree().get_nodes_in_group("enemy")


func set_arena(arena: Node):
	arena_scene = arena
