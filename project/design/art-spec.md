# DarkLoot 美术规范（ART SPEC）

> 本文件是 DarkLoot ARPG 的**视觉单一真源**。所有素材、特效、UI 配色一律以此为准。
> 代码层的颜色/排序/中文名常量收口在 `project/src/autoload/Schema.gd`，本文档是其设计依据与扩展规范。
> 新增任何视觉元素前，先对照本表。

---

## 0. 基调

**暗黑奇幻 · 黑暗纪元末世**。世界名「埃博利亚」，主题是拾荒者行会在古神遗祸的废土上刷宝求生。

- **整体色调**：低明度、高对比。背景偏暗（暗角 vignette 常驻），战利品与特效用高饱和点缀，形成"黑暗中的高光"。
- **参考坐标**：Diablo II 的阴郁 + Path of Exile 的词缀色彩语言 + 像素 ARPG 的可读性。
- **可读性优先**：任何时候，玩家要能一眼分辨——敌我、稀有度、危险区域（Boss AOE 预警）。视觉华丽度服从于可读性。

---

## 1. 稀有度配色（单一真源：`Schema.RARITY_COLOR`）

| 稀有度 | 中文 | 色值 | rank | 视觉规格（见 vfx.json）|
|--------|------|------|------|------|
| common | 普通 | `#C8C8C8` 灰白 | 0 | 无描边/粒子/光柱 |
| rare | 稀有 | `#4A90D9` 冷蓝 | 1 | 1px 冷光描边 |
| epic | 史诗 | `#9B4DCA` 幽紫 | 2 | 描边 + 紫色流光粒子 |
| legendary | 传奇 | `#E8A317` 辉金 | 3 | 描边 + 金色光环 + 拖尾 + 掉落光柱 |
| mythic | 神话 | `#E03131` 血红 | 4 | 全屏震屏 + 混沌粒子风暴 + 古神虚影 |

**铁律**：稀有度色值禁止在任何 `.gd`/`.json`/`.tscn` 里硬编码。一律走：
- GDScript：`Schema.rarity_color(r)` / `rarity_dark_color` / `rarity_glow_color` / `rarity_border_width` / `rarity_corner_radius` / `rarity_rank`
- 视觉成品（StyleBox/Gradient/富文本）：`RarityVisuals.*`（它内部已全部委托 Schema）

稀有度差异**必须多通道编码**（颜色 + 描边粗细 + 圆角 + 粒子等级），不能只靠颜色——照顾色觉障碍玩家。

---

## 2. 区域色温（6 大区域）

每个区域有专属色温，应用于：地面 tile 染色、环境暗角颜色、敌人 RANK_TINT 的基底、BGM 已对应。

| 区域 | 中文 | 主色温 | 暗角色 | 套装流派 | 敌人家族 |
|------|------|--------|--------|----------|----------|
| crypt | 安罗斯王陵 | 冷青灰 `#6B7A8F` | `#1A2230` | 白骨君王 set_bone | skeleton |
| swamp | 腐沼 | 黄绿 `#7A8F4A` | `#1F2A12` | 疫疠之主 set_plague | slime |
| forge | 熔炉/燃尽王座 | 橙红 `#D9622A` | `#2E1206` | 燃烬战甲 set_ember | demon |
| ice | 永眠之渊 | 蓝白 `#8FC4D9` | `#16242E` | 永冻王权 set_frost | ice |
| void | 虚空裂隙 | 紫黑 `#7A4ACA` | `#1A0E2E` | 虚空裂界 set_void | beast(void) |
| field | 荒野 | 中性褐绿 `#8F8456` | `#23200E` | 通用 | beast |

> **落地点**：这些色温目前只在 `SpriteLibrary.REGION_FAMILY` 和 BGM 里部分体现。A2 阶段 ThemeGenerator 将按当前副本 region 微调 UI 色温；DungeonTerrain 按 region 染色 tile。

---

## 3. 角色 / 敌人精灵规格

- **帧尺寸**：64×64（`SpriteLibrary.FRAME_SIZE`）。横向 spritesheet，每动画一张 PNG，4 帧/张（256×64）。
- **动画集**：角色 `idle/walk/attack/hurt` + `portrait`（头像，单帧）；敌人 `idle/attack/static`。
- **渲染缩放**：角色 ×2.6（Player）；敌人按 rank `SpriteLibrary.RANK_SCALE`（normal 2.4 / elite 3.0 / boss 4.2 / field_boss 3.6）。
- **rank 染色**：`SpriteLibrary.RANK_TINT`（精英偏金、Boss 偏红）。
- **朝向**：默认朝右，左行用 `flip_h`。素材只画朝右。
- **当前状态**：`assets/generated/` 下全是程序化色块占位图（500-900 字节）。升级路径见 §6。

