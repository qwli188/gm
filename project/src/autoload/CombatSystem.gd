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

	return {"damage": final_damage, "is_crit": is_crit}


## 应用伤害到目标
func apply_damage(target: Node2D, damage: float, attacker_stats: Dictionary, is_crit: bool = false):
	if not target.has_method("take_damage"):
		return

	target.take_damage(damage, is_crit)

	# 触发吸血
	var lifesteal = attacker_stats.get("lifesteal", 0.0)
	if lifesteal > 0:
		trigger_lifesteal(damage, lifesteal)

	# 触发点燃 (支持 ignite_chance 概率门控,默认100%以兼容旧词缀)
	var ignite_dps = attacker_stats.get("ignite_dps", 0)
	var ignite_duration = attacker_stats.get("ignite_duration", 0)
	if ignite_dps > 0 and ignite_duration > 0:
		var ignite_chance = attacker_stats.get("ignite_chance", 1.0)
		if ignite_chance >= 1.0 or randf() < ignite_chance:
			trigger_ignite(target, ignite_dps, ignite_duration)

	# 触发中毒 (支持 poison_chance 概率门控)
	var poison_dps = attacker_stats.get("poison_dps", 0)
	var poison_duration = attacker_stats.get("poison_duration", 0)
	if poison_dps > 0 and poison_duration > 0:
		var poison_chance = attacker_stats.get("poison_chance", 1.0)
		if poison_chance >= 1.0 or randf() < poison_chance:
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

	# 触发召唤词缀(命中时按概率召唤伴生)
	var summon_chance = attacker_stats.get("summon_chance", 0.0)
	if summon_chance > 0 and randf() < summon_chance:
		trigger_affix_summon(target.global_position, attacker_stats)

	# 触发连锁词缀(命中时弹射给附近敌人)
	var chain_chance = attacker_stats.get("chain_chance", 0.0)
	if chain_chance > 0 and randf() < chain_chance:
		trigger_affix_chain(target, damage, attacker_stats)


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
	# B1 shader接线: 点燃视觉反馈
	var sprite = target.get_node_or_null("AnimatedSprite2D")
	if sprite:
		ShaderHelper.apply_status_overlay(sprite, "ignite", 0.5)


## 中毒效果
func trigger_poison(target: Node2D, dps: float, duration: float):
	if not target.has_method("apply_poison"):
		return
	target.apply_poison(dps, duration)
	# B1 shader接线: 中毒视觉反馈
	var sprite = target.get_node_or_null("AnimatedSprite2D")
	if sprite:
		ShaderHelper.apply_status_overlay(sprite, "poison", 0.5)


## 冰冻效果
func trigger_freeze(target: Node2D, duration: float):
	if not target.has_method("apply_freeze"):
		return
	target.apply_freeze(duration)
	# B1 shader接线: 冰冻视觉反馈
	var sprite = target.get_node_or_null("AnimatedSprite2D")
	if sprite:
		ShaderHelper.apply_status_overlay(sprite, "freeze", 0.6)


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


## 召唤词缀效果(命中时召唤友方伴生)
## 这是装备词缀的本地实现,不走 ActiveSkillSystem.summons 池
func trigger_affix_summon(pos: Vector2, attacker_stats: Dictionary):
	var scene = get_tree().current_scene
	if scene == null:
		return
	var damage = attacker_stats.get("summon_damage", 6.0)
	var duration = attacker_stats.get("summon_duration", 8.0)
	var minion = CharacterBody2D.new()
	minion.add_to_group("minion")
	minion.global_position = pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
	var visual = ColorRect.new()
	visual.size = Vector2(16, 16)
	visual.position = Vector2(-8, -8)
	visual.color = Color(0.65, 0.85, 0.55, 0.9)
	minion.add_child(visual)
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 8
	col.shape = shape
	minion.add_child(col)
	minion.set_meta("damage", damage)
	minion.set_meta("life", duration)
	minion.set_meta("attack_cd", 0.0)
	minion.set_script(_minion_script())
	scene.add_child(minion)
	# 召唤特效
	if has_node("/root/EffectSprite") or ResourceLoader.exists("res://scripts/EffectSprite.gd"):
		EffectSprite.spawn(scene, "poison", pos, 1.1)


