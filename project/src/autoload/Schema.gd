class_name Schema
extends RefCounted
## 数据契约单一真源 - 所有跨 JSON/GDScript 共享的枚举与字段名常量
##
## 设计意图：杜绝散落的裸字符串（"uncommon"、"enhance_level" 之类）导致的
## 静默 bug。任何地方需要稀有度/部位/职业/字段名，一律引用 Schema.XXX，
## 这样改一处即全局生效，validate_config.gd 也据此校验配置数据。
##
## 用法：
##   if rarity in Schema.RARITIES: ...
##   var lv = instance.get(Schema.K_ENHANCEMENT_LEVEL, 0)

# ============ 稀有度（5 档，无旧的 uncommon）============
const RARITY_COMMON := "common"
const RARITY_RARE := "rare"
const RARITY_EPIC := "epic"
const RARITY_LEGENDARY := "legendary"
const RARITY_MYTHIC := "mythic"
const RARITIES := ["common", "rare", "epic", "legendary", "mythic"]

# 稀有度倍率（与 darkloot-content-v3 约定一致：1.0/1.4/1.9/2.6/3.5）
const RARITY_MULT := {
	"common": 1.0, "rare": 1.4, "epic": 1.9, "legendary": 2.6, "mythic": 3.5
}

# 稀有度中文名（UI 统一来源）
const RARITY_DISPLAY := {
	"common": "普通", "rare": "稀有", "epic": "史诗",
	"legendary": "传奇", "mythic": "神话"
}

# 稀有度颜色（UI/特效统一来源）
const RARITY_COLOR := {
	"common": "#C8C8C8", "rare": "#4A90D9", "epic": "#9B4DCA",
	"legendary": "#E8A317", "mythic": "#E03131"
}

# ============ 装备 8 部位 ============
const SLOTS := ["weapon", "helmet", "chest", "legs", "boots", "gloves", "ring", "amulet"]

# ============ 8 职业（带 class_ 前缀的完整 ID）============
const CLASS_IDS := [
	"class_warrior", "class_ranger", "class_mage",
	"class_assassin", "class_knight", "class_necromancer",
	"class_frost_witch", "class_shadow_archer"
]

# balance.json 的 class_mechanics 用去前缀的短键，这里提供映射避免再写裸字符串
const CLASS_SHORT := {
	"class_warrior": "warrior", "class_ranger": "ranger", "class_mage": "mage",
	"class_assassin": "assassin", "class_knight": "knight", "class_necromancer": "necromancer",
	"class_frost_witch": "frost_witch", "class_shadow_archer": "shadow_archer"
}

# ============ 6 套装 ============
const SET_IDS := ["set_bone", "set_plague", "set_ember", "set_frost", "set_void", "set_eternal_warrior"]
const SET_PIECES_PER_SET := 6

# ============ 装备实例字段名（唯一权威拼写）============
const K_ENHANCEMENT_LEVEL := "enhancement_level"   # 强化等级 +N，禁止再写 enhance_level
const K_TEMPLATE_ID := "template_id"
const K_RARITY := "rarity"
const K_ROLLED_AFFIXES := "rolled_affixes"
const K_UUID := "uuid"
const K_BOUND := "bound"

# ============ 敌人字段名 ============
const K_MAX_HP := "max_hp"   # 敌人/玩家生命字段，禁止写 hp

# ============ 校验辅助 ============
static func is_valid_rarity(r: String) -> bool:
	return r in RARITIES

static func is_valid_slot(s: String) -> bool:
	return s in SLOTS

static func is_valid_class(c: String) -> bool:
	return c in CLASS_IDS

static func rarity_display(r: String) -> String:
	return RARITY_DISPLAY.get(r, r)

static func rarity_color(r: String) -> Color:
	return Color(RARITY_COLOR.get(r, "#FFFFFF"))

# ============ 稀有度视觉派生（A1：所有视觉从此取，杜绝散落硬编码）============
## 稀有度排序索引（0=common ... 4=mythic）。用于过滤/比较。
static func rarity_rank(r: String) -> int:
	return RARITIES.find(r)

## 暗色调（UI 背景用）
static func rarity_dark_color(r: String) -> Color:
	return rarity_color(r).darkened(0.6)

## 发光色（描边/光环用）
static func rarity_glow_color(r: String) -> Color:
	return rarity_color(r).lightened(0.3)

## 稀有度边框宽度（高稀有度更粗）
static func rarity_border_width(r: String) -> int:
	match r:
		RARITY_COMMON: return 1
		RARITY_RARE: return 2
		RARITY_EPIC: return 2
		RARITY_LEGENDARY: return 3
		RARITY_MYTHIC: return 4
		_: return 1

## 稀有度圆角半径（高稀有度更圆润）
static func rarity_corner_radius(r: String) -> int:
	match r:
		RARITY_COMMON: return 0
		RARITY_RARE: return 2
		RARITY_EPIC: return 4
		RARITY_LEGENDARY: return 6
		RARITY_MYTHIC: return 8
		_: return 0
