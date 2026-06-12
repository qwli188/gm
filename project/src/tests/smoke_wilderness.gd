extends Node
## Smoke test - Wilderness 场景基线验证
## 验证野外场景能正常启动、事件点生成、传送门逻辑

var _passed := 0
var _failed := 0
var _failed_names := []


func run_tests():
	print("\n[Smoke] Wilderness 场景基线")
	test_wilderness_scene_loads()
	test_wilderness_system_layout()
	test_event_resolution()
	_report()
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}


func test_wilderness_scene_loads():
	var scene = load("res://scenes/Wilderness.tscn")
	if scene == null:
		_fail("Wilderness.tscn 加载失败")
		return
	var inst = scene.instantiate()
	if inst == null or not inst is Control:
		_fail("Wilderness 实例化失败或非 Control")
		return
	inst.free()
	_pass("Wilderness.tscn 加载成功")


func test_wilderness_system_layout():
	if not has_node("/root/WildernessSystem"):
		_fail("WildernessSystem autoload 未注册")
		return
	var ws = get_node("/root/WildernessSystem")
	# 用固定种子生成布局
	var layout = ws.generate_layout(12345)
	if layout.is_empty():
		_fail("WildernessSystem.generate_layout 返回空布局")
		return
	var portal_count = 0
	var event_count = 0
	for entry in layout:
		if entry.get("category", "") == "portal":
			portal_count += 1
		elif entry.get("category", "") == "event":
			event_count += 1
	if portal_count == 0:
		_fail("生成的布局没有传送门")
		return
	if event_count == 0:
		_fail("生成的布局没有事件点")
		return
	_pass("WildernessSystem.generate_layout 生成 %d 传送门 + %d 事件点" % [portal_count, event_count])


func test_event_resolution():
	if not has_node("/root/WildernessSystem"):
		_fail("WildernessSystem autoload 未注册")
		return
	var ws = get_node("/root/WildernessSystem")
	# 模拟采集事件（草药）
	var herb_def = {
		"id": "herb",
		"display_name": "草药丛",
		"reward": {"timber": [10, 20]},
	}
	var lines = ws.resolve_gather(herb_def)
	if lines.is_empty():
		_fail("resolve_gather 返回空结果")
		return
	_pass("resolve_gather 返回 %d 行结果" % lines.size())


func _pass(msg: String):
	_passed += 1
	print("  ✅ %s" % msg)


func _fail(msg: String):
	_failed += 1
	_failed_names.append("smoke_wilderness: " + msg)
	print("  ❌ %s" % msg)


func _report():
	print("  Total: %d | Passed: %d | Failed: %d" % [_passed + _failed, _passed, _failed])
