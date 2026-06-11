extends Node
## SaveSystem - 负责玩家存档的保存与加载
## 支持3个存档槽位，自动保存功能，装备实例序列化

const SAVE_DIR = "user://saves/"
const MAX_SLOTS = 3

# 自动保存设置
var auto_save_enabled: bool = true
var _dirty: bool = false

signal save_completed(slot: int)
signal load_completed(slot: int)
signal save_failed(slot: int, error: String)


func _ready():
	print("[SaveSystem] 存档系统初始化")
	_ensure_save_directory()


## 确保存档目录存在
func _ensure_save_directory():
	var dir = DirAccess.open("user://")
	if not dir.dir_exists("saves"):
		dir.make_dir("saves")


## 标记需要自动保存
func mark_dirty():
	_dirty = true


## 保存游戏到指定槽位
func save_game(slot: int) -> bool:
	if slot < 1 or slot > MAX_SLOTS:
		push_error("[SaveSystem] 槽位超出范围: %d" % slot)
		save_failed.emit(slot, "invalid_slot")
		return false

	var save_data = _collect_save_data(slot)
	var file_path = _get_save_path(slot)

	var file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		var error = FileAccess.get_open_error()
		push_error("[SaveSystem] 无法写入存档: %s (错误码: %d)" % [file_path, error])
		save_failed.emit(slot, "file_error")
		return false

	var json_string = JSON.stringify(save_data, "\t")
	file.store_string(json_string)
	file.close()

	_dirty = false
	save_completed.emit(slot)
	print("[SaveSystem] 存档保存成功: 槽位 %d" % slot)
	return true


## 加载指定槽位的游戏
func load_game(slot: int) -> bool:
	if slot < 1 or slot > MAX_SLOTS:
		push_error("[SaveSystem] 槽位超出范围: %d" % slot)
		return false

	var file_path = _get_save_path(slot)
	if not FileAccess.file_exists(file_path):
		push_warning("[SaveSystem] 存档不存在: 槽位 %d" % slot)
		return false

	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[SaveSystem] 无法读取存档: %s" % file_path)
		return false

	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_string)
	if parse_result != OK:
		push_error(
			"[SaveSystem] 存档解析失败: 第%d行 %s" % [json.get_error_line(), json.get_error_message()]
		)
		return false

	var save_data = json.data
	if typeof(save_data) != TYPE_DICTIONARY:
		push_error("[SaveSystem] 存档格式错误（非字典）")
		return false

	_apply_save_data(save_data)
	load_completed.emit(slot)
	print("[SaveSystem] 存档加载成功: 槽位 %d" % slot)
	return true


## 自动保存（在关键时机调用：升级/进城/退出副本）
func auto_save(slot: int = 1):
	if not auto_save_enabled:
		return
	if not _dirty:
		return
	print("[SaveSystem] 自动保存触发: 槽位 %d" % slot)
	save_game(slot)


## 列出已有存档（返回每个槽位的摘要信息）
func get_save_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for i in range(1, MAX_SLOTS + 1):
		var file_path = _get_save_path(i)
		if not FileAccess.file_exists(file_path):
			slots.append({"slot_id": i, "exists": false})
			continue
		var summary = _read_save_summary(i)
		summary["slot_id"] = i
		summary["exists"] = true
		slots.append(summary)
	return slots


## 删除指定槽位存档
func delete_save(slot: int) -> bool:
	var file_path = _get_save_path(slot)
	if not FileAccess.file_exists(file_path):
		return false
	var dir = DirAccess.open(SAVE_DIR)
	if dir == null:
		return false
	var err = dir.remove(_get_save_filename(slot))
	if err == OK:
		print("[SaveSystem] 删除存档: 槽位 %d" % slot)
		return true
	return false


