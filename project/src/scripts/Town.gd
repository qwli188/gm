extends Control
## 新手村/主城场景 - 可视化地图界面

@onready var player_sprite: Sprite2D = $WorldMap/PlayerMarker
@onready var gold_label: Label = $TopBar/GoldLabel
@onready var class_label: Label = $TopBar/ClassLabel
@onready var level_label: Label = $TopBar/LevelLabel
@onready var upgrade_panel: Panel = $Panels/UpgradePanel
@onready var dungeon_panel: Panel = $Panels/DungeonPanel
@onready var info_label: RichTextLabel = $BottomBar/InfoLabel

const SPRITE_SHEET = preload("res://assets/sprites/roguelike/roguelikeSheet_transparent.png")

var current_view: String = "town"  # town, upgrade, dungeon


func _ready():
	_setup_visuals()
	_refresh_ui()
	_create_town_locations()
	# 模块6: 首次进入教学提示
	_show_tutorial_if_needed()
	# 阶段1: 自动装备职业技能到槽位
	_equip_class_skills()
	# BGM: 城镇音乐
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_bgm("town")


## 设置视觉效果
func _setup_visuals():
	# 设置玩家标记精灵
	if player_sprite:
		player_sprite.texture = SPRITE_SHEET
		player_sprite.region_enabled = true
		var cls = GameState.get_current_class()
		var region = cls.get("sprite_region", [425, 408, 16, 16])
		player_sprite.region_rect = Rect2(region[0], region[1], region[2], region[3])
		player_sprite.scale = Vector2(4, 4)


## 刷新UI显示
func _refresh_ui():
	gold_label.text = "金币: %d" % GameState.total_gold
	var cls = GameState.get_current_class()
	# 多角色：标题显示操控角色名 + 职业
	var char_name = ""
	if has_node("/root/RosterSystem"):
		var active = get_node("/root/RosterSystem").get_active_character()
		char_name = active.get("name", "")
	if char_name != "":
		class_label.text = "%s (%s)" % [char_name, cls.get("display_name", "?")]
	else:
		class_label.text = "职业: %s" % cls.get("display_name", "未选择")
	var lvl = 1
	if has_node("/root/RosterSystem"):
		lvl = get_node("/root/RosterSystem").get_active_character().get("level", 1)
	level_label.text = "等级: %d" % lvl

	info_label.text = "[center][color=yellow]欢迎来到黎明堡[/color]\n点击地图上的建筑进行交互[/center]"


## 创建城镇交互点
func _create_town_locations():
	var world_map = $WorldMap

	# 铺地块地面（town 主题）
	_tile_ground(world_map)

	# 建筑布局：图标 + 名称 + 主题色
	var buildings = [
		{
			pos = Vector2(220, 420),
			name = "铁匠铺",
			color = Color(1, 0.6, 0.2),
			icon = "obstacle_forge",
			cb = _on_blacksmith_clicked
		},
		{
			pos = Vector2(530, 420),
			name = "副本入口",
			color = Color(0.6, 0.3, 1),
			icon = "obstacle_void",
			cb = _on_dungeon_portal_clicked
		},
		{
			pos = Vector2(840, 420),
			name = "商店",
			color = Color(0.3, 0.8, 0.3),
			icon = "obstacle_field",
			cb = _on_shop_clicked
		},
		{
			pos = Vector2(1150, 420),
			name = "城外野区",
			color = Color(0.8, 0.2, 0.2),
			icon = "obstacle_crypt",
			cb = _on_wilderness_clicked
		},
		{
			pos = Vector2(1460, 420),
			name = "我的领地",
			color = Color(0.9, 0.75, 0.2),
			icon = "obstacle_forge",
			cb = _on_territory_clicked
		},
		{
			pos = Vector2(1700, 420),
			name = "角色管理",
			color = Color(0.2, 0.6, 0.9),
			icon = "obstacle_ice",
			cb = _on_roster_clicked
		},
		{
			pos = Vector2(220, 640),
			name = "训练场",
			color = Color(0.6, 0.3, 0.8),
			icon = "obstacle_void",
			cb = _on_training_ground_clicked
		},
		{
			pos = Vector2(530, 640),
			name = "成就",
			color = Color(1, 0.7, 0.2),
			icon = "obstacle_field",
			cb = _on_achievement_clicked
		},
	]
	for b in buildings:
		var marker = _create_location_marker(b.pos, b.name, b.color, b.icon)
		marker.pressed.connect(b.cb)
		world_map.add_child(marker)


## 用 town 地块铺满地图背景
func _tile_ground(parent: Node):
	var tile_tex = SpriteLibrary.get_tile("town", false)
	if tile_tex == null:
		return
	var vp = Vector2(1920, 800)
	var ts = 64
	var holder = Node2D.new()
	holder.name = "GroundTiles"
	holder.z_index = -20
	parent.add_child(holder)
	parent.move_child(holder, 0)
	for y in range(0, int(vp.y) + ts, ts):
		for x in range(0, int(vp.x) + ts, ts):
			var s = Sprite2D.new()
			s.texture = tile_tex
			s.centered = false
			s.position = Vector2(x, y)
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			holder.add_child(s)


## 创建位置标记（建筑图标 + 圆形按钮）
func _create_location_marker(
	pos: Vector2, label_text: String, marker_color: Color, icon_name: String = ""
) -> Button:
	var button = Button.new()
	button.position = pos
	button.custom_minimum_size = Vector2(140, 140)
	button.size = Vector2(140, 140)
	button.text = label_text
	button.autowrap_mode = TextServer.AUTOWRAP_WORD
	button.clip_text = false

	# 建筑图标（放在按钮上方）
	if icon_name != "":
		var icon_tex = SpriteLibrary.get_ui(icon_name)  # 占位
		if icon_tex == null:
			icon_tex = (
				load("res://assets/generated/tiles/%s.png" % icon_name)
				if ResourceLoader.exists("res://assets/generated/tiles/%s.png" % icon_name)
				else null
			)
		if icon_tex:
			var icon = TextureRect.new()
			icon.texture = icon_tex
			icon.custom_minimum_size = Vector2(80, 80)
			icon.size = Vector2(80, 80)
			icon.position = Vector2(30, -90)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			button.add_child(icon)

	# 样式
	var style_normal = StyleBoxFlat.new()
	style_normal.bg_color = marker_color
	style_normal.set_border_width_all(3)
	style_normal.border_color = Color.WHITE
	style_normal.set_corner_radius_all(70)

	var style_hover = StyleBoxFlat.new()
	style_hover.bg_color = marker_color.lightened(0.2)
	style_hover.set_border_width_all(4)
	style_hover.border_color = Color.YELLOW
	style_hover.set_corner_radius_all(70)
	style_hover.shadow_size = 12
	style_hover.shadow_color = marker_color

	button.add_theme_stylebox_override("normal", style_normal)
	button.add_theme_stylebox_override("hover", style_hover)
	button.add_theme_stylebox_override("pressed", style_hover)
	button.add_theme_font_size_override("font_size", 20)

	return button


## 铁匠铺点击
func _on_blacksmith_clicked():
	upgrade_panel.visible = true
	dungeon_panel.visible = false
	_build_upgrade_list()
	info_label.text = "[center][color=orange]铁匠铺 - 永久强化[/color]\n使用金币提升基础属性\n\n[color=yellow]装备强化系统[/color]\n词缀工坊可强化装备(+0到+15)\n每+1增加基础属性10%\n消耗金币+区域材料，有成功率[/center]"  # gdlint:ignore=max-line-length


## 副本入口点击
func _on_dungeon_portal_clicked():
	upgrade_panel.visible = false
	dungeon_panel.visible = false
	if _roster_panel and is_instance_valid(_roster_panel):
		_roster_panel.visible = false
	if _territory_panel and is_instance_valid(_territory_panel):
		_territory_panel.visible = false
	# P2: 先打开组队面板
	_ensure_party_panel()
	_party_panel.visible = true
	_build_party_view()
	info_label.text = '[center][color=violet]选择随行队友[/color]\n最多3人，选好后点击"进入副本"[/center]'


