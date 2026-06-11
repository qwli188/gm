extends Node
## TerritorySystem - 领地容器与建造/升级逻辑（账号共享，存档持久）
##
## 设计要点（见领地玩法大扩展 P1）：
## - 领地是账号级持久状态：等级 + 建筑列表 + 居民/驻军（居民在 P3 接入）。
## - 出击制：建筑产出在每次出击归来结算（settle_sortie，P3 接入 SimClock）。
## - 材料消耗走 GameState.materials + total_gold（账号共享）。
##
## 数据结构：
##   level: int                领地等级（1~max）
##   buildings: {id: level}     已建造建筑及其等级（townhall 默认 1 级）
##   garrison: [unit_id...]     驻军（P3）
##   residents: [unit_dict...]  居民（P3）

signal territory_changed()
signal building_changed(building_id: String)
signal territory_leveled_up(new_level: int)
signal residents_changed()

var level: int = 1
var buildings: Dictionary = {}      # {building_id: building_level}
var garrison: Array = []            # P4: 驻军单位 [{name, power}]
var residents: Array = []           # P3: 居民 [{name, job, assigned_building}]
var sortie_count: int = 0           # P4: 出击计数,触发防御战
var last_defense_result: String = "" # P4: 上次防御战结果 (victory/defeat/none)

func _ready():
	print("[TerritorySystem] 领地系统初始化")
	_ensure_townhall()

## ============ P3: 居民系统 ============
const RESIDENT_RECRUIT_COST_GOLD := 100
const RESIDENT_RECRUIT_COST_FOOD := 5

## 当前居民数量
func resident_count() -> int:
	return residents.size()

## 可招募居民数(受上限限制)
func can_recruit_resident() -> bool:
	return resident_count() < get_resident_cap()

## 招募居民。返回 {ok, reason, resident}
func recruit_resident() -> Dictionary:
	if not can_recruit_resident():
		return {"ok": false, "reason": "居民已达上限"}
	if GameState.total_gold < RESIDENT_RECRUIT_COST_GOLD:
		return {"ok": false, "reason": "金币不足"}
	if GameState.get_material("food") < RESIDENT_RECRUIT_COST_FOOD:
		return {"ok": false, "reason": "粮食不足"}
	GameState.total_gold -= RESIDENT_RECRUIT_COST_GOLD
	GameState.add_material("food", -RESIDENT_RECRUIT_COST_FOOD)
	var r = _make_resident()
	residents.append(r)
	_emit_dirty()
	residents_changed.emit()
	print("[TerritorySystem] 招募居民: %s" % r["name"])
	return {"ok": true, "reason": "", "resident": r}

func _make_resident() -> Dictionary:
	var names = ["艾莉", "布兰登", "凯瑟琳", "德里克", "艾玛", "菲利克斯",
		"格蕾丝", "哈罗德", "艾薇", "杰克", "凯特", "利奥", "玛丽", "诺亚",
		"奥利维亚", "帕特里克", "昆西", "瑞秋", "塞缪尔", "泰勒"]
	return {
		"name": names[randi() % names.size()] + str(randi() % 100),
		"job": "idle",  # idle / farmer / miner / lumberjack / soldier
		"assigned_building": "",  # 分配到的建筑 id，空表示闲置
	}

## 分配居民到建筑(提升产出 / 兵营转为驻军)
func assign_resident(resident_idx: int, building_id: String) -> bool:
	if resident_idx < 0 or resident_idx >= residents.size():
		return false
	if building_id != "" and not has_building(building_id):
		return false
	residents[resident_idx]["assigned_building"] = building_id
	# 根据建筑类型设置 job
	if building_id == "":
		residents[resident_idx]["job"] = "idle"
	else:
		var def = ConfigLoader.get_building_def(building_id)
		var cat = def.get("category", "")
		match cat:
			"production":
				match building_id:
					"lumber_mill": residents[resident_idx]["job"] = "lumberjack"
					"quarry": residents[resident_idx]["job"] = "miner"
					"farm": residents[resident_idx]["job"] = "farmer"
					_: residents[resident_idx]["job"] = "worker"
			"military":
				residents[resident_idx]["job"] = "soldier"
			_:
				residents[resident_idx]["job"] = "worker"
	_emit_dirty()
	residents_changed.emit()
	return true

## 统计分配到某建筑的居民数(用于产出加成)
func count_assigned_to(building_id: String) -> int:
	var n = 0
	for r in residents:
		if r.get("assigned_building", "") == building_id:
			n += 1
	return n

## 统计士兵(分配到 military 建筑的居民，P4 防御战用)
func count_soldiers() -> int:
	var n = 0
	for r in residents:
		if r.get("job", "") == "soldier":
			n += 1
	return n

## 领主大厅是核心建筑，领地必有一座，等级跟随领地等级
func _ensure_townhall():
	if not buildings.has("townhall"):
		buildings["townhall"] = level

