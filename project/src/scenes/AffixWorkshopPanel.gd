extends Panel
## 词缀工坊界面 - 装备洗练/分解

@onready var item_slot: Panel = $VBox/ItemSlot
@onready var item_name_label: Label = $VBox/ItemSlot/ItemName
@onready var affix_list: VBoxContainer = $VBox/ScrollContainer/AffixList
@onready var cost_label: Label = $VBox/CostInfo
@onready var reforge_button: Button = $VBox/ButtonRow/ReforgeButton
@onready var dismantle_button: Button = $VBox/ButtonRow/DismantleButton
@onready var enhance_button: Button = $VBox/ButtonRow/EnhanceButton
@onready var close_button: Button = $VBox/CloseButton

var current_item: Dictionary = {}
var current_item_index: int = -1
var locked_affixes: Array[int] = []

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	reforge_button.pressed.connect(_on_reforge_pressed)
	dismantle_button.pressed.connect(_on_dismantle_pressed)
	enhance_button.pressed.connect(_on_enhance_pressed)
	_clear_ui()

## 打开面板并加载指定装备
func open_with_item(item_data: Dictionary, item_index: int):
	current_item = item_data
	current_item_index = item_index
	locked_affixes.clear()
	_refresh_ui()
	show()

## 刷新UI显示
func _refresh_ui():
	if current_item.is_empty():
		_clear_ui()
		return

	# 装备名称
	var rarity = current_item.get("rarity", "common")
	var color = EquipmentSystem.get_rarity_color(rarity)
	item_name_label.text = current_item.get("display_name", "未知装备")
	item_name_label.add_theme_color_override("font_color", color)

	# 词缀列表
	_build_affix_list()

	# 消耗信息
	_update_cost_display()

	# 按钮状态
	_update_button_states()

## 构建词缀列表（带锁定按钮）
func _build_affix_list():
	# 清空
	for child in affix_list.get_children():
		child.queue_free()

	var affixes = current_item.get("fixed_affixes", [])
	if affixes.is_empty():
		var label = Label.new()
		label.text = "该装备没有词缀"
		label.add_theme_color_override("font_color", Color.GRAY)
		affix_list.add_child(label)
		return

	for i in affixes.size():
		var affix_id = affixes[i]
		var affix = ConfigLoader.get_affix_by_id(affix_id)
		var row = _create_affix_row(affix, i)
		affix_list.add_child(row)

## 创建单个词缀行（词缀名 + 锁定按钮）
func _create_affix_row(affix: Dictionary, index: int) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var label = Label.new()
	label.text = affix.get("display_name", "未知词缀")
	label.custom_minimum_size = Vector2(200, 0)
	label.add_theme_font_size_override("font_size", 18)
	row.add_child(label)

	var lock_btn = Button.new()
	lock_btn.custom_minimum_size = Vector2(80, 40)
	lock_btn.toggle_mode = true
	lock_btn.button_pressed = index in locked_affixes
	lock_btn.text = "🔓" if not lock_btn.button_pressed else "🔒"
	lock_btn.toggled.connect(_on_lock_toggled.bind(index))
	row.add_child(lock_btn)

	return row

## 锁定开关回调
func _on_lock_toggled(pressed: bool, index: int):
	if pressed:
		if index not in locked_affixes:
			locked_affixes.append(index)
	else:
		locked_affixes.erase(index)
	_update_cost_display()
	_update_button_states()

## 更新消耗显示
func _update_cost_display():
	if current_item.is_empty():
		cost_label.text = ""
		return

	var rarity = current_item.get("rarity", "common")
	var cost_data = AffixWorkshop._get_reforge_cost(rarity)
	var gold = cost_data.get("gold", 0)
	var shards = cost_data.get("rune_shard", 0)

	# 锁定词缀增加消耗
	if locked_affixes.size() > 0:
		var mult = ConfigLoader.balance_data.get("affix_workshop", {}).get("lock_cost_multiplier", 1.5)
		gold = int(gold * mult)
		shards = int(shards * mult)

	var gold_color = "green" if GameState.total_gold >= gold else "red"
	var shard_color = "green" if GameState.get_material("rune_shard") >= shards else "red"

	cost_label.text = "洗练消耗: [color=%s]%d金币[/color] + [color=%s]%d符文碎片[/color]" % [gold_color, gold, shard_color, shards]