## 商店点击
func _on_shop_clicked():
	_hide_all_panels()
	_ensure_merchant_panel()
	_merchant_panel.visible = true
	_build_merchant_view()
	info_label.text = "[center][color=green]流浪商人[/color]\n购买装备与材料[/center]"


## 城外野区点击
func _on_wilderness_clicked():
	upgrade_panel.visible = false
	dungeon_panel.visible = false
	if _roster_panel and is_instance_valid(_roster_panel):
		_roster_panel.visible = false
	if _territory_panel and is_instance_valid(_territory_panel):
		_territory_panel.visible = false
	if _party_panel and is_instance_valid(_party_panel):
		_party_panel.visible = false
	# P5: 触发随机野外事件
	_trigger_wilderness_event()


## 构建升级列表
func _build_upgrade_list():
	var container = upgrade_panel.get_node("ScrollContainer/VBoxContainer")

	# 清空
	for child in container.get_children():
		child.queue_free()

	var meta = ConfigLoader.balance_data.get("meta_progression", {})
	for stat in meta.get("stats", []):
		var row = _make_upgrade_row(stat)
		container.add_child(row)


func _make_upgrade_row(stat: Dictionary) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	var sid = stat.get("id", "")
	var cur_level = GameState.meta_upgrades.get(sid, 0)
	var max_level = stat.get("max_level", 10)
	var cost = _calc_cost(stat, cur_level)

	var name_lbl = Label.new()
	name_lbl.custom_minimum_size = Vector2(200, 0)
	name_lbl.text = "%s  Lv.%d/%d" % [stat.get("display_name", sid), cur_level, max_level]
	name_lbl.add_theme_font_size_override("font_size", 20)
	row.add_child(name_lbl)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(150, 50)
	if cur_level >= max_level:
		btn.text = "已满级"
		btn.disabled = true
	else:
		btn.text = "升级 (%d金)" % cost
		btn.disabled = GameState.total_gold < cost
		btn.pressed.connect(_on_upgrade_pressed.bind(sid))
	btn.add_theme_font_size_override("font_size", 18)
	row.add_child(btn)

	return row


func _calc_cost(stat: Dictionary, level: int) -> int:
	var curve = stat.get("cost_curve", {})
	var base = curve.get("base", 50)
	var growth = curve.get("growth", 1.3)
	return int(base * pow(growth, level))


func _on_upgrade_pressed(stat_id: String):
	var meta = ConfigLoader.balance_data.get("meta_progression", {})
	var stat = {}
	for s in meta.get("stats", []):
		if s.get("id", "") == stat_id:
			stat = s
			break
	if stat.is_empty():
		return

	var cur_level = GameState.meta_upgrades.get(stat_id, 0)
	var cost = _calc_cost(stat, cur_level)
	if GameState.total_gold < cost:
		return

	GameState.total_gold -= cost
	GameState.meta_upgrades[stat_id] = cur_level + 1

	_refresh_ui()
	_build_upgrade_list()


## 构建副本列表
func _build_dungeon_list():
	var container = dungeon_panel.get_node("ScrollContainer/VBoxContainer")

	# 清空
	for child in container.get_children():
		child.queue_free()

	var dungeons = ConfigLoader.get_all_dungeons()

	# 按区域分组
	var regions = {}
	for dungeon in dungeons:
		var region = dungeon.get("region", "unknown")
		if not regions.has(region):
			regions[region] = []
		regions[region].append(dungeon)

	# 显示每个区域
	for region_id in regions:
		var region_label = Label.new()
		region_label.text = _get_region_name(region_id)
		region_label.add_theme_font_size_override("font_size", 24)
		region_label.add_theme_color_override("font_color", Color(1, 0.8, 0.3))
		container.add_child(region_label)

		for dungeon in regions[region_id]:
			var btn = _make_dungeon_button(dungeon)
			container.add_child(btn)

		# 分隔线
		var separator = HSeparator.new()
		container.add_child(separator)


func _make_dungeon_button(dungeon: Dictionary) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(0, 60)

	var name = dungeon.get("display_name", "未命名副本")
	var tiers = dungeon.get("difficulty_tiers", [])
	var tier_name = "普通"
	if tiers.size() > 0:
		tier_name = tiers[0].get("display_name", "普通")
	var set_drop = dungeon.get("set_drop", "")
	var set_hint = ""
	if set_drop != "":
		var set_data = ConfigLoader.get_set_by_id(set_drop)
		if not set_data.is_empty():
			set_hint = "  [掉落:%s]" % set_data.get("display_name", "")

	btn.text = "%s (%s)%s" % [name, tier_name, set_hint]
	btn.add_theme_font_size_override("font_size", 20)
	btn.pressed.connect(_on_dungeon_selected.bind(dungeon.get("id", "")))

	return btn


func _get_region_name(region_id: String) -> String:
	var names = {
		"crypt": "枯骨王陵",
		"swamp": "腐沼疫地",
		"forge": "熔火深渊",
		"ice": "冰封王座",
		"void": "虚空裂隙",
		"field": "城外野区"
	}
	return names.get(region_id, region_id)


func _on_dungeon_selected(dungeon_id: String):
	GameState.enter_dungeon(dungeon_id, 1)
	# 进入战斗场景
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _on_close_upgrade_panel():
	upgrade_panel.visible = false


func _on_close_dungeon_panel():
	dungeon_panel.visible = false


# ============================================================
# 模块6: 教学引导 (简化版)
# ============================================================


func _show_tutorial_if_needed():
	# 检查是否首次进入
	if GameState.tutorial_completed:
		return

	# 显示教学文本
	info_label.text = """[center][color=yellow]🎮 新手引导 🎮[/color]

[color=lime]欢迎来到黎明堡！[/color]

[color=white]基础操作:[/color]
• WASD - 移动
• 鼠标左键 - 攻击 (可切换自动攻击)
• 空格 - 闪避 (无敌帧)
• R键 - 职业技能 (战士怒气/骑士圣盾)
• Q键 - 打开背包
• E键 - 拾取/交互

[color=white]城镇功能:[/color]
• [color=orange]铁匠铺[/color] - 永久升级基础属性
• [color=purple]副本传送门[/color] - 进入6大区域战斗
• [color=yellow]词缀工坊[/color] - 洗练/分解/强化装备

[color=lime]点击任意建筑开始探索！[/color][/center]"""

	# 标记已查看
	GameState.tutorial_completed = true


# ============================================================
# 多角色：角色管理面板（程序化构建，避免改 .tscn）
# ============================================================

var _roster_panel: Panel = null


func _on_roster_clicked():
	upgrade_panel.visible = false
	dungeon_panel.visible = false
	_ensure_roster_panel()
	_roster_panel.visible = true
	_build_roster_list()
	info_label.text = "[center][color=aqua]角色管理[/color]\n切换操控角色 / 创建新角色\n其余角色可停驻领地或随队出击[/center]"


## 懒创建角色管理面板（首次点击时构建节点树）
func _ensure_roster_panel():
	if _roster_panel != null and is_instance_valid(_roster_panel):
		return
	var panel = Panel.new()
	panel.name = "RosterPanel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(700, 600)
	panel.size = Vector2(700, 600)
	panel.position = Vector2(610, 240)

	var title = Label.new()
	title.text = "角色管理"
	title.position = Vector2(20, 15)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.4, 0.8, 1))
	panel.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(640, 15)
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(func(): _roster_panel.visible = false)
	panel.add_child(close_btn)

	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.position = Vector2(20, 70)
	scroll.custom_minimum_size = Vector2(660, 460)
	scroll.size = Vector2(660, 460)
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 12)
	vbox.custom_minimum_size = Vector2(640, 0)
	scroll.add_child(vbox)
	panel.add_child(scroll)

	# 创建新角色按钮（跳到职业选择，复用现有界面）
	var create_btn = Button.new()
	create_btn.name = "CreateButton"
	create_btn.text = "+ 创建新角色"
	create_btn.position = Vector2(20, 540)
	create_btn.custom_minimum_size = Vector2(660, 45)
	create_btn.add_theme_font_size_override("font_size", 20)
	create_btn.pressed.connect(_on_create_character_pressed)
	panel.add_child(create_btn)

	$Panels.add_child(panel)
	_roster_panel = panel


