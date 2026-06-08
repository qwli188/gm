# 波次配置表模板（wave-config）

> 对应 `project/config/waves.json`
> 定义副本内怪物随时间生成的节奏。控制割草的强度曲线和爽感节奏。

---

## 一、设计理念

波次决定"什么时间、生成什么怪、生成多少"。好的波次曲线制造**张弛有度的节奏**：
- 开局轻松（让玩家起步、捡第一波装备）
- 中段渐强（数量和强度上升，配合玩家变强）
- 精英穿插（小高潮）
- Boss 前清场（喘息）→ Boss 战（高潮）

波次组（wave_set）被 dungeons.json 引用。一个副本对应一个波次组。

---

## 二、字段结构

```json
{
  "version": "1.0.0",
  "wave_sets": [
    {
      "id": "waveset_crypt",
      "display_name": "枯骨地穴波次",
      "waves": [
        {
          "start_time": 0,
          "end_time": 120,
          "spawns": [
            { "enemy_id": "enemy_skeleton", "rate": 2.0, "max_alive": 20 }
          ]
        },
        {
          "start_time": 120,
          "end_time": 300,
          "spawns": [
            { "enemy_id": "enemy_skeleton", "rate": 3.5, "max_alive": 40 },
            { "enemy_id": "enemy_zombie", "rate": 1.0, "max_alive": 15 }
          ]
        },
        {
          "start_time": 300,
          "end_time": 320,
          "spawns": [
            { "enemy_id": "elite_bone_knight", "count": 2, "burst": true }
          ]
        }
      ],
      "design_note": "开局纯骷髅热身，2分钟后混入僵尸加压，5分钟精英突袭制造小高潮。"
    }
  ]
}
```

---

## 三、字段说明

| 字段 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `id` | string | ✅ | 波次组唯一标识，`waveset_` 前缀 |
| `display_name` | string | ✅ | 显示名 |
| `waves` | array | ✅ | 波次列表（按时间分段） |
| `design_note` | string | ✅ | 节奏设计意图 |

### 每个 wave 段

| 字段 | 说明 |
|------|------|
| `start_time` | 该段开始时间（秒） |
| `end_time` | 该段结束时间（秒） |
| `spawns` | 该段生成的怪物配置 |

### 每个 spawn

| 字段 | 说明 |
|------|------|
| `enemy_id` | 生成的怪物（引用 enemies.json） |
| `rate` | 每秒生成数量（持续生成用） |
| `count` | 一次性生成总数（突袭用，配 burst） |
| `max_alive` | 同时存活上限（性能 + 难度控制） |
| `burst` | true = 一次性全部生成（精英突袭） |

---

## 四、节奏设计原则

- **开局 0-2 分钟**：低压力，让玩家捡装备、选前几个技能
- **中段**：逐步加 rate 和 max_alive，混入新怪种
- **精英突袭**：用 burst 制造紧张小高潮，间隔出现
- **Boss 前**：适当清场，给玩家喘息和准备
- **max_alive 是性能阀门**：割草游戏屏幕怪太多会卡，数值策划 + 程序共同把控上限

---

## 五、提交前自查

- [ ] JSON 合法，id 唯一、`waveset_` 前缀
- [ ] 引用的 enemy_id 都在 enemies.json 中存在
- [ ] 时间段不重叠或重叠是有意设计的
- [ ] max_alive 设了合理上限（防卡顿）
- [ ] 节奏有张弛（不是一条直线）
- [ ] design_note 说明节奏意图
