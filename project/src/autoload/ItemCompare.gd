extends Node
## ItemCompare - P10 装备对比器
##
## 用法（UI 调用）：
##   var diff = ItemCompare.compare_to_equipped(hovered_instance_id)
##   # diff: {damage: +5, max_hp: -10, ...}  正负数表示穿上后的差值
##
## 设计：装备对比是 ARPG 必需的体验，本系统纯函数式，不改变任何状态。


## 比较 hovered 装备穿上后相对当前的属性差异
## 返回：{stat_key: delta} 的字典；正数表示穿上后该属性更高
func compare_to_equipped(hovered_instance_id: String) -> Dictionary:
	if not EquipmentSystem.equipment_instances.has(hovered_instance_id):
		return {}
	var hovered = EquipmentSystem.get_equipment_instance_data(hovered_instance_id)
	if hovered.is_empty():
		return {}
	var slot = hovered.get("slot", "")
	if slot == "":
		return {}

	# 当前装备：构造一份"当前"快照
	var current_total = EquipmentSystem.get_total_stats(EquipmentSystem.equipped_items)

	# 模拟换装：临时替换该 slot 的 instance_id
	var simulated = EquipmentSystem.equipped_items.duplicate()
	simulated[slot] = hovered_instance_id
	var new_total = EquipmentSystem.get_total_stats(simulated)

	# 差值
	var diff: Dictionary = {}
	for k in new_total:
		var old_v = current_total.get(k, 0.0)
		var delta = float(new_total[k]) - float(old_v)
		# _mult 字段差值意义不同：直接给比率减 1
		if abs(delta) > 0.001:
			diff[k] = delta
	# 还要考虑当前 slot 是空（new_total 没新键时也要列出）
	for k in current_total:
		if not diff.has(k) and not new_total.has(k):
			diff[k] = -float(current_total[k])
	return diff


## 比较两件装备（不依赖玩家当前穿戴）
func compare_two(a_instance_id: String, b_instance_id: String) -> Dictionary:
	var a_total = _single_stats(a_instance_id)
	var b_total = _single_stats(b_instance_id)
	var diff: Dictionary = {}
	for k in b_total:
		var delta = float(b_total[k]) - float(a_total.get(k, 0.0))
		if abs(delta) > 0.001:
			diff[k] = delta
	for k in a_total:
		if not diff.has(k) and not b_total.has(k):
			diff[k] = -float(a_total[k])
	return diff


## 单件装备的属性快照（不含套装、词缀效果，仅 base_stats + 词缀属性）
func _single_stats(instance_id: String) -> Dictionary:
	if not EquipmentSystem.equipment_instances.has(instance_id):
		return {}
	var item = EquipmentSystem.get_equipment_instance_data(instance_id)
	if item.is_empty():
		return {}
	var stats = item.get("base_stats", {}).duplicate()
	# 应用强化等级
	var enhance = int(item.get(Schema.K_ENHANCEMENT_LEVEL, 0))
	if enhance > 0:
		var bal = ConfigLoader.get_balance_config().get("equipment_enhancement", {})
		var mult = 1.0 + enhance * float(bal.get("stat_bonus_per_level", 0.1))
		var new_stats = {}
		for k in stats:
			if typeof(stats[k]) in [TYPE_FLOAT, TYPE_INT]:
				new_stats[k] = float(stats[k]) * mult
			else:
				new_stats[k] = stats[k]
		stats = new_stats
	# 词缀的 add_stat 加成
	for affix_id in item.get("fixed_affixes", []):
		var affix = ConfigLoader.get_affix_by_id(affix_id)
		var eff = affix.get("effect", {})
		if eff.get("kind", "") == "add_stat":
			var stat_name = eff.get("stat", "")
			if stat_name != "":
				stats[stat_name] = float(stats.get(stat_name, 0.0)) + float(eff.get("value", 0))
	return stats


## 把 diff 字典格式化成富文本（绿色为正、红色为负），UI tooltip 直接用
func format_diff_richtext(diff: Dictionary) -> String:
	if diff.is_empty():
		return ""
	var lines: Array[String] = []
	for k in diff:
		var v = float(diff[k])
		var color = "lime" if v > 0 else "red"
		var sign = "+" if v > 0 else ""
		var formatted = "%s%.1f" % [sign, v]
		# 如果是整数倍率，用百分比格式
		if k.ends_with("_mult"):
			formatted = "%s%.0f%%" % [sign, v * 100.0]
		lines.append("[color=%s]%s: %s[/color]" % [color, k, formatted])
	return "\n".join(lines)
