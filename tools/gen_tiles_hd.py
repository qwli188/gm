# -*- coding: utf-8 -*-
"""
HD 多变体地块生成器
解决"整张地图铺同一块 tile = 重复网格感"的问题:
  - 每区域 4 个地板变体 (floor_<region>_0..3.png)
  - 每区域 4 个装饰道具 (prop_<region>_0..3.png) — 非阻挡氛围物
  - 富细节: 渐变底色 + 石缝/苔藓/裂纹 + 边缘暗角 + 噪点质感
在 gen_assets 之后运行, 覆盖/补充 tiles/ 目录。
"""
import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).parent.parent
TILES = ROOT / "project" / "src" / "assets" / "generated" / "tiles"
PROPS = ROOT / "project" / "src" / "assets" / "generated" / "props"
TILES.mkdir(parents=True, exist_ok=True)
PROPS.mkdir(parents=True, exist_ok=True)

TILE = 64
OUTLINE = (24, 20, 32, 255)

# 区域风味: 底色 / 缝隙色 / 点缀色 / 主题
REGIONS = {
    "crypt": {"base": (52, 48, 64),  "crack": (32, 28, 42),  "deco": (120, 115, 140), "theme": "stone"},
    "swamp": {"base": (48, 60, 42),  "crack": (30, 40, 26),  "deco": (90, 130, 70),   "theme": "moss"},
    "forge": {"base": (70, 42, 32),  "crack": (110, 50, 20), "deco": (255, 140, 50),  "theme": "lava"},
    "ice":   {"base": (54, 72, 92),  "crack": (90, 130, 170),"deco": (180, 220, 255), "theme": "ice"},
    "void":  {"base": (52, 40, 70),  "crack": (90, 50, 130), "deco": (170, 110, 220), "theme": "void"},
    "field": {"base": (62, 70, 50),  "crack": (45, 52, 36),  "deco": (110, 140, 80),  "theme": "grass"},
    "chaos": {"base": (66, 44, 60),  "crack": (120, 50, 90), "deco": (220, 120, 180), "theme": "stone"},
    "town":  {"base": (66, 76, 58),  "crack": (48, 56, 42),  "deco": (130, 150, 95),  "theme": "grass"},
}


def _lerp(c1, c2, t):
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def _clamp(c):
    return tuple(max(0, min(255, int(v))) for v in c)


def _grain(img, strength, seed):
    random.seed(seed)
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            n = random.randint(-strength, strength)
            px[x, y] = (*_clamp((r + n, g + n, b + n)), a)
    return img


