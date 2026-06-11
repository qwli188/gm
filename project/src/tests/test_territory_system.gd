extends Node
## TerritorySystem 单元测试 - 建造/升级/领地升级/产出结算/存档往返

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

const TEST_SLOT = 3


func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("territory: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))


func _reset():
	TerritorySystem.level = 1
	TerritorySystem.buildings = {"townhall": 1}
	TerritorySystem.garrison.clear()
	TerritorySystem.residents.clear()
	# 给足资源
	GameState.total_gold = 999999
	GameState.materials = {
		"timber": 9999,
		"stone_block": 9999,
		"food": 9999,
		"bone_dust": 999,
		"frost_shard": 999,
		"plague_essence": 999,
		"ember_core": 999,
		"void_fragment": 999,
		"rune_shard": 999,
	}


func test_initial_state():
	_reset()
	_check("init: level 1", TerritorySystem.level == 1, "")
	_check("init: has townhall", TerritorySystem.has_building("townhall"), "")
	_check(
		"init: used slots 0 (townhall not counted)",
		TerritorySystem.get_used_slots() == 0,
		"got " + str(TerritorySystem.get_used_slots())
	)
	_check("init: has free slot", TerritorySystem.has_free_slot(), "")


func test_build():
	_reset()
	var r = TerritorySystem.build_building("lumber_mill")
	_check("build: ok", r.get("ok", false), r.get("reason", ""))
	_check("build: has lumber_mill", TerritorySystem.has_building("lumber_mill"), "")
	_check("build: level 1", TerritorySystem.get_building_level("lumber_mill") == 1, "")
	_check("build: used slot 1", TerritorySystem.get_used_slots() == 1, "")
	# 重复建造应失败
	var r2 = TerritorySystem.build_building("lumber_mill")
	_check("build: reject duplicate", not r2.get("ok", true), "")


func test_build_cost_deducted():
	_reset()
	var gold_before = GameState.total_gold
	var timber_before = GameState.get_material("timber")
	TerritorySystem.build_building("lumber_mill")  # cost gold 300, timber 10
	_check(
		"cost: gold deducted",
		GameState.total_gold == gold_before - 300,
		"got " + str(GameState.total_gold)
	)
	_check(
		"cost: timber deducted",
		GameState.get_material("timber") == timber_before - 10,
		"got " + str(GameState.get_material("timber"))
	)


func test_build_insufficient():
	_reset()
	GameState.total_gold = 0
	GameState.materials = {}
	var r = TerritorySystem.build_building("lumber_mill")
	_check("build: reject when poor", not r.get("ok", true), "")


func test_slot_limit():
	_reset()
	# Lv1 有 3 槽位，建 3 个不同建筑应成功，第 4 个失败
	_check("slot: build 1", TerritorySystem.build_building("lumber_mill").get("ok"), "")
	_check("slot: build 2", TerritorySystem.build_building("quarry").get("ok"), "")
	_check("slot: build 3", TerritorySystem.build_building("farm").get("ok"), "")
	var r4 = TerritorySystem.build_building("house")
	_check("slot: reject 4th (cap 3)", not r4.get("ok", true), r4.get("reason", ""))


func test_upgrade_building():
	_reset()
	TerritorySystem.build_building("lumber_mill")
	var r = TerritorySystem.upgrade_building("lumber_mill")
	_check("upgrade: ok", r.get("ok", false), r.get("reason", ""))
	_check("upgrade: level 2", TerritorySystem.get_building_level("lumber_mill") == 2, "")


func test_upgrade_territory():
	_reset()
	var r = TerritorySystem.upgrade_territory()
	_check("territory up: ok", r.get("ok", false), r.get("reason", ""))
	_check("territory up: level 2", TerritorySystem.level == 2, "")
	_check(
		"territory up: townhall follows", TerritorySystem.get_building_level("townhall") == 2, ""
	)
	_check(
		"territory up: more slots",
		TerritorySystem.get_building_slots() == 5,
		"got " + str(TerritorySystem.get_building_slots())
	)


func test_settle_sortie_production():
	_reset()
	TerritorySystem.build_building("lumber_mill")  # produces timber 8/sortie at lv1
	var timber_before = GameState.get_material("timber")
	var gains = TerritorySystem.settle_sortie()
	_check(
		"settle: produces timber", gains.get("timber", 0) == 8, "got " + str(gains.get("timber", 0))
	)
	_check("settle: material added", GameState.get_material("timber") == timber_before + 8, "")


func test_resident_cap():
	_reset()
	var base_cap = TerritorySystem.get_resident_cap()  # lv1 = 5
	TerritorySystem.build_building("house")  # +4/level resident_cap
	_check(
		"cap: house increases cap",
		TerritorySystem.get_resident_cap() == base_cap + 4,
		"got " + str(TerritorySystem.get_resident_cap())
	)


func test_save_load():
	_reset()
	TerritorySystem.upgrade_territory()  # level 2
	TerritorySystem.build_building("lumber_mill")
	TerritorySystem.upgrade_building("lumber_mill")  # lumber_mill level 2

	SaveSystem.save_game(TEST_SLOT)
	# 清空模拟新进程
	TerritorySystem.level = 1
	TerritorySystem.buildings = {"townhall": 1}
	SaveSystem.load_game(TEST_SLOT)

	_check("save/load: level 2", TerritorySystem.level == 2, "got " + str(TerritorySystem.level))
	_check(
		"save/load: lumber_mill level 2",
		TerritorySystem.get_building_level("lumber_mill") == 2,
		"got " + str(TerritorySystem.get_building_level("lumber_mill"))
	)
	SaveSystem.delete_save(TEST_SLOT)
	_reset()


func test_materials_persist():
	_reset()
	GameState.materials = {"timber": 77, "bone_dust": 33}
	SaveSystem.save_game(TEST_SLOT)
	GameState.materials = {}
	SaveSystem.load_game(TEST_SLOT)
	_check(
		"materials persist: timber",
		GameState.get_material("timber") == 77,
		"got " + str(GameState.get_material("timber"))
	)
	_check("materials persist: bone_dust", GameState.get_material("bone_dust") == 33, "")
	SaveSystem.delete_save(TEST_SLOT)


func run_tests() -> Dictionary:
	print("\n=== TerritorySystem Tests ===")
	_passed = 0
	_failed = 0
	_failed_names.clear()

	test_initial_state()
	test_build()
	test_build_cost_deducted()
	test_build_insufficient()
	test_slot_limit()
	test_upgrade_building()
	test_upgrade_territory()
	test_settle_sortie_production()
	test_resident_cap()
	test_save_load()
	test_materials_persist()

	print("=== TerritorySystem: %d passed, %d failed ===" % [_passed, _failed])
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
