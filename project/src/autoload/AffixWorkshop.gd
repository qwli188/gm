extends Node
## 词缀工坊 - 洗练/重铸/词缀转移系统
## NPC "符文工匠" 提供装备词缀改造服务

signal reforge_completed(item_data: Dictionary)
signal dismantle_completed(shard_count: int)
signal upgrade_completed(item_data: Dictionary)
signal sanctify_completed(instance_id: String)

# P6: 神圣化标记池（instance_id -> true 表示下次强化必成）
# 不进存档（强化后立刻消耗），但持久化为 EquipmentSystem 实例字段后续可考虑
var _sanctified: Dictionary = {}


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

	print_verbose(
		(
			"[AffixWorkshop] 洗练完成: %s (锁定%d个)"
			% [instance.get("template_id", "?"), locked_affix_indices.size()]
		)
	)
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

	# 从背包/仓库移除（PR-3 后由 Inventory 管理）
	if has_node("/root/Inventory"):
		Inventory.backpack.erase(instance_id)
		Inventory.warehouse.erase(instance_id)
		Inventory.backpack_changed.emit()
		Inventory.warehouse_changed.emit()

	# 从实例表删除
	EquipmentSystem.equipment_instances.erase(instance_id)

	# 增加材料
	GameState.add_material("rune_shard", yield_count)

	print_verbose(
		"[AffixWorkshop] 分解: %s -> %d符文碎片" % [instance.get("template_id", "?"), yield_count]
	)
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

	# 金币从持久钱包扣除（工坊是城镇活动，钱包 = GameState.total_gold 单一真源）
	GameState.total_gold -= gold
	GameState.add_material("rune_shard", -shards)


## 获取适用于指定槽位和稀有度的词缀列表
func _get_applicable_affixes(slot: String, _rarity: String) -> Array:
	var all_affixes = ConfigLoader.get_all_affixes()
	var result = []

	for affix in all_affixes:
		var applicable_slots = affix.get("applicable_slots", [])
		if applicable_slots.is_empty() or slot in applicable_slots:
			result.append(affix)

	return result


## 随机roll一个词缀ID
func _roll_random_affix(_rarity: String) -> String:
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


## 装备强化：+0到+15，消耗金币+符文碎片，有成功率
## 返回 {success: bool, new_level: int, cost: {gold, material}, message: String}
func enhance_equipment(instance_id: String) -> Dictionary:
	if not EquipmentSystem.equipment_instances.has(instance_id):
		return {success = false, message = "装备不存在"}

	var instance = EquipmentSystem.equipment_instances[instance_id]
	if instance.is_empty():
		return {success = false, message = "装备不存在"}

	var current_level = instance.get(Schema.K_ENHANCEMENT_LEVEL, 0)
	var config = ConfigLoader.get_balance_config().get("equipment_enhancement", {})
	var max_level = config.get("max_level", 15)

	if current_level >= max_level:
		return {success = false, message = "已达最大强化等级+%d" % max_level}

	var rarity = instance.get(Schema.K_RARITY, Schema.RARITY_COMMON)

	# 计算消耗（按稀有度，含 mythic 档；缺档兜底到 common）
	var costs_all = config.get("costs", {})
	var cost_table = costs_all.get(rarity, costs_all.get(Schema.RARITY_COMMON, {}))
	var gold_cost = (
		int(cost_table.get("gold_base", 50))
		+ int(cost_table.get("gold_per_level", 25) * current_level)
	)
	var material_cost = int(
		(
			cost_table.get("material_base", 1)
			+ cost_table.get("material_per_level", 0.5) * current_level
		)
	)

	# 检查资源（金币走持久钱包，材料统一用通用材料 rune_shard）
	if GameState.total_gold < gold_cost:
		return {success = false, message = "金币不足(需要%d)" % gold_cost}
	if GameState.get_material("rune_shard") < material_cost:
		return {success = false, message = "符文碎片不足(需要%d)" % material_cost}

	# 扣除资源
	GameState.total_gold -= gold_cost
	GameState.add_material("rune_shard", -material_cost)

	# 计算成功率（阶梯：1-5 必成，6-10 风险，11-15 高风险）
	var success_rates = config.get("success_rates", {})
	var success_rate = 1.0
	if current_level >= 10:
		success_rate = success_rates.get("11-15", 0.4)
	elif current_level >= 5:
		success_rate = success_rates.get("6-10", 0.7)
	else:
		success_rate = success_rates.get("1-5", 1.0)

	# P6: 神圣化保护——本次强化必成功，使用后立即清除标记
	var was_sanctified = _sanctified.get(instance_id, false)
	if was_sanctified:
		success_rate = 1.0
		_sanctified.erase(instance_id)

	var succeeded = randf() < success_rate

	if succeeded:
		instance[Schema.K_ENHANCEMENT_LEVEL] = current_level + 1
		EquipmentSystem.equipment_instances[instance_id] = instance
		# 通知玩家重算属性（强化加成立即生效）
		EquipmentSystem._notify_player()
		var msg = "强化成功！装备现在是+%d" % (current_level + 1)
		if was_sanctified:
			msg = "[神圣化保佑] " + msg
		return {
			success = true,
			new_level = current_level + 1,
			cost = {gold = gold_cost, material = material_cost},
			message = msg
		}
	return {
		success = false,
		new_level = current_level,
		cost = {gold = gold_cost, material = material_cost},
		message = "强化失败，装备保持+%d（材料已损失）" % current_level
	}


