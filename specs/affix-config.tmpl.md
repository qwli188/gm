# 词缀配置表模板（affix-config）

> 对应 `project/config/affixes.json`
> 词缀是"装备构筑深度"的引擎——装备的特殊效果都来自词缀。
> 内容设计师设计词缀效果，数值策划平衡数值。

---

## 一、设计理念

词缀（Affix）是挂在装备上的"属性 / 效果模块"。同一个词缀可以出现在不同装备上，组合出千变万化的构筑。

词缀分两类：
- **属性词缀**：单纯加数值（+10 伤害、+15% 暴击）
- **效果词缀**：触发特殊机制（吸血、点燃、连锁闪电、召唤）—— 这是构筑深度的精华

构筑的乐趣 = 词缀之间的化学反应。例如：
- "点燃"词缀 + "燃烧伤害+50%"词缀 = 火焰流核心
- "吸血"词缀 + "攻速+30%"词缀 = 续航割草流

---

## 二、字段结构

```json
{
  "version": "1.0.0",
  "affixes": [
    {
      "id": "affix_fire_damage",
      "display_name": "烈焰",
      "type": "stat",
      "tags": ["fire", "elemental"],
      "effect": {
        "kind": "add_damage",
        "damage_type": "fire",
        "value": 8
      },
      "value_range": { "min": 5, "max": 12 },
      "tier": 1,
      "applicable_slots": ["weapon"],
      "design_note": "为武器附加火焰伤害，火焰流的入门词缀。"
    },
    {
      "id": "affix_lifesteal",
      "display_name": "嗜血",
      "type": "effect",
      "tags": ["lifesteal", "sustain"],
      "effect": {
        "kind": "lifesteal",
        "value": 0.10
      },
      "value_range": { "min": 0.05, "max": 0.15 },
      "tier": 2,
      "applicable_slots": ["weapon", "trinket"],
      "design_note": "攻击回复造成伤害的10%生命，续航流核心，配合高攻速最强。"
    }
  ]
}
```

---

## 三、字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | ✅ | 唯一标识，`affix_` 前缀 |
| `display_name` | string | ✅ | 显示名（暗黑风，如"烈焰""嗜血""狂暴"） |
| `type` | string | ✅ | `stat`（属性）或 `effect`（效果） |
| `tags` | array | ✅ | 标签，决定它属于哪个流派 |
| `effect` | object | ✅ | 效果定义（见第四节） |
| `value_range` | object | ⬜ | 随机词缀的数值范围（固定词缀可省略） |
| `tier` | int | ✅ | 词缀等级，越高越强、越稀有 |
| `applicable_slots` | array | ✅ | 能出现在哪些装备槽 |
| `design_note` | string | ✅ | 设计意图 + 推荐搭配 |

---

## 四、effect 效果类型（kind）

这是程序需要实现的"效果库"。每种 kind 程序实现一次，之后所有用它的词缀都能工作。

### 属性类（type: stat）

| kind | 参数 | 效果 |
|------|------|------|
| `add_stat` | stat, value | 增加某基础属性（平加） |
| `mult_stat` | stat, value | 某属性百分比增益 |
| `add_damage` | damage_type, value | 增加某类型伤害 |

### 效果类（type: effect）

| kind | 参数 | 效果 |
|------|------|------|
| `lifesteal` | value | 吸血（按伤害百分比回血） |
| `on_hit_chance` | chance, sub_effect | 命中时概率触发子效果 |
| `ignite` | dps, duration | 点燃（持续伤害） |
| `chain` | targets, falloff | 连锁（攻击跳跃到附近敌人） |
| `pierce` | count | 穿透（攻击穿过敌人） |
| `summon` | minion_id, count | 召唤随从 |
| `aura` | radius, sub_effect | 光环（范围持续效果） |

> 新增 kind 必须经系统设计师 + 程序确认（需要写新代码逻辑）。
> 用已有 kind 组合的新词缀，只需填表，不用改代码。

---

## 五、词缀分级（tier）

| tier | 强度 | 出现条件 |
|------|------|---------|
| 1 | 弱 | 低层副本、低稀有度装备 |
| 2 | 中 | 中层副本、稀有/史诗装备 |
| 3 | 强 | 高层副本、史诗/传奇装备 |
| 4 | 极强 | 仅传奇固定词缀 / 深渊难度掉落 |

---

## 六、设计词缀的检查清单

- [ ] 这个词缀属于哪个流派（tags）？
- [ ] 它能和哪些其他词缀/技能产生化学反应？
- [ ] 它是纯数值（stat）还是带机制（effect）？
- [ ] 用的 kind 是已有的，还是需要程序新写逻辑？
- [ ] tier 和数值强度匹配吗？
- [ ] design_note 写清楚推荐搭配了吗？

---

## 七、提交前自查

- [ ] JSON 合法
- [ ] id 唯一、`affix_` 前缀
- [ ] type / kind 用的是规范内的值
- [ ] 需要新 kind 的，已标注并经系统设计师确认
- [ ] value_range 合理（数值策划复核）
- [ ] applicable_slots 填写正确
- [ ] tags 能支撑流派构筑
