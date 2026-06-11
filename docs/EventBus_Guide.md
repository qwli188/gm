# EventBus 使用指南

## 概述
EventBus 是全局事件中枢，用于解耦 31 个 autoload 间的直接引用。通过事件通信替代 `get_node("/root/XXX")` 调用。

## 核心原则
- **状态变更用事件**：装备变了、敌人死了、配置重载 → 发 signal
- **只读查询不用事件**：获取当前职业、当前角色数据 → 仍用 getter（`GameState.get_current_class()`）

## 使用方法

### 发布事件（发送方）
```gdscript
# 在状态变更后发出事件
func equip_item(slot: String, instance_id: String) -> void:
    # ... 业务逻辑 ...
    EventBus.equipment_changed.emit()  # 通知订阅方
```

### 订阅事件（接收方）
```gdscript
func _ready() -> void:
    # 连接到 EventBus 的 signal
    EventBus.equipment_changed.connect(_on_equipment_changed)
    EventBus.enemy_died.connect(_on_enemy_died)

func _on_equipment_changed() -> void:
    # 刷新 UI / 重新计算属性
    _refresh_stats()
```

## 当前支持的事件

### 装备系统
- `equipment_changed` — 装备变更（穿戴/卸下/强化/词缀）

### 战斗系统
- `damage_dealt(target: Node2D, damage: float, is_crit: bool)` — 伤害结算
- `enemy_died(enemy: Node2D)` — 敌人死亡

### 角色系统
- `player_level_up(new_level: int)` — 玩家升级
- `active_character_changed(character_data: Dictionary)` — 当前角色切换

### 词缀工坊
- `item_reforged(item_data: Dictionary)` — 重铸完成
- `item_upgraded(item_data: Dictionary, new_level: int)` — 装备升级完成

### 配置热加载
- `config_reloaded(file_name: String)` — 配置文件重载

### 末期系统
- `endgame_modifiers_changed` — 末期词缀变更
- `rift_started(seed_id: String, modifiers: Array)` — 裂隙开始

## 迁移策略（现有代码）

### 阶段 1：桥接（当前）
EventBus 自动桥接现有系统的 signal（`EquipmentSystem.equipment_changed` → `EventBus.equipment_changed`），新旧代码共存，零破坏。

### 阶段 2：逐步迁移订阅方
```gdscript
# 旧代码（保持工作）
get_node("/root/EquipmentSystem").equipment_changed.connect(_callback)

# 新代码（推荐）
EventBus.equipment_changed.connect(_callback)
```

### 阶段 3：移除旧 signal（可选，未来）
当所有订阅方迁移完成后，可删除原系统的 signal 定义和 EventBus 的桥接代码。

## 迁移示例
**TagSynergySystem** 已从 `EquipmentSystem.equipment_changed` 迁移到 `EventBus.equipment_changed`（commit 中可见）。

## 扩展新事件
在 `EventBus.gd` 中添加新 signal 定义，无需修改其他文件：
```gdscript
## 新事件：技能冷却完成
signal skill_cooldown_finished(skill_id: String)
```

发送方直接调用：
```gdscript
EventBus.skill_cooldown_finished.emit("skill_fireball")
```

## 何时不用 EventBus
- **只读查询**：`GameState.get_current_class()` 比事件简单直接
- **紧耦合的组件**：父子节点间用 `get_parent()` 或直接引用即可
- **性能敏感路径**：每帧触发的逻辑（如 `_process`）不适合事件

## 调试
所有事件发送会在控制台打印（开发模式），可通过搜索 `[EventBus]` 查看事件流。
