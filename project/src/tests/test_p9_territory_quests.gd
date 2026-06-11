extends Node
## P9 领地深化测试 - 居民进化 / 商人 / 任务

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("p9: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))

func _reset():
	TerritorySystem.level = 2
	TerritorySystem.buildings = {"townhall": 2, "lumber_mill": 1, "farm": 1}
	TerritorySystem.residents.clear()
	TerritorySystem.sortie_count = 0
	TerritorySystem.merchant_stock.clear()
	TerritorySystem.merchant_last_refresh_sortie = 0
	GameState.total_gold = 99999
	GameState.materials = {"timber": 100, "stone_block": 100, "food": 200}
	QuestSystem.active_quests.clear()
	QuestSystem.completed_quests.clear()
	QuestSystem.last_refresh_sortie = 0

# ============ 居民进化 ============
func test_resident_stage_starts_novice():
	_reset()
	TerritorySystem.residents.append({"name": "测试1", "job": "lumberjack", "assigned_building": "lumber_mill", "sorties_worked": 0})
	var stage = TerritorySystem.get_resident_stage(0)
	_check("stage: starts novice", stage.get("id", "") == "novice", "got " + str(stage))

func test_resident_evolution_threshold():
	_reset()
	TerritorySystem.residents.append({"name": "测试2", "job": "lumberjack", "assigned_building": "lumber_mill", "sorties_worked": 5})
	var stage = TerritorySystem.get_resident_stage(0)
	_check("stage: skilled at 5 sorties", stage.get("id", "") == "skilled", "got " + str(stage))

	TerritorySystem.residents[0]["sorties_worked"] = 15
	stage = TerritorySystem.get_resident_stage(0)
	_check("stage: master at 15 sorties", stage.get("id", "") == "master", "")

	TerritorySystem.residents[0]["sorties_worked"] = 40
	stage = TerritorySystem.get_resident_stage(0)
	_check("stage: grandmaster at 40 sorties", stage.get("id", "") == "grandmaster", "")

func test_settle_sortie_increments_worker():
	_reset()
	TerritorySystem.residents.append({"name": "测试3", "job": "lumberjack", "assigned_building": "lumber_mill", "sorties_worked": 0})
	# 闲置居民不该累加
	TerritorySystem.residents.append({"name": "闲", "job": "idle", "assigned_building": "", "sorties_worked": 0})
	TerritorySystem.settle_sortie()
	_check("worker: assigned +1", TerritorySystem.residents[0].get("sorties_worked", 0) == 1, "")
	_check("worker: idle still 0", TerritorySystem.residents[1].get("sorties_worked", 0) == 0, "")

# ============ 商人 ============
func test_merchant_refresh_on_sortie():
	_reset()
	# refresh_every_n_sorties=3，3 次出击后应有库存
	for i in 3:
		TerritorySystem.settle_sortie()
	_check("merchant: stock filled", TerritorySystem.merchant_stock.size() > 0, "got " + str(TerritorySystem.merchant_stock.size()))

func test_merchant_buy_material():
	_reset()
	TerritorySystem.refresh_merchant()
	# 找一个 material 类型商品
	var mat_item = null
	for it in TerritorySystem.merchant_stock:
		if it.get("type", "") == "material":
			mat_item = it
			break
	if mat_item == null:
		# 强制塞一个测试商品
		TerritorySystem.merchant_stock.append({
			"id": "test_mat", "display_name": "测试袋", "type": "material",
			"material_id": "rune_shard", "amount": 10, "cost_gold": 100
		})
		mat_item = TerritorySystem.merchant_stock[-1]
	var before_mat = GameState.get_material(mat_item["material_id"])
	var before_gold = GameState.total_gold
	var r = TerritorySystem.buy_from_merchant(mat_item["id"])
	_check("merchant: buy success", r["ok"], r.get("reason", ""))
	_check("merchant: material added", GameState.get_material(mat_item["material_id"]) == before_mat + int(mat_item["amount"]), "")
	_check("merchant: gold deducted", GameState.total_gold == before_gold - int(mat_item["cost_gold"]), "")
	_check("merchant: removed from stock", not (mat_item in TerritorySystem.merchant_stock), "")

func test_merchant_buy_insufficient_gold():
	_reset()
	GameState.total_gold = 0
	TerritorySystem.refresh_merchant()
	if TerritorySystem.merchant_stock.is_empty():
		return
	var item = TerritorySystem.merchant_stock[0]
	var r = TerritorySystem.buy_from_merchant(item["id"])
	_check("merchant: rejected on no gold", not r["ok"], "")

# ============ 任务 ============
func test_quest_refresh():
	_reset()
	QuestSystem.refresh_quests(0)
	_check("quest: filled to max", QuestSystem.active_quests.size() == QuestSystem._max_active(), "got " + str(QuestSystem.active_quests.size()))

func test_quest_kill_tag():
	_reset()
	# 注入一条 kill_tag undead 30 的任务
	QuestSystem.active_quests = [{
		"id": "qtest1", "template_id": "quest_kill_undead", "type": "kill_tag",
		"tag": "undead", "target": 5, "progress": 0, "rewards": {"gold": 100}
	}]
	for i in 5:
		QuestSystem.register_kill({"tags": ["undead", "melee"], "rank": "normal"})
	_check("quest: completed", QuestSystem.active_quests.is_empty(), "still active: " + str(QuestSystem.active_quests))
	_check("quest: in completed list", QuestSystem.completed_quests.size() == 1, "")
	# 领奖
	GameState.total_gold = 0
	var qid = QuestSystem.completed_quests[0]["id"]
	var r = QuestSystem.claim_reward(qid)
	_check("quest: claimed", r["ok"], "")
	_check("quest: gold rewarded", GameState.total_gold == 100, "got " + str(GameState.total_gold))
	_check("quest: removed after claim", QuestSystem.completed_quests.is_empty(), "")

func test_quest_kill_boss():
	_reset()
	QuestSystem.active_quests = [{
		"id": "qboss", "template_id": "quest_kill_boss", "type": "kill_boss",
		"target": 1, "progress": 0, "rewards": {"gold": 200}
	}]
	# 普通敌人不计
	QuestSystem.register_kill({"tags": [], "rank": "normal"})
	_check("quest: normal does not progress boss", QuestSystem.active_quests[0]["progress"] == 0, "")
	# Boss 计
	QuestSystem.register_kill({"tags": [], "rank": "boss"})
	_check("quest: boss completed", QuestSystem.completed_quests.size() == 1, "")

func test_quest_drop_rarity():
	_reset()
	QuestSystem.active_quests = [{
		"id": "qdrop", "template_id": "quest_drop_legendary", "type": "drop_rarity",
		"rarity": "legendary", "target": 2, "progress": 0, "rewards": {"gold": 50}
	}]
	QuestSystem.register_drop("rare")
	_check("quest: rare not match", QuestSystem.active_quests[0]["progress"] == 0, "")
	QuestSystem.register_drop("legendary")
	QuestSystem.register_drop("legendary")
	_check("quest: legendary x2 completes", QuestSystem.completed_quests.size() == 1, "")

func test_quest_clear_dungeon():
	_reset()
	QuestSystem.active_quests = [{
		"id": "qclear", "template_id": "quest_clear_dungeon", "type": "clear_dungeon",
		"target": 1, "progress": 0, "rewards": {"gold": 80}
	}]
	QuestSystem.register_clear_dungeon("dungeon_crypt_1")
	_check("quest: clear completes", QuestSystem.completed_quests.size() == 1, "")

func run_tests() -> Dictionary:
	test_resident_stage_starts_novice()
	test_resident_evolution_threshold()
	test_settle_sortie_increments_worker()
	test_merchant_refresh_on_sortie()
	test_merchant_buy_material()
	test_merchant_buy_insufficient_gold()
	test_quest_refresh()
	test_quest_kill_tag()
	test_quest_kill_boss()
	test_quest_drop_rarity()
	test_quest_clear_dungeon()

	print("\n--- P9 领地深化测试 ---")
	print("✅ 通过: " + str(_passed))
	print("❌ 失败: " + str(_failed))
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
