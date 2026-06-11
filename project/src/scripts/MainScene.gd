extends Node2D
## Main 场景脚本 - 处理 UI 面板快捷键切换和快速存读档

@onready var player: Node2D = $Player


func _ready():
	# 阶段2: 启动副本流程系统
	_start_dungeon_flow()
	# P2: 生成随行 AI 队友
	_spawn_companions()


## P2: 在玩家附近生成随行 AI 队友（Companion）
func _spawn_companions():
	if not has_node("/root/PartySystem"):
		return
	var companions = get_node("/root/PartySystem").get_companion_characters()
	if companions.is_empty():
		return
	var companion_script = load("res://scripts/Companion.gd")
	if companion_script == null:
		push_error("[MainScene] Companion.gd 加载失败")
		return
	var idx = 0
	for char_data in companions:
		var c = CharacterBody2D.new()
		c.set_script(companion_script)
		c.setup(char_data)
		# 在玩家身后散开排布
		var angle = PI + (idx - 1) * 0.5
		var offset = Vector2(cos(angle), sin(angle)) * 70.0
		add_child(c)
		if player and is_instance_valid(player):
			c.global_position = player.global_position + offset
		idx += 1
	print("[MainScene] 生成 %d 个随行队友" % companions.size())


func _start_dungeon_flow():
	# 获取当前副本ID（从GameState或默认值）
	var dungeon_id = "dungeon_crypt_1"  # 默认第一个副本
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		var current = gs.get("selected_dungeon_id")
		if current != null and current != "":
			dungeon_id = current

	# 启动副本地形生成
	if has_node("/root/DungeonFlow"):
		DungeonFlow.start_dungeon(dungeon_id, self, player)
		print("[MainScene] 副本地形已生成: %s" % dungeon_id)


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
