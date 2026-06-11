extends Node
## test_acceptance.gd - DarkLoot v3 自动验收脚本（非 autoload）
## PR-5: 从 autoload 拆出（autoload 注册时会让正式启动 0.1s 后被 quit）
## 用法 1：独立运行 -s res://tests/test_acceptance.gd（自动 quit）
## 用法 2：作为子节点挂载到 test_runner，由它管理生命周期（不 quit）

var _errors: Array = []
var _warnings: Array = []
var _ran: bool = false


func _ready():
	if _ran:
		return
	_ran = true

	var sep = "============================================================"
	print(sep)
	print("  DarkLoot v3 自动验收")
	print(sep)

	_test_config_loading()
	_test_autoload_systems()
	_test_equipment_system()
	_test_combat_system()
	_print_report()

	# 仅独立调用时 quit（作为子节点挂载到 test_runner 时不退出）
	if get_parent() == get_tree().root:
		await get_tree().create_timer(0.1).timeout
		get_tree().quit(0 if _errors.is_empty() else 1)


func _test_config_loading():
	print("\n[TEST] 配置加载验收...")

	if not has_node("/root/ConfigLoader"):
		_errors.append("ConfigLoader autoload 未加载")
		return

	var cl = get_node("/root/ConfigLoader")

	var eq = cl.get_all_equipment()
	if eq.is_empty():
		_errors.append("equipment.json 为空或未加载")
	else:
		print("  [OK] 装备配置: %d 件" % eq.size())

	var aff = cl.get_all_affixes()
	if aff.is_empty():
		_errors.append("affixes.json 为空")
	else:
		print("  [OK] 词缀配置: %d 个" % aff.size())

	var sk = cl.get_all_skills()
	if sk.is_empty():
		_errors.append("skills.json 为空")
	else:
		print("  [OK] 技能配置: %d 个" % sk.size())

	var enemies = cl.enemies_data.get("enemies", [])
	if enemies.is_empty():
		_errors.append("enemies.json 为空")
	else:
		print("  [OK] 敌人配置: %d 个" % enemies.size())
		var boss_count = 0
		for e in enemies:
			if e.get("rank", "") == "boss":
				boss_count += 1
		if boss_count < 6:
			_warnings.append("Boss 数量不足6个(当前%d)" % boss_count)
		else:
			print("  [OK] Boss: %d 个" % boss_count)


func _test_autoload_systems():
	print("\n[TEST] Autoload 系统验收...")

	var required = [
		"ConfigLoader",
		"EquipmentSystem",
		"AffixSystem",
		"CombatSystem",
		"ActiveSkillSystem",
		"GameState",
		"AudioManager",
		"ClassMechanicSystem"
	]

	for name in required:
		if not has_node("/root/" + name):
			_errors.append("Autoload 缺失: " + name)
		else:
			print("  [OK] %s" % name)


func _test_equipment_system():
	print("\n[TEST] 装备系统验收...")

	if not has_node("/root/EquipmentSystem"):
		_errors.append("EquipmentSystem 不存在")
		return

	var es = get_node("/root/EquipmentSystem")

	var uuid = es.roll_equipment("weapon_iron_sword", "common")
	if uuid == "":
		_errors.append("装备实例生成失败")
		return

	print("  [OK] 装备实例生成: %s" % uuid)

	var item = es.get_equipment_instance_data(uuid)
	if item.is_empty():
		_errors.append("装备实例数据获取失败")
		return

	print("  [OK] 装备数据: %s (%s)" % [item.get("display_name", "?"), item.get("rarity", "?")])

	var combat_effects = es.get_combat_effects()
	print("  [OK] 词缀效果汇总: %d 条" % combat_effects.size())


func _test_combat_system():
	print("\n[TEST] 战斗系统验收...")

	if not has_node("/root/CombatSystem"):
		_errors.append("CombatSystem 不存在")
		return

	var cs = get_node("/root/CombatSystem")

	var stats = {"damage": 10, "crit_chance": 0.2, "crit_damage": 1.5}
	var result = cs.calculate_damage(stats, 0)

	if not result.has("damage") or not result.has("is_crit"):
		_errors.append("伤害计算返回格式错误")
		return

	print("  [OK] 伤害计算: %.1f (暴击=%s)" % [result.damage, result.is_crit])

	var methods = [
		"trigger_lifesteal",
		"trigger_ignite",
		"trigger_freeze",
		"trigger_affix_summon",
		"trigger_affix_chain"
	]
	for m in methods:
		if not cs.has_method(m):
			_errors.append("CombatSystem 缺失方法: " + m)
		else:
			print("  [OK] 方法: %s" % m)


func _print_report():
	var sep = "============================================================"
	print("\n" + sep)
	print("  验收报告")
	print(sep)

	if _errors.is_empty() and _warnings.is_empty():
		print("  [PASS] 全部通过")
	else:
		if not _errors.is_empty():
			print("\n  [FAIL] 错误 (%d):" % _errors.size())
			for e in _errors:
				print("    - %s" % e)

		if not _warnings.is_empty():
			print("\n  [WARN] 警告 (%d):" % _warnings.size())
			for w in _warnings:
				print("    - %s" % w)

	print("\n" + sep)
	print("  状态: %s" % ("PASS" if _errors.is_empty() else "FAIL"))
	print(sep)
