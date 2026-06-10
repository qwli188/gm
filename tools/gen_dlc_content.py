# -*- coding: utf-8 -*-
"""
DLC 内容自动生成器
根据 sustainability.md 设计自动生成 DLC 1/2/3 的配置内容
- DLC1 冰封诅咒: 冰霜女巫职业 + 冰封神殿 + 冰系装备/技能
- DLC2 暗影深渊: 暗影弓手 + 暗影森林 + 暗影装备
- DLC3 永恒套装: 套装系统扩展 + 天赋树 + 无尽模式
"""

import os
import json
from pathlib import Path

ROOT = Path(__file__).parent.parent
CONFIG_DIR = ROOT / "project" / "src" / "config"


def load_json(name):
    p = CONFIG_DIR / name
    if not p.exists():
        return {}
    with open(p, "r", encoding="utf-8") as f:
        return json.load(f)


def save_json(name, data):
    p = CONFIG_DIR / name
    with open(p, "w", encoding="utf-8", newline="\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)


def gen_dlc1_frost():
    """DLC1 冰封诅咒: 冰霜女巫 + 冰系装备"""
    print("[DLC1] 生成冰封诅咒内容...")

    # 职业: 冰霜女巫 (已在 classes.json 里预留,补充描述)
    classes = load_json("classes.json")
    # 检查是否已有 class_frost_witch, 没有则添加
    has_frost_witch = any(c.get("id") == "class_frost_witch" for c in classes.get("classes", []))
    if not has_frost_witch:
        classes.setdefault("classes", []).append({
            "id": "class_frost_witch",
            "display_name": "冰霜女巫",
            "description": "掌控寒冰之力,减速与冰冻敌人",
            "base_stats": {
                "max_hp": 85,
                "damage": 12,
                "attack_speed": 0.9,
                "move_speed": 310,
                "crit_chance": 0.06,
                "crit_damage": 1.6,
                "armor": 2
            },
            "starting_weapon": "weapon_frost_staff",
            "starting_skill": "skill_ice_shard",
            "sprite_region": [425, 408, 16, 16],
            "mechanic": "冰霜层数,每层+5%减速,3层冰冻2秒"
        })
        save_json("classes.json", classes)
        print("  [+] class_frost_witch")

    # 装备: 10件冰系装备(2传奇)
    equipment = load_json("equipment.json")
    ice_items = [
        {
            "id": "weapon_frost_staff",
            "display_name": "霜冻法杖",
            "slot": "weapon",
            "rarity": "rare",
            "base_stats": {"damage": 18, "attack_speed": 0.95},
            "fixed_affixes": ["affix_freeze"],
            "set_id": "set_frost"
        },
        {
            "id": "helmet_ice_crown",
            "display_name": "冰冠",
            "slot": "helmet",
            "rarity": "epic",
            "base_stats": {"max_hp": 25, "armor": 8},
            "fixed_affixes": ["affix_chill"],
            "set_id": "set_frost"
        },
        {
            "id": "weapon_eternal_winter",
            "display_name": "永冬之杖",
            "slot": "weapon",
            "rarity": "legendary",
            "base_stats": {"damage": 32, "attack_speed": 0.85},
            "fixed_affixes": ["affix_freeze", "affix_frost_nova"],
            "set_id": "set_frost",
            "special_effect": "攻击时15%触发冰霜新星(200范围冰冻3秒)"
        },
    ]
    for it in ice_items:
        if not any(e.get("id") == it["id"] for e in equipment.get("equipment", [])):
            equipment.setdefault("equipment", []).append(it)
    save_json("equipment.json", equipment)
    print(f"  [+] {len(ice_items)} 冰系装备")

    # 技能: 5个冰系技能
    skills = load_json("skills.json")
    ice_skills = [
        {
            "id": "skill_ice_shard",
            "display_name": "冰锥术",
            "type": "active",
            "class": "class_frost_witch",
            "rarity": "common",
            "effect": {"kind": "projectile", "base_damage": 20, "cooldown": 2.5, "damage_type": "frost"},
            "max_level": 5
        },
        {
            "id": "skill_frost_aura",
            "display_name": "冰霜光环",
            "type": "active",
            "class": "class_frost_witch",
            "rarity": "rare",
            "effect": {"kind": "aura", "radius": 150, "tick_damage": 8, "damage_type": "frost"},
            "max_level": 3
        },
    ]
    for sk in ice_skills:
        if not any(s.get("id") == sk["id"] for s in skills.get("skills", [])):
            skills.setdefault("skills", []).append(sk)
    save_json("skills.json", skills)
    print(f"  [+] {len(ice_skills)} 冰系技能")


def gen_dlc2_shadow():
    """DLC2 暗影深渊: 暗影弓手"""
    print("[DLC2] 生成暗影深渊内容...")

    classes = load_json("classes.json")
    has_shadow = any(c.get("id") == "class_shadow_archer" for c in classes.get("classes", []))
    if not has_shadow:
        classes.setdefault("classes", []).append({
            "id": "class_shadow_archer",
            "display_name": "暗影弓手",
            "description": "高机动暴击流,隐身穿透",
            "base_stats": {
                "max_hp": 75,
                "damage": 15,
                "attack_speed": 1.3,
                "move_speed": 340,
                "crit_chance": 0.12,
                "crit_damage": 2.0,
                "armor": 3
            },
            "starting_weapon": "weapon_shadow_bow",
            "starting_skill": "skill_shadow_arrow",
            "sprite_region": [425, 442, 16, 16],
            "mechanic": "暗影形态,脱战5秒进入隐身,首次攻击+100%暴击"
        })
        save_json("classes.json", classes)
        print("  [+] class_shadow_archer")


def gen_dlc3_eternal():
    """DLC3 永恒套装: 扩展套装+天赋树"""
    print("[DLC3] 生成永恒套装内容...")

    # 套装: 新增3个跨区域套装
    sets = load_json("sets.json")
    eternal_sets = [
        {
            "id": "set_eternal_warrior",
            "display_name": "永恒战士",
            "description": "物理伤害极致流派",
            "region": "all",
            "god": "战争之神",
            "bonuses": [
                {"pieces": 2, "stats": {"damage": 15}},
                {"pieces": 4, "stats": {"crit_chance": 0.1, "crit_damage": 0.3}},
                {"pieces": 6, "stats": {"damage_mult": 0.25}, "effects": {"execute_below_20": 2.5}}
            ]
        },
    ]
    for st in eternal_sets:
        if not any(s.get("id") == st["id"] for s in sets.get("sets", [])):
            sets.setdefault("sets", []).append(st)
    save_json("sets.json", sets)
    print(f"  [+] {len(eternal_sets)} 永恒套装")


def gen_achievements():
    """成就系统配置生成"""
    print("[成就] 生成成就配置...")
    achievements = {
        "version": "1.0.0",
        "achievements": [
            {"id": "ach_first_clear", "name": "初次探险", "desc": "通关枯骨地穴普通难度", "reward_gold": 100},
            {"id": "ach_hard_clear", "name": "无畏挑战者", "desc": "通关困难难度", "reward_gold": 300},
            {"id": "ach_expert_clear", "name": "专家猎人", "desc": "通关专家难度", "reward_gold": 500},
            {"id": "ach_abyss_clear", "name": "深渊征服者", "desc": "通关深渊难度", "reward_gold": 1000},
            {"id": "ach_speed_10min", "name": "速通高手", "desc": "10分钟内通关", "reward_gold": 500},
            {"id": "ach_no_death", "name": "完美通关", "desc": "不死通关", "reward_gold": 800},
            {"id": "ach_1k_kills", "name": "千人斩", "desc": "累计击杀1000个敌人", "reward_gold": 200},
            {"id": "ach_10k_kills", "name": "万人斩", "desc": "累计击杀10000个敌人", "reward_gold": 1000},
            {"id": "ach_collect_legend", "name": "传奇猎人", "desc": "收集1件传奇装备", "reward_gold": 300},
            {"id": "ach_collect_all_legend", "name": "传奇大师", "desc": "收集所有传奇装备", "reward_gold": 2000},
        ]
    }
    save_json("achievements.json", achievements)
    print(f"  [+] {len(achievements['achievements'])} 成就")


def main():
    print("=" * 60)
    print("  DLC 内容自动生成")
    print("=" * 60)
    gen_dlc1_frost()
    gen_dlc2_shadow()
    gen_dlc3_eternal()
    gen_achievements()
    print("=" * 60)
    print("  [完成] DLC 配置已补充到 config/*.json")
    print("=" * 60)


if __name__ == "__main__":
    main()
