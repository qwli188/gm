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
	class_label.text = "职业: %s" % cls.get("display_name", "未选择")
	level_label.text = "等级: 1"

	info_label.text = "[center][color=yellow]欢迎来到黎明堡[/color]\n点击地图上的建筑进行交互[/center]"

## 创建城镇交互点
func _create_town_locations():
	var world_map = $WorldMap

	# 铺地块地面（town 主题）
	_tile_ground(world_map)

	# 建筑布局：图标 + 名称 + 主题色
	var buildings = [
		{pos = Vector2(300, 420), name = "铁匠铺", color = Color(1, 0.6, 0.2), icon = "obstacle_forge", cb = _on_blacksmith_clicked},
		{pos = Vector2(760, 420), name = "副本入口", color = Color(0.6, 0.3, 1), icon = "obstacle_void", cb = _on_dungeon_portal_clicked},
		{pos = Vector2(1180, 420), name = "商店", color = Color(0.3, 0.8, 0.3), icon = "obstacle_field", cb = _on_shop_clicked},
		{pos = Vector2(1560, 420), name = "城外野区", color = Color(0.8, 0.2, 0.2), icon = "obstacle_crypt", cb = _on_wilderness_clicked},
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
func _create_location_marker(pos: Vector2, label_text: String, marker_color: Color, icon_name: String = "") -> Button:
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
			icon_tex = load("res://assets/generated/tiles/%s.png" % icon_name) if ResourceLoader.exists("res://assets/generated/tiles/%s.png" % icon_name) else null
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
	info_label.text = "[center][color=orange]铁匠铺 - 永久强化[/color]\n使用金币提升基础属性\n\n[color=yellow]装备强化系统[/color]\n词缀工坊可强化装备(+0到+15)\n每+1增加基础属性10%\n消耗金币+区域材料，有成功率[/center]"

## 副本入口点击
func _on_dungeon_portal_clicked():
	upgrade_panel.visible = false
	dungeon_panel.visible = true
	_build_dungeon_list()
	info_label.text = "[center][color=purple]副本传送门[/color]\n选择副本进入战斗[/center]"

## 商店点击
func _on_shop_clicked():
	info_label.text = "[center][color=green]商店功能开发中[/color]\n敬请期待[/center]"

## 城外野区点击
func _on_wilderness_clicked():
	info_label.text = "[center][color=red]城外野区[/color]\n自由探索区域，开发中[/center]"

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
	if GameState.has("tutorial_completed") and GameState.tutorial_completed:
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
