extends Node
## GameState - 跨场景的全局游戏状态
## 存储：选中的职业、选中的副本、局外永久数据

# 当前选中的职业 id（主菜单选择 → 传给游戏场景）
var selected_class_id: String = "class_warrior"

# 当前选中的副本和难度
var selected_dungeon_id: String = "dungeon_crypt_1"
var selected_difficulty_tier: int = 1
var selected_waveset: String = "waveset_crypt_1"
var selected_hp_mult: float = 1.0
var selected_dmg_mult: float = 1.0
var selected_drop_bonus: float = 0.0
var selected_set_drop: String = ""
var selected_slot_weights: Dictionary = {}

# 局外永久数据（金币、强化等级、已解锁内容）
var total_gold: int = 0
var meta_upgrades: Dictionary = {}  # {"perm_hp": 3, "perm_damage": 5, ...}
var unlocked_dungeons: Array = ["dungeon_crypt_1"]
# cleared_dungeons: 记录每个副本的通关进度（支持多难度）
# 格式: {
#   "dungeon_crypt_1": {
#     "max_tier_cleared": 2,
#     "first_clear_time": "2026-06-08T12:34:56",
#     "total_clears": 5
#   }
# }
var cleared_dungeons: Dictionary = {}

# 材料系统(区域专属材料用于改造)
var materials: Dictionary = {}

# 新手教学是否已完成（持久，避免每次进城重弹）
var tutorial_completed: bool = false

# ============ P6 巅峰系统（账号级持久状态，跨角色共享）============
# 巅峰等级（>=1 表示已解锁，0 表示未达 unlock_at_level）
var paragon_level: int = 0
# 巅峰经验池（超过 unlock_at_level 的所有溢出经验汇总到此）
var paragon_exp: float = 0.0
# 巅峰点未分配
var paragon_points_unspent: int = 0
# 巅峰加点 {paragon_id: allocated_points}
var paragon_allocations: Dictionary = {}

# ============ P6 天赋星图（跨职业大被动网，账号共享）============
# 已解锁天赋节点 {talent_id: 1}（这里值固定为 1，预留升级到 N 级的路径）
var unlocked_talents: Dictionary = {}
# 天赋点未分配（每巅峰级给 talent_points_per_paragon）
var talent_points_unspent: int = 0

signal paragon_changed
signal talent_changed


func _ready():
	print("[GameState] 全局状态初始化")


## 获取当前职业配置
func get_current_class() -> Dictionary:
	return ConfigLoader.get_class_by_id(selected_class_id)


## 设置职业
func set_class(class_id: String):
	selected_class_id = class_id
	print("[GameState] 选择职业: %s" % class_id)


## 进入副本：设置副本、波次、难度（Town 选择副本时调用）
func enter_dungeon(dungeon_id: String, tier: int = 1):
	selected_dungeon_id = dungeon_id
	var dungeon = ConfigLoader.get_dungeon_by_id(dungeon_id)
	if dungeon.is_empty():
		push_warning("[GameState] 未找到副本: %s" % dungeon_id)
		return
	selected_waveset = dungeon.get("wave_set", "waveset_crypt_1")
	selected_set_drop = dungeon.get("set_drop", "")
	selected_slot_weights = dungeon.get("slot_weights", {})
	# 应用难度
	var tiers = dungeon.get("difficulty_tiers", [])
	for t in tiers:
		if t.get("tier", 1) == tier:
			selected_difficulty_tier = tier
			selected_hp_mult = t.get("enemy_hp_mult", 1.0)
			selected_dmg_mult = t.get("enemy_dmg_mult", 1.0)
			selected_drop_bonus = t.get("drop_bonus", 0.0)
			break
	# P7: 叠加地图词缀（active_modifiers 是临时态，由 EndgameSystem 管理）
	if has_node("/root/EndgameSystem"):
		var eff = get_node("/root/EndgameSystem").aggregate_active_effects()
		selected_hp_mult *= (1.0 + float(eff.get("enemy_hp_mult", 0.0)))
		selected_dmg_mult *= (1.0 + float(eff.get("enemy_dmg_mult", 0.0)))
		selected_drop_bonus += float(eff.get("drop_bonus", 0.0))
	print(
		(
			"[GameState] 进入副本: %s (波次=%s, tier=%d, hp×%.2f, dmg×%.2f, drop+%.2f)"
			% [
				dungeon_id,
				selected_waveset,
				tier,
				selected_hp_mult,
				selected_dmg_mult,
				selected_drop_bonus
			]
		)
	)


