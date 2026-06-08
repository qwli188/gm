# 技能配置表模板（skill-config）

> 对应 `project/config/skills.json`
> 技能 = 局内升级三选一的选项 + 角色主动/被动能力。
> 技能和装备词缀共同构成构筑深度。

---

## 一、设计理念

本作 Roguelite 局制中，玩家每次升级从 3-4 个技能选项里选一个，逐步搭出本局的 Build。技能分：
- **主动技能**：玩家释放或自动触发的攻击/能力
- **被动技能**：持续生效的增益
- **强化技能**：强化已有技能/属性（升级现有选项）

技能也带 tags，与装备标签联动（如 `fire` 技能 + `fire` 装备 = 流派成型）。

---

## 二、字段结构

```json
{
  "version": "1.0.0",
  "skills": [
    {
      "id": "skill_fireball",
      "display_name": "火球术",
      "type": "active",
      "tags": ["fire", "magic", "ranged"],
      "effect": {
        "kind": "projectile",
        "damage_type": "fire",
        "base_damage": 15,
        "cooldown": 2.0,
        "projectile_count": 1,
        "extra": { "ignite_on_hit": false }
      },
      "max_level": 5,
      "level_scaling": { "damage_per_level": 5, "extra_projectile_at": [3, 5] },
      "icon": "res://assets/skills/fireball.png",
      "rarity": "common",
      "unlock_condition": "default",
      "design_note": "火焰流核心输出技能，升满可发射多发并联动点燃词缀。"
    },
    {
      "id": "skill_swift_boots",
      "display_name": "疾行",
      "type": "passive",
      "tags": ["mobility"],
      "effect": { "kind": "mult_stat", "stat": "move_speed", "value": 0.15 },
      "max_level": 3,
      "level_scaling": { "value_per_level": 0.10 },
      "icon": "res://assets/skills/swift_boots.png",
      "rarity": "common",
      "unlock_condition": "default",
      "design_note": "移动速度被动，提升走位和躲避，几乎万金油。"
    }
  ]
}
```

---

## 三、字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | ✅ | 唯一标识，`skill_` 前缀 |
| `display_name` | string | ✅ | 显示名 |
| `type` | string | ✅ | `active` / `passive` / `upgrade` |
| `tags` | array | ✅ | 标签，决定流派联动 |
| `effect` | object | ✅ | 效果定义（kind 复用词缀效果库 + 技能专属 kind） |
| `max_level` | int | ✅ | 局内最高可升几级 |
| `level_scaling` | object | ✅ | 每级如何变强 |
| `icon` | string | ✅ | 图标路径 |
| `rarity` | string | ✅ | 三选一时出现的权重（越稀有越少见） |
| `unlock_condition` | string | ✅ | 解锁/归属条件 |
| `design_note` | string | ✅ | 设计意图 + 推荐流派 |

---

## 四、技能专属 effect kind

除复用词缀效果库外，技能常用：

| kind | 参数 | 效果 |
|------|------|------|
| `projectile` | damage_type, base_damage, cooldown, projectile_count | 发射弹道 |
| `melee_swing` | damage, arc, cooldown | 近战挥砍 |
| `aura_skill` | radius, dps, damage_type | 范围光环 |
| `orbit` | count, damage, radius | 环绕弹（如旋转飞刀） |
| `summon_skill` | minion_id, count, duration | 召唤随从 |
| `dash` | distance, cooldown, invuln | 冲刺/闪避 |

---

## 五、三选一出现规则

- 升级时从可用技能池随机抽 3-4 个
- 已满级技能不再出现
- 出现权重受 rarity 影响（common 高，legendary 低）
- 可设计"协同提示"：已选火焰技能时，火焰相关技能权重提升（引导成型流派）

> 具体抽取算法在 balance.json 配置，内容设计师只管定义技能本身。

---

## 六、提交前自查

- [ ] JSON 合法，id 唯一、`skill_` 前缀
- [ ] type / kind 规范
- [ ] 需要新 kind 的已标注并经系统设计师确认
- [ ] level_scaling 清楚每级如何变强
- [ ] tags 能与装备联动构筑
- [ ] design_note 写明推荐流派
