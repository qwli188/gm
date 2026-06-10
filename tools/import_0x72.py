# -*- coding: utf-8 -*-
"""
0x72 DungeonTileset II 在线自动集成器 (CC0 可商用)
镜像: marceloferreira357/bun-crawler-client (含官方 v1.7 完整逐帧)
raw.githubusercontent.com 可达, frames 已预切, 无需裁图集.

流程:
  下载逐帧 PNG -> 居中补正方形(脚底对齐) -> 放大到64px(NEAREST)
  -> 横向拼成 SpriteLibrary 可切的 spritesheet
  -> 覆盖写入 generated/characters|enemies/ (零代码改动即生效)

幂等: 重复运行结果一致. 失败回退: 任一帧下载失败则跳过该动画, 保留程序化占位.
"""
import io
import sys
import urllib.request
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).parent.parent
GEN = ROOT / "project" / "src" / "assets" / "generated"
BASE_URL = ("https://raw.githubusercontent.com/marceloferreira357/bun-crawler-client"
            "/main/public/sprites/0x72_DungeonTilesetII_v1.7/frames")

FRAME = 64  # 目标帧尺寸(匹配 SpriteLibrary.FRAME_SIZE)

# ---- 职业映射: 我方6职业 -> 0x72角色前缀 ----
CLASS_MAP = {
    "warrior":     "knight_m",
    "knight":      "dwarf_m",
    "ranger":      "elf_m",
    "mage":        "wizzard_m",
    "assassin":    "lizard_m",
    "necromancer": "doc",
}

# ---- 敌人映射: 我方6家族 -> 0x72敌人前缀 ----
ENEMY_MAP = {
    "skeleton": "skelet",
    "slime":    "muddy",
    "demon":    "big_demon",
    "ice":      "ice_zombie",
    "void":     "wogol",
    "beast":    "ogre",
}

_cache = {}


def fetch(name):
    """下载单帧 PNG -> PIL Image (带缓存). 失败返回 None"""
    if name in _cache:
        return _cache[name]
    url = f"{BASE_URL}/{name}.png"
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "darkloot-build"})
        data = urllib.request.urlopen(req, timeout=20).read()
        img = Image.open(io.BytesIO(data)).convert("RGBA")
        _cache[name] = img
        return img
    except Exception:
        _cache[name] = None
        return None


def square_scale(img):
    """居中补正方形(底部对齐,脚踩地面) -> 放大到 FRAME, NEAREST"""
    w, h = img.size
    side = max(w, h)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    # 水平居中, 垂直底部对齐
    canvas.alpha_composite(img, ((side - w) // 2, side - h))
    return canvas.resize((FRAME, FRAME), Image.NEAREST)


def try_frames(prefix, anim, max_n=8):
    """收集 prefix_anim_anim_fN (N=0..) 直到缺失. 返回帧列表.
    回退: 若命名动画(<prefix>_<anim>_anim_fN)缺失, 尝试单动画(<prefix>_anim_fN).
    很多简单怪(muddy/ice_zombie/swampy/slug)只有单套 <prefix>_anim_fN 帧."""
    frames = []
    for n in range(max_n):
        img = fetch(f"{prefix}_{anim}_anim_f{n}")
        if img is None:
            break
        frames.append(square_scale(img))
    if frames:
        return frames
    # 回退: 单动画命名
    for n in range(max_n):
        img = fetch(f"{prefix}_anim_f{n}")
        if img is None:
            break
        frames.append(square_scale(img))
    return frames


def build_sheet(frames):
    """横向拼接帧 -> spritesheet Image"""
    if not frames:
        return None
    sheet = Image.new("RGBA", (FRAME * len(frames), FRAME), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.alpha_composite(f, (i * FRAME, 0))
    return sheet


def save_sheet(frames, out_path):
    sheet = build_sheet(frames)
    if sheet is None:
        return False
    out_path.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_path)
    return True


def import_characters():
    print("  [角色] 导入6职业...")
    ok = 0
    for our_class, src in CLASS_MAP.items():
        out_dir = GEN / "characters" / our_class
        # idle <- idle, walk <- run, attack/hurt <- hit (或回退 run)
        idle = try_frames(src, "idle")
        run = try_frames(src, "run")
        hit = try_frames(src, "hit", max_n=4)
        if not idle:
            print(f"    [SKIP] {our_class} <- {src} (idle帧缺失,保留程序化)")
            continue
        save_sheet(idle, out_dir / "idle.png")
        save_sheet(run or idle, out_dir / "walk.png")
        save_sheet(hit or run or idle, out_dir / "attack.png")
        save_sheet(hit or idle, out_dir / "hurt.png")
        # 头像 = idle第一帧
        if idle:
            idle[0].save(out_dir / "portrait.png")
        ok += 1
        print(f"    [OK] {our_class} <- {src} (idle{len(idle)}/run{len(run)}/hit{len(hit)})")
    return ok


def import_enemies():
    print("  [敌人] 导入6家族...")
    ok = 0
    for our_fam, src in ENEMY_MAP.items():
        out_dir = GEN / "enemies" / our_fam
        idle = try_frames(src, "idle")
        run = try_frames(src, "run")
        if not idle:
            print(f"    [SKIP] {our_fam} <- {src} (idle帧缺失,保留程序化)")
            continue
        save_sheet(idle, out_dir / "idle.png")
        save_sheet(run or idle, out_dir / "attack.png")
        save_sheet(idle, out_dir / "static.png")
        ok += 1
        print(f"    [OK] {our_fam} <- {src} (idle{len(idle)}/run{len(run)})")
    return ok


def import_floor_tiles():
    """0x72 floor_1..8 -> 各区域追加真实地板变体(可选增强)"""
    print("  [地块] 导入0x72地板...")
    saved = 0
    floors = []
    for n in range(1, 9):
        img = fetch(f"floor_{n}")
        if img:
            floors.append(img.resize((FRAME, FRAME), Image.NEAREST))
    if not floors:
        print("    [SKIP] 地板帧缺失")
        return 0
    # 作为 crypt 区域的真实地板变体(0x72是地牢石砖,最契合crypt)
    tiles_dir = GEN / "tiles"
    tiles_dir.mkdir(parents=True, exist_ok=True)
    for i, f in enumerate(floors[:4]):
        f.save(tiles_dir / f"floor_crypt_{i}.png")
        saved += 1
    # 同步覆盖默认
    floors[0].save(tiles_dir / "floor_crypt.png")
    print(f"    [OK] {saved} 真实地牢地板 -> crypt")
    return saved


def main():
    print("=" * 60)
    print("  0x72 DungeonTileset II 在线自动集成 (CC0)")
    print("=" * 60)

    # 连通性探测
    test = fetch("knight_m_idle_anim_f0")
    if test is None:
        print("  [ERR] 无法连接镜像源, 保留程序化美术")
        print("  镜像: raw.githubusercontent.com/marceloferreira357/...")
        return 1

    c = import_characters()
    e = import_enemies()
    t = import_floor_tiles()

    print("=" * 60)
    print(f"  [完成] 角色{c}/6 敌人{e}/6 地板{t}")
    print("  SpriteLibrary 零改动即生效 (已覆盖 generated/)")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    sys.exit(main())
