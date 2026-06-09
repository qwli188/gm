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
	ConfigLoader.config_reloaded.connect(_on_config_reloaded)

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

	# 触发减速（支持 slow_chance 概率触发）
	var slow_chance = attacker_stats.get("slow_chance", 0.0)
	var slow_percent = attacker_stats.get("slow_percent", 0.0)
	var slow_duration = attacker_stats.get("slow_duration", 0.0)
	if slow_percent > 0:
		# 如果有 slow_chance，按概率触发；否则 100% 触发
		if slow_chance > 0:
			if randf() < slow_chance:
				trigger_slow(target, slow_percent, slow_duration)
		else:
			trigger_slow(target, slow_percent, slow_duration)

	# 触发眩晕
	var stun_chance = attacker_stats.get("stun_chance", 0.0)
	var stun_duration = attacker_stats.get("stun_duration", 0.0)
	if stun_chance > 0 and randf() < stun_chance:
		trigger_stun(target, stun_duration)

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

## 眩晕效果
func trigger_stun(target: Node2D, duration: float):
	if not target.has_method("apply_stun"):
		return
	target.apply_stun(duration)

## 玩家攻击检测（Area2D）- 三方合并: A1职业机制 + A2刺客背刺 + B2粒子
func check_player_attack(attack_area: Area2D, player_stats: Dictionary):
	var enemies = attack_area.get_overlapping_bodies()

	# 战士: 怒气伤害加成(循环外预计算)
	var warrior_dmg_mult = 1.0
	var cms = null
	if has_node("/root/ClassMechanicSystem"):
		cms = get_node("/root/ClassMechanicSystem")
		warrior_dmg_mult = cms.get_warrior_damage_mult()

	for enemy in enemies:
		if enemy.is_in_group("enemy"):
			# (1) 刺客潜行背刺检测(calculate_damage前)
			var is_backstab = false
			var backstab_mult = 1.0
			if cms and cms.has_method("assassin_is_backstab"):
				is_backstab = cms.assassin_is_backstab()
				if is_backstab:
					backstab_mult = cms.assassin_get_backstab_damage_mult()
					cms.assassin_on_attack()  # 触发退出潜行

			# (2) 战士伤害加成 → modified_stats
			var modified_stats = player_stats.duplicate()
			modified_stats["damage"] = player_stats.get("damage", 10) * warrior_dmg_mult

			# (3) 计算伤害
			var armor = enemy.enemy_data.get("base_stats", {}).get("armor", 0)
			var result = calculate_damage(modified_stats, armor)

			# (4) 背刺override: 强制暴击+额外伤害
			if is_backstab:
				result.is_crit = true
				result.damage *= backstab_mult

			# (5) 应用伤害
			apply_damage(enemy, result.damage, player_stats, result.is_crit)
			damage_dealt.emit(enemy, result.damage, result.is_crit)

			# (6) A1职业命中机制: 战士怒气/游侠精准/法师连锁
			if cms:
				cms.on_player_hit_enemy()  # 战士命中加怒气
				cms.on_ranger_hit_target(enemy)  # 游侠精准层数
				cms.trigger_chain_lightning(enemy, result.damage, player_stats)  # 法师连锁

			# (7) 打击感: 顿帧 + 震屏
			if result.is_crit:
				_apply_hitstop(0.08)
				_apply_screen_shake(8.0)
			else:
				_apply_hitstop(0.04)
			# 击退
			if enemy.has_method("apply_knockback"):
				var player = get_tree().get_first_node_in_group("player")
				if player:
					enemy.apply_knockback(player.global_position, result.is_crit)

			# (8) B2粒子特效
			var hit_pos = enemy.global_position + Vector2(0, -15)
			if result.is_crit:
				ParticleHelper.spawn_crit_particles(enemy.get_parent(), hit_pos)
			else:
				ParticleHelper.spawn_hit_particles(enemy.get_parent(), hit_pos, Color(1.0, 0.9, 0.7))

## 敌人攻击玩家
func enemy_attack_player(enemy_damage: float, player: Node2D):
	if not player.has_method("take_damage"):
		return

	# 闪避无敌帧：攻击判定 miss，不结算伤害(先于一切结算,避免吸血/点燃误触发)
	if "is_dodging" in player and player.is_dodging:
		if "dodge_timer" in player and "dodge_i_frame_duration" in player:
			if player.dodge_timer < player.dodge_i_frame_duration:
				return

	var player_armor = 0.0
	if player.has_method("get_stat"):
		player_armor = player.get_stat("armor")

	var resistance = 1.0 - (player_armor / (player_armor + armor_constant))
	var final_damage = enemy_damage * resistance

	player.take_damage(final_damage)

func _on_config_reloaded(file_name: String) -> void:
	if file_name == "balance.json":
		var dmg_formula = ConfigLoader.balance_data.get("damage_formula", {})
		crit_multiplier_base = dmg_formula.get("crit_multiplier_base", 1.5)
		print("[CombatSystem] 响应 balance.json 重载: crit_mult=" + str(crit_multiplier_base))

## 打击感 - 顿帧效果
func _apply_hitstop(duration: float):
	Engine.time_scale = 0.0
	# 创建不受 time_scale 影响的定时器(第4参数 ignore_time_scale=true)
	get_tree().create_timer(duration, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
	)

## 打击感 - 震屏效果（暴击时）
func _apply_screen_shake(intensity: float):
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	# 第一段震动
	camera.offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	# 0.05 秒后衰减
	get_tree().create_timer(0.05).timeout.connect(func():
		if camera:
			camera.offset = Vector2(randf_range(-intensity * 0.5, intensity * 0.5), randf_range(-intensity * 0.5, intensity * 0.5))
	)
	# 0.1 秒后恢复
	get_tree().create_timer(0.1).timeout.connect(func():
		if camera:
			camera.offset = Vector2.ZERO
	)
