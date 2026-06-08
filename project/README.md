# DarkLoot ARPG - 开发者文档

> 暗黑奇幻 Loot ARPG - 装备构筑深度的 Roguelite 割草游戏
> 基于 GameForge 框架开发 | 配置表驱动架构

---

## 🎮 项目状态

**当前版本**：0.1.0-alpha（框架搭建完成）

**已完成**：
- ✅ Godot 4 项目初始化
- ✅ 配置表驱动架构搭建
- ✅ 核心系统代码（装备/词缀/配置加载）
- ✅ 初始配置表内容（7件装备/6个词缀/5个技能/4种敌人）
- ✅ 美术资源库规划

**待完成**：
- ⏳ 玩家控制实现（移动/攻击）
- ⏳ 敌人 AI 和生成
- ⏳ 战斗系统（伤害计算/碰撞检测）
- ⏳ UI 系统（血条/装备栏/技能栏）
- ⏳ 场景组装和游戏循环

---

## 📂 项目结构

```
gm/
├── GAME.md                    # GameForge 框架入口
├── constitution.md            # 开发铁律
├── roles/                     # 8个AI角色定义
├── workflows/                 # 6个标准工作流
├── specs/                     # 配置表规范模板
├── producer/                  # 制作人工作区
│   ├── PROGRESS.md           # 项目进度
│   ├── TODO.md               # 待办事项
│   ├── decisions.md          # 决策记录
│   └── QUICKSTART.md         # 快速上手指南
│
└── project/                   # 游戏项目
    ├── manifest.md            # 项目配置
    ├── GDD.md                 # 游戏设计文档
    │
    ├── src/                   # Godot 4 项目 ← 在这里打开
    │   ├── project.godot     # Godot项目配置
    │   ├── scenes/           # 场景文件
    │   ├── scripts/          # GDScript代码
    │   └── autoload/         # 全局单例系统
    │       ├── ConfigLoader.gd      # 配置表加载器
    │       ├── EquipmentSystem.gd   # 装备系统
    │       └── AffixSystem.gd       # 词缀系统
    │
    ├── config/                # 配置表（数据驱动核心）
    │   ├── equipment.json    # 装备配置（7件）
    │   ├── affixes.json      # 词缀配置（6个）
    │   ├── skills.json       # 技能配置（5个）
    │   ├── enemies.json      # 敌人配置（4种）
    │   └── balance.json      # 数值平衡参数
    │
    └── assets/                # 美术资源
        ├── README.md          # 资源库说明
        ├── CREDITS.md         # 授权记录
        └── DOWNLOAD_GUIDE.md  # 素材下载指引
```

---

## 🚀 快速开始

### 1. 安装 Godot 4

**下载**：https://godotengine.org/download/windows/

**版本要求**：Godot 4.3 或更高

**安装**：
- 下载 .exe 免安装版即可
- 或者 Steam 搜索 "Godot Engine" 安装

### 2. 打开项目

1. 启动 Godot 4
2. 点击"导入"（Import）
3. 浏览到 `D:\桌面\CC工具\gm\project\src\project.godot`
4. 点击"导入并编辑"（Import & Edit）

### 3. 验证配置表加载

项目打开后：
1. 按 F5 运行项目（会报错因为主场景未创建，这是正常的）
2. 查看 Godot 底部"输出"（Output）窗口
3. 应该看到类似日志：
   ```
   [ConfigLoader] 开始加载配置表...
   [ConfigLoader] 成功加载: equipment.json
   [ConfigLoader] 成功加载: affixes.json
   [ConfigLoader] 成功加载: skills.json
   [ConfigLoader] 成功加载: enemies.json
   [ConfigLoader] 成功加载: balance.json
   [ConfigLoader] 配置表加载完成
   ```

如果看到这些日志，说明**配置表驱动架构已正常工作**！

---

## 🎯 配置表驱动架构

### 核心理念

```
数据（配置表 JSON）  +  逻辑（代码）  =  游戏内容
   ↑ 制作人/AI填表       ↑ 程序写一次      ↑ 无限扩展
```

### 加新内容的标准流程

**示例：加一把"暴击之刃"**

