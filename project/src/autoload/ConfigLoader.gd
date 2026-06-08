extends Node
## 配置表加载器 - 从 JSON 文件加载游戏配置
## 这是配置表驱动架构的核心：所有游戏内容从配置读取，不写死在代码里

# 热重载信号
signal config_reloaded(file_name: String)
signal all_configs_reloaded()

# 配置数据缓存
var equipment_data: Dictionary = {}
var affixes_data: Dictionary = {}
var skills_data: Dictionary = {}
var enemies_data: Dictionary = {}
var balance_data: Dictionary = {}
var dungeons_data: Dictionary = {}
var waves_data: Dictionary = {}
var classes_data: Dictionary = {}
var sets_data: Dictionary = {}
var vfx_data: Dictionary = {}

# 配置文件路径（相对于项目根目录）
const CONFIG_DIR = "res://config/"

func _ready():
	print("[ConfigLoader] 开始加载配置表...")
	load_all_configs()
	print("[ConfigLoader] 配置表加载完成")

## 加载所有配置表
func load_all_configs():
	equipment_data = load_json_config("equipment.json")
	affixes_data = load_json_config("affixes.json")
	skills_data = load_json_config("skills.json")
	enemies_data = load_json_config("enemies.json")
	balance_data = load_json_config("balance.json")
	dungeons_data = load_json_config("dungeons.json")
	waves_data = load_json_config("waves.json")
	classes_data = load_json_config("classes.json")
	sets_data = load_json_config("sets.json")
	vfx_data = load_json_config("vfx.json")

## 加载单个 JSON 配置文件
func load_json_config(filename: String) -> Dictionary:
	var path = CONFIG_DIR + filename

	# 检查文件是否存在
	if not FileAccess.file_exists(path):
		push_error("[ConfigLoader] 配置文件不存在: %s" % path)
		return {}

	# 读取文件
	var file = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[ConfigLoader] 无法打开配置文件: %s (错误码: %d)" % [path, FileAccess.get_open_error()])
		return {}

	var content = file.get_as_text()
	file.close()

	# 解析 JSON
	var json = JSON.new()
	var error = json.parse(content)

	if error != OK:
		push_error("[ConfigLoader] JSON 解析错误: %s (行 %d: %s)" % [path, json.get_error_line(), json.get_error_message()])
		return {}

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("[ConfigLoader] JSON 根节点必须是对象(Dictionary): %s" % path)
		return {}

	print("[ConfigLoader] 成功加载: %s" % filename)
	return data

## 根据 id 查找词缀
func get_affix_by_id(id: String) -> Dictionary:
	if not affixes_data.has("affixes"):
		return {}

	for affix in affixes_data.get("affixes", []):
		if affix.get("id", "") == id:
			return affix

	return {}

## 根据 id 查找敌人
func get_enemy_by_id(id: String) -> Dictionary:
	if not enemies_data.has("enemies"):
		return {}

	for enemy in enemies_data.get("enemies", []):
		if enemy.get("id", "") == id:
			return enemy

	return {}

## 获取数值平衡参数
func get_balance_param(key: String, default_value = null):
	return balance_data.get(key, default_value)

## 获取所有装备列表（8部位全合并）
func get_all_equipment() -> Array:
	var result = []
	# 新结构：统一 items 数组
	result.append_array(equipment_data.get("items", []))
	# 兼容旧结构：分类数组
	result.append_array(equipment_data.get("weapons", []))
	result.append_array(equipment_data.get("armor", []))
	result.append_array(equipment_data.get("trinkets", []))
	return result

## 获取所有词缀列表
func get_all_affixes() -> Array:
	return affixes_data.get("affixes", [])

## 根据 id 查找装备（武器/护甲/饰品全找）
func get_equipment_by_id(id: String) -> Dictionary:
	for item in get_all_equipment():
		if item.get("id", "") == id:
			return item
	return {}

## 根据 id 查找职业
func get_class_by_id(id: String) -> Dictionary:
	for c in classes_data.get("classes", []):
		if c.get("id", "") == id:
			return c
	return {}

## 获取所有职业
func get_all_classes() -> Array:
	return classes_data.get("classes", [])

## 根据 id 查找套装
func get_set_by_id(id: String) -> Dictionary:
	for s in sets_data.get("sets", []):
		if s.get("id", "") == id:
			return s
	return {}

## 获取所有套装
func get_all_sets() -> Array:
	return sets_data.get("sets", [])

## 根据 id 查找技能
func get_skill_by_id(id: String) -> Dictionary:
	for s in skills_data.get("skills", []):
		if s.get("id", "") == id:
			return s
	return {}

## 获取某职业可用的技能（class 字段匹配或 "all" 通用）
func get_skills_for_class(class_id: String) -> Array:
	var result = []
	for s in skills_data.get("skills", []):
		var cls = s.get("class", "all")
		if cls == "all" or cls == class_id:
			result.append(s)
	return result

## 根据 id 查找副本
func get_dungeon_by_id(id: String) -> Dictionary:
	for d in dungeons_data.get("dungeons", []):
		if d.get("id", "") == id:
			return d
	return {}

## 获取所有副本
func get_all_dungeons() -> Array:
	return dungeons_data.get("dungeons", [])

## 获取稀有度特效配置
func get_vfx_for_rarity(rarity: String) -> Dictionary:
	return vfx_data.get("rarity_vfx", {}).get(rarity, {})

## 热重载单个配置文件
func reload_config(file_name: String) -> bool:
	var path = "res://config/" + file_name
	if not ResourceLoader.exists(path):
		push_error("[ConfigLoader] 文件不存在: " + path)
		return false
	var data = load_json_config(file_name)
	if data.is_empty():
		return false
	match file_name:
		"equipment.json": equipment_data = data
		"affixes.json": affixes_data = data
		"skills.json": skills_data = data
		"enemies.json": enemies_data = data
		"classes.json": classes_data = data
		"dungeons.json": dungeons_data = data
		"waves.json": waves_data = data
		"sets.json": sets_data = data
		"balance.json": balance_data = data
		"vfx.json": vfx_data = data
		_:
			push_warning("[ConfigLoader] 未知配置: " + file_name)
			return false
	print("[ConfigLoader] 热重载: " + file_name)
	config_reloaded.emit(file_name)
	return true

## 热重载所有配置文件
func reload_all() -> void:
	load_all_configs()
	all_configs_reloaded.emit()
	print("[ConfigLoader] 全部配置已重载")
