extends SceneTree
## 测试运行器 - 用 godot --headless -s res://tests/test_runner.gd 运行
## 加载所有测试套件，统一运行，输出汇总报告

const TEST_SCRIPTS = [
	"res://tests/test_equipment_system.gd",
	"res://tests/test_combat_system.gd",
	"res://tests/test_config_loader.gd",
	"res://tests/test_player.gd",
	"res://tests/test_inventory.gd",
	"res://tests/test_save_system.gd",
	"res://tests/test_roster_system.gd",
	"res://tests/test_territory_system.gd",
	"res://tests/test_party_system.gd",
	"res://tests/test_resident_system.gd",
	"res://tests/test_defense_system.gd",
	"res://tests/test_paragon_system.gd",
	"res://tests/test_workshop_upgrade.gd",
	"res://tests/test_endgame_system.gd",
	"res://tests/test_feedback_system.gd",
	"res://tests/test_p9_territory_quests.gd",
	"res://tests/test_p10_ux.gd",
	"res://tests/test_art_layer.gd"
]

func _initialize() -> void:
	# 等待一帧让 autoload 完成初始化
	await process_frame
	await process_frame

	print("\n=========== 测试运行器 ===========")
	var total_pass := 0
	var total_fail := 0
	var failed_tests: Array = []

	for script_path in TEST_SCRIPTS:
		if not ResourceLoader.exists(script_path):
			print("[跳过] 不存在: " + script_path)
			continue
		var script = load(script_path)
		var instance = Node.new()
		instance.set_script(script)
		root.add_child(instance)
		if instance.has_method("run_tests"):
			var result = instance.run_tests()
			if result is Dictionary:
				total_pass += result.get("pass", 0)
				total_fail += result.get("fail", 0)
				for f in result.get("failed_names", []):
					failed_tests.append(f)
		else:
			print("[警告] %s 缺少 run_tests()" % script_path)
		instance.queue_free()

	print("\n========== 测试汇总 ==========")
	print("✅ 通过: " + str(total_pass))
	print("❌ 失败: " + str(total_fail))
	if failed_tests.size() > 0:
		print("\n失败的测试:")
		for f in failed_tests:
			print("  • " + str(f))
	print("==============================\n")
	quit(1 if total_fail > 0 else 0)
