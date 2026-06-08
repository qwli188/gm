extends Control

signal skill_selected(skill_id: String)

@onready var skill_card_1: VBoxContainer = $Panel/VBoxContainer/SkillCard1
@onready var skill_card_2: VBoxContainer = $Panel/VBoxContainer/SkillCard2
@onready var skill_card_3: VBoxContainer = $Panel/VBoxContainer/SkillCard3

var skill_options: Array = []

func _ready():
	hide()

	# 连接按钮信号
	skill_card_1.get_node("SelectButton").pressed.connect(_on_skill_1_selected)
	skill_card_2.get_node("SelectButton").pressed.connect(_on_skill_2_selected)
	skill_card_3.get_node("SelectButton").pressed.connect(_on_skill_3_selected)

## 显示升级界面，传入3个技能选项
func show_level_up(skills: Array):
	if skills.size() != 3:
		push_error("[LevelUpUI] 技能选项必须是3个")
		return

	skill_options = skills

	# 填充3个技能卡片
	_populate_skill_card(skill_card_1, skills[0])
	_populate_skill_card(skill_card_2, skills[1])
	_populate_skill_card(skill_card_3, skills[2])

	# 暂停游戏并显示UI
	get_tree().paused = true
	show()

## 填充技能卡片UI
func _populate_skill_card(card: VBoxContainer, skill_data: Dictionary):
	var name_label: Label = card.get_node("NameLabel")
	var desc_label: Label = card.get_node("DescLabel")
	var icon_rect: ColorRect = card.get_node("IconRect")

	name_label.text = skill_data.get("display_name", "???")

	# 生成描述文本
	var desc = _generate_skill_description(skill_data)
	desc_label.text = desc

	# 图标占位（暂时用颜色区分稀有度）
	var rarity = skill_data.get("rarity", "common")
	icon_rect.color = _get_rarity_color(rarity)

## 生成技能描述
func _generate_skill_description(skill_data: Dictionary) -> String:
	var desc = ""
	var skill_type = skill_data.get("type", "")
	var effect = skill_data.get("effect", {})

	# 显示类型
	if skill_type == "active":
		desc += "[主动] "
	elif skill_type == "passive":
		desc += "[被动] "

	# 显示效果
	var kind = effect.get("kind", "")
	match kind:
		"projectile":
			var damage = effect.get("base_damage", 0)
			var cooldown = effect.get("cooldown", 0)
			desc += "发射弹道，造成 %d 伤害\n冷却: %.1f秒" % [damage, cooldown]
		"melee_swing":
			var damage = effect.get("damage", 0)
			var arc = effect.get("arc", 0)
			var cooldown = effect.get("cooldown", 0)
			desc += "%d度旋转攻击，造成 %d 伤害\n冷却: %.1f秒" % [arc, damage, cooldown]
		"add_stat":
			var stat = effect.get("stat", "")
			var value = effect.get("value", 0)
			desc += "%s +%s" % [_translate_stat(stat), value]
		"mult_stat":
			var stat = effect.get("stat", "")
			var value = effect.get("value", 0.0)
			desc += "%s +%d%%" % [_translate_stat(stat), value * 100]
		_:
			desc += "效果: " + kind

	return desc

## 翻译属性名
func _translate_stat(stat: String) -> String:
	match stat:
		"move_speed": return "移动速度"
		"max_hp": return "最大生命"
		"damage": return "伤害"
		"attack_speed": return "攻击速度"
		"crit_chance": return "暴击率"
		"crit_damage": return "暴击伤害"
		_: return stat

## 获取稀有度颜色
func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color(0.6, 0.6, 0.6)
		"uncommon": return Color(0.2, 0.8, 0.2)
		"rare": return Color(0.2, 0.5, 1.0)
		"legendary": return Color(1.0, 0.6, 0.0)
		_: return Color.WHITE

func _on_skill_1_selected():
	_select_skill(0)

func _on_skill_2_selected():
	_select_skill(1)

func _on_skill_3_selected():
	_select_skill(2)

func _select_skill(index: int):
	if index >= skill_options.size():
		return

	var selected_skill = skill_options[index]
	skill_selected.emit(selected_skill.get("id", ""))

	# 恢复游戏并隐藏UI
	get_tree().paused = false
	hide()
