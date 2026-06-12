extends Node
## 副本通关闭环测试
## 验证 Boss 阵亡 → Victory.show_victory 的结算逻辑：金币全额带回、通关记录写入。
## （配套接线在 GameManager._on_boss_defeated，本测试聚焦可单测的结算逻辑）

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("victory: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))


func _make_victory() -> Control:
	# 实例化 Victory 场景，@onready 标签节点随之就绪
	var scene = load("res://scenes/Victory.tscn")
	var v = scene.instantiate()
	add_child(v)
	return v


func _reset_state(dungeon_id: String, tier: int):
	GameState.total_gold = 0
	GameState.selected_dungeon_id = dungeon_id
	GameState.selected_difficulty_tier = tier
	GameState.cleared_dungeons.erase(dungeon_id)
	# 隔离领地出击/防御战副作用，避免 show_victory 触发自动防御战扣金币
	if has_node("/root/TerritorySystem"):
		TerritorySystem.sortie_count = 0


func test_gold_full_carry():
	_reset_state("dungeon_crypt_1", 1)
	var v = _make_victory()
	v.show_victory(123.0, 7, 500)
	# 通关全额带回（对比死亡的 50%）
	_check("gold full carry", GameState.total_gold == 500, "got %d" % GameState.total_gold)
	v.queue_free()


func test_first_clear_record():
	_reset_state("dungeon_crypt_2", 2)
	var v = _make_victory()
	v.show_victory(60.0, 3, 100)
	_check(
		"first clear recorded",
		GameState.cleared_dungeons.has("dungeon_crypt_2"),
		"cleared_dungeons missing key"
	)
	var rec = GameState.cleared_dungeons.get("dungeon_crypt_2", {})
	_check("first clear tier", rec.get("max_tier_cleared", -1) == 2, "got %s" % rec)
	_check("first clear count", rec.get("total_clears", 0) == 1, "got %s" % rec)
	v.queue_free()


func test_repeat_clear_increments():
	_reset_state("dungeon_crypt_3", 1)
	var v1 = _make_victory()
	v1.show_victory(60.0, 3, 100)
	v1.queue_free()
	# 同副本更高难度再通关一次
	GameState.selected_difficulty_tier = 3
	var v2 = _make_victory()
	v2.show_victory(50.0, 4, 120)
	var rec = GameState.cleared_dungeons.get("dungeon_crypt_3", {})
	_check("repeat clear count = 2", rec.get("total_clears", 0) == 2, "got %s" % rec)
	_check("max tier raised to 3", rec.get("max_tier_cleared", -1) == 3, "got %s" % rec)
	v2.queue_free()


func test_gold_accumulates():
	_reset_state("dungeon_crypt_4", 1)
	GameState.total_gold = 1000
	var v = _make_victory()
	v.show_victory(60.0, 3, 250)
	_check("gold accumulates", GameState.total_gold == 1250, "got %d" % GameState.total_gold)
	v.queue_free()


func run_tests() -> Dictionary:
	print("\n=== Victory Flow Tests ===")
	_passed = 0
	_failed = 0
	_failed_names.clear()

	test_gold_full_carry()
	test_first_clear_record()
	test_repeat_clear_increments()
	test_gold_accumulates()

	print("=== Victory: %d passed, %d failed ===" % [_passed, _failed])
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