## 读取存档摘要（不完整加载，仅显示用）
func _read_save_summary(slot: int) -> Dictionary:
	var file_path = _get_save_path(slot)
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var json_string = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(json_string) != OK:
		return {"corrupted": true}
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return {"corrupted": true}
	var char_data = data.get("character", {})
	return {
		"class_id": char_data.get("class_id", "?"),
		"level": char_data.get("level", 1),
		"gold": char_data.get("gold", 0),
		"playtime_seconds": data.get("playtime_seconds", 0),
		"last_played": data.get("last_played", ""),
	}


func _get_save_filename(slot: int) -> String:
	return "save_%d.json" % slot


func _get_save_path(slot: int) -> String:
	return SAVE_DIR + _get_save_filename(slot)


## ============ 数据收集（保存时）============
## 从 Player / EquipmentSystem / GameState 收集持久数据
func _collect_save_data(slot: int) -> Dictionary:
	var now_iso = Time.get_datetime_string_from_system(true)
	# 先把操控角色的实时状态同步进名册档案，再序列化
	if has_node("/root/RosterSystem"):
		get_node("/root/RosterSystem").sync_before_save()
	var data = {
		"version": "2.1.0",
		"slot_id": slot,
		"created_at": now_iso,
		"last_played": now_iso,
		"playtime_seconds": 0,
		"character": _collect_character_data(),  # 保留：兼容旧读取器/摘要显示
		"roster": _collect_roster_data(),
		"territory": _collect_territory_data(),
		"endgame": _collect_endgame_data(),
		"quests": _collect_quest_data(),
		"build_presets": _collect_preset_data(),
		"equipment_instances": {},
		"world_state": _collect_world_state(),
		"meta_progression": _collect_meta_progression(),
		"statistics": {},
	}

	# 装备实例序列化（由 EquipmentSystem 提供）
	if has_node("/root/EquipmentSystem"):
		var eq = get_node("/root/EquipmentSystem")
		if eq.has_method("serialize_instances"):
			data["equipment_instances"] = eq.serialize_instances()

	# 保留已存在存档的 created_at 与累计游戏时长
	var existing = _read_existing_raw(slot)
	if not existing.is_empty():
		data["created_at"] = existing.get("created_at", now_iso)
		data["playtime_seconds"] = existing.get("playtime_seconds", 0)

	return data


## 读取已存在的原始存档（用于保留 created_at 等字段）
func _read_existing_raw(slot: int) -> Dictionary:
	var file_path = _get_save_path(slot)
	if not FileAccess.file_exists(file_path):
		return {}
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
	var txt = file.get_as_text()
	file.close()
	var json = JSON.new()
	if json.parse(txt) != OK or typeof(json.data) != TYPE_DICTIONARY:
		return {}
	return json.data


## 收集角色数据
func _collect_character_data() -> Dictionary:
	var char_data = {
		"class_id": "class_warrior",
		"level": 1,
		"current_exp": 0.0,
		"gold": 0,
		"equipped": {},
		"backpack": [],
		"warehouse": [],
		"attributes": {"strength": 0, "agility": 0, "vitality": 0, "intelligence": 0},
		"attribute_points_unspent": 0,
		"learned_skills": {},
		"skill_points_unspent": 0,
	}

	if has_node("/root/GameState"):
		char_data["class_id"] = get_node("/root/GameState").selected_class_id

	# Player 的等级/经验/金币/属性点（防御性访问：兼容残缺/Mock player）
	var player = _find_player()
	if player and player.get("current_level") != null:
		char_data["level"] = player.current_level
		char_data["current_exp"] = player.current_exp
		char_data["gold"] = player.gold
		# 属性加点数据（如果 Player 有这些字段）
		if player.get("attributes") != null:
			char_data["attributes"] = player.attributes.duplicate()
		if player.get("attribute_points_unspent") != null:
			char_data["attribute_points_unspent"] = player.attribute_points_unspent

	# 已穿戴装备（存 instance_id）与背包
	if has_node("/root/EquipmentSystem"):
		var eq = get_node("/root/EquipmentSystem")
		if eq.has_method("serialize_equipped"):
			char_data["equipped"] = eq.serialize_equipped()

	# 背包/仓库（PR-3 后由 Inventory autoload 管理）
	if has_node("/root/Inventory"):
		var inv_data = Inventory.serialize()
		char_data["backpack"] = inv_data.get("backpack", [])
		char_data["warehouse"] = inv_data.get("warehouse", [])

	# 技能树数据（从 SkillSystem 收集）
	if has_node("/root/SkillSystem"):
		var ss = get_node("/root/SkillSystem")
		char_data["learned_skills"] = ss.learned_skills.duplicate()
		char_data["skill_points_unspent"] = ss.skill_points_unspent

	return char_data


