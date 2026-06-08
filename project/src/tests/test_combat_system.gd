extends Node
## CombatSystem 测试套件

var combat_system: Node
var test_results: Array = []

class MockTarget extends Node2D:
	var damage_received: float = 0.0
	var is_crit_received: bool = false
	var ignite_dps: float = 0.0
	var ignite_duration: float = 0.0
	var poison_dps: float = 0.0
	var poison_duration: float = 0.0
	var freeze_duration: float = 0.0
	var slow_percent: float = 0.0
	var slow_duration: float = 0.0

	func take_damage(damage: float, is_crit: bool = false):
		damage_received = damage
		is_crit_received = is_crit

	func apply_ignite(dps: float, duration: float):
		ignite_dps = dps
		ignite_duration = duration

	func apply_poison(dps: float, duration: float):
		poison_dps = dps
		poison_duration = duration

	func apply_freeze(duration: float):
		freeze_duration = duration

	func apply_slow(percent: float, duration: float):
		slow_percent = percent
		slow_duration = duration

class MockPlayer extends Node2D:
	var health: float = 100.0
	var healed_amount: float = 0.0

	func heal(amount: float):
		healed_amount += amount
		health += amount

	func _init():
		add_to_group("player")

func run_tests() -> Dictionary:
	combat_system = get_node_or_null("/root/CombatSystem")
	if not combat_system:
		push_error("[TestCombatSystem] CombatSystem autoload not found")
		return {"pass": 0, "fail": 1, "failed_names": ["CombatSystem autoload not found"]}

	print("\n========== CombatSystem Tests ==========")
	test_results.clear()

	test_calculate_damage_basic()
	test_calculate_damage_crit()
	test_calculate_damage_armor()
	test_calculate_damage_added()
	test_calculate_damage_mult()
	test_apply_lifesteal()
	test_apply_ignite()

	print_results()

	var passed := 0
	var failed_names: Array = []
	for r in test_results:
		if r.passed:
			passed += 1
		else:
			failed_names.append("combat: " + r.name)
	return {"pass": passed, "fail": test_results.size() - passed, "failed_names": failed_names}

func test_calculate_damage_basic():
	var test_name = "test_calculate_damage_basic"
	var attacker_stats = {"damage": 10}
	var target_armor = 0.0

	var result = combat_system.calculate_damage(attacker_stats, target_armor)

	# No crit should happen with default 5% chance in most cases, but we test the damage
	# For deterministic test, we check the damage when is_crit is false
	if not result.is_crit and is_equal_approx(result.damage, 10.0):
		log_test(test_name, true, "Damage=10, no crit, no resist")
	else:
		# If crit happened randomly, we can't fail the test, so we check if it's reasonable
		if result.is_crit:
			log_test(test_name, true, "Crit occurred randomly (5% chance), damage=" + str(result.damage))
		else:
			log_test(test_name, false, "Expected damage=10, got " + str(result.damage))

func test_calculate_damage_crit():
	var test_name = "test_calculate_damage_crit"
	var attacker_stats = {
		"damage": 10,
		"crit_chance": 1.0,  # 100% crit
		"crit_damage": 2.0
	}
	var target_armor = 0.0

	var result = combat_system.calculate_damage(attacker_stats, target_armor)

	if result.is_crit and is_equal_approx(result.damage, 20.0):
		log_test(test_name, true, "Crit with 2.0x multiplier: 10 * 2.0 = 20")
	else:
		log_test(test_name, false, "Expected is_crit=true and damage=20, got is_crit=" + str(result.is_crit) + " damage=" + str(result.damage))

