extends Node
## 成就系统 - 追踪长期目标，给玩家成就感
## 监听事件：首杀 Boss / 通关试炼塔层数 / 收集套装 / 巅峰等级达标

var unlocked: Array = []  # 已解锁成就 id 列表
var progress: Dictionary = {}  # 进度追踪 {achievement_id: current_value}

func _ready():
	print("[AchievementSystem] 成就系统初始化")

func get_all_achievements() -> Array:
	if has_node("/root/ConfigLoader"):
		var cfg = get_node("/root/ConfigLoader").config
		return cfg.get("achievements", [])
	return []

## 检查单个成就是否解锁
func is_unlocked(ach_id: String) -> bool:
	return ach_id in unlocked

## 获取成就进度（0-100%）
func get_progress(ach_id: String) -> float:
	var ach = _get_achievement(ach_id)
	if not ach:
		return 0.0
	var goal = ach.get("goal", 1)
	var cur = progress.get(ach_id, 0)
	return clampf(float(cur) / goal, 0.0, 1.0)

## 注册事件（由游戏其他系统调用）
func register_boss_kill(boss_id: String):
	_inc_achievement("ach_boss_first_kill_%s" % boss_id, 1)
	_inc_achievement("ach_boss_kill_count", 1)

func register_trial_floor(floor: int):
	_set_achievement("ach_trial_tower_floor", floor)

func register_set_collected(set_id: String):
	_inc_achievement("ach_collect_all_sets", 1)

func register_paragon_level(level: int):
	_set_achievement("ach_paragon_level", level)

func register_dungeon_clear(dungeon_id: String, difficulty: int):
	if difficulty >= 3:
		_inc_achievement("ach_clear_all_hard", 1)

## 内部：增量进度
func _inc_achievement(ach_id: String, delta: int):
	var cur = progress.get(ach_id, 0)
	progress[ach_id] = cur + delta
	_check_unlock(ach_id)

## 内部：设置进度（取最大值）
func _set_achievement(ach_id: String, value: int):
	var cur = progress.get(ach_id, 0)
	if value > cur:
		progress[ach_id] = value
		_check_unlock(ach_id)

## 检查是否达成解锁
func _check_unlock(ach_id: String):
	if ach_id in unlocked:
		return
	var ach = _get_achievement(ach_id)
	if not ach:
		return
	var goal = ach.get("goal", 1)
	var cur = progress.get(ach_id, 0)
	if cur >= goal:
		unlocked.append(ach_id)
		_show_unlock_toast(ach)
		print("[AchievementSystem] 成就解锁: %s" % ach.get("display_name", ach_id))

func _show_unlock_toast(ach: Dictionary):
	# TODO: 显示解锁提示 UI（浮窗 + 音效）
	pass

func _get_achievement(ach_id: String) -> Dictionary:
	for a in get_all_achievements():
		if a.get("id") == ach_id:
			return a
	return {}

func serialize() -> Dictionary:
	return {"unlocked": unlocked, "progress": progress}

func deserialize(data: Dictionary):
	unlocked = data.get("unlocked", [])
	progress = data.get("progress", {})