## 更新按钮状态
func _update_button_states():
	if current_item.is_empty():
		reforge_button.disabled = true
		dismantle_button.disabled = true
		return

	var rarity = current_item.get("rarity", "common")
	var cost_data = AffixWorkshop._get_reforge_cost(rarity)
	var gold = cost_data.get("gold", 0)
	var shards = cost_data.get("rune_shard", 0)

	if locked_affixes.size() > 0:
		var mult = ConfigLoader.balance_data.get("affix_workshop", {}).get("lock_cost_multiplier", 1.5)
		gold = int(gold * mult)
		shards = int(shards * mult)

	reforge_button.disabled = GameState.total_gold < gold or GameState.get_material("rune_shard") < shards
	dismantle_button.disabled = false

## 洗练按钮
func _on_reforge_pressed():
	if current_item_index < 0:
		return

	var result = AffixWorkshop.reforge(current_item_index, locked_affixes)
	if not result.is_empty():
		current_item = result
		locked_affixes.clear()
		_refresh_ui()
		_play_reforge_animation()

## 分解按钮
func _on_dismantle_pressed():
	if current_item_index < 0:
		return

	var shard_count = AffixWorkshop.dismantle_equipment(current_item_index)
	if shard_count > 0:
		_show_dismantle_result(shard_count)
		_clear_ui()
		current_item = {}
		current_item_index = -1

## 关闭按钮
func _on_close_pressed():
	hide()

## 清空UI
func _clear_ui():
	item_name_label.text = "拖入装备进行洗练"
	cost_label.text = ""
	reforge_button.disabled = true
	dismantle_button.disabled = true
	for child in affix_list.get_children():
		child.queue_free()

## 播放洗练动画（简单闪烁效果）
func _play_reforge_animation():
	var tween = create_tween()
	tween.tween_property(affix_list, "modulate:a", 0.3, 0.2)
	tween.tween_property(affix_list, "modulate:a", 1.0, 0.2)

## 显示分解结果
func _show_dismantle_result(shard_count: int):
	var label = Label.new()
	label.text = "+%d 符文碎片" % shard_count
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color.GOLD)
	label.position = Vector2(400, 300)
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", 200, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)



# ============================================================
# 阶段1: 装备强化功能集成
# ============================================================

## 强化按钮处理(需在场景中添加EnhanceButton节点,或动态创建)
func _on_enhance_pressed():
	if current_item.is_empty():
		return

	var instance_id = current_item.get("instance_id", "")
	if instance_id == "":
		_show_float_text("该装备无法强化", Color.RED)
		return

	if not has_node("/root/AffixWorkshop"):
		return

	var result = AffixWorkshop.enhance_equipment(instance_id)
	var msg = result.get("message", "")
	var succeeded = result.get("success", false)

	# 刷新当前装备数据
	if has_node("/root/EquipmentSystem"):
		var fresh = EquipmentSystem.get_equipment_instance(instance_id)
		if fresh:
			current_item = fresh

	_refresh_ui()
	_play_enhance_animation(succeeded)
	_show_float_text(msg, Color.CYAN if succeeded else Color.ORANGE_RED)

## 强化动画
func _play_enhance_animation(succeeded: bool):
	var color = Color(0.4, 1.0, 0.4) if succeeded else Color(1.0, 0.3, 0.3)
	if item_slot:
		var tween = create_tween()
		tween.tween_property(item_slot, "modulate", color, 0.15)
		tween.tween_property(item_slot, "modulate", Color.WHITE, 0.3)

## 浮动文本提示
func _show_float_text(text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", color)
	label.position = Vector2(350, 280)
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", 180, 1.2)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.2)
	tween.tween_callback(label.queue_free)

## 获取强化信息(供UI显示)
func _get_enhance_info() -> String:
	if current_item.is_empty():
		return ""

	var instance_id = current_item.get("instance_id", "")
	if instance_id == "" or not has_node("/root/EquipmentSystem"):
		return ""

	var instance = EquipmentSystem.get_equipment_instance(instance_id)
	if not instance:
		return ""

	var current_level = instance.get("enhance_level", 0)
	var config = ConfigLoader.get_balance_config().get("equipment_enhancement", {})
	var max_level = config.get("max_level", 15)

	if current_level >= max_level:
		return "已满级 +%d" % max_level

	# 计算成功率
	var rate = 1.0
	if current_level >= 10:
		rate = 0.4
	elif current_level >= 5:
		rate = 0.7

	# 计算消耗
	var rarity = instance.get("rarity", "common")
	var costs = config.get("costs", {}).get(rarity, {})
	var gold = costs.get("gold_base", 50) + int(costs.get("gold_per_level", 25) * current_level)
	var mat = int(costs.get("material_base", 1) + costs.get("material_per_level", 0.5) * current_level)

	return "强化 +%d → +%d\n成功率: %d%%\n消耗: %d金币 + %d材料" % [
		current_level, current_level + 1, int(rate * 100), gold, mat
	]
