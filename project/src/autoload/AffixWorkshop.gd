extends Node
## 词缀工坊 - 洗练/重铸/词缀转移系统
## NPC "符文工匠" 提供装备词缀改造服务

signal reforge_completed(item_data: Dictionary)
signal dismantle_completed(shard_count: int)

func _ready():
	print("[AffixWorkshop] 词缀工坊初始化")

## 洗练装备：重新roll词缀，可锁定指定词缀
## @param instance_id: 装备实例UUID String（从 EquipmentSystem.equipment_instances 中查找）
## @param locked_affix_indices: 锁定的词缀索引数组（从0开始，对应 rolled_affixes）
## @return: 成功返回true，失败返回false
func reforge(instance_id: String, locked_affix_indices: Array[int] = []) -> bool:
	if not EquipmentSystem.equipment_instances.has(instance_id):
		push_warning("[AffixWorkshop] 未找到装备实例: %s" % instance_id)
		return false

	var instance = EquipmentSystem.equipment_instances[instance_id]
	if instance.is_empty():
		return false

	var rarity = instance.get("rarity", "common")
	var cost_data = _get_reforge_cost(rarity)

	# 检查消耗
	if not _check_resources(cost_data):
		push_warning("[AffixWorkshop] 资源不足，无法洗练")
		return false

	# 扣除消耗
	_consume_resources(cost_data)

	# 重新roll词缀（保留锁定的）
	var rolled_affixes = instance.get("rolled_affixes", [])
	var affix_count = rolled_affixes.size()
	if affix_count == 0:
		push_warning("[AffixWorkshop] 该装备没有词缀，无法洗练")
		return false

	var new_affixes = []

	# 锁定的词缀保留
	for idx in locked_affix_indices:
		if idx >= 0 and idx < rolled_affixes.size():
			new_affixes.append(rolled_affixes[idx])

	# 剩余槽位重新roll
	var remaining_slots = affix_count - new_affixes.size()
	for i in remaining_slots:
		var affix_id = _roll_random_affix(rarity)
		if affix_id != "":
			new_affixes.append({"affix_id": affix_id, "roll_value": randf_range(0.8, 1.0)})

	# 更新装备实例
	instance["rolled_affixes"] = new_affixes
	EquipmentSystem.equipment_instances[instance_id] = instance

	print("[AffixWorkshop] 洗练完成: %s (锁定%d个)" % [instance.get("template_id", "?"), locked_affix_indices.size()])
	var item_data = EquipmentSystem.get_equipment_instance_data(instance_id)
	reforge_completed.emit(item_data)
	return true

## 分解装备：获得符文碎片
## @param instance_id: 装备实例UUID String
## @return: 获得的碎片数量
func dismantle_equipment(instance_id: String) -> int:
	if not EquipmentSystem.equipment_instances.has(instance_id):
		push_warning("[AffixWorkshop] 未找到装备实例: %s" % instance_id)
		return 0

	var instance = EquipmentSystem.equipment_instances[instance_id]
	if instance.is_empty():
		return 0

	var rarity = instance.get("rarity", "common")
	var yield_count = _get_dismantle_yield(rarity)

	# 从背包移除
	EquipmentSystem.inventory.erase(instance_id)

	# 从实例表删除
	EquipmentSystem.equipment_instances.erase(instance_id)

	# 增加材料
	GameState.add_material("rune_shard", yield_count)

	print("[AffixWorkshop] 分解: %s -> %d符文碎片" % [instance.get("template_id", "?"), yield_count])
	dismantle_completed.emit(yield_count)
	return yield_count

## ============ 内部辅助 ============

## 获取洗练消耗
func _get_reforge_cost(rarity: String) -> Dictionary:
	var costs = ConfigLoader.balance_data.get("affix_workshop", {}).get("reforge_cost", {})
	return costs.get(rarity, {"gold": 100, "rune_shard": 1})

## 获取分解收益
func _get_dismantle_yield(rarity: String) -> int:
	var yields = ConfigLoader.balance_data.get("affix_workshop", {}).get("dismantle_yield", {})
	return yields.get(rarity, 1)

