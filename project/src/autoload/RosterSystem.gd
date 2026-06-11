extends Node
## RosterSystem - 账号角色名册（多角色支持的地基）
##
## 设计分层（见多角色重构 P0）：
## - 角色私有状态：class_id / level / exp / attributes / equipped / learned_skills
##   全部存在每个角色档案里，由本系统管理。
## - 账号共享状态：装备实例池(EquipmentSystem) / 背包仓库(Inventory) /
##   材料金币进度(GameState) —— 本系统不碰，所有角色共用一份。
##
## 操控角色采用"换入换出"：切换时把当前角色的私有状态从
## Player/EquipmentSystem/SkillSystem 抽回档案，再把目标角色的私有状态灌进去。
## 这样 Player、战斗、UI 全部无需改动——它们读到的永远是"当前操控角色"。

const MAX_CHARACTERS := 6

# 角色档案数组。每个元素结构见 _make_character()
var characters: Array = []

# 当前操控的角色 id（空表示还没有任何角色）
var active_char_id: String = ""

signal roster_changed
signal active_character_changed(char_id: String)


func _ready():
	print("[RosterSystem] 角色名册系统初始化")


## ============ 角色档案结构 ============
## location: "idle"(闲置) / "deployed"(出击中) / "territory"(停驻领地)
## 字段为 P1/P3 预留，P0 阶段统一 idle。
func _make_character(class_id: String, char_name: String = "") -> Dictionary:
	if char_name == "":
		char_name = _default_name(class_id)
	return {
		"char_id": _generate_char_id(),
		"class_id": class_id,
		"name": char_name,
		"level": 1,
		"exp": 0.0,
		"attributes": {"strength": 0, "agility": 0, "vitality": 0, "intelligence": 0},
		"attribute_points": 0,
		"equipped": {},  # {slot: instance_id}
		"learned_skills": {},  # {skill_id: level}
		"skill_points": 0,
		"location": "idle",
	}


func _default_name(class_id: String) -> String:
	var cls = ConfigLoader.get_class_by_id(class_id)
	var base = cls.get("display_name", "冒险者")
	# 同职业按序号区分
	var count = 0
	for c in characters:
		if c.get("class_id", "") == class_id:
			count += 1
	return "%s%d" % [base, count + 1] if count > 0 else base


func _generate_char_id() -> String:
	var chars = "abcdefghijklmnopqrstuvwxyz0123456789"
	var result = "char_"
	for i in 10:
		result += chars[randi() % chars.length()]
	return result


## ============ 查询 ============
func get_character(char_id: String) -> Dictionary:
	for c in characters:
		if c.get("char_id", "") == char_id:
			return c
	return {}


func get_active_character() -> Dictionary:
	return get_character(active_char_id)


func has_character(char_id: String) -> bool:
	return not get_character(char_id).is_empty()


func character_count() -> int:
	return characters.size()


func is_full() -> bool:
	return characters.size() >= MAX_CHARACTERS


## 返回除操控角色外、可作为队友/可部署的角色（P2/P5 用）
func get_other_characters() -> Array:
	var result = []
	for c in characters:
		if c.get("char_id", "") != active_char_id:
			result.append(c)
	return result


