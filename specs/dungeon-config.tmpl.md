# 副本配置表模板（dungeon-config）

> 对应 `project/config/dungeons.json`
> 副本 = 一局游戏的容器。每个副本有独特机制和 Boss，是"挑战更高难度"和"记忆点"的载体。

---

## 一、设计理念

每个副本应该有**至少一个独特机制**，让它和别的副本玩起来不一样。机制可以是：
- 环境机制（地面熔岩、周期黑暗、毒雾）
- 规则机制（限定时间、禁用某类技能、强制移动）
- Boss 机制（多阶段、召唤、狂暴）

副本有难度分层（难度词缀），装备越好能挑战越高难度，掉落越好——这是核心成长循环。

---

## 二、字段结构

```json
{
  "version": "1.0.0",
  "dungeons": [
    {
      "id": "dungeon_crypt",
      "display_name": "枯骨地穴",
      "theme": "undead",
      "tags": ["undead", "indoor"],
      "duration": 900,
      "wave_set": "waveset_crypt",
      "mechanic": {
        "kind": "periodic_darkness",
        "params": { "interval": 60, "duration": 8, "vision_radius": 120 },
        "description": "每60秒陷入8秒黑暗，视野缩小，考验走位记忆。"
      },
      "boss": {
        "enemy_id": "boss_bone_lord",
        "spawn_at": 600,
        "phases": [
          { "hp_threshold": 1.0, "behavior": "召唤骷髅+近战" },
          { "hp_threshold": 0.5, "behavior": "狂暴，召唤频率翻倍，地面出现尖刺" }
        ]
      },
      "difficulty_tiers": [
        { "tier": 1, "enemy_hp_mult": 1.0, "enemy_dmg_mult": 1.0, "drop_quality_bonus": 0.0, "unlock": "default" },
        { "tier": 2, "enemy_hp_mult": 1.5, "enemy_dmg_mult": 1.3, "drop_quality_bonus": 0.1, "unlock": "clear_tier_1" },
        { "tier": 3, "enemy_hp_mult": 2.2, "enemy_dmg_mult": 1.7, "drop_quality_bonus": 0.25, "unlock": "clear_tier_2" }
      ],
      "rewards": { "clear_exp": 100, "first_clear_unlock": "weapon_bone_blade" },
      "background": "res://assets/dungeons/crypt_bg.png",
      "unlock_condition": "default",
      "design_note": "新手第一个副本。黑暗机制制造紧张感，Boss双阶段。难度分层提供长期挑战。"
    }
  ]
}
```

---

## 三、字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | ✅ | 唯一标识，`dungeon_` 前缀 |
| `display_name` | string | ✅ | 显示名 |
| `theme` | string | ✅ | 主题（undead/demon/nature 等），影响怪物和美术 |
| `tags` | array | ✅ | 标签 |
| `duration` | int | ✅ | 单局时长（秒），到时通关或触发 Boss |
| `wave_set` | string | ✅ | 引用 waves.json 中的波次组 id |
| `mechanic` | object | ✅ | 副本独特机制（记忆点核心） |
| `boss` | object | ✅ | Boss 配置（含阶段） |
| `difficulty_tiers` | array | ✅ | 难度分层（长期挑战 + 成长循环） |
| `rewards` | object | ✅ | 通关奖励 |
| `background` | string | ✅ | 背景资源路径 |
| `unlock_condition` | string | ✅ | 解锁/归属 |
| `design_note` | string | ✅ | 设计意图 |

---

## 四、mechanic 机制类型

| kind | 参数 | 效果 |
|------|------|------|
| `periodic_darkness` | interval, duration, vision_radius | 周期黑暗 |
| `lava_floor` | spawn_interval, damage | 地面随机熔岩 |
| `poison_fog` | rise_time, dps | 毒雾从边缘逼近（逼迫向中心） |
| `time_pressure` | bonus_decay | 通关越快奖励越高 |
| `skill_restriction` | banned_tags | 禁用某类技能（强制换 Build） |
| `elite_rush` | wave_interval | 精英怪频繁出现 |

> 新增机制 kind 需经系统设计师 + 程序确认（要写代码）。
> 这些机制是副本"有趣、有记忆点"的关键，内容设计师要为每个副本想清楚机制。

---

## 五、难度分层（difficulty_tiers）

这是"装备越好挑战越高"的成长循环载体：
- 每层提升怪物血量/伤害倍率
- 每层提升掉落品质加成（drop_quality_bonus）
- 高层需要前层通关解锁
- 装备和构筑跟不上就打不过 → 驱动玩家回去刷装备变强

---

## 六、提交前自查

- [ ] JSON 合法，id 唯一、`dungeon_` 前缀
- [ ] mechanic 有明确机制（不是空壳副本）
- [ ] boss 引用的 enemy_id 存在且有阶段设计
- [ ] wave_set 引用的波次组存在
- [ ] difficulty_tiers 难度递增合理（数值策划复核）
- [ ] rewards 引用的解锁内容 id 存在
- [ ] design_note 说明记忆点是什么
