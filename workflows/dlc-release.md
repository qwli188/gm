# DLC 发布流程（DLC Release Workflow）

> DLC = 新内容包（新职业/新副本/新装备套装）。
> 配置表驱动架构的最大价值体现：加 DLC = 填表 + 加美术,代码不动。

---

## 一、DLC 内容规划

典型 DLC 包含：
- 1 个新职业（或新玩法模式）
- 1-2 个新副本
- 10-20 件新装备（含新套装）
- 3-5 个新技能
- 新怪物/Boss

**定价参考**：本体 $5,DLC $2-3。

---

## 二、标准流程（7 步）

```
制作人确定 DLC 方向
   ↓
1. DLC 规划（游戏策划）→ 主题、内容清单
   ↓
2. 内容设计（内容设计师）→ 填配置表（id 加 dlc 前缀）
   ↓
3. 数值平衡（数值策划）→ 确保不破坏现有平衡
   ↓
4. 美术资源（美术）→ 新素材、授权记录
   ↓
5. 实现与测试（程序 + 测试）→ 验证 DLC 开关
   ↓
6. 制作人验收 ← 决策点
   ↓
7. 打包发布（程序）→ 导出、上架
```

---

## 三、关键步骤详解

### 步骤 1：DLC 规划

**游戏策划要做**：
- 确定主题（如"DLC1:冰霜女巫"）
- 列出内容清单：
  - 新职业：冰霜女巫（远程、控制）
  - 新副本：冰封神殿
  - 新装备：冰系套装 15 件
  - 新技能：5 个冰系技能
  - 新怪物：冰元素、霜巨人、冰龙Boss
- 确认与本体内容的联动（冰系能和火系对抗吗？）
- 确认开发时间（通常 1-2 个月）

**输出**：DLC 设计文档

---

### 步骤 2：内容设计

**关键原则**：所有新内容 id 加 DLC 前缀

```json
{
  "id": "dlc1_weapon_frost_staff",
  "display_name": "寒霜法杖",
  "tags": ["ice", "magic", "dlc1"],
  "unlock_condition": "dlc1_purchased"
}
```

**好处**：
- 一眼看出哪些是 DLC 内容
- 代码可按 unlock_condition 过滤（玩家未购买则不出现）
- 方便测试开关（调试时可临时解锁 DLC）

---

### 步骤 3：数值平衡

**数值策划要确认**：
- DLC 内容不能比本体内容强太多（Pay to Win 嫌疑）
- 但也要有吸引力（否则没人买）
- 平衡点：DLC 提供**新玩法路线**，不是单纯更强

**示例**：
```
冰系套装 DPS = 本体火系套装 DPS（持平）
但冰系有控制能力（冻结敌人），火系有爆发伤害
→ 不同风格，各有优势
```

---

### 步骤 5：实现 DLC 开关

**程序要做**：
- 读取玩家是否拥有 DLC（从存档或平台 API）
- 加载配置时过滤 unlock_condition = "dlc1" 的内容
- 提供调试开关（开发时临时解锁所有 DLC）

**Godot 示例**：
```gdscript
func load_equipment_data():
    var all_items = JSON.parse_file("res://config/equipment.json")
    var unlocked = []
    for item in all_items:
        if check_unlock(item.unlock_condition):
            unlocked.append(item)
    return unlocked

func check_unlock(condition: String) -> bool:
    if condition == "default": return true
    if condition == "dlc1": return player_owns_dlc("dlc1")
    # ...
```

---

### 步骤 6：制作人验收

**制作人要验**：
- DLC 内容符合规划吗？
- 玩起来有新鲜感吗？
- 值这个价钱吗？
- 本体玩家会不会觉得被坑了？（DLC 不能必买）

---

### 步骤 7：打包发布

**程序要做**：
- Godot 导出（Windows/Mac/Linux）
- 配置 Steam DLC（需 Steamworks SDK）
- 上传到 Steam 后台
- 更新商店页面描述

**制作人要做**：
- 写 DLC 宣传文案
- 发更新公告
- 定价和促销策略

---

## 四、DLC vs 免费更新

| 类型 | 内容 | 何时用 |
|------|------|--------|
| 付费 DLC | 大块新内容（职业/副本/套装） | 值得单独定价的 |
| 免费更新 | Bug 修复、平衡调整、小内容 | 维护本体、回馈玩家 |

**策略**：付费 DLC 和免费更新穿插发，维持热度和好评。

---

## 五、成功标准

- [ ] DLC 主题明确、内容丰富
- [ ] 所有新内容 id 规范（dlc 前缀、unlock_condition）
- [ ] 数值平衡不破坏本体
- [ ] 美术风格统一、授权合规
- [ ] DLC 开关正常工作
- [ ] 制作人验收通过
- [ ] 打包上架成功
- [ ] 玩家反馈正面（物有所值）
