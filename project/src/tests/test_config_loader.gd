extends Node
## ConfigLoader 单元测试
## 验证配置加载、查询、热重载、异常处理

var config_loader: Node
var test_results: Array = []


## 运行所有测试
func run_tests() -> Dictionary:
	print("\n=== ConfigLoader 单元测试开始 ===\n")
	test_results.clear()

	# 获取 ConfigLoader 实例
	config_loader = get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		print("❌ 错误: 无法获取 ConfigLoader autoload")
		return {"pass": 0, "fail": 1, "failed_names": ["ConfigLoader autoload not found"]}

	# 执行测试用例
	test_load_all_configs()
	test_get_equipment_by_id()
	test_get_affix_by_id()
	test_get_skill_by_id()
	test_get_enemy_by_id()
	test_reload_config()
	test_invalid_path_safety()

	# 输出测试总结并返回汇总（供 test_runner 聚合）
	return print_summary()


## 测试1: 启动后所有配置数据非空
func test_load_all_configs():
	var test_name = "test_load_all_configs"
	print("▶ " + test_name)

	var passed = true
	var failures = []

	# 检查所有 *_data 字典
	if config_loader.equipment_data.is_empty():
		failures.append("equipment_data 为空")
		passed = false

	if config_loader.affixes_data.is_empty():
		failures.append("affixes_data 为空")
		passed = false

	if config_loader.skills_data.is_empty():
		failures.append("skills_data 为空")
		passed = false

	if config_loader.enemies_data.is_empty():
		failures.append("enemies_data 为空")
		passed = false

	if config_loader.balance_data.is_empty():
		failures.append("balance_data 为空")
		passed = false

	if config_loader.dungeons_data.is_empty():
		failures.append("dungeons_data 为空")
		passed = false

	if config_loader.classes_data.is_empty():
		failures.append("classes_data 为空")
		passed = false

	if config_loader.sets_data.is_empty():
		failures.append("sets_data 为空")
		passed = false

	log_result(test_name, passed, failures)


## 测试2: 根据ID查找装备
func test_get_equipment_by_id():
	var test_name = "test_get_equipment_by_id"
	print("▶ " + test_name)

	var passed = true
	var failures = []

	# 获取第一个装备ID用于测试
	var all_equipment = config_loader.get_all_equipment()
	if all_equipment.size() > 0:
		var test_id = all_equipment[0].get("id", "")
		var result = config_loader.get_equipment_by_id(test_id)

		if result.is_empty():
			failures.append("查找已存在的装备ID返回空字典: " + test_id)
			passed = false
		elif result.get("id", "") != test_id:
			failures.append("返回的装备ID不匹配")
			passed = false
	else:
		failures.append("equipment_data 中没有装备数据")
		passed = false

	# 测试不存在的ID
	var invalid_result = config_loader.get_equipment_by_id("non_existent_id_12345")
	if not invalid_result.is_empty():
		failures.append("查找不存在的ID应返回空字典")
		passed = false

	log_result(test_name, passed, failures)


## 测试3: 根据ID查找词缀
func test_get_affix_by_id():
	var test_name = "test_get_affix_by_id"
	print("▶ " + test_name)

	var passed = true
	var failures = []

	# 获取第一个词缀ID用于测试
	var all_affixes = config_loader.get_all_affixes()
	if all_affixes.size() > 0:
		var test_id = all_affixes[0].get("id", "")
		var result = config_loader.get_affix_by_id(test_id)

		if result.is_empty():
			failures.append("查找已存在的词缀ID返回空字典: " + test_id)
			passed = false
		elif result.get("id", "") != test_id:
			failures.append("返回的词缀ID不匹配")
			passed = false
	else:
		failures.append("affixes_data 中没有词缀数据")
		passed = false

	# 测试不存在的ID
	var invalid_result = config_loader.get_affix_by_id("non_existent_affix_99999")
	if not invalid_result.is_empty():
		failures.append("查找不存在的ID应返回空字典")
		passed = false

	log_result(test_name, passed, failures)


