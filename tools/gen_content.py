#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
DarkLoot v3 批量内容生成器
用法：python gen_content.py --type equipment --count 10 --theme fire --slot weapon

功能：
1. 批量生成 N 件装备
2. 稀有度按权重分布（common 50%, rare 30%, epic 15%, legendary 5%）
3. 自动生成名字（主题词库 + 部位类别 + 稀有度形容词）
4. 数值按公式计算（base × rarity_mult × level_mult，对齐 content-spec-v3.md）
5. 词缀按主题标签匹配
6. 写入前校验，写入后调用 Godot 校验，输出生成报告
"""

import json
import os
import argparse
import random
from pathlib import Path

# ── 从 add_equipment.py 复用的核心配置 ──────────────────────────
RARITY_MULT = {
    "common": 1.0,
    "rare": 1.4,
    "epic": 1.9,
    "legendary": 2.6,
    "mythic": 3.5,
}

AFFIX_SLOTS = {
    "common": [0, 1],
    "rare": [2],
    "epic": [3],
    "legendary": [4],
    "mythic": [5],
}

SLOT_BASE_STATS = {
    "weapon":  {"damage": 12, "attack_speed": 1.0, "crit_chance": 0.05},
    "helmet":  {"armor": 8, "max_hp": 25, "crit_chance": 0.03},
    "chest":   {"armor": 15, "max_hp": 50},
    "legs":    {"armor": 10, "max_hp": 35, "move_speed": 0.05},
    "boots":   {"move_speed": 0.1, "armor": 5},
    "gloves":  {"attack_speed": 0.1, "crit_chance": 0.05},
    "ring":    {"crit_chance": 0.08, "crit_damage": 0.2},
    "amulet":  {"max_hp": 30, "hp_regen": 1.5},
}

THEME_CONFIG = {
    "shadow":  {"tags": ["shadow", "stealth", "crit"],   "affixes": ["affix_crit_chance", "affix_shadow_strike"]},
    "fire":    {"tags": ["fire", "magic", "damage"],      "affixes": ["affix_ignite", "affix_fire_damage"]},
    "frost":   {"tags": ["frost", "magic", "control"],    "affixes": ["affix_freeze", "affix_chill"]},
    "bone":    {"tags": ["undead", "lifesteal", "summon"],"affixes": ["affix_lifesteal", "affix_grave_strength"]},
    "plague":  {"tags": ["poison", "dot", "swamp"],       "affixes": ["affix_poison", "affix_contagion"]},
    "generic": {"tags": ["generic", "physical"],          "affixes": []},
}

VFX_LEVEL = {"common": 0, "rare": 1, "epic": 2, "legendary": 3, "mythic": 4}

# ── 稀有度权重分布 ───────────────────────────────────────────
RARITY_WEIGHTS = {"common": 50, "rare": 30, "epic": 15, "legendary": 5}

# ── 主题名字词库（形容词 + 按部位名词） ──────────────────────────
NAME_VOCAB = {
    "fire": {
        "adjectives": ["烈焰", "炽热", "燃烬", "余烬", "熔火", "灼热"],
        "nouns": {
            "weapon": ["剑", "斧", "锤", "刀", "枪", "法杖"],
            "helmet": ["盔", "冠", "面具", "兜帽"],
            "chest": ["甲", "战铠", "护胸", "战袍"],
            "legs": ["护腿", "战裤", "腿甲"],
            "boots": ["战靴", "踏足", "行者"],
            "gloves": ["护手", "拳套", "手甲"],
            "ring": ["戒指", "指环", "徽记"],
            "amulet": ["项链", "护符", "吊坠"],
        },
    },
    "frost": {
        "adjectives": ["冰霜", "寒冰", "凛冬", "冰封", "霜寒", "凝霜"],
        "nouns": {
            "weapon": ["剑", "法杖", "弓", "匕首", "镰刀"],
            "helmet": ["冠", "盔", "面具", "兜帽"],
            "chest": ["铠", "甲", "外衣", "护胸"],
            "legs": ["护腿", "腿甲", "裹腿"],
            "boots": ["战靴", "踏雪", "冰靴"],
            "gloves": ["手套", "护手", "冰爪"],
            "ring": ["戒指", "冰环", "指环"],
            "amulet": ["项链", "护符", "冰坠"],
        },
    },
    "shadow": {
        "adjectives": ["暗影", "幽影", "夜影", "阴影", "暗夜", "幽暗"],
        "nouns": {
            "weapon": ["匕首", "刀", "剑", "弓", "刺针"],
            "helmet": ["兜帽", "面具", "头罩", "头巾"],
            "chest": ["披风", "暗衣", "夜袍", "护甲"],
            "legs": ["腿甲", "裹腿", "夜行裤"],
            "boots": ["轻靴", "疾行靴", "无声靴"],
            "gloves": ["手套", "刺客手", "影爪"],
            "ring": ["戒指", "影环", "暗印"],
            "amulet": ["项链", "暗符", "影坠"],
        },
    },
    "bone": {
        "adjectives": ["枯骨", "白骨", "死骨", "骸骨", "尸骨", "亡骨"],
        "nouns": {
            "weapon": ["镰刀", "剑", "锤", "权杖", "骨刃"],
            "helmet": ["骷髅盔", "骨冠", "头骨", "面具"],
            "chest": ["骨甲", "亡灵铠", "骨胸", "尸衣"],
            "legs": ["骨腿", "腿骨", "骨护"],
            "boots": ["骨靴", "亡者足", "踏骨靴"],
            "gloves": ["骨爪", "骨手", "尸手"],
            "ring": ["骨戒", "亡灵环", "骸骨印"],
            "amulet": ["骨坠", "亡灵符", "骷髅链"],
        },
    },
    "plague": {
        "adjectives": ["疫病", "瘟疫", "毒瘴", "腐败", "病疫", "瘴毒"],
        "nouns": {
            "weapon": ["匕首", "法杖", "弓", "毒爪", "刃"],
            "helmet": ["面具", "头盔", "头罩", "兜帽"],
            "chest": ["袍", "护甲", "腐衣", "毒铠"],
            "legs": ["腿甲", "毒裤", "腐腿"],
            "boots": ["毒靴", "瘴踏", "腐足"],
            "gloves": ["毒手", "腐爪", "病手"],
            "ring": ["毒戒", "疫环", "病印"],
            "amulet": ["瘴坠", "疫符", "毒链"],
        },
    },
    "generic": {
        "adjectives": ["锻铁", "钢铁", "坚固", "锐利", "粗糙", "精制"],
        "nouns": {
            "weapon": ["剑", "斧", "锤", "枪", "刀"],
            "helmet": ["盔", "头盔", "兜帽"],
            "chest": ["甲", "护胸", "战铠"],
            "legs": ["腿甲", "护腿"],
            "boots": ["战靴", "皮靴"],
            "gloves": ["手套", "护手"],
            "ring": ["戒指", "指环"],
            "amulet": ["项链", "护符"],
        },
    },
}

# 形容词中文 → 英文 ID 片段
ADJ_PINYIN = {
    "烈焰": "flame", "炽热": "searing", "燃烬": "ember", "余烬": "cinder",
    "熔火": "molten", "灼热": "scorching",
    "冰霜": "frost", "寒冰": "ice", "凛冬": "winter", "冰封": "frozen",
    "霜寒": "chill", "凝霜": "rime",
    "暗影": "shadow", "幽影": "shade", "夜影": "night", "阴影": "dark",
    "暗夜": "dusk", "幽暗": "gloom",
    "枯骨": "bone", "白骨": "skull", "死骨": "death", "骸骨": "skeletal",
    "尸骨": "corpse", "亡骨": "undead",
    "疫病": "plague", "瘟疫": "pestilence", "毒瘴": "venom", "腐败": "rot",
    "病疫": "disease", "瘴毒": "toxic",
    "锻铁": "iron", "钢铁": "steel", "坚固": "sturdy", "锐利": "sharp",
    "粗糙": "crude", "精制": "fine",
}

LEGENDARY_SUFFIX = ["传说", "君王", "霸主", "至高"]
MYTHIC_SUFFIX = ["神话", "永恒", "不朽", "起源"]


def choose_rarity() -> str:
    """按权重随机选择稀有度"""
    rarities = list(RARITY_WEIGHTS.keys())
    weights = list(RARITY_WEIGHTS.values())
    return random.choices(rarities, weights=weights)[0]


def generate_name(theme: str, slot: str, rarity: str):
    """生成装备名字，返回 (名字, 形容词英文片段)"""
    vocab = NAME_VOCAB.get(theme, NAME_VOCAB["generic"])
    adj = random.choice(vocab["adjectives"])
    noun = random.choice(vocab["nouns"].get(slot, ["装备"]))

    suffix = ""
    if rarity == "legendary":
        suffix = "·" + random.choice(LEGENDARY_SUFFIX)
    elif rarity == "mythic":
        suffix = "·" + random.choice(MYTHIC_SUFFIX)

    name = f"{adj}之{noun}{suffix}"
    adj_en = ADJ_PINYIN.get(adj, "item")
    return name, adj_en


def generate_id(adj_en: str, slot: str, rarity: str, index: int) -> str:
    """生成唯一 ID（带索引避免重复）"""
    return f"{slot}_{adj_en}_{rarity}_{index}"


def calculate_base_stats(slot: str, rarity: str, drop_level: int = 1) -> dict:
    """按公式计算基础属性：base × rarity_mult × level_mult"""
    base = SLOT_BASE_STATS.get(slot, {}).copy()
    mult = RARITY_MULT[rarity]
    level_mult = 1.0 + 0.15 * (drop_level - 1)

    for k in base:
        # 百分比加成类（攻速/移速）不乘稀有度
        if k in ["attack_speed", "move_speed"]:
            continue
        base[k] = round(base[k] * mult * level_mult, 2)

    return base


def choose_affixes(theme: str, rarity: str) -> list:
    """根据主题和稀有度选择固定词缀（按主题标签匹配）"""
    theme_cfg = THEME_CONFIG.get(theme, THEME_CONFIG["generic"])
    max_affixes = AFFIX_SLOTS[rarity][0]
    return theme_cfg["affixes"][:max_affixes]


def validate_item(item: dict) -> list:
    """写入前校验（对齐 _schema_standard.json 的 equipment 必填字段）"""
    required = ["id", "display_name", "slot", "rarity", "base_stats",
                "affix_slots", "set_id", "vfx_level", "drop_level"]
    errors = []
    for field in required:
        if field not in item:
            errors.append(f"缺少必填字段: {field}")
    if item.get("rarity") not in RARITY_MULT:
        errors.append(f"非法稀有度: {item.get('rarity')}")
    if item.get("slot") not in SLOT_BASE_STATS:
        errors.append(f"非法部位: {item.get('slot')}")
    return errors


def generate_equipment(theme: str, slot: str, drop_level: int, index: int) -> dict:
    """生成单件装备"""
    rarity = choose_rarity()
    name, adj_en = generate_name(theme, slot, rarity)
    item_id = generate_id(adj_en, slot, rarity, index)
    base_stats = calculate_base_stats(slot, rarity, drop_level)
    affixes = choose_affixes(theme, rarity)
    theme_cfg = THEME_CONFIG.get(theme, THEME_CONFIG["generic"])

    return {
        "id": item_id,
        "display_name": name,
        "slot": slot,
        "category": slot,
        "rarity": rarity,
        "tags": theme_cfg["tags"],
        "base_stats": base_stats,
        "affix_slots": AFFIX_SLOTS[rarity][0],
        "fixed_affixes": affixes,
        "set_id": "",
        "vfx_level": VFX_LEVEL[rarity],
        "drop_level": drop_level,
        "design_note": f"批量生成 - {theme}主题 {slot} {rarity}",
    }


def append_to_equipment_json(items: list, config_path: str) -> int:
    """批量追加到 equipment.json，处理 ID 冲突"""
    with open(config_path, "r", encoding="utf-8") as f:
        data = json.load(f)

    existing_ids = {x["id"] for x in data.get("items", [])}
    added = 0

    for item in items:
        original_id = item["id"]
        counter = 2
        while item["id"] in existing_ids:
            item["id"] = f"{original_id}_v{counter}"
            counter += 1
        existing_ids.add(item["id"])
        data.setdefault("items", []).append(item)
        added += 1

    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

    return added


def validate_config(project_root: str):
    """调用 Godot 校验脚本（同 add_equipment.py 逻辑）"""
    godot_exe = project_root + "/../tools/Godot_v4.3-stable_win64.exe"
    validate_script = project_root + "/project/src/validate_config.gd"

    if not os.path.exists(godot_exe):
        print("⚠️  Godot 不存在，跳过自动校验")
        return

    print("🔍 运行配置校验...")
    os.system(f'"{godot_exe}" --headless --path "{project_root}/project/src" -s "{validate_script}" --quit')


def print_report(items: list):
    """输出生成报告"""
    print("\n📊 生成报告")
    print("=" * 64)

    rarity_counts = {}
    for item in items:
        r = item["rarity"]
        rarity_counts[r] = rarity_counts.get(r, 0) + 1

    total = len(items)
    print(f"总计: {total} 件装备\n")
    print("稀有度分布:")
    for rarity in ["common", "rare", "epic", "legendary", "mythic"]:
        count = rarity_counts.get(rarity, 0)
        if count > 0:
            pct = count / total * 100
            print(f"  {rarity:12s}: {count:3d} ({pct:5.1f}%)")

    print("\n装备概要:")
    for i, item in enumerate(items, 1):
        stats = ", ".join(f"{k}={v}" for k, v in item["base_stats"].items())
        affix = f" 词缀:{len(item['fixed_affixes'])}" if item["fixed_affixes"] else ""
        print(f"  {i:2d}. [{item['rarity']:10s}] {item['display_name']:18s} | {stats}{affix}")

    print("=" * 64)


def main():
    parser = argparse.ArgumentParser(description="DarkLoot v3 批量内容生成器")
    parser.add_argument("--type", default="equipment", choices=["equipment"], help="生成类型（当前仅支持 equipment）")
    parser.add_argument("--count", type=int, required=True, help="生成数量")
    parser.add_argument("--theme", required=True, choices=list(THEME_CONFIG.keys()), help="主题（决定词库/标签/词缀）")
    parser.add_argument("--slot", required=True, choices=list(SLOT_BASE_STATS.keys()), help="装备部位")
    parser.add_argument("--drop-level", type=int, default=1, help="掉落等级（1-5）")
    parser.add_argument("--no-validate", action="store_true", help="跳过 Godot 自动校验")
    parser.add_argument("--seed", type=int, help="随机种子（用于复现）")

    args = parser.parse_args()

    if args.seed is not None:
        random.seed(args.seed)
        print(f"🎲 随机种子: {args.seed}")

    print(f"\n🔨 批量生成 {args.count} 件 {args.theme} 主题 {args.slot}")
    print("   稀有度分布: common 50%, rare 30%, epic 15%, legendary 5%\n")

    items = []
    for i in range(args.count):
        item = generate_equipment(args.theme, args.slot, args.drop_level, i + 1)
        errors = validate_item(item)
        if errors:
            print(f"  ❌ 第 {i+1} 件校验失败: {'; '.join(errors)}，已跳过")
            continue
        items.append(item)
        print(f"  生成 {i+1}/{args.count}: {item['display_name']} ({item['rarity']})")

    if not items:
        print("\n❌ 没有有效装备生成，退出")
        return

    project_root = Path(__file__).parent.parent
    config_path = project_root / "project/src/config/equipment.json"
    added = append_to_equipment_json(items, str(config_path))
    print(f"\n✅ 已追加 {added} 件装备到 equipment.json")

    if not args.no_validate:
        validate_config(str(project_root))

    print_report(items)
    print("\n✅ 完成！下一步：启动 Godot 查看效果")


if __name__ == "__main__":
    main()
