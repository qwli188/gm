extends Node
## Smoke test - Territory 场景基线验证
## 验证领地场景能正常启动、玩家能移动、建筑交互区能生成

var _passed := 0
var _failed := 0
var _failed_names := []


func run_tests():
	print("\n[Smoke] Territory 场景基线")
	test_territory_scene_loads()
	test_explorer_spawns()
	test_buildings_spawn()
	_report()
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}


func test_territory_scene_loads():
	var scene = load("res://scenes/Territory.tscn")
	if scene == null:
		_fail("Territory.tscn 加载失败")
		return
	var inst = scene.instantiate()
	if inst == null or not inst is Control:
		_fail("Territory 实例化失败或非 Control")
		return
	inst.free()
	_pass("Territory.tscn 加载成功")


func test_explorer_spawns():
	var script = load("res://scripts/ExplorerActor.gd")
	if script == null:
		_fail("ExplorerActor.gd 加载失败")
		return
	var explorer = script.new()
	if explorer == null or not explorer is CharacterBody2D:
		_fail("ExplorerActor 实例化失败")
		if explorer:
			explorer.free()
		return
	explorer.free()
	_pass("ExplorerActor 实例化成功")


func test_buildings_spawn():
	var zone_script = load("res://scripts/InteractZone.gd")
	if zone_script == null:
		_fail("InteractZone.gd 加载失败")
		return
	var zone = zone_script.new()
	if zone == null or not zone is Area2D:
		_fail("InteractZone 实例化失败")
		if zone:
			zone.free()
		return
	# 测试 setup 方法存在
	if not zone.has_method("setup"):
		_fail("InteractZone 缺少 setup 方法")
		zone.free()
		return
	zone.free()
	_pass("InteractZone 实例化成功")


func _pass(msg: String):
	_passed += 1
	print("  ✅ %s" % msg)


func _fail(msg: String):
	_failed += 1
	_failed_names.append("smoke_territory: " + msg)
	print("  ❌ %s" % msg)


func _report():
	print("  Total: %d | Passed: %d | Failed: %d" % [_passed + _failed, _passed, _failed])
