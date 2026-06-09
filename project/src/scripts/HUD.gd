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
	_setup_skill_bar()

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
	_update_boss_health()
	_update_skill_bar_cd()

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
	# 连接EnemySpawner的Boss信号（场景树节点）
	await get_tree().process_frame  # 等待场景树就绪
	var spawner = get_tree().get_first_node_in_group("enemy_spawner")
	if not spawner:
		# 尝试通过路径查找
		var main = get_tree().current_scene
		if main and main.has_node("EnemySpawner"):
			spawner = main.get_node("EnemySpawner")

	if spawner and spawner.has_signal("boss_spawned"):
		if not spawner.boss_spawned.is_connected(_on_spawner_boss):
			spawner.boss_spawned.connect(_on_spawner_boss)

## EnemySpawner Boss生成回调
func _on_spawner_boss(boss_node):
	show_wave_text("⚔ BOSS ⚔")
	if is_instance_valid(boss_node):
		await get_tree().create_timer(0.5).timeout
		_show_boss_health(boss_node)

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

func _update_boss_health():
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



# ============================================================
# 阶段C2: 技能栏UI (1/2/3技能槽 + CD显示)
# ============================================================

var skill_bar: HBoxContainer = null
var skill_slots: Array = []  # [{panel, icon, cd_label, key_label}]

func _setup_skill_bar():
	"""创建底部中央技能栏"""
	skill_bar = HBoxContainer.new()
	skill_bar.add_theme_constant_override("separation", 8)
	skill_bar.anchor_left = 0.5
	skill_bar.anchor_right = 0.5
	skill_bar.anchor_top = 1.0
	skill_bar.anchor_bottom = 1.0
	skill_bar.position = Vector2(-120, -80)
	$Control.add_child(skill_bar)

	# 创建3个技能槽
	for i in range(3):
		var slot = _create_skill_slot(i)
		skill_bar.add_child(slot.panel)
		skill_slots.append(slot)

	_refresh_skill_bar()

func _create_skill_slot(index: int) -> Dictionary:
	var panel = Panel.new()
	panel.custom_minimum_size = Vector2(64, 64)

	# 背景样式
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.15, 0.15, 0.2, 0.9)
	style.border_color = Color(0.5, 0.5, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	# 技能图标（颜色块占位）
	var icon = ColorRect.new()
	icon.size = Vector2(56, 56)
	icon.position = Vector2(4, 4)
	icon.color = Color(0.3, 0.4, 0.6)
	panel.add_child(icon)

	# 快捷键标签（左上角）
	var key_label = Label.new()
	key_label.text = str(index + 1)
	key_label.add_theme_font_size_override("font_size", 14)
	key_label.add_theme_color_override("font_color", Color.WHITE)
	key_label.position = Vector2(4, 2)
	panel.add_child(key_label)

	# 技能名（底部）
	var name_label = Label.new()
	name_label.add_theme_font_size_override("font_size", 9)
	name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	name_label.position = Vector2(4, 48)
	name_label.size = Vector2(56, 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(name_label)

	# CD遮罩（半透明黑色覆盖层）
	var cd_overlay = ColorRect.new()
	cd_overlay.size = Vector2(56, 56)
	cd_overlay.position = Vector2(4, 4)
	cd_overlay.color = Color(0, 0, 0, 0.6)
	cd_overlay.visible = false
	panel.add_child(cd_overlay)

	# CD倒计时文字（居中大字）
	var cd_label = Label.new()
	cd_label.add_theme_font_size_override("font_size", 24)
	cd_label.add_theme_color_override("font_color", Color.WHITE)
	cd_label.position = Vector2(4, 16)
	cd_label.size = Vector2(56, 32)
	cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cd_label.visible = false
	panel.add_child(cd_label)

	return {
		"panel": panel,
		"icon": icon,
		"name_label": name_label,
		"cd_overlay": cd_overlay,
		"cd_label": cd_label
	}

## 刷新技能栏（更新技能名称/图标）
func _refresh_skill_bar():
	if not has_node("/root/ActiveSkillSystem"):
		return

	var ask = get_node("/root/ActiveSkillSystem")
	var manual_skills = ask.get("manual_skills")
	if manual_skills == null:
		return

	for i in range(min(3, skill_slots.size())):
		var slot = skill_slots[i]
		var skill_id = manual_skills[i] if i < manual_skills.size() else ""

		if skill_id == "":
			slot.name_label.text = "空"
			slot.icon.color = Color(0.2, 0.2, 0.25)
			continue

		# 获取技能数据
		var skill_data = _get_skill_info(skill_id)
		slot.name_label.text = skill_data.get("display_name", skill_id).substr(0, 4)

		# 根据effect类型设置颜色
		var effect_kind = skill_data.get("effect", {}).get("kind", "")
		slot.icon.color = _skill_kind_color(effect_kind)

func _get_skill_info(skill_id: String) -> Dictionary:
	for s in ConfigLoader.get_all_skills():
		if s.get("id") == skill_id:
			return s
	return {}

func _skill_kind_color(kind: String) -> Color:
	match kind:
		"dash": return Color(0.4, 0.8, 0.4)
		"aoe", "melee_swing": return Color(0.9, 0.5, 0.2)
		"projectile": return Color(0.4, 0.6, 0.9)
		"buff", "add_stat", "mult_stat": return Color(0.9, 0.85, 0.3)
		"summon": return Color(0.6, 0.3, 0.7)
		"aura": return Color(0.3, 0.7, 0.8)
		"channel": return Color(0.8, 0.3, 0.5)
		"execute": return Color(0.9, 0.2, 0.2)
		_: return Color(0.4, 0.4, 0.5)

## 更新技能栏CD（每帧调用）
func _update_skill_bar_cd():
	if not has_node("/root/ActiveSkillSystem"):
		return

	var ask = get_node("/root/ActiveSkillSystem")
	var manual_skills = ask.get("manual_skills")
	var cooldowns = ask.get("manual_cooldowns")
	if manual_skills == null or cooldowns == null:
		return

	for i in range(min(3, skill_slots.size())):
		var slot = skill_slots[i]
		var skill_id = manual_skills[i] if i < manual_skills.size() else ""

		if skill_id == "":
			continue

		var cd = cooldowns.get(skill_id, 0.0)
		if cd > 0:
			slot.cd_overlay.visible = true
			slot.cd_label.visible = true
			slot.cd_label.text = "%.0f" % ceil(cd)
		else:
			slot.cd_overlay.visible = false
			slot.cd_label.visible = false
