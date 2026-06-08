extends Node
## 技能树系统 - 管理技能点分配与技能学习
## 替换原有的三选一Roguelite机制

# 已学技能: {skill_id: current_level}
var learned_skills: Dictionary = {}

# 未分配的技能点
var skill_points_unspent: int = 0

# 当前职业ID（用于过滤可学技能）
var current_class: String = ""

# 信号
signal skill_learned(skill_id: String, new_level: int)
signal skill_points_changed(points: int)

func _ready():
	print("[SkillSystem] 技能树系统初始化")

## 重置（新游戏开始时）
func reset():
	learned_skills.clear()
	skill_points_unspent = 0
	current_class = ""
	print("[SkillSystem] 技能树已重置")

## 设置当前职业
func set_current_class(class_id: String):
	current_class = class_id
	print("[SkillSystem] 职业设为: %s" % class_id)

## 增加技能点（升级时调用）
func add_skill_points(amount: int):
	skill_points_unspent += amount
	skill_points_changed.emit(skill_points_unspent)
	print("[SkillSystem] 获得技能点 +%d, 当前未分配: %d" % [amount, skill_points_unspent])

## 检查是否可以学习/升级技能
func can_learn(skill_id: String) -> bool:
	var skill_data = ConfigLoader.get_skill_by_id(skill_id)
	if skill_data.is_empty():
		return false

	# 检查职业匹配
	var skill_class = skill_data.get("class", "")
	if skill_class != "all" and skill_class != current_class:
		return false

	# 检查当前等级
	var current_level = learned_skills.get(skill_id, 0)
	var max_level = skill_data.get("max_level", 1)
	if current_level >= max_level:
		return false  # 已满级

	# 检查前置技能
	var prerequisites = skill_data.get("prerequisites", [])
	for prereq_id in prerequisites:
		if not learned_skills.has(prereq_id) or learned_skills[prereq_id] <= 0:
			return false  # 前置技能未学习

	# 检查技能点是否足够
	var sp_cost_list = skill_data.get("sp_cost_per_level", [])
	if sp_cost_list.size() > current_level:
		var sp_cost = sp_cost_list[current_level]
		if skill_points_unspent < sp_cost:
			return false  # 技能点不足

	return true

## 学习/升级技能
func learn_skill(skill_id: String) -> bool:
	if not can_learn(skill_id):
		return false

	var skill_data = ConfigLoader.get_skill_by_id(skill_id)
	var current_level = learned_skills.get(skill_id, 0)
	var sp_cost_list = skill_data.get("sp_cost_per_level", [])
	var sp_cost = sp_cost_list[current_level] if sp_cost_list.size() > current_level else 1

	# 消耗技能点
	skill_points_unspent -= sp_cost

	# 升级技能等级
	learned_skills[skill_id] = current_level + 1
	var new_level = learned_skills[skill_id]

	skill_learned.emit(skill_id, new_level)
	skill_points_changed.emit(skill_points_unspent)

	print("[SkillSystem] 学习技能: %s Lv.%d (消耗 %d SP)" % [skill_data.get("display_name", "?"), new_level, sp_cost])

	# 如果是主动技能，注册到ActiveSkillSystem
	if skill_data.get("type") == "active" and has_node("/root/ActiveSkillSystem"):
		get_node("/root/ActiveSkillSystem").register_skill(skill_data, new_level)

	# 如果是被动技能，通知Player重算属性
	if skill_data.get("type") == "passive":
		_apply_passive_skill(skill_data, new_level)

	return true

## 应用被动技能到玩家属性
func _apply_passive_skill(skill_data: Dictionary, level: int):
	var player = get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("recalculate_stats"):
		return

	# 被动技能效果会在Player的recalculate_stats中统一读取
	player.recalculate_stats()

## 获取技能当前等级效果
func get_skill_effect(skill_id: String) -> Dictionary:
	var current_level = learned_skills.get(skill_id, 0)
	if current_level <= 0:
		return {}

	var skill_data = ConfigLoader.get_skill_by_id(skill_id)
	if skill_data.is_empty():
		return {}

	# 如果有per_level数组，直接返回对应等级的效果
	var per_level = skill_data.get("per_level", [])
	if per_level.size() >= current_level:
		return per_level[current_level - 1]

	# 否则根据基础effect和level_scaling计算
	var effect = skill_data.get("effect", {}).duplicate(true)
	var scaling = skill_data.get("level_scaling", {})

	# 根据等级调整效果值
	if effect.has("damage"):
		effect["damage"] += (current_level - 1) * scaling.get("damage_per_level", 0)
	if effect.has("base_damage"):
		effect["base_damage"] += (current_level - 1) * scaling.get("damage_per_level", 0)
	if effect.has("value"):
		effect["value"] += (current_level - 1) * scaling.get("value_per_level", 0)

	return effect

## 获取当前职业所有可用技能（用于UI显示）
func get_available_skills_for_class() -> Array:
	var all_skills = ConfigLoader.get_all_skills()
	var available = []

	for skill_data in all_skills:
		var skill_class = skill_data.get("class", "")
		if skill_class == "all" or skill_class == current_class:
			available.append(skill_data)

	return available

## 获取技能当前等级
func get_skill_level(skill_id: String) -> int:
	return learned_skills.get(skill_id, 0)

## 获取所有已学技能列表
func get_learned_skills() -> Dictionary:
	return learned_skills.duplicate()




