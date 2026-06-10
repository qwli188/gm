extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var quit_button: Button = $VBoxContainer/QuitButton

func _ready():
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	# BGM: 主菜单史诗英雄风
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_bgm("menu")

func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/ClassSelect.tscn")

func _on_quit_pressed():
	get_tree().quit()