## 构建角色列表
func _build_roster_list():
	if not has_node("/root/RosterSystem"):
		return
	var rs = get_node("/root/RosterSystem")
	var container = _roster_panel.get_node("ScrollContainer/VBoxContainer")
	for child in container.get_children():
		child.queue_free()

	var active_id = rs.active_char_id
	for c in rs.characters:
		container.add_child(_make_roster_row(c, c.get("char_id", "") == active_id))

	# 满员提示 + 禁用创建按钮
	var create_btn = _roster_panel.get_node("CreateButton")
	if rs.is_full():
		create_btn.text = "角色已满 (%d/%d)" % [rs.character_count(), rs.MAX_CHARACTERS]
		create_btn.disabled = true
	else:
		create_btn.text = "+ 创建新角色 (%d/%d)" % [rs.character_count(), rs.MAX_CHARACTERS]
		create_btn.disabled = false

	# A6: BD 预设区（如果有 BuildPresets 节点）
	_build_bd_presets_section()


func _make_roster_row(character: Dictionary, is_active: bool) -> PanelContainer:
	var row = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.28, 0.35) if is_active else Color(0.15, 0.15, 0.2)
	style.set_border_width_all(2)
	style.border_color = Color(1, 0.85, 0.3) if is_active else Color(0.3, 0.3, 0.4)
	style.set_corner_radius_all(6)
	row.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	margin.add_child(hbox)
	row.add_child(margin)

	var cls = ConfigLoader.get_class_by_id(character.get("class_id", ""))
	var info = Label.new()
	info.custom_minimum_size = Vector2(420, 0)
	var loc_tag = {"idle": "闲置", "territory": "领地", "deployed": "出击中"}.get(
		character.get("location", "idle"), ""
	)
	info.text = (
		"%s  Lv.%d  [%s]  %s"
		% [
			character.get("name", "?"),
			character.get("level", 1),
			cls.get("display_name", "?"),
			loc_tag,
		]
	)
	info.add_theme_font_size_override("font_size", 20)
	if is_active:
		info.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	hbox.add_child(info)

	if is_active:
		var tag = Label.new()
		tag.text = "操控中"
		tag.add_theme_font_size_override("font_size", 18)
		tag.add_theme_color_override("font_color", Color(0.4, 1, 0.4))
		hbox.add_child(tag)
	else:
		var switch_btn = Button.new()
		switch_btn.text = "操控"
		switch_btn.custom_minimum_size = Vector2(90, 40)
		switch_btn.pressed.connect(_on_switch_character.bind(character.get("char_id", "")))
		hbox.add_child(switch_btn)

	return row


func _on_switch_character(char_id: String):
	if has_node("/root/RosterSystem"):
		get_node("/root/RosterSystem").switch_character(char_id)
		_refresh_ui()
		_setup_visuals()
		_equip_class_skills()
		_build_roster_list()


func _on_create_character_pressed():
	# 跳到职业选择界面创建新角色（ClassSelect 会写入名册）
	get_tree().change_scene_to_file("res://scenes/ClassSelect.tscn")


# ============================================================
# 领地系统：建造 / 升级面板（程序化构建）
# ============================================================

var _territory_panel: Panel = null


func _on_territory_clicked():
	upgrade_panel.visible = false
	dungeon_panel.visible = false
	if _roster_panel and is_instance_valid(_roster_panel):
		_roster_panel.visible = false
	_ensure_territory_panel()
	_territory_panel.visible = true
	_build_territory_view()


func _ensure_territory_panel():
	if _territory_panel != null and is_instance_valid(_territory_panel):
		return
	var panel = Panel.new()
	panel.name = "TerritoryPanel"
	panel.custom_minimum_size = Vector2(820, 640)
	panel.size = Vector2(820, 640)
	panel.position = Vector2(550, 210)

	var title = Label.new()
	title.name = "TitleLabel"
	title.text = "我的领地"
	title.position = Vector2(20, 14)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	panel.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(760, 14)
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(func(): _territory_panel.visible = false)
	panel.add_child(close_btn)

	# 资源条
	var res_label = RichTextLabel.new()
	res_label.name = "ResourceLabel"
	res_label.bbcode_enabled = true
	res_label.fit_content = true
	res_label.position = Vector2(20, 56)
	res_label.custom_minimum_size = Vector2(780, 30)
	res_label.size = Vector2(780, 30)
	panel.add_child(res_label)

	# 领地等级 + 升级按钮行
	var lvl_label = RichTextLabel.new()
	lvl_label.name = "LevelLabel"
	lvl_label.bbcode_enabled = true
	lvl_label.fit_content = true
	lvl_label.position = Vector2(20, 92)
	lvl_label.custom_minimum_size = Vector2(560, 30)
	lvl_label.size = Vector2(560, 30)
	panel.add_child(lvl_label)

	var up_btn = Button.new()
	up_btn.name = "TerritoryUpgradeButton"
	up_btn.position = Vector2(590, 88)
	up_btn.custom_minimum_size = Vector2(210, 40)
	up_btn.pressed.connect(_on_upgrade_territory)
	panel.add_child(up_btn)

	# 建筑列表滚动区
	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.position = Vector2(20, 140)
	scroll.custom_minimum_size = Vector2(780, 480)
	scroll.size = Vector2(780, 480)
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 8)
	vbox.custom_minimum_size = Vector2(760, 0)
	scroll.add_child(vbox)
	panel.add_child(scroll)

	$Panels.add_child(panel)
	_territory_panel = panel


func _build_territory_view():
	if not has_node("/root/TerritorySystem"):
		return
	var ts = get_node("/root/TerritorySystem")

	# 资源条
	var res_label: RichTextLabel = _territory_panel.get_node("ResourceLabel")
	res_label.text = _format_resources()

	# 领地等级
	var lvl_label: RichTextLabel = _territory_panel.get_node("LevelLabel")
	var lv_def = ts.get_level_def()
	lvl_label.text = (
		"[color=gold]领地 Lv.%d %s[/color]  槽位 %d/%d  居民 %d/%d  防御 +%d%%"
		% [
			ts.level,
			lv_def.get("display_name", "?"),
			ts.get_used_slots(),
			ts.get_building_slots(),
			ts.resident_count(),
			ts.get_resident_cap(),
			int(ts.get_defense_bonus() * 100),
		]
	)

	# 领地升级按钮
	var up_btn: Button = _territory_panel.get_node("TerritoryUpgradeButton")
	if ts.level >= ConfigLoader.get_territory_max_level():
		up_btn.text = "领地已达最高等级"
		up_btn.disabled = true
	else:
		var cost = ts.get_territory_upgrade_cost()
		up_btn.text = "升级领地 (%s)" % _format_cost(cost)
		up_btn.disabled = not ts.can_upgrade_territory()

	# 建筑列表
	var container = _territory_panel.get_node("ScrollContainer/VBoxContainer")
	for child in container.get_children():
		child.queue_free()

	# P3: 居民招募区
	container.add_child(_make_resident_section(ts))

	for def in ConfigLoader.get_all_buildings():
		if def.get("id", "") == "townhall":
			continue  # 领主大厅随领地升级，不在列表单列
		container.add_child(_make_building_row(def, ts))


