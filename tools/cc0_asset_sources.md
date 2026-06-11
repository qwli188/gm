# CC0 ARPG 素材源清单

## 已集成
- ✅ Kenney Tiny Dungeon (download_kenney.py)
- ✅ 0x72 DungeonTileset (import_0x72.py)

## 待扩展（全部 CC0 / Public Domain）

### 1. Kenney 其他包（kenney.nl，全站 CC0）
- **RPG Urban Pack** - 城镇/NPC/建筑
  https://kenney.nl/assets/rpg-urban-pack
- **Platformer Pack Redux** - 通用角色动画
  https://kenney.nl/assets/platformer-pack-redux
- **Particle Pack** - 粒子特效
  https://kenney.nl/assets/particle-pack

### 2. OpenGameArt（筛选 CC0）
- **Liberated Pixel Cup (LPC)** - 角色/装备 spritesheet
  https://opengameart.org/content/lpc-collection (需注意 LPC 有多个许可混合，筛选纯 CC0 部分)
- **PixelDungeons** - 地牢 tiles
  https://opengameart.org/content/pixel-dungeon-tiles

### 3. itch.io CC0 合集
- **Pixel Art Dungeon Asset Pack** by @Stealthix (CC0)
  https://stealthix.itch.io/rpg-nature-tileset
  
### 4. 自动生成（程序化，零授权风险）
- gen_assets.py 已有：色块敌人、粒子
- 可扩展：Perlin noise 地形、程序化武器图标

## 法线贴图管线
- 工具：Laigter（开源 MIT，支持 CLI）或 Pillow Sobel 边缘检测
- 输入：现有 2D sprite
- 输出：_n.png 法线贴图（Godot CanvasItem 材质可用）

## 图集打包
- Godot 内置：SpriteFrames 资源（.tres）
- 外部工具：TexturePacker（付费）/ ShoeBox（免费）/ gdtoolkit 未来扩展
- 当前不急：Godot 自动合批小图，性能已足够