## 局外强化加成查询（每级的总加成）
func get_meta_bonus(upgrade_id: String) -> float:
	var level = meta_upgrades.get(upgrade_id, 0)
	if level == 0:
		return 0.0
	# 从 balance.json 读取每级数值
	var meta = ConfigLoader.balance_data.get("meta_progression", {})
	for stat in meta.get("stats", []):
		if stat.get("id", "") == upgrade_id:
			return stat.get("per_level", 0) * level
	return 0.0


## 查询副本最高通关难度（返回 0 表示未通关）
func get_max_cleared_tier(dungeon_id: String) -> int:
	if not cleared_dungeons.has(dungeon_id):
		return 0
	return cleared_dungeons[dungeon_id].get("max_tier_cleared", 0)


## 查询副本是否通关过指定难度
func is_dungeon_cleared(dungeon_id: String, tier: int = 1) -> bool:
	return get_max_cleared_tier(dungeon_id) >= tier


## 材料系统 - 添加/扣除材料
func add_material(material_id: String, amount: int):
	var current = materials.get(material_id, 0)
	materials[material_id] = max(0, current + amount)
	print("[GameState] 材料变动: %s %+d -> %d" % [material_id, amount, materials[material_id]])


## 材料系统 - 获取材料数量
func get_material(material_id: String) -> int:
	return materials.get(material_id, 0)


## ============ P6 巅峰系统 ============
## 60 级满后调用：把 player 溢出的经验喂进巅峰池，按曲线给巅峰级
## 返回新增巅峰级数（用于 UI 飘字）
func gain_paragon_exp(amount: float) -> int:
	if amount <= 0:
		return 0
	var cfg = ConfigLoader.get_balance_config().get("paragon_system", {})
	if not cfg.get("enabled", false):
		return 0
	var max_p = int(cfg.get("max_paragon_level", 200))
	if paragon_level >= max_p:
		return 0
	paragon_exp += amount
	var gained = 0
	while paragon_level < max_p:
		var need = paragon_exp_to_next()
		if paragon_exp < need:
			break
		paragon_exp -= need
		paragon_level += 1
		paragon_points_unspent += 1
		# 同步给天赋点（每巅峰级给 N 个天赋点）
		var grid = ConfigLoader.get_balance_config().get("talent_grid", {})
		talent_points_unspent += int(grid.get("talent_points_per_paragon", 1))
		gained += 1
	if gained > 0:
		paragon_changed.emit()
		talent_changed.emit()
		if has_node("/root/SaveSystem"):
			SaveSystem.mark_dirty()
		print("[GameState] 巅峰升级 +%d -> Lv.%d (天赋点 +%d)" % [gained, paragon_level, gained])
	return gained


## 当前巅峰级所需经验（指数曲线）
func paragon_exp_to_next() -> float:
	var cfg = ConfigLoader.get_balance_config().get("paragon_system", {})
	var base = float(cfg.get("exp_per_paragon_level_base", 5000))
	var growth = float(cfg.get("exp_growth_per_paragon", 1.05))
	return base * pow(growth, paragon_level)