## ============ 查询 ============
func get_level_def() -> Dictionary:
	return ConfigLoader.get_territory_level_def(level)

## 建筑槽位上限（已含领地等级基础值）
func get_building_slots() -> int:
	return int(get_level_def().get("building_slots", 3))

## 已占用槽位（townhall 不占普通槽位）
func get_used_slots() -> int:
	var n = 0
	for bid in buildings:
		if bid == "townhall":
			continue
		n += 1
	return n

func has_free_slot() -> bool:
	return get_used_slots() < get_building_slots()

func get_building_level(building_id: String) -> int:
	return int(buildings.get(building_id, 0))

func has_building(building_id: String) -> bool:
	return buildings.has(building_id)

## 居民上限 = 领地等级基础 + 农田/民居加成
func get_resident_cap() -> int:
	var cap = int(get_level_def().get("resident_cap", 5))
	cap += _sum_building_effect("resident_cap_bonus")
	return cap

## 驻军上限 = 兵营加成
func get_garrison_cap() -> int:
	return _sum_building_effect("garrison_cap_bonus")

## 领地防御值（0~1 减伤，城墙/领主大厅贡献）
func get_defense_bonus() -> float:
	return _sum_building_effect_f("defense_bonus")

## 哨塔总伤害（防御战远程火力，P4 用）
func get_tower_damage() -> float:
	return _sum_building_effect_f("tower_damage")

## 汇总所有建筑的某个整数 per_level 效果（按建筑当前等级）
func _sum_building_effect(key: String) -> int:
	var total = 0
	for bid in buildings:
		var def = ConfigLoader.get_building_def(bid)
		var per = def.get("per_level", {})
		if per.has(key):
			total += int(per[key]) * int(buildings[bid])
	return total

func _sum_building_effect_f(key: String) -> float:
	var total = 0.0
	for bid in buildings:
		var def = ConfigLoader.get_building_def(bid)
		var per = def.get("per_level", {})
		if per.has(key):
			total += float(per[key]) * int(buildings[bid])
	return total

## ============ 建造 / 升级 ============
## 判断成本是否可负担（gold 走 GameState.total_gold，其余走 materials）
func can_afford(cost: Dictionary) -> bool:
	for key in cost:
		var need = int(cost[key])
		if key == "gold":
			if GameState.total_gold < need:
				return false
		else:
			if GameState.get_material(key) < need:
				return false
	return true

## 扣除成本（调用前应先 can_afford）
func _pay_cost(cost: Dictionary):
	for key in cost:
		var amount = int(cost[key])
		if key == "gold":
			GameState.total_gold -= amount
		else:
			GameState.add_material(key, -amount)

## 建造新建筑。返回 {ok, reason}
func build_building(building_id: String) -> Dictionary:
	var def = ConfigLoader.get_building_def(building_id)
	if def.is_empty():
		return {"ok": false, "reason": "未知建筑"}
	if has_building(building_id):
		return {"ok": false, "reason": "已建造"}
	if def.get("unique", false) and has_building(building_id):
		return {"ok": false, "reason": "唯一建筑已存在"}
	if not has_free_slot():
		return {"ok": false, "reason": "建筑槽位已满"}
	var cost = def.get("build_cost", {})
	if not can_afford(cost):
		return {"ok": false, "reason": "材料不足"}
	_pay_cost(cost)
	buildings[building_id] = 1
	_emit_dirty()
	building_changed.emit(building_id)
	territory_changed.emit()
	print("[TerritorySystem] 建造: %s" % building_id)
	return {"ok": true, "reason": ""}

## 升级已有建筑。返回 {ok, reason}
func upgrade_building(building_id: String) -> Dictionary:
	var def = ConfigLoader.get_building_def(building_id)
	if def.is_empty():
		return {"ok": false, "reason": "未知建筑"}
	if not has_building(building_id):
		return {"ok": false, "reason": "尚未建造"}
	var cur = get_building_level(building_id)
	var max_lv = int(def.get("max_level", 5))
	if cur >= max_lv:
		return {"ok": false, "reason": "已满级"}
	# townhall 跟随领地等级，不单独升级
	if building_id == "townhall":
		return {"ok": false, "reason": "随领地升级"}
	var cost = _scaled_upgrade_cost(def, cur)
	if not can_afford(cost):
		return {"ok": false, "reason": "材料不足"}
	_pay_cost(cost)
	buildings[building_id] = cur + 1
	_emit_dirty()
	building_changed.emit(building_id)
	territory_changed.emit()
	print("[TerritorySystem] 升级建筑: %s -> Lv.%d" % [building_id, cur + 1])
	return {"ok": true, "reason": ""}

