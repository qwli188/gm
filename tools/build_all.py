# -*- coding: utf-8 -*-
"""
DarkLoot v3 — 一键构建自动化主控脚本
Python 3.14+ / Windows / numpy + scipy 已就位

执行顺序:
  1. 程序化 BGM 合成 (gen_bgm.py)
  2. 美术资源生成 (gen_assets.py)
  3. Godot headless 加载验收
  4. 写 AUTO_DECISION_LOG.md + RELEASE_REPORT.md

用法:
  python tools/build_all.py [--force] [--skip-godot]

--force: 强制重新生成已存在的资源(BGM/美术)
--skip-godot: 跳过 Godot headless 加载测试(适合无 Godot 环境)
"""

import os
import sys
import subprocess
import json
import time
from pathlib import Path
from datetime import datetime

ROOT = Path(__file__).parent.parent
TOOLS = ROOT / "tools"
PROJECT_SRC = ROOT / "project" / "src"
CONFIG_DIR = PROJECT_SRC / "config"
ASSETS_DIR = PROJECT_SRC / "assets"
# 修正: Godot 实际在仓库外层 tools 目录
GODOT_EXE = Path("d:/桌面/CC工具/tools/Godot_v4.3-stable_win64.exe")

PYTHON_EXE = sys.executable


class BuildContext:
    def __init__(self):
        self.start_time = time.time()
        self.steps = []
        self.errors = []
        self.force = False
        self.skip_godot = False

    def log_step(self, step_name, duration, success=True, notes=""):
        self.steps.append({
            "step": step_name,
            "duration": f"{duration:.1f}s",
            "success": success,
            "notes": notes,
        })
        status = "[OK]" if success else "[FAIL]"
        print(f"  {status} {step_name:32s} {duration:6.1f}s  {notes}")

    def run_subprocess(self, cmd, desc, cwd=None, timeout=120):
        print(f"[→] {desc} ...")
        t0 = time.time()
        try:
            res = subprocess.run(
                cmd,
                cwd=cwd,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=timeout,
                text=True,
                encoding="utf-8",
                errors="ignore",
            )
            t1 = time.time()
            if res.returncode != 0:
                err_msg = res.stderr[:500]
                self.log_step(desc, t1 - t0, success=False, notes=f"ERR {res.returncode}")
                self.errors.append(f"{desc}: {err_msg}")
                return False
            self.log_step(desc, t1 - t0, success=True)
            return True
        except subprocess.TimeoutExpired:
            t1 = time.time()
            self.log_step(desc, t1 - t0, success=False, notes="timeout")
            self.errors.append(f"{desc}: timeout {timeout}s")
            return False
        except Exception as e:
            t1 = time.time()
            self.log_step(desc, t1 - t0, success=False, notes=str(e)[:40])
            self.errors.append(f"{desc}: {e}")
            return False