## 检查资源是否充足
func _check_resources(cost: Dictionary) -> bool:
	var gold = cost.get("gold", 0)
	var shards = cost.get("rune_shard", 0)

	if GameState.total_gold < gold:
		return false
	if GameState.get_material("rune_shard") < shards:
		return false
	return true

## 消耗资源
func _consume_resources(cost: Dictionary):
	var gold = cost.get("gold", 0)
	var shards = cost.get("rune_shard", 0)

	# 金币从 Player 扣除（单一数据源）
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.gold -= gold
	GameState.add_material("rune_shard", -shards)

## 获取适用于指定槽位和稀有度的词缀列表
func _get_applicable_affixes(slot: String, rarity: String) -> Array:
	var all_affixes = ConfigLoader.get_all_affixes()
	var result = []

	for affix in all_affixes:
		var applicable_slots = affix.get("applicable_slots", [])
		if applicable_slots.is_empty() or slot in applicable_slots:
			result.append(affix)

	return result

## 随机roll一个词缀ID
func _roll_random_affix(rarity: String) -> String:
	var all_affixes = ConfigLoader.get_all_affixes()
	if all_affixes.is_empty():
		return ""

	# 简单实现：从所有词缀中随机选一个
	# TODO: 可根据稀有度调整词缀池或权重
	var random_index = randi() % all_affixes.size()
	return all_affixes[random_index].get("id", "")


# ============================================================
# 装备强化系统 (模块5)
# ============================================================

## 装备强化：+0到+15，消耗金币+材料，有成功率
## 返回 {success: bool, new_level: int, cost: {gold, material}, message: String}
func enhance_equipment(instance_id: String) -> Dictionary:
	var eq_sys = get_node_or_null("/root/EquipmentSystem")
	if not eq_sys:
		return {success = false, message = "EquipmentSystem未找到"}

	var instance = eq_sys.get_equipment_instance(instance_id)
	if not instance:
		return {success = false, message = "装备不存在"}

	var current_level = instance.get("enhance_level", 0)
	var config = ConfigLoader.get_balance_config().get("equipment_enhancement", {})
	var max_level = config.get("max_level", 15)

	if current_level >= max_level:
		return {success = false, message = "已达最大强化等级+%d" % max_level}

	var rarity = instance.get("rarity", "common")
	var region = instance.get("region", "field")

	# 计算消耗
	var cost_table = config.get("costs", {}).get(rarity, config.get("costs", {}).get("common", {}))
	var gold_cost = cost_table.get("gold_base", 50) + int(cost_table.get("gold_per_level", 25) * current_level)
	var material_cost = int(cost_table.get("material_base", 1) + cost_table.get("material_per_level", 0.5) * current_level)

	# 检查资源
	var game_state = get_node_or_null("/root/GameState")
	if not game_state:
		return {success = false, message = "GameState未找到"}

	if game_state.gold < gold_cost:
		return {success = false, message = "金币不足(需要%d)" % gold_cost}

	var material_id = "material_" + region
	var current_material = game_state.materials.get(material_id, 0)
	if current_material < material_cost:
		return {success = false, message = "材料不足(需要%s x%d)" % [material_id, material_cost]}

	# 扣除资源
	game_state.gold -= gold_cost
	game_state.materials[material_id] = current_material - material_cost

	# 计算成功率
	var success_rates = config.get("success_rates", {})
	var success_rate = 1.0
	if current_level >= 10:
		success_rate = success_rates.get("11-15", 0.4)
	elif current_level >= 5:
		success_rate = success_rates.get("6-10", 0.7)
	else:
		success_rate = success_rates.get("1-5", 1.0)

	var roll = randf()
	var succeeded = roll < success_rate

	if succeeded:
		instance["enhance_level"] = current_level + 1
		return {
			success = true,
			new_level = current_level + 1,
			cost = {gold = gold_cost, material = material_cost},
			message = "强化成功！装备现在是+%d" % (current_level + 1)
		}
	else:
		return {
			success = false,
			new_level = current_level,
			cost = {gold = gold_cost, material = material_cost},
			message = "强化失败，装备保持+%d" % current_level
		}