1. 打开 `project/config/equipment.json`
2. 在 `weapons` 数组里追加：
```json
{
  "id": "weapon_crit_blade",
  "display_name": "暴击之刃",
  "slot": "weapon",
  "category": "sword",
  "rarity": "rare",
  "tags": ["melee", "physical", "crit"],
  "base_stats": {
    "damage": 20,
    "attack_speed": 1.3,
    "crit_chance": 0.20
  },
  "affix_slots": 2,
  "fixed_affixes": ["affix_crit_chance"],
  "icon": "res://assets/icons/equipment/crit_blade.png",
  "drop_level": 3,
  "unlock_condition": "default",
  "design_note": "暴击流核心武器，20%基础暴击率。"
}
```
3. 保存文件
4. 重启 Godot 项目
5. 新武器自动生效（能掉落、能穿戴、属性生效）

**代码一行不用改！**

---

## 🔧 核心系统说明

### ConfigLoader（配置加载器）

- 自动加载所有 JSON 配置表
- 提供查询接口（如 `get_equipment_by_id()`）
- 错误处理和日志输出

### EquipmentSystem（装备系统）

- 管理玩家当前装备（武器/护甲/饰品）
- 装备穿戴/卸下
- 属性应用到玩家
- 词缀效果应用

### AffixSystem（词缀系统）

- 管理装备词缀效果
- 实现词缀效果逻辑（吸血/点燃/属性加成）
- 标签联动和套装效果

---

## 📋 已有内容清单

### 装备（7件）
- 铁剑（common，无词缀）
- 吸血之刃（rare，固定吸血）
- 烈焰法杖（rare，固定火焰伤害）
- 皮甲（common）
- 铁板甲（uncommon）
- 铁戒指（common）
- 生命项链（uncommon）

### 词缀（6个）
- 嗜血（吸血15%）
- 烈焰（火焰伤害+8）
- 迅捷（攻速+20%）
- 精准（暴击率+10%）
- 再生（生命回复+2/秒）
- 点燃（持续伤害）

### 技能（5个）
- 火球术（主动攻击）
- 疾行（移速被动）
- 钢铁之躯（生命被动）
- 旋风斩（近战AOE）
- 致命一击（暴伤被动）

### 敌人（4种）
- 骷髅兵（基础杂兵）
- 僵尸（慢速坦克）
- 骸骨骑士（精英）
- 白骨领主（Boss）

---

## 🎨 美术资源

详见 `project/assets/DOWNLOAD_GUIDE.md`

**快速开始**：
1. 下载推荐的6个免费素材包（链接在文档中）
2. 解压到对应目录
3. 重新导入 Godot 项目

**占位方案**：
- 如果暂不下载美术，Godot 会用纯色方块占位
- 不影响功能测试

---

## 🔄 下一步开发

### 优先级 P0（核心玩法）

1. **创建主场景**
   - 地图背景
   - 玩家节点
   - 敌人生成器
   - UI 叠加层

2. **实现玩家控制**
   - WASD 移动
   - 手动/自动攻击切换
   - 装备穿戴交互

3. **实现敌人 AI**
   - 追踪玩家
   - 攻击判定
   - 死亡掉落

4. **实现战斗系统**
   - 伤害计算（读 balance.json）
   - 碰撞检测
   - 暴击/属性加成

### 优先级 P1（完善循环）

- 升级系统（经验值/三选一）
- 掉落系统（装备掉落/拾取）
- UI 系统（血条/装备栏/技能栏）
- 局外强化（金币升级）

### 优先级 P2（内容扩展）

- 更多装备和词缀
- 副本和波次系统
- Boss 阶段机制
- 音效和特效

---

## 🐛 已知问题

- 主场景未创建，按 F5 会报错（正常）
- 玩家控制代码未实现
- 美术资源为占位
- UI 系统缺失

---

## 📞 获取帮助

- 查看 `producer/QUICKSTART.md` 了解框架使用
- 查看 `project/GDD.md` 了解游戏设计
- 查看 `workflows/` 了解标准开发流程

---

## 📝 开发日志

**2026-06-02**：
- ✅ GameForge 框架搭建完成
- ✅ Godot 项目初始化
- ✅ 配置表架构搭建
- ✅ 初始内容填充

**下一里程碑**：核心玩法原型（玩家能移动攻击，敌人能追踪掉落）