# ============================================================
# P6: 装备升品（common→rare→epic→legendary→mythic）
# ============================================================


## 是否有可用升品配方
func can_upgrade(instance_id: String) -> Dictionary:
	if not EquipmentSystem.equipment_instances.has(instance_id):
		return {"ok": false, "reason": "装备不存在"}
	var instance = EquipmentSystem.equipment_instances[instance_id]
	var rarity = instance.get(Schema.K_RARITY, Schema.RARITY_COMMON)
	var cfg = ConfigLoader.get_balance_config().get("equipment_upgrade", {})
	if not cfg.get("enabled", false):
		return {"ok": false, "reason": "升品系统未启用"}
	var tiers = cfg.get("tiers", {})
	var tier = tiers.get(rarity, {})
	if tier.is_empty():
		return {"ok": false, "reason": "已是最高品质"}
	return {"ok": true, "reason": "", "tier": tier, "rarity": rarity}


## 升品装备
## fodder_ids: 同稀有度同部位的"饲料"装备 instance_id 列表（数量必须等于配置 fodder_count_per_upgrade）
## 返回 {success, new_rarity, message}
func upgrade_equipment(instance_id: String, fodder_ids: Array) -> Dictionary:
	var check = can_upgrade(instance_id)
	if not check["ok"]:
		return {"success": false, "message": check["reason"]}

	var cfg = ConfigLoader.get_balance_config().get("equipment_upgrade", {})
	var tier = check["tier"]
	var instance = EquipmentSystem.equipment_instances[instance_id]
	var template_id = instance.get(Schema.K_TEMPLATE_ID, "")
	var template = ConfigLoader.get_equipment_by_id(template_id)
	var slot = template.get("slot", "")

	# 校验饲料数量
	var need_count = int(cfg.get("fodder_count_per_upgrade", 3))
	if fodder_ids.size() != need_count:
		return {"success": false, "message": "需要 %d 件饲料装备" % need_count}

	# 校验饲料：必须同稀有度，同部位（不一定同模板，但同 slot），且不是被升品的本体
	var fodder_rarity = tier.get("fodder_rarity", check["rarity"])
	var seen = {}
	for fid in fodder_ids:
		if fid == instance_id or seen.has(fid):
			return {"success": false, "message": "饲料不能是本体或重复"}
		seen[fid] = true
		if not EquipmentSystem.equipment_instances.has(fid):
			return {"success": false, "message": "饲料 %s 不存在" % fid}
		var f_inst = EquipmentSystem.equipment_instances[fid]
		if f_inst.get(Schema.K_RARITY, "") != fodder_rarity:
			return {"success": false, "message": "饲料稀有度不匹配（需 %s）" % fodder_rarity}
		var f_tpl = ConfigLoader.get_equipment_by_id(f_inst.get(Schema.K_TEMPLATE_ID, ""))
		if f_tpl.get("slot", "") != slot:
			return {"success": false, "message": "饲料部位不匹配（需 %s）" % slot}

	# 校验材料
	var gold_cost = int(tier.get("gold", 0))
	var rune_cost = int(tier.get("rune_shard", 0))
	var void_cost = int(tier.get("void_fragment", 0))
	if GameState.total_gold < gold_cost:
		return {"success": false, "message": "金币不足（需 %d）" % gold_cost}
	if GameState.get_material("rune_shard") < rune_cost:
		return {"success": false, "message": "符文碎片不足（需 %d）" % rune_cost}
	if void_cost > 0 and GameState.get_material("void_fragment") < void_cost:
		return {"success": false, "message": "虚空碎片不足（需 %d）" % void_cost}

	# 扣资源
	GameState.total_gold -= gold_cost
	GameState.add_material("rune_shard", -rune_cost)
	if void_cost > 0:
		GameState.add_material("void_fragment", -void_cost)

	# 销毁饲料：实例池清除 + 背包/仓库移除
	for fid in fodder_ids:
		if has_node("/root/Inventory"):
			Inventory.backpack.erase(fid)
			Inventory.warehouse.erase(fid)
		EquipmentSystem.equipment_instances.erase(fid)
	if has_node("/root/Inventory"):
		Inventory.backpack_changed.emit()
		Inventory.warehouse_changed.emit()

	# 升品本体：稀有度上调一档
	var new_rarity = tier.get("to", "rare")
	instance[Schema.K_RARITY] = new_rarity
	# 重新 roll 词缀（稀有度对应词缀数量），保留强化等级
	if cfg.get("reroll_affixes", true):
		var new_count = _affix_count_for_rarity(new_rarity)
		var new_affixes = []
		for i in new_count:
			var aid = _roll_random_affix(new_rarity)
			if aid != "":
				new_affixes.append({"affix_id": aid, "roll_value": randf_range(0.85, 1.0)})
		instance[Schema.K_ROLLED_AFFIXES] = new_affixes
	EquipmentSystem.equipment_instances[instance_id] = instance
	EquipmentSystem._recompute_sets()
	EquipmentSystem.equipment_changed.emit()
	EquipmentSystem._notify_player()
	var item_data = EquipmentSystem.get_equipment_instance_data(instance_id)
	upgrade_completed.emit(item_data)
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()
	print_verbose("[AffixWorkshop] 升品: %s -> %s" % [template_id, new_rarity])
	return {
		"success": true,
		"new_rarity": new_rarity,
		"message": "升品成功 -> %s" % Schema.rarity_display(new_rarity)
	}


