extends Node2D
## Main 场景脚本 - 处理 UI 面板快捷键切换和快速存读档

func _input(event):
	# UI 面板切换
	if event.is_action_pressed("toggle_character_panel"):
		_toggle_panel("CharacterPanel")
	elif event.is_action_pressed("toggle_skill_tree"):
		_toggle_panel("SkillTreePanel")
	elif event.is_action_pressed("toggle_backpack"):
		_toggle_panel("BackpackPanel")
	# 快速存读档
	elif event.is_action_pressed("quick_save"):
		if has_node("/root/SaveSystem"):
			get_node("/root/SaveSystem").save_game(1)
			print("[Main] 快速存档到槽位 1")
	elif event.is_action_pressed("quick_load"):
		if has_node("/root/SaveSystem"):
			get_node("/root/SaveSystem").load_game(1)
			print("[Main] 快速读档从槽位 1")

func _toggle_panel(panel_name: String):
	var panel = $UILayer.get_node_or_null(panel_name)
	if panel:
		panel.visible = !panel.visible
		# 切换面板时暂停游戏(可选,取决于你的设计)
		# get_tree().paused = panel.visible
