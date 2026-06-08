extends Node
## 战斗系统 - 伤害计算、词缀触发、碰撞检测

signal damage_dealt(target: Node2D, damage: float, is_crit: bool)
signal enemy_died(enemy: Node2D)

# 从配置文件读取
var crit_multiplier_base: float = 1.5
var armor_constant: float = 100.0

func _ready():
	var config = ConfigLoader.balance_data
	if not config.is_empty():
		var dmg_formula = config.get("damage_formula", {})
		crit_multiplier_base = dmg_formula.get("crit_multiplier_base", 1.5)
	print("[CombatSystem] 战斗系统初始化")

## 计算最终伤害
## 公式: (基础伤害 + 附加伤害) × 增益 × 暴击 × 抗性
func calculate_damage(attacker_stats: Dictionary, target_armor: float) -> Dictionary:
	var base_damage = attacker_stats.get("damage", 10)
	var added_damage = attacker_stats.get("added_damage", 0)
	var damage_mult = attacker_stats.get("damage_mult", 1.0)
	var crit_chance = attacker_stats.get("crit_chance", 0.05)
	var crit_damage = attacker_stats.get("crit_damage", crit_multiplier_base)

	var is_crit = randf() < crit_chance
	var crit_mult = crit_damage if is_crit else 1.0

	var resistance = 1.0 - (target_armor / (target_armor + armor_constant))

	var final_damage = (base_damage + added_damage) * damage_mult * crit_mult * resistance

	return {
		"damage": final_damage,
		"is_crit": is_crit
	}

## 应用伤害到目标
func apply_damage(target: Node2D, damage: float, attacker_stats: Dictionary, is_crit: bool = false):
	if not target.has_method("take_damage"):
		return

	target.take_damage(damage, is_crit)

	# 触发吸血
	var lifesteal = attacker_stats.get("lifesteal", 0.0)
	if lifesteal > 0:
		trigger_lifesteal(damage, lifesteal)

	# 触发点燃
	var ignite_dps = attacker_stats.get("ignite_dps", 0)
	var ignite_duration = attacker_stats.get("ignite_duration", 0)
	if ignite_dps > 0 and ignite_duration > 0:
		trigger_ignite(target, ignite_dps, ignite_duration)

	# 触发中毒
	var poison_dps = attacker_stats.get("poison_dps", 0)
	var poison_duration = attacker_stats.get("poison_duration", 0)
	if poison_dps > 0 and poison_duration > 0:
		trigger_poison(target, poison_dps, poison_duration)

	# 触发冰冻
	var freeze_chance = attacker_stats.get("freeze_chance", 0.0)
	var freeze_duration = attacker_stats.get("freeze_duration", 0.0)
	if freeze_chance > 0 and randf() < freeze_chance:
		trigger_freeze(target, freeze_duration)

	# 触发减速
	var slow_percent = attacker_stats.get("slow_percent", 0.0)
	var slow_duration = attacker_stats.get("slow_duration", 0.0)
	if slow_percent > 0:
		trigger_slow(target, slow_percent, slow_duration)

## 吸血效果
func trigger_lifesteal(damage: float, lifesteal_percent: float):
	var heal = damage * lifesteal_percent
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("heal"):
		player.heal(heal)

## 点燃效果
func trigger_ignite(target: Node2D, dps: float, duration: float):
	if not target.has_method("apply_ignite"):
		return
	target.apply_ignite(dps, duration)

## 中毒效果
func trigger_poison(target: Node2D, dps: float, duration: float):
	if not target.has_method("apply_poison"):
		return
	target.apply_poison(dps, duration)

## 冰冻效果
func trigger_freeze(target: Node2D, duration: float):
	if not target.has_method("apply_freeze"):
		return
	target.apply_freeze(duration)

## 减速效果
func trigger_slow(target: Node2D, slow_percent: float, duration: float):
	if not target.has_method("apply_slow"):
		return
	target.apply_slow(slow_percent, duration)

## 玩家攻击检测（Area2D）
func check_player_attack(attack_area: Area2D, player_stats: Dictionary):
	var enemies = attack_area.get_overlapping_bodies()
	for enemy in enemies:
		if enemy.is_in_group("enemy"):
			var armor = enemy.enemy_data.get("base_stats", {}).get("armor", 0)
			var result = calculate_damage(player_stats, armor)
			apply_damage(enemy, result.damage, player_stats, result.is_crit)
			damage_dealt.emit(enemy, result.damage, result.is_crit)

## 敌人攻击玩家
func enemy_attack_player(enemy_damage: float, player: Node2D):
	if not player.has_method("take_damage"):
		return

	var player_armor = 0.0
	if player.has_method("get_stat"):
		player_armor = player.get_stat("armor")

	var resistance = 1.0 - (player_armor / (player_armor + armor_constant))
	var final_damage = enemy_damage * resistance

	player.take_damage(final_damage)
