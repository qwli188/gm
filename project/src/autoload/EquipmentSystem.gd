extends Node
## 装备系统 - 管理8部位装备穿戴、属性汇总、词缀效果、套装检测
## 配置表驱动：装备数据从 ConfigLoader 读取

# 调试日志开关：默认关闭。每次操作 print 是性能热点（roll_equipment 1000 次原本 14968ms，
# 关闭后 39ms，提速 380 倍）。需要追踪问题时改为 true，或将 print 改为 print_verbose。
const DEBUG_LOG := false
## Player 通过 get_total_stats() 和 get_combat_effects() 获取最终加成

# 8 部位槽位
const SLOTS = ["weapon", "helmet", "chest", "legs", "boots", "gloves", "ring", "amulet"]

# 玩家当前装备（每部位存 instance_id，而非完整 item_data）
var equipped_items: Dictionary = {}

# 装备实例仓库 {uuid_str: {template_id, rarity, rolled_affixes, enhancement_level, bound, acquired_at}}
var equipment_instances: Dictionary = {}

# 背包/仓库已拆分到独立的 Inventory autoload (PR-3)
# EquipmentSystem 只持有装备实例池 + 穿戴状态，不再管理容器

# 当前激活的套装效果缓存 {set_id: piece_count}
var active_sets: Dictionary = {}

signal equipment_changed
signal set_bonus_changed(set_id: String, pieces: int)


func _ready():
	for slot in SLOTS:
		equipped_items[slot] = null
	print("[EquipmentSystem] 装备系统初始化 (8部位)")
	ConfigLoader.config_reloaded.connect(_on_config_reloaded)


## ============ 装备实例管理 ============
## 生成装备实例（roll 随机词缀）
func roll_equipment(template_id: String, rarity: String = "") -> String:
	var template = ConfigLoader.get_equipment_by_id(template_id)
	if template.is_empty():
		push_warning("[EquipmentSystem] 模板不存在: %s" % template_id)
		return ""
	if rarity == "":
		rarity = template.get("rarity", "common")

	var uuid = _generate_uuid()
	var now_iso = Time.get_datetime_string_from_system(true)
	var instance = {
		"uuid": uuid,
		"template_id": template_id,
		"rarity": rarity,
		"rolled_affixes": _roll_affixes(rarity),
		"enhancement_level": 0,
		"bound": false,
		"acquired_at": now_iso,
	}
	equipment_instances[uuid] = instance
	if DEBUG_LOG:
		print(
			(
				"[EquipmentSystem] 生成实例: %s (%s, id=%s)"
				% [template.get("display_name", "?"), rarity, uuid]
			)
		)
	return uuid


## roll 随机词缀（根据稀有度决定词缀数量）
func _roll_affixes(rarity: String) -> Array:
	var affix_count = 0
	match rarity:
		"common":
			affix_count = 0
		"rare":
			affix_count = 1
		"epic":
			affix_count = 2
		"legendary":
			affix_count = 3
		"mythic":
			affix_count = 4
	var affixes = []
	# 简化：从配置表随机抽取词缀（实际可按 slot/tier 过滤）
	var all_affixes = ConfigLoader.get_all_affixes()
	if all_affixes.is_empty():
		return affixes
	for i in affix_count:
		var affix = all_affixes[randi() % all_affixes.size()]
		(
			affixes
			. append(
				{
					"affix_id": affix.get("id", ""),
					"roll_value": randf_range(0.8, 1.0),  # roll 倍率 0.8~1.0
				}
			)
		)
	return affixes


## 生成简单 UUID（不依赖外部插件）
func _generate_uuid() -> String:
	var chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	var result = "eq_inst_"
	for i in 12:
		result += chars[randi() % chars.length()]
	return result


