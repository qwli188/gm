extends Node
## 标签联动系统 - 统计装备+技能标签，触发N个同标签的协同加成
## 玩家集齐fire/crit/physical等标签达到阈值时，激活额外加成
## 示例：3个fire标签→火焰伤害+20%，5个fire标签→点燃持续时间+50%

# 当前激活的标签联动加成缓存 {tag: count}
var active_tag_counts: Dictionary = {}

# 上一帧的标签计数，用于检测变化
var _prev_tag_counts: Dictionary = {}

signal tag_synergy_changed(tag: String, count: int)


func _ready() -> void:
	print("[TagSynergySystem] 标签联动系统初始化")
	# 迁移到 EventBus（旧代码：EquipmentSystem.equipment_changed）
	EventBus.equipment_changed.connect(_on_equipment_changed)


## 重新统计当前所有标签（装备+技能）
func recompute_tags():
	var tag_counts = {}

	# 1. 统计装备标签
	if has_node("/root/EquipmentSystem"):
		var eq_sys = get_node("/root/EquipmentSystem")
		for slot in eq_sys.SLOTS:
			var instance_id = eq_sys.equipped_items.get(slot, null)
			if instance_id == null:
				continue
			var item = eq_sys.get_equipment_instance_data(instance_id)
			if item.is_empty():
				continue
			for tag in item.get("tags", []):
				tag_counts[tag] = tag_counts.get(tag, 0) + 1

	# 2. 统计技能标签（未来扩展：SkillSystem）
	# TODO: 当技能系统实现后，这里读取玩家已装备技能的标签
	# if has_node("/root/SkillSystem"):
	#     var skills = get_node("/root/SkillSystem").get_equipped_skills()
	#     for skill in skills:
	#         for tag in skill.get("tags", []):
	#             tag_counts[tag] = tag_counts.get(tag, 0) + 1

	# 检测变化并发送信号
	for tag in tag_counts:
		if _prev_tag_counts.get(tag, 0) != tag_counts[tag]:
			tag_synergy_changed.emit(tag, tag_counts[tag])

	_prev_tag_counts = active_tag_counts.duplicate()
	active_tag_counts = tag_counts

	# 调试：打印标签统计
	if not active_tag_counts.is_empty():
		print("[TagSynergySystem] 标签统计: %s" % str(active_tag_counts))
		var bonuses = get_tag_synergy_bonuses()
		if not bonuses.is_empty():
			print("[TagSynergySystem] 标签联动加成激活: %s" % str(bonuses))


## 获取某标签当前数量
func get_tag_count(tag: String) -> int:
	return active_tag_counts.get(tag, 0)


## 获取当前激活的标签联动加成
## 返回格式: {"fire_damage_mult": 0.2, "crit_chance": 0.05, ...}
func get_tag_synergy_bonuses() -> Dictionary:
	var bonuses = {}

	var config = ConfigLoader.get_balance_config().get("tag_synergy", {})
	if config.is_empty():
		return bonuses

	# 遍历每个标签的联动配置
	for tag in active_tag_counts:
		var count = active_tag_counts[tag]
		var tag_config = config.get(tag, {})
		if tag_config.is_empty():
			continue

		# 检查每个阈值档位
		for threshold_str in tag_config:
			var threshold = int(threshold_str)
			if count >= threshold:
				# 达到阈值，合并加成
				var tier_bonuses = tag_config[threshold_str]
				for stat_key in tier_bonuses:
					bonuses[stat_key] = bonuses.get(stat_key, 0.0) + tier_bonuses[stat_key]

	return bonuses


## 获取标签联动的描述（供UI显示）
## 返回格式: [{"tag": "fire", "count": 5, "active_tiers": [3, 5], "next_tier": null}, ...]
func get_tag_synergy_info() -> Array:
	var info = []
	var config = ConfigLoader.get_balance_config().get("tag_synergy", {})

	# 只显示有配置且有计数的标签
	var tags_to_show = {}
	for tag in active_tag_counts:
		if config.has(tag):
			tags_to_show[tag] = active_tag_counts[tag]

	for tag in tags_to_show:
		var count = tags_to_show[tag]
		var tag_config = config.get(tag, {})

		# 找出已激活的阈值
		var active_tiers = []
		var all_tiers = []
		for threshold_str in tag_config:
			var threshold = int(threshold_str)
			all_tiers.append(threshold)
			if count >= threshold:
				active_tiers.append(threshold)

		all_tiers.sort()
		active_tiers.sort()

		# 找下一个未激活的阈值
		var next_tier = null
		for tier in all_tiers:
			if tier > count:
				next_tier = tier
				break

		info.append(
			{"tag": tag, "count": count, "active_tiers": active_tiers, "next_tier": next_tier}
		)

	return info


## 装备变化时自动重算
func _on_equipment_changed():
	recompute_tags()
	# 通知玩家重新计算属性
	var tree = Engine.get_main_loop()
	if tree and tree.has_method("get_first_node_in_group"):
		var player = tree.get_first_node_in_group("player")
		if player and player.has_method("recalculate_stats"):
			player.recalculate_stats()
