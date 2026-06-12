extends Node
## 野外探索系统 - 事件点/副本传送门的生成 + 遭遇自动结算
##
## 设计：
## - 每次进野外，随机生成一批事件点（采集/矿脉/藏宝/遗迹/商人/怪窝）+ 若干副本传送门。
## - 布局是临时态（每次进野外重 roll），不持久化。
## - 遭遇战走"玩家战力 vs 怪窝威胁"自动结算，复用领地防御战的简单模型。
## - 奖励发放统一走 GameState（材料/金币/经验/天赋点）。

signal point_consumed(point_id: String)

# 本次野外会话的布局（Wilderness.gd 读取并实例化）
var current_layout: Array = []


## 生成一次野外布局：返回 [{kind, def, pos}...]（含 portal 与 event 两类）
## rng_seed 用于可复现（测试传固定值）；默认用时间派生。
func generate_layout(rng_seed: int = -1) -> Array:
	var rng = RandomNumberGenerator.new()
	if rng_seed >= 0:
		rng.seed = rng_seed
	else:
		rng.randomize()

	var cfg = ConfigLoader.get_wilderness_config()
	var gen = cfg.get("generation", {})
	var w = float(gen.get("map_width_px", 1760))
	var h = float(gen.get("map_height_px", 900))
	var spacing = float(gen.get("min_spacing_px", 180))

	var placed_positions: Array = []
	var layout: Array = []

	# 1. 副本传送门（按已解锁副本的 region 取，散布在野外）
	var portal_count = int(gen.get("portal_count", 3))
	var portals = _pick_portals(portal_count, rng)
	for p in portals:
		var pos = _find_spot(w, h, spacing, placed_positions, rng)
		placed_positions.append(pos)
		layout.append({"category": "portal", "dungeon": p, "pos": pos})

	# 2. 事件点（按权重 roll）
	var n_min = int(gen.get("event_points_min", 5))
	var n_max = int(gen.get("event_points_max", 8))
	var n = rng.randi_range(n_min, n_max)
	var event_types = cfg.get("event_types", [])
	for i in n:
		var def = _weighted_pick(event_types, rng)
		if def.is_empty():
			continue
		var pos = _find_spot(w, h, spacing, placed_positions, rng)
		placed_positions.append(pos)
		layout.append({"category": "event", "def": def, "pos": pos, "point_id": "wild_%d" % i})

	current_layout = layout
	return layout


## 已解锁副本里挑 region 多样的若干个作为传送门目标
func _pick_portals(count: int, rng: RandomNumberGenerator) -> Array:
	var all_dungeons = ConfigLoader.get_all_dungeons()
	var unlocked_ids = []
	if has_node("/root/GameState"):
		unlocked_ids = get_node("/root/GameState").unlocked_dungeons
	var pool = []
	for dg in all_dungeons:
		if dg.get("id", "") in unlocked_ids:
			pool.append(dg)
	# 没有已解锁记录时，至少放第一个副本，避免野外没有入口
	if pool.is_empty() and not all_dungeons.is_empty():
		pool.append(all_dungeons[0])
	# 洗牌取前 count 个
	_shuffle(pool, rng)
	return pool.slice(0, min(count, pool.size()))


