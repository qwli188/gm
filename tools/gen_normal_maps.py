#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
2D 精灵法线贴图自动生成器
========================================
为现有 sprite 生成 *_n.png 法线贴图，配合 Godot CanvasItem 材质实现动态光照。

原理：
  1. 从 sprite 的 alpha 通道提取轮廓
  2. 用 Sobel 算子在亮度图上求梯度（X/Y 方向）
  3. 梯度映射为 RGB：R=X梯度, G=Y梯度, B=平整度
  4. 沿 alpha 边缘做斜面（bevel），让边缘处法线向外倾斜，模拟立体感

输出：
  对每个 sprite.png 生成同目录的 sprite_n.png
  Godot 中给 Sprite2D 加 CanvasItemMaterial，把 normal_map 指向 _n.png 即可

许可：脚本本身 MIT，输出归你所有（基于你输入的精灵）。

用法：
  python tools/gen_normal_maps.py                        # 处理全部 generated/sprites
  python tools/gen_normal_maps.py path/to/sprite.png     # 单文件
  python tools/gen_normal_maps.py --strength 1.5         # 调整法线强度
"""
import argparse
import sys
from pathlib import Path
from PIL import Image, ImageFilter

# 强制 stdout UTF-8（Windows GBK 控制台兼容）
try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

ROOT = Path(__file__).resolve().parent.parent
SPRITE_DIRS = [
    ROOT / "project" / "src" / "assets" / "generated" / "characters",
    ROOT / "project" / "src" / "assets" / "generated" / "enemies",
    ROOT / "project" / "src" / "assets" / "generated" / "bosses",
    ROOT / "project" / "src" / "assets" / "generated" / "props",
    ROOT / "project" / "src" / "assets" / "generated" / "icons",
]


def luminance(img: Image.Image) -> Image.Image:
    """RGBA → 灰度（仅基于 RGB，忽略 alpha）"""
    rgb = img.convert("RGB")
    return rgb.convert("L")


def sobel(img: Image.Image) -> tuple[Image.Image, Image.Image]:
    """返回 (Gx, Gy) 两张梯度图"""
    # Pillow 的 EDGE_ENHANCE / FIND_EDGES 是组合算子，自己用 Kernel 写更可控
    kx = ImageFilter.Kernel((3, 3),
                            [-1, 0, 1,
                             -2, 0, 2,
                             -1, 0, 1], scale=1, offset=128)
    ky = ImageFilter.Kernel((3, 3),
                            [-1, -2, -1,
                              0,  0,  0,
                              1,  2,  1], scale=1, offset=128)
    return img.filter(kx), img.filter(ky)


def build_normal(sprite_path: Path, strength: float = 1.0) -> Path | None:
    """对单个 sprite 生成法线贴图，返回输出路径（None=跳过）"""
    if "_n.png" in sprite_path.name:
        return None  # 已是法线贴图本身

    out_path = sprite_path.with_name(sprite_path.stem + "_n.png")

    img = Image.open(sprite_path).convert("RGBA")
    w, h = img.size
    alpha = img.split()[3]

    # 1) 亮度图（用于梯度计算）
    lum = luminance(img)
    # 模糊一下避免 1px 锯齿放大成噪点
    lum = lum.filter(ImageFilter.GaussianBlur(radius=0.7))

    # 2) Sobel 梯度
    gx, gy = sobel(lum)

    # 3) 组装法线 RGB：R=X(127为零), G=Y(127为零), B=平整(255)
    # 增加 strength 控制法线偏移强度
    r_band = gx.point(lambda v: int(128 + (v - 128) * strength))
    g_band = gy.point(lambda v: int(128 + (v - 128) * strength))
    # B 通道为高光朝向（Z 分量）：alpha 边缘附近降低 B 制造斜面
    b_band = alpha.point(lambda a: 255 if a > 200 else int(180 + a * 0.3))

    normal = Image.merge("RGB", (r_band, g_band, b_band))
    # 4) 透明区域置空（避免影响光照计算）
    normal_rgba = Image.merge("RGBA", (*normal.split(), alpha))

    normal_rgba.save(out_path)
    return out_path


def process_dir(dir_path: Path, strength: float, dry_run: bool) -> int:
    """处理目录下所有 PNG，返回生成数量"""
    if not dir_path.exists():
        return 0
    count = 0
    for p in sorted(dir_path.rglob("*.png")):
        if "_n.png" in p.name:
            continue
        if dry_run:
            print(f"  [dry] {p.relative_to(ROOT)}")
            count += 1
            continue
        out = build_normal(p, strength)
        if out:
            count += 1
            if count % 20 == 0:
                print(f"  ... 已生成 {count} 张")
    return count


def main() -> int:
    parser = argparse.ArgumentParser(description="2D 精灵法线贴图生成器")
    parser.add_argument("path", nargs="?", default=None, help="单个 PNG 文件（不指定则批量处理）")
    parser.add_argument("--strength", type=float, default=1.0, help="法线强度（默认 1.0）")
    parser.add_argument("--dry-run", action="store_true", help="仅列出，不写入")
    parser.add_argument("--dirs", nargs="*", help="自定义处理目录")
    args = parser.parse_args()

    if args.path:
        p = Path(args.path)
        if not p.exists():
            print(f"[FAIL] 文件不存在: {p}")
            return 1
        out = build_normal(p, args.strength)
        if out:
            print(f"[OK] {out.relative_to(ROOT) if out.is_relative_to(ROOT) else out}")
        return 0

    dirs = [Path(d).resolve() for d in args.dirs] if args.dirs else SPRITE_DIRS
    total = 0
    for d in dirs:
        if d.exists():
            try:
                rel = d.relative_to(ROOT)
                print(f"[处理] {rel}")
            except ValueError:
                print(f"[处理] {d}")
            total += process_dir(d, args.strength, args.dry_run)
    print(f"\n[完成] 共生成/识别 {total} 张法线贴图")
    return 0


if __name__ == "__main__":
    sys.exit(main())
