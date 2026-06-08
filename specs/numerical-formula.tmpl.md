# 数值公式模板（numerical-formula）

> 对应 `project/config/balance.json` 和数值策划的工作。
> 定义全局数值公式：成长曲线、伤害计算、掉落率、强化成本等。
> 这些是"代码读取的全局参数"，与具体内容（装备/怪物）分离。

---

## 一、设计理念

具体内容的数值（某把剑伤害10）放在内容配置表里；**全局规则**（伤害怎么算、经验怎么涨、掉落怎么定）放这里。

好处：调整全局手感（如"整体掉落率太低"）只改一处，不用动每个内容条目。

---

## 二、balance.json 结构

```json
{
  "version": "1.0.0",

  "level_curve": {
    "description": "局内升级所需经验",
    "formula": "base * (growth ^ (level-1))",
    "base_exp": 10,
    "growth": 1.15,
    "max_level": 50
  },

  "damage_formula": {
    "description": "最终伤害 = (基础+附加) * 增益 * 暴击 * 抗性系数",
    "crit_multiplier_base": 1.5,
    "resistance_factor": "damage * (1 - resist/(resist+100))"
  },

  "meta_progression": {
    "description": "局外永久强化",
    "stats": [
      { "id": "perm_hp", "display_name": "体魄", "per_level": 10, "max_level": 20, "cost_curve": { "base": 50, "growth": 1.3 } },
      { "id": "perm_damage", "display_name": "力量", "per_level": 2, "max_level": 20, "cost_curve": { "base": 50, "growth": 1.3 } }
    ]
  },

  "drop_rates": {
    "description": "装备掉落与品质权重",
    "base_equipment_drop": 0.03,
    "rarity_weights": {
      "common": 60, "uncommon": 25, "rare": 10, "epic": 4, "legendary": 1
    },
    "drop_level_scaling": "更高副本层数提升稀有度权重"
  },

  "skill_choice": {
    "description": "升级三选一抽取规则",
    "choices_count": 3,
    "rarity_weights": { "common": 60, "uncommon": 25, "rare": 12, "legendary": 3 },
    "synergy_boost": 1.5
  }
}
```

---

## 三、核心曲线说明

### 升级曲线（level_curve）
- 控制局内升级节奏。growth 越大，后期升级越慢
- 数值策划目标：前期快（每局前几分钟频繁升级=爽），后期慢（拉开节奏）

### 伤害公式（damage_formula）
- 统一的伤害计算管线，所有伤害来源走同一套
- 抗性用边际递减公式，避免堆抗无敌

### 局外强化（meta_progression）
- 永久成长项，用金币升级
- cost_curve 控制成长速度，growth 越大越肝
- 目标：让失败的局也有收获（金币），驱动"再来一局"

### 掉落率（drop_rates）
- base_equipment_drop：基础掉装概率
- rarity_weights：掉落时各稀有度的权重
- 高层副本提升稀有度权重（drop_quality_bonus 叠加）

### 三选一（skill_choice）
- synergy_boost：已选某流派标签时，同标签技能权重乘数（引导成型 Build）

---

## 四、数值评估指标

数值策划改动后，用这些指标自查：

| 指标 | 含义 | 健康范围（参考） |
|------|------|----------------|
| TTK | 击杀普通怪耗时 | 前期1-2秒，后期瞬杀 |
| Time To Level | 升级间隔 | 前期10-20秒，后期渐长 |
| 单局时长 | 一局游戏 | 10-20分钟 |
| Build 多样性 | 可行流派数 | ≥3（不能只有一个最优解） |
| 失败收益 | 阵亡也能拿到的金币/经验 | >0（不能一无所获） |

---

## 五、改动规范

- 每次改数值，记录：改了什么、原值、新值、为什么、影响哪些内容
- 全局参数改动影响面大，改前做影响分析，改后必须测试验证
- 不追求"绝对平衡"，追求"多种 Build 可行 + 持续爽感"
- 改动经制作人确认（涉及核心手感时）

---

## 六、提交前自查

- [ ] JSON 合法
- [ ] 改动记录了原值/新值/原因/影响
- [ ] 是否避免了唯一最优解（保护构筑多样性）
- [ ] 是否保留前期爽感和成长感
- [ ] 是否给出试玩验证方法
