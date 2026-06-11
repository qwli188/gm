extends Control
## 技能树面板 - 显示职业技能树并允许玩家加点

signal skill_tree_closed

# UI节点引用
@onready var skill_points_label: Label = $Panel/TopBar/SkillPointsLabel
@onready var skill_tree_container: VBoxContainer = $Panel/ScrollContainer/SkillTreeContainer
@onready var close_button: Button = $Panel/TopBar/CloseButton
@onready var skill_tooltip: PanelContainer = $SkillTooltip

# 当前职业技能列表
var current_skills: Array = []

# 技能分支（按tags分类）
var skill_branches: Dictionary = {}


func _ready():
	hide()
	close_button.pressed.connect(_on_close_pressed)
	skill_tooltip.hide()


## 显示技能树面板
func show_skill_tree():
	_refresh_skill_tree()
	show()
	get_tree().paused = true


## 刷新技能树显示
func _refresh_skill_tree():
	# 清空现有技能按钮
	for child in skill_tree_container.get_children():
		child.queue_free()

	# 更新技能点显示
	if has_node("/root/SkillSystem"):
		var sp = get_node("/root/SkillSystem").skill_points_unspent
		skill_points_label.text = "可用技能点: %d" % sp

	# 获取当前职业技能
	current_skills = get_node("/root/SkillSystem").get_available_skills_for_class()

	# 按tags分类技能（战士示例：melee/defense/rage）
	skill_branches = _categorize_skills(current_skills)

	# 为每个分支创建UI
	for branch_name in skill_branches.keys():
		_create_branch_ui(branch_name, skill_branches[branch_name])


## 按第一个tag分类技能
func _categorize_skills(skills: Array) -> Dictionary:
	var branches = {}

	for skill_data in skills:
		var tags = skill_data.get("tags", [])
		if tags.is_empty():
			continue

		# 使用第一个tag作为分支名
		var branch_name = tags[0]
		if not branches.has(branch_name):
			branches[branch_name] = []

		branches[branch_name].append(skill_data)

	return branches


## 创建分支UI
func _create_branch_ui(branch_name: String, skills: Array):
	# 分支标题
	var branch_label = Label.new()
	branch_label.text = _translate_branch(branch_name)
	branch_label.add_theme_font_size_override("font_size", 18)
	skill_tree_container.add_child(branch_label)

	# 技能按钮容器（横向排列）
	var skill_hbox = HBoxContainer.new()
	skill_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	skill_tree_container.add_child(skill_hbox)

	# 为每个技能创建按钮
	for skill_data in skills:
		_create_skill_button(skill_hbox, skill_data)

	# 分支间隔
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	skill_tree_container.add_child(spacer)


## 创建单个技能按钮
func _create_skill_button(parent: Container, skill_data: Dictionary):
	var button = Button.new()
	button.custom_minimum_size = Vector2(120, 80)
	button.text = skill_data.get("display_name", "???")

	var skill_id = skill_data.get("id", "")
	var skill_system = get_node("/root/SkillSystem")
	var current_level = skill_system.get_skill_level(skill_id)
	var max_level = skill_data.get("max_level", 1)

	# 显示等级
	if current_level > 0:
		button.text += "\nLv.%d/%d" % [current_level, max_level]
	else:
		button.text += "\n未学习"

	# 检查是否可学习
	var can_learn = skill_system.can_learn(skill_id)

	# 设置按钮样式
	if current_level >= max_level:
		button.disabled = true
		button.modulate = Color(0.5, 1.0, 0.5)  # 满级绿色
	elif not can_learn:
		button.disabled = true
		button.modulate = Color(0.5, 0.5, 0.5)  # 不可学灰色
	else:
		button.modulate = Color(1.0, 1.0, 0.7)  # 可学高亮

	# 连接信号
	button.pressed.connect(_on_skill_button_pressed.bind(skill_id))
	button.mouse_entered.connect(_on_skill_button_hover.bind(skill_data, button))
	button.mouse_exited.connect(_on_skill_button_unhover)

	parent.add_child(button)


## 技能按钮点击
func _on_skill_button_pressed(skill_id: String):
	var skill_system = get_node("/root/SkillSystem")
	if skill_system.learn_skill(skill_id):
		AudioManager.play("skill_learn")
		_refresh_skill_tree()  # 刷新UI
	else:
		AudioManager.play("error")