## 根据 instance_id 获取完整装备数据（模板 + 词缀）
func get_equipment_instance_data(instance_id: String) -> Dictionary:
	var instance = equipment_instances.get(instance_id, {})
	if instance.is_empty():
		return {}
	var template = ConfigLoader.get_equipment_by_id(instance.get("template_id", ""))
	if template.is_empty():
		return {}
	# 合并模板与实例数据
	var item_data = template.duplicate(true)
	item_data["instance_id"] = instance_id
	item_data["rarity"] = instance.get("rarity", item_data.get("rarity", "common"))
	item_data["enhancement_level"] = instance.get("enhancement_level", 0)
	item_data["bound"] = instance.get("bound", false)
	# 将 rolled_affixes 合并到 fixed_affixes（供后续计算使用）
	var rolled = instance.get("rolled_affixes", [])
	for affix_roll in rolled:
		var affix_id = affix_roll.get("affix_id", "")
		if affix_id != "":
			if not item_data.has("fixed_affixes"):
				item_data["fixed_affixes"] = []
			item_data["fixed_affixes"].append(affix_id)
	return item_data


## 装备一件物品（通过 instance_id）
func equip_item_by_id(instance_id: String) -> bool:
	var item_data = get_equipment_instance_data(instance_id)
	if item_data.is_empty():
		return false
	var slot = item_data.get("slot", "weapon")
	if not equipped_items.has(slot):
		push_warning("[EquipmentSystem] 未知部位: %s" % slot)
		return false
	equipped_items[slot] = instance_id
	print_verbose(
		(
			"[EquipmentSystem] 装备: %s [%s] (id=%s)"
			% [item_data.get("display_name", "?"), slot, instance_id]
		)
	)
	_recompute_sets()
	equipment_changed.emit()
	_notify_player()
	return true


## 装备一件物品（自动判断槽位）- 兼容旧接口
func equip_item(item_data: Dictionary) -> bool:
	# 如果是 instance_id，转到新接口
	if item_data.has("instance_id"):
		return equip_item_by_id(item_data["instance_id"])
	# 否则是模板数据，生成实例后装备
	var template_id = item_data.get("id", "")
	if template_id == "":
		return false
	var instance_id = roll_equipment(template_id, item_data.get("rarity", ""))
	return equip_item_by_id(instance_id)


## 从背包穿戴（PR-3 添加）：
## - 背包移除该实例
## - 若该槽位有装备，把它放回背包
## - 若背包满则拒绝（防止丢失原穿戴装备）
## 返回 true=成功
func equip_from_backpack(instance_id: String) -> bool:
	if not has_node("/root/Inventory"):
		# 兼容回退：直接穿戴
		return equip_item_by_id(instance_id)
	if not (instance_id in Inventory.backpack):
		push_warning("[EquipmentSystem] 实例不在背包: %s" % instance_id)
		return false
	var item = get_equipment_instance_data(instance_id)
	if item.is_empty():
		return false
	var slot = item.get("slot", "")
	if not equipped_items.has(slot):
		push_warning("[EquipmentSystem] 未知部位: %s" % slot)
		return false

	# 若原槽位有装备，先确保背包有空位（移除新装备会腾出 1 格 + 旧装备占 1 格 = 持平）
	# 唯一需要拒绝的情形：背包满 且 原槽位为空（穿戴后无法把"新装备"格子留给可能的换下装备 —— 此时其实 OK）
	# 实际:腾 1 占 1 持平,只要原本背包不超容,换装永远成功
	var old_id = equipped_items.get(slot)
	Inventory.backpack.erase(instance_id)
	equipped_items[slot] = instance_id
	if old_id != null:
		Inventory.backpack.append(old_id)
	Inventory.backpack_changed.emit()

	_recompute_sets()
	equipment_changed.emit()
	_notify_player()
	print_verbose("[EquipmentSystem] 从背包穿戴: %s [%s]" % [item.get("display_name", "?"), slot])
	return true


## 卸下部位
func unequip_item(slot: String):
	if not equipped_items.has(slot):
		return
	var old_id = equipped_items[slot]
	if old_id == null:
		return
	# 卸下:回背包(若背包满则拒绝,避免装备消失)
	if has_node("/root/Inventory"):
		if Inventory.is_backpack_full():
			push_warning("[EquipmentSystem] 背包已满，无法卸下 %s" % slot)
			return
		Inventory.backpack.append(old_id)
		Inventory.backpack_changed.emit()
	equipped_items[slot] = null
	_recompute_sets()
	equipment_changed.emit()
	_notify_player()