## P3: 居民招募与分配区
func _make_resident_section(ts) -> VBoxContainer:
	var section = VBoxContainer.new()
	section.add_theme_constant_override("separation", 8)

	var header = PanelContainer.new()
	var h_style = StyleBoxFlat.new()
	h_style.bg_color = Color(0.2, 0.3, 0.25)
	h_style.set_corner_radius_all(4)
	header.add_theme_stylebox_override("panel", h_style)
	var h_margin = MarginContainer.new()
	h_margin.add_theme_constant_override("margin_left", 10)
	h_margin.add_theme_constant_override("margin_top", 6)
	h_margin.add_theme_constant_override("margin_right", 10)
	h_margin.add_theme_constant_override("margin_bottom", 6)
	header.add_child(h_margin)
	var h_box = HBoxContainer.new()
	h_box.add_theme_constant_override("separation", 16)
	h_margin.add_child(h_box)

	var h_label = Label.new()
	h_label.text = (
		"居民管理  当前 %d/%d  (每个居民提升所在建筑 +10%% 产出)" % [ts.resident_count(), ts.get_resident_cap()]
	)
	h_label.add_theme_font_size_override("font_size", 18)
	h_label.add_theme_color_override("font_color", Color(0.7, 1, 0.8))
	h_label.custom_minimum_size = Vector2(450, 0)
	h_box.add_child(h_label)

	var recruit_btn = Button.new()
	recruit_btn.text = (
		"招募居民 (金%d 粮%d)" % [ts.RESIDENT_RECRUIT_COST_GOLD, ts.RESIDENT_RECRUIT_COST_FOOD]
	)
	recruit_btn.custom_minimum_size = Vector2(220, 40)
	recruit_btn.disabled = (
		not ts.can_recruit_resident()
		or GameState.total_gold < ts.RESIDENT_RECRUIT_COST_GOLD
		or GameState.get_material("food") < ts.RESIDENT_RECRUIT_COST_FOOD
	)
	recruit_btn.pressed.connect(_on_recruit_resident)
	h_box.add_child(recruit_btn)
	section.add_child(header)

	# 居民列表（简化版：只显示 job 和分配按钮，点击弹出分配菜单由 P4 完善）
	if ts.residents.size() > 0:
		var res_list = Label.new()
		var job_counts = {}
		for r in ts.residents:
			var j = r.get("job", "idle")
			job_counts[j] = job_counts.get(j, 0) + 1
		var parts = []
		for j in job_counts:
			var j_disp = (
				{
					"idle": "闲置",
					"farmer": "农夫",
					"lumberjack": "伐木",
					"miner": "矿工",
					"soldier": "士兵",
					"worker": "工人"
				}
				. get(j, j)
			)
			parts.append("%s×%d" % [j_disp, job_counts[j]])
		res_list.text = "  分配情况: " + " / ".join(parts)
		res_list.add_theme_font_size_override("font_size", 14)
		res_list.add_theme_color_override("font_color", Color(0.65, 0.75, 0.7))
		section.add_child(res_list)

	return section


func _on_recruit_resident():
	var ts = get_node("/root/TerritorySystem")
	var r = ts.recruit_resident()
	if not r.get("ok", false):
		info_label.text = "[center][color=red]招募失败: %s[/color][/center]" % r.get("reason", "")
	else:
		info_label.text = (
			"[center][color=lime]招募成功: %s[/color][/center]" % r.get("resident", {}).get("name", "?")
		)
	_refresh_ui()
	_build_territory_view()


func _make_building_row(def: Dictionary, ts) -> PanelContainer:
	var bid = def.get("id", "")
	var built = ts.has_building(bid)
	var cur_lv = ts.get_building_level(bid)
	var max_lv = int(def.get("max_level", 5))

	var row = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.2, 0.16) if built else Color(0.14, 0.14, 0.17)
	style.set_border_width_all(2)
	style.border_color = Color(0.5, 0.7, 0.3) if built else Color(0.3, 0.3, 0.4)
	style.set_corner_radius_all(6)
	row.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	margin.add_child(hbox)

	# 左侧信息
	var info = VBoxContainer.new()
	info.custom_minimum_size = Vector2(480, 0)
	var name_lbl = Label.new()
	var cat_tag = {"production": "产出", "military": "军事", "housing": "住房", "core": "核心"}.get(
		def.get("category", ""), ""
	)
	if built:
		name_lbl.text = (
			"%s  Lv.%d/%d  [%s]" % [def.get("display_name", "?"), cur_lv, max_lv, cat_tag]
		)
	else:
		name_lbl.text = "%s  [%s]  (未建造)" % [def.get("display_name", "?"), cat_tag]
	name_lbl.add_theme_font_size_override("font_size", 19)
	if built:
		name_lbl.add_theme_color_override("font_color", Color(0.8, 1, 0.6))
	info.add_child(name_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = def.get("description", "")
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	desc_lbl.custom_minimum_size = Vector2(470, 0)
	info.add_child(desc_lbl)
	hbox.add_child(info)

	# 右侧按钮
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(220, 50)
	btn.add_theme_font_size_override("font_size", 15)
	if not built:
		var cost = def.get("build_cost", {})
		btn.text = "建造\n%s" % _format_cost(cost)
		btn.disabled = not (ts.has_free_slot() and ts.can_afford(cost))
		btn.pressed.connect(_on_build_building.bind(bid))
	elif cur_lv >= max_lv:
		btn.text = "已满级"
		btn.disabled = true
	else:
		var cost = ts.get_upgrade_cost(bid)
		btn.text = "升级 Lv.%d\n%s" % [cur_lv + 1, _format_cost(cost)]
		btn.disabled = not ts.can_afford(cost)
		btn.pressed.connect(_on_upgrade_building.bind(bid))
	hbox.add_child(btn)

	return row


func _on_build_building(building_id: String):
	var ts = get_node("/root/TerritorySystem")
	var r = ts.build_building(building_id)
	if not r.get("ok", false):
		info_label.text = "[center][color=red]建造失败: %s[/color][/center]" % r.get("reason", "")
	_refresh_ui()
	_build_territory_view()


func _on_upgrade_building(building_id: String):
	var ts = get_node("/root/TerritorySystem")
	var r = ts.upgrade_building(building_id)
	if not r.get("ok", false):
		info_label.text = "[center][color=red]升级失败: %s[/color][/center]" % r.get("reason", "")
	_refresh_ui()
	_build_territory_view()


func _on_upgrade_territory():
	var ts = get_node("/root/TerritorySystem")
	var r = ts.upgrade_territory()
	if r.get("ok", false):
		info_label.text = "[center][color=lime]领地升级到 Lv.%d！[/color][/center]" % ts.level
	else:
		info_label.text = "[center][color=red]领地升级失败: %s[/color][/center]" % r.get("reason", "")
	_refresh_ui()
	_build_territory_view()


## 格式化资源条（金币 + 基础建材）
func _format_resources() -> String:
	var parts = ["[color=gold]金币 %d[/color]" % GameState.total_gold]
	for m in ConfigLoader.get_basic_materials():
		var mid = m.get("id", "")
		parts.append("%s %d" % [m.get("display_name", mid), GameState.get_material(mid)])
	return "  ".join(parts)


## 格式化成本字典为简短文本（材料不足标红）
func _format_cost(cost: Dictionary) -> String:
	if cost.is_empty():
		return "免费"
	var parts = []
	for key in cost:
		var need = int(cost[key])
		var have = GameState.total_gold if key == "gold" else GameState.get_material(key)
		var disp = "金" if key == "gold" else _material_name(key)
		if have < need:
			parts.append("[color=red]%s%d[/color]" % [disp, need])
		else:
			parts.append("%s%d" % [disp, need])
	return " ".join(parts)


func _material_name(material_id: String) -> String:
	# 基础建材
	for m in ConfigLoader.get_basic_materials():
		if m.get("id", "") == material_id:
			return m.get("display_name", material_id)
	# 区域材料
	var region_mats = ConfigLoader.get_balance_config().get("region_materials", {}).get(
		"materials", []
	)
	for m in region_mats:
		if m.get("id", "") == material_id:
			return m.get("display_name", material_id)
	return material_id


# ============================================================
# P2: 组队系统 - 选择随行队友
# ============================================================

var _party_panel: Panel = null


func _ensure_party_panel():
	if _party_panel != null and is_instance_valid(_party_panel):
		return
	var panel = Panel.new()
	panel.name = "PartyPanel"
	panel.custom_minimum_size = Vector2(750, 580)
	panel.size = Vector2(750, 580)
	panel.position = Vector2(585, 250)

	var title = Label.new()
	title.text = "组队出击"
	title.position = Vector2(20, 14)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.9, 0.6, 1))
	panel.add_child(title)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.position = Vector2(690, 14)
	close_btn.custom_minimum_size = Vector2(40, 40)
	close_btn.pressed.connect(func(): _party_panel.visible = false)
	panel.add_child(close_btn)

	var hint = RichTextLabel.new()
	hint.name = "HintLabel"
	hint.bbcode_enabled = true
	hint.fit_content = true
	hint.position = Vector2(20, 58)
	hint.custom_minimum_size = Vector2(710, 30)
	hint.size = Vector2(710, 30)
	hint.text = "[color=yellow]最多选择3名队友随你出击，队友会自动攻击敌人并承担伤害[/color]"
	panel.add_child(hint)

	var scroll = ScrollContainer.new()
	scroll.name = "ScrollContainer"
	scroll.position = Vector2(20, 95)
	scroll.custom_minimum_size = Vector2(710, 400)
	scroll.size = Vector2(710, 400)
	var vbox = VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.add_theme_constant_override("separation", 10)
	vbox.custom_minimum_size = Vector2(690, 0)
	scroll.add_child(vbox)
	panel.add_child(scroll)

	# 进入副本按钮
	var enter_btn = Button.new()
	enter_btn.name = "EnterButton"
	enter_btn.text = "进入副本"
	enter_btn.position = Vector2(20, 510)
	enter_btn.custom_minimum_size = Vector2(710, 55)
	enter_btn.add_theme_font_size_override("font_size", 22)
	enter_btn.pressed.connect(_on_enter_dungeon)
	panel.add_child(enter_btn)

	$Panels.add_child(panel)
	_party_panel = panel


