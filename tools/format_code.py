#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
GDScript 工程一键格式化 + 静态检查。

用法：
    python tools/format_code.py            # 格式化所有 .gd 并跑 lint
    python tools/format_code.py --check    # 只检查不改动（CI 用，有问题则退出码 1）
    python tools/format_code.py --lint-only

依赖 gdtoolkit（见 requirements.txt）。gdformat/gdlint 通过 `python -m` 调用，
无需把 Scripts 目录加进 PATH。
"""
import subprocess
import sys
from pathlib import Path

# Windows 控制台默认 GBK，强制 UTF-8 输出避免中文/符号编码错误
try:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "project" / "src"


def gd_files():
    return [
        str(p)
        for p in SRC.rglob("*.gd")
        if ".godot" not in p.parts
    ]


def run(module, args):
    cmd = [sys.executable, "-m", module] + args
    print(f"  $ {module} ({len(args)} files)" if len(args) > 5 else f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, cwd=str(SRC)).returncode


def main():
    check = "--check" in sys.argv
    lint_only = "--lint-only" in sys.argv
    files = gd_files()
    if not files:
        print("没有找到 .gd 文件")
        return 1
    print(f"目标：{len(files)} 个 GDScript 文件")

    rc = 0
    if not lint_only:
        print("[1/2] gdformat" + (" --check" if check else ""))
        fmt_args = (["--check"] if check else []) + files
        rc |= run("gdtoolkit.formatter", fmt_args)

    print("[2/2] gdlint")
    rc |= run("gdtoolkit.linter", files)

    if rc == 0:
        print("[OK] 全部通过")
    else:
        print("[FAIL] 存在问题（见上方输出）")
    return rc


if __name__ == "__main__":
    sys.exit(main())