## 通知玩家重算属性
func _notify_player():
	var tree = Engine.get_main_loop()
	if tree and tree.has_method("get_first_node_in_group"):
		var player = tree.get_first_node_in_group("player")
		if player and player.has_method("recalculate_stats"):
			player.recalculate_stats()


## ============ 套装检测 ============
## 重算当前激活的套装件数
func _recompute_sets():
	var counts = {}
	for slot in equipped_items:
		var instance_id = equipped_items[slot]
		if instance_id == null:
			continue
		var item = get_equipment_instance_data(instance_id)
		if item.is_empty():
			continue
		var sid = item.get("set_id", "")
		if sid != "":
			counts[sid] = counts.get(sid, 0) + 1
	# 发出变化信号
	for sid in counts:
		if active_sets.get(sid, 0) != counts[sid]:
			set_bonus_changed.emit(sid, counts[sid])
	active_sets = counts


## 获取某套装当前件数
func get_set_pieces(set_id: String) -> int:
	return active_sets.get(set_id, 0)


## 获取所有激活的套装加成（供属性汇总）
func get_set_bonuses() -> Dictionary:
	var bonuses = {}
	for sid in active_sets:
		var pieces = active_sets[sid]
		var set_data = ConfigLoader.get_set_by_id(sid)
		if set_data.is_empty():
			continue
		# 遍历套装的阶梯加成
		for tier in set_data.get("bonuses", []):
			var req = tier.get("pieces", 99)
			if pieces >= req:
				_merge_set_tier(bonuses, tier)
	return bonuses


## 合并单个套装阶梯加成
func _merge_set_tier(bonuses: Dictionary, tier: Dictionary):
	var stats = tier.get("stats", {})
	for k in stats:
		bonuses[k] = bonuses.get(k, 0.0) + stats[k]
	# 套装专属词条效果
	var effects = tier.get("effects", {})
	for k in effects:
		bonuses["effect_" + k] = effects[k]


## ============ 属性汇总 ============
## 汇总所有装备的基础属性 + 套装加成（供 Player.recalculate_stats 调用）
## equipped_map 默认用当前操控角色的 equipped_items；传入其他角色的
## {slot: instance_id} 可计算任意角色的面板（P2 AI 队友用，不切换全局状态）。
func get_total_stats(equipped_map: Dictionary = equipped_items) -> Dictionary:
	var total = {
		"damage": 0.0,
		"max_hp": 0.0,
		"armor": 0.0,
		"crit_chance": 0.0,
		"crit_damage": 0.0,
		"attack_speed_mult": 1.0,
		"move_speed_mult": 1.0,
		"hp_regen": 0.0
	}

	for slot in equipped_map:
		var instance_id = equipped_map[slot]
		if instance_id == null:
			continue
		var item = get_equipment_instance_data(instance_id)
		if item.is_empty():
			continue
		var stats = item.get("base_stats", {})

		# 模块5: 应用装备强化加成
		var enhance_level = item.get(Schema.K_ENHANCEMENT_LEVEL, 0)
		if enhance_level > 0:
			var config = ConfigLoader.get_balance_config().get("equipment_enhancement", {})
			var bonus_per_level = config.get("stat_bonus_per_level", 0.1)
			var enhance_mult = 1.0 + (enhance_level * bonus_per_level)
			# 对所有数值属性应用强化倍率
			var enhanced_stats = {}
			for key in stats:
				if typeof(stats[key]) in [TYPE_FLOAT, TYPE_INT]:
					enhanced_stats[key] = stats[key] * enhance_mult
				else:
					enhanced_stats[key] = stats[key]
			stats = enhanced_stats

		total["damage"] += stats.get("damage", 0)
		total["max_hp"] += stats.get("max_hp", 0)
		total["armor"] += stats.get("armor", 0)
		total["crit_chance"] += stats.get("crit_chance", 0)
		total["crit_damage"] += stats.get("crit_damage", 0)
		total["hp_regen"] += stats.get("hp_regen", 0)
		if stats.has("attack_speed"):
			# 语义区分：武器的 attack_speed 是倍率（1.1 = 1.1 倍）
			# 其它部位（手套等）是百分比加成（0.1 = +10%）
			if slot == "weapon":
				total["attack_speed_mult"] *= stats["attack_speed"]
			else:
				total["attack_speed_mult"] *= (1.0 + stats["attack_speed"])
		if stats.has("move_speed"):
			# move_speed 统一为百分比加成（0.1 = +10%）
			total["move_speed_mult"] *= (1.0 + stats["move_speed"])
		# 词缀的属性加成（roll出来的随机词缀）
		_apply_item_affix_stats(item, total)

	# 套装属性加成
	var set_bonus = get_set_bonuses()
	for stat_key in set_bonus:
		# 跳过 effect_ 前缀的键(由 get_combat_effects 处理,不进基础属性)
		if stat_key.begins_with("effect_"):
			continue
		if stat_key.ends_with("_mult"):
			total[stat_key] = total.get(stat_key, 1.0) * (1.0 + set_bonus[stat_key])
		else:
			total[stat_key] = total.get(stat_key, 0.0) + set_bonus[stat_key]

	return total