func _build_party_view():
	if not has_node("/root/RosterSystem") or not has_node("/root/PartySystem"):
		return
	var rs = get_node("/root/RosterSystem")
	var ps = get_node("/root/PartySystem")
	ps.sanitize()

	var container = _party_panel.get_node("ScrollContainer/VBoxContainer")
	for child in container.get_children():
		child.queue_free()

	var others = rs.get_other_characters()
	if others.is_empty():
		var empty = Label.new()
		empty.text = "没有其他角色可选（去角色管理创建新角色）"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		container.add_child(empty)
		return

	for c in others:
		container.add_child(_make_party_candidate_row(c, ps))

	# 更新进入按钮文本显示已选数量
	var enter_btn: Button = _party_panel.get_node("EnterButton")
	enter_btn.text = "进入副本 (已选 %d/%d 队友)" % [ps.companion_count(), ps.MAX_COMPANIONS]


func _make_party_candidate_row(character: Dictionary, ps) -> PanelContainer:
	var cid = character.get("char_id", "")
	var selected = ps.is_in_party(cid)

	var row = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.18, 0.3) if selected else Color(0.15, 0.15, 0.2)
	style.set_border_width_all(2)
	style.border_color = Color(0.9, 0.6, 1) if selected else Color(0.3, 0.3, 0.4)
	style.set_corner_radius_all(6)
	row.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	row.add_child(margin)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 16)
	margin.add_child(hbox)

	var cls = ConfigLoader.get_class_by_id(character.get("class_id", ""))
	var info = VBoxContainer.new()
	info.custom_minimum_size = Vector2(450, 0)
	var name_lbl = Label.new()
	name_lbl.text = (
		"%s  Lv.%d  [%s]"
		% [
			character.get("name", "?"),
			character.get("level", 1),
			cls.get("display_name", "?"),
		]
	)
	name_lbl.add_theme_font_size_override("font_size", 20)
	if selected:
		name_lbl.add_theme_color_override("font_color", Color(1, 0.9, 1))
	info.add_child(name_lbl)

	var power = RosterSystem.get_character_power(cid)
	var stats_lbl = Label.new()
	stats_lbl.text = "战力 %.0f" % power
	stats_lbl.add_theme_font_size_override("font_size", 15)
	stats_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
	info.add_child(stats_lbl)
	hbox.add_child(info)

	var btn = Button.new()
	btn.custom_minimum_size = Vector2(180, 50)
	btn.add_theme_font_size_override("font_size", 18)
	if selected:
		btn.text = "✓ 已选中"
		btn.modulate = Color(0.9, 1, 0.9)
	else:
		btn.text = "+ 加入队伍"
		if not ps.can_add():
			btn.disabled = true
			btn.text = "队伍已满"
	btn.pressed.connect(_on_toggle_party_member.bind(cid))
	hbox.add_child(btn)

	return row


func _on_toggle_party_member(char_id: String):
	if has_node("/root/PartySystem"):
		get_node("/root/PartySystem").toggle_companion(char_id)
		_build_party_view()


func _on_enter_dungeon():
	# 关闭组队面板，打开原副本选择面板
	_party_panel.visible = false
	dungeon_panel.visible = true
	_build_dungeon_list()
	info_label.text = "[center][color=purple]副本传送门[/color]\n选择副本进入战斗[/center]"


# ============================================================
# P5: 野外随机事件
# ============================================================


func _trigger_wilderness_event():
	var events = [
		{"type": "resource", "weight": 40},
		{"type": "merchant", "weight": 30},
		{"type": "nothing", "weight": 30},
	]
	var total_weight = 0
	for e in events:
		total_weight += e["weight"]
	var roll = randi() % total_weight
	var acc = 0
	var chosen = events[0]
	for e in events:
		acc += e["weight"]
		if roll < acc:
			chosen = e
			break

	match chosen["type"]:
		"resource":
			_event_resource_cache()
		"merchant":
			_event_wandering_merchant()
		"nothing":
			_event_nothing()


func _event_resource_cache():
	var gains = {
		"timber": 20 + randi() % 30,
		"stone_block": 15 + randi() % 20,
		"food": 25 + randi() % 25,
	}
	for mat in gains:
		GameState.add_material(mat, gains[mat])
	var parts = []
	for mat in gains:
		parts.append("%s +%d" % [_material_name(mat), gains[mat]])
	info_label.text = "[center][color=lime]发现资源点！[/color]\n获得: " + "  ".join(parts) + "[/center]"
	SaveSystem.mark_dirty()


func _event_wandering_merchant():
	var gold_gain = 50 + randi() % 100
	GameState.total_gold += gold_gain
	info_label.text = (
		"[center][color=yellow]遇到流浪商人！[/color]\n商人收购了你的战利品\n金币 +%d[/center]" % gold_gain
	)
	SaveSystem.mark_dirty()


func _event_nothing():
	var msgs = [
		"四处寻找无果，空手而归",
		"远处传来怪物咆哮，你谨慎撤退",
		"天色渐暗，决定回城",
		"遇到巡逻队，他们劝你不要深入",
	]
	info_label.text = "[center][color=gray]野外探索[/color]\n%s[/center]" % msgs[randi() % msgs.size()]


## 阶段1: 自动装备职业技能
func _equip_class_skills():
	var class_id = GameState.get_current_class().get("id", "")
	var skill_map = {
		"class_warrior": ["skill_charge", "skill_whirlwind_active", "skill_taunt"],
		"class_ranger": ["skill_multishot_active", "skill_trap", "skill_hawk_eye"],
		"class_mage": ["skill_fireball_active", "skill_frost_wall", "skill_teleport"],
		"class_assassin": ["skill_shadow_strike", "skill_smoke_bomb", "skill_poison_blade"],
		"class_knight": ["skill_judgment_hammer", "skill_blessing_aura", "skill_holy_heal"],
		"class_necromancer": ["skill_shadow_bolt", "skill_weakness_curse", "skill_army_summon"]
	}

	var skills = skill_map.get(class_id, [])
	if skills.is_empty():
		return

	if has_node("/root/ActiveSkillSystem"):
		var ask = get_node("/root/ActiveSkillSystem")
		for i in range(min(3, skills.size())):
			ask.equip_manual_skill(i, skills[i])
		print("[Town] 已为%s装备3个技能" % class_id)


# ============ A 路线：UI 接线 ============
var _training_panel: Panel = null


func _on_training_ground_clicked():
	_hide_all_panels()
	_ensure_training_panel()
	_training_panel.visible = true
	_build_training_view()
	info_label.text = "[center][color=violet]训练场[/color]\n巅峰等级 / 天赋星图[/center]"


