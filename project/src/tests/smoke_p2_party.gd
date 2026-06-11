extends SceneTree
## P2 冒烟测试：组队面板 + Companion 实例化


func _initialize() -> void:
	await process_frame
	await process_frame
	var fails = 0

	var rs = root.get_node("RosterSystem")
	var ps = root.get_node("PartySystem")
	rs.characters.clear()
	rs.active_char_id = ""
	ps.companion_ids.clear()

	# 创建操控角色 + 2 队友
	var active = rs.create_character("class_warrior", "主角", false)
	var ally1 = rs.create_character("class_mage", "法师队友", false)
	var ally2 = rs.create_character("class_ranger", "射手队友", false)
	rs.switch_character(active)
	ps.add_companion(ally1)
	ps.add_companion(ally2)

	# 加载 Town 并触发组队面板
	var town_scene = load("res://scenes/Town.tscn")
	if town_scene == null:
		print("[SMOKE FAIL] Town.tscn 加载失败")
		fails += 1
	else:
		var town = town_scene.instantiate()
		root.add_child(town)
		await process_frame
		if town.has_method("_on_dungeon_portal_clicked"):
			town._on_dungeon_portal_clicked()
			await process_frame
			print("[SMOKE OK] 组队面板构建成功")
		else:
			print("[SMOKE FAIL] Town 缺少 _on_dungeon_portal_clicked")
			fails += 1
		town.queue_free()

	# Companion 实例化测试
	var companion_script = load("res://scripts/Companion.gd")
	if companion_script == null:
		print("[SMOKE FAIL] Companion.gd 加载失败")
		fails += 1
	else:
		var c = CharacterBody2D.new()
		c.set_script(companion_script)
		c.setup(rs.get_character(ally1))
		root.add_child(c)
		await process_frame
		if c.get("max_hp") > 0:
			print("[SMOKE OK] Companion 实例化成功，max_hp=" + str(c.max_hp))
		else:
			print("[SMOKE FAIL] Companion max_hp 未初始化")
			fails += 1
		c.queue_free()

	print("[SMOKE P2] fails=%d" % fails)
	quit(1 if fails > 0 else 0)
