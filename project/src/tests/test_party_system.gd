extends Node
## PartySystem + RosterSystem.compute_character_stats 测试

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("party: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))

func _reset():
	RosterSystem.characters.clear()
	RosterSystem.active_char_id = ""
	PartySystem.companion_ids.clear()

func test_compute_stats():
	_reset()
	var id = RosterSystem.create_character("class_warrior", "战")
	var stats = RosterSystem.compute_character_stats(id)
	_check("stats: not empty", not stats.is_empty(), "")
	_check("stats: has max_hp", stats.get("max_hp", 0) > 0, "")
	_check("stats: has damage", stats.get("damage", 0) > 0, "")
	# 起手武器应让 damage 高于纯职业基础
	var cls = ConfigLoader.get_class_by_id("class_warrior")
	var base_dmg = cls.get("base_stats", {}).get("damage", 0)
	_check("stats: weapon adds damage", stats.get("damage", 0) >= base_dmg,
		"got " + str(stats.get("damage", 0)) + " vs base " + str(base_dmg))

func test_stats_scale_with_level():
	_reset()
	var id = RosterSystem.create_character("class_mage", "法")
	var lvl1 = RosterSystem.compute_character_stats(id)
	# 手动升级档案
	RosterSystem.get_character(id)["level"] = 20
	var lvl20 = RosterSystem.compute_character_stats(id)
	_check("stats: hp grows with level",
		lvl20.get("max_hp", 0) >= lvl1.get("max_hp", 0),
		"lvl20 " + str(lvl20.get("max_hp")) + " vs lvl1 " + str(lvl1.get("max_hp")))

func test_power_value():
	_reset()
	var id = RosterSystem.create_character("class_warrior", "战")
	var power = RosterSystem.get_character_power(id)
	_check("power: positive", power > 0, "got " + str(power))

func test_add_companion():
	_reset()
	var active = RosterSystem.create_character("class_warrior", "主控")
	var ally1 = RosterSystem.create_character("class_mage", "队友1")
	RosterSystem.switch_character(active)  # 主控为操控角色

	var ok = PartySystem.add_companion(ally1)
	_check("party: add ok", ok, "")
	_check("party: count 1", PartySystem.companion_count() == 1, "")
	_check("party: is in party", PartySystem.is_in_party(ally1), "")

func test_cannot_add_active():
	_reset()
	var active = RosterSystem.create_character("class_warrior", "主控")
	RosterSystem.switch_character(active)
	var ok = PartySystem.add_companion(active)
	_check("party: reject active char", not ok, "")

func test_max_companions():
	_reset()
	var active = RosterSystem.create_character("class_warrior", "主控", false)
	RosterSystem.switch_character(active)
	# 创建超过上限的队友（set_active=false 避免覆盖 active）
	for i in range(PartySystem.MAX_COMPANIONS + 2):
		var cid = RosterSystem.create_character("class_ranger", "ally%d" % i, false)
		PartySystem.add_companion(cid)
	_check("party: capped at max",
		PartySystem.companion_count() == PartySystem.MAX_COMPANIONS,
		"got " + str(PartySystem.companion_count()))

func test_toggle():
	_reset()
	var active = RosterSystem.create_character("class_warrior", "主控")
	var ally = RosterSystem.create_character("class_mage", "队友")
	RosterSystem.switch_character(active)
	PartySystem.toggle_companion(ally)
	_check("toggle: added", PartySystem.is_in_party(ally), "")
	PartySystem.toggle_companion(ally)
	_check("toggle: removed", not PartySystem.is_in_party(ally), "")

func test_sanitize_removes_active():
	_reset()
	var a = RosterSystem.create_character("class_warrior", "A")
	var b = RosterSystem.create_character("class_mage", "B")
	RosterSystem.switch_character(a)
	PartySystem.add_companion(b)
	# 切换操控到 b，b 不应再是队友
	RosterSystem.switch_character(b)
	PartySystem.sanitize()
	_check("sanitize: active not companion", not PartySystem.is_in_party(b), "")

func test_get_companion_characters():
	_reset()
	var a = RosterSystem.create_character("class_warrior", "A")
	var b = RosterSystem.create_character("class_mage", "B队友")
	RosterSystem.switch_character(a)
	PartySystem.add_companion(b)
	var chars = PartySystem.get_companion_characters()
	_check("get: returns 1", chars.size() == 1, "got " + str(chars.size()))
	if chars.size() > 0:
		_check("get: correct char", chars[0].get("name", "") == "B队友", "")

func run_tests() -> Dictionary:
	print("\n=== PartySystem Tests ===")
	_passed = 0
	_failed = 0
	_failed_names.clear()

	test_compute_stats()
	test_stats_scale_with_level()
	test_power_value()
	test_add_companion()
	test_cannot_add_active()
	test_max_companions()
	test_toggle()
	test_sanitize_removes_active()
	test_get_companion_characters()

	print("=== PartySystem: %d passed, %d failed ===" % [_passed, _failed])
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
