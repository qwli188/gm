extends Panel
## 仓库面板 - 显示100格仓库，只能在城镇打开

const GRID_COLUMNS = 10
const SLOT_SIZE = 64

@onready var grid_container: GridContainer = $ScrollContainer/GridContainer
@onready var tooltip_panel: PanelContainer = $TooltipPanel
@onready var tooltip_label: RichTextLabel = $TooltipPanel/TooltipLabel

var slot_buttons: Array = []

signal equipment_to_backpack(instance_id: String)

func _ready():
	hide()
	_setup_grid()
	Inventory.warehouse_changed.connect(_refresh_warehouse)

## 设置格子网格
func _setup_grid():
	if not grid_container:
		grid_container = GridContainer.new()
		grid_container.columns = GRID_COLUMNS
		var scroll = ScrollContainer.new()
		scroll.name = "ScrollContainer"
		add_child(scroll)
		scroll.add_child(grid_container)

	grid_container.columns = GRID_COLUMNS

	# 创建100个格子
	for i in range(Inventory.MAX_WAREHOUSE_SIZE):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.set_meta("slot_index", i)
		btn.pressed.connect(_on_slot_clicked.bind(i))
		btn.mouse_entered.connect(_on_slot_hover_enter.bind(i))
		btn.mouse_exited.connect(_on_slot_hover_exit)
		grid_container.add_child(btn)
		slot_buttons.append(btn)

## 打开仓库（只能在城镇）
func open_warehouse():
	_refresh_warehouse()
	show()

## 关闭仓库
func close_warehouse():
	hide()

## 刷新仓库显示
func _refresh_warehouse():
	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		if i < Inventory.warehouse.size():
			var instance_id = Inventory.warehouse[i]
			var item_data = Inventory.get_equipment_data(instance_id)
			_update_slot_button(btn, item_data, instance_id)
		else:
			_clear_slot_button(btn)

## 更新格子显示
func _update_slot_button(btn: Button, item_data: Dictionary, instance_id: String):
	btn.set_meta("instance_id", instance_id)
	btn.text = ""

	var slot = item_data.get("slot", "weapon")
	var category = item_data.get("category", "sword")
	var rarity = item_data.get("rarity", "common")
	btn.icon = SpriteLibrary.get_equipment_icon(slot, category, rarity)

	var color = EquipmentSystem.get_rarity_color(rarity)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.2, 0.2, 0.9)
	style.border_color = color
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	btn.add_theme_stylebox_override("normal", style)

## 清空格子
func _clear_slot_button(btn: Button):
	btn.text = "空"
	btn.icon = null
	btn.set_meta("instance_id", "")
	btn.remove_theme_stylebox_override("normal")

## 格子点击事件
func _on_slot_clicked(slot_index: int):
	var btn = slot_buttons[slot_index]
	var instance_id = btn.get_meta("instance_id", "")
	if instance_id == "":
		return
	_show_context_menu(instance_id, btn.global_position)

## 显示右键菜单
func _show_context_menu(instance_id: String, pos: Vector2):
	var popup = PopupMenu.new()
	add_child(popup)
	popup.add_item("取到背包", 0)
	popup.id_pressed.connect(_on_context_menu_selected.bind(instance_id, popup))
	popup.popup(Rect2(pos, Vector2(120, 60)))

## 菜单选择
func _on_context_menu_selected(id: int, instance_id: String, popup: PopupMenu):
	if id == 0: # 取到背包
		if Inventory.transfer_to_backpack(instance_id):
			equipment_to_backpack.emit(instance_id)
			print("[WarehousePanel] 取到背包: %s" % instance_id)
		else:
			print("[WarehousePanel] 背包已满")
	popup.queue_free()

## 鼠标悬停显示tooltip
func _on_slot_hover_enter(slot_index: int):
	var btn = slot_buttons[slot_index]
	var instance_id = btn.get_meta("instance_id", "")
	if instance_id == "":
		return
	var item_data = Inventory.get_equipment_data(instance_id)
	_show_tooltip(item_data)

func _on_slot_hover_exit():
	if tooltip_panel:
		tooltip_panel.hide()

## 显示装备tooltip
func _show_tooltip(item_data: Dictionary):
	if not tooltip_panel or not tooltip_label:
		return
	var tooltip_text = EquipmentSystem.generate_tooltip(item_data)
	tooltip_label.text = tooltip_text
	tooltip_panel.show()
	tooltip_panel.global_position = get_global_mouse_position() + Vector2(10, 10)

