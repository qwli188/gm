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
	_ready_dungeon_ui()

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


# ============================================================
# 阶段A: 副本流程UI (波次提示 + Boss血条)
# ============================================================

var wave_label: Label = null
var boss_health_container: VBoxContainer = null
var boss_health_bar: ProgressBar = null
var boss_name_label: Label = null
var tracked_boss: Node = null

func _ready_dungeon_ui():
	"""初始化副本UI（在_ready末尾调用）"""
	# 连接DungeonFlow信号
	if has_node("/root/DungeonFlow"):
		var df = get_node("/root/DungeonFlow")
		if not df.wave_started.is_connected(_on_wave_started):
			df.wave_started.connect(_on_wave_started)
		if not df.boss_spawned.is_connected(_on_boss_spawned):
			df.boss_spawned.connect(_on_boss_spawned)

## 显示波次提示（大字居中淡出）
func show_wave_text(text: String):
	if wave_label and is_instance_valid(wave_label):
		wave_label.queue_free()

	wave_label = Label.new()
	wave_label.text = text
	wave_label.add_theme_font_size_override("font_size", 48)
	wave_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	wave_label.add_theme_constant_override("outline_size", 4)
	wave_label.add_theme_color_override("font_outline_color", Color.BLACK)
	wave_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wave_label.anchor_left = 0.5
	wave_label.anchor_right = 0.5
	wave_label.anchor_top = 0.3
	wave_label.position = Vector2(-150, 0)
	wave_label.custom_minimum_size = Vector2(300, 60)
	$Control.add_child(wave_label)

	# 淡入淡出动画
	wave_label.modulate.a = 0.0
	var tween = create_tween()
	tween.tween_property(wave_label, "modulate:a", 1.0, 0.4)
	tween.tween_interval(1.5)
	tween.tween_property(wave_label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func():
		if is_instance_valid(wave_label):
			wave_label.queue_free()
	)

## 波次开始回调
func _on_wave_started(wave_index: int):
	show_wave_text("第 %d 波" % (wave_index + 1))

## Boss登场回调
func _on_boss_spawned():
	show_wave_text("⚔ BOSS ⚔")
	await get_tree().create_timer(0.5).timeout
	# 查找Boss节点
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and e.get("_is_boss"):
			_show_boss_health(e)
			break

## 显示Boss血条
func _show_boss_health(boss: Node):
	tracked_boss = boss

	# 创建Boss血条容器（屏幕底部中央）
	if boss_health_container and is_instance_valid(boss_health_container):
		boss_health_container.queue_free()

	boss_health_container = VBoxContainer.new()
	boss_health_container.anchor_left = 0.5
	boss_health_container.anchor_right = 0.5
	boss_health_container.anchor_top = 0.85
	boss_health_container.position = Vector2(-300, 0)
	boss_health_container.custom_minimum_size = Vector2(600, 50)
	$Control.add_child(boss_health_container)

	# Boss名称
	boss_name_label = Label.new()
	var boss_name = boss.enemy_data.get("display_name", boss.enemy_data.get("name", "BOSS")) if boss.get("enemy_data") else "BOSS"
	boss_name_label.text = boss_name
	boss_name_label.add_theme_font_size_override("font_size", 22)
	boss_name_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	boss_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_health_container.add_child(boss_name_label)

	# Boss血条
	boss_health_bar = ProgressBar.new()
	boss_health_bar.custom_minimum_size = Vector2(600, 24)
	boss_health_bar.show_percentage = false
	var boss_max_hp = boss.get("max_hp") if boss.get("max_hp") else 1000
	boss_health_bar.max_value = boss_max_hp
	boss_health_bar.value = boss_max_hp

	# 红色样式
	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.15, 0.15)
	fill.corner_radius_top_left = 3
	fill.corner_radius_top_right = 3
	fill.corner_radius_bottom_left = 3
	fill.corner_radius_bottom_right = 3
	boss_health_bar.add_theme_stylebox_override("fill", fill)
	boss_health_container.add_child(boss_health_bar)

func _process(_delta):
	# 更新Boss血条
	if tracked_boss and is_instance_valid(tracked_boss) and boss_health_bar:
		var current = tracked_boss.get("current_hp")
		if current != null:
			boss_health_bar.value = current
	elif boss_health_container and is_instance_valid(boss_health_container):
		# Boss已死亡，隐藏血条
		if not is_instance_valid(tracked_boss):
			boss_health_container.queue_free()
			boss_health_container = null
			tracked_boss = null