---

## 4. 特效语言（shader + 粒子）

现有 5 个 shader（`shaders/*.gdshader`）+ ParticleHelper，构成视觉骨架。新增特效复用它们，不要另起炉灶。

| 用途 | 实现 | 入口 |
|------|------|------|
| 稀有度描边 | rarity_outline.gdshader | `ShaderHelper.apply_rarity_glow` |
| 受击闪白 | hit_flash.gdshader | `ShaderHelper.apply_hit_flash` |
| 状态叠色（点燃/中毒/冰冻）| status_overlay.gdshader | `ShaderHelper.apply_status_overlay` |
| 死亡溶解 | dissolve.gdshader | `ShaderHelper.apply_dissolve` |
| 区域暗角 | vignette.gdshader | `ShaderHelper.create_vignette` |
| 命中/暴击/死亡/升级/拾取粒子 | CPUParticles2D | `ParticleHelper.*` |

**元素配色统一**（状态/技能/词缀共用）：
- 火/点燃：`#FF6B2A` 橙红
- 毒：`#7FBF3F` 黄绿
- 冰/冰冻：`#7FD4FF` 冰蓝
- 雷/连锁：`#9BE6FF` 亮青
- 暗影/虚空：`#9B4DCA` 紫
- 物理/暴击：`#FFE08A` 暖金

> A3 阶段把这些收口到 `vfx.json` 的 `element_colors` 段，供 CombatSystem/ParticleHelper 取用。

**手感反馈分级**（已由 FeedbackSystem 实现，配色/强度规范）：
- 普通命中：hitstop 0.04s，无震屏
- 暴击：hitstop 0.08s + 震屏 8px + 暴击粒子
- Boss 死亡：slowmo 0.35× / 0.5s + 震屏 14px

---

## 5. UI 视觉规范

- **主题真源**：`ThemeGenerator`（程序化生成 Theme），强调色金 `#E8A317`。
- **面板**：暗底 + 稀有度/区域色描边，圆角统一走 `Schema.rarity_corner_radius`（装备相关）或固定 6px（通用面板）。
- **字体**：标题/副标题/正文三级，由 ThemeGenerator 提供工厂方法。
- **血条/蓝条/经验条/职业资源条**：ThemeGenerator 已有专用 StyleBox 工厂。
- **装备 tooltip**：背景用 `RarityVisuals.get_rarity_bg_gradient`，边框用 `get_rarity_border_style`，标题用 `get_rarity_rich_text`。属性对比（P10 ItemCompare）正绿负红。
- **新系统面板**（巅峰/天赋/任务/商人）：A2 统一用 ThemeGenerator 的面板工厂，避免每个程序化 Panel 各写各的样式。

---

## 6. 素材升级路径

**现状**：`assets/generated/` 是程序化占位（角色/敌人/图标/tile/prop/ui/boss 入场图），`assets/sprites/` 有 Kenney roguelike sheet（仅 ClassSelect/Town 用）。

**两条升级路线**（按投入排序）：

1. **程序化占位升级**（零外部依赖，A4 做）：给生成的色块加轮廓描边、底部阴影、职业/家族区分色，立刻提升一档辨识度。
2. **真实像素素材接入**（需外部素材，采购清单见下）：
   - 角色：[itch.io] 16/32px 暗黑奇幻角色包（带 idle/walk/attack/hurt 四向或单向）
   - 敌人：骷髅/史莱姆/恶魔/亡灵 像素包
   - 图标：装备/技能图标包（110 个装备槽位，见 `generated/icons/`）
   - 规格要求：透明背景 PNG，单帧 64×64 或可整除，import 设 Filter=Nearest（像素风必须）
   - 放置：替换 `assets/generated/<category>/` 对应路径，保持文件名不变即可被 SpriteLibrary 自动加载

**接入规范**：所有外部素材必须**可商用授权**（CC0 / Kenney / 已购），授权记录写入 `assets/CREDITS.md`。

---

## 7. 校验

- 配色硬编码检查：`grep -rn "C8C8C8\|4A90D9\|9B4DCA\|E8A317\|E03131" --include=*.gd` 应只在 `Schema.gd` 命中。
- 像素素材 import：所有 `assets/generated/**` 与 `assets/sprites/**` 的 `.import` 必须 `filter=false`（Nearest）。
- 新区域/稀有度：先改 Schema 常量与本文档，再改其余代码。
