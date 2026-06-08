extends Control
## SaveLoadMenu - 存档/读档界面
## 显示3个存档槽位，支持新游戏/加载/删除

signal slot_selected(slot_id: int, is_new_game: bool)

@onready var slot_container = $VBoxContainer/SlotContainer

func _ready():
	_refresh_slots()

## 刷新存档槽位显示
func _refresh_slots():
	if not has_node("/root/SaveSystem"):
		return
	var slots = get_node("/root/SaveSystem").get_save_slots()

	# 清空旧的槽位按钮
	if slot_container:
		for child in slot_container.get_children():
			child.queue_free()

	# 为每个槽位创建按钮
	for slot_info in slots:
		var slot_id = slot_info.get("slot_id", 1)
		var exists = slot_info.get("exists", false)

		var slot_panel = _create_slot_panel(slot_id, slot_info, exists)
		if slot_container:
			slot_container.add_child(slot_panel)

## 创建单个槽位面板
func _create_slot_panel(slot_id: int, slot_info: Dictionary, exists: bool) -> Panel:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(400, 100)

	var vbox = VBoxContainer.new()
	vbox.position = Vector2(10, 10)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "存档槽位 %d" % slot_id
	title.add_theme_font_size_override("font_size", 20)
	vbox.add_child(title)

	if exists:
		var corrupted = slot_info.get("corrupted", false)
		if corrupted:
			var info_label = Label.new()
			info_label.text = "（存档损坏）"
			info_label.add_theme_color_override("font_color", Color.RED)
			vbox.add_child(info_label)
		else:
			var class_id = slot_info.get("class_id", "?")
			var level = slot_info.get("level", 1)
			var gold = slot_info.get("gold", 0)
			var info_label = Label.new()
			info_label.text = "职业: %s | 等级: %d | 金币: %d" % [class_id, level, gold]
			vbox.add_child(info_label)

		# 按钮行
		var btn_hbox = HBoxContainer.new()
		vbox.add_child(btn_hbox)

		var load_btn = Button.new()
		load_btn.text = "加载"
		load_btn.pressed.connect(_on_load_pressed.bind(slot_id))
		btn_hbox.add_child(load_btn)

		var delete_btn = Button.new()
		delete_btn.text = "删除"
		delete_btn.pressed.connect(_on_delete_pressed.bind(slot_id))
		btn_hbox.add_child(delete_btn)
	else:
		var info_label = Label.new()
		info_label.text = "（空槽位）"
		vbox.add_child(info_label)

		var new_btn = Button.new()
		new_btn.text = "新游戏"
		new_btn.pressed.connect(_on_new_game_pressed.bind(slot_id))
		vbox.add_child(new_btn)

	return panel

## 加载存档
func _on_load_pressed(slot_id: int):
	if not has_node("/root/SaveSystem"):
		return
	var success = get_node("/root/SaveSystem").load_game(slot_id)
	if success:
		slot_selected.emit(slot_id, false)
		print("[SaveLoadMenu] 加载存档: 槽位 %d" % slot_id)
	else:
		print("[SaveLoadMenu] 加载失败: 槽位 %d" % slot_id)

## 删除存档
func _on_delete_pressed(slot_id: int):
	if not has_node("/root/SaveSystem"):
		return
	var success = get_node("/root/SaveSystem").delete_save(slot_id)
	if success:
		_refresh_slots()
		print("[SaveLoadMenu] 删除存档: 槽位 %d" % slot_id)

## 新游戏
func _on_new_game_pressed(slot_id: int):
	slot_selected.emit(slot_id, true)
	print("[SaveLoadMenu] 新游戏: 槽位 %d" % slot_id)