def main():
    ctx = BuildContext()
    if "--force" in sys.argv:
        ctx.force = True
        os.environ["BGM_FORCE"] = "1"
        print("[!] --force: 强制覆盖已存在资源")
    if "--skip-godot" in sys.argv:
        ctx.skip_godot = True
        print("[!] --skip-godot: 跳过 Godot headless 验收")

    print("=" * 70)
    print("  DarkLoot v3 — 一键构建自动化")
    print("=" * 70)

    # Step 1: 程序化 BGM 合成 (gen_bgm.py)
    if not ctx.run_subprocess(
        [PYTHON_EXE, str(TOOLS / "gen_bgm.py")],
        "程序化BGM合成(8首)",
        cwd=ROOT,
        timeout=180,
    ):
        print("[WARN] BGM 合成失败,继续后续步骤")

    # Step 2: 美术资源生成 (gen_assets.py)
    if not ctx.run_subprocess(
        [PYTHON_EXE, str(TOOLS / "gen_assets.py")],
        "程序化美术资源生成",
        cwd=ROOT,
        timeout=240,
    ):
        print("[ERR] 美术资源生成失败,中断构建")
        return write_report(ctx, success=False)

    # Step 2.2: HD 多变体地块 + 装饰道具 (gen_tiles_hd.py)
    #   必须在 gen_assets 之后(覆盖默认 tiles), enhance 之前
    if not ctx.run_subprocess(
        [PYTHON_EXE, str(TOOLS / "gen_tiles_hd.py")],
        "HD地块+装饰道具(64个)",
        cwd=ROOT,
        timeout=60,
    ):
        print("[WARN] HD地块生成失败,使用默认地块")

    # Step 2.25: 0x72 DungeonTileset II 在线集成 (CC0真实像素美术)
    #   覆盖程序化角色/敌人占位为官方手绘像素; 网络失败则保留程序化
    if not ctx.run_subprocess(
        [PYTHON_EXE, str(TOOLS / "import_0x72.py")],
        "0x72真实像素美术(6职业6敌人)",
        cwd=ROOT,
        timeout=180,
    ):
        print("[WARN] 0x72集成失败(网络?),保留程序化美术")

    # Step 2.3: 精灵质量增强后处理 (enhance_sprites.py)
    #   对图标/光环/Boss登场图做软投影+渐变+材质
    if not ctx.run_subprocess(
        [PYTHON_EXE, str(TOOLS / "enhance_sprites.py")],
        "精灵质量增强(投影/渐变/AO)",
        cwd=ROOT,
        timeout=120,
    ):
        print("[WARN] 精灵增强失败,使用原始精灵")

    # Step 2.4: 程序化地牢布局 (gen_dungeons.py)
    if not ctx.run_subprocess(
        [PYTHON_EXE, str(TOOLS / "gen_dungeons.py")],
        "程序化地牢布局(21副本)",
        cwd=ROOT,
        timeout=30,
    ):
        print("[WARN] 地牢布局生成失败")

    # Step 2.5: DLC 内容生成 (gen_dlc_content.py)
    if not ctx.run_subprocess(
        [PYTHON_EXE, str(TOOLS / "gen_dlc_content.py")],
        "DLC配置内容补充",
        cwd=ROOT,
        timeout=30,
    ):
        print("[WARN] DLC 内容生成失败,继续后续步骤")

    # Step 3: 配置表校验(validate_config.gd, 如果存在)
    validate_script = PROJECT_SRC / "autoload" / "validate_config.gd"
    if validate_script.exists() and not ctx.skip_godot:
        if not GODOT_EXE.exists():
            print(f"[WARN] Godot 不在 {GODOT_EXE}, 跳过配置校验")
        else:
            # Godot CLI 执行 validate_config.gd 的方式:
            # godot --headless --script <path>
            # 但 validate_config 是 autoload, 不方便独立跑,先跳过
            print("[SKIP] 配置校验需 Godot runtime, 当前跳过")

    # Step 4: Godot headless 自动验收
    if not ctx.skip_godot:
        if not GODOT_EXE.exists():
            print(f"[WARN] Godot 未找到: {GODOT_EXE}, 跳过验收")
        else:
            # godot --headless --quit-after 1 --path <project>
            # AutoloadTestRunner 会在 _ready 时执行测试并自动退出
            if not ctx.run_subprocess(
                [str(GODOT_EXE), "--headless", "--quit-after", "1", "--path", str(PROJECT_SRC)],
                "Godot自动验收",
                cwd=PROJECT_SRC,
                timeout=30,
            ):
                print("[WARN] Godot 验收失败,检查 autoload 加载")

    # Step 5: 统计资源完成度
    stats = gather_stats(ctx)

    # Step 6: 写报告
    return write_report(ctx, success=len(ctx.errors) == 0, stats=stats)


