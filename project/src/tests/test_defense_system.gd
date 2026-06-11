extends Node
## P4 防御战测试

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("defense: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))


func _reset():
	TerritorySystem.level = 1
	TerritorySystem.buildings = {"townhall": 1}
	TerritorySystem.residents.clear()
	TerritorySystem.sortie_count = 0
	TerritorySystem.last_defense_result = ""
	GameState.total_gold = 999999
	GameState.materials = {"timber": 9999, "stone_block": 9999, "food": 9999}


func test_trigger_interval():
	_reset()
	for i in 4:
		TerritorySystem.settle_sortie()
		_check(
			"trigger: sortie %d not trigger" % (i + 1),
			not TerritorySystem.should_trigger_defense(),
			""
		)
	TerritorySystem.settle_sortie()  # 第 5 次
	_check("trigger: sortie 5 triggers", TerritorySystem.should_trigger_defense(), "")


func test_victory_reward():
	_reset()
	var timber_before = GameState.get_material("timber")
	var rewards = TerritorySystem.reward_defense_victory()
	_check("victory: got rewards", not rewards.is_empty(), "")
	_check(
		"victory: timber added",
		GameState.get_material("timber") > timber_before,
		"got " + str(GameState.get_material("timber"))
	)
	_check("victory: result recorded", TerritorySystem.last_defense_result == "victory", "")


func test_defeat_penalty():
	_reset()
	var gold_before = GameState.total_gold
	TerritorySystem.penalty_defense_defeat()
	_check("defeat: gold lost", GameState.total_gold < gold_before, "")
	_check("defeat: result recorded", TerritorySystem.last_defense_result == "defeat", "")


func test_soldier_power():
	_reset()
	_check("power: no soldiers = 0", TerritorySystem.count_soldiers() == 0, "")
	TerritorySystem.build_building("barracks")
	TerritorySystem.recruit_resident()
	TerritorySystem.assign_resident(0, "barracks")
	_check("power: 1 soldier", TerritorySystem.count_soldiers() == 1, "")


func run_tests() -> Dictionary:
	print("\n=== Defense (P4) Tests ===")
	_passed = 0
	_failed = 0
	_failed_names.clear()

	test_trigger_interval()
	test_victory_reward()
	test_defeat_penalty()
	test_soldier_power()

	print("=== Defense: %d passed, %d failed ===" % [_passed, _failed])
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