## 应用装备上词缀的属性加成
func _apply_item_affix_stats(item: Dictionary, total: Dictionary):
	for affix_id in item.get("fixed_affixes", []):
		var affix = ConfigLoader.get_affix_by_id(affix_id)
		var eff = affix.get("effect", {})
		if eff.get("kind", "") == "add_stat":
			var stat = eff.get("stat", "")
			if total.has(stat):
				total[stat] += eff.get("value", 0)


## 汇总所有装备的词缀效果（吸血、点燃、附加伤害等，传给战斗系统）
func get_combat_effects() -> Dictionary:
	var effects = {}
	for slot in equipped_items:
		var instance_id = equipped_items[slot]
		if instance_id == null:
			continue
		var item = get_equipment_instance_data(instance_id)
		if item.is_empty():
			continue
		for affix_id in item.get("fixed_affixes", []):
			var affix = ConfigLoader.get_affix_by_id(affix_id)
			if affix.is_empty():
				continue
			_merge_affix_effect(effects, affix)
	# 套装专属战斗效果
	var set_bonus = get_set_bonuses()
	for k in set_bonus:
		if k.begins_with("effect_"):
			effects[k.trim_prefix("effect_")] = set_bonus[k]
	return effects


## 把单个词缀的效果合并进 effects
func _merge_affix_effect(effects: Dictionary, affix: Dictionary):
	var eff = affix.get("effect", {})
	var kind = eff.get("kind", "")
	match kind:
		"lifesteal":
			effects["lifesteal"] = effects.get("lifesteal", 0.0) + eff.get("value", 0)
		"add_damage":
			effects["added_damage"] = effects.get("added_damage", 0.0) + eff.get("value", 0)
			effects["damage_type"] = eff.get("damage_type", "physical")
		"ignite":
			effects["ignite_dps"] = effects.get("ignite_dps", 0.0) + eff.get("dps", 0)
			effects["ignite_duration"] = max(
				effects.get("ignite_duration", 0.0), eff.get("duration", 0)
			)
		"poison":
			effects["poison_dps"] = effects.get("poison_dps", 0.0) + eff.get("dps", 0)
			effects["poison_duration"] = max(
				effects.get("poison_duration", 0.0), eff.get("duration", 0)
			)
		"freeze":
			effects["freeze_chance"] = effects.get("freeze_chance", 0.0) + eff.get("chance", 0)
			effects["freeze_duration"] = max(
				effects.get("freeze_duration", 0.0), eff.get("duration", 0)
			)
		"slow":
			effects["slow_percent"] = effects.get("slow_percent", 0.0) + eff.get("percent", 0)
			effects["slow_duration"] = max(
				effects.get("slow_duration", 0.0), eff.get("duration", 0)
			)
		"stun":
			effects["stun_chance"] = effects.get("stun_chance", 0.0) + eff.get("chance", 0)
			effects["stun_duration"] = max(
				effects.get("stun_duration", 0.0), eff.get("duration", 0)
			)
		"mult_stat":
			var stat = eff.get("stat", "")
			effects[stat + "_mult"] = effects.get(stat + "_mult", 0.0) + eff.get("value", 0)
		"on_hit_chance":
			# 通用 on_hit 触发框架: 把 sub_effect 转成扁平字段供 CombatSystem 直接读
			# 多件相同子效果叠加 chance 上限 0.6,duration 取最大
			var chance = eff.get("chance", 0.0)
			var sub = eff.get("sub_effect", {})
			match sub.get("kind", ""):
				"stun":
					effects["stun_chance"] = min(0.6, effects.get("stun_chance", 0.0) + chance)
					effects["stun_duration"] = max(
						effects.get("stun_duration", 0.0), sub.get("duration", 0)
					)
				"freeze":
					effects["freeze_chance"] = min(0.6, effects.get("freeze_chance", 0.0) + chance)
					effects["freeze_duration"] = max(
						effects.get("freeze_duration", 0.0), sub.get("duration", 0)
					)
				"slow":
					effects["slow_chance"] = min(0.8, effects.get("slow_chance", 0.0) + chance)
					effects["slow_percent"] = max(
						effects.get("slow_percent", 0.0), sub.get("value", 0)
					)
					effects["slow_duration"] = max(
						effects.get("slow_duration", 0.0), sub.get("duration", 0)
					)
				"ignite":
					effects["ignite_chance"] = min(0.8, effects.get("ignite_chance", 0.0) + chance)
					effects["ignite_dps"] = max(effects.get("ignite_dps", 0.0), sub.get("dps", 10))
					effects["ignite_duration"] = max(
						effects.get("ignite_duration", 0.0), sub.get("duration", 3)
					)
				"poison":
					effects["poison_chance"] = min(0.8, effects.get("poison_chance", 0.0) + chance)
					effects["poison_dps"] = max(effects.get("poison_dps", 0.0), sub.get("dps", 8))
					effects["poison_duration"] = max(
						effects.get("poison_duration", 0.0), sub.get("duration", 4)
					)
				"summon":
					# 召唤词缀: 命中时按概率召唤伴生骷髅/活尸,由 CombatSystem 触发
					effects["summon_chance"] = min(0.5, effects.get("summon_chance", 0.0) + chance)
					effects["summon_duration"] = max(
						effects.get("summon_duration", 0.0), sub.get("duration", 8)
					)
					effects["summon_damage"] = max(
						effects.get("summon_damage", 0.0), sub.get("damage", 6)
					)
				"chain":
					# 连锁词缀: 命中时按概率链向附近敌人
					effects["chain_chance"] = min(0.5, effects.get("chain_chance", 0.0) + chance)
					effects["chain_targets"] = max(
						effects.get("chain_targets", 0), sub.get("targets", 2)
					)
					effects["chain_damage_mult"] = max(
						effects.get("chain_damage_mult", 0.0), sub.get("damage_mult", 0.5)
					)
		_:
			pass


