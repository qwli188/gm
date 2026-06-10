extends Control

signal equipment_equipped(item_data: Dictionary)
signal equipment_discarded

@onready var name_label: Label = $Panel/VBoxContainer/NameLabel
@onready var stats_label: Label = $Panel/VBoxContainer/StatsLabel
@onready var affixes_label: Label = $Panel/VBoxContainer/AffixesLabel
@onready var comparison_label: RichTextLabel = $Panel/VBoxContainer/ComparisonLabel
@onready var equip_button: Button = $Panel/VBoxContainer/ButtonContainer/EquipButton
@onready var discard_button: Button = $Panel/VBoxContainer/ButtonContainer/DiscardButton

var current_item_data: Dictionary = {}
var current_slot: String = ""
var icon_rect: TextureRect = null

func _ready():
	hide()
	equip_button.pressed.connect(_on_equip_pressed)
	discard_button.pressed.connect(_on_discard_pressed)
	# 创建图标显示节点
	icon_rect = TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(80, 80)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# 插到名称标签前面
	var vbox = $Panel/VBoxContainer
	vbox.add_child(icon_rect)
	vbox.move_child(icon_rect, 0)

func _input(event):
	if not visible:
		return

	if event.is_action_pressed("equip_item"):
		_on_equip_pressed()
	elif event.is_action_pressed("discard_item"):
		_on_discard_pressed()

## 显示装备拾取弹窗
func show_equipment(item_data: Dictionary, slot: String):
	current_item_data = item_data
	current_slot = slot

	# 填充装备信息
	_populate_equipment_info(item_data, slot)

	# 暂停游戏并显示
	get_tree().paused = true
	show()

## 填充装备信息
func _populate_equipment_info(item_data: Dictionary, slot: String):
	# 显示装备图标
	if icon_rect:
		var item_slot = item_data.get("slot", "weapon")
		var category = item_data.get("category", "sword")
		var rarity = item_data.get("rarity", "common")
		icon_rect.texture = SpriteLibrary.get_equipment_icon(item_slot, category, rarity)

	var display_name = item_data.get("display_name", "???")
	var rarity = item_data.get("rarity", "common")
	var rarity_text = _translate_rarity(rarity)

	name_label.text = "%s (%s)" % [display_name, rarity_text]
	name_label.modulate = _get_rarity_color(rarity)

	# 显示基础属性
	var base_stats = item_data.get("base_stats", {})
	var stats_text = "属性:\n"
	for stat_key in base_stats:
		var value = base_stats[stat_key]
		stats_text += "  %s: %s\n" % [_translate_stat(stat_key), _format_stat_value(stat_key, value)]
	stats_label.text = stats_text

	# 显示词缀
	var fixed_affixes = item_data.get("fixed_affixes", [])
	if fixed_affixes.size() > 0:
		var affixes_text = "词缀:\n"
		for affix_id in fixed_affixes:
			var affix_data = ConfigLoader.get_affix_by_id(affix_id)
			if not affix_data.is_empty():
				affixes_text += "  - %s\n" % affix_data.get("display_name", affix_id)
		affixes_label.text = affixes_text
	else:
		affixes_label.text = "无词缀"

	# 对比当前装备
	_show_comparison(item_data, slot)

## 显示装备对比
func _show_comparison(new_item: Dictionary, slot: String):
	var equipped_item = EquipmentSystem.equipped_items.get(slot, null)

	if equipped_item == null:
		comparison_label.text = "当前未装备"
		return

	var comparison_text = "对比当前装备:\n"
	var new_stats = new_item.get("base_stats", {})
	var old_stats = equipped_item.get("base_stats", {})

	# 对比每个属性
	var all_stats = {}
	for key in new_stats:
		all_stats[key] = true
	for key in old_stats:
		all_stats[key] = true

	for stat_key in all_stats:
		var new_value = new_stats.get(stat_key, 0)
		var old_value = old_stats.get(stat_key, 0)
		var diff = new_value - old_value

		if diff > 0:
			comparison_text += "  %s: +%s [color=green]↑[/color]\n" % [_translate_stat(stat_key), _format_stat_value(stat_key, diff)]
		elif diff < 0:
			comparison_text += "  %s: %s [color=red]↓[/color]\n" % [_translate_stat(stat_key), _format_stat_value(stat_key, diff)]
		else:
			comparison_text += "  %s: 相同\n" % _translate_stat(stat_key)

	comparison_label.text = comparison_text

## 翻译稀有度
func _translate_rarity(rarity: String) -> String:
	match rarity:
		"common": return "普通"
		"rare": return "稀有"
		"epic": return "史诗"
		"legendary": return "传奇"
		"mythic": return "神话"
		_: return rarity

## 翻译属性名
func _translate_stat(stat: String) -> String:
	match stat:
		"damage": return "伤害"
		"attack_speed": return "攻速"
		"crit_chance": return "暴击率"
		"armor": return "护甲"
		"max_hp": return "生命"
		"move_speed": return "移速"
		"hp_regen": return "生命回复"
		_: return stat

## 格式化属性值
func _format_stat_value(stat: String, value) -> String:
	if stat in ["attack_speed", "crit_chance", "move_speed"]:
		if value > 0:
			return "+%.1f%%" % (value * 100)
		else:
			return "%.1f%%" % (value * 100)
	else:
		if value > 0:
			return "+%d" % value
		else:
			return "%d" % value

## 获取稀有度颜色（统一用 EquipmentSystem）
func _get_rarity_color(rarity: String) -> Color:
	return EquipmentSystem.get_rarity_color(rarity)

func _on_equip_pressed():
	equipment_equipped.emit(current_item_data)

	# 拾取（PR-3 后:槽位空则穿戴，否则进 Inventory 背包；不再粗暴覆盖穿戴）
	if not current_item_data.is_empty():
		EquipmentSystem.pickup_equipment(current_item_data)

	# 恢复游戏并隐藏
	get_tree().paused = false
	hide()

func _on_discard_pressed():
	equipment_discarded.emit()

	# 恢复游戏并隐藏
	get_tree().paused = false
	hide()
