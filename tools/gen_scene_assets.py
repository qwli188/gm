# -*- coding: utf-8 -*-
"""
场景互动物件精灵生成器（黑暗奇幻·末世风）
为 主城/领地/野外 三大可探索场景生成带主体造型的互动物件:
  - 副本传送门 (portal_<region>.png) — 野外里按区域分布的副本入口
  - 领地建筑 (build_<id>.png) — 可走到交互的领地建筑
  - 野外事件点 (wild_<kind>.png) — 采集/矿脉/藏点/遗迹/怪窝/商人
统一规格: 64x64 透明 PNG, 暗描边 + 底部阴影 + 高对比点缀。
输出到 project/src/assets/generated/scene/。
"""
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).parent.parent
SCENE = ROOT / "project" / "src" / "assets" / "generated" / "scene"
SCENE.mkdir(parents=True, exist_ok=True)

TILE = 64
OUTLINE = (22, 18, 30, 255)

# 区域色温（与 art-spec.md §2 一致）
REGION_TINT = {
    "crypt": (107, 122, 143),
    "swamp": (122, 143, 74),
    "forge": (217, 98, 42),
    "ice": (143, 196, 217),
    "void": (122, 74, 202),
    "field": (143, 132, 86),
}


def _clamp(c):
    return tuple(max(0, min(255, int(v))) for v in c)


