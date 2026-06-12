#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
性能基准一键运行
========================================
跑 profile_runner.gd 并解析输出，给出友好摘要。

用法：
    python tools/run_profile.py                # 跑一次
    python tools/run_profile.py --baseline     # 保存为基线（后续回归比对）
    python tools/run_profile.py --compare      # 与基线对比

报告位置：project/src/performance_report.json（每次运行覆盖）
基线位置：tools/perf_baseline.json（手动保存）
"""
import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path

try:
    sys.stdout.reconfigure(encoding="utf-8")
except (AttributeError, ValueError):
    pass

ROOT = Path(__file__).resolve().parent.parent
GODOT = Path("d:/桌面/CC工具/tools/Godot_v4.3-stable_win64.exe")
PROJECT_SRC = ROOT / "project" / "src"
REPORT = PROJECT_SRC / "performance_report.json"
BASELINE = ROOT / "tools" / "perf_baseline.json"


def run_profile() -> dict:
    if not GODOT.exists():
        print(f"[FAIL] Godot 不存在: {GODOT}")
        sys.exit(1)
    print("[运行] profile_runner.gd ...")
    result = subprocess.run(
        [str(GODOT), "--headless", "--path", str(PROJECT_SRC),
         "-s", "res://tools/profile_runner.gd"],
        capture_output=True, text=True, encoding="utf-8", errors="replace"
    )
    # 输出 profiler 的关键行
    for line in result.stdout.splitlines():
        if any(k in line for k in ["[1/5]", "[2/5]", "[3/5]", "[4/5]", "[5/5]",
                                     "==========", "渲染器", "冷启动",
                                     "装备生成", "标签重算", "配置访问", "内存峰值"]):
            print(f"  {line}")
    if not REPORT.exists():
        print("[FAIL] 报告未生成")
        sys.exit(1)
    return json.loads(REPORT.read_text(encoding="utf-8"))


def summarize(data: dict) -> None:
    print("\n========== 性能摘要 ==========")
    meta = data.get("meta", {})
    print(f"渲染器: {meta.get('renderer', '?')}")
    print(f"时间戳: {meta.get('timestamp', '?')}")
    startup = data.get("startup", {})
    print(f"冷启动: {startup.get('cold_start_ms', '?')} ms")

    eq = data.get("equipment_gen", {})
    if "avg_us_per_item" in eq:
        print(f"装备生成: {eq['avg_us_per_item']:.1f} us/件 ({eq['items_per_sec']}/秒)")
    elif "skipped" in eq:
        print(f"装备生成: 跳过 ({eq['skipped']})")

    tag = data.get("tag_recompute", {})
    if "avg_us" in tag:
        print(f"标签重算: {tag['avg_us']:.1f} us/次")

    cfg = data.get("config_access", {})
    if "avg_us_per_call" in cfg:
        print(f"配置访问: {cfg['avg_us_per_call']:.2f} us/调用")

    mem = data.get("memory", {})
    if "static_mem_peak_bytes" in mem:
        print(f"内存峰值: {mem['static_mem_peak_bytes']/1024/1024:.1f} MB")
    print("==============================")


def compare_with_baseline(current: dict) -> None:
    if not BASELINE.exists():
        print("\n[!] 基线不存在，先用 --baseline 创建")
        return
    base = json.loads(BASELINE.read_text(encoding="utf-8"))
    print("\n========== 与基线对比 ==========")

    def diff(label, base_val, cur_val, unit=""):
        if base_val == 0:
            return
        delta_pct = (cur_val - base_val) / base_val * 100
        symbol = "↑" if delta_pct > 5 else ("↓" if delta_pct < -5 else "·")
        print(f"  {label}: {base_val:.1f}{unit} → {cur_val:.1f}{unit}  {symbol} {delta_pct:+.1f}%")

    # 冷启动
    if "startup" in base and "startup" in current:
        diff("冷启动", base["startup"]["cold_start_ms"],
             current["startup"]["cold_start_ms"], "ms")
    # 装备生成
    bg = base.get("equipment_gen", {})
    cg = current.get("equipment_gen", {})
    if "avg_us_per_item" in bg and "avg_us_per_item" in cg:
        diff("装备生成", bg["avg_us_per_item"], cg["avg_us_per_item"], "us/件")
    # 标签重算
    bt = base.get("tag_recompute", {})
    ct = current.get("tag_recompute", {})
    if "avg_us" in bt and "avg_us" in ct:
        diff("标签重算", bt["avg_us"], ct["avg_us"], "us/次")
    # 配置访问
    bc = base.get("config_access", {})
    cc = current.get("config_access", {})
    if "avg_us_per_call" in bc and "avg_us_per_call" in cc:
        diff("配置访问", bc["avg_us_per_call"], cc["avg_us_per_call"], "us/调用")
    # 内存
    bm = base.get("memory", {})
    cm = current.get("memory", {})
    if "static_mem_peak_bytes" in bm and "static_mem_peak_bytes" in cm:
        diff("内存峰值", bm["static_mem_peak_bytes"]/1024/1024,
             cm["static_mem_peak_bytes"]/1024/1024, "MB")
    print("================================")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--baseline", action="store_true", help="保存当前结果为基线")
    parser.add_argument("--compare", action="store_true", help="与基线对比")
    args = parser.parse_args()

    data = run_profile()
    summarize(data)

    if args.baseline:
        shutil.copy(REPORT, BASELINE)
        print(f"\n[OK] 基线已保存: {BASELINE.name}")

    if args.compare:
        compare_with_baseline(data)

    return 0


if __name__ == "__main__":
    sys.exit(main())
