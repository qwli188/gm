#!/usr/bin/env python3
"""
素材接入验证脚本（asset_validator.py）
用途：批量检查 assets/generated/ 下的素材是否符合 DarkLoot 规范
运行：python asset_validator.py
"""
import os
import json
from pathlib import Path

PROJECT_ROOT = Path(__file__).parent.parent / "project"
ASSETS_DIR = PROJECT_ROOT / "assets" / "generated"

# 规范（来自 asset-procurement.md）
SPECS = {
    "characters": {
        "count": 8,
        "classes": ["warrior", "ranger", "mage", "assassin", "knight", "necromancer", "frost_witch", "shadow_archer"],
        "files_per_class": ["idle.png", "walk.png", "attack.png", "hurt.png", "portrait.png"],
        "frame_size": (64, 64),
        "sheet_width": 256,  # 4 帧最小
    },
    "enemies": {
        "count": 6,
        "families": ["skeleton", "slime", "demon", "ice", "void", "beast"],
        "files_per_family": ["idle.png", "attack.png", "static.png"],
        "frame_size": (64, 64),
        "sheet_width": 256,
    },
    "equipment_icons": {
        "kinds": ["sword", "staff", "bow", "helmet", "chest", "legs", "boots", "gloves", "ring", "amulet"],
        "rarities": ["common", "rare", "epic", "legendary", "mythic"],
        "min_per_kind": 1,  # 至少 1 张 common
        "icon_size": (64, 64),
    },
}

def check_image_size(path: Path, expected_w: int, expected_h: int, allow_multiples: bool = False):
    """检查图片尺寸（需要 PIL）"""
    try:
        from PIL import Image
        img = Image.open(path)
        w, h = img.size
        if h != expected_h:
            return False, f"高度错误: {h} (期望 {expected_h})"
        if allow_multiples:
            if w % expected_w != 0:
                return False, f"宽度 {w} 不是 {expected_w} 的整数倍"
            if w < expected_w:
                return False, f"宽度 {w} 小于最小值 {expected_w}"
        else:
            if w != expected_w:
                return False, f"宽度错误: {w} (期望 {expected_w})"
        return True, f"{w}×{h}"
    except ImportError:
        return None, "PIL 未安装，跳过尺寸检查"
    except Exception as e:
        return False, str(e)

def check_import_filter(path: Path):
    """检查 .import 文件的 filter 设置"""
    import_path = Path(str(path) + ".import")
    if not import_path.exists():
        return False, ".import 文件不存在"
    try:
        content = import_path.read_text(encoding="utf-8")
        if "filter=false" in content or "filter = false" in content:
            return True, "✓"
        else:
            return False, "filter 未关闭（像素风必须 filter=false）"
    except Exception as e:
        return False, str(e)

def validate_characters():
    print("\n=== 角色精灵检查 ===")
    char_dir = ASSETS_DIR / "characters"
    if not char_dir.exists():
        print("❌ characters/ 目录不存在")
        return

    for cls in SPECS["characters"]["classes"]:
        cls_dir = char_dir / cls
        if not cls_dir.exists():
            print(f"⚠️  {cls}/ 目录不存在")
            continue

        for fname in SPECS["characters"]["files_per_class"]:
            fpath = cls_dir / fname
            if not fpath.exists():
                print(f"  ❌ {cls}/{fname} 缺失")
                continue

            # 检查尺寸
            if fname == "portrait.png":
                ok, msg = check_image_size(fpath, 64, 64, allow_multiples=False)
            else:
                ok, msg = check_image_size(fpath, 64, 64, allow_multiples=True)

            # 检查 import
            import_ok, import_msg = check_import_filter(fpath)

            status = "✅" if (ok or ok is None) and import_ok else "❌"
            print(f"  {status} {cls}/{fname}  尺寸:{msg}  filter:{import_msg}")

def validate_enemies():
    print("\n=== 敌人精灵检查 ===")
    enemy_dir = ASSETS_DIR / "enemies"
    if not enemy_dir.exists():
        print("❌ enemies/ 目录不存在")
        return

    for fam in SPECS["enemies"]["families"]:
        fam_dir = enemy_dir / fam
        if not fam_dir.exists():
            print(f"⚠️  {fam}/ 目录不存在")
            continue

        for fname in SPECS["enemies"]["files_per_family"]:
            fpath = fam_dir / fname
            if not fpath.exists():
                print(f"  ❌ {fam}/{fname} 缺失")
                continue

            if fname == "static.png":
                ok, msg = check_image_size(fpath, 64, 64, allow_multiples=False)
            else:
                ok, msg = check_image_size(fpath, 64, 64, allow_multiples=True)

            import_ok, import_msg = check_import_filter(fpath)
            status = "✅" if (ok or ok is None) and import_ok else "❌"
            print(f"  {status} {fam}/{fname}  尺寸:{msg}  filter:{import_msg}")

def validate_equipment_icons():
    print("\n=== 装备图标检查 ===")
    icon_dir = ASSETS_DIR / "icons" / "equipment"
    if not icon_dir.exists():
        print("❌ icons/equipment/ 目录不存在")
        return

    for kind in SPECS["equipment_icons"]["kinds"]:
        found = []
        for rarity in SPECS["equipment_icons"]["rarities"]:
            fname = f"{kind}_{rarity}.png"
            fpath = icon_dir / fname
            if fpath.exists():
                found.append(rarity)
                ok, msg = check_image_size(fpath, 64, 64)
                import_ok, import_msg = check_import_filter(fpath)
                status = "✅" if (ok or ok is None) and import_ok else "❌"
                print(f"  {status} {fname}  尺寸:{msg}  filter:{import_msg}")

        if len(found) == 0:
            print(f"  ❌ {kind}_* 一张都没有（至少需要 common）")
        elif "common" not in found:
            print(f"  ⚠️  {kind} 缺少 common（回退图）")

def main():
    print("DarkLoot 素材接入验证")
    print("=" * 50)

    if not ASSETS_DIR.exists():
        print(f"❌ 素材目录不存在: {ASSETS_DIR}")
        return

    validate_characters()
    validate_enemies()
    validate_equipment_icons()

    print("\n" + "=" * 50)
    print("提示: 如需修复 filter 设置，在 Godot 编辑器中选中图片 → Import → Filter 关闭 → Reimport")
    print("或批量修改: 用文本编辑器打开 .import 文件，添加或修改 `filter = false`")

if __name__ == "__main__":
    main()
