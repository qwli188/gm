extends Node
## Inventory - 背包(40格) + 仓库(100格) 容量管理与转移
##
## 设计分层（见 PR-3 重构）：
## - EquipmentSystem：装备实例池(uuid→instance)、穿戴、属性汇总、套装、tooltip
## - Inventory(本系统)：只存 instance_id 的背包/仓库，负责容量上限/转移/销毁
## - GameState.materials：材料数量（Inventory 提供只读视图，便于材料 tab 复用）
## - SaveSystem：序列化以上三者
##
## 装备实例数据一律通过 EquipmentSystem 查询，Inventory 不持有实例本体。

# ============ 容量上限 ============
const MAX_BACKPACK_SIZE := 40
const MAX_WAREHOUSE_SIZE := 100

# ============ 存储（instance_id 数组）============
var backpack: Array = []
var warehouse: Array = []

signal backpack_changed()
signal warehouse_changed()

func _ready():
	print("[Inventory] 背包/仓库系统初始化 (背包%d/仓库%d)" % [MAX_BACKPACK_SIZE, MAX_WAREHOUSE_SIZE])

## ============ 查询 ============
## 获取装备完整数据（委托 EquipmentSystem）
func get_equipment_data(instance_id: String) -> Dictionary:
	if not has_node("/root/EquipmentSystem"):
		return {}
	return EquipmentSystem.get_equipment_instance_data(instance_id)

## 背包是否已满
func is_backpack_full() -> bool:
	return backpack.size() >= MAX_BACKPACK_SIZE

## 仓库是否已满
func is_warehouse_full() -> bool:
	return warehouse.size() >= MAX_WAREHOUSE_SIZE

## 背包剩余格数
func backpack_free_slots() -> int:
	return MAX_BACKPACK_SIZE - backpack.size()

## PLACEHOLDER_INVENTORY_METHODS

## ============ 操作 ============
## 加到背包末尾。返回 true=成功；false=背包满
func add_to_backpack(instance_id: String) -> bool:
	if instance_id == "":
		return false
	if is_backpack_full():
		print("[Inventory] 背包已满，无法添加: %s" % instance_id)
		return false
	if instance_id in backpack:
		push_warning("[Inventory] 重复添加同一实例: %s" % instance_id)
		return false
	backpack.append(instance_id)
	backpack_changed.emit()
	return true

## 从背包移到仓库（前提：仓库有空位）
func transfer_to_warehouse(instance_id: String) -> bool:
	if not instance_id in backpack:
		return false
	if is_warehouse_full():
		print("[Inventory] 仓库已满，无法存入")
		return false
	backpack.erase(instance_id)
	warehouse.append(instance_id)
	backpack_changed.emit()
	warehouse_changed.emit()
	return true

## 从仓库取回背包（前提：背包有空位）
func transfer_to_backpack(instance_id: String) -> bool:
	if not instance_id in warehouse:
		return false
	if is_backpack_full():
		print("[Inventory] 背包已满，无法取回")
		return false
	warehouse.erase(instance_id)
	backpack.append(instance_id)
	backpack_changed.emit()
	warehouse_changed.emit()
	return true

## 销毁装备：从背包/仓库移除 + 从 EquipmentSystem 实例池删除
## 注意：穿戴中的装备不能销毁（先卸下）
func destroy_equipment(instance_id: String) -> bool:
	# 检查是否穿戴中
	if has_node("/root/EquipmentSystem"):
		for slot in EquipmentSystem.SLOTS:
			if EquipmentSystem.equipped_items.get(slot) == instance_id:
				push_warning("[Inventory] 拒绝销毁穿戴中的装备: %s" % instance_id)
				return false

	var was_in_backpack = instance_id in backpack
	var was_in_warehouse = instance_id in warehouse
	backpack.erase(instance_id)
	warehouse.erase(instance_id)

	if has_node("/root/EquipmentSystem"):
		EquipmentSystem.equipment_instances.erase(instance_id)

	if was_in_backpack:
		backpack_changed.emit()
	if was_in_warehouse:
		warehouse_changed.emit()
	return was_in_backpack or was_in_warehouse

## ============ 材料 tab（只读视图，真源在 GameState）============
## 获取所有材料 {material_id: count}
func get_all_materials() -> Dictionary:
	if not has_node("/root/GameState"):
		return {}
	return GameState.materials.duplicate()

## 获取单种材料数量
func get_material_count(material_id: String) -> int:
	if not has_node("/root/GameState"):
		return 0
	return GameState.get_material(material_id)

## ============ 序列化（SaveSystem 调用）============
func serialize() -> Dictionary:
	return {
		"backpack": backpack.duplicate(),
		"warehouse": warehouse.duplicate(),
	}

func deserialize(data: Dictionary):
	backpack = data.get("backpack", []).duplicate()
	warehouse = data.get("warehouse", []).duplicate()
	# 清理无效 instance_id（实例池里可能已删除）
	if has_node("/root/EquipmentSystem"):
		backpack = backpack.filter(func(id): return EquipmentSystem.equipment_instances.has(id))
		warehouse = warehouse.filter(func(id): return EquipmentSystem.equipment_instances.has(id))
	backpack_changed.emit()
	warehouse_changed.emit()
	print("[Inventory] 恢复: 背包%d / 仓库%d" % [backpack.size(), warehouse.size()])

