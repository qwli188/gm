# 素材采购与接线清单（ASSET PROCUREMENT）

> 配合 [art-spec.md](art-spec.md) 使用。本文件是**把真实像素素材接进 DarkLoot 的操作手册**。
> 当前 `assets/generated/` 全是程序化色块占位图；本清单告诉你买什么、放哪、怎么 import 才能被自动加载。

---

## 0. 核心原则

- **零代码接入**：SpriteLibrary 按**固定路径 + 文件名**加载素材。只要新素材放对位置、用对文件名、规格匹配，**不改一行代码**就生效。
- **必须可商用授权**：只用 CC0 / Kenney / 已购买授权的素材。每个素材来源记入 `assets/CREDITS.md`。
- **像素风必须关闭过滤**：所有 `.import` 设 `filter=false`（Nearest），否则像素图会糊。

---

## 1. 优先级（按画面收益排序）

| 优先级 | 类别 | 数量 | 收益 |
|--------|------|------|------|
| ★★★ | 角色精灵（8 职业）| 8×4 动画 | 玩家全程盯着，收益最高 |
| ★★★ | 敌人精灵（6 家族）| 6×2 动画 | 战斗画面主体 |
| ★★ | 装备图标 | ~15 类 ×5 稀有度 | 背包/工坊高频可见 |
| ★★ | Boss 立绘/入场图 | 6 张 | 演出感 |
| ★ | tile / prop | 6 区域 | 场景氛围（已有暗角+染色兜底）|
| ★ | 技能图标 | ~10 形状 | 技能栏 |

---

## 2. 角色精灵（★★★）

**路径**：`assets/generated/characters/<class>/` —— `<class>` ∈ `warrior / ranger / mage / assassin / knight / necromancer / frost_witch / shadow_archer`

> 注意：`SpriteLibrary` 用去前缀短名（`class_warrior` → `warrior`）。

**每个职业需要的文件**（文件名固定）：
| 文件 | 内容 | 规格 |
|------|------|------|
| `idle.png` | 待机动画 | 横向 spritesheet，4 帧，每帧 64×64（共 256×64）|
| `walk.png` | 行走动画 | 同上 |
| `attack.png` | 攻击动画 | 同上 |
| `hurt.png` | 受击动画 | 同上 |
| `portrait.png` | 头像 | 单帧 64×64 |

- 帧数可不止 4 帧，SpriteLibrary 按 `宽度 / 64` 自动算帧数。
- 朝向画**朝右**，引擎用 flip_h 处理左行。
- **推荐素材源**：
  - itch.io 搜 "dark fantasy character pixel" / "32x32 rpg hero sprites"
  - Kenney「Tiny Dungeon」「Roguelike Characters」(CC0)
  - LPC (Liberated Pixel Cup) 角色集（CC-BY-SA，注意授权）

## 3. 敌人精灵（★★★）

**路径**：`assets/generated/enemies/<family>/` —— `<family>` ∈ `skeleton / slime / demon / ice / void / beast`

> region→family 映射见 `SpriteLibrary.REGION_FAMILY`：crypt→skeleton, swamp→slime, forge→demon, ice→ice, void→void, field→beast。

**每个家族需要**：`idle.png` `attack.png`（4 帧 256×64）+ `static.png`（单帧，给不动的敌人）。

- 同家族一套图通吃该区域所有敌人，rank（精英/Boss）由代码自动缩放+染色，无需单独出图。
- **推荐**：itch.io "monster pixel pack" / Kenney "Roguelike Monsters"。

## 4. 装备图标（★★）

**路径**：`assets/generated/icons/equipment/`，文件名 `<kind>_<rarity>.png`

- `<kind>`（见 `SpriteLibrary._slot_to_icon`）：`sword / staff / bow / helmet / chest / legs / boots / gloves / ring / amulet`
- `<rarity>`：`common / rare / epic / legendary / mythic`
- 缺某稀有度时代码自动回退到 `<kind>_common.png`，所以**最低限度每个 kind 出 1 张 common 即可**，稀有度差异可全交给 ShaderHelper 描边运行时渲染。
- 规格：单帧 64×64，透明背景。
- **推荐**：Kenney "Game Icons" / itch.io "RPG equipment icons 32x32"。

## 5. Boss 立绘（★★）

**路径**：`assets/generated/bosses/`，文件名 `entrance_<boss_id>.png`（已有 6 张占位：bone_lord / brood_mother / ember_lord / frost_lich / void_child / abyss_herald）。用于 Boss 入场演出叠加。

## 6. tile / prop / 技能图标（★）

- **tile**：`assets/generated/tiles/` —— `floor_<region>.png` / `floor_<region>_<0..N>.png`（变体）/ `obstacle_<region>.png`。规格 32×32 或 64×64 可平铺。
- **prop**：`assets/generated/props/prop_<region>_<0..N>.png`，非阻挡氛围物。
- **技能图标**：`assets/generated/icons/skills/<shape>.png`，缺失回退 `slash.png`。

---

## 7. 接入流程（每批素材）

1. 把 PNG 放到上表对应路径，**文件名严格匹配**。
2. 在 Godot 编辑器导入（或直接放好后开编辑器，会自动生成 `.import`）。
3. **检查 import 设置**：选中图片 → Import 面板 → `Filter` 关闭（Nearest）→ Reimport。
   - 批量校验：`grep -L 'filter=false' assets/generated/**/*.import` 应无输出。
4. 运行游戏，SpriteLibrary 自动加载新图（无需改代码）。
5. 把素材来源/作者/授权写入 `assets/CREDITS.md`。

---

## 8. 验收 checklist

- [ ] 8 职业各 5 文件齐全，尺寸为 64 的整数倍宽 × 64 高
- [ ] 6 敌人家族各 3 文件齐全
- [ ] 装备图标至少每 kind 一张 common
- [ ] 所有 `.import` filter 已关
- [ ] CREDITS.md 已更新
- [ ] 游戏内目视：角色/敌人不再是色块，落地阴影与新图协调（阴影由 ShaderHelper.ensure_drop_shadow 运行时叠加，无需出图）

---

## 9. 不需要采购的部分（代码已覆盖）

以下视觉**完全由代码生成**，不要浪费预算买素材：
- 稀有度描边/发光（`rarity_outline.gdshader`）
- 受击闪白、状态叠色、死亡溶解、暗角（其余 4 个 shader）
- 命中/暴击/死亡/升级/拾取粒子、攻击拖尾、冲刺残影、技能爆发、Boss 冲击波（ParticleHelper）
- 落地阴影（ShaderHelper.ensure_drop_shadow）
- 全部 UI 主题、面板、血条、tooltip（ThemeGenerator）
- 伤害飘字（DamageNumber）
