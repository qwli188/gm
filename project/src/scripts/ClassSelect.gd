extends Control
## 职业选择界面 - 可视化职业卡片展示

@onready var class_grid: GridContainer = $VBoxContainer/GridCenter/ClassGrid
@onready var class_name_label: Label = $VBoxContainer/InfoPanel/MarginContainer/VBox/ClassNameLabel
@onready var desc_label: Label = $VBoxContainer/InfoPanel/MarginContainer/VBox/DescLabel
@onready var stats_label: Label = $VBoxContainer/InfoPanel/MarginContainer/VBox/StatsLabel
@onready var confirm_button: Button = $VBoxContainer/ButtonContainer/ConfirmButton
@onready var back_button: Button = $VBoxContainer/ButtonContainer/BackButton

const SPRITE_SHEET = preload("res://assets/sprites/roguelike/roguelikeSheet_transparent.png")

var selected_class_id: String = ""
var class_cards: Dictionary = {}

func _ready():
	print("[ClassSelect] 开始初始化")
	_build_class_cards()
	confirm_button.pressed.connect(_on_confirm)
	back_button.pressed.connect(_on_back)
	print("[ClassSelect] 初始化完成")

## 创建可视化职业卡片
func _build_class_cards():
	var classes = ConfigLoader.get_all_classes()
	print("[ClassSelect] 加载到 %d 个职业" % classes.size())

	for cls in classes:
		var card = _create_class_card(cls)
		class_grid.add_child(card)
		class_cards[cls.get("id", "")] = card
		print("[ClassSelect] 创建职业卡片: %s" % cls.get("display_name", ""))

## 创建单个职业卡片 - 修复版本
func _create_class_card(cls: Dictionary) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(280, 320)

	# 添加样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.14, 0.2, 1)
	style.set_border_width_all(2)
	style.border_color = Color(0.3, 0.3, 0.4, 1)
	style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", style)

	# 创建内容容器（正确的层级结构）
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 15)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_right", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	card.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	margin.add_child(vbox)

	# 职业精灵图（使用生成的卡通立绘，放大显示）
	var sprite_container = CenterContainer.new()
	sprite_container.custom_minimum_size = Vector2(0, 180)
	var portrait = TextureRect.new()
	portrait.texture = SpriteLibrary.get_class_portrait(cls.get("id", "class_warrior"))
	portrait.custom_minimum_size = Vector2(160, 160)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # 像素锐利放大
	sprite_container.add_child(portrait)
	vbox.add_child(sprite_container)

	# 职业名称
	var name_label = Label.new()
	name_label.text = cls.get("display_name", "")
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color(1, 0.9, 0.6, 1))
	name_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(name_label)

	# 职业称号
	var title_label = Label.new()
	title_label.text = cls.get("title", "")
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.8, 1))
	title_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(title_label)

	# 选择按钮
	var btn = Button.new()
	btn.text = "选择"
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_on_class_selected.bind(cls.get("id", "")))
	vbox.add_child(btn)

	return card

## 职业被选中
func _on_class_selected(class_id: String):
	selected_class_id = class_id
	var cls = ConfigLoader.get_class_by_id(class_id)
	print("[ClassSelect] 选择职业: %s" % cls.get("display_name", ""))

	# 更新详情面板
	class_name_label.text = "【%s】%s" % [cls.get("display_name", ""), cls.get("title", "")]
	desc_label.text = cls.get("description", "")

	var stats = cls.get("base_stats", {})
	stats_label.text = "生命: %d | 伤害: %d | 攻速: %.1f | 移速: %d | 护甲: %d\n暴击率: %.0f%% | 暴击伤害: %.0f%%" % [
		stats.get("max_hp", 100),
		stats.get("damage", 10),
		stats.get("attack_speed", 1.0),
		stats.get("move_speed", 300),
		stats.get("armor", 0),
		stats.get("crit_chance", 0.05) * 100,
		stats.get("crit_damage", 1.5) * 100
	]

	# 启用确认按钮
	confirm_button.disabled = false

	# 高亮选中卡片
	_update_card_highlight(class_id)

## 更新卡片高亮效果
func _update_card_highlight(selected_id: String):
	for id in class_cards:
		var card = class_cards[id]
		var style = StyleBoxFlat.new()

		if id == selected_id:
			# 选中状态
			style.bg_color = Color(0.25, 0.22, 0.3, 1)
			style.set_border_width_all(3)
			style.border_color = Color(1, 0.8, 0.3, 1)
			style.shadow_color = Color(1, 0.8, 0.3, 0.3)
			style.shadow_size = 8
		else:
			# 未选中状态
			style.bg_color = Color(0.15, 0.14, 0.2, 1)
			style.set_border_width_all(2)
			style.border_color = Color(0.3, 0.3, 0.4, 1)

		style.set_corner_radius_all(8)
		card.add_theme_stylebox_override("panel", style)

func _on_confirm():
	if selected_class_id == "":
		print("[ClassSelect] 未选择职业")
		return
	print("[ClassSelect] 确认职业: %s" % selected_class_id)
	GameState.set_class(selected_class_id)
	# 进入新手村
	get_tree().change_scene_to_file("res://scenes/Town.tscn")

func _on_back():
	print("[ClassSelect] 返回主菜单")
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
