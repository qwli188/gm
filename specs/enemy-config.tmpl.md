# 敌人配置表模板（enemy-config）

> 对应 `project/config/enemies.json`
> 定义所有怪物、精英、Boss 的属性和行为。

---

## 一、设计理念

敌人分三档：
- **普通怪**：成群出现，提供割草爽感和经验/掉落
- **精英怪**：更强、带特殊能力，掉落更好，制造小高潮
- **Boss**：副本核心挑战，有独特机制（阶段、技能），是记忆点

敌人行为也尽量配置化：移动方式、攻击方式、特殊能力都用字段描述，程序按字段执行。

---

## 二、字段结构

```json
{
  "version": "1.0.0",
  "enemies": [
    {
      "id": "enemy_skeleton",
      "display_name": "骷髅兵",
      "rank": "normal",
      "tags": ["undead", "melee"],
      "base_stats": {
        "max_hp": 20,
        "damage": 5,
        "move_speed": 60,
        "attack_speed": 1.0,
        "attack_range": 30
      },
      "behavior": {
        "movement": "chase",
        "attack": "melee_contact"
      },
      "abilities": [],
      "drop_table": {
        "exp": 3,
        "gold": { "min": 1, "max": 3 },
        "equipment_drop_chance": 0.02
      },
      "sprite": "res://assets/enemies/skeleton.png",
      "spawn_level": 1,
      "unlock_condition": "default",
      "design_note": "最基础的暗黑系杂兵，成群冲锋，割草主力。"
    }
  ]
}
```

---

## 三、字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | ✅ | 唯一标识，`enemy_`/`elite_`/`boss_` 前缀 |
| `display_name` | string | ✅ | 显示名 |
| `rank` | string | ✅ | `normal` / `elite` / `boss` |
| `tags` | array | ✅ | 标签（undead/demon/beast 等，可被装备克制联动） |
| `base_stats` | object | ✅ | 基础属性 |
| `behavior` | object | ✅ | 移动和攻击方式 |
| `abilities` | array | ⬜ | 特殊能力 id 列表（精英/Boss 用） |
| `drop_table` | object | ✅ | 掉落（经验、金币、装备概率） |
| `sprite` | string | ✅ | 精灵图路径 |
| `spawn_level` | int | ✅ | 从第几层开始出现 |
| `unlock_condition` | string | ✅ | 解锁/归属 |
| `design_note` | string | ✅ | 设计意图 |

---

## 四、behavior 行为类型

### movement（移动）
| 值 | 行为 |
|----|------|
| `chase` | 直线追玩家 |
| `ranged_keep_distance` | 远程，保持距离 |
| `charge` | 蓄力冲锋 |
| `wander` | 游荡（低威胁） |
| `summon_stay` | 原地召唤，不动 |

### attack（攻击）
| 值 | 行为 |
|----|------|
| `melee_contact` | 接触造成伤害 |
| `melee_swing` | 近战挥击（有前摇） |
| `ranged_projectile` | 发射弹道 |
| `aoe_ground` | 地面范围攻击 |

---

## 五、abilities 特殊能力（精英/Boss）

特殊能力单独定义（可放 enemies.json 的 abilities 段或独立），常见：
- `split`：死亡时分裂成小怪
- `enrage`：血量低于阈值后狂暴（攻速/伤害提升）
- `shield`：周期性获得护盾
- `summon_adds`：召唤增援
- `phase_change`：Boss 阶段转换（血线触发新机制）

> Boss 的"阶段机制"在 dungeons.json 的 boss 段或这里的 abilities 定义，是副本记忆点的核心。

---

## 六、提交前自查

- [ ] JSON 合法，id 唯一且前缀正确（enemy_/elite_/boss_）
- [ ] rank、behavior 用规范内的值
- [ ] drop_table 合理（数值策划复核掉落率）
- [ ] abilities 引用的能力已定义
- [ ] sprite 路径填写（或标注 [待美术]）
- [ ] Boss 是否有独特机制（记忆点）
