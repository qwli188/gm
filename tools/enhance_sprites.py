# -*- coding: utf-8 -*-
"""
精灵质量增强后处理器 (非破坏式)
对 gen_assets.py 生成的扁平精灵做"打磨":
  - 软投影 (drop shadow)
  - 垂直渐变光照 (顶亮底暗,仅作用于非透明像素)
  - 材质颗粒 (金属/布料噪点)
  - 边缘环境光遮蔽 (AO)
在 build 流程中紧跟 gen_assets 之后运行,作用于新生成的精灵。
"""
from pathlib import Path
from PIL import Image, ImageFilter, ImageChops
import random

ROOT = Path(__file__).parent.parent
GEN = ROOT / "project" / "src" / "assets" / "generated"


def _alpha_mask(img):
    """返回非透明区域掩码"""
    return img.split()[3]


def add_drop_shadow(img, offset=(2, 3), blur=3, opacity=110):
    """在精灵下方加柔和投影"""
    w, h = img.size
    pad = blur * 2 + max(abs(offset[0]), abs(offset[1]))
    canvas = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    # 投影 = 黑色 + alpha
    alpha = _alpha_mask(img)
    shadow = Image.new("RGBA", img.size, (0, 0, 0, opacity))
    shadow.putalpha(alpha.point(lambda a: int(a * opacity / 255)))
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(shadow, (pad + offset[0], pad + offset[1]))
    canvas.alpha_composite(img, (pad, pad))
    return canvas


def add_vertical_gradient_light(img, top_boost=1.18, bottom_dim=0.82):
    """垂直渐变光照: 顶部提亮, 底部压暗, 仅作用于非透明像素"""
    w, h = img.size
    rgb = img.convert("RGBA")
    px = rgb.load()
    alpha = _alpha_mask(img)
    apx = alpha.load()
    for y in range(h):
        # 线性插值 top_boost -> bottom_dim
        t = y / max(1, h - 1)
        factor = top_boost + (bottom_dim - top_boost) * t
        for x in range(w):
            if apx[x, y] == 0:
                continue
            r, g, b, a = px[x, y]
            px[x, y] = (
                min(255, int(r * factor)),
                min(255, int(g * factor)),
                min(255, int(b * factor)),
                a,
            )
    return rgb


def add_material_grain(img, strength=10, seed=0):
    """材质颗粒: 在非透明区叠加细噪点, 增加质感"""
    random.seed(seed)
    w, h = img.size
    rgb = img.convert("RGBA")
    px = rgb.load()
    alpha = _alpha_mask(img)
    apx = alpha.load()
    for y in range(h):
        for x in range(w):
            if apx[x, y] == 0:
                continue
            n = random.randint(-strength, strength)
            r, g, b, a = px[x, y]
            px[x, y] = (
                max(0, min(255, r + n)),
                max(0, min(255, g + n)),
                max(0, min(255, b + n)),
                a,
            )
    return rgb


def add_edge_ao(img, darkness=0.7):
    """边缘环境光遮蔽: 精灵轮廓内缘压暗, 增加体积感"""
    alpha = _alpha_mask(img)
    # 收缩alpha获得内缘
    eroded = alpha.filter(ImageFilter.MinFilter(3))
    edge = ImageChops.subtract(alpha, eroded)  # 边缘环
    edge = edge.filter(ImageFilter.GaussianBlur(1))
    rgb = img.convert("RGBA")
    px = rgb.load()
    epx = edge.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            e = epx[x, y]
            if e == 0:
                continue
            r, g, b, a = px[x, y]
            f = 1.0 - (e / 255.0) * (1.0 - darkness)
            px[x, y] = (int(r * f), int(g * f), int(b * f), a)
    return rgb


def enhance_sprite(img, seed=0, shadow=True):
    """完整增强管线"""
    out = add_vertical_gradient_light(img)
    out = add_edge_ao(out)
    out = add_material_grain(out, strength=8, seed=seed)
    if shadow:
        out = add_drop_shadow(out)
    return out


# 不加投影的类别(spritesheet逐帧/tile需保持原尺寸)
NO_SHADOW_DIRS = {"effects", "tiles", "characters", "enemies"}
# 完全跳过的类别(已是特殊用途)
SKIP_DIRS = {"dungeon_layouts"}


def process_all():
    """遍历 generated/ 增强所有静态精灵"""
    if not GEN.exists():
        print("  [WARN] generated/ 不存在,跳过增强")
        return 0

    count = 0
    for png in GEN.rglob("*.png"):
        rel = png.relative_to(GEN)
        top = rel.parts[0] if rel.parts else ""

        if top in SKIP_DIRS:
            continue

        # spritesheet 类(多帧横拼)不能整体加投影/渐变,会串色; 跳过
        # 仅处理单帧图标/光环/Boss登场图
        if top in {"icons", "sets", "bosses", "ui"}:
            try:
                img = Image.open(png).convert("RGBA")
                # ui 的按钮/面板不加投影(会改变九宫格), 只加渐变
                add_shadow = top in {"icons", "sets", "bosses"}
                seed = hash(str(rel)) % 100000
                enhanced = enhance_sprite(img, seed=seed, shadow=add_shadow)
                enhanced.save(png)
                count += 1
            except Exception as e:
                print(f"  [SKIP] {rel}: {e}")

    print(f"  [OK] 增强 {count} 张单帧精灵")
    return count


def main():
    print("=" * 60)
    print("  精灵质量增强后处理")
    print("=" * 60)
    n = process_all()
    print("=" * 60)
    print(f"  [完成] 处理 {n} 张")
    print("=" * 60)


if __name__ == "__main__":
    main()
