extends Panel
## 背包面板 - 显示40格背包，支持装备/丢弃/存入仓库

const GRID_COLUMNS = 8
const SLOT_SIZE = 64

@onready var grid_container: GridContainer = $ScrollContainer/GridContainer
@onready var tooltip_panel: PanelContainer = $TooltipPanel
@onready var tooltip_label: RichTextLabel = $TooltipPanel/TooltipLabel

var slot_buttons: Array = []
var current_tooltip_instance_id: String = ""

signal equipment_equipped(instance_id: String)
signal equipment_discarded(instance_id: String)
signal equipment_to_warehouse(instance_id: String)

func _ready():
	hide()
	_setup_grid()
	Inventory.backpack_changed.connect(_refresh_backpack)
	_refresh_backpack()

func _input(event):
	if event.is_action_pressed("toggle_backpack"):
		toggle_visibility()

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

	# 创建40个格子按钮
	for i in range(Inventory.MAX_BACKPACK_SIZE):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
		btn.toggle_mode = false
		btn.set_meta("slot_index", i)
		btn.pressed.connect(_on_slot_clicked.bind(i))
		btn.mouse_entered.connect(_on_slot_hover_enter.bind(i))
		btn.mouse_exited.connect(_on_slot_hover_exit)
		grid_container.add_child(btn)
		slot_buttons.append(btn)

## 切换显示/隐藏
func toggle_visibility():
	visible = not visible
	if visible:
		_refresh_backpack()

## 刷新背包显示
func _refresh_backpack():
	for i in range(slot_buttons.size()):
		var btn = slot_buttons[i]
		if i < Inventory.backpack.size():
			var instance_id = Inventory.backpack[i]
			var item_data = Inventory.get_equipment_data(instance_id)
			_update_slot_button(btn, item_data, instance_id)
		else:
			_clear_slot_button(btn)

## 更新格子显示（显示图标和稀有度边框）
func _update_slot_button(btn: Button, item_data: Dictionary, instance_id: String):
	btn.set_meta("instance_id", instance_id)
	btn.text = ""

	# 设置图标
	var slot = item_data.get("slot", "weapon")
	var category = item_data.get("category", "sword")
	var rarity = item_data.get("rarity", "common")
	btn.icon = SpriteLibrary.get_equipment_icon(slot, category, rarity)

	# 稀有度边框颜色
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

## 格子点击事件（右键打开菜单）
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
	popup.add_item("装备", 0)
	popup.add_item("丢弃", 1)
	popup.add_item("存入仓库", 2)
	popup.id_pressed.connect(_on_context_menu_selected.bind(instance_id, popup))
	popup.popup(Rect2(pos, Vector2(120, 100)))

## 菜单选择
func _on_context_menu_selected(id: int, instance_id: String, popup: PopupMenu):
	match id:
		0: # 装备
			equipment_equipped.emit(instance_id)
			# PR-3: 走 equip_from_backpack —— 自动管理背包/穿戴实例转移
			if EquipmentSystem.equip_from_backpack(instance_id):
				var item_data = Inventory.get_equipment_data(instance_id)
				print("[BackpackPanel] 装备: %s" % item_data.get("display_name", ""))
		1: # 丢弃
			equipment_discarded.emit(instance_id)
			Inventory.destroy_equipment(instance_id)
			print("[BackpackPanel] 丢弃: %s" % instance_id)
		2: # 存入仓库
			if Inventory.transfer_to_warehouse(instance_id):
				equipment_to_warehouse.emit(instance_id)
				print("[BackpackPanel] 存入仓库: %s" % instance_id)
			else:
				print("[BackpackPanel] 仓库已满")
	popup.queue_free()

## 鼠标悬停显示tooltip
func _on_slot_hover_enter(slot_index: int):
	var btn = slot_buttons[slot_index]
	var instance_id = btn.get_meta("instance_id", "")
	if instance_id == "":
		return
	var item_data = Inventory.get_equipment_data(instance_id)
	_show_tooltip(item_data, instance_id)

func _on_slot_hover_exit():
	if tooltip_panel:
		tooltip_panel.hide()

## 显示装备tooltip
func _show_tooltip(item_data: Dictionary, instance_id: String):
	if not tooltip_panel or not tooltip_label:
		return
	var tooltip_text = EquipmentSystem.generate_tooltip(item_data)
	tooltip_label.text = tooltip_text
	tooltip_panel.show()
	# 跟随鼠标位置
	tooltip_panel.global_position = get_global_mouse_position() + Vector2(10, 10)