func _hide_all_panels():
	upgrade_panel.visible = false
	dungeon_panel.visible = false
	if _roster_panel and is_instance_valid(_roster_panel):
		_roster_panel.visible = false
	if _territory_panel and is_instance_valid(_territory_panel):
		_territory_panel.visible = false
	if _party_panel and is_instance_valid(_party_panel):
		_party_panel.visible = false
	if _training_panel and is_instance_valid(_training_panel):
		_training_panel.visible = false


func _ensure_training_panel():
	if _training_panel != null and is_instance_valid(_training_panel):
		return
	var panel_dict = ThemeGenerator.create_system_panel("训练场")
	_training_panel = panel_dict["root"]
	_training_panel.name = "TrainingPanel"
	_training_panel.position = Vector2(50, 100)
	_training_panel.custom_minimum_size = Vector2(1800, 650)
	_training_panel.size = Vector2(1800, 650)
	add_child(_training_panel)
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(1650, 10)
	close_btn.custom_minimum_size = Vector2(120, 50)
	close_btn.pressed.connect(func(): _training_panel.visible = false)
	_training_panel.add_child(close_btn)


func _build_training_view():
	if not _training_panel or not is_instance_valid(_training_panel):
		return
	var body = _training_panel.get_node("VBoxContainer/VBoxContainer")
	for c in body.get_children():
		c.queue_free()

	var tab_bar = HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 20)
	body.add_child(tab_bar)

	var btn_paragon = Button.new()
	btn_paragon.text = "巅峰等级"
	btn_paragon.custom_minimum_size = Vector2(180, 50)
	btn_paragon.pressed.connect(_show_paragon_tab)
	tab_bar.add_child(btn_paragon)

	var btn_talent = Button.new()
	btn_talent.text = "天赋星图"
	btn_talent.custom_minimum_size = Vector2(180, 50)
	btn_talent.pressed.connect(_show_talent_tab)
	tab_bar.add_child(btn_talent)

	var btn_quest = Button.new()
	btn_quest.text = "居民任务"
	btn_quest.custom_minimum_size = Vector2(180, 50)
	btn_quest.pressed.connect(_show_quest_tab)
	tab_bar.add_child(btn_quest)

	var sep = HSeparator.new()
	body.add_child(sep)

	var content = ScrollContainer.new()
	content.custom_minimum_size = Vector2(1750, 480)
	content.name = "TrainingContent"
	body.add_child(content)

	_show_paragon_tab()


func _show_paragon_tab():
	var content = _training_panel.get_node_or_null("VBoxContainer/VBoxContainer/TrainingContent")
	if not content:
		return
	for c in content.get_children():
		c.queue_free()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	content.add_child(vbox)

	var header = Label.new()
	var pg = GameState.meta_progression.get("paragon", {})
	var lvl = pg.get("level", 0)
	var pts = pg.get("points", 0)
	header.text = "巅峰等级: %d   可用点数: %d" % [lvl, pts]
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	vbox.add_child(header)

	var paths = [
		"power",
		"finesse",
		"vitality",
		"spirit",
		"defense",
		"swiftness",
		"fortune",
		"mastery",
		"cunning",
		"might"
	]
	var names = {
		"power": "力量",
		"finesse": "灵巧",
		"vitality": "活力",
		"spirit": "精神",
		"defense": "防御",
		"swiftness": "迅捷",
		"fortune": "幸运",
		"mastery": "精通",
		"cunning": "狡诈",
		"might": "威能"
	}

	for path in paths:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.custom_minimum_size = Vector2(1700, 50)
		vbox.add_child(row)

		var name_lbl = Label.new()
		name_lbl.text = names.get(path, path)
		name_lbl.custom_minimum_size = Vector2(120, 0)
		name_lbl.add_theme_font_size_override("font_size", 20)
		row.add_child(name_lbl)

		var cur = pg.get("stats", {}).get(path, 0)
		var val_lbl = Label.new()
		val_lbl.text = "%d / 50" % cur
		val_lbl.custom_minimum_size = Vector2(100, 0)
		val_lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(val_lbl)

		var bar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 50
		bar.value = cur
		bar.custom_minimum_size = Vector2(800, 30)
		bar.show_percentage = false
		row.add_child(bar)

		var btn_minus = Button.new()
		btn_minus.text = "-"
		btn_minus.custom_minimum_size = Vector2(50, 40)
		btn_minus.disabled = cur <= 0
		btn_minus.pressed.connect(_paragon_adjust.bind(path, -1))
		row.add_child(btn_minus)

		var btn_plus = Button.new()
		btn_plus.text = "+"
		btn_plus.custom_minimum_size = Vector2(50, 40)
		btn_plus.disabled = pts <= 0 or cur >= 50
		btn_plus.pressed.connect(_paragon_adjust.bind(path, 1))
		row.add_child(btn_plus)

		var bonus_lbl = Label.new()
		var bonus_pct = cur * 0.5
		bonus_lbl.text = "+%.1f%%" % bonus_pct
		bonus_lbl.custom_minimum_size = Vector2(100, 0)
		bonus_lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.3))
		row.add_child(bonus_lbl)


func _paragon_adjust(path: String, delta: int):
	var pg = GameState.meta_progression.get("paragon", {})
	var pts = pg.get("points", 0)
	var stats = pg.get("stats", {})
	var cur = stats.get(path, 0)

	if delta > 0 and pts > 0 and cur < 50:
		stats[path] = cur + 1
		pg["points"] = pts - 1
	elif delta < 0 and cur > 0:
		stats[path] = cur - 1
		pg["points"] = pts + 1

	pg["stats"] = stats
	GameState.meta_progression["paragon"] = pg
	_show_paragon_tab()


func _show_talent_tab():
	var content = _training_panel.get_node_or_null("VBoxContainer/VBoxContainer/TrainingContent")
	if not content:
		return
	for c in content.get_children():
		c.queue_free()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	content.add_child(vbox)

	var tal = GameState.meta_progression.get("talents", {})
	var pts = tal.get("points", 0)
	var unlocked = tal.get("unlocked", [])

	var header = Label.new()
	header.text = "可用天赋点: %d   已解锁: %d / 23" % [pts, unlocked.size()]
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	vbox.add_child(header)

	var talents_cfg = ConfigLoader.get_all_talents()
	for t in talents_cfg:
		var tid = t.get("id", "")
		var is_unlocked = tid in unlocked
		var can_unlock = _can_unlock_talent(tid, unlocked, tal.get("class", ""))

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.custom_minimum_size = Vector2(1700, 50)
		vbox.add_child(row)

		var name_lbl = Label.new()
		name_lbl.text = t.get("display_name", tid)
		name_lbl.custom_minimum_size = Vector2(200, 0)
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.add_theme_color_override(
			"font_color", Color(0.3, 1, 0.3) if is_unlocked else Color(0.7, 0.7, 0.7)
		)
		row.add_child(name_lbl)

		var desc_lbl = Label.new()
		var effects = t.get("effects", [])
		var desc_parts = []
		for eff in effects:
			if eff.get("kind") == "add_stat":
				desc_parts.append("%s +%s" % [eff.get("stat", "?"), eff.get("value", 0)])
		desc_lbl.text = (
			" / ".join(desc_parts) if desc_parts.size() > 0 else t.get("description", "")
		)
		desc_lbl.custom_minimum_size = Vector2(600, 0)
		desc_lbl.add_theme_font_size_override("font_size", 16)
		row.add_child(desc_lbl)

		var prereq_lbl = Label.new()
		var prereq = t.get("prerequisite", [])
		var any_prereq = t.get("any_prerequisite", [])
		if prereq.size() > 0:
			prereq_lbl.text = "前置: " + ", ".join(prereq)
		elif any_prereq.size() > 0:
			prereq_lbl.text = "前置(任一): " + ", ".join(any_prereq)
		else:
			prereq_lbl.text = "无前置"
		prereq_lbl.custom_minimum_size = Vector2(400, 0)
		prereq_lbl.add_theme_font_size_override("font_size", 14)
		prereq_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.5))
		row.add_child(prereq_lbl)

		var btn = Button.new()
		if is_unlocked:
			btn.text = "已解锁"
			btn.disabled = true
		elif can_unlock and pts > 0:
			btn.text = "解锁"
			btn.pressed.connect(_talent_unlock.bind(tid))
		else:
			btn.text = "不可用"
			btn.disabled = true
		btn.custom_minimum_size = Vector2(100, 40)
		row.add_child(btn)


