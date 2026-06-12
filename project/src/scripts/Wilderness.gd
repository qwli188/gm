extends Control
## 野外探索场景 - 采集/遭遇/传送门的可走动地图
##
## WildernessSystem.generate_layout() 生成事件点 + 副本传送门，本场景实例化为 InteractZone。
## 玩家用 ExplorerActor 走动，触发事件点 → 结算奖励；触发传送门 → 弹副本选择面板。

var _explorer: CharacterBody2D = null
var _dungeon_panel: Panel = null


func _ready():
	_setup_scene()
	_spawn_explorer()
	_generate_and_spawn_layout()


func _setup_scene():
	# 背景
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.06, 0.055, 0.065)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	add_child(bg)

	# 顶栏
	var top_bar = Panel.new()
	top_bar.name = "TopBar"
	top_bar.custom_minimum_size = Vector2(0, 80)
	top_bar.anchor_right = 1.0
	add_child(top_bar)
	var title = Label.new()
	title.text = "野外·辛陵平原"
	title.position = Vector2(30, 20)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.85, 0.8, 0.6))
	top_bar.add_child(title)

	var back_btn = Button.new()
	back_btn.text = "返回主城"
	back_btn.position = Vector2(1720, 20)
	back_btn.custom_minimum_size = Vector2(160, 50)
	back_btn.pressed.connect(_on_back_to_town)
	top_bar.add_child(back_btn)

	# 地图区
	var map_area = Control.new()
	map_area.name = "MapArea"
	map_area.anchor_top = 0.08
	map_area.anchor_right = 1.0
	map_area.anchor_bottom = 1.0
	add_child(map_area)
	_tile_ground(map_area)


func _tile_ground(parent: Node):
	var tile_tex = SpriteLibrary.get_tile("wild", false)
	if tile_tex == null:
		return
	var vp = Vector2(1920, 920)
	var ts = 64
	var holder = Node2D.new()
	holder.name = "GroundTiles"
	holder.z_index = -20
	parent.add_child(holder)
	for y in range(0, int(vp.y) + ts, ts):
		for x in range(0, int(vp.x) + ts, ts):
			var s = Sprite2D.new()
			s.texture = tile_tex
			s.centered = false
			s.position = Vector2(x, y)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			holder.add_child(s)


func _spawn_explorer():
	var explorer_script = load("res://scripts/ExplorerActor.gd")
	_explorer = explorer_script.new()
	_explorer.global_position = Vector2(200, 500)
	$MapArea.add_child(_explorer)
	$MapArea.gui_input.connect(_on_map_input)


func _on_map_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _explorer:
			_explorer.set_click_target(event.position + $MapArea.global_position)


## 生成布局（传送门 + 事件点）
func _generate_and_spawn_layout():
	var ws = get_node("/root/WildernessSystem")
	var layout = ws.generate_layout()
	var zone_script = load("res://scripts/InteractZone.gd")

	for entry in layout:
		var cat = entry.get("category", "")
		var pos = entry.get("pos", Vector2.ZERO)
		var zone = zone_script.new()
		zone.global_position = pos

		if cat == "portal":
			var dungeon = entry.get("dungeon", {})
			var region = dungeon.get("region", "field")
			var icon_tex = _load_portal_sprite(region)
			var label = "%s" % dungeon.get("display_name", "副本")
			zone.setup(icon_tex, label, {"category": "portal", "dungeon": dungeon}, 90.0)
			zone.interacted.connect(_on_portal_interacted)
		elif cat == "event":
			var def = entry.get("def", {})
			var sprite_id = def.get("sprite", "wild_herb")
			var icon_tex = _load_wild_sprite(sprite_id)
			var label = def.get("display_name", "事件点")
			zone.setup(
				icon_tex,
				label,
				{"category": "event", "def": def, "point_id": entry.get("point_id", "")},
				70.0
			)
			zone.interacted.connect(_on_event_interacted)

		$MapArea.add_child(zone)


func _load_portal_sprite(region: String) -> Texture2D:
	var path = "res://assets/generated/scene/portal_%s.png" % region
	if ResourceLoader.exists(path):
		return load(path)
	return null


