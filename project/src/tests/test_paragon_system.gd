extends Node
## P6 巅峰系统单元测试 - 经验溢出/加点/天赋/重置/存档往返

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("paragon: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))

func _reset():
	GameState.paragon_level = 0
	GameState.paragon_exp = 0.0
	GameState.paragon_points_unspent = 0
	GameState.paragon_allocations.clear()
	GameState.unlocked_talents.clear()
	GameState.talent_points_unspent = 0

func test_paragon_unlocks_above_max_level():
	_reset()
	# 一次性吃 10000 经验，按 base=5000 至少应得 1 级
	var gained = GameState.gain_paragon_exp(10000.0)
	_check("paragon: gained >= 1", gained >= 1, "got " + str(gained))
	_check("paragon: level >= 1", GameState.paragon_level >= 1, "")
	_check("paragon: points granted", GameState.paragon_points_unspent >= 1, "")
	_check("paragon: talent points granted", GameState.talent_points_unspent >= 1, "")

func test_paragon_allocate():
	_reset()
	GameState.paragon_points_unspent = 5
	var r = GameState.allocate_paragon("paragon_damage", 3)
	_check("alloc: ok", r["ok"], r.get("reason", ""))
	_check("alloc: bonus applied", abs(GameState.get_paragon_bonus("damage_pct") - 3 * 0.005) < 0.0001, "")
	_check("alloc: points decremented", GameState.paragon_points_unspent == 2, "")
	# 不足
	var r2 = GameState.allocate_paragon("paragon_damage", 100)
	_check("alloc: insufficient", not r2["ok"], "")
	# 未知 id
	var r3 = GameState.allocate_paragon("paragon_unknown", 1)
	_check("alloc: unknown id rejected", not r3["ok"], "")

func test_paragon_max_alloc():
	_reset()
	GameState.paragon_points_unspent = 999
	# crit_chance max 50
	GameState.allocate_paragon("paragon_crit_chance", 50)
	var r = GameState.allocate_paragon("paragon_crit_chance", 1)
	_check("alloc: max cap", not r["ok"], "should reject above max_alloc")

func test_paragon_reset():
	_reset()
	GameState.paragon_points_unspent = 10
	GameState.allocate_paragon("paragon_damage", 5)
	_check("pre-reset spent", GameState.paragon_points_unspent == 5, "")
	GameState.reset_paragon_allocations()
	_check("post-reset refunded", GameState.paragon_points_unspent == 10, "")
	_check("post-reset bonus zero", GameState.get_paragon_bonus("damage_pct") == 0.0, "")

func test_talent_unlock():
	_reset()
	GameState.talent_points_unspent = 5
	GameState.selected_class_id = "class_warrior"
	# 战士根节点应可解
	var r = GameState.unlock_talent("talent_warrior_root")
	_check("talent: warrior root unlocked", r["ok"], r.get("reason", ""))
	_check("talent: cost 1 point", GameState.talent_points_unspent == 4, "")
	# 非战士根节点应被拒
	var r2 = GameState.unlock_talent("talent_mage_root")
	_check("talent: foreign class root rejected", not r2["ok"], "")
	# 已解锁不可重复
	var r3 = GameState.unlock_talent("talent_warrior_root")
	_check("talent: dup rejected", not r3["ok"], "")

func test_talent_prereq_chain():
	_reset()
	GameState.talent_points_unspent = 10
	GameState.selected_class_id = "class_warrior"
	GameState.unlock_talent("talent_warrior_root")
	# might_1 前置（any: warrior 或 knight 根），warrior 已解 → ok
	var r1 = GameState.unlock_talent("talent_might_1")
	_check("talent: might_1 unlocked via any-prereq", r1["ok"], r1.get("reason", ""))
	# capstone_berserker 需要 might_2 + guard_2，未解锁 → 拒
	var rb = GameState.unlock_talent("talent_capstone_berserker")
	_check("talent: capstone blocked without prereqs", not rb["ok"], "")

func test_talent_effects_aggregate():
	_reset()
	GameState.unlocked_talents = {"talent_warrior_root": 1, "talent_might_1": 1}
	var eff = ConfigLoader.get_unlocked_talent_effects(GameState.unlocked_talents)
	# warrior_root: hp+30, dmg+3; might_1: dmg+4, hp+20 → 总 hp+50, dmg+7
	_check("talent: aggregate hp", eff.get("max_hp", 0) == 50, "got " + str(eff.get("max_hp", 0)))
	_check("talent: aggregate dmg", eff.get("damage", 0) == 7, "got " + str(eff.get("damage", 0)))

func run_tests() -> Dictionary:
	test_paragon_unlocks_above_max_level()
	test_paragon_allocate()
	test_paragon_max_alloc()
	test_paragon_reset()
	test_talent_unlock()
	test_talent_prereq_chain()
	test_talent_effects_aggregate()

	print("\n--- Paragon/Talent 测试 ---")
	print("✅ 通过: " + str(_passed))
	print("❌ 失败: " + str(_failed))
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