## 建筑升级成本随等级递增（每级 ×(1 + 0.4*cur)）
func _scaled_upgrade_cost(def: Dictionary, current_level: int) -> Dictionary:
	var base = def.get("upgrade_cost_per_level", {})
	var scaled = {}
	var mult = 1.0 + 0.4 * current_level
	for key in base:
		scaled[key] = int(ceil(float(base[key]) * mult))
	return scaled

## 获取建筑下一级的成本（UI 显示用，不扣费）
func get_upgrade_cost(building_id: String) -> Dictionary:
	var def = ConfigLoader.get_building_def(building_id)
	if def.is_empty() or not has_building(building_id):
		return {}
	return _scaled_upgrade_cost(def, get_building_level(building_id))

## ============ 领地升级 ============
func get_territory_upgrade_cost() -> Dictionary:
	var next_def = ConfigLoader.get_territory_level_def(level + 1)
	return next_def.get("upgrade_cost", {})

func can_upgrade_territory() -> bool:
	if level >= ConfigLoader.get_territory_max_level():
		return false
	return can_afford(get_territory_upgrade_cost())

func upgrade_territory() -> Dictionary:
	if level >= ConfigLoader.get_territory_max_level():
		return {"ok": false, "reason": "已达最高等级"}
	var cost = get_territory_upgrade_cost()
	if not can_afford(cost):
		return {"ok": false, "reason": "材料不足"}
	_pay_cost(cost)
	level += 1
	buildings["townhall"] = level  # 大厅跟随
	_emit_dirty()
	territory_leveled_up.emit(level)
	territory_changed.emit()
	print("[TerritorySystem] 领地升级 -> Lv.%d (%s)" % [level, get_level_def().get("display_name", "?")])
	return {"ok": true, "reason": ""}

func _emit_dirty():
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()

## ============ 出击结算（P3 接入产出，P1 先留接口）============
## 每次出击归来调用：建筑产出材料入库。返回产出明细 {material: amount}
func settle_sortie() -> Dictionary:
	sortie_count += 1  # P4: 计数触发防御战
	var gains = {}
	for bid in buildings:
		var def = ConfigLoader.get_building_def(bid)
		var prod = def.get("produces", {})
		if prod.is_empty():
			continue
		var mat = prod.get("material", "")
		if mat == "":
			continue
		var lv = get_building_level(bid)
		var amount = int(prod.get("base_per_sortie", 0)) + int(prod.get("per_level", 0)) * (lv - 1)
		# P3: 居民加成（每个居民 +10%，上限 +100%）
		var workers = count_assigned_to(bid)
		var worker_mult = min(1.0 + workers * 0.1, 2.0)
		amount = int(float(amount) * worker_mult)
		if amount > 0:
			GameState.add_material(mat, amount)
			gains[mat] = gains.get(mat, 0) + amount
	if not gains.is_empty():
		_emit_dirty()
		print("[TerritorySystem] 出击结算产出: %s" % str(gains))
	return gains

## ============ P4: 防御战触发 ============
const DEFENSE_INTERVAL := 5  # 每 5 次出击触发一次防御

func should_trigger_defense() -> bool:
	return sortie_count > 0 and (sortie_count % DEFENSE_INTERVAL) == 0

## 防御战胜利奖励
func reward_defense_victory() -> Dictionary:
	var rewards = {
		"timber": 50 + level * 10,
		"stone_block": 30 + level * 8,
		"food": 40 + level * 5,
	}
	for mat in rewards:
		GameState.add_material(mat, rewards[mat])
	last_defense_result = "victory"
	_emit_dirty()
	print("[TerritorySystem] 防御战胜利奖励: %s" % str(rewards))
	return rewards

## 防御战失败惩罚(损失部分材料 + 金币)
func penalty_defense_defeat():
	var loss_gold = min(GameState.total_gold, 200 + level * 50)
	GameState.total_gold -= loss_gold
	var mats = ["timber", "stone_block", "food"]
	var losses = {}
	for mat in mats:
		var have = GameState.get_material(mat)
		var loss = min(have, 20 + level * 5)
		if loss > 0:
			GameState.add_material(mat, -loss)
			losses[mat] = loss
	last_defense_result = "defeat"
	_emit_dirty()
	print("[TerritorySystem] 防御战失败惩罚: 金%d %s" % [loss_gold, str(losses)])

## ============ 序列化 ============
func serialize() -> Dictionary:
	return {
		"level": level,
		"buildings": buildings.duplicate(),
		"garrison": garrison.duplicate(true),
		"residents": residents.duplicate(true),
	}

func deserialize(data: Dictionary):
	level = int(data.get("level", 1))
	buildings = data.get("buildings", {}).duplicate()
	garrison = data.get("garrison", []).duplicate(true)
	residents = data.get("residents", []).duplicate(true)
	_ensure_townhall()
	territory_changed.emit()
	print("[TerritorySystem] 加载领地: Lv.%d, %d 建筑" % [level, buildings.size()])
