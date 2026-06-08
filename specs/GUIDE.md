# 配置表规范编写指南（GUIDE）

> 新加入的 AI Agent（尤其内容设计师、程序）必读。
> 本指南说明 GameForge 的配置表怎么组织、怎么写、怎么扩展。

---

## 一、为什么用配置表驱动

我们的制作人不写代码。如果每加一把武器、一个怪都要改代码，那制作人无法参与、AI 也容易出错、加 DLC 成本极高。

所以我们把**所有游戏内容数据化**：

```
内容（数据）放 config/*.json  ←  内容设计师 / 制作人能看懂、能改
逻辑（代码）放 src/scripts/   ←  程序写一次，读配置执行
```

加新内容 = 往 JSON 追加一条，代码不动。这就是"装备构筑深度能无限扩展"和"DLC 靠填表"的根基。

---

## 二、配置表清单

| 文件 | 内容 | 负责角色 |
|------|------|---------|
| `config/equipment.json` | 所有装备（武器/护甲/饰品） | 内容设计师 |
| `config/affixes.json` | 词缀池（装备上的随机/固定属性） | 内容设计师 + 数值策划 |
| `config/skills.json` | 技能 / 局内升级选项 | 内容设计师 |
| `config/enemies.json` | 怪物属性和行为 | 内容设计师 |
| `config/dungeons.json` | 副本配置（机制、阶段、奖励） | 内容设计师 |
| `config/waves.json` | 每个副本的怪物波次 | 内容设计师 |
| `config/balance.json` | 全局数值参数（成长曲线、掉落率等） | 数值策划 |

每张表都有对应的 `specs/*.tmpl.md` 模板，定义字段结构。

---

## 三、通用约定（所有配置表都要遵守）

### 3.1 必备字段

每个内容条目都必须有：

| 字段 | 说明 |
|------|------|
| `id` | 全局唯一标识，英文小写 + 下划线，如 `sword_vampire` |
| `display_name` | 玩家看到的名字，如 `"吸血剑"` |
| `design_note` | 设计意图（为什么有这个东西），给人看的，不影响逻辑 |

### 3.2 id 命名规范

```
{类别前缀}_{名称}

武器:   weapon_iron_sword
护甲:   armor_leather_vest
饰品:   trinket_ruby_ring
词缀:   affix_fire_damage
技能:   skill_fireball
怪物:   enemy_skeleton
精英:   elite_skeleton_captain
Boss:   boss_lich_king
副本:   dungeon_crypt
```

- 只能用小写字母、数字、下划线
- 不能重名（程序靠 id 引用，重名会冲突）
- DLC 内容加前缀，如 `dlc1_weapon_frost_blade`，便于区分和按 DLC 开关

### 3.3 引用关系

配置表之间通过 id 互相引用。例如装备引用词缀：

```json
{
  "id": "weapon_vampire_blade",
  "affixes": ["affix_lifesteal", "affix_fire_damage"]
}
```

**铁律**：引用的 id 必须真实存在，否则程序加载会报错。提交前自查。

### 3.4 标签系统（tags）— 构筑深度的关键

用标签把内容归类，实现"联动"和"流派"：

```json
{
  "id": "weapon_flame_staff",
  "tags": ["fire", "magic", "ranged"]
}
```

标签的用途：
- 套装效果："装备 3 件 `fire` 标签的物品，火焰伤害 +50%"
- 技能联动："`fire` 技能命中带 `oil` 标签的敌人，触发爆炸"
- 流派构筑：玩家围绕某个标签（火焰流、吸血流、召唤流）凑装备

**这是"装备构筑深度"在数据层的实现方式。** 内容设计师设计每件装备时都要想：它属于哪些标签？能加入哪些流派？

---

## 四、JSON 写法规范

### 4.1 结构

每张表是一个顶层对象，内含一个数组：

```json
{
  "version": "1.0.0",
  "items": [
    { "id": "...", "display_name": "...", ... },
    { "id": "...", "display_name": "...", ... }
  ]
}
```

- `version`：配置表版本，改结构时升级
- `items`：内容数组（不同表可能叫 weapons / enemies / dungeons）

### 4.2 数值写法

- 整数直接写：`"damage": 10`
- 小数表示百分比时注明：`"lifesteal": 0.15`（= 15%），并在 design_note 说明
- 不要在 JSON 里写计算式，只写最终值（计算逻辑在 balance.json + 代码）

### 4.3 资源路径

美术/音效路径用 Godot 的 `res://` 开头：

```json
{
  "icon": "res://assets/items/sword_vampire.png"
}
```

资源还没做好时，先填占位路径并在 design_note 标注 `[待美术]`。

---

## 五、扩展（加 DLC）的标准流程

1. 内容设计师在对应 JSON 追加新条目（id 加 dlc 前缀）
2. 新条目用 `unlock_condition` 标注解锁/归属（如 `"unlock_condition": "dlc1"`）
3. 美术准备素材，填好 `icon` 等资源路径
4. 程序确认代码能读取新条目（通常无需改代码）
5. 测试验证新内容生效且不破坏旧内容
6. 数值策划确认新内容不破坏平衡

**全程不改代码逻辑，只增数据和资源。** 如果发现"必须改代码才能加这个内容"，说明系统设计有缺陷，要回到系统设计师那里把它配置化。

---

## 六、提交前自查（所有配置表通用）

- [ ] JSON 格式合法（能被解析）
- [ ] 每个条目有 id、display_name、design_note
- [ ] id 唯一、命名规范
- [ ] 引用的其他 id（词缀、技能、资源）都存在
- [ ] tags 填写正确，支持构筑/联动
- [ ] 数值含义清楚（百分比有注明）
- [ ] 符合"西方奇幻暗黑"题材
