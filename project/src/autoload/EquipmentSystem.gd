extends Node
## 装备系统 - 管理8部位装备穿戴、属性汇总、词缀效果、套装检测
## 配置表驱动：装备数据从 ConfigLoader 读取
## Player 通过 get_total_stats() 和 get_combat_effects() 获取最终加成

# 8 部位槽位
const SLOTS = ["weapon", "helmet", "chest", "legs", "boots", "gloves", "ring", "amulet"]

# 玩家当前装备（每部位一件，存完整 item_data）
var equipped_items: Dictionary = {}

# 装备仓库
var inventory: Array = []

# 当前激活的套装效果缓存 {set_id: piece_count}
var active_sets: Dictionary = {}

signal equipment_changed()
signal set_bonus_changed(set_id: String, pieces: int)

func _ready():
	for slot in SLOTS:
		equipped_items[slot] = null
	print("[EquipmentSystem] 装备系统初始化 (8部位)")

## 装备一件物品（自动判断槽位）
func equip_item(item_data: Dictionary) -> bool:
	if item_data.is_empty():
		return false
	var slot = item_data.get("slot", "weapon")
	if not equipped_items.has(slot):
		push_warning("[EquipmentSystem] 未知部位: %s" % slot)
		return false
	equipped_items[slot] = item_data
	print("[EquipmentSystem] 装备: %s [%s]" % [item_data.get("display_name", "?"), slot])
	_recompute_sets()
	equipment_changed.emit()
	_notify_player()
	return true

## 卸下部位
func unequip_item(slot: String):
	if equipped_items.has(slot):
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
		var item = equipped_items[slot]
		if item == null:
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
func get_total_stats() -> Dictionary:
	var total = {
		"damage": 0.0, "max_hp": 0.0, "armor": 0.0,
		"crit_chance": 0.0, "crit_damage": 0.0,
		"attack_speed_mult": 1.0, "move_speed_mult": 1.0, "hp_regen": 0.0
	}

	for slot in equipped_items:
		var item = equipped_items[slot]
		if item == null:
			continue
		var stats = item.get("base_stats", {})
		total["damage"] += stats.get("damage", 0)
		total["max_hp"] += stats.get("max_hp", 0)
		total["armor"] += stats.get("armor", 0)
		total["crit_chance"] += stats.get("crit_chance", 0)
		total["crit_damage"] += stats.get("crit_damage", 0)
		total["hp_regen"] += stats.get("hp_regen", 0)
		if stats.has("attack_speed"):
			total["attack_speed_mult"] *= stats["attack_speed"]
		if stats.has("move_speed"):
			total["move_speed_mult"] *= (1.0 + stats["move_speed"])
		# 词缀的属性加成（roll出来的随机词缀）
		_apply_item_affix_stats(item, total)

	# 套装属性加成
	var set_bonus = get_set_bonuses()
	total["damage"] += set_bonus.get("damage", 0)
	total["max_hp"] += set_bonus.get("max_hp", 0)
	total["armor"] += set_bonus.get("armor", 0)
	total["crit_chance"] += set_bonus.get("crit_chance", 0)
	total["crit_damage"] += set_bonus.get("crit_damage", 0)
	if set_bonus.has("attack_speed_mult"):
		total["attack_speed_mult"] *= (1.0 + set_bonus["attack_speed_mult"])
	if set_bonus.has("damage_mult"):
		total["damage"] *= (1.0 + set_bonus["damage_mult"])

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
		var item = equipped_items[slot]
		if item == null:
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
			effects["ignite_duration"] = max(effects.get("ignite_duration", 0.0), eff.get("duration", 0))
		"poison":
			effects["poison_dps"] = effects.get("poison_dps", 0.0) + eff.get("dps", 0)
			effects["poison_duration"] = max(effects.get("poison_duration", 0.0), eff.get("duration", 0))
		"on_hit_chance":
			var sub = eff.get("sub_effect", {})
			effects["on_hit_" + sub.get("kind", "")] = eff.get("chance", 0)
		"mult_stat":
			var stat = eff.get("stat", "")
			effects["mult_" + stat] = effects.get("mult_" + stat, 0.0) + eff.get("value", 0)
		_:
			pass

## ============ 掉落系统（含稀有度特效） ============
## 在地图随机掉落装备（Enemy 死亡调用）
func drop_random_equipment(position: Vector2, quality_bonus: float = 0.0, set_bias: String = ""):
	var all_equipment = ConfigLoader.get_all_equipment()
	if all_equipment.is_empty():
		return
	var item = _roll_equipment(all_equipment, quality_bonus, set_bias)
	if item.is_empty():
		return
	print("[EquipmentSystem] 掉落: %s (%s)" % [item.get("display_name", "?"), item.get("rarity", "?")])
	_spawn_drop_item(item, position)

## 按稀有度权重随机抽一件装备
func _roll_equipment(pool: Array, quality_bonus: float, set_bias: String = "") -> Dictionary:
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
	for r in order: total_w += int(weights.get(r, 0))
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
	return candidates[randi() % candidates.size()]

## 实例化掉落物到场景（附带稀有度特效）
func _spawn_drop_item(item_data: Dictionary, position: Vector2):
	var tree = Engine.get_main_loop()
	if not tree:
		return
	var drop_scene = load("res://scenes/DropItem.tscn")
	if drop_scene == null:
		inventory.append(item_data)
		return
	var drop = drop_scene.instantiate()
	drop.global_position = position
	if drop.has_method("setup"):
		drop.setup(item_data)
	var current_scene = tree.current_scene
	if current_scene:
		current_scene.add_child(drop)

## 获取稀有度对应的颜色（供UI和特效使用）
func get_rarity_color(rarity: String) -> Color:
	match rarity:
		"common": return Color("#C8C8C8")
		"rare": return Color("#4A90D9")
		"epic": return Color("#9B4DCA")
		"legendary": return Color("#E8A317")
		"mythic": return Color("#E03131")
		_: return Color.WHITE

## 获取稀有度特效等级（0=无 1=描边 2=粒子 3=光环 4=全屏）
func get_rarity_vfx_level(rarity: String) -> int:
	match rarity:
		"common": return 0
		"rare": return 1
		"epic": return 2
		"legendary": return 3
		"mythic": return 4
		_: return 0

## 拾取装备
func pickup_equipment(item_data: Dictionary):
	inventory.append(item_data)
	print("[EquipmentSystem] 拾取: %s" % item_data.get("display_name", "?"))
	var slot = item_data.get("slot", "weapon")
	if equipped_items.has(slot) and equipped_items[slot] == null:
		equip_item(item_data)
