extends Node
## PartySystem - 出击队伍管理（哪些其他角色随操控角色一起出击）
##
## 设计（见领地玩法大扩展 P2）：
## - 操控角色始终在队（玩家手操）。
## - 额外可带 0~MAX_COMPANIONS 个"其他角色"作为 AI 队友（Companion）。
## - 出击是临时状态，不进存档（每次出门前在 Town 选择）。
## - 队友角色的 location 在出击期间标记 deployed，归来恢复 idle。

const MAX_COMPANIONS := 3

# 当前选定的随行角色 id 列表（不含操控角色）
var companion_ids: Array = []

signal party_changed


func _ready():
	print("[PartySystem] 队伍系统初始化")


## 选定的随行角色数量
func companion_count() -> int:
	return companion_ids.size()


func is_in_party(char_id: String) -> bool:
	return char_id in companion_ids


func can_add() -> bool:
	return companion_ids.size() < MAX_COMPANIONS


## 添加随行角色（不能是操控角色，不能超上限）
func add_companion(char_id: String) -> bool:
	if not can_add():
		return false
	if char_id in companion_ids:
		return false
	if has_node("/root/RosterSystem"):
		if char_id == RosterSystem.active_char_id:
			return false
		if not RosterSystem.has_character(char_id):
			return false
	companion_ids.append(char_id)
	party_changed.emit()
	return true


func remove_companion(char_id: String) -> bool:
	if char_id in companion_ids:
		companion_ids.erase(char_id)
		party_changed.emit()
		return true
	return false


func toggle_companion(char_id: String) -> bool:
	if char_id in companion_ids:
		remove_companion(char_id)
		return false
	add_companion(char_id)
	return char_id in companion_ids


## 清空队伍（操控角色切换时调用，避免把新操控角色当队友）
func clear():
	companion_ids.clear()
	party_changed.emit()


## 出击前校验：移除已不存在或等于操控角色的 id
func sanitize():
	if not has_node("/root/RosterSystem"):
		return
	var active = RosterSystem.active_char_id
	companion_ids = companion_ids.filter(
		func(cid): return cid != active and RosterSystem.has_character(cid)
	)
	# 超员裁剪
	if companion_ids.size() > MAX_COMPANIONS:
		companion_ids = companion_ids.slice(0, MAX_COMPANIONS)


## 获取随行角色档案列表（出击时 MainScene 用来 spawn）
func get_companion_characters() -> Array[Dictionary]:
	sanitize()
	var result: Array[Dictionary] = []
	if has_node("/root/RosterSystem"):
		for cid in companion_ids:
			var c = RosterSystem.get_character(cid)
			if not c.is_empty():
				result.append(c)
	return result