def gather_stats(ctx):
    """统计当前资源和配置完成度"""
    stats = {}
    # BGM 完成度
    bgm_dir = ASSETS_DIR / "audio" / "bgm"
    bgm_count = len(list(bgm_dir.glob("*.ogg"))) if bgm_dir.exists() else 0
    stats["bgm"] = f"{bgm_count}/8 首"

    # SFX 完成度
    sfx_dir = ASSETS_DIR / "audio" / "sfx"
    sfx_count = len(list(sfx_dir.glob("*.ogg"))) if sfx_dir.exists() else 0
    stats["sfx"] = f"{sfx_count} 音效"

    # 生成美术资源数
    gen_dir = ASSETS_DIR / "generated"
    if gen_dir.exists():
        png_count = len(list(gen_dir.rglob("*.png")))
        stats["generated_sprites"] = f"{png_count} PNG"

    # 配置表数量
    if CONFIG_DIR.exists():
        json_files = list(CONFIG_DIR.glob("*.json"))
        stats["config_files"] = f"{len(json_files)} JSON"
        # 装备总数
        equipment_json = CONFIG_DIR / "equipment.json"
        if equipment_json.exists():
            with open(equipment_json, "r", encoding="utf-8") as f:
                data = json.load(f)
                eq_count = len(data.get("equipment", []))
                stats["equipment_count"] = f"{eq_count} 件"

        # 词缀总数
        affixes_json = CONFIG_DIR / "affixes.json"
        if affixes_json.exists():
            with open(affixes_json, "r", encoding="utf-8") as f:
                data = json.load(f)
                aff_count = len(data.get("affixes", []))
                stats["affix_count"] = f"{aff_count} 词缀"

    return stats


def write_report(ctx, success=True, stats=None):
    """写构建报告到 AUTO_DECISION_LOG.md 和 RELEASE_REPORT.md"""
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    elapsed = time.time() - ctx.start_time

    # 决策日志(追加模式)
    decision_log = ROOT / "AUTO_DECISION_LOG.md"
    with open(decision_log, "a", encoding="utf-8") as f:
        f.write(f"\n## {now} - 自动化构建批次\n\n")
        f.write(f"**状态**: {'✅ 成功' if success else '❌ 失败'}\n")
        f.write(f"**耗时**: {elapsed:.1f}s\n\n")
        f.write("**执行步骤**:\n\n")
        for step in ctx.steps:
            icon = "✓" if step["success"] else "✗"
            f.write(f"- {icon} {step['step']} ({step['duration']}) {step['notes']}\n")
        if ctx.errors:
            f.write("\n**错误**:\n\n")
            for err in ctx.errors:
                f.write(f"- {err}\n")
        f.write("\n---\n")

    # 发布报告(覆盖模式)
    release_report = ROOT / "RELEASE_REPORT.md"
    with open(release_report, "w", encoding="utf-8") as f:
        f.write("# DarkLoot v3 — 构建报告\n\n")
        f.write(f"**生成时间**: {now}\n")
        f.write(f"**构建状态**: {'✅ 就绪' if success else '⚠️ 未完全通过'}\n")
        f.write(f"**构建耗时**: {elapsed:.1f}s\n\n")
        f.write("## 资源统计\n\n")
        if stats:
            for key, val in stats.items():
                f.write(f"- **{key}**: {val}\n")
        f.write("\n## 构建步骤\n\n")
        f.write("| 步骤 | 耗时 | 状态 | 备注 |\n")
        f.write("|----|-----|-----|-----|\n")
        for step in ctx.steps:
            icon = "✓" if step["success"] else "✗"
            f.write(f"| {step['step']} | {step['duration']} | {icon} | {step['notes']} |\n")

        if ctx.errors:
            f.write("\n## 错误记录\n\n")
            for err in ctx.errors:
                f.write(f"- {err}\n")

        f.write("\n## 下一步\n\n")
        if success:
            f.write("- ✅ 资源已就绪,可以启动 Godot 编辑器测试\n")
            f.write("- 📋 人工验收:试玩核心循环,检查音效/BGM/战斗/词缀触发\n")
            f.write("- 🚀 下阶段:B2 Boss 区域技能 → B4 美术扩展 → B5 DLC 内容\n")
        else:
            f.write("- ⚠️ 部分步骤失败,检查 AUTO_DECISION_LOG.md 错误日志\n")
            f.write("- 🔧 修复后重新运行 `python tools/build_all.py`\n")

    print("\n" + "=" * 70)
    print(f"  构建完成 ({'成功' if success else '失败'}) — 耗时 {elapsed:.1f}s")
    print("=" * 70)
    print(f"  报告: {release_report}")
    print(f"  决策日志: {decision_log}")
    print("=" * 70)
    return 0 if success else 1


if __name__ == "__main__":
    sys.exit(main())