func _affix_count_for_rarity(rarity: String) -> int:
	match rarity:
		"common":
			return 0
		"rare":
			return 1
		"epic":
			return 2
		"legendary":
			return 3
		"mythic":
			return 4
		_:
			return 0


# ============================================================
# P6: 神圣化（保证下一次强化必成功）
# ============================================================


func is_sanctified(instance_id: String) -> bool:
	return _sanctified.get(instance_id, false)


func sanctify_equipment(instance_id: String) -> Dictionary:
	if not EquipmentSystem.equipment_instances.has(instance_id):
		return {"success": false, "message": "装备不存在"}
	if _sanctified.get(instance_id, false):
		return {"success": false, "message": "已处于神圣化状态"}
	var instance = EquipmentSystem.equipment_instances[instance_id]
	var rarity = instance.get(Schema.K_RARITY, Schema.RARITY_COMMON)
	var cfg = ConfigLoader.get_balance_config().get("equipment_sanctify", {})
	if not cfg.get("enabled", false):
		return {"success": false, "message": "神圣化未启用"}
	var cost = cfg.get("cost_by_rarity", {}).get(rarity, {})
	if cost.is_empty():
		return {"success": false, "message": "未知稀有度"}
	# 校验
	var gold_cost = int(cost.get("gold", 0))
	var rune_cost = int(cost.get("rune_shard", 0))
	var void_cost = int(cost.get("void_fragment", 0))
	if GameState.total_gold < gold_cost:
		return {"success": false, "message": "金币不足（需 %d）" % gold_cost}
	if GameState.get_material("rune_shard") < rune_cost:
		return {"success": false, "message": "符文碎片不足（需 %d）" % rune_cost}
	if void_cost > 0 and GameState.get_material("void_fragment") < void_cost:
		return {"success": false, "message": "虚空碎片不足（需 %d）" % void_cost}
	# 扣资源
	GameState.total_gold -= gold_cost
	GameState.add_material("rune_shard", -rune_cost)
	if void_cost > 0:
		GameState.add_material("void_fragment", -void_cost)
	_sanctified[instance_id] = true
	sanctify_completed.emit(instance_id)
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()
	print_verbose("[AffixWorkshop] 神圣化: %s" % instance_id)
	return {"success": true, "message": "神圣化生效，下次强化必成"}
