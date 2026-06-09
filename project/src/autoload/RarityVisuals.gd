extends Node
## 稀有度视觉体系 - 统一管理稀有度颜色、边框、特效、标签
## 集成 EquipmentSystem.get_rarity_color 并扩展完整视觉体系

## 稀有度排序和配置
const RARITY_ORDER = ["common", "rare", "epic", "legendary", "mythic"]
const RARITY_NAMES = {
	"common": "普通",
	"rare": "稀有",
	"epic": "史诗",
	"legendary": "传奇",
	"mythic": "神话"
}

## 稀有度颜色（与 EquipmentSystem 保持一致）
const RARITY_COLORS = {
	"common": Color("#C8C8C8"),      # 灰白
	"rare": Color("#4A90D9"),        # 蓝
	"epic": Color("#9B4DCA"),        # 紫
	"legendary": Color("#E8A317"),   # 金
	"mythic": Color("#E03131")       # 红
}

## ============ 颜色系统 ============
## 获取稀有度颜色
func get_rarity_color(rarity: String) -> Color:
	return RARITY_COLORS.get(rarity, Color.WHITE)

## 获取稀有度暗色（背景用）
func get_rarity_dark_color(rarity: String) -> Color:
	var base = get_rarity_color(rarity)
	return base.darkened(0.6)

## 获取稀有度发光色（特效用）
func get_rarity_glow_color(rarity: String) -> Color:
	var base = get_rarity_color(rarity)
	return base.lightened(0.3)

## ============ 边框样式 ============
## 获取稀有度边框样式（返回 StyleBoxFlat）
func get_rarity_border_style(rarity: String, bg_alpha: float = 0.9) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	var color = get_rarity_color(rarity)

	# 背景色：暗色调，保留稀有度色调
	style.bg_color = get_rarity_dark_color(rarity)
	style.bg_color.a = bg_alpha

	# 边框：稀有度颜色
	style.border_color = color
	var border_width = _get_border_width(rarity)
	style.border_width_left = border_width
	style.border_width_right = border_width
	style.border_width_top = border_width
	style.border_width_bottom = border_width

	# 圆角（高稀有度更圆润）
	var corner_radius = _get_corner_radius(rarity)
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius

	# 阴影（传奇和神话有发光效果）
	if rarity in ["legendary", "mythic"]:
		style.shadow_color = get_rarity_glow_color(rarity)
		style.shadow_color.a = 0.5
		style.shadow_size = 4 if rarity == "legendary" else 6
		style.shadow_offset = Vector2(0, 0)

	return style

## 获取边框宽度
func _get_border_width(rarity: String) -> int:
	match rarity:
		"common": return 1
		"rare": return 2
		"epic": return 2
		"legendary": return 3
		"mythic": return 4
		_: return 1

## 获取圆角半径
func _get_corner_radius(rarity: String) -> int:
	match rarity:
		"common": return 0
		"rare": return 2
		"epic": return 4
		"legendary": return 6
		"mythic": return 8
		_: return 0

## ============ 背景渐变 ============
## 获取稀有度背景渐变（用于 tooltip/面板）
func get_rarity_bg_gradient(rarity: String) -> Gradient:
	var gradient = Gradient.new()
	var dark_color = get_rarity_dark_color(rarity)
	var darker_color = dark_color.darkened(0.3)

	gradient.set_color(0, darker_color)  # 顶部更暗
	gradient.set_color(1, dark_color)     # 底部稍亮

	return gradient

## ============ 文本标签 ============
## 获取稀有度中文名
func get_rarity_label(rarity: String) -> String:
	return RARITY_NAMES.get(rarity, "未知")

## 获取稀有度带颜色的富文本标签（用于 RichTextLabel）
func get_rarity_rich_text(rarity: String) -> String:
	var color = get_rarity_color(rarity)
	var label = get_rarity_label(rarity)
	return "[color=#%s]%s[/color]" % [color.to_html(false), label]

## ============ 特效等级 ============
## 获取稀有度特效等级（0=无 1=描边 2=粒子 3=光环 4=全屏）
func get_rarity_vfx_level(rarity: String) -> int:
	match rarity:
		"common": return 0
		"rare": return 1
		"epic": return 2
		"legendary": return 3
		"mythic": return 4
		_: return 0

## ============ UI元素生成器 ============
## 创建稀有度标签（Label节点）
func create_rarity_label(rarity: String) -> Label:
	var label = Label.new()
	label.text = get_rarity_label(rarity)
	label.add_theme_color_override("font_color", get_rarity_color(rarity))
	return label

## 创建带边框的稀有度面板（PanelContainer）
func create_rarity_panel(rarity: String) -> PanelContainer:
	var panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", get_rarity_border_style(rarity))
	return panel

