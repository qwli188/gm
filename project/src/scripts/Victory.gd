extends Control

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var completion_time_label: Label = $Panel/VBoxContainer/StatsContainer/CompletionTimeLabel
@onready var kills_label: Label = $Panel/VBoxContainer/StatsContainer/KillsLabel
@onready var gold_label: Label = $Panel/VBoxContainer/StatsContainer/GoldLabel
@onready var next_button: Button = $Panel/VBoxContainer/ButtonContainer/NextButton
@onready var menu_button: Button = $Panel/VBoxContainer/ButtonContainer/MenuButton

var completion_time: float = 0.0
var kills: int = 0
var gold_earned: int = 0
# 结算模式："dungeon" / "trial" / "rift"，决定按钮去向
var _result_mode: String = "dungeon"


func _ready():
	hide()
	next_button.pressed.connect(_on_next_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


## 显示通关界面
func show_victory(time: float, kill_count: int, gold: int):
	_result_mode = "dungeon"
	# 清理副本机制
	if has_node("/root/DungeonFeatureSystem"):
		get_node("/root/DungeonFeatureSystem").deactivate()
	completion_time = time
	kills = kill_count
	gold_earned = gold

	# 更新显示
	var minutes = int(time / 60)
	var seconds = int(time) % 60
	completion_time_label.text = "通关时间: %02d:%02d" % [minutes, seconds]
	kills_label.text = "击杀数: %d" % kill_count
	gold_label.text = "获得金币: %d (全额带回)" % gold

	# 通关全额存金币 + 记录解锁
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		gs.total_gold += gold
		# 记录通关进度（复杂格式：支持多难度、首次时间、总次数）
		var dungeon_id = gs.selected_dungeon_id
		var tier = gs.selected_difficulty_tier
		var now_iso = Time.get_datetime_string_from_system(true)

		if not gs.cleared_dungeons.has(dungeon_id):
			# 首次通关该副本
			gs.cleared_dungeons[dungeon_id] = {
				"max_tier_cleared": tier, "first_clear_time": now_iso, "total_clears": 1
			}
		else:
			# 更新记录
			var record = gs.cleared_dungeons[dungeon_id]
			record["max_tier_cleared"] = max(record.get("max_tier_cleared", 0), tier)
			record["total_clears"] = record.get("total_clears", 0) + 1

	# 出击制：一次通关 = 一次出击，领地建筑结算产出
	_settle_territory_sortie()

	# P9: 通知任务系统副本通关
	if has_node("/root/QuestSystem") and has_node("/root/GameState"):
		get_node("/root/QuestSystem").register_clear_dungeon(
			get_node("/root/GameState").selected_dungeon_id
		)

	# P4: 检查是否触发防御战
	if _check_defense_trigger():
		return  # 跳转到防御战,不显示通关界面

	show()


## 领地出击结算：建筑产出材料入库，并在通关界面提示
func _settle_territory_sortie():
	if not has_node("/root/TerritorySystem"):
		return
	var gains = get_node("/root/TerritorySystem").settle_sortie()
	if gains.is_empty():
		return
	var parts = []
	for mat in gains:
		parts.append("%s +%d" % [_mat_display(mat), gains[mat]])
	gold_label.text += "\n领地产出: " + "  ".join(parts)


func _mat_display(material_id: String) -> String:
	for m in ConfigLoader.get_basic_materials():
		if m.get("id", "") == material_id:
			return m.get("display_name", material_id)
	return material_id


## P4: 防御战触发检查
func _check_defense_trigger() -> bool:
	if not has_node("/root/TerritorySystem"):
		return false
	var ts = get_node("/root/TerritorySystem")
	if ts.should_trigger_defense():
		# P4 简化版:自动结算(不进战斗场景)
		_resolve_defense_battle(ts)
		return false  # 继续显示通关界面,附加防御战结果
	return false


## 自动结算防御战:领地防御力 vs 威胁等级
func _resolve_defense_battle(ts):
	var threat = 100 + ts.level * 50  # 威胁随领地等级增长
	var defense_power = _calculate_defense_power(ts)
	print("[Defense] 威胁 %d vs 防御力 %d" % [threat, defense_power])
	if defense_power >= threat:
		# 胜利
		var rewards = ts.reward_defense_victory()
		var parts = []
		for mat in rewards:
			parts.append("%s +%d" % [_mat_display(mat), rewards[mat]])
		gold_label.text += "\n\n[color=lime]防御战胜利！[/color]\n奖励: " + "  ".join(parts)
	else:
		# 失败
		ts.penalty_defense_defeat()
		gold_label.text += "\n\n[color=red]领地遭袭！防御失败[/color]\n损失了部分资源"


func _calculate_defense_power(ts) -> float:
	var power = 0.0
	# 城墙 + 哨塔贡献
	power += ts.get_defense_bonus() * 200  # 防御加成
	power += ts.get_tower_damage() * 2  # 哨塔伤害
	# 士兵数量 × 50
	power += ts.count_soldiers() * 50
	# 领地等级基础
	power += ts.level * 30
	return power


## 试炼塔层通关结算界面
func show_trial_result(result: Dictionary, kill_count: int):
	_result_mode = "trial"
	if has_node("/root/DungeonFeatureSystem"):
		get_node("/root/DungeonFeatureSystem").deactivate()
	var cleared = int(result.get("cleared_floor", 0))
	var finished = bool(result.get("finished", false))
	title_label.text = "试炼塔 第 %d 层 通过！" % cleared
	completion_time_label.text = (
		"已达最高层: %d"
		% int(
			(
				get_node("/root/EndgameSystem").trial_max_floor
				if has_node("/root/EndgameSystem")
				else cleared
			)
		)
	)
	kills_label.text = "击杀数: %d" % kill_count
	var reward_parts = []
	for d in [result.get("layer_rewards", {}), result.get("milestone_rewards", {})]:
		for k in d:
			if k == "design_note":
				continue
			reward_parts.append("%s +%s" % [k, d[k]])
	gold_label.text = "奖励: " + ("  ".join(reward_parts) if reward_parts.size() > 0 else "（本层无额外奖励）")
	if finished:
		next_button.text = "已登顶！"
		next_button.disabled = true
	else:
		next_button.text = "继续下一层"
		next_button.disabled = false
	menu_button.text = "收手回城"
	show()


## 裂隙通关结算界面
func show_rift_result(rewards: Dictionary, success: bool, kill_count: int):
	_result_mode = "rift"
	if has_node("/root/DungeonFeatureSystem"):
		get_node("/root/DungeonFeatureSystem").deactivate()
	title_label.text = "裂隙关闭" if success else "裂隙崩溃"
	completion_time_label.text = "结果: %s" % ("成功" if success else "失败")
	kills_label.text = "击杀数: %d" % kill_count
	var parts = []
	for k in rewards:
		parts.append("%s +%s" % [k, rewards[k]])
	gold_label.text = "奖励: " + ("  ".join(parts) if parts.size() > 0 else "（无）")
	next_button.text = "返回主城"
	next_button.disabled = false
	menu_button.text = "返回主菜单"
	show()


func _on_next_pressed():
	get_tree().paused = false
	# 试炼塔：继续下一层（重进战斗场景，逐层倍率已由 EndgameSystem 推进）
	if _result_mode == "trial":
		if has_node("/root/GameState"):
			get_node("/root/GameState").enter_trial_floor()
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	# 普通副本 / 裂隙：返回主城
	get_tree().change_scene_to_file("res://scenes/Town.tscn")


func _on_menu_pressed():
	get_tree().paused = false
	# 试炼塔"收手回城"按钮：回主城而非主菜单
	if _result_mode == "trial":
		get_tree().change_scene_to_file("res://scenes/Town.tscn")
		return
	# 返回主菜单
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