def make_floor(region, variant):
    """生成单个地板变体: 渐变底 + 主题细节 + 边缘暗角 + 噪点"""
    cfg = REGIONS[region]
    base = cfg["base"]
    crack = cfg["crack"]
    deco = cfg["deco"]
    theme = cfg["theme"]
    seed = hash(f"{region}_{variant}") % 100000
    random.seed(seed)

    img = Image.new("RGBA", (TILE, TILE), (*base, 255))
    d = ImageDraw.Draw(img)

    # 1. 垂直渐变(顶亮底暗)
    for y in range(TILE):
        t = y / TILE
        col = _lerp(_lerp(base, (255, 255, 255), 0.08), _lerp(base, (0, 0, 0), 0.18), t)
        d.line([(0, y), (TILE, y)], fill=(*_clamp(col), 255))

    # 2. 主题细节
    if theme == "stone":
        # 石砖缝(2x2分块)
        d.line([(TILE // 2, 0), (TILE // 2, TILE)], fill=(*crack, 200), width=2)
        d.line([(0, TILE // 2), (TILE, TILE // 2)], fill=(*crack, 200), width=2)
        # 随机裂纹
        for _ in range(variant + 1):
            x = random.randint(8, TILE - 8)
            y = random.randint(8, TILE - 8)
            for _ in range(4):
                nx = x + random.randint(-6, 6)
                ny = y + random.randint(-6, 6)
                d.line([(x, y), (nx, ny)], fill=(*crack, 180), width=1)
                x, y = nx, ny
    elif theme == "moss":
        # 苔藓斑块
        for _ in range(5 + variant * 2):
            x = random.randint(4, TILE - 8)
            y = random.randint(4, TILE - 8)
            r = random.randint(3, 7)
            c = _lerp(deco, base, random.random() * 0.4)
            d.ellipse([x, y, x + r, y + r], fill=(*_clamp(c), 160))
    elif theme == "lava":
        # 熔岩裂隙(发光)
        for _ in range(variant + 2):
            x = random.randint(6, TILE - 6)
            y = random.randint(6, TILE - 6)
            for _ in range(5):
                nx = x + random.randint(-8, 8)
                ny = y + random.randint(-8, 8)
                d.line([(x, y), (nx, ny)], fill=(*deco, 200), width=2)
                x, y = nx, ny
    elif theme == "ice":
        # 冰面裂纹(浅色)
        cx, cy = random.randint(16, 48), random.randint(16, 48)
        for _ in range(4 + variant):
            a = random.random() * math.tau
            ln = random.randint(10, 24)
            d.line([(cx, cy), (cx + math.cos(a) * ln, cy + math.sin(a) * ln)],
                   fill=(*deco, 150), width=1)
        # 高光
        d.ellipse([cx - 3, cy - 3, cx + 3, cy + 3], fill=(*deco, 120))
    elif theme == "void":
        # 虚空星点
        for _ in range(8 + variant * 3):
            x = random.randint(2, TILE - 2)
            y = random.randint(2, TILE - 2)
            s = random.choice([1, 1, 2])
            c = _lerp(deco, (255, 255, 255), random.random() * 0.5)
            d.ellipse([x, y, x + s, y + s], fill=(*_clamp(c), random.randint(120, 220)))
    elif theme == "grass":
        # 草叶
        for _ in range(10 + variant * 3):
            x = random.randint(3, TILE - 3)
            y = random.randint(6, TILE - 3)
            h = random.randint(3, 7)
            c = _lerp(deco, base, random.random() * 0.5)
            d.line([(x, y), (x + random.randint(-2, 2), y - h)], fill=(*_clamp(c), 180), width=1)

    # 3. 边缘暗角(让 tile 拼接有缝隙感, 增强立体)
    edge = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    ed = ImageDraw.Draw(edge)
    ed.rectangle([0, 0, TILE - 1, TILE - 1], outline=(0, 0, 0, 90), width=2)
    edge = edge.filter(ImageFilter.GaussianBlur(1))
    img.alpha_composite(edge)

    # 4. 噪点质感
    img = _grain(img, 6, seed)
    return img


def make_prop(region, variant):
    """生成区域装饰道具(非阻挡氛围物): 蘑菇/骨头/水晶/火堆..."""
    cfg = REGIONS[region]
    deco = cfg["deco"]
    base = cfg["base"]
    theme = cfg["theme"]
    seed = hash(f"prop_{region}_{variant}") % 100000
    random.seed(seed)

    img = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    cx = TILE // 2

    if theme == "stone":  # crypt: 骨头/碎墓碑
        if variant % 2 == 0:
            # 骨头堆
            for _ in range(3):
                x = cx + random.randint(-10, 10)
                y = 40 + random.randint(-6, 6)
                d.line([(x - 6, y), (x + 6, y)], fill=(230, 228, 215, 255), width=3)
                d.ellipse([x - 8, y - 2, x - 4, y + 2], fill=(230, 228, 215, 255))
                d.ellipse([x + 4, y - 2, x + 8, y + 2], fill=(230, 228, 215, 255))
        else:
            # 碎墓碑
            d.polygon([(cx - 10, 48), (cx - 8, 24), (cx + 8, 26), (cx + 10, 48)],
                      fill=(90, 86, 100, 255), outline=OUTLINE)
    elif theme == "moss":  # swamp: 蘑菇
        d.ellipse([cx - 3, 40, cx + 3, 52], fill=(180, 170, 150, 255))  # 柄
        d.ellipse([cx - 9, 30, cx + 9, 44], fill=(*deco, 255), outline=OUTLINE)  # 伞
        for _ in range(3):
            sx = cx + random.randint(-6, 6)
            sy = 34 + random.randint(-2, 4)
            d.ellipse([sx, sy, sx + 2, sy + 2], fill=(230, 240, 220, 255))
    elif theme == "lava":  # forge: 矿石/铁砧
        d.polygon([(cx - 10, 48), (cx - 6, 32), (cx + 8, 30), (cx + 10, 46)],
                  fill=(80, 70, 65, 255), outline=OUTLINE)
        for _ in range(3):
            gx = cx + random.randint(-6, 6)
            gy = 38 + random.randint(-4, 4)
            d.ellipse([gx, gy, gx + 4, gy + 4], fill=(*deco, 255))  # 矿脉发光
    elif theme == "ice":  # ice: 冰锥
        d.polygon([(cx - 7, 48), (cx, 22), (cx + 7, 48)], fill=(*deco, 220), outline=(200, 230, 255, 255))
        d.polygon([(cx - 2, 48), (cx + 1, 30), (cx + 4, 48)], fill=(230, 245, 255, 200))
    elif theme == "void":  # void: 浮空水晶
        for i, r in enumerate([14, 10, 6]):
            a = 200 - i * 40
            d.ellipse([cx - r, 32 - r, cx + r, 32 + r], outline=(*deco, a), width=2)
        d.polygon([(cx - 5, 38), (cx, 22), (cx + 5, 38), (cx, 44)], fill=(*deco, 230))
    elif theme == "grass":  # field: 灌木/篝火
        if variant % 2 == 0:
            d.ellipse([cx - 12, 30, cx + 12, 50], fill=(*deco, 255), outline=OUTLINE)
            for _ in range(4):
                bx = cx + random.randint(-8, 8)
                by = 38 + random.randint(-6, 6)
                d.ellipse([bx, by, bx + 3, by + 3], fill=(220, 80, 80, 255))  # 浆果
        else:
            # 篝火
            d.polygon([(cx - 8, 48), (cx + 8, 48), (cx + 4, 40), (cx - 4, 40)], fill=(90, 60, 40, 255))
            d.polygon([(cx - 5, 42), (cx, 26), (cx + 5, 42)], fill=(255, 140, 40, 255))
            d.polygon([(cx - 3, 42), (cx, 32), (cx + 3, 42)], fill=(255, 220, 80, 255))

    return img


def main():
    print("=" * 60)
    print("  HD 多变体地块 + 装饰道具生成")
    print("=" * 60)

    floor_count = 0
    prop_count = 0
    for region in REGIONS:
        for v in range(4):
            make_floor(region, v).save(TILES / f"floor_{region}_{v}.png")
            floor_count += 1
            make_prop(region, v).save(PROPS / f"prop_{region}_{v}.png")
            prop_count += 1
        # 同时覆盖默认 floor_<region>.png (变体0) 保持兼容
        make_floor(region, 0).save(TILES / f"floor_{region}.png")

    print(f"  [OK] {floor_count} 地板变体 (8区域 x 4)")
    print(f"  [OK] {prop_count} 装饰道具")
    print("=" * 60)


if __name__ == "__main__":
    main()