## ============ 装备Tooltip美化 ============
## 生成装备tooltip（完整版，带稀有度视觉）
func generate_equipment_tooltip(item_data: Dictionary) -> String:
	var lines = []

	# 1. 装备名（稀有度颜色）
	var rarity = item_data.get("rarity", "common")
	var name = item_data.get("display_name", "未知装备")
	var enhancement = item_data.get("enhancement_level", 0)
	if enhancement > 0:
		name = "%s +%d" % [name, enhancement]
	var name_color = get_rarity_color(rarity)
	lines.append("[color=#%s][b]%s[/b][/color]" % [name_color.to_html(false), name])

	# 2. 稀有度标签
	lines.append(get_rarity_rich_text(rarity))
	lines.append("")

	# 3. 部位和分类
	var slot = item_data.get("slot", "weapon")
	var category = item_data.get("category", "")
	var slot_text = _get_slot_display_name(slot)
	if category != "":
		slot_text += " · " + category
	lines.append("[color=#888888]%s[/color]" % slot_text)
	lines.append("")

	# 4. 基础属性（白色/绿色）
	var stats = item_data.get("base_stats", {})
	if not stats.is_empty():
		lines.append("[b]基础属性:[/b]")
		for stat_key in stats:
			var value = stats[stat_key]
			var stat_line = _format_stat_line(stat_key, value)
			if stat_line != "":
				lines.append("[color=#88FF88]%s[/color]" % stat_line)
		lines.append("")

	# 5. 词缀属性（蓝色/金色）
	var affixes = item_data.get("fixed_affixes", [])
	if not affixes.is_empty():
		lines.append("[b]词缀:[/b]")
		for affix_id in affixes:
			var affix = ConfigLoader.get_affix_by_id(affix_id)
			if not affix.is_empty():
				var affix_line = _format_affix_line(affix)
				lines.append("[color=#88DDFF]• %s[/color]" % affix_line)
		lines.append("")

	# 6. 套装信息
	var set_id = item_data.get("set_id", "")
	if set_id != "":
		var set_data = ConfigLoader.get_set_by_id(set_id)
		if not set_data.is_empty():
			var set_name = set_data.get("display_name", set_id)
			var pieces = EquipmentSystem.get_set_pieces(set_id)
			lines.append("[color=#FF88FF][b]套装: %s (%d/6)[/b][/color]" % [set_name, pieces])

			# 显示套装加成（已激活的用绿色，未激活的用灰色）
			for bonus in set_data.get("bonuses", []):
				var req = bonus.get("pieces", 0)
				var is_active = pieces >= req
				var color_code = "#88FF88" if is_active else "#666666"
				var bonus_text = "(%d件) %s" % [req, _format_set_bonus(bonus)]
				lines.append("[color=%s]  %s[/color]" % [color_code, bonus_text])
			lines.append("")

	# 7. 物品描述
	var desc = item_data.get("description", "")
	if desc != "":
		lines.append("[i][color=#AAAAAA]%s[/color][/i]" % desc)

	return "\n".join(lines)

## 格式化属性行
func _format_stat_line(stat_key: String, value: float) -> String:
	match stat_key:
		"damage":
			return "+%.1f 伤害" % value
		"max_hp":
			return "+%.0f 生命上限" % value
		"armor":
			return "+%.1f 护甲" % value
		"crit_chance":
			return "+%.1f%% 暴击率" % (value * 100)
		"crit_damage":
			return "+%.1f%% 暴击伤害" % ((value - 1.0) * 100)
		"attack_speed":
			if value > 1.0:
				return "%.2fx 攻击速度" % value
			else:
				return "+%.1f%% 攻击速度" % (value * 100)
		"move_speed":
			return "+%.1f%% 移动速度" % (value * 100)
		"hp_regen":
			return "+%.1f 生命回复/秒" % value
		_:
			return "%s: %.2f" % [stat_key, value]

## 格式化词缀行
func _format_affix_line(affix: Dictionary) -> String:
	var display_name = affix.get("display_name", "")
	var effect = affix.get("effect", {})
	var kind = effect.get("kind", "")

	match kind:
		"lifesteal":
			return "%s (%.1f%% 吸血)" % [display_name, effect.get("value", 0) * 100]
		"add_damage":
			var dmg_type = effect.get("damage_type", "physical")
			return "%s (+%.0f %s伤害)" % [display_name, effect.get("value", 0), dmg_type]
		"ignite":
			return "%s (%.0f DPS, %.1fs)" % [display_name, effect.get("dps", 0), effect.get("duration", 0)]
		"freeze":
			return "%s (%.1f%% 几率, %.1fs)" % [display_name, effect.get("chance", 0) * 100, effect.get("duration", 0)]
		"add_stat":
			var stat = effect.get("stat", "")
			var value = effect.get("value", 0)
			return "%s (%s)" % [display_name, _format_stat_line(stat, value)]
		_:
			return display_name

## 格式化套装加成
func _format_set_bonus(bonus: Dictionary) -> String:
	var parts = []
	var stats = bonus.get("stats", {})
	for stat_key in stats:
		parts.append(_format_stat_line(stat_key, stats[stat_key]))
	var effects = bonus.get("effects", {})
	for effect_key in effects:
		parts.append(str(effect_key) + ": " + str(effects[effect_key]))
	return ", ".join(parts) if not parts.is_empty() else "未知加成"

## 部位中文名映射
func _get_slot_display_name(slot: String) -> String:
	match slot:
		"weapon": return "武器"
		"helmet": return "头盔"
		"chest": return "胸甲"
		"legs": return "腿甲"
		"boots": return "靴子"
		"gloves": return "手套"
		"ring": return "戒指"
		"amulet": return "项链"
		_: return slot