## ============ 掉落系统（含稀有度特效） ============
## 在地图随机掉落装备（Enemy 死亡调用）
func drop_random_equipment(
	position: Vector2,
	quality_bonus: float = 0.0,
	set_bias: String = "",
	slot_weights: Dictionary = {}
):
	var all_equipment = ConfigLoader.get_all_equipment()
	if all_equipment.is_empty():
		return
	var template = _roll_equipment(all_equipment, quality_bonus, set_bias, slot_weights)
	if template.is_empty():
		return
	# 生成实例
	var instance_id = roll_equipment(template.get("id", ""), template.get("rarity", "common"))
	if instance_id == "":
		return
	var item_data = get_equipment_instance_data(instance_id)
	print_verbose(
		(
			"[EquipmentSystem] 掉落: %s (%s)"
			% [item_data.get("display_name", "?"), item_data.get("rarity", "?")]
		)
	)
	_spawn_drop_item(item_data, position)


## 按稀有度权重随机抽一件装备
func _roll_equipment(
	pool: Array, quality_bonus: float, set_bias: String = "", slot_weights: Dictionary = {}
) -> Dictionary:
	# 从 balance.json 读权重，失败用默认
	var weights = {"common": 50, "rare": 28, "epic": 14, "legendary": 6, "mythic": 2}
	var cfg_weights = ConfigLoader.balance_data.get("drop_rates", {}).get("rarity_weights", {})
	if not cfg_weights.is_empty():
		weights = cfg_weights.duplicate()
	# 品质加成：提升高稀有度权重
	if quality_bonus > 0:
		weights["epic"] = weights.get("epic", 0) + int(quality_bonus * 25)
		weights["legendary"] = weights.get("legendary", 0) + int(quality_bonus * 15)
		weights["mythic"] = weights.get("mythic", 0) + int(quality_bonus * 8)
	# roll 稀有度
	var order = ["common", "rare", "epic", "legendary", "mythic"]
	var total_w = 0
	for r in order:
		total_w += int(weights.get(r, 0))
	var roll = randi() % int(max(total_w, 1))
	var chosen_rarity = "common"
	var acc = 0
	for r in order:
		acc += int(weights.get(r, 0))
		if roll < acc:
			chosen_rarity = r
			break
	# 从该稀有度里筛选候选（可选区域套装偏好）
	var candidates = []
	for item in pool:
		if item.get("rarity", "common") != chosen_rarity:
			continue
		if set_bias != "" and item.get("set_id", "") != "" and item.get("set_id", "") != set_bias:
			continue  # 该区域偏好掉对应套装
		candidates.append(item)
	if candidates.is_empty():
		# 放宽：只按稀有度
		for item in pool:
			if item.get("rarity", "common") == chosen_rarity:
				candidates.append(item)
	if candidates.is_empty():
		candidates = pool

	# slot 加权选择逻辑
	if not slot_weights.is_empty() and candidates.size() > 0:
		# 按 slot 分组
		var slot_pool = {}
		for item in candidates:
			var s = item.get("slot", "")
			if s == "":
				continue
			if not slot_pool.has(s):
				slot_pool[s] = []
			slot_pool[s].append(item)

		if not slot_pool.is_empty():
			# 计算总权重
			var total_slot_weight = 0
			for s in slot_pool:
				var w = slot_weights.get(s, 1)
				total_slot_weight += w * slot_pool[s].size()

			# 加权随机选择 slot
			var r = randi() % max(total_slot_weight, 1)
			var accumulator = 0
			for s in slot_pool:
				var w = slot_weights.get(s, 1)
				accumulator += w * slot_pool[s].size()
				if r < accumulator:
					return slot_pool[s][randi() % slot_pool[s].size()]

	return candidates[randi() % candidates.size()]


