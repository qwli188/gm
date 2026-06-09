extends Node
## 副本流程管理器 - 阶段2流程系统
## 职责: 波次生成、Boss登场、地形互动

signal wave_started(wave_index: int)
signal wave_cleared(wave_index: int)
signal boss_spawned()
signal dungeon_completed()

# 当前副本状态
var current_dungeon_id: String = ""
var current_wave: int = -1
var waves: Array = []
var enemies_alive: Array = []
var _boss_active: bool = false
var dungeon_active: bool = false

# 场景引用
var player: Node2D = null
var dungeon_scene: Node2D = null

func _ready():
	# 监听敌人死亡
	pass

## 开始副本流程
func start_dungeon(dungeon_id: String, scene: Node2D, player_ref: Node2D):
	current_dungeon_id = dungeon_id
	dungeon_scene = scene
	player = player_ref
	dungeon_active = true
	_boss_active = false
	current_wave = -1
	enemies_alive.clear()

	# 加载波次配置
	waves = _load_waves(dungeon_id)

	print("[DungeonFlow] 副本开始: %s, %d波" % [dungeon_id, waves.size()])

	# 延迟3秒后开始第1波
	await get_tree().create_timer(3.0).timeout
	if dungeon_active:
		_start_next_wave()

## 加载波次配置
func _load_waves(dungeon_id: String) -> Array:
	# 从 dungeons.json 读取 wave_set
	var dungeon_data = _get_dungeon_data(dungeon_id)
	if not dungeon_data:
		push_error("[DungeonFlow] 未找到副本: %s" % dungeon_id)
		return []

	var wave_set_id = dungeon_data.get("wave_set", "")
	if wave_set_id == "":
		# 无配置，返回默认3波
		return _generate_default_waves(dungeon_data)

	# TODO: 从 wave_sets.json 读取（暂未创建）
	return _generate_default_waves(dungeon_data)

## 生成默认波次（暂无配置时使用）
func _generate_default_waves(dungeon_data: Dictionary) -> Array:
	var region = dungeon_data.get("region", "crypt")
	var result = []

	# 第1波: 4只普通小怪
	result.append({
		"enemies": [
			{"type": _get_region_minion(region), "count": 4}
		],
		"delay": 0
	})

	# 第2波: 6只普通 + 2只精英
	result.append({
		"enemies": [
			{"type": _get_region_minion(region), "count": 6},
			{"type": _get_region_elite(region), "count": 2}
		],
		"delay": 15
	})

	# 第3波: 8只普通 + 1只精英
	result.append({
		"enemies": [
			{"type": _get_region_minion(region), "count": 8},
			{"type": _get_region_elite(region), "count": 1}
		],
		"delay": 20
	})

	return result

## 开始下一波
func _start_next_wave():
	current_wave += 1

	if current_wave >= waves.size():
		# 所有波次完成，生成Boss
		_spawn_boss()
		return

	var wave = waves[current_wave]
	print("[DungeonFlow] 第%d波开始" % (current_wave + 1))
	wave_started.emit(current_wave)

	# 生成敌人
	for enemy_config in wave.get("enemies", []):
		var enemy_type = enemy_config.get("type", "enemy_skeleton")
		var count = enemy_config.get("count", 1)
		for i in range(count):
			_spawn_enemy(enemy_type)

	# 波次提示由HUD通过wave_started信号处理（无需直接调用）

## 生成敌人
func _spawn_enemy(enemy_type: String):
	if not dungeon_scene or not player:
		return

	# 加载敌人数据
	var enemy_data = ConfigLoader.get_enemy_by_id(enemy_type)
	if not enemy_data:
		push_error("[DungeonFlow] 未找到敌人: %s" % enemy_type)
		return

	# 创建敌人实例
	var enemy_scene = preload("res://scenes/Enemy.tscn")
	var enemy = enemy_scene.instantiate()

	# 设置属性
	enemy.enemy_id = enemy_type
	enemy.enemy_data = enemy_data

	# 随机位置（玩家周围200-400范围）
	var angle = randf() * TAU
	var distance = randf_range(200, 400)
	var spawn_pos = player.global_position + Vector2(cos(angle), sin(angle)) * distance
	enemy.global_position = spawn_pos

	dungeon_scene.add_child(enemy)
	enemies_alive.append(enemy)

	# 监听死亡
	enemy.tree_exited.connect(_on_enemy_died.bind(enemy))

