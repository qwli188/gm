extends Node
## EndgameSystem - 末期内容统一管理（地图词缀 / 试炼塔进度 / 裂隙）
##
## 设计：
## - 地图词缀 active_modifiers 是临时状态（每次进副本前选择，回城清空）。
## - 试炼塔进度 trial_max_floor / trial_milestones_claimed 是持久状态。
## - 裂隙是临时会话；rift_essence 走 GameState.materials。

signal modifiers_changed()
signal trial_progress_changed()
signal rift_started(seed_id: String, modifiers: Array)
signal rift_completed(success: bool, rewards: Dictionary)

# 已选地图词缀（id 列表，进副本时由 EnemySpawner/CombatSystem/Player 读取并应用）
var active_modifiers: Array = []

# 试炼塔最高层（持久）
var trial_max_floor: int = 0
# 已领取的里程碑（"10"/"25"/"50"/"100"）
var trial_milestones_claimed: Dictionary = {}
# 当前试炼塔会话状态（临时）
var trial_active: bool = false
var trial_current_floor: int = 0

# 裂隙临时状态
var rift_active: bool = false
var rift_modifiers: Array = []
var rift_start_time: float = 0.0
var rift_seed: String = ""

func _ready():
	print("[EndgameSystem] 末期内容系统初始化")

# ============ 地图词缀 ============
func get_modifier_def(mod_id: String) -> Dictionary:
	var pool = ConfigLoader.get_endgame_config().get("dungeon_modifiers", {}).get("modifiers", [])
	for m in pool:
		if m.get("id", "") == mod_id:
			return m
	return {}

func get_all_modifiers() -> Array:
	return ConfigLoader.get_endgame_config().get("dungeon_modifiers", {}).get("modifiers", [])

func max_modifiers() -> int:
	return int(ConfigLoader.get_endgame_config().get("dungeon_modifiers", {}).get("max_active", 3))

func toggle_modifier(mod_id: String) -> bool:
	if mod_id in active_modifiers:
		active_modifiers.erase(mod_id)
		modifiers_changed.emit()
		return false
	if active_modifiers.size() >= max_modifiers():
		return false
	if get_modifier_def(mod_id).is_empty():
		return false
	active_modifiers.append(mod_id)
	modifiers_changed.emit()
	return true

func clear_modifiers():
	active_modifiers.clear()
	modifiers_changed.emit()

## 把激活词缀的所有数值字段聚合成 {key: value} 字典，给系统消费
## 同 key 数值相加（drop_bonus / exp_bonus / rarity_boost / enemy_xxx_mult / player_xxx_mult ...）
func aggregate_active_effects() -> Dictionary:
	var totals: Dictionary = {}
	for mid in active_modifiers:
		var def = get_modifier_def(mid)
		var eff = def.get("effect", {})
		for k in eff:
			totals[k] = totals.get(k, 0.0) + float(eff[k])
		# 顶层奖励字段也聚合
		for k in ["drop_bonus", "exp_bonus", "rarity_boost"]:
			if def.has(k):
				totals[k] = totals.get(k, 0.0) + float(def[k])
	return totals

# ============ 试炼塔 ============
func start_trial(starting_floor: int = 1) -> void:
	trial_active = true
	trial_current_floor = max(1, starting_floor)
	trial_progress_changed.emit()
	print("[EndgameSystem] 试炼塔开战，从 Lv.%d 开始" % trial_current_floor)

## 一层结算成功（玩家通过该层）。
## 返回 {next_floor, milestone_rewards, layer_rewards}
func clear_trial_floor() -> Dictionary:
	if not trial_active:
		return {}
	var cfg = ConfigLoader.get_endgame_config().get("trial_tower", {})
	var max_floor = int(cfg.get("max_floors", 100))
	var cleared = trial_current_floor
	# 更新最高记录
	if cleared > trial_max_floor:
		trial_max_floor = cleared

	# 每 5 层奖励
	var layer_rewards = {}
	var every_n = int(cfg.get("boss_every_n_floors", 5))
	if cleared % every_n == 0:
		layer_rewards = cfg.get("rewards_per_5_floors", {}).duplicate()
		_grant_rewards(layer_rewards)

	# 里程碑奖励
	var milestone_rewards = {}
	var milestones = cfg.get("milestone_rewards", {})
	var key = str(cleared)
	if milestones.has(key) and not trial_milestones_claimed.get(key, false):
		milestone_rewards = milestones[key].duplicate()
		_grant_rewards(milestone_rewards)
		trial_milestones_claimed[key] = true

	# 推下一层 / 收尾
	if cleared >= max_floor:
		trial_active = false
	else:
		trial_current_floor = cleared + 1
	trial_progress_changed.emit()
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()
	return {
		"cleared_floor": cleared,
		"next_floor": trial_current_floor,
		"layer_rewards": layer_rewards,
		"milestone_rewards": milestone_rewards,
		"finished": not trial_active,
	}

