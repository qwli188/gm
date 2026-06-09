extends CanvasLayer

@onready var health_bar: ProgressBar = $Control/TopLeft/HealthBar
@onready var health_label: Label = $Control/TopLeft/HealthLabel
@onready var class_resource_bar: HBoxContainer = $Control/TopLeft/ClassResourceBar
@onready var level_label: Label = $Control/TopLeft/LevelLabel
@onready var exp_label: Label = $Control/TopLeft/ExpLabel
@onready var kills_label: Label = $Control/TopLeft/KillsLabel
@onready var gold_label: Label = $Control/TopLeft/GoldLabel
@onready var time_label: Label = $Control/TopLeft/TimeLabel
@onready var attack_mode_label: Label = $Control/BottomLeft/AttackModeLabel

var player: CharacterBody2D

func _ready():
	# 应用主题
	ThemeGenerator.apply_theme_to_node(self)
	_apply_custom_bar_styles()

	player = get_tree().get_first_node_in_group("player")
	if player:
		player.hp_changed.connect(_on_player_hp_changed)
		player.auto_attack_toggled.connect(_on_auto_attack_toggled)
		player.level_up.connect(_on_player_level_up)
		_on_player_hp_changed(player.current_hp, player.max_hp)

	_beautify_ui()
	_setup_class_resource_bar()

## 应用自定义进度条样式
func _apply_custom_bar_styles():
	if health_bar:
		health_bar.add_theme_stylebox_override("fill", ThemeGenerator.create_health_bar_style())

## 设置职业资源条（根据职业配置）
func _setup_class_resource_bar():
	if not class_resource_bar:
		return

	# 根据职业设置资源类型（从 GameState 获取）
	var current_class = ""
	if has_node("/root/GameState"):
		var cls = get_node("/root/GameState").get_current_class()
		current_class = cls.get("id", "")

	# 根据职业ID配置资源条(修复: 用 class_ 前缀的真实ID)
	match current_class:
		"class_warrior":
			class_resource_bar.set_resource_type(class_resource_bar.ResourceType.RAGE)
			class_resource_bar.set_resource_name("怒气")
			class_resource_bar.set_resource_value(0, 100)
		"class_mage":
			class_resource_bar.set_resource_type(class_resource_bar.ResourceType.MANA)
			class_resource_bar.set_resource_name("法力")
			class_resource_bar.set_resource_value(100, 100)
		"class_assassin":
			class_resource_bar.set_resource_type(class_resource_bar.ResourceType.ENERGY)
			class_resource_bar.set_resource_name("潜行")
			class_resource_bar.set_resource_value(0, 100)
		"class_ranger":
			class_resource_bar.set_resource_type(class_resource_bar.ResourceType.COMBO)
			class_resource_bar.set_resource_name("精准")
			class_resource_bar.set_resource_value(0, 10)
		"class_knight":
			class_resource_bar.set_resource_type(class_resource_bar.ResourceType.HOLY)
			class_resource_bar.set_resource_name("圣盾")
			class_resource_bar.set_resource_value(0, 100)
		"class_necromancer":
			class_resource_bar.set_resource_type(class_resource_bar.ResourceType.CUSTOM)
			class_resource_bar.set_resource_name("灵能")
			class_resource_bar.set_custom_color(Color("#9B4DCA"))
			class_resource_bar.set_resource_value(0, 100)
		_:
			class_resource_bar.visible = false

	# 连接 ClassMechanicSystem 信号(怒气/法力/精准实时更新)
	if has_node("/root/ClassMechanicSystem"):
		var cms = get_node("/root/ClassMechanicSystem")
		if cms.has_signal("rage_changed") and not cms.rage_changed.is_connected(_on_rage_changed):
			cms.rage_changed.connect(_on_rage_changed)
		if cms.has_signal("mana_changed") and not cms.mana_changed.is_connected(_on_mana_changed):
			cms.mana_changed.connect(_on_mana_changed)
		if cms.has_signal("precision_changed") and not cms.precision_changed.is_connected(_on_precision_changed):
			cms.precision_changed.connect(_on_precision_changed)

func _on_rage_changed(current: float, maximum: float):
	if class_resource_bar:
		class_resource_bar.set_resource_value(current, maximum)

func _on_mana_changed(current: float, maximum: float):
	if class_resource_bar:
		class_resource_bar.set_resource_value(current, maximum)

func _on_precision_changed(stacks: int, _target):
	if class_resource_bar:
		class_resource_bar.set_resource_value(stacks, 10)

## 美化HUD：用生成的UI素材替换默认样式
func _beautify_ui():
	# 血条/经验条使用生成的纹理
	var hp_tex = SpriteLibrary.get_ui("bar_hp")
	if hp_tex and health_bar:
		var fill = StyleBoxTexture.new()
		fill.texture = hp_tex
		health_bar.add_theme_stylebox_override("fill", fill)
	var exp_tex = SpriteLibrary.get_ui("bar_exp")
	if exp_tex:
		var fill = StyleBoxTexture.new()
		fill.texture = exp_tex
		# 经验条在exp_label下方没有单独ProgressBar，跳过
	# 装备槽使用生成的格子纹理
	var slot_tex = SpriteLibrary.get_ui("slot")
	if slot_tex:
		for i in range(1, 4):
			var slot = get_node_or_null("Control/TopRight/EquipSlot%d" % i)
			if slot:
				slot.texture = slot_tex

func _process(delta):
	if player:
		_update_stats()

func _update_stats():
	# 更新生命
	health_bar.max_value = player.max_hp
	health_bar.value = player.current_hp
	health_label.text = "生命: %d / %d" % [int(player.current_hp), int(player.max_hp)]

	# 更新等级和经验
	level_label.text = "等级: %d" % player.current_level
	exp_label.text = "经验: %d / %d" % [int(player.current_exp), int(player.exp_to_next_level)]

	# 更新击杀和金币
	kills_label.text = "击杀: %d" % player.kills
	gold_label.text = "金币: %d" % player.gold

	# 更新存活时间
	var minutes = int(player.survival_time / 60)
	var seconds = int(player.survival_time) % 60
	time_label.text = "时间: %02d:%02d" % [minutes, seconds]

func _on_player_hp_changed(current: float, maximum: float):
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
	if health_label:
		health_label.text = "生命: %d / %d" % [int(current), int(maximum)]

func _on_auto_attack_toggled(enabled: bool):
	if attack_mode_label:
		attack_mode_label.text = "攻击模式: " + ("自动" if enabled else "手动")

func _on_player_level_up(new_level: int):
	# 升级音效
	AudioManager.play("level_up")
