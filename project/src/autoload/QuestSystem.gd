extends Node
## QuestSystem - P9 居民悬赏任务
##
## 设计：
## - active_quests 是当前生效任务（最多 active_max 条），账号级（同名册共享）。
## - 任务进度由各系统在事件发生时调用 register_kill / register_drop / register_clear 推进。
## - 每出击 N 次自动刷新一批新任务（旧的不丢，仍可继续推进，直至完成或被替换）。
## - 完成后调用 claim_reward 领取，自动从 active_quests 移除。

signal quests_changed
signal quest_completed(quest_id: String)
signal quest_claimed(quest_id: String, rewards: Dictionary)

# 当前进行中任务 [{id, template_id, progress, target, rewards, type, ...}]
var active_quests: Array = []
# 已完成未领取 [{id, template_id, rewards}]
var completed_quests: Array = []
# 上次刷新对应的 sortie_count
var last_refresh_sortie: int = 0


func _ready():
	print("[QuestSystem] 任务系统初始化")


func _config() -> Dictionary:
	return ConfigLoader.territory_data.get("resident_quests", {})


func _templates() -> Array:
	return _config().get("templates", [])


func _max_active() -> int:
	return int(_config().get("active_max", 3))


# ============ 刷新 ============
func maybe_refresh(current_sortie: int) -> bool:
	var every = int(_config().get("refresh_every_n_sorties", 2))
	if every <= 0:
		return false
	if active_quests.size() >= _max_active():
		return false
	if current_sortie - last_refresh_sortie < every and not active_quests.is_empty():
		return false
	refresh_quests(current_sortie)
	return true


## 强制刷新一批任务到最大数量
func refresh_quests(current_sortie: int = 0):
	var templates = _templates()
	if templates.is_empty():
		return
	var slots_open = _max_active() - active_quests.size()
	for i in slots_open:
		var t = templates[randi() % templates.size()].duplicate(true)
		var quest = {
			"id": "quest_" + str(Time.get_ticks_msec()) + "_" + str(randi() % 10000),
			"template_id": t.get("id", ""),
			"display_name": t.get("display_name", "悬赏"),
			"type": t.get("type", "kill_tag"),
			"target": int(t.get("target_count", 1)),
			"progress": 0,
			"rewards": t.get("rewards", {}).duplicate(true),
		}
		# type 专属字段
		for k in ["tag", "rarity", "material_id"]:
			if t.has(k):
				quest[k] = t[k]
		active_quests.append(quest)
	last_refresh_sortie = current_sortie
	quests_changed.emit()
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()
	print("[QuestSystem] 刷新任务: %d 条" % active_quests.size())


# ============ 进度推进（由系统事件触发）============
func register_kill(enemy_data: Dictionary):
	var changed = false
	var tags = enemy_data.get("tags", [])
	var is_boss = enemy_data.get("rank", "normal") == "boss"
	for q in active_quests:
		if q.get("type", "") == "kill_tag":
			var need_tag = q.get("tag", "")
			if need_tag in tags:
				_inc_progress(q, 1)
				changed = true
		elif q.get("type", "") == "kill_boss" and is_boss:
			_inc_progress(q, 1)
			changed = true
	if changed:
		_check_completions()
		quests_changed.emit()


func register_drop(rarity: String):
	var changed = false
	for q in active_quests:
		if q.get("type", "") == "drop_rarity" and q.get("rarity", "") == rarity:
			_inc_progress(q, 1)
			changed = true
	if changed:
		_check_completions()
		quests_changed.emit()


func register_clear_dungeon(_dungeon_id: String):
	var changed = false
	for q in active_quests:
		if q.get("type", "") == "clear_dungeon":
			_inc_progress(q, 1)
			changed = true
	if changed:
		_check_completions()
		quests_changed.emit()


func register_collect(material_id: String, amount: int):
	var changed = false
	for q in active_quests:
		if q.get("type", "") == "collect_material" and q.get("material_id", "") == material_id:
			_inc_progress(q, amount)
			changed = true
	if changed:
		_check_completions()
		quests_changed.emit()


func _inc_progress(quest: Dictionary, delta: int):
	quest["progress"] = min(int(quest["progress"]) + delta, int(quest["target"]))


func _check_completions():
	var still_active: Array = []
	for q in active_quests:
		if int(q.get("progress", 0)) >= int(q.get("target", 1)):
			(
				completed_quests
				. append(
					{
						"id": q["id"],
						"template_id": q.get("template_id", ""),
						"display_name": q.get("display_name", ""),
						"rewards": q.get("rewards", {}).duplicate(true),
					}
				)
			)
			quest_completed.emit(q["id"])
		else:
			still_active.append(q)
	active_quests = still_active
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()


# ============ 领奖 ============
func claim_reward(quest_id: String) -> Dictionary:
	var idx = -1
	for i in completed_quests.size():
		if completed_quests[i].get("id", "") == quest_id:
			idx = i
			break
	if idx < 0:
		return {"ok": false, "reason": "未完成或不存在"}
	var q = completed_quests[idx]
	var rewards = q.get("rewards", {})
	for k in rewards:
		match k:
			"gold":
				GameState.total_gold += int(rewards[k])
			"talent_points":
				GameState.talent_points_unspent += int(rewards[k])
			"paragon_points":
				GameState.paragon_points_unspent += int(rewards[k])
			"exp_bonus":
				pass  # 仅在出击中有效，已生效则无操作
			_:
				GameState.add_material(k, int(rewards[k]))
	completed_quests.remove_at(idx)
	quest_claimed.emit(quest_id, rewards)
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()
	return {"ok": true, "rewards": rewards}


# ============ 序列化 ============
func serialize() -> Dictionary:
	return {
		"active_quests": active_quests.duplicate(true),
		"completed_quests": completed_quests.duplicate(true),
		"last_refresh_sortie": last_refresh_sortie,
	}


func deserialize(data: Dictionary):
	active_quests = data.get("active_quests", []).duplicate(true)
	completed_quests = data.get("completed_quests", []).duplicate(true)
	last_refresh_sortie = int(data.get("last_refresh_sortie", 0))
	quests_changed.emit()
	print("[QuestSystem] 加载: %d 进行 / %d 已完待领" % [active_quests.size(), completed_quests.size()])