func _can_unlock_talent(tid: String, unlocked: Array, player_class: String) -> bool:
	var talents_cfg = ConfigLoader.get_all_talents()
	var t = null
	for talent in talents_cfg:
		if talent.get("id") == tid:
			t = talent
			break
	if not t:
		return false

	var class_req = t.get("class_requirement", [])
	if class_req.size() > 0 and player_class not in class_req:
		return false

	var prereq = t.get("prerequisite", [])
	if prereq.size() > 0:
		for p in prereq:
			if p not in unlocked:
				return false

	var any_prereq = t.get("any_prerequisite", [])
	if any_prereq.size() > 0:
		var has_any = false
		for p in any_prereq:
			if p in unlocked:
				has_any = true
				break
		if not has_any:
			return false

	return true


func _talent_unlock(tid: String):
	var tal = GameState.meta_progression.get("talents", {})
	var pts = tal.get("points", 0)
	var unlocked = tal.get("unlocked", [])

	if pts > 0 and tid not in unlocked:
		unlocked.append(tid)
		tal["points"] = pts - 1
		tal["unlocked"] = unlocked
		GameState.meta_progression["talents"] = tal
		_show_talent_tab()


func _show_quest_tab():
	var content = _training_panel.get_node_or_null("VBoxContainer/VBoxContainer/TrainingContent")
	if not content:
		return
	for c in content.get_children():
		c.queue_free()

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	content.add_child(vbox)

	var header = Label.new()
	header.text = "居民任务（完成后领取奖励）"
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	vbox.add_child(header)

	if not has_node("/root/QuestSystem"):
		var err = Label.new()
		err.text = "QuestSystem 未加载"
		vbox.add_child(err)
		return

	var qs = get_node("/root/QuestSystem")
	var active = qs.active_quests

	if active.is_empty():
		var empty = Label.new()
		empty.text = "当前无活跃任务，完成出击后自动刷新"
		empty.add_theme_font_size_override("font_size", 18)
		vbox.add_child(empty)
		return

	for q in active:
		var qid = q.get("id", "")
		var title = q.get("title", qid)
		var cur = q.get("current", 0)
		var goal = q.get("goal", 1)
		var completed = cur >= goal
		var claimed = q.get("claimed", false)

		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(1700, 80)
		var panel_style = StyleBoxFlat.new()
		panel_style.bg_color = Color(0.2, 0.2, 0.25, 0.9)
		panel_style.border_color = Color(0.3, 1, 0.3) if completed else Color(0.6, 0.6, 0.6)
		panel_style.set_border_width_all(2)
		panel_style.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", panel_style)
		vbox.add_child(panel)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		panel.add_child(row)

		var name_lbl = Label.new()
		name_lbl.text = title
		name_lbl.custom_minimum_size = Vector2(300, 0)
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override("font_color", Color(1, 1, 0.8))
		row.add_child(name_lbl)

		var prog_lbl = Label.new()
		prog_lbl.text = "%d / %d" % [cur, goal]
		prog_lbl.custom_minimum_size = Vector2(100, 0)
		prog_lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(prog_lbl)

		var bar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = goal
		bar.value = cur
		bar.custom_minimum_size = Vector2(500, 30)
		bar.show_percentage = false
		row.add_child(bar)

		var reward_lbl = Label.new()
		var rew = q.get("reward", {})
		var rew_text = []
		if rew.get("gold", 0) > 0:
			rew_text.append("金币 %d" % rew.get("gold"))
		if rew.get("exp", 0) > 0:
			rew_text.append("经验 %d" % rew.get("exp"))
		var mats = rew.get("materials", {})
		for mat in mats:
			rew_text.append("%s x%d" % [mat, mats[mat]])
		reward_lbl.text = "奖励: " + ", ".join(rew_text)
		reward_lbl.custom_minimum_size = Vector2(400, 0)
		reward_lbl.add_theme_font_size_override("font_size", 16)
		reward_lbl.add_theme_color_override("font_color", Color(0.3, 1, 0.8))
		row.add_child(reward_lbl)

		var btn = Button.new()
		if claimed:
			btn.text = "已领取"
			btn.disabled = true
		elif completed:
			btn.text = "领取"
			btn.pressed.connect(_quest_claim.bind(qid))
		else:
			btn.text = "进行中"
			btn.disabled = true
		btn.custom_minimum_size = Vector2(100, 50)
		row.add_child(btn)


func _quest_claim(qid: String):
	if not has_node("/root/QuestSystem"):
		return
	var qs = get_node("/root/QuestSystem")
	var reward = qs.claim_reward(qid)
	if reward.get("gold", 0) > 0:
		GameState.total_gold += reward.get("gold", 0)
	if reward.get("exp", 0) > 0:
		GameState.gain_experience(reward.get("exp", 0))
	_show_quest_tab()
	_refresh_ui()


var _merchant_panel: Panel = null


func _ensure_merchant_panel():
	if _merchant_panel != null and is_instance_valid(_merchant_panel):
		return
	var panel_dict = ThemeGenerator.create_system_panel("流浪商人")
	_merchant_panel = panel_dict["root"]
	_merchant_panel.name = "MerchantPanel"
	_merchant_panel.position = Vector2(50, 100)
	_merchant_panel.custom_minimum_size = Vector2(1800, 650)
	_merchant_panel.size = Vector2(1800, 650)
	add_child(_merchant_panel)
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(1650, 10)
	close_btn.custom_minimum_size = Vector2(120, 50)
	close_btn.pressed.connect(func(): _merchant_panel.visible = false)
	_merchant_panel.add_child(close_btn)


func _build_merchant_view():
	if not _merchant_panel or not is_instance_valid(_merchant_panel):
		return
	var body = _merchant_panel.get_node("VBoxContainer/VBoxContainer")
	for c in body.get_children():
		c.queue_free()

	var header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 20)
	body.add_child(header)

	var gold_lbl = Label.new()
	gold_lbl.text = "当前金币: %d" % GameState.total_gold
	gold_lbl.add_theme_font_size_override("font_size", 22)
	gold_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	header.add_child(gold_lbl)

	var refresh_btn = Button.new()
	refresh_btn.text = "刷新商店 (花费 50 金币)"
	refresh_btn.custom_minimum_size = Vector2(250, 50)
	refresh_btn.disabled = GameState.total_gold < 50
	refresh_btn.pressed.connect(_merchant_refresh)
	header.add_child(refresh_btn)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1750, 500)
	body.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	scroll.add_child(vbox)

	if not has_node("/root/TerritorySystem"):
		var err = Label.new()
		err.text = "TerritorySystem 未加载"
		vbox.add_child(err)
		return

	var ts = get_node("/root/TerritorySystem")
	var stock = ts.merchant_stock

	if stock.is_empty():
		var empty = Label.new()
		empty.text = "商人暂无货物，点击刷新"
		empty.add_theme_font_size_override("font_size", 18)
		vbox.add_child(empty)
		return

	for item in stock:
		var itype = item.get("type", "")
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		row.custom_minimum_size = Vector2(1700, 60)
		vbox.add_child(row)

		var name_lbl = Label.new()
		if itype == "equipment":
			var eq = item.get("data", {})
			name_lbl.text = eq.get("display_name", "装备")
			var rarity = eq.get("rarity", "common")
			name_lbl.add_theme_color_override("font_color", Schema.rarity_color(rarity))
		elif itype == "material":
			name_lbl.text = "%s x%d" % [item.get("id", "材料"), item.get("amount", 1)]
			name_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 1))
		name_lbl.custom_minimum_size = Vector2(400, 0)
		name_lbl.add_theme_font_size_override("font_size", 20)
		row.add_child(name_lbl)

		var price_lbl = Label.new()
		var price = item.get("price", 0)
		price_lbl.text = "价格: %d 金币" % price
		price_lbl.custom_minimum_size = Vector2(200, 0)
		price_lbl.add_theme_font_size_override("font_size", 18)
		price_lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		row.add_child(price_lbl)

		var btn = Button.new()
		btn.text = "购买"
		btn.custom_minimum_size = Vector2(100, 50)
		btn.disabled = GameState.total_gold < price
		btn.pressed.connect(_merchant_buy.bind(item))
		row.add_child(btn)


