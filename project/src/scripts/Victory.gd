extends Control

@onready var completion_time_label: Label = $Panel/VBoxContainer/StatsContainer/CompletionTimeLabel
@onready var kills_label: Label = $Panel/VBoxContainer/StatsContainer/KillsLabel
@onready var gold_label: Label = $Panel/VBoxContainer/StatsContainer/GoldLabel
@onready var next_button: Button = $Panel/VBoxContainer/ButtonContainer/NextButton
@onready var menu_button: Button = $Panel/VBoxContainer/ButtonContainer/MenuButton

var completion_time: float = 0.0
var kills: int = 0
var gold_earned: int = 0

func _ready():
	hide()
	next_button.pressed.connect(_on_next_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

## 显示通关界面
func show_victory(time: float, kill_count: int, gold: int):
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
		# 记录通关：clear_{dungeon}_t{tier} 用于解锁下一难度/下一副本
		var dungeon_short = gs.selected_dungeon_id.replace("dungeon_", "")
		var clear_key = "clear_%s_t%d" % [dungeon_short, gs.selected_difficulty_tier]
		gs.cleared_dungeons[clear_key] = true

	show()

func _on_next_pressed():
	# 返回主城（选下一个难度/副本）
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Town.tscn")

func _on_menu_pressed():
	# 返回主菜单
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
