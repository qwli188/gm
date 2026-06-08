extends Node
## GameState - 跨场景的全局游戏状态
## 存储：选中的职业、选中的副本、局外永久数据

# 当前选中的职业 id（主菜单选择 → 传给游戏场景）
var selected_class_id: String = "class_warrior"

# 当前选中的副本和难度
var selected_dungeon_id: String = "dungeon_crypt_1"
var selected_difficulty_tier: int = 1
var selected_waveset: String = "waveset_crypt_1"
var selected_hp_mult: float = 1.0
var selected_dmg_mult: float = 1.0
var selected_drop_bonus: float = 0.0
var selected_set_drop: String = ""

# 局外永久数据（金币、强化等级、已解锁内容）
var total_gold: int = 0
var meta_upgrades: Dictionary = {}      # {"perm_hp": 3, "perm_damage": 5, ...}
var unlocked_dungeons: Array = ["dungeon_crypt_1"]
var cleared_dungeons: Dictionary = {}   # {"clear_dungeon_crypt_1": true}

func _ready():
	print("[GameState] 全局状态初始化")

## 获取当前职业配置
func get_current_class() -> Dictionary:
	return ConfigLoader.get_class_by_id(selected_class_id)

## 设置职业
func set_class(class_id: String):
	selected_class_id = class_id
	print("[GameState] 选择职业: %s" % class_id)

## 进入副本：设置副本、波次、难度（Town 选择副本时调用）
## 兼容别名：selected_dungeon
var selected_dungeon: String:
	get:
		return selected_dungeon_id
	set(value):
		selected_dungeon_id = value

func enter_dungeon(dungeon_id: String, tier: int = 1):
	selected_dungeon_id = dungeon_id
	var dungeon = ConfigLoader.get_dungeon_by_id(dungeon_id)
	if dungeon.is_empty():
		push_warning("[GameState] 未找到副本: %s" % dungeon_id)
		return
	selected_waveset = dungeon.get("wave_set", "waveset_crypt_1")
	selected_set_drop = dungeon.get("set_drop", "")
	# 应用难度
	var tiers = dungeon.get("difficulty_tiers", [])
	for t in tiers:
		if t.get("tier", 1) == tier:
			selected_difficulty_tier = tier
			selected_hp_mult = t.get("enemy_hp_mult", 1.0)
			selected_dmg_mult = t.get("enemy_dmg_mult", 1.0)
			selected_drop_bonus = t.get("drop_bonus", 0.0)
			break
	print("[GameState] 进入副本: %s (波次=%s, tier=%d)" % [dungeon_id, selected_waveset, tier])

## 局外强化加成查询（每级的总加成）
func get_meta_bonus(upgrade_id: String) -> float:
	var level = meta_upgrades.get(upgrade_id, 0)
	if level == 0:
		return 0.0
	# 从 balance.json 读取每级数值
	var meta = ConfigLoader.balance_data.get("meta_progression", {})
	for stat in meta.get("stats", []):
		if stat.get("id", "") == upgrade_id:
			return stat.get("per_level", 0) * level
	return 0.0