## 收集角色名册（多角色，v2.0+）
func _collect_roster_data() -> Dictionary:
	if has_node("/root/RosterSystem"):
		return get_node("/root/RosterSystem").serialize()
	return {}


## 收集领地数据（v2.0+）
func _collect_territory_data() -> Dictionary:
	if has_node("/root/TerritorySystem"):
		return get_node("/root/TerritorySystem").serialize()
	return {}


## P7 收集末期内容数据（试炼塔进度等）
func _collect_endgame_data() -> Dictionary:
	if has_node("/root/EndgameSystem"):
		return get_node("/root/EndgameSystem").serialize()
	return {}


## P9 收集任务系统数据
func _collect_quest_data() -> Dictionary:
	if has_node("/root/QuestSystem"):
		return get_node("/root/QuestSystem").serialize()
	return {}


## P10 收集 BD 预设数据
func _collect_preset_data() -> Dictionary:
	if has_node("/root/BuildPresets"):
		return get_node("/root/BuildPresets").serialize()
	return {}


## 收集世界状态
func _collect_world_state() -> Dictionary:
	var ws = {"unlocked_dungeons": [], "cleared_dungeons": {}}
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		ws["unlocked_dungeons"] = gs.unlocked_dungeons.duplicate()
		# 深拷贝 cleared_dungeons（嵌套字典格式）
		ws["cleared_dungeons"] = {}
		for dungeon_id in gs.cleared_dungeons:
			ws["cleared_dungeons"][dungeon_id] = gs.cleared_dungeons[dungeon_id].duplicate(true)
	return ws


## 收集局外永久进度
func _collect_meta_progression() -> Dictionary:
	var meta = {"total_gold_earned": 0, "meta_upgrades": {}, "materials": {}}
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		meta["total_gold_earned"] = gs.total_gold
		meta["meta_upgrades"] = gs.meta_upgrades.duplicate(true)
		meta["materials"] = gs.materials.duplicate(true)
		# P6: 巅峰系统持久化（账号级共享）
		meta["paragon"] = {
			"level": gs.paragon_level,
			"exp": gs.paragon_exp,
			"points_unspent": gs.paragon_points_unspent,
			"allocations": gs.paragon_allocations.duplicate(true),
		}
		# P6: 天赋星图持久化
		meta["talents"] = {
			"unlocked": gs.unlocked_talents.duplicate(true),
			"points_unspent": gs.talent_points_unspent,
		}
	return meta