## 敌人死亡回调
func _on_enemy_died(enemy: Node):
	enemies_alive.erase(enemy)

	# 检查波次是否清理完毕
	if enemies_alive.is_empty() and not _boss_active:
		_on_wave_cleared()

## 波次清理
func _on_wave_cleared():
	print("[DungeonFlow] 第%d波清理完毕" % (current_wave + 1))
	wave_cleared.emit(current_wave)

	# 等待延迟后开始下一波
	var next_wave_delay = 10.0
	if current_wave + 1 < waves.size():
		next_wave_delay = waves[current_wave + 1].get("delay", 10.0)

	await get_tree().create_timer(next_wave_delay).timeout
	if dungeon_active:
		_start_next_wave()

## 生成Boss
func _spawn_boss():
	print("[DungeonFlow] Boss登场！")
	_boss_active = true
	boss_spawned.emit()

	var dungeon_data = _get_dungeon_data(current_dungeon_id)
	if not dungeon_data:
		return

	# 获取Boss ID（根据区域推断）
	var region = dungeon_data.get("region", "crypt")
	var boss_id = _get_region_boss(region)

	# 加载Boss数据
	var boss_data = ConfigLoader.get_enemy_by_id(boss_id)
	if not boss_data:
		push_error("[DungeonFlow] 未找到Boss: %s" % boss_id)
		return

	# 创建Boss实例
	var enemy_scene = preload("res://scenes/Enemy.tscn")
	var boss = enemy_scene.instantiate()
	boss.enemy_id = boss_id
	boss.enemy_data = boss_data

	# Boss出现位置（玩家前方300距离）
	var boss_pos = player.global_position + Vector2(300, 0)
	boss.global_position = boss_pos

	dungeon_scene.add_child(boss)
	enemies_alive.append(boss)

	# Boss登场动画（简化版）
	_play_boss_entrance(boss)

	# 监听Boss死亡
	boss.tree_exited.connect(_on_boss_died)

## Boss登场动画
func _play_boss_entrance(boss: Node2D):
	# 简单缩放动画
	boss.scale = Vector2(0.1, 0.1)
	var tween = boss.create_tween()
	tween.tween_property(boss, "scale", Vector2(1.5, 1.5), 0.5)
	tween.tween_property(boss, "scale", Vector2(1.0, 1.0), 0.2)

## Boss死亡
func _on_boss_died():
	print("[DungeonFlow] Boss被击败！副本完成")
	dungeon_completed.emit()
	dungeon_active = false

	# 3秒后返回城镇
	await get_tree().create_timer(3.0).timeout
	if has_node("/root/GameState"):
		GameState.return_to_town()

## 获取副本数据
func _get_dungeon_data(dungeon_id: String) -> Dictionary:
	var all_dungeons = ConfigLoader.get_all_dungeons()
	for dg in all_dungeons:
		if dg.get("id", "") == dungeon_id:
			return dg
	return {}

## 区域对应的小怪类型
func _get_region_minion(region: String) -> String:
	var map = {
		"crypt": "enemy_skeleton",
		"forge": "enemy_fire_elemental",
		"ice": "enemy_frost_drake",
		"swamp": "enemy_toxic_frog",
		"void": "enemy_void_spawn",
		"field": "enemy_cultist_scout",
		"chaos": "enemy_chaos_aberration"
	}
	return map.get(region, "enemy_skeleton")

## 区域对应的精英怪
func _get_region_elite(region: String) -> String:
	var map = {
		"crypt": "enemy_skeleton_knight",
		"forge": "enemy_lava_golem",
		"ice": "enemy_ice_knight",
		"swamp": "enemy_swamp_titan",
		"void": "enemy_void_watcher",
		"field": "enemy_cultist_berserker",
		"chaos": "enemy_chaos_lord"
	}
	return map.get(region, "enemy_skeleton_knight")

## 区域对应的Boss
func _get_region_boss(region: String) -> String:
	var map = {
		"crypt": "boss_lich_lord",
		"forge": "boss_flame_warden",
		"ice": "boss_frost_queen",
		"swamp": "boss_plague_spawn",
		"void": "boss_void_walker",
		"field": "boss_abyss_champion",
		"chaos": "boss_chaos_prophet"
	}
	return map.get(region, "boss_lich_lord")

## 重置副本
func reset():
	current_dungeon_id = ""
	current_wave = -1
	waves.clear()
	enemies_alive.clear()
	_boss_active = false
	dungeon_active = false
	player = null
	dungeon_scene = null
