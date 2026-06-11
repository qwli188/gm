#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
渲染器一键切换工具
========================================
在 gl_compatibility / mobile / forward_plus 之间切换。

用法：
    python tools/switch_renderer.py mobile           # 切到 mobile（解锁动态光照）
    python tools/switch_renderer.py gl_compatibility # 回滚到兼容模式
    python tools/switch_renderer.py status           # 显示当前渲染器
    python tools/switch_renderer.py forward_plus     # 切到桌面 PC 旗舰渲染器

切换后建议：
    1. 重新跑测试：tools/run_tests.bat
    2. 在编辑器打开工程一次，让 shader 重新编译
    3. 详细评估见 docs/Renderer_Upgrade_Evaluation.md
"""
import re
import sys
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

ROOT = Path(__file__).resolve().parent.parent
PROJECT_GODOT = ROOT / "project" / "src" / "project.godot"

VALID_RENDERERS = {"gl_compatibility", "mobile", "forward_plus"}


def get_current_renderer() -> str:
    text = PROJECT_GODOT.read_text(encoding="utf-8")
    match = re.search(r'renderer/rendering_method="([^"]+)"', text)
    return match.group(1) if match else "unknown"


def switch_to(target: str) -> int:
    text = PROJECT_GODOT.read_text(encoding="utf-8")

    new_text = re.sub(
        r'renderer/rendering_method="[^"]+"',
        f'renderer/rendering_method="{target}"',
        text,
    )
    new_text = re.sub(
        r'renderer/rendering_method\.mobile="[^"]+"',
        f'renderer/rendering_method.mobile="{target}"',
        new_text,
    )

    if new_text == text:
        print(f"[NOOP] 已经是 {target}，无需切换")
        return 0

    PROJECT_GODOT.write_text(new_text, encoding="utf-8")
    print(f"[OK] 渲染器已切换为: {target}")
    print()
    print("后续步骤：")
    print("  1. 删除 .godot/ 缓存让 shader 重新编译（可选，但推荐）：")
    print("     rm -rf project/src/.godot/")
    print("  2. 在 Godot 编辑器打开工程一次，让导入器重建")
    print("  3. 跑测试确认: tools/run_tests.bat")
    print()
    if target == "mobile":
        print("✓ 已解锁: PointLight2D 动态光照、完整法线贴图、自由 shader")
        print("  生成法线贴图: python tools/gen_normal_maps.py")
    elif target == "forward_plus":
        print("✓ 桌面 PC 旗舰：所有特性可用，但要求 Vulkan + 现代 GPU")
    else:
        print("✓ 兼容性最广（OpenGL 2.0+），但失去动态光照等特性")
    return 0


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 1

    cmd = sys.argv[1]

    if cmd == "status":
        print(f"当前渲染器: {get_current_renderer()}")
        return 0

    if cmd not in VALID_RENDERERS:
        print(f"[FAIL] 无效渲染器: {cmd}")
        print(f"       可选: {', '.join(sorted(VALID_RENDERERS))} | status")
        return 1

    current = get_current_renderer()
    print(f"当前: {current}  →  目标: {cmd}")
    return switch_to(cmd)


if __name__ == "__main__":
    sys.exit(main())