## ============ 数据应用（加载时）============
func _apply_save_data(data: Dictionary):
	# 1. 先恢复装备实例（角色装备引用它们）
	var instances = data.get("equipment_instances", {})
	if has_node("/root/EquipmentSystem"):
		var eq = get_node("/root/EquipmentSystem")
		if eq.has_method("deserialize_instances"):
			eq.deserialize_instances(instances)

	# 2. 角色数据
	var char_data = data.get("character", {})
	if has_node("/root/GameState"):
		get_node("/root/GameState").selected_class_id = char_data.get("class_id", "class_warrior")

	# 3. 世界状态与局外进度
	if has_node("/root/GameState"):
		var gs = get_node("/root/GameState")
		var ws = data.get("world_state", {})
		gs.unlocked_dungeons = ws.get("unlocked_dungeons", ["dungeon_crypt_1"])
		# 加载 cleared_dungeons（深拷贝嵌套字典）+ 兼容旧格式
		var saved_cleared = ws.get("cleared_dungeons", {})
		gs.cleared_dungeons = {}
		for dungeon_id in saved_cleared:
			var value = saved_cleared[dungeon_id]
			# 检测旧格式：如果值是 bool，转为新格式（假设 tier=1）
			if typeof(value) == TYPE_BOOL:
				if value == true:
					# 旧格式 key 可能是 "clear_crypt_1_t1"，提取真实 dungeon_id
					var real_dungeon_id = _parse_legacy_dungeon_key(dungeon_id)
					gs.cleared_dungeons[real_dungeon_id] = {
						"max_tier_cleared": 1, "first_clear_time": "", "total_clears": 1
					}
			elif typeof(value) == TYPE_DICTIONARY:
				# 新格式：直接深拷贝
				gs.cleared_dungeons[dungeon_id] = value.duplicate(true)
		var meta = data.get("meta_progression", {})
		gs.total_gold = meta.get("total_gold_earned", 0)
		gs.meta_upgrades = meta.get("meta_upgrades", {})
		gs.materials = meta.get("materials", {})
		# P6: 恢复巅峰系统
		var paragon = meta.get("paragon", {})
		gs.paragon_level = int(paragon.get("level", 0))
		gs.paragon_exp = float(paragon.get("exp", 0.0))
		gs.paragon_points_unspent = int(paragon.get("points_unspent", 0))
		gs.paragon_allocations = paragon.get("allocations", {}).duplicate(true)
		# P6: 恢复天赋星图
		var talents = meta.get("talents", {})
		gs.unlocked_talents = talents.get("unlocked", {}).duplicate(true)
		gs.talent_points_unspent = int(talents.get("points_unspent", 0))

	# 4. 恢复穿戴与背包（在实例就绪后）
	#    注意：多角色名册恢复要在穿戴恢复之前，由名册决定操控角色的 equipped。
	_restore_roster(data, char_data)

	# 4b. 恢复领地
	if has_node("/root/TerritorySystem"):
		var territory_data = data.get("territory", {})
		if territory_data is Dictionary and not territory_data.is_empty():
			get_node("/root/TerritorySystem").deserialize(territory_data)

	# 4c. P7 恢复末期内容进度
	if has_node("/root/EndgameSystem"):
		var endgame_data = data.get("endgame", {})
		if endgame_data is Dictionary and not endgame_data.is_empty():
			get_node("/root/EndgameSystem").deserialize(endgame_data)

	# 4d. P9 恢复任务系统
	if has_node("/root/QuestSystem"):
		var quest_data = data.get("quests", {})
		if quest_data is Dictionary and not quest_data.is_empty():
			get_node("/root/QuestSystem").deserialize(quest_data)

	# 4e. P10 恢复 BD 预设
	if has_node("/root/BuildPresets"):
		var preset_data = data.get("build_presets", {})
		if preset_data is Dictionary and not preset_data.is_empty():
			get_node("/root/BuildPresets").deserialize(preset_data)

	if has_node("/root/EquipmentSystem"):
		var eq = get_node("/root/EquipmentSystem")
		if eq.has_method("deserialize_equipped"):
			# 操控角色的 equipped 来自名册档案（已在 _restore_roster 里灌好）
			# 这里用名册操控角色的 equipped，回退到旧 char_data.equipped
			var equipped = char_data.get("equipped", {})
			if has_node("/root/RosterSystem"):
				var active = get_node("/root/RosterSystem").get_active_character()
				if not active.is_empty():
					equipped = active.get("equipped", {})
			eq.deserialize_equipped(equipped)

	# 背包/仓库（PR-3 后由 Inventory autoload 管理）
	if has_node("/root/Inventory"):
		(
			Inventory
			. deserialize(
				{
					"backpack": char_data.get("backpack", []),
					"warehouse": char_data.get("warehouse", []),
				}
			)
		)

	# 5. 玩家等级/经验/金币/属性加点（防御性：兼容残缺/Mock player）
	#    多角色：操控角色的私有数据优先取自名册档案，回退到旧 char_data。
	var active_char = _get_active_char_or_legacy(char_data)
	var player = _find_player()
	if player and player.get("current_level") != null:
		player.current_level = active_char.get("level", 1)
		player.current_exp = active_char.get("exp", char_data.get("current_exp", 0.0))
		player.gold = char_data.get("gold", 0)
		# 恢复属性加点数据
		if player.get("attributes") != null:
			player.attributes = active_char.get(
				"attributes", {"strength": 0, "agility": 0, "vitality": 0, "intelligence": 0}
			)
		if player.get("attribute_points_unspent") != null:
			player.attribute_points_unspent = active_char.get(
				"attribute_points", char_data.get("attribute_points_unspent", 0)
			)
		if player.has_method("_calculate_exp_to_next_level"):
			player._calculate_exp_to_next_level()
		if player.has_method("recalculate_stats"):
			player.recalculate_stats()

	# 6. 恢复技能树数据（操控角色的技能取自名册档案）
	if has_node("/root/SkillSystem"):
		var ss = get_node("/root/SkillSystem")
		ss.learned_skills = active_char.get("learned_skills", char_data.get("learned_skills", {}))
		ss.skill_points_unspent = active_char.get(
			"skill_points", char_data.get("skill_points_unspent", 0)
		)
		# 触发信号更新UI
		ss.skill_points_changed.emit(ss.skill_points_unspent)


