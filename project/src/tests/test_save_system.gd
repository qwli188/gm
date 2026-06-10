extends Node
## SaveSystem 单元测试 - 最小往返一致校验
## 测试: 写存档 -> 读存档 -> 关键字段保留(equipment_instances/backpack/warehouse/character)
## 注意: 使用槽位 3(避免覆盖玩家自己的存档),测试结束后清理

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []

const TEST_SLOT = 3

func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("save: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))

func _setup_test_state():
	# 清空 Inventory 并放入已知装备
	Inventory.backpack.clear()
	Inventory.warehouse.clear()
	# 生成 3 个实例: 2 进背包,1 进仓库
	var id1 = EquipmentSystem.roll_equipment("weapon_iron_sword", "common")
	var id2 = EquipmentSystem.roll_equipment("weapon_iron_sword", "rare")
	var id3 = EquipmentSystem.roll_equipment("weapon_iron_sword", "epic")
	Inventory.add_to_backpack(id1)
	Inventory.add_to_backpack(id2)
	Inventory.add_to_backpack(id3)
	Inventory.transfer_to_warehouse(id3)

	# GameState 已知数据
	GameState.total_gold = 1234
	GameState.add_material("rune_shard", 50)

	return [id1, id2, id3]

func _cleanup():
	SaveSystem.delete_save(TEST_SLOT)
	# 清空测试状态
	Inventory.backpack.clear()
	Inventory.warehouse.clear()

func test_save_then_load_inventory():
	var ids = _setup_test_state()

	var saved = SaveSystem.save_game(TEST_SLOT)
	_check("save: returns true", saved, "save_game 失败")

	# 故意改变内存状态（模拟新进程：实例池也清空）
	Inventory.backpack.clear()
	Inventory.warehouse.clear()
	EquipmentSystem.equipment_instances.clear()

	var loaded = SaveSystem.load_game(TEST_SLOT)
	_check("load: returns true", loaded, "load_game 失败")

	# 验证 backpack 恢复
	_check("load: backpack count = 2",
		Inventory.backpack.size() == 2,
		"got " + str(Inventory.backpack.size()))
	_check("load: warehouse count = 1",
		Inventory.warehouse.size() == 1,
		"got " + str(Inventory.warehouse.size()))

	# 验证 instance_id 一致(serialize/deserialize 不应丢失或改变 id)
	_check("load: id1 in backpack", ids[0] in Inventory.backpack, "")
	_check("load: id2 in backpack", ids[1] in Inventory.backpack, "")
	_check("load: id3 in warehouse", ids[2] in Inventory.warehouse, "")

	_cleanup()

func test_save_preserves_total_gold():
	GameState.total_gold = 9999
	SaveSystem.save_game(TEST_SLOT)
	GameState.total_gold = 0  # 故意改变
	SaveSystem.load_game(TEST_SLOT)
	_check("save: total_gold preserved",
		GameState.total_gold == 9999,
		"got " + str(GameState.total_gold))
	_cleanup()

func test_save_summary_readable():
	_setup_test_state()
	SaveSystem.save_game(TEST_SLOT)

	var slots = SaveSystem.get_save_slots()
	var test_summary = null
	for s in slots:
		if s.get("slot_id") == TEST_SLOT and s.get("exists"):
			test_summary = s
			break

	_check("summary: exists", test_summary != null, "")
	if test_summary != null:
		_check("summary: has class_id", test_summary.has("class_id"), "")
		_check("summary: has level", test_summary.has("level"), "")
		_check("summary: not corrupted",
			not test_summary.get("corrupted", false), "")
	_cleanup()

func test_delete_save():
	SaveSystem.save_game(TEST_SLOT)
	var deleted = SaveSystem.delete_save(TEST_SLOT)
	_check("delete: returns true", deleted, "")

	# 删除后 get_save_slots 应该报告 not exists
	var slots = SaveSystem.get_save_slots()
	for s in slots:
		if s.get("slot_id") == TEST_SLOT:
			_check("delete: slot reports not exists",
				not s.get("exists", true),
				"slot still reports exists")
			break

func run_tests() -> Dictionary:
	print("\n=== SaveSystem Tests ===")
	_passed = 0
	_failed = 0
	_failed_names.clear()

	test_save_then_load_inventory()
	test_save_preserves_total_gold()
	test_save_summary_readable()
	test_delete_save()

	print("=== SaveSystem: %d passed, %d failed ===" % [_passed, _failed])
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