## ============ 角色战斗属性计算（P2 队友 / P4 防御战复用）============
## 不切换全局状态，纯函数式算出任意角色的最终面板：
##   基础(职业) + 等级成长 + 属性点 + 装备(该角色的 equipped)。
## 注意：套装加成依赖 EquipmentSystem.active_sets(操控角色)，队友暂不计套装，
##       这是已知近似（AI 友方可接受）。
func compute_character_stats(char_id: String) -> Dictionary:
	var character = get_character(char_id)
	if character.is_empty():
		return {}
	var class_id = character.get("class_id", "class_warrior")
	var cls = ConfigLoader.get_class_by_id(class_id)
	var bs = cls.get("base_stats", {})

	var stats = {
		"max_hp": float(bs.get("max_hp", 100)),
		"damage": float(bs.get("damage", 10)),
		"attack_speed": float(bs.get("attack_speed", 1.0)),
		"move_speed": float(bs.get("move_speed", 300)),
		"crit_chance": float(bs.get("crit_chance", 0.05)),
		"crit_damage": float(bs.get("crit_damage", 1.5)),
		"armor": float(bs.get("armor", 0)),
	}

	# 等级成长（同 Player._on_level_up 的 level_curve）
	var level = int(character.get("level", 1))
	var curve = ConfigLoader.get_balance_config().get("level_curve", {})
	var per_level = curve.get("stats_per_level", {})
	stats["max_hp"] += float(per_level.get("max_hp", 0)) * (level - 1)
	stats["damage"] += float(per_level.get("damage", 0)) * (level - 1)

	# 属性点加成（简化版，对齐 Player._apply_attribute_bonuses 的主要项）
	_apply_char_attributes(character, stats)

	# 装备加成（用该角色自己的 equipped，复用 EquipmentSystem 的默认参数桩）
	if has_node("/root/EquipmentSystem"):
		var equipped = character.get("equipped", {})
		var total = EquipmentSystem.get_total_stats(equipped)
		stats["max_hp"] += total.get("max_hp", 0)
		stats["damage"] += total.get("damage", 0)
		stats["attack_speed"] *= total.get("attack_speed_mult", 1.0)
		stats["move_speed"] *= total.get("move_speed_mult", 1.0)
		stats["crit_chance"] += total.get("crit_chance", 0)
		stats["crit_damage"] += total.get("crit_damage", 0)
		stats["armor"] += total.get("armor", 0)

	stats["crit_chance"] = min(stats["crit_chance"], 0.75)
	stats["attack_speed"] = min(stats["attack_speed"], 3.0)
	return stats


## 角色属性点 -> 数值（与 Player._apply_attribute_bonuses 主项一致）
func _apply_char_attributes(character: Dictionary, stats: Dictionary):
	var attrs = character.get("attributes", {})
	var cfg = ConfigLoader.get_balance_config().get("attributes", {})
	var str_val = int(attrs.get("strength", 0))
	if str_val > 0:
		var c = cfg.get("strength", {})
		stats["damage"] += str_val * float(c.get("damage_flat", 0))
		stats["damage"] *= (1.0 + str_val * float(c.get("damage_percent", 0)))
	var agi_val = int(attrs.get("agility", 0))
	if agi_val > 0:
		var c = cfg.get("agility", {})
		stats["attack_speed"] += agi_val * float(c.get("attack_speed", 0))
		stats["crit_chance"] += agi_val * float(c.get("crit_chance", 0))
	var vit_val = int(attrs.get("vitality", 0))
	if vit_val > 0:
		var c = cfg.get("vitality", {})
		stats["max_hp"] += vit_val * float(c.get("max_hp", 0))
		stats["armor"] += vit_val * float(c.get("armor", 0))


## 计算角色综合战力（单一数值，用于 P4 防御战强度对比 / UI 展示）
func get_character_power(char_id: String) -> float:
	var s = compute_character_stats(char_id)
	if s.is_empty():
		return 0.0
	# 战力 = 有效HP × DPS 的简化估算
	var dps = (
		s.get("damage", 0)
		* s.get("attack_speed", 1.0)
		* (1.0 + s.get("crit_chance", 0) * (s.get("crit_damage", 1.5) - 1.0))
	)
	var ehp = s.get("max_hp", 0) * (1.0 + s.get("armor", 0) / 100.0)
	return dps * 0.5 + ehp * 0.5


