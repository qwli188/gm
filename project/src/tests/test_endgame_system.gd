extends Node
## P7 末期内容测试 - 地图词缀/试炼塔/裂隙

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("endgame: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))


func _reset():
	EndgameSystem.active_modifiers.clear()
	EndgameSystem.trial_max_floor = 0
	EndgameSystem.trial_milestones_claimed.clear()
	EndgameSystem.trial_active = false
	EndgameSystem.trial_current_floor = 0
	EndgameSystem.rift_active = false
	EndgameSystem.rift_modifiers.clear()
	GameState.total_gold = 0
	GameState.materials.clear()
	GameState.talent_points_unspent = 0


func test_modifier_toggle():
	_reset()
	var on = EndgameSystem.toggle_modifier("mod_savage")
	_check("modifier: toggled on", on, "")
	_check("modifier: in active list", "mod_savage" in EndgameSystem.active_modifiers, "")
	# 关闭
	var on2 = EndgameSystem.toggle_modifier("mod_savage")
	_check("modifier: toggled off", not on2, "")
	_check("modifier: removed", not ("mod_savage" in EndgameSystem.active_modifiers), "")


func test_modifier_max_cap():
	_reset()
	var pool = EndgameSystem.get_all_modifiers()
	# 加满 max_active 个
	var cap = EndgameSystem.max_modifiers()
	for i in cap:
		EndgameSystem.toggle_modifier(pool[i].get("id", ""))
	_check("modifier: at cap", EndgameSystem.active_modifiers.size() == cap, "")
	# 第 cap+1 个应被拒（不会加进去）
	var extra = pool[cap].get("id", "")
	EndgameSystem.toggle_modifier(extra)
	_check("modifier: cap respected", EndgameSystem.active_modifiers.size() == cap, "")
	_check("modifier: extra not added", not (extra in EndgameSystem.active_modifiers), "")


func test_modifier_aggregate():
	_reset()
	EndgameSystem.toggle_modifier("mod_savage")  # enemy_dmg_mult +0.30, drop+0.15, exp+0.10
	EndgameSystem.toggle_modifier("mod_juggernaut")  # enemy_hp_mult +0.50, drop+0.20
	var agg = EndgameSystem.aggregate_active_effects()
	_check("agg: dmg_mult", abs(agg.get("enemy_dmg_mult", 0) - 0.30) < 0.0001, str(agg))
	_check("agg: hp_mult", abs(agg.get("enemy_hp_mult", 0) - 0.50) < 0.0001, "")
	_check("agg: drop sum", abs(agg.get("drop_bonus", 0) - 0.35) < 0.0001, str(agg))


func test_modifier_applied_to_enter_dungeon():
	_reset()
	EndgameSystem.toggle_modifier("mod_savage")
	GameState.enter_dungeon("dungeon_crypt_1", 1)
	# tier 1 默认 hp/dmg 倍率 ≈ 1.0；savage 给 dmg +30%
	_check(
		"enter: dmg_mult applied",
		GameState.selected_dmg_mult >= 1.29,
		"got " + str(GameState.selected_dmg_mult)
	)
	_check(
		"enter: drop bonus applied",
		GameState.selected_drop_bonus >= 0.15,
		"got " + str(GameState.selected_drop_bonus)
	)


func test_trial_progress():
	_reset()
	EndgameSystem.start_trial(1)
	_check("trial: active", EndgameSystem.trial_active, "")
	_check("trial: floor 1", EndgameSystem.trial_current_floor == 1, "")
	# 通过 5 层（含一次 5 层奖励）
	for i in 5:
		EndgameSystem.clear_trial_floor()
	_check("trial: max floor 5", EndgameSystem.trial_max_floor == 5, "")
	_check(
		"trial: gold rewarded for floor 5",
		GameState.total_gold > 0,
		"got " + str(GameState.total_gold)
	)
	# 推到 10 层应给里程碑（+1 talent point）
	for i in 5:
		EndgameSystem.clear_trial_floor()
	_check("trial: max floor 10", EndgameSystem.trial_max_floor == 10, "")
	_check(
		"trial: milestone talent point",
		GameState.talent_points_unspent >= 1,
		"got " + str(GameState.talent_points_unspent)
	)
	_check("trial: milestone marked", EndgameSystem.trial_milestones_claimed.get("10", false), "")


func test_trial_floor_multipliers():
	_reset()
	EndgameSystem.start_trial(11)
	var m = EndgameSystem.get_trial_floor_multipliers()
	# floor 11: hp×(1+0.10×10)=2.0, dmg×(1+0.07×10)=1.7
	_check("trial: floor 11 hp x2", abs(m["hp_mult"] - 2.0) < 0.001, "got " + str(m["hp_mult"]))
	_check(
		"trial: floor 11 dmg x1.7", abs(m["dmg_mult"] - 1.7) < 0.001, "got " + str(m["dmg_mult"])
	)
	_check("trial: floor 11 not boss", not m["is_boss_floor"], "")
	EndgameSystem.trial_current_floor = 10
	var m2 = EndgameSystem.get_trial_floor_multipliers()
	_check("trial: floor 10 is boss", m2["is_boss_floor"], "")


func test_rift_lifecycle():
	_reset()
	var info = EndgameSystem.start_rift()
	_check("rift: active", EndgameSystem.rift_active, "")
	_check("rift: seed assigned", info.get("seed", "") != "", "")
	_check("rift: time_limit present", info.get("time_limit", 0) > 0, "")
	# 完成
	var rew = EndgameSystem.complete_rift(true)
	_check("rift: not active after complete", not EndgameSystem.rift_active, "")
	_check(
		"rift: essence rewarded",
		GameState.get_material("rift_essence") > 0,
		"got " + str(GameState.get_material("rift_essence"))
	)
	_check("rift: gold rewarded", GameState.total_gold > 0, "")


func test_rift_fail_no_reward():
	_reset()
	EndgameSystem.start_rift()
	var rew = EndgameSystem.complete_rift(false)
	_check("rift: no essence on fail", GameState.get_material("rift_essence") == 0, "")
	_check("rift: no gold on fail", GameState.total_gold == 0, "")


func run_tests() -> Dictionary:
	test_modifier_toggle()
	test_modifier_max_cap()
	test_modifier_aggregate()
	test_modifier_applied_to_enter_dungeon()
	test_trial_progress()
	test_trial_floor_multipliers()
	test_rift_lifecycle()
	test_rift_fail_no_reward()

	print("\n--- 末期内容测试 ---")
	print("✅ 通过: " + str(_passed))
	print("❌ 失败: " + str(_failed))
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
