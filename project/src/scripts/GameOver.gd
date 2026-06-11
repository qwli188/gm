extends Control

@onready var survival_time_label: Label = $Panel/VBoxContainer/StatsContainer/SurvivalTimeLabel
@onready var kills_label: Label = $Panel/VBoxContainer/StatsContainer/KillsLabel
@onready var gold_label: Label = $Panel/VBoxContainer/StatsContainer/GoldLabel
@onready var retry_button: Button = $Panel/VBoxContainer/ButtonContainer/RetryButton
@onready var menu_button: Button = $Panel/VBoxContainer/ButtonContainer/MenuButton

var survival_time: float = 0.0
var kills: int = 0
var gold_earned: int = 0


func _ready():
	hide()
	retry_button.pressed.connect(_on_retry_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


## 显示游戏结束界面
func show_game_over(time: float, kill_count: int, gold: int):
	# 清理副本机制
	if has_node("/root/DungeonFeatureSystem"):
		get_node("/root/DungeonFeatureSystem").deactivate()
	survival_time = time
	kills = kill_count
	gold_earned = gold

	# 计算金币带回（50%）
	var gold_kept = int(gold * 0.5)

	# 存入全局局外数据
	if has_node("/root/GameState"):
		get_node("/root/GameState").total_gold += gold_kept

	# 更新显示
	var minutes = int(time / 60)
	var seconds = int(time) % 60
	survival_time_label.text = "存活时间: %02d:%02d" % [minutes, seconds]
	kills_label.text = "击杀数: %d" % kill_count
	gold_label.text = "获得金币: %d (带回 %d)" % [gold, gold_kept]

	show()


func _on_retry_pressed():
	# 返回主城（而不是直接重开）
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Town.tscn")


func _on_menu_pressed():
	# 返回主菜单
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
