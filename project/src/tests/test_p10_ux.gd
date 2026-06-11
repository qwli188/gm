extends Node
## P10 UX 测试 - ItemCompare / Inventory.sort / BuildPresets

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("p10: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))


func _make_instance(slot: String, rarity: String, enhance: int = 0) -> String:
	var pool = ConfigLoader.get_all_equipment()
	for item in pool:
		if item.get("slot", "") == slot:
			var id = EquipmentSystem.roll_equipment(item.get("id", ""), rarity)
			if enhance > 0 and id != "":
				EquipmentSystem.equipment_instances[id]["enhancement_level"] = enhance
			return id
	return ""


func _reset():
	# 清空背包
	for id in Inventory.backpack.duplicate():
		Inventory.backpack.erase(id)
	# 清穿戴
	for slot in EquipmentSystem.SLOTS:
		EquipmentSystem.equipped_items[slot] = null
	# 清实例池中本测试创建的（实测不必，留着没影响）
	BuildPresets.presets.clear()


# ============ ItemCompare ============
func test_compare_to_empty_slot():
	_reset()
	var inst = _make_instance("weapon", "rare")
	# 当前 weapon 槽空 → 穿上后所有属性都是正向
	var diff = ItemCompare.compare_to_equipped(inst)
	_check("compare: returns dict", typeof(diff) == TYPE_DICTIONARY, "")
	_check(
		"compare: has damage delta", diff.has("damage") or diff.has("max_hp"), "got " + str(diff)
	)


func test_compare_two():
	_reset()
	var a = _make_instance("weapon", "common")
	var b = _make_instance("weapon", "epic", 8)  # 强化+8 保证 base_stats 必有差异（不依赖随机词缀）
	var diff = ItemCompare.compare_two(a, b)
	# epic+8 的 base_stats 经强化放大，必然在某维度 > common
	_check("compare_two: nontrivial diff", not diff.is_empty(), "got " + str(diff))


func test_format_richtext():
	var diff = {"damage": 5.0, "max_hp": -10.0}
	var s = ItemCompare.format_diff_richtext(diff)
	_check("compare: format has lime", s.find("lime") >= 0, s)
	_check("compare: format has red", s.find("red") >= 0, s)


# ============ Inventory.sort ============
func test_inventory_sort():
	_reset()
	# 加 5 件不同稀有度的装备到背包
	var w_common = _make_instance("weapon", "common")
	var w_legendary = _make_instance("weapon", "legendary")
	var h_rare = _make_instance("helmet", "rare")
	var w_epic = _make_instance("weapon", "epic", 5)
	var w_epic2 = _make_instance("weapon", "epic", 0)
	# 卸下到背包
	for id in [w_common, w_legendary, h_rare, w_epic, w_epic2]:
		# 这些是 roll 出来还没穿，直接加进背包
		Inventory.add_to_backpack(id)
	Inventory.sort_backpack()
	# 排序后第 0 应是 legendary
	_check("sort: first is legendary", Inventory.backpack[0] == w_legendary, "")
	# 后面两个 epic：强化高的在前
	var idx_e_high = Inventory.backpack.find(w_epic)
	var idx_e_low = Inventory.backpack.find(w_epic2)
	_check("sort: enhanced epic before bare epic", idx_e_high < idx_e_low, "")
	# 最后是 common
	_check(
		"sort: last is common", Inventory.backpack[Inventory.backpack.size() - 1] == w_common, ""
	)


func test_auto_dismantle_below():
	_reset()
	GameState.materials = {"rune_shard": 0}
	var c1 = _make_instance("weapon", "common")
	var c2 = _make_instance("helmet", "common")
	var r = _make_instance("weapon", "rare")
	Inventory.add_to_backpack(c1)
	Inventory.add_to_backpack(c2)
	Inventory.add_to_backpack(r)
	var result = Inventory.auto_dismantle_below("rare")
	_check("auto_dismantle: 2 commons sold", result["sold_count"] == 2, "got " + str(result))
	_check("auto_dismantle: shards gained", result["shards_gained"] >= 2, "got " + str(result))
	_check("auto_dismantle: rare kept", r in Inventory.backpack, "")


# ============ BuildPresets ============
func test_save_load_preset():
	_reset()
	# 准备一个角色
	if RosterSystem.character_count() == 0:
		RosterSystem.create_character("class_warrior", "测试战士", true)
	var char_id = RosterSystem.active_char_id
	# 穿一件武器
	var w = _make_instance("weapon", "epic")
	# 让它进背包再穿
	Inventory.add_to_backpack(w)
	EquipmentSystem.equip_from_backpack(w)
	# 保存预设 0
	var s = BuildPresets.save_preset(char_id, 0, "DPS")
	_check("preset: saved", s["ok"], s.get("reason", ""))
	# 卸下武器
	EquipmentSystem.unequip_item("weapon")
	_check("preset: weapon unequipped", EquipmentSystem.equipped_items["weapon"] == null, "")
	# 加载预设
	var l = BuildPresets.load_preset(char_id, 0)
	_check("preset: loaded", l["ok"], l.get("reason", ""))
	_check("preset: weapon back on", EquipmentSystem.equipped_items["weapon"] == w, "")


func test_preset_invalid_slot():
	var char_id = "char_dummy"
	var r = BuildPresets.save_preset(char_id, 99)
	_check("preset: invalid slot rejected", not r["ok"], "")
	var r2 = BuildPresets.load_preset(char_id, 0)
	_check("preset: load missing rejected", not r2["ok"], "")


func test_preset_delete():
	_reset()
	if RosterSystem.character_count() == 0:
		RosterSystem.create_character("class_warrior", "T2", true)
	var char_id = RosterSystem.active_char_id
	BuildPresets.save_preset(char_id, 1, "Tank")
	_check(
		"preset: saved at slot 1",
		BuildPresets.get_presets(char_id)[1].get("name", "") == "Tank",
		""
	)
	BuildPresets.delete_preset(char_id, 1)
	_check("preset: cleared", BuildPresets.get_presets(char_id)[1].is_empty(), "")


func run_tests() -> Dictionary:
	test_compare_to_empty_slot()
	test_compare_two()
	test_format_richtext()
	test_inventory_sort()
	test_auto_dismantle_below()
	test_save_load_preset()
	test_preset_invalid_slot()
	test_preset_delete()

	print("\n--- P10 UX 测试 ---")
	print("✅ 通过: " + str(_passed))
	print("❌ 失败: " + str(_failed))
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
