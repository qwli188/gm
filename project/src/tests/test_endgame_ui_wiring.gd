extends Node
## 末期系统 UI 接线测试
## 覆盖本次接线新增的后端契约：
## - GameState.deallocate_paragon（巅峰减号）
## - GameState.enter_trial_floor / enter_rift_run（试炼塔/裂隙进场参数 + run_mode）
## - 巅峰加点经 allocate/deallocate 的往返一致性（UI ± 按钮依赖）

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("endgame_ui: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))


func _reset():
	GameState.paragon_points_unspent = 0
	GameState.paragon_allocations.clear()
	GameState.unlocked_talents.clear()
	GameState.talent_points_unspent = 0
	GameState.run_mode = "dungeon"
	EndgameSystem.trial_active = false
	EndgameSystem.trial_current_floor = 0
	EndgameSystem.trial_max_floor = 0
	EndgameSystem.rift_active = false


## 巅峰加点：allocate 后 deallocate 回到原点，点数守恒
func test_paragon_allocate_deallocate_roundtrip():
	_reset()
	# 找一个真实巅峰条目 id
	var cfg = ConfigLoader.get_balance_config().get("paragon_system", {})
	var stats = cfg.get("paragon_stats", [])
	_check("paragon: config has stats", stats.size() > 0, "")
	if stats.is_empty():
		return
	var pid = stats[0].get("id", "")

	GameState.paragon_points_unspent = 5
	var r1 = GameState.allocate_paragon(pid, 1)
	_check("paragon: allocate ok", r1.get("ok", false), str(r1))
	_check("paragon: allocated 1", GameState.paragon_allocations.get(pid, 0) == 1, "")
	_check("paragon: points 4 after alloc", GameState.paragon_points_unspent == 4, "")

	var r2 = GameState.deallocate_paragon(pid, 1)
	_check("paragon: deallocate ok", r2.get("ok", false), str(r2))
	_check("paragon: allocation cleared", not GameState.paragon_allocations.has(pid), "")
	_check("paragon: points restored to 5", GameState.paragon_points_unspent == 5, "")


## 巅峰减号：无加点时退点应失败，不产生负数
func test_paragon_deallocate_guard():
	_reset()
	var r = GameState.deallocate_paragon("paragon_damage", 1)
	_check("paragon: deallocate empty fails", not r.get("ok", true), str(r))
	_check("paragon: points stay 0", GameState.paragon_points_unspent == 0, "")


## 试炼塔进场：run_mode=trial，倍率取逐层值
func test_enter_trial_floor():
	_reset()
	EndgameSystem.start_trial(11)
	GameState.enter_trial_floor()
	_check("trial: run_mode set", GameState.run_mode == "trial", GameState.run_mode)
	# floor 11: hp×2.0, dmg×1.7（与 EndgameSystem 单测一致）
	_check(
		"trial: hp mult from floor",
		abs(GameState.selected_hp_mult - 2.0) < 0.001,
		str(GameState.selected_hp_mult)
	)
	_check(
		"trial: dmg mult from floor",
		abs(GameState.selected_dmg_mult - 1.7) < 0.001,
		str(GameState.selected_dmg_mult)
	)
	_check("trial: waveset assigned", GameState.selected_waveset != "", "")


## 裂隙进场：run_mode=rift，倍率为裂隙基准
func test_enter_rift_run():
	_reset()
	EndgameSystem.start_rift()
	GameState.enter_rift_run()
	_check("rift: run_mode set", GameState.run_mode == "rift", GameState.run_mode)
	_check("rift: hp mult buffed", GameState.selected_hp_mult > 1.0, "")
	_check("rift: drop bonus positive", GameState.selected_drop_bonus > 0.0, "")


## enter_dungeon 应把 run_mode 重置回 dungeon
func test_enter_dungeon_resets_mode():
	_reset()
	GameState.run_mode = "trial"
	GameState.enter_dungeon("dungeon_crypt_1", 1)
	_check("dungeon: run_mode reset", GameState.run_mode == "dungeon", GameState.run_mode)


func run_tests() -> Dictionary:
	print("\n=== Endgame UI Wiring Tests ===")
	_passed = 0
	_failed = 0
	_failed_names.clear()

	test_paragon_allocate_deallocate_roundtrip()
	test_paragon_deallocate_guard()
	test_enter_trial_floor()
	test_enter_rift_run()
	test_enter_dungeon_resets_mode()

	print("=== Endgame UI: %d passed, %d failed ===" % [_passed, _failed])
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