func _merchant_refresh():
	if GameState.total_gold < 50:
		return
	GameState.total_gold -= 50
	if has_node("/root/TerritorySystem"):
		get_node("/root/TerritorySystem").refresh_merchant()
	_build_merchant_view()
	_refresh_ui()


func _merchant_buy(item: Dictionary):
	var price = item.get("price", 0)
	if GameState.total_gold < price:
		return
	GameState.total_gold -= price

	var itype = item.get("type", "")
	if itype == "equipment":
		var eq = item.get("data", {})
		if has_node("/root/EquipmentSystem"):
			get_node("/root/EquipmentSystem").add_to_inventory(eq)
	elif itype == "material":
		var mid = item.get("id", "")
		var amt = item.get("amount", 1)
		GameState.add_material(mid, amt)

	if has_node("/root/TerritorySystem"):
		var ts = get_node("/root/TerritorySystem")
		ts.merchant_stock.erase(item)

	_build_merchant_view()
	_refresh_ui()


func _build_bd_presets_section():
	if not has_node("/root/BuildPresets"):
		return

	var bd_section = _roster_panel.get_node_or_null("BDPresetsSection")
	if bd_section:
		bd_section.queue_free()

	var sep = HSeparator.new()
	sep.name = "BDPresetsSection"
	_roster_panel.add_child(sep)

	var header = Label.new()
	header.text = "BD 预设（每个角色 3 个预设槽）"
	header.position = Vector2(20, 560)
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	_roster_panel.add_child(header)

	var bp = get_node("/root/BuildPresets")
	var presets = bp.presets

	var row = HBoxContainer.new()
	row.name = "BDRow"
	row.position = Vector2(20, 590)
	row.add_theme_constant_override("separation", 20)
	_roster_panel.add_child(row)

	for i in range(3):
		var slot = VBoxContainer.new()
		slot.add_theme_constant_override("separation", 6)
		row.add_child(slot)

		var lbl = Label.new()
		lbl.text = "预设 %d" % (i + 1)
		lbl.add_theme_font_size_override("font_size", 18)
		slot.add_child(lbl)

		var has_preset = presets.has(str(i))
		var info = Label.new()
		if has_preset:
			var snapshot = presets[str(i)]
			var eq_count = snapshot.get("equipment", {}).size()
			var skill_count = snapshot.get("skills", []).size()
			info.text = "装备: %d  技能: %d" % [eq_count, skill_count]
			info.add_theme_font_size_override("font_size", 14)
			info.add_theme_color_override("font_color", Color(0.7, 0.9, 0.7))
		else:
			info.text = "空槽"
			info.add_theme_font_size_override("font_size", 14)
			info.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		slot.add_child(info)

		var btn_save = Button.new()
		btn_save.text = "保存"
		btn_save.custom_minimum_size = Vector2(100, 40)
		btn_save.pressed.connect(_bd_save.bind(i))
		slot.add_child(btn_save)

		var btn_load = Button.new()
		btn_load.text = "加载"
		btn_load.custom_minimum_size = Vector2(100, 40)
		btn_load.disabled = not has_preset
		btn_load.pressed.connect(_bd_load.bind(i))
		slot.add_child(btn_load)


func _bd_save(slot_idx: int):
	if not has_node("/root/BuildPresets"):
		return
	get_node("/root/BuildPresets").save_build(slot_idx)
	_build_bd_presets_section()


func _bd_load(slot_idx: int):
	if not has_node("/root/BuildPresets"):
		return
	get_node("/root/BuildPresets").load_build(slot_idx)
	_build_bd_presets_section()
	_refresh_ui()


var _achievement_panel: Panel = null


func _on_achievement_clicked():
	_hide_all_panels()
	_ensure_achievement_panel()
	_achievement_panel.visible = true
	_build_achievement_view()
	info_label.text = "[center][color=gold]成就系统[/color]\n追踪长期目标[/center]"


func _ensure_achievement_panel():
	if _achievement_panel != null and is_instance_valid(_achievement_panel):
		return
	var panel_dict = ThemeGenerator.create_system_panel("成就")
	_achievement_panel = panel_dict["root"]
	_achievement_panel.name = "AchievementPanel"
	_achievement_panel.position = Vector2(50, 100)
	_achievement_panel.custom_minimum_size = Vector2(1800, 650)
	_achievement_panel.size = Vector2(1800, 650)
	add_child(_achievement_panel)
	var close_btn = Button.new()
	close_btn.text = "关闭"
	close_btn.position = Vector2(1650, 10)
	close_btn.custom_minimum_size = Vector2(120, 50)
	close_btn.pressed.connect(func(): _achievement_panel.visible = false)
	_achievement_panel.add_child(close_btn)


func _build_achievement_view():
	if not _achievement_panel or not is_instance_valid(_achievement_panel):
		return
	var body = _achievement_panel.get_node("VBoxContainer/VBoxContainer")
	for c in body.get_children():
		c.queue_free()

	if not has_node("/root/AchievementSystem"):
		var err = Label.new()
		err.text = "AchievementSystem 未加载"
		body.add_child(err)
		return

	var ach_sys = get_node("/root/AchievementSystem")
	var all_ach = ach_sys.get_all_achievements()

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1750, 550)
	body.add_child(scroll)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(vbox)

	var unlocked_count = ach_sys.unlocked.size()
	var header = Label.new()
	header.text = "已解锁: %d / %d" % [unlocked_count, all_ach.size()]
	header.add_theme_font_size_override("font_size", 24)
	header.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	vbox.add_child(header)

	for ach in all_ach:
		var aid = ach.get("id", "")
		var unlocked = ach_sys.is_unlocked(aid)
		var prog = ach_sys.get_progress(aid)

		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(1700, 80)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.3, 0.25, 0.2, 0.9) if unlocked else Color(0.15, 0.15, 0.2, 0.9)
		style.border_color = Color(1, 0.9, 0.3) if unlocked else Color(0.4, 0.4, 0.4)
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel", style)
		vbox.add_child(panel)

		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		panel.add_child(row)

		var name_lbl = Label.new()
		name_lbl.text = ach.get("display_name", aid)
		name_lbl.custom_minimum_size = Vector2(300, 0)
		name_lbl.add_theme_font_size_override("font_size", 20)
		name_lbl.add_theme_color_override(
			"font_color", Color(1, 0.9, 0.5) if unlocked else Color(0.7, 0.7, 0.7)
		)
		row.add_child(name_lbl)

		var desc_lbl = Label.new()
		desc_lbl.text = ach.get("description", "")
		desc_lbl.custom_minimum_size = Vector2(500, 0)
		desc_lbl.add_theme_font_size_override("font_size", 16)
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		row.add_child(desc_lbl)

		var prog_lbl = Label.new()
		var goal = ach.get("goal", 1)
		var cur = ach_sys.progress.get(aid, 0)
		prog_lbl.text = "%d / %d" % [cur, goal]
		prog_lbl.custom_minimum_size = Vector2(100, 0)
		prog_lbl.add_theme_font_size_override("font_size", 18)
		row.add_child(prog_lbl)

		var bar = ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 100
		bar.value = prog * 100
		bar.custom_minimum_size = Vector2(300, 30)
		bar.show_percentage = false
		row.add_child(bar)

		var status_lbl = Label.new()
		status_lbl.text = "✓ 已解锁" if unlocked else "未完成"
		status_lbl.custom_minimum_size = Vector2(100, 0)
		status_lbl.add_theme_font_size_override("font_size", 18)
		status_lbl.add_theme_color_override(
			"font_color", Color(0.3, 1, 0.3) if unlocked else Color(0.6, 0.6, 0.6)
		)
		row.add_child(status_lbl)
