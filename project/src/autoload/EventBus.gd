extends Node
## EventBus - 全局事件中枢
##
## 目的：解耦 31 个 autoload 间的直接引用，通过事件通信替代 get_node("/root/XXX") 调用。
##
## 使用示例：
##   # 发布事件
##   EventBus.equipment_changed.emit()
##   EventBus.enemy_died.emit(enemy_node)
##
##   # 订阅事件
##   EventBus.equipment_changed.connect(_on_equipment_changed)
##
## 迁移策略：
##   现有 signal（如 EquipmentSystem.equipment_changed）保留作为 deprecated 桥接，
##   逐步迁移订阅方到 EventBus，最终移除旧 signal。

## === 装备系统事件 ===
## 装备变更（穿戴/卸下/强化/词缀变化）
signal equipment_changed

## === 战斗系统事件 ===
## 伤害结算（target: Node2D, damage: float, is_crit: bool）
signal damage_dealt(target: Node2D, damage: float, is_crit: bool)

## 敌人死亡（enemy: Node2D）
signal enemy_died(enemy: Node2D)

## === 角色系统事件 ===
## 玩家升级（new_level: int）
signal player_level_up(new_level: int)

## 当前角色切换（character_data: Dictionary）
signal active_character_changed(character_data: Dictionary)

## === 词缀工坊事件 ===
## 重铸完成（item_data: Dictionary）
signal item_reforged(item_data: Dictionary)

## 装备升级完成（item_data: Dictionary, new_level: int）
signal item_upgraded(item_data: Dictionary, new_level: int)

## === 配置热加载事件 ===
## 配置文件重载（file_name: String）
signal config_reloaded(file_name: String)

## === 末期系统事件 ===
## 末期词缀变更（用于UI刷新）
signal endgame_modifiers_changed

## 裂隙开始（seed_id: String, modifiers: Array）
signal rift_started(seed_id: String, modifiers: Array)


func _ready() -> void:
	name = "EventBus"
	print("[EventBus] 全局事件总线已就绪")
	_bridge_legacy_signals()


## 桥接现有系统的 signal 到 EventBus（过渡期，避免破坏现有代码）
func _bridge_legacy_signals() -> void:
	# EquipmentSystem.equipment_changed → EventBus.equipment_changed
	if has_node("/root/EquipmentSystem"):
		var eq_sys := get_node("/root/EquipmentSystem")
		if not eq_sys.equipment_changed.is_connected(_forward_equipment_changed):
			eq_sys.equipment_changed.connect(_forward_equipment_changed)

	# CombatSystem.damage_dealt / enemy_died
	if has_node("/root/CombatSystem"):
		var combat := get_node("/root/CombatSystem")
		if not combat.damage_dealt.is_connected(_forward_damage_dealt):
			combat.damage_dealt.connect(_forward_damage_dealt)
		if not combat.enemy_died.is_connected(_forward_enemy_died):
			combat.enemy_died.connect(_forward_enemy_died)

	# AffixWorkshop 的各种完成事件
	if has_node("/root/AffixWorkshop"):
		var workshop := get_node("/root/AffixWorkshop")
		if not workshop.reforge_completed.is_connected(_forward_item_reforged):
			workshop.reforge_completed.connect(_forward_item_reforged)
		if not workshop.upgrade_completed.is_connected(_forward_item_upgraded):
			workshop.upgrade_completed.connect(_forward_item_upgraded)

	# ConfigLoader.config_reloaded
	if has_node("/root/ConfigLoader"):
		var cfg := get_node("/root/ConfigLoader")
		if not cfg.config_reloaded.is_connected(_forward_config_reloaded):
			cfg.config_reloaded.connect(_forward_config_reloaded)

	# EndgameSystem.modifiers_changed / rift_started
	if has_node("/root/EndgameSystem"):
		var endgame := get_node("/root/EndgameSystem")
		if not endgame.modifiers_changed.is_connected(_forward_endgame_modifiers_changed):
			endgame.modifiers_changed.connect(_forward_endgame_modifiers_changed)
		if not endgame.rift_started.is_connected(_forward_rift_started):
			endgame.rift_started.connect(_forward_rift_started)


## === 转发函数（桥接层，未来可移除） ===
func _forward_equipment_changed() -> void:
	equipment_changed.emit()


func _forward_damage_dealt(target: Node2D, damage: float, is_crit: bool) -> void:
	damage_dealt.emit(target, damage, is_crit)


func _forward_enemy_died(enemy: Node2D) -> void:
	enemy_died.emit(enemy)


func _forward_item_reforged(item_data: Dictionary) -> void:
	item_reforged.emit(item_data)


func _forward_item_upgraded(item_data: Dictionary) -> void:
	# 旧 signal 无 new_level 参数，从 item_data 提取
	var new_level: int = item_data.get("enhancement_level", 0)
	item_upgraded.emit(item_data, new_level)


func _forward_config_reloaded(file_name: String) -> void:
	config_reloaded.emit(file_name)


func _forward_endgame_modifiers_changed() -> void:
	endgame_modifiers_changed.emit()


func _forward_rift_started(seed_id: String, modifiers: Array) -> void:
	rift_started.emit(seed_id, modifiers)
