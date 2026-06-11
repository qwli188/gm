extends SceneTree
## 冒烟测试：实例化 Town 场景，确认多角色 UI 代码运行无误
## 通过 root.get_node 访问 autoload（-s 启动脚本无法在编译期解析 autoload 全局名）

func _initialize() -> void:
	await process_frame
	await process_frame
	var fails = 0

	var rs = root.get_node("RosterSystem")
	# 准备一个名册（模拟已创建角色）
	rs.characters.clear()
	rs.active_char_id = ""
	var id1 = rs.create_character("class_warrior", "冒烟战士")
	rs.create_character("class_mage", "冒烟法师")
	rs.switch_character(id1)

	var town_scene = load("res://scenes/Town.tscn")
	if town_scene == null:
		print("[SMOKE FAIL] Town.tscn 加载失败")
		fails += 1
	else:
		var town = town_scene.instantiate()
		root.add_child(town)
		await process_frame
		if town.has_method("_on_roster_clicked"):
			town._on_roster_clicked()
			await process_frame
			print("[SMOKE OK] Town 角色管理面板构建成功")
		else:
			print("[SMOKE FAIL] Town 缺少 _on_roster_clicked")
			fails += 1
		if town.has_method("_on_switch_character"):
			var others = rs.get_other_characters()
			if others.size() > 0:
				town._on_switch_character(others[0].get("char_id", ""))
				await process_frame
				print("[SMOKE OK] Town 切换角色成功，当前=" + rs.get_active_character().get("name", "?"))

		# 领地面板
		var ts = root.get_node("TerritorySystem")
		ts.level = 1
		ts.buildings = {"townhall": 1}
		root.get_node("GameState").total_gold = 999999
		root.get_node("GameState").materials = {"timber": 999, "stone_block": 999, "food": 999}
		if town.has_method("_on_territory_clicked"):
			town._on_territory_clicked()
			await process_frame
			print("[SMOKE OK] Town 领地面板构建成功")
			# 建造一座伐木场
			town._on_build_building("lumber_mill")
			await process_frame
			if ts.has_building("lumber_mill"):
				print("[SMOKE OK] 领地建造伐木场成功")
			else:
				print("[SMOKE FAIL] 领地建造失败")
				fails += 1
		else:
			print("[SMOKE FAIL] Town 缺少 _on_territory_clicked")
			fails += 1
		town.queue_free()

	print("[SMOKE] fails=%d" % fails)
	quit(1 if fails > 0 else 0)