## 测试4: 根据ID查找技能
func test_get_skill_by_id():
	var test_name = "test_get_skill_by_id"
	print("▶ " + test_name)

	var passed = true
	var failures = []

	# 获取第一个技能ID用于测试
	var all_skills = config_loader.skills_data.get("skills", [])
	if all_skills.size() > 0:
		var test_id = all_skills[0].get("id", "")
		var result = config_loader.get_skill_by_id(test_id)

		if result.is_empty():
			failures.append("查找已存在的技能ID返回空字典: " + test_id)
			passed = false
		elif result.get("id", "") != test_id:
			failures.append("返回的技能ID不匹配")
			passed = false
	else:
		failures.append("skills_data 中没有技能数据")
		passed = false

	# 测试不存在的ID
	var invalid_result = config_loader.get_skill_by_id("skill_not_found_xyz")
	if not invalid_result.is_empty():
		failures.append("查找不存在的ID应返回空字典")
		passed = false

	log_result(test_name, passed, failures)


## 测试5: 根据ID查找敌人
func test_get_enemy_by_id():
	var test_name = "test_get_enemy_by_id"
	print("▶ " + test_name)

	var passed = true
	var failures = []

	# 获取第一个敌人ID用于测试
	var all_enemies = config_loader.enemies_data.get("enemies", [])
	if all_enemies.size() > 0:
		var test_id = all_enemies[0].get("id", "")
		var result = config_loader.get_enemy_by_id(test_id)

		if result.is_empty():
			failures.append("查找已存在的敌人ID返回空字典: " + test_id)
			passed = false
		elif result.get("id", "") != test_id:
			failures.append("返回的敌人ID不匹配")
			passed = false
	else:
		failures.append("enemies_data 中没有敌人数据")
		passed = false

	# 测试不存在的ID
	var invalid_result = config_loader.get_enemy_by_id("enemy_invalid_000")
	if not invalid_result.is_empty():
		failures.append("查找不存在的ID应返回空字典")
		passed = false

	log_result(test_name, passed, failures)


## 测试6: 热重载配置
func test_reload_config():
	var test_name = "test_reload_config"
	print("▶ " + test_name)

	var passed = true
	var failures = []
	var signal_received = false

	# 连接信号
	var signal_handler = func(file_name: String):
		if file_name == "equipment.json":
			signal_received = true

	config_loader.config_reloaded.connect(signal_handler)

	# 保存当前数据指纹
	var old_data_str = JSON.stringify(config_loader.equipment_data)

	# 执行热重载
	var result = config_loader.reload_config("equipment.json")

	if not result:
		failures.append("reload_config 返回 false")
		passed = false

	# 等待信号（简单检查：信号应该立即发出）
	await get_tree().create_timer(0.1).timeout

	if not signal_received:
		failures.append("未收到 config_reloaded 信号")
		passed = false

	# 验证数据已重新加载（内容应该相同，但对象引用可能不同）
	var new_data_str = JSON.stringify(config_loader.equipment_data)
	if old_data_str != new_data_str:
		# 数据不同不一定是错误，但如果为空则是问题
		if config_loader.equipment_data.is_empty():
			failures.append("重载后 equipment_data 变为空")
			passed = false

	config_loader.config_reloaded.disconnect(signal_handler)
	log_result(test_name, passed, failures)


## 测试7: 无效路径安全性
func test_invalid_path_safety():
	var test_name = "test_invalid_path_safety"
	print("▶ " + test_name)

	var passed = true
	var failures = []

	# 测试不存在的文件
	var result = config_loader.reload_config("不存在的配置文件.json")

	if result:
		failures.append("reload_config 对不存在的文件应返回 false")
		passed = false

	# 确保程序没有崩溃（能执行到这里就说明没崩）
	if not is_instance_valid(config_loader):
		failures.append("ConfigLoader 实例失效（可能崩溃）")
		passed = false

	log_result(test_name, passed, failures)


## 记录测试结果
func log_result(test_name: String, passed: bool, failures: Array):
	test_results.append({"name": test_name, "passed": passed, "failures": failures})

	if passed:
		print("  ✅ PASS")
	else:
		print("  ❌ FAIL")
		for failure in failures:
			print("    - " + failure)
	print("")


## 打印测试总结，并返回 {pass, fail, failed_names} 供 test_runner 聚合
func print_summary() -> Dictionary:
	print("=== 测试总结 ===")
	var total = test_results.size()
	var passed = 0
	var failed_names: Array = []

	for result in test_results:
		if result.passed:
			passed += 1
		else:
			failed_names.append(result.name)

	var failed = total - passed
	print("总计: %d | 通过: %d | 失败: %d" % [total, passed, failed])

	if failed == 0:
		print("🎉 所有测试通过!")
	else:
		print("⚠ 部分测试失败，请检查上方详情")

	print("\n=== ConfigLoader 单元测试结束 ===\n")
	return {"pass": passed, "fail": failed, "failed_names": failed_names}