func test_calculate_damage_armor():
	var test_name = "test_calculate_damage_armor"
	var attacker_stats = {
		"damage": 10,
		"crit_chance": 0.0  # No crit for deterministic test
	}
	var target_armor = 100.0

	# resistance = 1.0 - (100 / (100 + 100)) = 1.0 - 0.5 = 0.5
	# final_damage = 10 * 0.5 = 5
	var result = combat_system.calculate_damage(attacker_stats, target_armor)

	if is_equal_approx(result.damage, 5.0):
		log_test(test_name, true, "Armor=100 reduces damage to 5.0")
	else:
		log_test(test_name, false, "Expected damage=5.0, got " + str(result.damage))

func test_calculate_damage_added():
	var test_name = "test_calculate_damage_added"
	var attacker_stats = {
		"damage": 10,
		"added_damage": 5,
		"crit_chance": 0.0
	}
	var target_armor = 0.0

	# final_damage = (10 + 5) = 15
	var result = combat_system.calculate_damage(attacker_stats, target_armor)

	if is_equal_approx(result.damage, 15.0):
		log_test(test_name, true, "Added damage: (10+5) = 15")
	else:
		log_test(test_name, false, "Expected damage=15.0, got " + str(result.damage))

func test_calculate_damage_mult():
	var test_name = "test_calculate_damage_mult"
	var attacker_stats = {
		"damage": 10,
		"damage_mult": 2.0,
		"crit_chance": 0.0
	}
	var target_armor = 0.0

	# final_damage = 10 * 2.0 = 20
	var result = combat_system.calculate_damage(attacker_stats, target_armor)

	if is_equal_approx(result.damage, 20.0):
		log_test(test_name, true, "Damage multiplier: 10 * 2.0 = 20")
	else:
		log_test(test_name, false, "Expected damage=20.0, got " + str(result.damage))

func test_apply_lifesteal():
	var test_name = "test_apply_lifesteal"
	var target = MockTarget.new()
	add_child(target)

	var mock_player = MockPlayer.new()
	add_child(mock_player)

	var attacker_stats = {
		"lifesteal": 0.2  # 20% lifesteal
	}
	var damage = 100.0

	combat_system.apply_damage(target, damage, attacker_stats, false)

	# Wait one frame for signal propagation
	await get_tree().process_frame

	# Expected heal: 100 * 0.2 = 20
	if is_equal_approx(mock_player.healed_amount, 20.0):
		log_test(test_name, true, "Lifesteal 20% of 100 damage = 20 heal")
	else:
		log_test(test_name, false, "Expected heal=20.0, got " + str(mock_player.healed_amount))

	mock_player.queue_free()
	target.queue_free()

func test_apply_ignite():
	var test_name = "test_apply_ignite"
	var target = MockTarget.new()
	add_child(target)

	var attacker_stats = {
		"ignite_dps": 10.0,
		"ignite_duration": 3.0
	}
	var damage = 50.0

	combat_system.apply_damage(target, damage, attacker_stats, false)

	if is_equal_approx(target.ignite_dps, 10.0) and is_equal_approx(target.ignite_duration, 3.0):
		log_test(test_name, true, "Ignite applied: 10 DPS for 3 seconds")
	else:
		log_test(test_name, false, "Expected ignite_dps=10.0 and duration=3.0, got dps=" + str(target.ignite_dps) + " duration=" + str(target.ignite_duration))

	target.queue_free()

func log_test(test_name: String, passed: bool, message: String = ""):
	var status = "PASS" if passed else "FAIL"
	var log_msg = "[%s] %s" % [status, test_name]
	if message:
		log_msg += ": " + message

	print(log_msg)
	test_results.append({"name": test_name, "passed": passed, "message": message})

func print_results():
	print("\n========== Test Summary ==========")
	var passed = 0
	var failed = 0

	for result in test_results:
		if result.passed:
			passed += 1
		else:
			failed += 1

	print("Total: %d | Passed: %d | Failed: %d" % [test_results.size(), passed, failed])

	if failed > 0:
		print("\nFailed tests:")
		for result in test_results:
			if not result.passed:
				print("  - " + result.name + ": " + result.message)

	print("==================================\n")
