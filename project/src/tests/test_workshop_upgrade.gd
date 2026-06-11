extends Node
## P6 装备工坊扩展测试 - 升品/神圣化

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("workshop+: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))


func _reset_resources():
	GameState.total_gold = 999999
	GameState.materials = {"rune_shard": 9999, "void_fragment": 999, "bone_dust": 999}


func _make_instance(slot: String, rarity: String) -> String:
	# 找该 slot 的任一模板
	var pool = ConfigLoader.get_all_equipment()
	for item in pool:
		if item.get("slot", "") == slot:
			return EquipmentSystem.roll_equipment(item.get("id", ""), rarity)
	return ""


func test_can_upgrade():
	_reset_resources()
	var inst = _make_instance("weapon", "common")
	_check("setup: instance created", inst != "", "")
	var r = AffixWorkshop.can_upgrade(inst)
	_check("can_upgrade: common -> ok", r["ok"], r.get("reason", ""))
	_check("can_upgrade: tier present", r.has("tier"), "")
	# legendary 之后 mythic 是终点；mythic 装备应被拒（已最高）
	var top = _make_instance("weapon", "mythic")
	var r2 = AffixWorkshop.can_upgrade(top)
	_check("can_upgrade: mythic blocked", not r2["ok"], "")


func test_upgrade_consumes_fodder():
	_reset_resources()
	var target = _make_instance("weapon", "common")
	# 准备 3 件同 slot 同 rarity 的饲料
	var f1 = _make_instance("weapon", "common")
	var f2 = _make_instance("weapon", "common")
	var f3 = _make_instance("weapon", "common")
	var before_cnt = EquipmentSystem.equipment_instances.size()
	var r = AffixWorkshop.upgrade_equipment(target, [f1, f2, f3])
	_check("upgrade: success", r.get("success", false), r.get("message", ""))
	_check(
		"upgrade: rarity raised",
		EquipmentSystem.equipment_instances[target].get("rarity", "") == "rare",
		""
	)
	# 饲料被销毁
	_check("upgrade: fodder destroyed", not EquipmentSystem.equipment_instances.has(f1), "")
	_check(
		"upgrade: total decreased", EquipmentSystem.equipment_instances.size() == before_cnt - 3, ""
	)


func test_upgrade_rejects_wrong_fodder():
	_reset_resources()
	var target = _make_instance("weapon", "common")
	# 错配：稀有度不同
	var bad = _make_instance("weapon", "rare")
	var f2 = _make_instance("weapon", "common")
	var f3 = _make_instance("weapon", "common")
	var r = AffixWorkshop.upgrade_equipment(target, [bad, f2, f3])
	_check("upgrade: wrong rarity rejected", not r.get("success", true), "")

	# 错配：部位不同
	var target2 = _make_instance("weapon", "common")
	var helm = _make_instance("helmet", "common")
	var w2 = _make_instance("weapon", "common")
	var w3 = _make_instance("weapon", "common")
	var r2 = AffixWorkshop.upgrade_equipment(target2, [helm, w2, w3])
	_check("upgrade: wrong slot rejected", not r2.get("success", true), "")


func test_sanctify_grants_next_success():
	_reset_resources()
	var inst = _make_instance("weapon", "rare")
	# 先把强化推到 +5（必成区间），再做神圣化
	for i in 5:
		AffixWorkshop.enhance_equipment(inst)
	var lvl_before = EquipmentSystem.equipment_instances[inst].get("enhancement_level", 0)
	_check("sanctify: prep level 5", lvl_before == 5, "got " + str(lvl_before))
	var s = AffixWorkshop.sanctify_equipment(inst)
	_check("sanctify: success", s.get("success", false), s.get("message", ""))
	_check("sanctify: flag set", AffixWorkshop.is_sanctified(inst), "")
	# 强化必成（落在 +5→+6 段，原本 0.7 概率，现在保证 100%）
	# 跑 5 次保险，神圣化只对第一次生效
	var r = AffixWorkshop.enhance_equipment(inst)
	_check("sanctify: enhance succeeded", r.get("success", false), r.get("message", ""))
	_check("sanctify: flag cleared", not AffixWorkshop.is_sanctified(inst), "")


func test_sanctify_dup_rejected():
	_reset_resources()
	var inst = _make_instance("weapon", "common")
	AffixWorkshop.sanctify_equipment(inst)
	var r = AffixWorkshop.sanctify_equipment(inst)
	_check("sanctify: dup rejected", not r.get("success", true), "")


func run_tests() -> Dictionary:
	test_can_upgrade()
	test_upgrade_consumes_fodder()
	test_upgrade_rejects_wrong_fodder()
	test_sanctify_grants_next_success()
	test_sanctify_dup_rejected()

	print("\n--- 装备工坊扩展测试 ---")
	print("✅ 通过: " + str(_passed))
	print("❌ 失败: " + str(_failed))
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