## 恢复名册：新档读 roster；旧档把单角色 char_data 迁移成名册。
func _restore_roster(data: Dictionary, char_data: Dictionary):
	if not has_node("/root/RosterSystem"):
		return
	var rs = get_node("/root/RosterSystem")
	var roster_data = data.get("roster", {})
	if roster_data is Dictionary and not roster_data.get("characters", []).is_empty():
		# 新档：直接反序列化名册
		rs.deserialize(roster_data)
		# 同步操控角色的职业到 GameState
		var active = rs.get_active_character()
		if not active.is_empty() and has_node("/root/GameState"):
			get_node("/root/GameState").selected_class_id = active.get("class_id", "class_warrior")
	else:
		# 旧档：单角色迁移成名册第一个角色
		rs.migrate_from_legacy(char_data)


## 取操控角色档案；无名册时回退到旧 char_data（字段名做映射）
func _get_active_char_or_legacy(char_data: Dictionary) -> Dictionary:
	if has_node("/root/RosterSystem"):
		var active = get_node("/root/RosterSystem").get_active_character()
		if not active.is_empty():
			return active
	return char_data


## 查找当前场景中的 Player 节点
func _find_player():
	var tree = get_tree()
	if tree == null:
		return null
	var p = tree.get_first_node_in_group("player")
	# 防御:queue_free 中或已失效的节点应视为无 player
	if p == null or not is_instance_valid(p):
		return null
	return p


## 解析旧格式副本 key（"clear_crypt_1_t1" -> "dungeon_crypt_1"）
func _parse_legacy_dungeon_key(legacy_key: String) -> String:
	# 旧格式示例: "clear_crypt_1_t1", "clear_swamp_2_t2"
	# 提取: clear_<region>_<num>_t<tier> -> dungeon_<region>_<num>
	var pattern = "^clear_(.+)_t\\d+$"
	var regex = RegEx.new()
	regex.compile(pattern)
	var result = regex.search(legacy_key)
	if result:
		return "dungeon_" + result.get_string(1)
	# 如果解析失败，返回原 key（兜底）
	push_warning("[SaveSystem] 无法解析旧格式副本 key: %s" % legacy_key)
	return legacy_key
