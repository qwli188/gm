# 素材采购清单（SHOPPING LIST）

> 本文件是 **asset-procurement.md 的实操补充**。给出可直接购买的精确链接、价格、授权、接入步骤。

---

## 0. 总预算估算

| 类别 | 推荐来源 | 价格 | 授权 |
|------|----------|------|------|
| 角色精灵（8 职业）| Kenney Roguelike Pack（免费 CC0）或 itch.io 付费包 | $0-15 | CC0 / 商用 |
| 敌人精灵（6 家族）| Kenney + itch.io 怪物包 | $0-10 | CC0 / 商用 |
| 装备图标 | Kenney Game Icons（免费）| $0 | CC0 |
| Boss 立绘 | 程序化占位先用，或 itch.io 定制 | $0-20 | 商用 |
| **总计** | | **$0-45** | |

**策略**：优先用 Kenney 免费 CC0 素材（质量高、风格统一、零授权风险），缺口用 itch.io 补齐。

---

## 1. 角色精灵（★★★ 最高优先级）

### 推荐方案 A：Kenney Roguelike Pack（免费 CC0）

- **链接**：https://www.kenney.nl/assets/roguelike-characters
- **价格**：免费
- **授权**：CC0（公有领域，可商用、无需署名）
- **规格**：16×16 原始尺寸（需放大到 64×64）
- **包含内容**：~100 个角色变体（战士/法师/刺客等都有）
- **接入步骤**：
  1. 下载 ZIP，解压得到 `roguelikeChar_transparent.png` 大图（968×526，单帧 16×16）
  2. 用 Aseprite/Photoshop/GIMP 裁切出 8 个职业对应的精灵（如战士取 row 0 column 0-3 做 4 帧 idle）
  3. 放大到 64×64（Nearest neighbor 插值保持像素风）
  4. 横向拼成 256×64 的 spritesheet
  5. 保存到 `assets/generated/characters/<class>/idle.png` 等

**优点**：免费、零授权风险、质量稳定。
**缺点**：需要手动裁切+拼接（工作量 ~2 小时），动画帧数有限（可能只有 idle/walk，attack/hurt 需自己拼或用同一帧）。

### 推荐方案 B：itch.io 付费包（更精致、动画齐全）

- **链接示例**：
  - https://0x72.itch.io/dungeontileset-ii （$10，16×16 暗黑地牢风格，含角色+敌人+tile）
  - https://rvros.itch.io/animated-pixel-hero （$5，32×32 完整动画）
- **优点**：动画完整（idle/walk/attack/hurt 都有）、风格统一、直接可用。
- **缺点**：需付费，授权需确认（一般是"商用 OK，需在 credits 署名"）。

---

## 2. 敌人精灵（★★★）

### 推荐方案 A：Kenney Roguelike Monster Pack（免费）

- **链接**：https://www.kenney.nl/assets/roguelike-monsters
- **规格**：16×16
- **包含**：骷髅/史莱姆/恶魔/冰元素等，覆盖 6 家族
- **接入**：同角色精灵，裁切+拼接

### 推荐方案 B：itch.io 怪物包

- https://0x72.itch.io/dungeontileset-ii 的怪物部分（已含在 $10 包里）

---

## 3. 装备图标（★★）

### 推荐：Kenney Game Icons（免费 CC0）

- **链接**：https://www.kenney.nl/assets/game-icons
- **规格**：多种尺寸可选，取 64×64
- **包含**：剑/弓/法杖/盔甲/戒指/护符等，全覆盖
- **接入**：
  1. 下载，找到对应图标（如 `sword.png`）
  2. 重命名为 `sword_common.png`（至少每个 kind 一张 common，稀有度靠 shader 描边区分）
  3. 放到 `assets/generated/icons/equipment/`

---

## 4. Boss 立绘（★）

当前 Boss 入场演出用粒子+冲击波，立绘是锦上添花。可先跳过，或用：

- **程序化生成占位图升级版**（当前已有 ShaderHelper 落地阴影，可再加轮廓描边）
- itch.io 定制委托（$20-50，6 张 Boss 立绘）

---

## 5. 接入自动化工具

已提供 `tools/asset_validator.py`（Python 脚本），功能：
- 检查所有素材文件是否存在
- 验证尺寸是否符合规范（64×64 或 256×64）
- 检查 `.import` 文件的 `filter` 是否关闭（像素风必须）

**用法**：
```bash
cd d:/桌面/CC工具/gm
python tools/asset_validator.py
```

输出示例：
```
=== 角色精灵检查 ===
  ✅ warrior/idle.png  尺寸:256×64  filter:✓
  ❌ warrior/attack.png 缺失
  ⚠️  ranger/ 目录不存在
```

---

## 6. 接入 SOP（标准操作流程）

每批素材接入按此流程：

1. **下载素材** → 解压到临时目录
2. **裁切+拼接**（如需） → Aseprite/Photoshop，横向拼成 256×64
3. **重命名** → 严格按 asset-procurement.md 的文件名（如 `warrior/idle.png`）
4. **放置** → 复制到 `project/assets/generated/<category>/`
5. **Godot Import** → 打开 Godot 编辑器，自动生成 `.import`
6. **关闭 Filter** → 选中图片 → Import 面板 → Filter 关闭 → Reimport（批量可用脚本）
7. **验证** → 运行 `python tools/asset_validator.py`
8. **测试** → 启动游戏，目视角色/敌人不再是色块
9. **记录授权** → 把素材来源/作者/授权写入 `assets/CREDITS.md`

---

## 7. 批量关闭 Filter 的脚本（可选）

如果手动一个个改 Import 太慢，用此脚本批量修改 `.import` 文件：

```bash
cd project/assets/generated
find . -name "*.import" -exec sed -i 's/filter=true/filter=false/g' {} \;
```

（Windows 下用 Git Bash 或 WSL 运行）

---

## 8. 时间估算

| 任务 | 工作量 | 说明 |
|------|--------|------|
| 下载 Kenney 3 个包 | 10 分钟 | 角色+怪物+图标 |
| 裁切+拼接角色（8 职业 × 5 文件）| 2 小时 | Aseprite 批处理可加速 |
| 裁切+拼接敌人（6 家族 × 3 文件）| 1 小时 | 同上 |
| 装备图标重命名+放置 | 30 分钟 | 批量重命名脚本 |
| Godot Import + Filter 关闭 | 20 分钟 | 批量脚本 |
| 验证+测试 | 30 分钟 | asset_validator.py + 游戏内目视 |
| **总计** | **~4.5 小时** | 单人完成，熟练后可压到 3 小时 |

---

## 9. 如果你没有图片编辑软件

推荐工具（免费）：
- **Aseprite**（付费 $20，或自己编译免费）— 像素画专用，批处理强
- **GIMP**（免费开源）— Photoshop 平替
- **Piskel**（在线免费）— https://www.piskelapp.com/ 轻量级像素编辑器

---

## 10. 下一步

素材接入完成后：
- 游戏画面立刻从"程序员美术"升级到"像素 ARPG"
- 可启动 C 路线（重构 Enemy/Town 巨型脚本）
- 或 D 路线（Boss 战设计+成就系统）