## ============ 创建/删除 ============
## 创建新角色。成功返回 char_id，失败返回空串。
## set_active=true 时立即切换为操控角色（会先同步当前角色）。
func create_character(class_id: String, char_name: String = "", set_active: bool = true) -> String:
	if is_full():
		push_warning("[RosterSystem] 角色已满(%d)，无法创建" % MAX_CHARACTERS)
		return ""
	if ConfigLoader.get_class_by_id(class_id).is_empty():
		push_warning("[RosterSystem] 未知职业: %s" % class_id)
		return ""

	var character = _make_character(class_id, char_name)
	# 起手武器：生成一个独立实例（账号共享实例池）
	_grant_starting_weapon(character)
	characters.append(character)
	print("[RosterSystem] 创建角色: %s (%s)" % [character["name"], class_id])

	if set_active:
		# 先把旧角色私有状态抽回，再切换
		_sync_active_from_systems()
		active_char_id = character["char_id"]
		_apply_character_to_systems(character["char_id"])
		active_character_changed.emit(active_char_id)

	roster_changed.emit()
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()
	return character["char_id"]


## 给新角色发起手武器（实例进账号实例池，instance_id 记入角色 equipped）
func _grant_starting_weapon(character: Dictionary):
	var cls = ConfigLoader.get_class_by_id(character["class_id"])
	var starting_weapon = cls.get("starting_weapon", "")
	if starting_weapon == "" or not has_node("/root/EquipmentSystem"):
		return
	var template = ConfigLoader.get_equipment_by_id(starting_weapon)
	if template.is_empty():
		return
	var instance_id = EquipmentSystem.roll_equipment(
		starting_weapon, template.get("rarity", "common")
	)
	if instance_id != "":
		var slot = template.get("slot", "weapon")
		character["equipped"][slot] = instance_id


## 删除角色。不能删最后一个；删的是操控角色时自动切到另一个。
func delete_character(char_id: String) -> bool:
	if characters.size() <= 1:
		push_warning("[RosterSystem] 不能删除最后一个角色")
		return false
	var idx := -1
	for i in characters.size():
		if characters[i].get("char_id", "") == char_id:
			idx = i
			break
	if idx == -1:
		return false

	# 回收该角色独占的装备实例（穿戴中的回背包，避免实例泄漏；背包满则销毁）
	_reclaim_equipment(characters[idx])
	characters.remove_at(idx)

	if active_char_id == char_id:
		# 切到列表第一个
		active_char_id = characters[0].get("char_id", "")
		_apply_character_to_systems(active_char_id)
		active_character_changed.emit(active_char_id)

	roster_changed.emit()
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()
	print("[RosterSystem] 删除角色: %s" % char_id)
	return true


## 把角色穿戴的装备放回背包（删除角色时调用）
func _reclaim_equipment(character: Dictionary):
	if not has_node("/root/Inventory"):
		return
	for slot in character.get("equipped", {}):
		var inst_id = character["equipped"][slot]
		if inst_id == null or inst_id == "":
			continue
		if not Inventory.add_to_backpack(inst_id):
			# 背包满：销毁实例避免泄漏
			if has_node("/root/EquipmentSystem"):
				EquipmentSystem.equipment_instances.erase(inst_id)


## ============ 切换操控角色 ============
## 把当前角色私有状态存回档案，载入目标角色。
func switch_character(char_id: String) -> bool:
	if char_id == active_char_id:
		return true
	if not has_character(char_id):
		push_warning("[RosterSystem] 角色不存在: %s" % char_id)
		return false
	_sync_active_from_systems()
	active_char_id = char_id
	_apply_character_to_systems(char_id)
	active_character_changed.emit(active_char_id)
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()
	print("[RosterSystem] 切换操控角色: %s" % char_id)
	return true


## 把 Player/EquipmentSystem/SkillSystem 的当前实时状态抽回操控角色档案。
## 在切换前、存档前调用，确保档案是最新的。
func _sync_active_from_systems():
	var character = get_active_character()
	if character.is_empty():
		return

	# 装备穿戴（来自 EquipmentSystem，私有）
	if has_node("/root/EquipmentSystem"):
		character["equipped"] = EquipmentSystem.serialize_equipped()

	# 技能（来自 SkillSystem，私有）
	if has_node("/root/SkillSystem"):
		character["learned_skills"] = SkillSystem.learned_skills.duplicate()
		character["skill_points"] = SkillSystem.skill_points_unspent

	# 等级/经验/属性（来自 Player，若在场景里）
	var player = _find_player()
	if player and player.get("current_level") != null:
		character["level"] = player.current_level
		character["exp"] = player.current_exp
		if player.get("attributes") != null:
			character["attributes"] = player.attributes.duplicate()
		if player.get("attribute_points_unspent") != null:
			character["attribute_points"] = player.attribute_points_unspent


