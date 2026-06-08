extends Node

# Mock GameState autoload for testing
class MockGameState:
	var meta_bonuses = {}

	func get_meta_bonus(key: String) -> float:
		return meta_bonuses.get(key, 0.0)

	func set_meta_bonus(key: String, value: float):
		meta_bonuses[key] = value

# Mock EquipmentSystem autoload for testing
class MockEquipmentSystem:
	var total_stats = {}
	var combat_effects = {}

	func get_total_stats() -> Dictionary:
		return total_stats

	func get_combat_effects() -> Dictionary:
		return combat_effects

	func set_total_stats(stats: Dictionary):
		total_stats = stats

	func set_combat_effects(effects: Dictionary):
		combat_effects = effects

var player: CharacterBody2D
var mock_game_state: MockGameState
var mock_equipment_system: MockEquipmentSystem

func setup():
	# Create mock autoloads
	mock_game_state = MockGameState.new()
	mock_game_state.name = "GameState"
	add_child(mock_game_state)

	mock_equipment_system = MockEquipmentSystem.new()
	mock_equipment_system.name = "EquipmentSystem"
	add_child(mock_equipment_system)

	# Load and instantiate Player scene
	var player_script = load("res://src/scripts/Player.gd")
	player = CharacterBody2D.new()
	player.set_script(player_script)
	add_child(player)

	# Initialize player manually (skip _ready animations)
	player.base_max_hp = 100.0
	player.base_damage = 10.0
	player.base_attack_speed = 1.0
	player.base_move_speed = 300.0
	player.base_crit_chance = 0.05
	player.base_crit_damage = 1.5
	player.base_armor = 0.0

func teardown():
	if player:
		player.queue_free()
	if mock_equipment_system:
		mock_equipment_system.queue_free()
	if mock_game_state:
		mock_game_state.queue_free()

func test_recalculate_stats():
	setup()

	# Set equipment to provide +20 damage
	mock_equipment_system.set_total_stats({"damage": 20.0})

	# Recalculate stats
	player.recalculate_stats()

	# Verify damage = base + equipment
	assert(player.damage == 30.0, "Expected damage 30 (10 base + 20 equipment), got " + str(player.damage))

	teardown()
	print("[PASS] test_recalculate_stats")

func test_take_damage():
	setup()
	player.current_hp = 100.0
	player.max_hp = 100.0

	# Take 10 damage
	player.take_damage(10.0)

	# Verify hp decreased by 10
	assert(player.current_hp == 90.0, "Expected current_hp 90, got " + str(player.current_hp))

	teardown()
	print("[PASS] test_take_damage")

func test_take_damage_with_armor():
	setup()
	player.current_hp = 100.0
	player.max_hp = 100.0
	player.armor = 10.0

	# Note: Player.gd's take_damage() doesn't apply armor reduction
	# Armor is used by CombatSystem when calculating incoming damage
	# This test verifies the armor stat is set correctly
	assert(player.armor == 10.0, "Expected armor 10, got " + str(player.armor))

	# The actual damage reduction happens in CombatSystem, not in take_damage()
	# So take_damage(10) still reduces HP by 10
	player.take_damage(10.0)
	assert(player.current_hp == 90.0, "Expected current_hp 90, got " + str(player.current_hp))

	teardown()
	print("[PASS] test_take_damage_with_armor")

func test_gain_exp():
	setup()
	player.current_level = 1
	player.current_exp = 0.0
	player.exp_to_next_level = 10.0

	var level_up_triggered = false
	player.level_up.connect(func(_level): level_up_triggered = true)

	# Gain exactly enough exp to level up
	player.gain_exp(10.0)

	# Verify level increased
	assert(player.current_level == 2, "Expected level 2, got " + str(player.current_level))
	assert(level_up_triggered, "Expected level_up signal to be emitted")

	teardown()
	print("[PASS] test_gain_exp")

func test_level_up_stats():
	setup()
	player.current_level = 1
	player.base_max_hp = 100.0
	player.base_damage = 10.0
	player.current_exp = 0.0
	player.exp_to_next_level = 10.0

	var initial_base_hp = player.base_max_hp
	var initial_base_damage = player.base_damage

	# Trigger level up
	player.gain_exp(10.0)

	# Verify base stats increased (+8 hp, +2 damage per level)
	assert(player.base_max_hp == initial_base_hp + 8, "Expected base_max_hp " + str(initial_base_hp + 8) + ", got " + str(player.base_max_hp))
	assert(player.base_damage == initial_base_damage + 2, "Expected base_damage " + str(initial_base_damage + 2) + ", got " + str(player.base_damage))

	# Verify HP was restored to max
	assert(player.current_hp == player.max_hp, "Expected current_hp to equal max_hp after level up")

	teardown()
	print("[PASS] test_level_up_stats")

func test_get_meta_bonus_call():
	setup()

	# Set meta bonuses in mock GameState
	mock_game_state.set_meta_bonus("perm_damage", 5.0)
	mock_game_state.set_meta_bonus("perm_max_hp", 20.0)

	var initial_base_damage = player.base_damage
	var initial_base_hp = player.base_max_hp

	# Recalculate stats (should call GameState.get_meta_bonus)
	player.recalculate_stats()

	# Verify meta bonuses were applied to base stats
	assert(player.base_damage == initial_base_damage + 5.0, "Expected base_damage increased by 5, got " + str(player.base_damage))
	assert(player.base_max_hp == initial_base_hp + 20.0, "Expected base_max_hp increased by 20, got " + str(player.base_max_hp))

	teardown()
	print("[PASS] test_get_meta_bonus_call")

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

func _check(name: String, cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
		print("[PASS] " + name)
	else:
		_failed += 1
		_failed_names.append("player: " + name)
		print("[FAIL] " + name + ": " + msg)

func run_tests() -> Dictionary:
	print("\n=== Running Player Tests ===")
	_passed = 0
	_failed = 0
	_failed_names.clear()

	test_recalculate_stats()
	test_take_damage()
	test_take_damage_with_armor()
	test_gain_exp()
	test_level_up_stats()
	test_get_meta_bonus_call()

	print("=== Player: %d passed, %d failed ===\n" % [_passed, _failed])
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
