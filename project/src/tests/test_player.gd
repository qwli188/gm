extends Node
## Player 单元测试 - PR-5 重构版
## 设计原则：只测能本地断言的逻辑（take_damage / gain_exp / attribute_points）
## 不依赖 mock 替换全局 autoload（GDScript 编译期符号无法被 add_child 替换）
## 旧的 mock 派测试已删除（test_recalculate_stats / test_get_meta_bonus_call）
## test_level_up_stats 期望 base_*+8/+2 是未实现的设计，已改为测当前实际行为（发 attribute_points）

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

var player: CharacterBody2D


func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("player: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))


func setup_player():
	# 构造一个最小可用的 player（不调 _ready 链，跳过 _apply_class 装备起手武器）
	player = CharacterBody2D.new()
	# 不 set_script，因为 _ready 会装备起手武器导致干扰
	# 改为只测 Player.gd 中可以纯函数化的逻辑
	# 但 take_damage / gain_exp / add_attribute 都是实例方法 → 必须 set_script
	# 折中：set_script 后 add_child 时 _ready 跑会失败（无 GameState 配置）
	# Player._apply_class 已经有 has_node 守护，会优雅跳过
	var script = load("res://scripts/Player.gd")
	player.set_script(script)
	add_child(player)

	# 强制设定基础属性（覆盖 _apply_class 可能的默认）
	player.base_max_hp = 100.0
	player.base_damage = 10.0
	player.base_attack_speed = 1.0
	player.base_move_speed = 300.0
	player.base_crit_chance = 0.05
	player.base_crit_damage = 1.5
	player.base_armor = 0.0
	player.current_hp = 100.0
	player.max_hp = 100.0
	player.current_level = 1
	player.current_exp = 0.0
	player.exp_to_next_level = 10.0
	player.attribute_points_unspent = 0
	player.attributes = {"strength": 0, "agility": 0, "vitality": 0, "intelligence": 0}


func teardown_player():
	if player:
		player.queue_free()
		player = null


func test_take_damage_basic():
	setup_player()
	player.take_damage(10.0)
	_check(
		"take_damage: hp decreased",
		player.current_hp == 90.0,
		"Expected 90, got " + str(player.current_hp)
	)
	teardown_player()


func test_take_damage_clamps_to_zero():
	setup_player()
	player.current_hp = 5.0
	player.take_damage(20.0)
	_check(
		"take_damage: clamped to 0 not negative",
		player.current_hp == 0.0,
		"Expected 0, got " + str(player.current_hp)
	)
	teardown_player()


func test_heal():
	setup_player()
	player.current_hp = 50.0
	player.heal(30.0)
	_check("heal: hp restored", player.current_hp == 80.0, str(player.current_hp))


func test_heal_clamps_to_max():
	setup_player()
	player.current_hp = 90.0
	player.max_hp = 100.0
	player.heal(50.0)
	_check(
		"heal: clamped to max",
		player.current_hp == 100.0,
		"Expected 100 cap, got " + str(player.current_hp)
	)
	teardown_player()


func test_gain_exp_levels_up():
	setup_player()
	var level_up_triggered = [false]
	player.level_up.connect(func(_level): level_up_triggered[0] = true)

	player.gain_exp(10.0)

	_check("gain_exp: level=2", player.current_level == 2, str(player.current_level))
	_check("gain_exp: signal emitted", level_up_triggered[0], "")
	teardown_player()


func test_level_up_grants_attribute_points():
	# 升级发放属性点（数量读 balance.json level_curve）
	setup_player()
	var curve = ConfigLoader.get_balance_config().get("level_curve", {})
	var expected_pts = int(curve.get("attribute_points_per_level", 5))
	var initial_pts = player.attribute_points_unspent
	player.gain_exp(10.0)
	_check(
		"level_up: attribute_points granted",
		player.attribute_points_unspent == initial_pts + expected_pts,
		"Expected +%d, got %d" % [expected_pts, player.attribute_points_unspent - initial_pts]
	)
	teardown_player()


func test_level_up_grows_base_stats():
	# PR-7: 升级带来基础属性成长（持久 ARPG）
	setup_player()
	var curve = ConfigLoader.get_balance_config().get("level_curve", {})
	var spl = curve.get("stats_per_level", {})
	var exp_hp = spl.get("max_hp", 0)
	var exp_dmg = spl.get("damage", 0)
	var init_hp = player.base_max_hp
	var init_dmg = player.base_damage
	player.gain_exp(10.0)
	_check(
		"level_up: base_max_hp grew",
		player.base_max_hp == init_hp + exp_hp,
		"Expected base_max_hp %d, got %d" % [init_hp + exp_hp, player.base_max_hp]
	)
	_check(
		"level_up: base_damage grew",
		player.base_damage == init_dmg + exp_dmg,
		"Expected base_damage %d, got %d" % [init_dmg + exp_dmg, player.base_damage]
	)
	teardown_player()


func test_level_up_restores_hp():
	setup_player()
	player.current_hp = 30.0
	player.gain_exp(10.0)
	_check(
		"level_up: hp restored to max",
		player.current_hp == player.max_hp,
		"Expected hp=max, got " + str(player.current_hp) + "/" + str(player.max_hp)
	)
	teardown_player()


func test_add_attribute_strength():
	setup_player()
	player.attribute_points_unspent = 5
	player.add_attribute("strength", 3)
	_check(
		"add_attribute: strength updated",
		player.attributes.get("strength", 0) == 3,
		str(player.attributes.get("strength"))
	)
	_check(
		"add_attribute: points consumed",
		player.attribute_points_unspent == 2,
		str(player.attribute_points_unspent)
	)
	teardown_player()


func test_add_attribute_insufficient_points():
	setup_player()
	player.attribute_points_unspent = 1
	player.add_attribute("strength", 5)
	# 应被拒绝（add_attribute 行 489 检查不足时 push_warning 并 return）
	_check(
		"add_attribute: rejects when insufficient",
		player.attributes.get("strength", 0) == 0,
		str(player.attributes.get("strength"))
	)
	teardown_player()


func test_get_stat():
	setup_player()
	player.armor = 25.0
	player.max_hp = 250.0
	player.damage = 50.0
	_check("get_stat: armor", player.get_stat("armor") == 25.0, "")
	_check("get_stat: max_hp", player.get_stat("max_hp") == 250.0, "")
	_check("get_stat: damage", player.get_stat("damage") == 50.0, "")
	_check("get_stat: unknown returns 0", player.get_stat("nonexistent") == 0.0, "")
	teardown_player()


func run_tests() -> Dictionary:
	print("\n=== Player Tests (PR-5 重构,不依赖 mock) ===")
	_passed = 0
	_failed = 0
	_failed_names.clear()

	test_take_damage_basic()
	test_take_damage_clamps_to_zero()
	test_heal()
	test_heal_clamps_to_max()
	test_gain_exp_levels_up()
	test_level_up_grants_attribute_points()
	test_level_up_grows_base_stats()
	test_level_up_restores_hp()
	test_add_attribute_strength()
	test_add_attribute_insufficient_points()
	test_get_stat()

	print("=== Player: %d passed, %d failed ===" % [_passed, _failed])
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
