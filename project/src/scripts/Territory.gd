extends Control
## 领地场景 - 可走动探索 + 走到建筑交互弹管理面板
##
## 玩家用 ExplorerActor 在领地里走动，走到建筑(InteractZone)按 E/左键 → 弹建造/升级面板。
## 面板逻辑从 Town.gd 搬运，保持后端调用一致（TerritorySystem）。

var _explorer: CharacterBody2D = null
var _territory_panel: Panel = null


func _ready():
	_setup_scene()
	_spawn_explorer()
	_spawn_buildings()


## 场景框架：顶栏 + 地图区 + 返回按钮
func _setup_scene():
	# 背景
	var bg = ColorRect.new()
	bg.name = "Background"
	bg.color = Color(0.08, 0.07, 0.09)
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
	title.text = "我的领地"
	title.position = Vector2(30, 20)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.9, 0.75, 0.2))
	top_bar.add_child(title)

	# 返回主城按钮
	var back_btn = Button.new()
	back_btn.text = "返回主城"
	back_btn.position = Vector2(1720, 20)
	back_btn.custom_minimum_size = Vector2(160, 50)
	back_btn.pressed.connect(_on_back_to_town)
	top_bar.add_child(back_btn)

	# 资源显示（金币/木材/石材/食物/居民）
	var res_label = Label.new()
	res_label.name = "ResourceLabel"
	res_label.position = Vector2(400, 25)
	res_label.add_theme_font_size_override("font_size", 20)
	top_bar.add_child(res_label)
	_update_resource_display()

	# 地图区（用于铺地板 + 放建筑）
	var map_area = Control.new()
	map_area.name = "MapArea"
	map_area.anchor_top = 0.08
	map_area.anchor_right = 1.0
	map_area.anchor_bottom = 1.0
	add_child(map_area)
	_tile_ground(map_area)


## 铺领地地板(territory tile)
func _tile_ground(parent: Node):
	var tile_tex = SpriteLibrary.get_tile("territory", false)
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


## 实例化探索玩家
func _spawn_explorer():
	var explorer_script = load("res://scripts/ExplorerActor.gd")
	_explorer = explorer_script.new()
	_explorer.global_position = Vector2(960, 540)
	$MapArea.add_child(_explorer)
	# 左键点地寻路（点击地图时设置目标）
	$MapArea.gui_input.connect(_on_map_input)


## 左键点地寻路
func _on_map_input(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _explorer:
			_explorer.set_click_target(event.position + $MapArea.global_position)


## 生成已建造建筑作为 InteractZone
func _spawn_buildings():
	var ts = get_node("/root/TerritorySystem")
	var buildings = ts.buildings
	var positions = {
		"townhall": Vector2(960, 300),
		"lumber_mill": Vector2(400, 400),
		"quarry": Vector2(700, 550),
		"farm": Vector2(1200, 400),
		"barracks": Vector2(500, 700),
		"watchtower": Vector2(1400, 600),
		"wall": Vector2(1600, 450),
	}
	for bid in buildings:
		var level = buildings[bid]
		if level <= 0:
			continue
		var pos = positions.get(bid, Vector2(960, 600))
		var def = _get_building_def(bid)
		var icon_tex = _load_building_sprite(bid)
		var zone_script = load("res://scripts/InteractZone.gd")
		var zone = zone_script.new()
		zone.global_position = pos
		zone.setup(icon_tex, def.get("display_name", bid), {"building_id": bid}, 80.0)
		zone.interacted.connect(_on_building_interacted)
		$MapArea.add_child(zone)


func _get_building_def(bid: String) -> Dictionary:
	var all_def = ConfigLoader.territory_data.get("buildings", [])
	for d in all_def:
		if d.get("id", "") == bid:
			return d
	return {}


func _load_building_sprite(bid: String) -> Texture2D:
	var path = "res://assets/generated/scene/build_%s.png" % bid
	if ResourceLoader.exists(path):
		return load(path)
	return null


## 走到建筑交互：弹建造/升级面板（复用 Town 逻辑）
func _on_building_interacted(payload: Dictionary):
	var bid = payload.get("building_id", "")
	if bid == "":
		return
	_show_building_panel(bid)


## 建筑管理面板（精简版，只显示升级/建造按钮+当前等级）
func _show_building_panel(bid: String):
	if _territory_panel and is_instance_valid(_territory_panel):
		_territory_panel.queue_free()
	_territory_panel = Panel.new()
	_territory_panel.custom_minimum_size = Vector2(600, 400)
	_territory_panel.position = Vector2(660, 300)
	add_child(_territory_panel)
	var def = _get_building_def(bid)
	var ts = get_node("/root/TerritorySystem")
	var cur_lv = ts.get_building_level(bid)

	var title = Label.new()
	title.text = "%s (Lv.%d)" % [def.get("display_name", bid), cur_lv]
	title.position = Vector2(20, 20)
	title.add_theme_font_size_override("font_size", 24)
	_territory_panel.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(540, 20)
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(func(): _territory_panel.queue_free())
	_territory_panel.add_child(close_btn)

	# 升级按钮
	var up_btn = Button.new()
	up_btn.position = Vector2(50, 120)
	up_btn.custom_minimum_size = Vector2(200, 60)
	var cost = ts.get_upgrade_cost(bid)
	if not cost.is_empty():
		up_btn.text = "升级 Lv.%d\n%s" % [cur_lv + 1, _format_cost(cost)]
		up_btn.disabled = not ts.can_afford(cost)
		up_btn.pressed.connect(func(): _on_upgrade(bid))
	else:
		up_btn.text = "已满级"
		up_btn.disabled = true
	_territory_panel.add_child(up_btn)


func _on_upgrade(bid: String):
	var ts = get_node("/root/TerritorySystem")
	ts.upgrade_building(bid)
	_update_resource_display()
	if _territory_panel:
		_territory_panel.queue_free()
	_spawn_buildings()  # 刷新建筑列表


func _format_cost(cost: Dictionary) -> String:
	var parts = []
	for mat in cost:
		var name = _material_name(mat)
		parts.append("%s:%d" % [name, cost[mat]])
	return "  ".join(parts)


func _material_name(mid: String) -> String:
	match mid:
		"timber":
			return "木材"
		"stone_block":
			return "石材"
		"food":
			return "食物"
		_:
			return mid


func _update_resource_display():
	var res_label = $TopBar/ResourceLabel
	if not res_label:
		return
	var gs = get_node("/root/GameState")
	var ts = get_node("/root/TerritorySystem")
	res_label.text = (
		"金币:%d  木材:%d  石材:%d  食物:%d  居民:%d/%d"
		% [
			gs.total_gold,
			gs.get_material("timber"),
			gs.get_material("stone_block"),
			gs.get_material("food"),
			ts.resident_count(),
			ts.get_resident_cap(),
		]
	)


func _on_back_to_town():
	get_tree().change_scene_to_file("res://scenes/Town.tscn")
