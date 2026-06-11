extends Node
## Inventory 单元测试 - 验证 PR-3 拆分后的容器逻辑
## 测试: 容量上限 / 转移 / 销毁拒绝穿戴中 / 序列化往返

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("inventory: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))


func _setup_clean():
	# 清空背包/仓库以保证测试独立
	Inventory.backpack.clear()
	Inventory.warehouse.clear()
	# 清空装备实例池里测试期间可能残留的实例(只清测试相关)
	for id in Inventory.backpack + Inventory.warehouse:
		EquipmentSystem.equipment_instances.erase(id)


func _make_test_instance() -> String:
	# 用真实模板生成一个实例(铁剑是 common 武器,稳定存在)
	return EquipmentSystem.roll_equipment("weapon_iron_sword", "common")


func test_add_to_backpack_basic():
	_setup_clean()
	var id = _make_test_instance()
	_check("add_to_backpack: returns true on empty", Inventory.add_to_backpack(id), "")
	_check(
		"add_to_backpack: backpack size = 1",
		Inventory.backpack.size() == 1,
		str(Inventory.backpack.size())
	)
	_check("add_to_backpack: contains id", id in Inventory.backpack, "")


func test_backpack_full_rejects():
	_setup_clean()
	# 填满 40 格
	for i in Inventory.MAX_BACKPACK_SIZE:
		var id = _make_test_instance()
		Inventory.add_to_backpack(id)
	_check(
		"backpack full: size = MAX", Inventory.backpack.size() == Inventory.MAX_BACKPACK_SIZE, ""
	)
	_check("backpack full: is_backpack_full true", Inventory.is_backpack_full(), "")
	# 再加一件应失败
	var extra = _make_test_instance()
	_check("backpack full: add returns false", not Inventory.add_to_backpack(extra), "")
	_check(
		"backpack full: size unchanged",
		Inventory.backpack.size() == Inventory.MAX_BACKPACK_SIZE,
		""
	)


func test_transfer_to_warehouse():
	_setup_clean()
	var id = _make_test_instance()
	Inventory.add_to_backpack(id)
	_check("transfer: success", Inventory.transfer_to_warehouse(id), "")
	_check("transfer: not in backpack", not (id in Inventory.backpack), "")
	_check("transfer: in warehouse", id in Inventory.warehouse, "")


func test_transfer_back():
	_setup_clean()
	var id = _make_test_instance()
	Inventory.add_to_backpack(id)
	Inventory.transfer_to_warehouse(id)
	_check("transfer_back: success", Inventory.transfer_to_backpack(id), "")
	_check("transfer_back: in backpack", id in Inventory.backpack, "")
	_check("transfer_back: not in warehouse", not (id in Inventory.warehouse), "")


func test_destroy_basic():
	_setup_clean()
	var id = _make_test_instance()
	Inventory.add_to_backpack(id)
	_check("destroy: returns true", Inventory.destroy_equipment(id), "")
	_check("destroy: not in backpack", not (id in Inventory.backpack), "")
	_check("destroy: instance pool clean", not EquipmentSystem.equipment_instances.has(id), "")


func test_destroy_rejects_equipped():
	_setup_clean()
	var id = _make_test_instance()
	# 直接装备到武器槽(假设职业有 starting_weapon 已占位,我们 unequip 先)
	# 简化:卸下武器,用我们的实例占位
	var orig_weapon = EquipmentSystem.equipped_items.get("weapon")
	EquipmentSystem.equipped_items["weapon"] = id
	_check("destroy_equipped: returns false", not Inventory.destroy_equipment(id), "")
	_check("destroy_equipped: instance preserved", EquipmentSystem.equipment_instances.has(id), "")
	# 恢复
	EquipmentSystem.equipped_items["weapon"] = orig_weapon


func test_serialize_roundtrip():
	_setup_clean()
	var id1 = _make_test_instance()
	var id2 = _make_test_instance()
	var id3 = _make_test_instance()
	Inventory.add_to_backpack(id1)
	Inventory.add_to_backpack(id2)
	Inventory.transfer_to_warehouse(id2)
	Inventory.add_to_backpack(id3)

	var data = Inventory.serialize()
	_check("serialize: backpack count", data.backpack.size() == 2, str(data.backpack.size()))
	_check("serialize: warehouse count", data.warehouse.size() == 1, str(data.warehouse.size()))

	# 清空再恢复
	Inventory.backpack.clear()
	Inventory.warehouse.clear()
	Inventory.deserialize(data)
	_check("deserialize: backpack restored", Inventory.backpack.size() == 2, "")
	_check("deserialize: warehouse restored", Inventory.warehouse.size() == 1, "")


func test_deserialize_filters_invalid():
	_setup_clean()
	var fake_data = {
		"backpack": ["nonexistent_id_1", "nonexistent_id_2"],
		"warehouse": ["nonexistent_id_3"],
	}
	Inventory.deserialize(fake_data)
	_check(
		"deserialize: invalid filtered from backpack",
		Inventory.backpack.size() == 0,
		str(Inventory.backpack.size())
	)
	_check(
		"deserialize: invalid filtered from warehouse",
		Inventory.warehouse.size() == 0,
		str(Inventory.warehouse.size())
	)


func test_equip_from_backpack():
	_setup_clean()
	var id = _make_test_instance()
	Inventory.add_to_backpack(id)
	var orig_size = Inventory.backpack.size()
	var orig_weapon = EquipmentSystem.equipped_items.get("weapon")

	_check("equip_from_backpack: returns true", EquipmentSystem.equip_from_backpack(id), "")
	_check("equip_from_backpack: removed from backpack", not (id in Inventory.backpack), "")
	_check(
		"equip_from_backpack: now equipped", EquipmentSystem.equipped_items.get("weapon") == id, ""
	)
	# 若原槽位有装备应回到背包(背包总数不变)
	if orig_weapon != null:
		_check(
			"equip_from_backpack: old weapon back to backpack",
			orig_weapon in Inventory.backpack,
			""
		)

	# 恢复
	EquipmentSystem.equipped_items["weapon"] = orig_weapon
	Inventory.backpack.erase(id)
	Inventory.backpack.erase(orig_weapon)


func run_tests() -> Dictionary:
	print("\n=== Inventory Tests ===")
	_passed = 0
	_failed = 0
	_failed_names.clear()

	test_add_to_backpack_basic()
	test_backpack_full_rejects()
	test_transfer_to_warehouse()
	test_transfer_back()
	test_destroy_basic()
	test_destroy_rejects_equipped()
	test_serialize_roundtrip()
	test_deserialize_filters_invalid()
	test_equip_from_backpack()

	print("=== Inventory: %d passed, %d failed ===" % [_passed, _failed])
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