## 把目标角色档案灌进 GameState/EquipmentSystem/SkillSystem/Player。
func _apply_character_to_systems(char_id: String):
	var character = get_character(char_id)
	if character.is_empty():
		return

	# 职业（GameState，影响 Player._apply_class 与技能过滤）
	if has_node("/root/GameState"):
		GameState.selected_class_id = character.get("class_id", "class_warrior")

	# 技能
	if has_node("/root/SkillSystem"):
		SkillSystem.learned_skills = character.get("learned_skills", {}).duplicate()
		SkillSystem.skill_points_unspent = character.get("skill_points", 0)
		SkillSystem.set_current_class(character.get("class_id", ""))
		SkillSystem.skill_points_changed.emit(SkillSystem.skill_points_unspent)

	# 装备穿戴（实例池是共享的，这里只切换"穿了哪些"）
	if has_node("/root/EquipmentSystem"):
		EquipmentSystem.deserialize_equipped(character.get("equipped", {}))

	# Player（若在场景里）：等级/经验/属性 + 重算
	var player = _find_player()
	if player and player.get("current_level") != null:
		player.current_level = character.get("level", 1)
		player.current_exp = character.get("exp", 0.0)
		if player.get("attributes") != null:
			player.attributes = character.get("attributes", {}).duplicate()
		if player.get("attribute_points_unspent") != null:
			player.attribute_points_unspent = character.get("attribute_points", 0)
		if player.has_method("_apply_class"):
			player._apply_class()
		if player.has_method("_calculate_exp_to_next_level"):
			player._calculate_exp_to_next_level()
		if player.has_method("recalculate_stats"):
			player.recalculate_stats()


func _find_player():
	var tree = get_tree()
	if tree == null:
		return null
	var p = tree.get_first_node_in_group("player")
	if p == null or not is_instance_valid(p):
		return null
	return p


## ============ 序列化（SaveSystem 调用）============
## 存档前务必先 _sync_active_from_systems()，由 SaveSystem 统一触发。
func serialize() -> Dictionary:
	return {
		"characters": characters.duplicate(true),
		"active_char_id": active_char_id,
	}


func deserialize(data: Dictionary):
	characters = data.get("characters", []).duplicate(true)
	active_char_id = data.get("active_char_id", "")
	# 兜底：active 无效则指向第一个
	if not has_character(active_char_id) and characters.size() > 0:
		active_char_id = characters[0].get("char_id", "")
	roster_changed.emit()
	print("[RosterSystem] 加载名册: %d 个角色，操控=%s" % [characters.size(), active_char_id])


## 把存档前的实时状态同步进档案（SaveSystem 在收集数据前调用）
func sync_before_save():
	_sync_active_from_systems()


## ============ 旧档迁移 ============
## 旧存档（无 roster）把单角色数据包装成名册第一个角色。
## char_data 是旧格式的 character 字典。
func migrate_from_legacy(char_data: Dictionary):
	var character = _make_character(char_data.get("class_id", "class_warrior"))
	character["level"] = char_data.get("level", 1)
	character["exp"] = char_data.get("current_exp", 0.0)
	character["attributes"] = char_data.get(
		"attributes", {"strength": 0, "agility": 0, "vitality": 0, "intelligence": 0}
	)
	character["attribute_points"] = char_data.get("attribute_points_unspent", 0)
	character["equipped"] = char_data.get("equipped", {})
	character["learned_skills"] = char_data.get("learned_skills", {})
	character["skill_points"] = char_data.get("skill_points_unspent", 0)
	characters = [character]
	active_char_id = character["char_id"]
	roster_changed.emit()
	print("[RosterSystem] 旧档迁移：单角色 -> 名册")
