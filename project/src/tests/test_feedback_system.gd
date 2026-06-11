extends Node
## P8 反馈系统测试 - 拾取过滤/震动状态/累计字段

var _passed: int = 0
var _failed: int = 0
var _failed_names: Array = []


func _check(name: String, cond: bool, msg: String = "") -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		_failed_names.append("feedback: " + name)
		print("[FAIL] " + name + (": " + msg if msg != "" else ""))


func test_loot_filter_threshold():
	FeedbackSystem.set_loot_filter(FeedbackSystem.FILTER_RARE)
	_check("filter: common hidden", not FeedbackSystem.should_display_drop("common"), "")
	_check("filter: rare visible", FeedbackSystem.should_display_drop("rare"), "")
	_check("filter: legendary visible", FeedbackSystem.should_display_drop("legendary"), "")

	FeedbackSystem.set_loot_filter(FeedbackSystem.FILTER_LEGENDARY)
	_check("filter: rare hidden at L+", not FeedbackSystem.should_display_drop("rare"), "")
	_check("filter: epic hidden at L+", not FeedbackSystem.should_display_drop("epic"), "")
	_check("filter: legendary visible", FeedbackSystem.should_display_drop("legendary"), "")
	_check("filter: mythic visible", FeedbackSystem.should_display_drop("mythic"), "")

	FeedbackSystem.set_loot_filter(FeedbackSystem.FILTER_ALL)
	_check("filter: ALL shows common", FeedbackSystem.should_display_drop("common"), "")


func test_filter_clamp():
	FeedbackSystem.set_loot_filter(99)
	_check(
		"filter: clamps to MYTHIC",
		FeedbackSystem.loot_filter_threshold == FeedbackSystem.FILTER_MYTHIC,
		""
	)
	FeedbackSystem.set_loot_filter(-5)
	_check(
		"filter: clamps to ALL",
		FeedbackSystem.loot_filter_threshold == FeedbackSystem.FILTER_ALL,
		""
	)


func test_filter_label():
	FeedbackSystem.set_loot_filter(FeedbackSystem.FILTER_EPIC)
	_check(
		"filter: label has '史诗'",
		FeedbackSystem.filter_label().find("史诗") >= 0,
		"got " + FeedbackSystem.filter_label()
	)


func test_hitstop_idempotent():
	# 简单调用两次，不应崩溃；第二次会被忽略
	FeedbackSystem.hitstop(0.05)
	FeedbackSystem.hitstop(0.05)
	_check("hitstop: did not crash", true, "")
	# 复位
	Engine.time_scale = 1.0
	FeedbackSystem._hitstop_active = false


func test_shake_no_camera_silent():
	# 没相机时，不应崩溃
	FeedbackSystem.shake(10.0, 0.1)
	_check("shake: no-cam silent", true, "")


func test_should_display_drop_unknown():
	FeedbackSystem.set_loot_filter(FeedbackSystem.FILTER_RARE)
	# 未知 rarity 当作 0 处理（low）
	_check("filter: unknown treated as low", not FeedbackSystem.should_display_drop("garbage"), "")


func run_tests() -> Dictionary:
	test_loot_filter_threshold()
	test_filter_clamp()
	test_filter_label()
	test_hitstop_idempotent()
	test_shake_no_camera_silent()
	test_should_display_drop_unknown()

	print("\n--- 反馈系统测试 ---")
	print("✅ 通过: " + str(_passed))
	print("❌ 失败: " + str(_failed))
	return {"pass": _passed, "fail": _failed, "failed_names": _failed_names}