## 分配一个巅峰点到某条路径，返回 {ok, reason}
func allocate_paragon(paragon_id: String, points: int = 1) -> Dictionary:
	if points <= 0:
		return {"ok": false, "reason": "无效点数"}
	if paragon_points_unspent < points:
		return {"ok": false, "reason": "巅峰点不足"}
	var def = _get_paragon_def(paragon_id)
	if def.is_empty():
		return {"ok": false, "reason": "未知巅峰条目"}
	var current = int(paragon_allocations.get(paragon_id, 0))
	var max_alloc = int(def.get("max_alloc", 100))
	if current + points > max_alloc:
		return {"ok": false, "reason": "已达单条上限"}
	paragon_allocations[paragon_id] = current + points
	paragon_points_unspent -= points
	paragon_changed.emit()
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()
	# 巅峰加成立即生效：通知玩家重算
	_notify_player_recalc()
	return {"ok": true, "reason": ""}


## 获取某条巅峰路径的当前总加成（per_level × allocated）
func get_paragon_bonus(kind: String) -> float:
	var total = 0.0
	for pid in paragon_allocations:
		var def = _get_paragon_def(pid)
		if def.get("kind", "") == kind:
			total += float(def.get("per_level", 0.0)) * int(paragon_allocations[pid])
	return total


func _get_paragon_def(paragon_id: String) -> Dictionary:
	var cfg = ConfigLoader.get_balance_config().get("paragon_system", {})
	for p in cfg.get("paragon_stats", []):
		if p.get("id", "") == paragon_id:
			return p
	return {}


## ============ P6 天赋星图 ============
func has_talent(talent_id: String) -> bool:
	return unlocked_talents.get(talent_id, 0) > 0


## 解锁一个天赋节点。返回 {ok, reason}
func unlock_talent(talent_id: String) -> Dictionary:
	if has_talent(talent_id):
		return {"ok": false, "reason": "已解锁"}
	if talent_points_unspent <= 0:
		return {"ok": false, "reason": "天赋点不足"}
	# 获取节点定义
	var def = (
		ConfigLoader.get_talent_def(talent_id) if ConfigLoader.has_method("get_talent_def") else {}
	)
	if def.is_empty():
		return {"ok": false, "reason": "未知天赋节点"}
	# 职业根节点：要求当前操控角色与之匹配
	if def.get("is_class_root", false):
		var grid = ConfigLoader.get_balance_config().get("talent_grid", {})
		var roots = grid.get("starter_node_per_class", {})
		var class_id = selected_class_id
		if has_node("/root/RosterSystem"):
			var active = get_node("/root/RosterSystem").get_active_character()
			if not active.is_empty():
				class_id = active.get("class_id", class_id)
		if roots.get(class_id, "") != talent_id:
			return {"ok": false, "reason": "非本职业起始天赋"}
	# 前置（all 或 any 模式由 ConfigLoader.can_unlock_talent 判定）
	var ck = ConfigLoader.can_unlock_talent(talent_id, unlocked_talents)
	if not ck["ok"]:
		return ck
	unlocked_talents[talent_id] = 1
	talent_points_unspent -= 1
	talent_changed.emit()
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()
	_notify_player_recalc()
	print("[GameState] 解锁天赋: %s" % talent_id)
	return {"ok": true, "reason": ""}


## 重置巅峰加点（所有点回收，分配清空，节点不退）
func reset_paragon_allocations():
	var total = 0
	for pid in paragon_allocations:
		total += int(paragon_allocations[pid])
	paragon_allocations.clear()
	paragon_points_unspent += total
	paragon_changed.emit()
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()
	_notify_player_recalc()


## 重置天赋（节点全部退回，按解锁数还原天赋点）
func reset_talents():
	var refunded = unlocked_talents.size()
	unlocked_talents.clear()
	talent_points_unspent += refunded
	talent_changed.emit()
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()
	_notify_player_recalc()


## 让 Player 重算属性（巅峰/天赋变化时）
func _notify_player_recalc():
	var tree = Engine.get_main_loop()
	if tree and tree.has_method("get_first_node_in_group"):
		var p = tree.get_first_node_in_group("player")
		if p and p.has_method("recalculate_stats"):
			p.recalculate_stats()
