#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
DarkLoot v3 装备快速生成工具
用法：python add_equipment.py --name "暗影匕首" --slot weapon --rarity epic --theme shadow

功能：
1. 按公式自动计算基础数值（对齐 content-spec-v3.md）
2. 智能分配词缀槽和固定词缀（基于主题标签）
3. 追加到 equipment.json（保持格式）
4. 自动校验（调用 validate_config.gd）
5. 输出 Godot 可直接使用的条目

目标：从 30 分钟降到 3 分钟
"""

import json
import sys
import os
import argparse
from pathlib import Path

# 稀有度数值乘数（对齐 content-spec-v3.md）
RARITY_MULT = {
    "common": 1.0,
    "rare": 1.4,
    "epic": 1.9,
    "legendary": 2.6,
    "mythic": 3.5
}

# 词缀槽数量（对齐 content-spec-v3.md）
AFFIX_SLOTS = {
    "common": [0, 1],
    "rare": [2],
    "epic": [3],
    "legendary": [4],
    "mythic": [5]
}

# 部位基础数值模板（weapon/helmet/chest/etc）
SLOT_BASE_STATS = {
    "weapon": {
        "damage": 12,
        "attack_speed": 1.0,
        "crit_chance": 0.05
    },
    "helmet": {
        "armor": 8,
        "max_hp": 25,
        "crit_chance": 0.03
    },
    "chest": {
        "armor": 15,
        "max_hp": 50
    },
    "legs": {
        "armor": 10,
        "max_hp": 35,
        "move_speed": 0.05
    },
    "boots": {
        "move_speed": 0.1,
        "armor": 5
    },
    "gloves": {
        "attack_speed": 0.1,
        "crit_chance": 0.05
    },
    "ring": {
        "crit_chance": 0.08,
        "crit_damage": 0.2
    },
    "amulet": {
        "max_hp": 30,
        "hp_regen": 1.5
    }
}

# 主题 → 标签 + 固定词缀映射
THEME_CONFIG = {
    "shadow": {
        "tags": ["shadow", "stealth", "crit"],
        "affixes": ["affix_crit_chance", "affix_shadow_strike"]
    },
    "fire": {
        "tags": ["fire", "magic", "damage"],
        "affixes": ["affix_ignite", "affix_fire_damage"]
    },
    "frost": {
        "tags": ["frost", "magic", "control"],
        "affixes": ["affix_freeze", "affix_chill"]
    },
    "bone": {
        "tags": ["undead", "lifesteal", "summon"],
        "affixes": ["affix_lifesteal", "affix_grave_strength"]
    },
    "plague": {
        "tags": ["poison", "dot", "swamp"],
        "affixes": ["affix_poison", "affix_contagion"]
    },
    "generic": {
        "tags": ["generic", "physical"],
        "affixes": []
    }
}

def generate_id(name: str, slot: str, rarity: str) -> str:
    """生成符合规范的 ID"""
    # 中文转拼音简化版（实际项目应用 pypinyin）
    name_en = name.lower().replace(" ", "_").replace("暗影", "shadow").replace("匕首", "dagger") \
                  .replace("烈焰", "flame").replace("法杖", "staff").replace("冰霜", "frost") \
                  .replace("白骨", "bone").replace("疫病", "plague")
    return f"{slot}_{name_en}_{rarity}"

def calculate_base_stats(slot: str, rarity: str, drop_level: int = 1) -> dict:
    """按公式计算基础属性"""
    base = SLOT_BASE_STATS.get(slot, {}).copy()
    mult = RARITY_MULT[rarity]
    level_mult = 1.0 + 0.15 * (drop_level - 1)

    # 应用乘数
    for k in base:
        if k in ["attack_speed", "move_speed"]:
            # 百分比加成类不乘稀有度
            continue
        base[k] = round(base[k] * mult * level_mult, 2)

    return base

def choose_affixes(theme: str, rarity: str) -> list:
    """根据主题和稀有度选择固定词缀"""
    theme_cfg = THEME_CONFIG.get(theme, THEME_CONFIG["generic"])
    affixes = theme_cfg["affixes"][:AFFIX_SLOTS[rarity][0]]  # 最多取词缀槽数量
    return affixes

def generate_equipment(name: str, slot: str, rarity: str, theme: str = "generic", drop_level: int = 1) -> dict:
    """生成完整装备条目"""
    item_id = generate_id(name, slot, rarity)
    base_stats = calculate_base_stats(slot, rarity, drop_level)
    affixes = choose_affixes(theme, rarity)
    theme_cfg = THEME_CONFIG.get(theme, THEME_CONFIG["generic"])

    item = {
        "id": item_id,
        "display_name": name,
        "slot": slot,
        "category": slot,  # 简化，实际可细分 sword/dagger/staff 等
        "rarity": rarity,
        "tags": theme_cfg["tags"],
        "base_stats": base_stats,
        "affix_slots": AFFIX_SLOTS[rarity][0],
        "fixed_affixes": affixes,
        "set_id": "",
        "vfx_level": {"common": 0, "rare": 1, "epic": 2, "legendary": 3, "mythic": 4}[rarity],
        "drop_level": drop_level,
        "design_note": f"{name} - {theme} 主题 {rarity} 装备，自动生成"
    }

    return item

def append_to_equipment_json(item: dict, config_path: str):
    """追加到 equipment.json"""
    with open(config_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    # 检查重复 ID
    existing_ids = {x["id"] for x in data.get("items", [])}
    if item["id"] in existing_ids:
        print(f"⚠️  警告：ID {item['id']} 已存在，自动添加后缀 _v2")
        item["id"] += "_v2"

    data.setdefault("items", []).append(item)

    with open(config_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    print(f"✅ 已追加到 equipment.json")

def validate_config(project_root: str):
    """调用 Godot 校验脚本"""
    godot_exe = project_root + "/../tools/Godot_v4.3-stable_win64.exe"
    validate_script = project_root + "/project/src/validate_config.gd"

    if not os.path.exists(godot_exe):
        print("⚠️  Godot 不存在，跳过自动校验")
        return

    print("🔍 运行配置校验...")
    os.system(f'"{godot_exe}" --headless --path "{project_root}/project/src" -s "{validate_script}" --quit')

def main():
    parser = argparse.ArgumentParser(description='DarkLoot v3 装备快速生成工具')
    parser.add_argument('--name', required=True, help='装备名称（中文或英文）')
    parser.add_argument('--slot', required=True, choices=list(SLOT_BASE_STATS.keys()), help='装备部位')
    parser.add_argument('--rarity', required=True, choices=list(RARITY_MULT.keys()), help='稀有度')
    parser.add_argument('--theme', default='generic', choices=list(THEME_CONFIG.keys()), help='主题（决定标签和词缀）')
    parser.add_argument('--drop-level', type=int, default=1, help='掉落等级（1-5）')
    parser.add_argument('--no-validate', action='store_true', help='跳过自动校验')

    args = parser.parse_args()

    # 生成装备
    print(f"\n🔨 生成装备：{args.name} ({args.rarity} {args.slot})")
    item = generate_equipment(args.name, args.slot, args.rarity, args.theme, args.drop_level)

    # 输出预览
    print("\n📋 装备预览：")
    print(json.dumps(item, ensure_ascii=False, indent=2))

    # 追加到配置文件
    project_root = Path(__file__).parent.parent
    config_path = project_root / "project/src/config/equipment.json"
    append_to_equipment_json(item, str(config_path))

    # 校验
    if not args.no_validate:
        validate_config(str(project_root))

    print(f"\n✅ 完成！装备 ID: {item['id']}")
    print(f"   下一步：启动 Godot 查看效果")

if __name__ == "__main__":
    main()