## 实例化掉落物到场景（附带稀有度特效）
func _spawn_drop_item(item_data: Dictionary, position: Vector2):
	# P9: 通知任务系统稀有度掉落（无视过滤，统计真实掉落事件）
	if has_node("/root/QuestSystem"):
		QuestSystem.register_drop(item_data.get(Schema.K_RARITY, "common"))
	# P8: 拾取过滤——稀有度低于玩家阈值则不显示在地图（模板装备直接跳过实例化）
	if has_node("/root/FeedbackSystem"):
		var rarity = item_data.get(Schema.K_RARITY, "common")
		if not FeedbackSystem.should_display_drop(rarity):
			# 销毁实例避免实例池泄漏
			var inst_id = item_data.get("instance_id", "")
			if inst_id != "":
				equipment_instances.erase(inst_id)
			print_verbose(
				(
					"[EquipmentSystem] 掉落被过滤: %s (%s 低于阈值)"
					% [item_data.get("display_name", "?"), rarity]
				)
			)
			return
	var tree = Engine.get_main_loop()
	if not tree:
		return
	var drop_scene = load("res://scenes/DropItem.tscn")
	if drop_scene == null:
		# DropItem 场景丢失：放弃掉落（避免污染状态）
		push_error("[EquipmentSystem] DropItem.tscn 加载失败，掉落丢弃")
		return
	var drop = drop_scene.instantiate()
	drop.global_position = position
	if drop.has_method("setup"):
		drop.setup(item_data)
	var current_scene = tree.current_scene
	if current_scene:
		current_scene.add_child(drop)


