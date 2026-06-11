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
var territory_data: Dictionary = {}

# O(1) 查找索引（id -> 数据字典）
var _equipment_index: Dictionary = {}
var _affixes_index: Dictionary = {}
var _skills_index: Dictionary = {}
var _enemies_index: Dictionary = {}
var _classes_index: Dictionary = {}
var _sets_index: Dictionary = {}
var _dungeons_index: Dictionary = {}

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
	territory_data = load_json_config("territory.json")
	_build_indexes()

## 构建 ID 索引（加载后调用一次）
func _build_indexes():
	_equipment_index.clear()
	for item in get_all_equipment():
		var id = item.get("id", "")
		if id != "":
			_equipment_index[id] = item

	_affixes_index.clear()
	for affix in affixes_data.get("affixes", []):
		var id = affix.get("id", "")
		if id != "":
			_affixes_index[id] = affix

	_skills_index.clear()
	for skill in skills_data.get("skills", []):
		var id = skill.get("id", "")
		if id != "":
			_skills_index[id] = skill

	_enemies_index.clear()
	for enemy in enemies_data.get("enemies", []):
		var id = enemy.get("id", "")
		if id != "":
			_enemies_index[id] = enemy

	_classes_index.clear()
	for cls in classes_data.get("classes", []):
		var id = cls.get("id", "")
		if id != "":
			_classes_index[id] = cls

	_sets_index.clear()
	for set_item in sets_data.get("sets", []):
		var id = set_item.get("id", "")
		if id != "":
			_sets_index[id] = set_item

	_dungeons_index.clear()
	for dungeon in dungeons_data.get("dungeons", []):
		var id = dungeon.get("id", "")
		if id != "":
			_dungeons_index[id] = dungeon

	print("[ConfigLoader] 索引构建完成: %d 装备, %d 词缀, %d 技能, %d 敌人, %d 职业, %d 套装, %d 副本" % [
		_equipment_index.size(), _affixes_index.size(), _skills_index.size(),
		_enemies_index.size(), _classes_index.size(), _sets_index.size(), _dungeons_index.size()
	])

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

## 根据 id 查找词缀（O(1) 索引查找）
func get_affix_by_id(id: String) -> Dictionary:
	return _affixes_index.get(id, {})

## 根据 id 查找敌人（O(1) 索引查找）
func get_enemy_by_id(id: String) -> Dictionary:
	return _enemies_index.get(id, {})

## 获取数值平衡参数
func get_balance_param(key: String, default_value = null):
	return balance_data.get(key, default_value)

## 获取完整 balance 配置（只读视图）
## 说明：balance_data 是 Dictionary（引用语义），调用方只读不应改写。
## 多处系统（EquipmentSystem/AffixWorkshop/ClassMechanicSystem/TagSynergySystem/Player）
## 通过此方法读取 balance.json，语义比直接访问 balance_data 更清晰。
func get_balance_config() -> Dictionary:
	return balance_data

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

## 获取所有技能列表
func get_all_skills() -> Array:
	return skills_data.get("skills", [])

## 根据 id 查找装备（武器/护甲/饰品全找，O(1) 索引查找）
func get_equipment_by_id(id: String) -> Dictionary:
	return _equipment_index.get(id, {})

## 根据 id 查找职业（O(1) 索引查找）
func get_class_by_id(id: String) -> Dictionary:
	return _classes_index.get(id, {})

## 获取所有职业
func get_all_classes() -> Array:
	return classes_data.get("classes", [])

## 根据 id 查找套装（O(1) 索引查找）
func get_set_by_id(id: String) -> Dictionary:
	return _sets_index.get(id, {})

## 获取所有套装
func get_all_sets() -> Array:
	return sets_data.get("sets", [])

## 根据 id 查找技能（O(1) 索引查找）
func get_skill_by_id(id: String) -> Dictionary:
	return _skills_index.get(id, {})

## 获取某职业可用的技能（class 字段匹配或 "all" 通用）
func get_skills_for_class(class_id: String) -> Array:
	var result = []
	for s in skills_data.get("skills", []):
		var cls = s.get("class", "all")
		if cls == "all" or cls == class_id:
			result.append(s)
	return result

## 根据 id 查找副本（O(1) 索引查找）
func get_dungeon_by_id(id: String) -> Dictionary:
	return _dungeons_index.get(id, {})

## 获取所有副本
func get_all_dungeons() -> Array:
	return dungeons_data.get("dungeons", [])

## 获取稀有度特效配置
func get_vfx_for_rarity(rarity: String) -> Dictionary:
	return vfx_data.get("rarity_vfx", {}).get(rarity, {})

## ============ 领地系统 ============
## 获取建筑定义（by id）
func get_building_def(building_id: String) -> Dictionary:
	for b in territory_data.get("buildings", []):
		if b.get("id", "") == building_id:
			return b
	return {}

## 获取所有可建造建筑定义
func get_all_buildings() -> Array:
	return territory_data.get("buildings", [])

## 获取领地某等级的定义
func get_territory_level_def(level: int) -> Dictionary:
	for lv in territory_data.get("territory_levels", []):
		if int(lv.get("level", 0)) == level:
			return lv
	return {}

## 领地最高等级
func get_territory_max_level() -> int:
	var mx = 1
	for lv in territory_data.get("territory_levels", []):
		mx = max(mx, int(lv.get("level", 1)))
	return mx

## 获取基础建材定义列表
func get_basic_materials() -> Array:
	return territory_data.get("basic_materials", [])

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
		"territory.json": territory_data = data
		_:
			push_warning("[ConfigLoader] 未知配置: " + file_name)
			return false
	_build_indexes()  # 热重载后重建索引
	print("[ConfigLoader] 热重载: " + file_name)
	config_reloaded.emit(file_name)
	return true

## 热重载所有配置文件
func reload_all() -> void:
	load_all_configs()
	all_configs_reloaded.emit()
	print("[ConfigLoader] 全部配置已重载")
