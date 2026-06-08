extends Node
## SpriteLibrary - 程序化生成素材的统一访问层
## 把 region/rank/class 映射到 assets/generated 下的精灵帧
## 提供 AnimatedSprite2D 的 SpriteFrames 构建

const GEN = "res://assets/generated/"
const FRAME_SIZE = 64       # 角色/敌人帧尺寸
const EFFECT_SIZE = 64

# region -> 敌人家族
const REGION_FAMILY = {
	"crypt": "skeleton",
	"swamp": "slime",
	"forge": "demon",
	"ice": "ice",
	"void": "void",
	"field": "beast",
}

# rank -> 缩放与染色
const RANK_SCALE = {
	"normal": 2.4,
	"elite": 3.0,
	"boss": 4.2,
	"field_boss": 3.6,
}
const RANK_TINT = {
	"normal": Color(1, 1, 1),
	"elite": Color(1.15, 1.05, 0.8),     # 偏金
	"boss": Color(1.2, 0.7, 0.7),        # 偏红
	"field_boss": Color(0.9, 1.1, 1.1),
}

var _sheet_cache: Dictionary = {}      # path -> Array[Texture2D]
var _frames_cache: Dictionary = {}     # key -> SpriteFrames

func _ready():
	print("[SpriteLibrary] 初始化")

## 切割横向 spritesheet 为帧纹理数组
func _slice_sheet(path: String, frame_size: int = FRAME_SIZE) -> Array:
	if _sheet_cache.has(path):
		return _sheet_cache[path]
	var frames := []
	if not ResourceLoader.exists(path):
		push_warning("[SpriteLibrary] 缺失: %s" % path)
		_sheet_cache[path] = frames
		return frames
	var tex: Texture2D = load(path)
	var img := tex.get_image()
	var count := int(img.get_width() / frame_size)
	count = max(count, 1)
	for i in range(count):
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * frame_size, 0, frame_size, frame_size)
		frames.append(at)
	_sheet_cache[path] = frames
	return frames

## 为职业构建 SpriteFrames（idle/walk/attack/hurt）
func get_class_frames(class_id: String) -> SpriteFrames:
	var key := "class_" + class_id
	if _frames_cache.has(key):
		return _frames_cache[key]
	var short := class_id.replace("class_", "")
	var base := GEN + "characters/" + short + "/"
	var sf := SpriteFrames.new()
	for anim in ["idle", "walk", "attack", "hurt"]:
		if not sf.has_animation(anim):
			sf.add_animation(anim)
		sf.set_animation_loop(anim, anim in ["idle", "walk"])
		sf.set_animation_speed(anim, 6.0 if anim == "idle" else 10.0)
		var frames := _slice_sheet(base + anim + ".png")
		for f in frames:
			sf.add_frame(anim, f)
	_frames_cache[key] = sf
	return sf

## 为敌人构建 SpriteFrames（idle/attack），按 region 取家族
func get_enemy_frames(region: String) -> SpriteFrames:
	var fam: String = REGION_FAMILY.get(region, "beast")
	var key := "enemy_" + fam
	if _frames_cache.has(key):
		return _frames_cache[key]
	var base := GEN + "enemies/" + fam + "/"
	var sf := SpriteFrames.new()
	for anim in ["idle", "attack"]:
		if not sf.has_animation(anim):
			sf.add_animation(anim)
		sf.set_animation_loop(anim, anim == "idle")
		sf.set_animation_speed(anim, 6.0 if anim == "idle" else 10.0)
		var frames := _slice_sheet(base + anim + ".png")
		for f in frames:
			sf.add_frame(anim, f)
	_frames_cache[key] = sf
	return sf

## 职业头像（单帧 idle 的第一帧）
func get_class_portrait(class_id: String) -> Texture2D:
	var short := class_id.replace("class_", "")
	var path := GEN + "characters/" + short + "/portrait.png"
	if ResourceLoader.exists(path):
		return load(path)
	return null

## 装备图标（按 slot + rarity）
## slot: weapon->按category, 其它直接用 slot 名
func get_equipment_icon(slot: String, category: String, rarity: String) -> Texture2D:
	var kind := _slot_to_icon(slot, category)
	var path := GEN + "icons/equipment/%s_%s.png" % [kind, rarity]
	if ResourceLoader.exists(path):
		return load(path)
	# 回退到 common
	path = GEN + "icons/equipment/%s_common.png" % kind
	if ResourceLoader.exists(path):
		return load(path)
	return null

func _slot_to_icon(slot: String, category: String) -> String:
	if slot == "weapon":
		match category:
			"sword", "scythe", "dagger", "mace": return "sword"
			"staff", "wand": return "staff"
			"bow": return "bow"
			_: return "sword"
	if slot in ["helmet", "chest", "legs", "boots", "gloves", "ring", "amulet"]:
		return slot
	return "sword"

## 技能图标（按 shape 关键字）
func get_skill_icon(shape: String) -> Texture2D:
	var path := GEN + "icons/skills/%s.png" % shape
	if ResourceLoader.exists(path):
		return load(path)
	return load(GEN + "icons/skills/slash.png") if ResourceLoader.exists(GEN + "icons/skills/slash.png") else null

## 特效帧数组
func get_effect_frames(kind: String) -> Array:
	return _slice_sheet(GEN + "effects/%s.png" % kind, EFFECT_SIZE)

## 地块纹理
func get_tile(region: String, is_obstacle: bool = false) -> Texture2D:
	var prefix := "obstacle_" if is_obstacle else "floor_"
	var path := GEN + "tiles/%s%s.png" % [prefix, region]
	if ResourceLoader.exists(path):
		return load(path)
	path = GEN + "tiles/%s%s.png" % [prefix, "field"]
	return load(path) if ResourceLoader.exists(path) else null

## UI 纹理
func get_ui(name: String) -> Texture2D:
	var path := GEN + "ui/%s.png" % name
	return load(path) if ResourceLoader.exists(path) else null