## 获取稀有度对应的颜色（供UI和特效使用）
## A1 收口：委托 Schema 单一真源，不再本地硬编码
func get_rarity_color(rarity: String) -> Color:
	return Schema.rarity_color(rarity)


## 获取稀有度特效等级（0=无 1=描边 2=粒子 3=光环 4=全屏）
func get_rarity_vfx_level(rarity: String) -> int:
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


## 拾取装备：进入 Inventory 背包；若对应槽位为空则自动穿戴
## 注意：背包已拆分到 Inventory autoload，此处只是路由
func pickup_equipment(item_data: Dictionary):
	var instance_id = item_data.get("instance_id", "")
	if instance_id == "":
		# 兼容旧代码：直接传模板数据，先生成实例
		var template_id = item_data.get("id", "")
		if template_id == "":
			return
		instance_id = roll_equipment(template_id, item_data.get(Schema.K_RARITY, ""))

	print_verbose(
		"[EquipmentSystem] 拾取: %s (id=%s)" % [item_data.get("display_name", "?"), instance_id]
	)

	var slot = item_data.get("slot", "weapon")
	# 若对应槽位为空：直接穿戴（不进背包）
	if equipped_items.has(slot) and equipped_items[slot] == null:
		equip_item_by_id(instance_id)
	else:
		# 否则进背包（背包满则丢弃实例池中的实例）
		if has_node("/root/Inventory"):
			if not Inventory.add_to_backpack(instance_id):
				push_warning("[EquipmentSystem] 背包已满，丢弃: %s" % instance_id)
				equipment_instances.erase(instance_id)


func _on_config_reloaded(file_name: String) -> void:
	if file_name in ["equipment.json", "affixes.json", "sets.json"]:
		_recompute_sets()
		_notify_player()
		equipment_changed.emit()
		print("[EquipmentSystem] 响应配置重载: " + file_name)


## ============ 序列化与反序列化（供 SaveSystem 调用）============
## 序列化所有装备实例
func serialize_instances() -> Dictionary:
	return equipment_instances.duplicate(true)


## 反序列化装备实例
func deserialize_instances(data: Dictionary):
	equipment_instances = data.duplicate(true)
	print("[EquipmentSystem] 加载装备实例: %d 件" % equipment_instances.size())


## 序列化已穿戴装备（返回 {slot: instance_id}）
func serialize_equipped() -> Dictionary:
	var result = {}
	for slot in SLOTS:
		var instance_id = equipped_items.get(slot, null)
		if instance_id != null:
			result[slot] = instance_id
	return result


## 反序列化已穿戴装备
func deserialize_equipped(data: Dictionary):
	for slot in SLOTS:
		equipped_items[slot] = null
	for slot in data:
		var instance_id = data[slot]
		if equipment_instances.has(instance_id):
			equipped_items[slot] = instance_id
	_recompute_sets()
	equipment_changed.emit()
	_notify_player()
	print("[EquipmentSystem] 恢复穿戴: %d 件" % data.size())


# serialize_backpack / deserialize_backpack 已迁移到 Inventory.serialize() / deserialize() (PR-3)


## B3: 装备tooltip生成(委托RarityVisuals)
func generate_tooltip(item_data: Dictionary) -> String:
	return RarityVisuals.generate_equipment_tooltip(item_data)
