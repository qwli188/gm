#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
DarkLoot v3 战斗模拟器
用法：python balance_simulator.py --class assassin --equipment weapon_shadow_dagger --enemy enemy_skeleton --duration 60

功能：
1. 无 UI 战斗模拟（纯计算）
2. 计算 DPS / 生存时间 / 击杀数
3. 对比基准值，判断新装备是否破坏平衡
4. 输出详细报告（每秒 tick 数据）

目标：改装备后 10 秒内知道 DPS 变化
"""

import json
import argparse
import sys
from pathlib import Path
from typing import Dict, List, Tuple

# 伤害公式常量（对齐 CombatSystem.gd）
CRIT_MULTIPLIER_BASE = 1.5
ARMOR_CONSTANT = 100.0

class MockPlayer:
    def __init__(self, class_id: str, equipment_ids: List[str], config_root: str):
        self.class_id = class_id
        self.equipment_ids = equipment_ids
        self.config_root = Path(config_root)

        # 加载配置
        self.class_data = self._load_class(class_id)
        self.equipment = [self._load_equipment(eid) for eid in equipment_ids]

        # 计算最终属性
        self.stats = self._calculate_stats()

        # 状态
        self.hp = self.stats["max_hp"]
        self.attack_cooldown = 0.0

    def _load_class(self, class_id: str) -> Dict:
        path = self.config_root / "classes.json"
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        for cls in data.get("classes", []):
            if cls["id"] == class_id:
                return cls
        return {}

    def _load_equipment(self, eq_id: str) -> Dict:
        path = self.config_root / "equipment.json"
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        for item in data.get("items", []):
            if item["id"] == eq_id:
                return item
        return {}

    def _calculate_stats(self) -> Dict:
        # 基础属性（对齐 Player.gd）
        base = {
            "damage": 10.0,
            "max_hp": 100.0,
            "armor": 0.0,
            "crit_chance": 0.05,
            "crit_damage": CRIT_MULTIPLIER_BASE,
            "attack_speed": 1.0,
            "move_speed": 150.0,
            "hp_regen": 0.0,
            "lifesteal": 0.0
        }

        # 装备加成
        for item in self.equipment:
            if not item:
                continue
            stats = item.get("base_stats", {})
            base["damage"] += stats.get("damage", 0)
            base["max_hp"] += stats.get("max_hp", 0)
            base["armor"] += stats.get("armor", 0)
            base["crit_chance"] += stats.get("crit_chance", 0)
            base["crit_damage"] += stats.get("crit_damage", 0)

            # 攻速/移速是乘法
            if "attack_speed" in stats:
                base["attack_speed"] *= stats["attack_speed"]
            if "move_speed" in stats:
                base["move_speed"] *= (1.0 + stats["move_speed"])

        # 上限保护（对齐 Player.gd）
        base["crit_chance"] = min(base["crit_chance"], 0.75)
        base["attack_speed"] = min(base["attack_speed"], 3.0)

        return base

    def tick(self, dt: float, enemy: 'MockEnemy') -> Dict:
        """单帧 tick（dt 通常是 1/60 秒）"""
        result = {"damage_dealt": 0.0, "damage_taken": 0.0, "hp_regen": 0.0}

        # 回血
        regen = self.stats["hp_regen"] * dt
        self.hp = min(self.hp + regen, self.stats["max_hp"])
        result["hp_regen"] = regen

        # 攻击冷却
        self.attack_cooldown -= dt
        if self.attack_cooldown <= 0:
            dmg = self._attack(enemy)
            result["damage_dealt"] = dmg
            self.attack_cooldown = 1.0 / self.stats["attack_speed"]

        return result

    def _attack(self, enemy: 'MockEnemy') -> float:
        """攻击敌人，返回实际伤害"""
        import random

        # 计算伤害（对齐 CombatSystem.calculate_damage）
        base_damage = self.stats["damage"]
        is_crit = random.random() < self.stats["crit_chance"]
        crit_mult = self.stats["crit_damage"] if is_crit else 1.0

        # 抗性（简化，只考虑护甲）
        enemy_armor = enemy.stats["armor"]
        resistance = 1.0 - (enemy_armor / (enemy_armor + ARMOR_CONSTANT))

        final_damage = base_damage * crit_mult * resistance

        # 吸血
        if self.stats["lifesteal"] > 0:
            heal = final_damage * self.stats["lifesteal"]
            self.hp = min(self.hp + heal, self.stats["max_hp"])

        # 应用伤害到敌人
        enemy.hp -= final_damage

        return final_damage

class MockEnemy:
    def __init__(self, enemy_id: str, config_root: str):
        self.enemy_id = enemy_id
        self.config_root = Path(config_root)

        # 加载配置
        self.enemy_data = self._load_enemy(enemy_id)
        self.stats = self.enemy_data.get("base_stats", {})

        # 状态
        self.hp = self.stats.get("max_hp", 20)
        self.attack_cooldown = 0.0

    def _load_enemy(self, enemy_id: str) -> Dict:
        path = self.config_root / "enemies.json"
        with open(path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        for enemy in data.get("enemies", []):
            if enemy["id"] == enemy_id:
                return enemy
        return {}

    def tick(self, dt: float, player: MockPlayer) -> Dict:
        """单帧 tick"""
        result = {"damage_dealt": 0.0}

        # 攻击冷却
        self.attack_cooldown -= dt
        if self.attack_cooldown <= 0:
            dmg = self._attack(player)
            result["damage_dealt"] = dmg
            attack_speed = self.stats.get("attack_speed", 1.0)
            self.attack_cooldown = 1.0 / attack_speed

        return result

    def _attack(self, player: MockPlayer) -> float:
        """攻击玩家，返回实际伤害"""
        enemy_damage = self.stats.get("damage", 5)
        player_armor = player.stats["armor"]
        resistance = 1.0 - (player_armor / (player_armor + ARMOR_CONSTANT))
        final_damage = enemy_damage * resistance

        player.hp -= final_damage
        return final_damage

    def is_dead(self) -> bool:
        return self.hp <= 0

    def respawn(self):
        """重生（模拟连续战斗）"""
        self.hp = self.stats.get("max_hp", 20)
        self.attack_cooldown = 0.0

def simulate_combat(class_id: str, equipment_ids: List[str], enemy_id: str, duration: float, config_root: str) -> Dict:
    """模拟战斗"""
    player = MockPlayer(class_id, equipment_ids, config_root)
    enemy = MockEnemy(enemy_id, config_root)

    dt = 1.0 / 60.0  # 60 FPS
    ticks = int(duration / dt)

    result = {
        "total_damage": 0.0,
        "total_taken": 0.0,
        "kill_count": 0,
        "survival_time": 0.0,
        "player_dps": 0.0,
        "player_died": False,
        "ticks": []
    }

    for i in range(ticks):
        current_time = i * dt

        # 玩家 tick
        p_result = player.tick(dt, enemy)
        result["total_damage"] += p_result["damage_dealt"]

        # 敌人 tick
        e_result = enemy.tick(dt, player)
        result["total_taken"] += e_result["damage_dealt"]

        # 记录（每秒记录一次）
        if i % 60 == 0:
            result["ticks"].append({
                "time": round(current_time, 2),
                "player_hp": round(player.hp, 2),
                "enemy_hp": round(enemy.hp, 2),
                "kills": result["kill_count"]
            })

        # 敌人死亡
        if enemy.is_dead():
            result["kill_count"] += 1
            enemy.respawn()

        # 玩家死亡
        if player.hp <= 0:
            result["player_died"] = True
            result["survival_time"] = current_time
            break

    # 计算 DPS
    if result["survival_time"] == 0:
        result["survival_time"] = duration
    result["player_dps"] = result["total_damage"] / result["survival_time"]

    return result

def compare_with_baseline(result: Dict, baseline: Dict) -> Dict:
    """对比基准值"""
    comparison = {}

    # DPS 对比
    dps_ratio = result["player_dps"] / baseline["player_dps"] if baseline["player_dps"] > 0 else 1.0
    comparison["dps_change"] = round((dps_ratio - 1.0) * 100, 2)  # 百分比变化

    # 生存时间对比
    survival_ratio = result["survival_time"] / baseline["survival_time"] if baseline["survival_time"] > 0 else 1.0
    comparison["survival_change"] = round((survival_ratio - 1.0) * 100, 2)

    # 击杀数对比
    kill_ratio = result["kill_count"] / baseline["kill_count"] if baseline["kill_count"] > 0 else 1.0
    comparison["kill_change"] = round((kill_ratio - 1.0) * 100, 2)

    # 平衡判断
    warnings = []
    if abs(comparison["dps_change"]) > 50:
        warnings.append(f"⚠️  DPS 变化 {comparison['dps_change']:+.1f}%，可能破坏平衡")
    if comparison["survival_change"] < -30:
        warnings.append(f"⚠️  生存时间下降 {comparison['survival_change']:.1f}%，过于脆弱")
    if comparison["kill_change"] > 100:
        warnings.append(f"⚠️  击杀数翻倍 ({comparison['kill_change']:+.1f}%)，明显过强")

    comparison["warnings"] = warnings
    comparison["is_balanced"] = len(warnings) == 0

    return comparison

def main():
    parser = argparse.ArgumentParser(description='DarkLoot v3 战斗模拟器')
    parser.add_argument('--class', dest='class_id', required=True, help='职业 ID（如 class_warrior）')
    parser.add_argument('--equipment', nargs='+', required=True, help='装备 ID 列表')
    parser.add_argument('--enemy', required=True, help='敌人 ID（如 enemy_skeleton）')
    parser.add_argument('--duration', type=float, default=60.0, help='战斗时长（秒）')
    parser.add_argument('--baseline', help='基准装备 ID（用于对比）')
    parser.add_argument('--verbose', action='store_true', help='输出详细 tick 数据')

    args = parser.parse_args()

    # 配置文件路径
    project_root = Path(__file__).parent.parent
    config_root = project_root / "project/src/config"

    print(f"\n🎮 战斗模拟器 - DarkLoot v3")
    print(f"   职业: {args.class_id}")
    print(f"   装备: {', '.join(args.equipment)}")
    print(f"   敌人: {args.enemy}")
    print(f"   时长: {args.duration}s\n")

    # 运行模拟
    result = simulate_combat(args.class_id, args.equipment, args.enemy, args.duration, str(config_root))

    print(f"📊 模拟结果：")
    print(f"   DPS: {result['player_dps']:.2f}")
    print(f"   生存时间: {result['survival_time']:.2f}s")
    print(f"   击杀数: {result['kill_count']}")
    print(f"   总伤害: {result['total_damage']:.2f}")
    print(f"   受到伤害: {result['total_taken']:.2f}")

    # 基准对比
    if args.baseline:
        print(f"\n🔍 基准对比（vs {args.baseline}）：")
        baseline = simulate_combat(args.class_id, [args.baseline], args.enemy, args.duration, str(config_root))
        comparison = compare_with_baseline(result, baseline)

        print(f"   DPS 变化: {comparison['dps_change']:+.2f}%")
        print(f"   生存时间变化: {comparison['survival_change']:+.2f}%")
        print(f"   击杀数变化: {comparison['kill_change']:+.2f}%")

        if comparison["warnings"]:
            print(f"\n❌ 平衡警告：")
            for warning in comparison["warnings"]:
                print(f"   {warning}")
        else:
            print(f"\n✅ 平衡检查通过")

    # 详细数据
    if args.verbose:
        print(f"\n📈 逐秒数据：")
        for tick in result["ticks"]:
            print(f"   {tick['time']}s - 玩家 HP: {tick['player_hp']}, 敌人 HP: {tick['enemy_hp']}, 击杀: {tick['kills']}")

    print()

if __name__ == "__main__":
    main()