## 试炼失败：保留最高层记录，结束当前会话
func abort_trial():
	trial_active = false
	trial_current_floor = 0
	trial_progress_changed.emit()

## 当前层敌人难度倍率（HP/伤害/掉落）
func get_trial_floor_multipliers() -> Dictionary:
	var cfg = ConfigLoader.get_endgame_config().get("trial_tower", {})
	var f = max(1, trial_current_floor)
	return {
		"hp_mult": 1.0 + float(cfg.get("hp_mult_per_floor", 0.10)) * (f - 1),
		"dmg_mult": 1.0 + float(cfg.get("dmg_mult_per_floor", 0.07)) * (f - 1),
		"drop_bonus": float(cfg.get("drop_bonus_per_floor", 0.02)) * (f - 1),
		"is_boss_floor": (f % int(cfg.get("boss_every_n_floors", 5))) == 0,
	}

# ============ 裂隙 ============
func start_rift() -> Dictionary:
	var cfg = ConfigLoader.get_endgame_config().get("rifts", {})
	rift_active = true
	rift_seed = str(Time.get_ticks_msec()) + "_" + str(randi() % 1000000)
	rift_modifiers.clear()
	# 按概率 roll 0~N 个 modifier
	var chance = float(cfg.get("modifier_chance", 0.7))
	var pool_size = int(cfg.get("modifier_pool_size", 2))
	var pool = get_all_modifiers()
	if randf() < chance and not pool.is_empty():
		var picked = {}
		for i in pool_size:
			if randf() > 0.5:
				continue
			var idx = randi() % pool.size()
			var mid = pool[idx].get("id", "")
			if mid != "" and not picked.has(mid):
				picked[mid] = true
				rift_modifiers.append(mid)
	rift_start_time = Time.get_unix_time_from_system()
	rift_started.emit(rift_seed, rift_modifiers)
	print("[EndgameSystem] 裂隙启动: %s, modifiers=%s" % [rift_seed, str(rift_modifiers)])
	return {"seed": rift_seed, "modifiers": rift_modifiers, "time_limit": cfg.get("time_limit_seconds", 300)}

func is_rift_timed_out() -> bool:
	if not rift_active:
		return false
	var cfg = ConfigLoader.get_endgame_config().get("rifts", {})
	var limit = float(cfg.get("time_limit_seconds", 300))
	return (Time.get_unix_time_from_system() - rift_start_time) > limit

func complete_rift(success: bool) -> Dictionary:
	var cfg = ConfigLoader.get_endgame_config().get("rifts", {})
	var rewards: Dictionary = {}
	if success and not is_rift_timed_out():
		var rew = cfg.get("rewards_on_clear", {})
		var ess_min = int(rew.get("rift_essence_min", 5))
		var ess_max = int(rew.get("rift_essence_max", 15))
		var ess = randi_range(ess_min, ess_max)
		var gold_min = int(rew.get("gold_min", 1000))
		var gold_max = int(rew.get("gold_max", 3000))
		var gold = randi_range(gold_min, gold_max)
		var ess_id = cfg.get("essence_material_id", "rift_essence")
		GameState.add_material(ess_id, ess)
		GameState.total_gold += gold
		rewards = {ess_id: ess, "gold": gold}
		if has_node("/root/SaveSystem"):
			SaveSystem.mark_dirty()
	rift_active = false
	rift_modifiers.clear()
	rift_completed.emit(success, rewards)
	return rewards

# ============ 通用奖励发放 ============
func _grant_rewards(rewards: Dictionary):
	for k in rewards:
		if k == "design_note":
			continue
		if k == "gold":
			GameState.total_gold += int(rewards[k])
		elif k == "talent_points":
			GameState.talent_points_unspent += int(rewards[k])
			GameState.talent_changed.emit()
		elif k == "paragon_points":
			GameState.paragon_points_unspent += int(rewards[k])
			GameState.paragon_changed.emit()
		else:
			# 视为材料
			GameState.add_material(k, int(rewards[k]))

# ============ 序列化（持久部分）============
func serialize() -> Dictionary:
	return {
		"trial_max_floor": trial_max_floor,
		"trial_milestones_claimed": trial_milestones_claimed.duplicate(true),
	}

func deserialize(data: Dictionary):
	trial_max_floor = int(data.get("trial_max_floor", 0))
	trial_milestones_claimed = data.get("trial_milestones_claimed", {}).duplicate(true)
	print("[EndgameSystem] 加载末期进度: 试炼最高 Lv.%d" % trial_max_floor)