## 连锁词缀效果(命中目标时弹射给附近敌人)
func trigger_affix_chain(origin: Node2D, damage: float, attacker_stats: Dictionary):
	var targets_count = int(attacker_stats.get("chain_targets", 2))
	var damage_mult = attacker_stats.get("chain_damage_mult", 0.5)
	if targets_count <= 0 or not is_instance_valid(origin):
		return
	var chained = [origin]
	var current = origin
	for i in range(targets_count):
		var next = _find_nearest_unchained(current, chained, 200.0)
		if next == null:
			break
		# 视觉:画一条短暂闪电
		_draw_chain_bolt(current.global_position, next.global_position)
		if next.has_method("take_damage"):
			next.take_damage(damage * damage_mult, false)
		chained.append(next)
		current = next


func _find_nearest_unchained(origin: Node2D, exclude: Array, max_range: float) -> Node2D:
	var nearest = null
	var min_d = max_range
	for e in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(e) or e in exclude:
			continue
		var d = origin.global_position.distance_to(e.global_position)
		if d < min_d:
			min_d = d
			nearest = e
	return nearest


func _draw_chain_bolt(from: Vector2, to: Vector2):
	var scene = get_tree().current_scene
	if scene == null:
		return
	var line = Line2D.new()
	line.add_point(from)
	line.add_point(to)
	line.width = 3.0
	line.default_color = Color(0.6, 0.9, 1.0, 0.9)
	line.z_index = 50
	scene.add_child(line)
	var tw = line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.18)
	tw.tween_callback(line.queue_free)


func _minion_script() -> GDScript:
	var src = """
extends CharacterBody2D
func _physics_process(delta):
	var life = get_meta(\"life\") - delta
	set_meta(\"life\", life)
	if life <= 0:
		queue_free()
		return
	var cd = get_meta(\"attack_cd\") - delta
	set_meta(\"attack_cd\", cd)
	var target = _nearest_enemy()
	if target == null:
		return
	var dist = global_position.distance_to(target.global_position)
	if dist > 35:
		var dir = (target.global_position - global_position).normalized()
		velocity = dir * 160
		move_and_slide()
	elif cd <= 0:
		if target.has_method(\"take_damage\"):
			target.take_damage(get_meta(\"damage\"))
		set_meta(\"attack_cd\", 0.9)
func _nearest_enemy():
	var nearest = null
	var min_d = 99999.0
	for e in get_tree().get_nodes_in_group(\"enemy\"):
		if not is_instance_valid(e):
			continue
		var d = global_position.distance_to(e.global_position)
		if d < min_d:
			min_d = d
			nearest = e
	return nearest
"""
	var gd = GDScript.new()
	gd.source_code = src
	gd.reload()
	return gd


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
				# 暴击爆闪光（mobile 渲染器下生效）
				if is_instance_valid(enemy) and enemy.get_parent():
					ParticleHelper.spawn_flash_light(
						enemy.get_parent(),
						enemy.global_position,
						Color(1.0, 0.85, 0.3),
						240.0,
						0.25,
						2.0
					)
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
				ParticleHelper.spawn_hit_particles(
					enemy.get_parent(), hit_pos, Color(1.0, 0.9, 0.7)
				)


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
	# P8: 优先走 FeedbackSystem（它做了嵌套去重）
	if has_node("/root/FeedbackSystem"):
		get_node("/root/FeedbackSystem").hitstop(duration)
		return
	# 兜底：旧实现
	Engine.time_scale = 0.0
	get_tree().create_timer(duration, true, false, true).timeout.connect(
		func(): Engine.time_scale = 1.0
	)


## 打击感 - 震屏效果（暴击时）
func _apply_screen_shake(intensity: float):
	# P8: 优先走 FeedbackSystem（它做了渐衰减）
	if has_node("/root/FeedbackSystem"):
		get_node("/root/FeedbackSystem").shake(intensity, 0.15)
		return
	# 兜底：旧实现
	var camera = get_viewport().get_camera_2d()
	if not camera:
		return
	camera.offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
	get_tree().create_timer(0.1).timeout.connect(
		func():
			if camera:
				camera.offset = Vector2.ZERO
	)