## 按 weight 加权随机挑一个事件类型
func _weighted_pick(types: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total = 0
	for t in types:
		total += int(t.get("weight", 1))
	if total <= 0:
		return {}
	var roll = rng.randi_range(0, total - 1)
	var acc = 0
	for t in types:
		acc += int(t.get("weight", 1))
		if roll < acc:
			return t
	return {}


## 找一个与已放置点间距足够的随机位置（失败则放宽）
func _find_spot(
	w: float, h: float, spacing: float, placed: Array, rng: RandomNumberGenerator
) -> Vector2:
	for _attempt in 20:
		var pos = Vector2(rng.randf_range(120, w - 120), rng.randf_range(120, h - 120))
		var ok = true
		for q in placed:
			if pos.distance_to(q) < spacing:
				ok = false
				break
		if ok:
			return pos
	# 放宽：直接返回随机点
	return Vector2(rng.randf_range(120, w - 120), rng.randf_range(120, h - 120))


func _shuffle(arr: Array, rng: RandomNumberGenerator) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


## ============ 事件点结算 ============
## 采集/藏宝/遗迹类：发奖励，返回可读结果文本数组
func resolve_gather(def: Dictionary) -> Array:
	var lines = []
	var reward = def.get("reward", {})
	for key in reward:
		var rng_pair = reward[key]
		var amount = _roll_pair(rng_pair)
		_grant(key, amount)
		lines.append("%s +%d" % [_reward_name(key), amount])

	# 藏宝箱概率掉装备
	var eq_chance = float(def.get("equipment_drop_chance", 0.0))
	if eq_chance > 0.0 and randf() < eq_chance:
		_drop_equipment()
		lines.append("发现一件装备！")

	# 遗迹概率给天赋点
	var tp_chance = float(def.get("talent_point_chance", 0.0))
	if tp_chance > 0.0 and randf() < tp_chance:
		if has_node("/root/GameState"):
			var gs = get_node("/root/GameState")
			gs.talent_points_unspent += 1
			gs.talent_changed.emit()
		lines.append("顿悟！天赋点 +1")

	return lines


## 怪窝遭遇：战力 vs 威胁自动结算。返回 {win, lines}
func resolve_encounter(def: Dictionary) -> Dictionary:
	var cfg = ConfigLoader.get_wilderness_config()
	var enc = cfg.get("encounter", {})
	var threat_base = float(enc.get("threat_base", 60))
	var threat_per_level = float(enc.get("threat_per_level", 14))

	var level = 1
	if has_node("/root/RosterSystem"):
		level = get_node("/root/RosterSystem").get_active_character().get("level", 1)
	var threat = threat_base + threat_per_level * (level - 1)
	var power = _player_power()

	var win = power >= threat
	var lines = []
	if win:
		lines.append("[color=lime]击退了怪物！[/color]")
		var reward = def.get("win_reward", {})
		for key in reward:
			var amount = _roll_pair(reward[key])
			_grant(key, amount)
			lines.append("%s +%d" % [_reward_name(key), amount])
		var eq_chance = float(def.get("win_equipment_drop_chance", 0.0))
		if eq_chance > 0.0 and randf() < eq_chance:
			_drop_equipment()
			lines.append("掉落一件装备！")
	else:
		lines.append("[color=red]不敌怪物，负伤撤退[/color]")
		# 失败惩罚：玩家当前 HP 损失（不致死，仅用于提示；战斗 Player 不在此场景）
		lines.append("损失了部分体力")
	return {"win": win, "lines": lines}


## 玩家战力估算（与 wilderness.json 的 player_power_formula 概念一致）
func _player_power() -> float:
	var player = get_tree().get_first_node_in_group("player")
	if player == null:
		# 野外场景没有战斗 Player，用当前角色快照估算
		if has_node("/root/EquipmentSystem"):
			var stats = get_node("/root/EquipmentSystem").get_total_stats({})
			return (
				float(stats.get("damage", 10)) * 2.0
				+ float(stats.get("max_hp", 100)) * 0.3
				+ float(stats.get("armor", 0)) * 1.5
			)
		return 100.0
	return player.damage * 2.0 + player.max_hp * 0.3 + player.armor * 1.5


# ============ 工具 ============
func _roll_pair(pair) -> int:
	if pair is Array and pair.size() == 2:
		return randi_range(int(pair[0]), int(pair[1]))
	return int(pair)


func _grant(key: String, amount: int) -> void:
	if not has_node("/root/GameState"):
		return
	var gs = get_node("/root/GameState")
	if key == "gold":
		gs.total_gold += amount
	elif key == "exp":
		# 经验直接加到当前 Player（野外无 Player，批次结算在回主城后自动同步）
		# 改为：通过 RosterSystem 找当前角色，直接加 exp 字段
		if has_node("/root/RosterSystem"):
			var roster = get_node("/root/RosterSystem")
			var ch = roster.get_active_character()
			if not ch.is_empty():
				ch["exp"] = ch.get("exp", 0.0) + float(amount)
	else:
		gs.add_material(key, amount)


func _drop_equipment() -> void:
	if not has_node("/root/EquipmentSystem"):
		return
	var es = get_node("/root/EquipmentSystem")
	# 野外场景无掉落拾取，直接 roll 一件装备进背包
	var all_eq = ConfigLoader.get_all_equipment()
	if all_eq.is_empty():
		return
	var template = all_eq[randi() % all_eq.size()]
	var template_id = template.get("id", "")
	var rarity = template.get("rarity", "common")
	# roll_equipment 生成实例，返回 UUID
	var instance_id = es.roll_equipment(template_id, rarity)
	if instance_id == "":
		return
	# 加进背包
	if has_node("/root/Inventory"):
		get_node("/root/Inventory").add_to_backpack(instance_id)


func _reward_name(key: String) -> String:
	match key:
		"gold":
			return "金币"
		"exp":
			return "经验"
		_:
			for m in ConfigLoader.get_basic_materials():
				if m.get("id", "") == key:
					return m.get("display_name", key)
			return key
