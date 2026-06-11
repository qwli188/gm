extends Node
## RosterSystem 单元测试 - 多角色名册 + 切换 + 旧档迁移

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

const TEST_SLOT = 3


func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("roster: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))


func _reset_roster():
	RosterSystem.characters.clear()
	RosterSystem.active_char_id = ""


func test_create_character():
	_reset_roster()
	var id = RosterSystem.create_character("class_warrior", "测试战士")
	_check("create: returns id", id != "", "")
	_check("create: count = 1", RosterSystem.character_count() == 1, "")
	_check("create: is active", RosterSystem.active_char_id == id, "")
	var c = RosterSystem.get_character(id)
	_check("create: name set", c.get("name", "") == "测试战士", "")
	_check("create: class set", c.get("class_id", "") == "class_warrior", "")
	_check("create: level 1", c.get("level", 0) == 1, "")
	# 起手武器应进 equipped
	_check("create: has starting weapon", not c.get("equipped", {}).is_empty(), "equipped empty")


func test_switch_character():
	_reset_roster()
	var id1 = RosterSystem.create_character("class_warrior", "战士")
	var id2 = RosterSystem.create_character("class_mage", "法师")
	# 创建第二个后应自动切到 id2
	_check("switch: active is id2 after create", RosterSystem.active_char_id == id2, "")

	# 给当前操控角色(法师)学个技能，切走再切回应保留
	SkillSystem.learned_skills = {"skill_fireball_active": 2}
	SkillSystem.skill_points_unspent = 5

	RosterSystem.switch_character(id1)
	_check("switch: active is id1", RosterSystem.active_char_id == id1, "")
	# 战士的技能应该是空的（独立）
	_check(
		"switch: warrior skills isolated",
		SkillSystem.learned_skills.is_empty(),
		"got " + str(SkillSystem.learned_skills)
	)

	# 切回法师，技能应恢复
	RosterSystem.switch_character(id2)
	_check(
		"switch: mage skills restored",
		SkillSystem.learned_skills.get("skill_fireball_active", 0) == 2,
		"got " + str(SkillSystem.learned_skills)
	)
	_check("switch: mage class applied", GameState.selected_class_id == "class_mage", "")


func test_delete_character():
	_reset_roster()
	var id1 = RosterSystem.create_character("class_warrior")
	var id2 = RosterSystem.create_character("class_mage")
	# 删非操控角色
	var ok = RosterSystem.delete_character(id1)
	_check("delete: returns true", ok, "")
	_check("delete: count = 1", RosterSystem.character_count() == 1, "")
	# 不能删最后一个
	var blocked = RosterSystem.delete_character(id2)
	_check("delete: blocks last", not blocked, "")
	_check("delete: still 1", RosterSystem.character_count() == 1, "")


func test_delete_active_switches():
	_reset_roster()
	var id1 = RosterSystem.create_character("class_warrior")
	var id2 = RosterSystem.create_character("class_mage")
	# 当前操控 id2，删它应自动切到 id1
	RosterSystem.delete_character(id2)
	_check(
		"delete active: switched to remaining",
		RosterSystem.active_char_id == id1,
		"got " + RosterSystem.active_char_id
	)


func test_max_characters():
	_reset_roster()
	for i in RosterSystem.MAX_CHARACTERS:
		RosterSystem.create_character("class_warrior")
	_check("max: at cap", RosterSystem.character_count() == RosterSystem.MAX_CHARACTERS, "")
	var overflow = RosterSystem.create_character("class_warrior")
	_check("max: rejects overflow", overflow == "", "")


func test_legacy_migration():
	_reset_roster()
	var legacy = {
		"class_id": "class_ranger",
		"level": 25,
		"current_exp": 123.0,
		"attributes": {"strength": 5, "agility": 10, "vitality": 3, "intelligence": 0},
		"attribute_points_unspent": 2,
		"equipped": {"weapon": "eq_inst_fake"},
		"learned_skills": {"skill_multishot_active": 3},
		"skill_points_unspent": 4,
	}
	RosterSystem.migrate_from_legacy(legacy)
	_check("migrate: count 1", RosterSystem.character_count() == 1, "")
	var c = RosterSystem.get_active_character()
	_check("migrate: class", c.get("class_id", "") == "class_ranger", "")
	_check("migrate: level", c.get("level", 0) == 25, "")
	_check("migrate: skills", c.get("learned_skills", {}).get("skill_multishot_active", 0) == 3, "")
	_check("migrate: attr points", c.get("attribute_points", 0) == 2, "")


func test_save_load_roster():
	_reset_roster()
	var id1 = RosterSystem.create_character("class_warrior", "存档战士")
	var id2 = RosterSystem.create_character("class_assassin", "存档刺客")
	RosterSystem.switch_character(id1)

	SaveSystem.save_game(TEST_SLOT)

	# 清空内存模拟新进程
	_reset_roster()
	SkillSystem.learned_skills = {}

	SaveSystem.load_game(TEST_SLOT)
	_check(
		"save/load: count 2",
		RosterSystem.character_count() == 2,
		"got " + str(RosterSystem.character_count())
	)
	_check(
		"save/load: active is warrior",
		RosterSystem.get_active_character().get("class_id", "") == "class_warrior",
		""
	)
	# 两个角色都在
	var classes = []
	for c in RosterSystem.characters:
		classes.append(c.get("class_id", ""))
	_check("save/load: has assassin", "class_assassin" in classes, "")

	SaveSystem.delete_save(TEST_SLOT)
	_reset_roster()


func run_tests() -> Dictionary:
	print("\n=== RosterSystem Tests ===")
	_passed = 0
	_failed = 0
	_failed_names.clear()

	test_create_character()
	test_switch_character()
	test_delete_character()
	test_delete_active_switches()
	test_max_characters()
	test_legacy_migration()
	test_save_load_roster()

	print("=== RosterSystem: %d passed, %d failed ===" % [_passed, _failed])
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