def _lerp(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def _shadow(img):
    """底部椭圆阴影，增强立体感"""
    sh = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(sh)
    d.ellipse([14, 50, 50, 60], fill=(0, 0, 0, 90))
    sh = sh.filter(ImageFilter.GaussianBlur(2))
    sh.alpha_composite(img)
    return sh


def make_portal(region):
    """副本传送门: 拱门 + 区域色能量漩涡 + 漂浮符文"""
    tint = REGION_TINT.get(region, (143, 132, 86))
    seed = hash(f"portal_{region}") % 100000
    random.seed(seed)
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = TILE // 2

    # 石质拱门（两根立柱 + 顶横梁）
    stone = (74, 70, 84)
    d.rectangle([12, 18, 20, 52], fill=stone, outline=OUTLINE)
    d.rectangle([44, 18, 52, 52], fill=stone, outline=OUTLINE)
    d.polygon([(10, 18), (54, 18), (50, 10), (14, 10)], fill=stone, outline=OUTLINE)

    # 能量漩涡（区域色，多层椭圆 + 高光核心）
    for i, r in enumerate([18, 13, 8]):
        a = 120 + i * 40
        col = _lerp(tint, (255, 255, 255), i * 0.25)
        d.ellipse([cx - r, 34 - r + 6, cx + r, 34 + r + 6], fill=(*_clamp(col), a))
    d.ellipse([cx - 4, 36, cx + 4, 44], fill=(255, 255, 255, 230))

    # 漂浮符文点
    for _ in range(5):
        a = random.random() * math.tau
        rr = random.randint(10, 16)
        px = cx + math.cos(a) * rr
        py = 40 + math.sin(a) * rr * 0.7
        d.ellipse([px - 1, py - 1, px + 1, py + 1], fill=(*_clamp(_lerp(tint, (255, 255, 255), 0.5)), 220))

    return _shadow(img)


# 领地建筑: id -> (主色, 造型)
BUILDINGS = {
    "townhall": ((150, 120, 70), "hall"),
    "lumber_mill": ((120, 90, 55), "mill"),
    "quarry": ((110, 110, 120), "quarry"),
    "farm": ((130, 160, 70), "farm"),
    "barracks": ((130, 70, 60), "barracks"),
    "watchtower": ((100, 110, 140), "tower"),
    "wall": ((110, 105, 110), "wall"),
}


def make_building(bid):
    """领地建筑: 按造型画屋顶/墙体/标志物"""
    color, shape = BUILDINGS.get(bid, ((120, 110, 90), "hall"))
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = TILE // 2
    wall = _clamp(_lerp(color, (40, 36, 44), 0.3))
    roof = _clamp(_lerp(color, (255, 255, 255), 0.15))

    # 基础墙体
    d.rectangle([16, 30, 48, 54], fill=wall, outline=OUTLINE)

    if shape == "hall":  # 领主大厅: 高屋顶 + 旗帜
        d.polygon([(12, 30), (cx, 12), (52, 30)], fill=roof, outline=OUTLINE)
        d.line([(cx, 12), (cx, 4)], fill=OUTLINE, width=2)
        d.polygon([(cx, 4), (cx + 10, 7), (cx, 11)], fill=(200, 70, 60, 255))
        d.rectangle([28, 40, 36, 54], fill=(40, 34, 30, 255))  # 门
    elif shape == "mill":  # 伐木场: 斜屋顶 + 圆锯
        d.polygon([(14, 30), (50, 30), (44, 18), (20, 18)], fill=roof, outline=OUTLINE)
        d.ellipse([34, 36, 50, 52], fill=(180, 180, 190, 255), outline=OUTLINE)
        for a in range(0, 360, 45):
            x = 42 + math.cos(math.radians(a)) * 7
            y = 44 + math.sin(math.radians(a)) * 7
            d.line([(42, 44), (x, y)], fill=OUTLINE, width=1)
    elif shape == "quarry":  # 采石场: 平顶 + 石堆
        d.rectangle([16, 26, 48, 30], fill=roof, outline=OUTLINE)
        for _ in range(4):
            sx, sy = 20 + (_ * 7), 48
            d.polygon([(sx, sy), (sx + 4, sy - 6), (sx + 8, sy)], fill=(130, 130, 140, 255), outline=OUTLINE)
    elif shape == "farm":  # 农场: 茅草顶 + 麦垛
        d.polygon([(12, 30), (cx, 16), (52, 30)], fill=(170, 150, 80, 255), outline=OUTLINE)
        for gx in [22, 30, 38]:
            d.line([(gx, 54), (gx, 44)], fill=(200, 180, 90, 255), width=2)
    elif shape == "barracks":  # 兵营: 平顶 + 盾牌
        d.rectangle([14, 26, 50, 30], fill=roof, outline=OUTLINE)
        d.polygon([(cx - 7, 36), (cx + 7, 36), (cx + 5, 48), (cx, 52), (cx - 5, 48)],
                  fill=(180, 60, 55, 255), outline=OUTLINE)
    elif shape == "tower":  # 哨塔: 高塔 + 雉堞
        d.rectangle([24, 14, 40, 54], fill=wall, outline=OUTLINE)
        for bx in [24, 30, 36]:
            d.rectangle([bx, 10, bx + 4, 16], fill=wall, outline=OUTLINE)
        d.ellipse([29, 24, 35, 30], fill=(255, 200, 90, 220))  # 瞭望灯
    elif shape == "wall":  # 城墙: 矮墙 + 雉堞
        d.rectangle([10, 34, 54, 54], fill=wall, outline=OUTLINE)
        for bx in range(10, 54, 8):
            d.rectangle([bx, 28, bx + 5, 34], fill=wall, outline=OUTLINE)

    return _shadow(img)


def make_wild(kind):
    """野外事件点造型"""
    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = TILE // 2

    if kind == "herb":  # 草药丛: 绿叶 + 花
        for _ in range(6):
            x = cx + random.randint(-10, 10)
            d.line([(x, 52), (x + random.randint(-3, 3), 36)], fill=(90, 150, 70, 255), width=2)
        for _ in range(3):
            fx = cx + random.randint(-8, 8)
            d.ellipse([fx, 34, fx + 5, 39], fill=(200, 120, 180, 255))
    elif kind == "ore":  # 矿脉: 灰岩 + 发光矿石
        d.polygon([(16, 52), (22, 32), (42, 30), (48, 50)], fill=(90, 86, 96, 255), outline=OUTLINE)
        for _ in range(4):
            gx, gy = cx + random.randint(-8, 8), 40 + random.randint(-6, 6)
            d.ellipse([gx, gy, gx + 4, gy + 4], fill=(120, 200, 230, 255))
    elif kind == "chest":  # 藏宝箱: 木箱 + 金锁
        d.rectangle([18, 34, 46, 52], fill=(110, 75, 45, 255), outline=OUTLINE)
        d.rectangle([18, 30, 46, 38], fill=(130, 90, 55, 255), outline=OUTLINE)
        d.rectangle([29, 36, 35, 44], fill=(230, 180, 60, 255), outline=OUTLINE)
    elif kind == "ruin":  # 古老遗迹: 断柱 + 符文光
        d.rectangle([20, 26, 28, 52], fill=(120, 116, 128, 255), outline=OUTLINE)
        d.rectangle([38, 32, 46, 52], fill=(110, 106, 118, 255), outline=OUTLINE)
        d.ellipse([24, 20, 32, 28], fill=(150, 110, 220, 200))  # 符文光
    elif kind == "lair":  # 怪物窝点: 暗洞 + 红眼
        d.ellipse([16, 30, 48, 56], fill=(40, 34, 44, 255), outline=OUTLINE)
        d.ellipse([20, 36, 44, 54], fill=(20, 16, 24, 255))
        d.ellipse([27, 42, 31, 46], fill=(220, 50, 50, 255))  # 红眼
        d.ellipse([34, 42, 38, 46], fill=(220, 50, 50, 255))
    elif kind == "merchant":  # 流浪商人: 兜帽身影 + 货摊
        d.rectangle([18, 44, 46, 52], fill=(90, 70, 50, 255), outline=OUTLINE)  # 货摊
        d.ellipse([28, 24, 40, 40], fill=(70, 60, 90, 255), outline=OUTLINE)  # 兜帽
        d.ellipse([31, 30, 37, 36], fill=(30, 26, 36, 255))  # 帽影脸
        d.ellipse([32, 32, 34, 34], fill=(255, 210, 90, 255))  # 眼光

    return _shadow(img)


WILD_KINDS = ["herb", "ore", "chest", "ruin", "lair", "merchant"]


def main():
    print("=" * 60)
    print("  场景互动物件精灵生成（传送门/建筑/野外事件点）")
    print("=" * 60)
    n = 0
    for region in REGION_TINT:
        make_portal(region).save(SCENE / f"portal_{region}.png")
        n += 1
    for bid in BUILDINGS:
        make_building(bid).save(SCENE / f"build_{bid}.png")
        n += 1
    for kind in WILD_KINDS:
        make_wild(kind).save(SCENE / f"wild_{kind}.png")
        n += 1
    print(f"  [OK] {n} 个场景物件精灵 -> {SCENE}")
    print("=" * 60)


if __name__ == "__main__":
    main()