## 技能按钮悬停
func _on_skill_button_hover(skill_data: Dictionary, button: Button):
	# 显示技能详情tooltip
	_show_tooltip(skill_data, button.global_position)


## 技能按钮取消悬停
func _on_skill_button_unhover():
	skill_tooltip.hide()


## 显示技能tooltip
func _show_tooltip(skill_data: Dictionary, pos: Vector2):
	var skill_id = skill_data.get("id", "")
	var skill_system = get_node("/root/SkillSystem")
	var current_level = skill_system.get_skill_level(skill_id)
	var max_level = skill_data.get("max_level", 1)

	# 构建tooltip文本
	var text = "[b]%s[/b]\n" % skill_data.get("display_name", "???")
	text += "类型: %s\n" % ("主动" if skill_data.get("type") == "active" else "被动")
	text += "等级: %d/%d\n\n" % [current_level, max_level]

	# 显示当前等级效果
	var effect = skill_system.get_skill_effect(skill_id)
	if not effect.is_empty():
		text += _format_skill_effect(effect)
	else:
		text += _format_skill_effect(skill_data.get("effect", {}))

	text += (
		"\n\n前置: %s"
		% (
			"无"
			if skill_data.get("prerequisites", []).is_empty()
			else str(skill_data.get("prerequisites", []))
		)
	)

	# 显示下一级消耗
	if current_level < max_level:
		var sp_cost_list = skill_data.get("sp_cost_per_level", [])
		if sp_cost_list.size() > current_level:
			var sp_cost = sp_cost_list[current_level]
			text += "\n下一级消耗: %d SP" % sp_cost

	# 设置tooltip内容
	var label = skill_tooltip.get_node_or_null("Label")
	if label == null:
		label = RichTextLabel.new()
		label.name = "Label"
		label.bbcode_enabled = true
		label.fit_content = true
		skill_tooltip.add_child(label)

	label.text = text
	skill_tooltip.global_position = pos + Vector2(10, -50)
	skill_tooltip.show()


## 格式化技能效果描述
func _format_skill_effect(effect: Dictionary) -> String:
	var text = ""
	var kind = effect.get("kind", "")

	match kind:
		"melee_swing":
			text += "伤害: %d\n" % effect.get("damage", 0)
			text += "范围: %d度" % effect.get("arc", 0)
		"projectile":
			text += "伤害: %d\n" % effect.get("base_damage", 0)
			text += "弹道数: %d" % effect.get("projectile_count", 1)
		"add_stat":
			text += "%s +%s" % [_translate_stat(effect.get("stat", "")), effect.get("value", 0)]
		"mult_stat":
			text += (
				"%s +%d%%"
				% [_translate_stat(effect.get("stat", "")), effect.get("value", 0.0) * 100]
			)
		"execute":
			text += "斩杀线: %d%%\n" % (effect.get("threshold", 0.3) * 100)
			text += "伤害倍率: %.1fx" % effect.get("bonus_mult", 1.0)
		_:
			text += "效果: %s" % kind

	if effect.has("cooldown"):
		text += "\n冷却: %.1fs" % effect.get("cooldown", 0)

	return text


## 翻译属性名
func _translate_stat(stat: String) -> String:
	match stat:
		"armor":
			return "护甲"
		"max_hp":
			return "最大生命"
		"damage":
			return "伤害"
		"attack_speed":
			return "攻击速度"
		"crit_chance":
			return "暴击率"
		"crit_damage":
			return "暴击伤害"
		"move_speed":
			return "移动速度"
		_:
			return stat


## 翻译分支名
func _translate_branch(branch: String) -> String:
	match branch:
		"melee":
			return "近战系"
		"defense":
			return "防御系"
		"tank":
			return "坦克系"
		"rage":
			return "怒气系"
		"ranged":
			return "远程系"
		"crit":
			return "暴击系"
		"mobility":
			return "机动系"
		"fire":
			return "火焰系"
		"magic":
			return "魔法系"
		"stealth":
			return "潜行系"
		"poison":
			return "毒素系"
		"holy":
			return "神圣系"
		"undead":
			return "亡灵系"
		"summon":
			return "召唤系"
		_:
			return branch.capitalize()  # gdlint:ignore=max-returns


## 关闭按钮
func _on_close_pressed():
	get_tree().paused = false
	hide()
	skill_tree_closed.emit()
