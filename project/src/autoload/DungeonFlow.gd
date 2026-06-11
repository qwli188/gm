extends Node
## 副本地形管理器 - 阶段A2/C
## 职责: 仅负责地形生成与互动元素
## 刷怪由现有 EnemySpawner 负责（时间流式，已对接GameState/难度/Boss burst）

signal terrain_generated(region: String)

var current_dungeon_id: String = ""
var dungeon_scene: Node2D = null
var terrain_node: Node2D = null


## 开始副本地形生成（MainScene._ready调用）
func start_dungeon(dungeon_id: String, scene: Node2D, _player_ref: Node2D):
	current_dungeon_id = dungeon_id
	dungeon_scene = scene

	_generate_terrain(dungeon_id)

	print("[DungeonFlow] 地形生成: %s" % dungeon_id)


## 生成副本地形
func _generate_terrain(dungeon_id: String):
	var dungeon_data = _get_dungeon_data(dungeon_id)
	if not dungeon_data or not dungeon_scene:
		return

	var region = dungeon_data.get("region", "crypt")

	# 创建地形生成器节点
	var terrain_script = load("res://scripts/DungeonTerrain.gd")
	terrain_node = terrain_script.new()
	terrain_node.name = "DungeonTerrain"
	dungeon_scene.add_child(terrain_node)
	terrain_node.generate_terrain(region, dungeon_scene)

	terrain_generated.emit(region)


## 获取副本数据
func _get_dungeon_data(dungeon_id: String) -> Dictionary:
	var all_dungeons = ConfigLoader.get_all_dungeons()
	for dg in all_dungeons:
		if dg.get("id", "") == dungeon_id:
			return dg
	return {}


## 重置
func reset():
	current_dungeon_id = ""
	dungeon_scene = null
	if is_instance_valid(terrain_node):
		terrain_node.queue_free()
	terrain_node = null
