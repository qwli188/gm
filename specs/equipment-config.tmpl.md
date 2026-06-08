# 装备配置表模板（equipment-config）

> 对应 `project/config/equipment.json`
> 装备是本作的核心——"装备构筑深度"卖点的主要载体。
> 内容设计师按此模板设计装备，程序按此结构读取。

---

## 一、设计理念

装备不只是"属性数字"，而是**构筑（Build）的积木**。每件装备应该：
- 提供基础属性（攻击/防御/生命等）
- 带有词缀（来自 affixes.json，提供特殊效果）
- 拥有标签（tags，决定它能加入哪些流派和套装）
- 有稀有度（决定属性强度和词缀数量）

玩家的乐趣来自：刷到好装备 → 发现它能和现有装备/技能联动 → 凑出强力流派。

---

## 二、字段结构

```json
{
  "version": "1.0.0",
  "weapons": [
    {
      "id": "weapon_iron_sword",
      "display_name": "铁剑",
      "slot": "weapon",
      "category": "sword",
      "rarity": "common",
      "tags": ["melee", "physical"],
      "base_stats": {
        "damage": 10,
        "attack_speed": 1.0,
        "crit_chance": 0.05
      },
      "affix_slots": 0,
      "fixed_affixes": [],
      "icon": "res://assets/items/weapon_iron_sword.png",
      "drop_level": 1,
      "unlock_condition": "default",
      "design_note": "最基础的近战武器，新手起步装。无词缀槽，定位是构筑的起点。"
    }
  ]
}
```

---

## 三、字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | ✅ | 唯一标识，如 `weapon_iron_sword` |
| `display_name` | string | ✅ | 显示名 |
| `slot` | string | ✅ | 装备槽：`weapon` / `armor` / `trinket` |
| `category` | string | ✅ | 细分类：sword / axe / staff / vest / ring 等 |
| `rarity` | string | ✅ | 稀有度（见下表） |
| `tags` | array | ✅ | 标签，决定流派和套装联动 |
| `base_stats` | object | ✅ | 基础属性 |
| `affix_slots` | int | ✅ | 随机词缀槽数量（稀有度越高越多） |
| `fixed_affixes` | array | ✅ | 固定词缀 id 列表（传奇装备的特色效果） |
| `icon` | string | ✅ | 图标资源路径 |
| `drop_level` | int | ✅ | 从第几层副本开始掉落 |
| `unlock_condition` | string | ✅ | 解锁/归属条件（default / dlc1 / 成就 id） |
| `design_note` | string | ✅ | 设计意图 |

---

## 四、稀有度规范

| rarity | 中文 | 颜色 | affix_slots | 定位 |
|--------|------|------|-------------|------|
| `common` | 普通 | 白 | 0 | 起步装，纯基础属性 |
| `uncommon` | 优秀 | 绿 | 1 | 开始有变化 |
| `rare` | 稀有 | 蓝 | 2 | 构筑核心 |
| `epic` | 史诗 | 紫 | 3 | 强力构筑件 |
| `legendary` | 传奇 | 橙 | 2 + 固定特效 | 围绕它做流派（build-defining） |

> 传奇装备的关键不是属性高，而是 `fixed_affixes` 带来的**独特机制**，能定义一个流派。
> 例：传奇剑"嗜血"固定带"击杀回复全部生命"，催生"高风险贴脸割草"流派。

---

## 五、base_stats 可用属性

| 属性 | 含义 | 适用槽 |
|------|------|--------|
| `damage` | 基础伤害 | weapon |
| `attack_speed` | 攻击速度（次/秒） | weapon |
| `crit_chance` | 暴击率（0~1） | weapon/trinket |
| `crit_damage` | 暴击伤害倍率 | weapon/trinket |
| `attack_range` | 攻击范围 | weapon |
| `armor` | 护甲（减伤） | armor |
| `max_hp` | 生命上限 | armor/trinket |
| `move_speed` | 移动速度 | armor/trinket |
| `hp_regen` | 生命回复 | armor/trinket |

> 新增属性需先经系统设计师确认，并在 balance.json 定义其计算方式。

---

## 六、设计装备的检查清单

设计每件装备时问自己：
- [ ] 它属于哪些 tags？能加入哪个流派？
- [ ] 它和现有的哪些装备/技能/词缀能联动？
- [ ] 它的稀有度和 affix_slots 匹配吗？
- [ ] 如果是传奇，它的 fixed_affixes 能定义一个流派吗？
- [ ] drop_level 合理吗？（强装备不应过早掉落）
- [ ] design_note 写清楚它的构筑定位了吗？

---

## 七、提交前自查

- [ ] JSON 合法
- [ ] id 唯一且命名规范（weapon_/armor_/trinket_ 前缀）
- [ ] slot、rarity 用的是规范内的值
- [ ] fixed_affixes 引用的词缀 id 在 affixes.json 中存在
- [ ] affix_slots 与 rarity 对应
- [ ] icon 路径填写（或标注 [待美术]）
- [ ] tags 支持至少一种构筑路线
