extends Node
## P3 居民与产出测试

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("resident: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))

func _reset():
	TerritorySystem.level = 1
	TerritorySystem.buildings = {"townhall": 1}
	TerritorySystem.residents.clear()
	GameState.total_gold = 999999
	GameState.materials = {"timber": 9999, "stone_block": 9999, "food": 9999}

func test_recruit():
	_reset()
	var r = TerritorySystem.recruit_resident()
	_check("recruit: ok", r.get("ok", false), r.get("reason", ""))
	_check("recruit: count 1", TerritorySystem.resident_count() == 1, "")
	var resident = r.get("resident", {})
	_check("recruit: has name", resident.get("name", "") != "", "")
	_check("recruit: job idle", resident.get("job", "") == "idle", "")

func test_recruit_cost():
	_reset()
	var gold_before = GameState.total_gold
	var food_before = GameState.get_material("food")
	TerritorySystem.recruit_resident()
	_check("cost: gold deducted",
		GameState.total_gold == gold_before - TerritorySystem.RESIDENT_RECRUIT_COST_GOLD, "")
	_check("cost: food deducted",
		GameState.get_material("food") == food_before - TerritorySystem.RESIDENT_RECRUIT_COST_FOOD, "")

func test_recruit_at_cap():
	_reset()
	var cap = TerritorySystem.get_resident_cap()
	for i in cap:
		TerritorySystem.recruit_resident()
	var overflow = TerritorySystem.recruit_resident()
	_check("cap: reject overflow", not overflow.get("ok", true), "")

func test_assign():
	_reset()
	TerritorySystem.build_building("lumber_mill")
	TerritorySystem.recruit_resident()
	var ok = TerritorySystem.assign_resident(0, "lumber_mill")
	_check("assign: ok", ok, "")
	_check("assign: job lumberjack",
		TerritorySystem.residents[0].get("job", "") == "lumberjack", "")
	_check("assign: count 1",
		TerritorySystem.count_assigned_to("lumber_mill") == 1, "")

func test_production_bonus():
	_reset()
	TerritorySystem.build_building("lumber_mill")  # base 8 timber/sortie
	# 无居民
	var gains0 = TerritorySystem.settle_sortie()
	_check("bonus: no worker = base", gains0.get("timber", 0) == 8, "got " + str(gains0.get("timber", 0)))
	# 1 居民 +10%
	TerritorySystem.recruit_resident()
	TerritorySystem.assign_resident(0, "lumber_mill")
	var gains1 = TerritorySystem.settle_sortie()
	_check("bonus: 1 worker = 110%",
		gains1.get("timber", 0) == int(8 * 1.1),
		"got " + str(gains1.get("timber", 0)))
	# 5 居民 +50%
	for i in 4:
		TerritorySystem.recruit_resident()
		TerritorySystem.assign_resident(i + 1, "lumber_mill")
	var gains5 = TerritorySystem.settle_sortie()
	_check("bonus: 5 workers = 150%",
		gains5.get("timber", 0) == int(8 * 1.5),
		"got " + str(gains5.get("timber", 0)))

func test_soldier_count():
	_reset()
	TerritorySystem.build_building("barracks")
	TerritorySystem.recruit_resident()
	TerritorySystem.recruit_resident()
	TerritorySystem.assign_resident(0, "barracks")
	_check("soldier: count 1", TerritorySystem.count_soldiers() == 1, "")
	_check("soldier: job soldier",
		TerritorySystem.residents[0].get("job", "") == "soldier", "")

func run_tests() -> Dictionary:
	print("\n=== Resident (P3) Tests ===")
	_passed = 0
	_failed = 0
	_failed_names.clear()

	test_recruit()
	test_recruit_cost()
	test_recruit_at_cap()
	test_assign()
	test_production_bonus()
	test_soldier_count()

	print("=== Resident: %d passed, %d failed ===" % [_passed, _failed])
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
