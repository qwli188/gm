extends Panel
## 词缀工坊界面 - 装备洗练/分解

@onready var item_slot: Panel = $VBox/ItemSlot
@onready var item_name_label: Label = $VBox/ItemSlot/ItemName
@onready var affix_list: VBoxContainer = $VBox/ScrollContainer/AffixList
@onready var cost_label: Label = $VBox/CostInfo
@onready var reforge_button: Button = $VBox/ButtonRow/ReforgeButton
@onready var dismantle_button: Button = $VBox/ButtonRow/DismantleButton
@onready var close_button: Button = $VBox/CloseButton

var current_item: Dictionary = {}
var current_item_index: int = -1
var locked_affixes: Array[int] = []

func _ready():
	close_button.pressed.connect(_on_close_pressed)
	reforge_button.pressed.connect(_on_reforge_pressed)
	dismantle_button.pressed.connect(_on_dismantle_pressed)
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