func _load_wild_sprite(sprite_id: String) -> Texture2D:
	var path = "res://assets/generated/scene/%s.png" % sprite_id
	if ResourceLoader.exists(path):
		return load(path)
	return null


## 副本传送门交互：弹副本选择面板（组队+词缀+难度+启动）
func _on_portal_interacted(payload: Dictionary):
	var dungeon = payload.get("dungeon", {})
	if dungeon.is_empty():
		return
	_show_dungeon_panel(dungeon)


func _show_dungeon_panel(dungeon: Dictionary):
	if _dungeon_panel and is_instance_valid(_dungeon_panel):
		_dungeon_panel.queue_free()
	_dungeon_panel = Panel.new()
	_dungeon_panel.custom_minimum_size = Vector2(700, 500)
	_dungeon_panel.position = Vector2(610, 290)
	add_child(_dungeon_panel)

	var title = Label.new()
	title.text = dungeon.get("display_name", "副本")
	title.position = Vector2(20, 20)
	title.add_theme_font_size_override("font_size", 28)
	_dungeon_panel.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(640, 20)
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(func(): _dungeon_panel.queue_free())
	_dungeon_panel.add_child(close_btn)

	# 启动按钮（暂时简化：直接进副本，不选难度/词缀）
	var start_btn = Button.new()
	start_btn.text = "进入副本"
	start_btn.position = Vector2(50, 400)
	start_btn.custom_minimum_size = Vector2(200, 60)
	start_btn.pressed.connect(func(): _start_dungeon(dungeon.get("id", "")))
	_dungeon_panel.add_child(start_btn)

	# TODO: 组队/词缀/难度选择（复用 Town 的 DungeonPanel 逻辑）


func _start_dungeon(dungeon_id: String):
	if dungeon_id == "":
		return
	if has_node("/root/GameState"):
		get_node("/root/GameState").current_dungeon = dungeon_id
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## 野外事件点交互：结算奖励 + 弹结果提示
func _on_event_interacted(payload: Dictionary):
	var def = payload.get("def", {})
	var kind = def.get("id", "")
	var zone_node = null
	# 找到触发的 zone（通过信号 sender，Godot 4.x 用 signal.get_object())
	# 简化：用 point_id 标记，触发后销毁
	var point_id = payload.get("point_id", "")

	if kind == "merchant":
		_show_merchant_panel()
		return

	var ws = get_node("/root/WildernessSystem")
	var lines = []
	if kind == "lair":
		var result = ws.resolve_encounter(def)
		lines = result.get("lines", [])
	else:
		lines = ws.resolve_gather(def)

	_show_result_popup(lines)
	# 触发后移除该事件点（采集/藏宝/遗迹/怪窝都是一次性）
	_remove_event_zone(point_id)
	SaveSystem.mark_dirty()


func _remove_event_zone(point_id: String):
	for child in $MapArea.get_children():
		if child.has_method("get") and child.get("name") == point_id:
			child.queue_free()
			return


func _show_result_popup(lines: Array):
	var popup = Panel.new()
	popup.custom_minimum_size = Vector2(500, 300)
	popup.position = Vector2(710, 390)
	add_child(popup)
	var content = RichTextLabel.new()
	content.bbcode_enabled = true
	content.position = Vector2(20, 20)
	content.custom_minimum_size = Vector2(460, 220)
	var text = "\n".join(lines)
	content.text = "[center]%s[/center]" % text
	popup.add_child(content)
	var close_btn = Button.new()
	close_btn.text = "确定"
	close_btn.position = Vector2(200, 250)
	close_btn.custom_minimum_size = Vector2(100, 40)
	close_btn.pressed.connect(func(): popup.queue_free())
	popup.add_child(close_btn)


func _show_merchant_panel():
	# TODO: 打开流浪商人面板（复用 Town 的商人逻辑）
	_show_result_popup(["遇到流浪商人！（商人面板尚未接线）"])


func _on_back_to_town():
	get_tree().change_scene_to_file("res://scenes/Town.tscn")
