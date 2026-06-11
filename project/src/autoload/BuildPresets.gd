extends Node
## BuildPresets - P10 BD 预设系统
##
## 每个角色（char_id）可保存最多 3 套预设。每套预设包含：
##   - equipped: {slot: instance_id}
##   - learned_skills: {skill_id: level}（仅记录,切预设需要重置技能并重新加点）
##   - attributes: {strength, agility, vitality, intelligence}
## 切换预设：
##   - 装备：从背包/穿戴池中查找 instance_id，重新穿戴；找不到的留空
##   - 属性/技能：弹窗提示玩家手动确认重分配（首版只切装备，技能/属性预留）

const MAX_PRESETS_PER_CHAR := 3

## 数据：{char_id: [preset0, preset1, preset2]}
var presets: Dictionary = {}

signal presets_changed(char_id: String)


func _ready():
	print("[BuildPresets] BD 预设系统初始化")


func get_presets(char_id: String) -> Array:
	return presets.get(char_id, [])


## 保存当前角色当前装备/属性/技能为某槽预设。slot_index 0~2
## 返回 {ok, reason}
func save_preset(char_id: String, slot_index: int, name: String = "") -> Dictionary:
	if slot_index < 0 or slot_index >= MAX_PRESETS_PER_CHAR:
		return {"ok": false, "reason": "槽位越界"}
	if not has_node("/root/RosterSystem"):
		return {"ok": false, "reason": "RosterSystem 未启用"}
	var character = RosterSystem.get_character(char_id)
	if character.is_empty():
		return {"ok": false, "reason": "角色不存在"}

	# 当前角色 = 操控角色：从 EquipmentSystem 抓最新；否则从档案
	var equipped = {}
	var skills = {}
	var attrs = {}
	if char_id == RosterSystem.active_char_id:
		equipped = EquipmentSystem.serialize_equipped() if has_node("/root/EquipmentSystem") else {}
		skills = SkillSystem.learned_skills.duplicate() if has_node("/root/SkillSystem") else {}
		# 属性来自 Player 节点（只读）
		var p = _find_player()
		if p and p.get("attributes") != null:
			attrs = p.attributes.duplicate()
		else:
			attrs = character.get("attributes", {}).duplicate()
	else:
		equipped = character.get("equipped", {}).duplicate()
		skills = character.get("learned_skills", {}).duplicate()
		attrs = character.get("attributes", {}).duplicate()

	var preset = {
		"name": name if name != "" else "预设%d" % (slot_index + 1),
		"equipped": equipped,
		"learned_skills": skills,
		"attributes": attrs,
		"saved_at": Time.get_datetime_string_from_system(true),
	}

	if not presets.has(char_id):
		presets[char_id] = []
	# 用空预设填充到 slot_index
	while presets[char_id].size() <= slot_index:
		presets[char_id].append({})
	presets[char_id][slot_index] = preset
	presets_changed.emit(char_id)
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()
	return {"ok": true, "name": preset["name"]}


## 加载预设到当前角色（仅装备部分；技能/属性走预留）
## 返回 {ok, reason, missing: [instance_ids]}
func load_preset(char_id: String, slot_index: int) -> Dictionary:
	var arr = presets.get(char_id, [])
	if slot_index < 0 or slot_index >= arr.size():
		return {"ok": false, "reason": "预设不存在"}
	var preset = arr[slot_index]
	if preset.is_empty():
		return {"ok": false, "reason": "预设为空"}
	if not has_node("/root/RosterSystem") or not has_node("/root/EquipmentSystem"):
		return {"ok": false, "reason": "系统不可用"}
	if char_id != RosterSystem.active_char_id:
		# 切换到目标角色
		RosterSystem.switch_character(char_id)

	var equipped = preset.get("equipped", {})
	var missing: Array = []
	# 先卸下当前所有装备到背包
	for slot in EquipmentSystem.SLOTS:
		var current = EquipmentSystem.equipped_items.get(slot)
		if current != null:
			EquipmentSystem.unequip_item(slot)
	# 从背包/仓库找回预设要求的 instance
	for slot in EquipmentSystem.SLOTS:
		var want_id = equipped.get(slot)
		if want_id == null or want_id == "":
			continue
		if not EquipmentSystem.equipment_instances.has(want_id):
			missing.append(want_id)
			continue
		# 在背包还是仓库
		var in_backpack = false
		if has_node("/root/Inventory"):
			if want_id in Inventory.backpack:
				in_backpack = true
			elif want_id in Inventory.warehouse:
				# 取回背包再穿
				Inventory.transfer_to_backpack(want_id)
				in_backpack = true
			# 已是穿戴态？（卸下后理论上回了背包）
		if in_backpack and has_node("/root/EquipmentSystem"):
			EquipmentSystem.equip_from_backpack(want_id)
	return {"ok": true, "name": preset.get("name", ""), "missing": missing}


func delete_preset(char_id: String, slot_index: int) -> bool:
	var arr = presets.get(char_id, [])
	if slot_index < 0 or slot_index >= arr.size():
		return false
	arr[slot_index] = {}
	presets[char_id] = arr
	presets_changed.emit(char_id)
	if has_node("/root/SaveSystem"):
		SaveSystem.mark_dirty()
	return true


func _find_player():
	var tree = Engine.get_main_loop()
	if tree and tree.has_method("get_first_node_in_group"):
		return tree.get_first_node_in_group("player")
	return null


# ============ 序列化 ============
func serialize() -> Dictionary:
	return {"presets": presets.duplicate(true)}


func deserialize(data: Dictionary):
	presets = data.get("presets", {}).duplicate(true)
	print("[BuildPresets] 加载预设: %d 个角色" % presets.size())
