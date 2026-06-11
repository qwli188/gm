extends CharacterBody2D

# ============ 基础属性（角色裸装） ============
var base_max_hp: float = 100.0
var base_damage: float = 10.0
var base_attack_speed: float = 1.0
var base_move_speed: float = 300.0
var base_crit_chance: float = 0.05
var base_crit_damage: float = 1.5
var base_armor: float = 0.0

# ============ 最终属性（基础 + 装备 + 词缀，每次装备变化时重算） ============
var max_hp: float = 100.0
var current_hp: float = 100.0
var damage: float = 10.0
var attack_speed: float = 1.0
var move_speed: float = 300.0
var crit_chance: float = 0.05
var crit_damage: float = 1.5
var armor: float = 0.0
# 词缀效果属性（吸血、点燃等，传给战斗系统）
var combat_stats: Dictionary = {}

var auto_attack_enabled: bool = false
var attack_cooldown: float = 0.0

# 经验与等级
var current_level: int = 1
var current_exp: float = 0.0
var exp_to_next_level: float = 10.0

# 属性加点系统
var attributes: Dictionary = {
	"strength": 0,
	"agility": 0,
	"vitality": 0,
	"intelligence": 0
}
var attribute_points_unspent: int = 0

# 游戏统计
var survival_time: float = 0.0
var kills: int = 0
var gold: int = 0

signal stats_recalculated()

signal hp_changed(current: float, maximum: float)
signal auto_attack_toggled(enabled: bool)
signal level_up(new_level: int)
signal player_died(time: float, kill_count: int, gold_earned: int)
signal attribute_points_changed(unspent: int)
signal attributes_changed(attrs: Dictionary)

var anim_sprite: AnimatedSprite2D
var _attacking: bool = false
var _facing_left: bool = false

# ============ 闪避系统 ============
var is_dodging: bool = false
var dodge_cooldown: float = 0.0
var dodge_timer: float = 0.0
var dodge_i_frame_duration: float = 0.3  # 无敌帧时长
var dodge_duration: float = 0.3  # 闪避总时长
var dodge_distance: float = 220.0  # 闪避距离(220 保证一次能脱出 Boss AOE)
var dodge_speed: float = 600.0  # 闪避速度
var dodge_cooldown_time: float = 1.5  # 闪避冷却
var dodge_direction: Vector2 = Vector2.ZERO  # 闪避方向
var _dodge_requested: bool = false  # 输入缓冲(由 _unhandled_input 设置,_physics_process 消费)

func _ready():
	add_to_group("player")
	_setup_visual()
	_apply_class()
	recalculate_stats()
	current_hp = max_hp
	_calculate_exp_to_next_level()

## 创建职业动画精灵
func _setup_visual():
	anim_sprite = AnimatedSprite2D.new()
	anim_sprite.name = "Sprite"
	anim_sprite.scale = Vector2(2.6, 2.6)
	add_child(anim_sprite)

## 根据选中职业设置基础属性和起手武器
func _apply_class():
	if not has_node("/root/GameState"):
		return
	var cls = get_node("/root/GameState").get_current_class()
	if cls.is_empty():
		return
	var bs = cls.get("base_stats", {})
	base_max_hp = bs.get("max_hp", 100)
	base_damage = bs.get("damage", 10)
	base_attack_speed = bs.get("attack_speed", 1.0)
	base_move_speed = bs.get("move_speed", 300)
	base_crit_chance = bs.get("crit_chance", 0.05)
	base_crit_damage = bs.get("crit_damage", 1.5)
	base_armor = bs.get("armor", 0)
	print("[Player] 职业: %s" % cls.get("display_name", "?"))

	# 装备起手武器
	var starting_weapon = cls.get("starting_weapon", "")
	if starting_weapon != "" and has_node("/root/EquipmentSystem"):
		var weapon = ConfigLoader.get_equipment_by_id(starting_weapon)
		if not weapon.is_empty():
			get_node("/root/EquipmentSystem").equip_item(weapon)

	# 加载职业动画精灵
	var class_id = cls.get("id", "class_warrior")
	if anim_sprite:
		anim_sprite.sprite_frames = SpriteLibrary.get_class_frames(class_id)
		anim_sprite.animation = "idle"
		anim_sprite.play("idle")

## 重算最终属性 = 基础 + 局外强化 + 属性加点 + 装备 + 词缀
## 每次装备/卸下/局外升级/加点后调用
func recalculate_stats():
	# 1. 从基础属性起步
	max_hp = base_max_hp
	damage = base_damage
	attack_speed = base_attack_speed
	move_speed = base_move_speed
	crit_chance = base_crit_chance
	crit_damage = base_crit_damage
	armor = base_armor
	combat_stats = {}

	# 2. 叠加局外永久强化（GameState 管理）
	#    加到最终值 damage/max_hp，绝不回写 base_*（base_* 是裸装持久值，
	#    回写会导致每次 recalculate 累加膨胀 + 滞后一帧的状态污染）
	damage += GameState.get_meta_bonus("perm_damage")
	max_hp += GameState.get_meta_bonus("perm_max_hp")

	# 3. 叠加属性加点效果
	_apply_attribute_bonuses()

	# 4. 叠加装备属性（由 EquipmentSystem 汇总）
	if has_node("/root/EquipmentSystem"):
		var eq = get_node("/root/EquipmentSystem")
		var total = eq.get_total_stats()
		max_hp += total.get("max_hp", 0)
		damage += total.get("damage", 0)
		attack_speed *= total.get("attack_speed_mult", 1.0)
		move_speed *= total.get("move_speed_mult", 1.0)
		crit_chance += total.get("crit_chance", 0)
		crit_damage += total.get("crit_damage", 0)
		armor += total.get("armor", 0)
		# 词缀效果（吸血、点燃、毒、附加伤害等）传给战斗系统
		combat_stats = eq.get_combat_effects()

	# 上限保护
	crit_chance = min(crit_chance, 0.75)
	attack_speed = min(attack_speed, 3.0)

	# A3: 标签联动加成(集齐N个同tag触发)
	if has_node("/root/TagSynergySystem"):
		var tss = get_node("/root/TagSynergySystem")
		if tss.has_method("get_tag_synergy_bonuses"):
			var syn = tss.get_tag_synergy_bonuses()
			for k in syn:
				if k.ends_with("_mult"):
					var stat = k.trim_suffix("_mult")
					match stat:
						"damage": damage *= (1.0 + syn[k])
						"attack_speed": attack_speed *= (1.0 + syn[k])
						"move_speed": move_speed *= (1.0 + syn[k])
						_: combat_stats[k] = combat_stats.get(k, 0.0) + syn[k]
				else:
					match k:
						"crit_chance": crit_chance += syn[k]
						"crit_damage": crit_damage += syn[k]
						"max_hp": max_hp += syn[k]
						"armor": armor += syn[k]
						"damage": damage += syn[k]
						_: combat_stats[k] = combat_stats.get(k, 0.0) + syn[k]

	# A1: 游侠精准射击叠层(暴击加成)
	if has_node("/root/ClassMechanicSystem"):
		var cms = get_node("/root/ClassMechanicSystem")
		if cms.has_method("get_ranger_crit_bonus"):
			crit_chance += cms.get_ranger_crit_bonus()
			crit_damage += cms.get_ranger_crit_damage_bonus()

	# 副本机制buff(死亡之雾暴击加成)
	if has_node("/root/DungeonFeatureSystem"):
		var dfs = get_node("/root/DungeonFeatureSystem")
		var fog_crit = dfs.active_buffs.get("fog_crit_bonus", 0.0)
		if fog_crit > 0:
			crit_chance += fog_crit

	# P6: 巅峰加成（账号级共享，跨角色，最终乘到结算前）
	if has_node("/root/GameState"):
		damage *= (1.0 + GameState.get_paragon_bonus("damage_pct"))
		max_hp *= (1.0 + GameState.get_paragon_bonus("max_hp_pct"))
		armor += GameState.get_paragon_bonus("armor_flat")
		crit_chance += GameState.get_paragon_bonus("crit_chance")
		crit_damage += GameState.get_paragon_bonus("crit_damage")
		attack_speed *= (1.0 + GameState.get_paragon_bonus("attack_speed_pct"))
		move_speed *= (1.0 + GameState.get_paragon_bonus("move_speed_pct"))
		# 金币/掉率/技能冷却走 combat_stats，由对应系统读取
		var gold_find = GameState.get_paragon_bonus("gold_find")
		if gold_find > 0:
			combat_stats["gold_find"] = combat_stats.get("gold_find", 0.0) + gold_find
		var magic_find = GameState.get_paragon_bonus("magic_find")
		if magic_find > 0:
			combat_stats["magic_find"] = combat_stats.get("magic_find", 0.0) + magic_find
		var cdr = GameState.get_paragon_bonus("skill_cd_reduce")
		if cdr > 0:
			combat_stats["skill_cd_reduce"] = combat_stats.get("skill_cd_reduce", 0.0) + cdr

	# P6: 天赋星图加成（节点静态属性 → 平铺到属性）
	if has_node("/root/GameState") and ConfigLoader.has_method("get_unlocked_talent_effects"):
		var talent_effects = ConfigLoader.get_unlocked_talent_effects(GameState.unlocked_talents)
		for k in talent_effects:
			match k:
				"damage": damage += talent_effects[k]
				"damage_pct": damage *= (1.0 + talent_effects[k])
				"max_hp": max_hp += talent_effects[k]
				"max_hp_pct": max_hp *= (1.0 + talent_effects[k])
				"armor": armor += talent_effects[k]
				"crit_chance": crit_chance += talent_effects[k]
				"crit_damage": crit_damage += talent_effects[k]
				"attack_speed_pct": attack_speed *= (1.0 + talent_effects[k])
				"move_speed_pct": move_speed *= (1.0 + talent_effects[k])
				_: combat_stats[k] = combat_stats.get(k, 0.0) + talent_effects[k]

	# 最终暴击率再clamp(游侠精准+雾加成后)
	crit_chance = min(crit_chance, 0.95)

	stats_recalculated.emit()

func _physics_process(delta):
	survival_time += delta

	# 更新闪避冷却
	if dodge_cooldown > 0:
		dodge_cooldown -= delta

	# 处理闪避逻辑
	handle_dodge(delta)

	# 不在闪避中才正常处理移动(闪避期间 velocity 由 handle_dodge 接管)
	if not is_dodging:
		handle_movement()
		# 冰面惯性(副本机制ice_slide)
		if has_node("/root/DungeonFeatureSystem"):
			var dfs = get_node("/root/DungeonFeatureSystem")
			var ice_zones = dfs.active_buffs.get("ice_slide_zones", [])
			var on_ice = false
			for zone in ice_zones:
				if is_instance_valid(zone) and zone.has_method("overlaps_body"):
					if zone.overlaps_body(self):
						on_ice = true
						break
			if on_ice:
				velocity *= 0.85  # 惯性打滑

	handle_attack(delta)
	move_and_slide()

## 闪避输入用 _unhandled_input 检测,避免顿帧(time_scale=0)期间物理帧停摆吞输入
func _unhandled_input(event):
	if event.is_action_pressed("dodge"):
		_dodge_requested = true

func handle_dodge(delta):
	# 消费输入缓冲(冷却好了且不在闪避中)
	if _dodge_requested:
		_dodge_requested = false
		if dodge_cooldown <= 0 and not is_dodging:
			# 确定闪避方向
			var input_dir = Vector2(
				Input.get_axis("move_left", "move_right"),
				Input.get_axis("move_up", "move_down")
			).normalized()
			# 有移动输入则用移动方向,否则用朝向
			if input_dir.length() > 0.1:
				dodge_direction = input_dir
			else:
				dodge_direction = Vector2(-1 if _facing_left else 1, 0)
			# 触发闪避
			is_dodging = true
			dodge_timer = 0.0
			dodge_cooldown = dodge_cooldown_time
			dodge_duration = dodge_distance / dodge_speed
			# 视觉反馈:半透明
			if anim_sprite:
				anim_sprite.modulate.a = 0.5
			AudioManager.play("footstep")

	# 闪避进行中
	if is_dodging:
		dodge_timer += delta
		if dodge_timer < dodge_duration:
			velocity = dodge_direction * dodge_speed
		else:
			is_dodging = false
			if anim_sprite:
				anim_sprite.modulate.a = 1.0

func handle_movement():
	var input_dir = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()

	velocity = input_dir * move_speed

	# 动画：移动时 walk，静止时 idle（攻击动画优先）
	if anim_sprite and not _attacking:
		if input_dir.length() > 0.1:
			if anim_sprite.animation != "walk":
				anim_sprite.play("walk")
		else:
			if anim_sprite.animation != "idle":
				anim_sprite.play("idle")
	# 朝向翻转
	if anim_sprite and abs(input_dir.x) > 0.1:
		_facing_left = input_dir.x < 0
		anim_sprite.flip_h = _facing_left

func handle_attack(delta):
	if attack_cooldown > 0:
		attack_cooldown -= delta
		return

	if Input.is_action_just_pressed("toggle_auto_attack"):
		auto_attack_enabled = !auto_attack_enabled
		auto_attack_toggled.emit(auto_attack_enabled)

	# 职业调优: class_skill(R键)根据职业分发
	if Input.is_action_just_pressed("class_skill"):
		if has_node("/root/ClassMechanicSystem"):
			var cms = get_node("/root/ClassMechanicSystem")
			var class_id = get_node("/root/GameState").get_current_class().get("id", "")
			match class_id:
				"class_warrior":
					if cms.has_method("activate_rage_skill"):
						cms.activate_rage_skill()
				"class_knight":
					if cms.has_method("activate_knight_shield"):
						cms.activate_knight_shield()
				# 其他职业暂无R键技能

	# 阶段1: 手动技能快捷键 1/2/3
	if has_node("/root/ActiveSkillSystem"):
		var ask = get_node("/root/ActiveSkillSystem")
		if Input.is_action_just_pressed("skill_1"):
			ask.activate_manual_skill(0)
		elif Input.is_action_just_pressed("skill_2"):
			ask.activate_manual_skill(1)
		elif Input.is_action_just_pressed("skill_3"):
			ask.activate_manual_skill(2)

	# 阶段1: 装备强化调试快捷键 (F1强化武器)
	if Input.is_action_just_pressed("ui_home") and has_node("/root/EquipmentSystem"):  # F1键
		var eq_sys = get_node("/root/EquipmentSystem")
		var weapon_id = eq_sys.equipped_items.get("weapon", "")
		if weapon_id != "":
			if has_node("/root/AffixWorkshop"):
				var result = get_node("/root/AffixWorkshop").enhance_equipment(weapon_id)
				print("[装备强化] ", result.get("message", ""))
		else:
			print("[装备强化] 未装备武器")

	var should_attack = false
	if auto_attack_enabled:
		should_attack = true
	elif Input.is_action_pressed("attack"):
		should_attack = true

	if should_attack:
		perform_attack()

func perform_attack():
	attack_cooldown = 1.0 / attack_speed
	AudioManager.play("attack")

	# A1: 法师施法消耗法力(用于连锁判定)
	if has_node("/root/ClassMechanicSystem"):
		var cms = get_node("/root/ClassMechanicSystem")
		if cms.has_method("on_mage_cast"):
			cms.on_mage_cast()

	# 播放攻击动画
	if anim_sprite and anim_sprite.sprite_frames.has_animation("attack"):
		_attacking = true
		anim_sprite.play("attack")
		if not anim_sprite.animation_finished.is_connected(_on_attack_done):
			anim_sprite.animation_finished.connect(_on_attack_done, CONNECT_ONE_SHOT)

	# 攻击挥砍特效（朝向前方）
	var fx_offset = Vector2(-50 if _facing_left else 50, 0)
	EffectSprite.spawn(get_parent(), "slash", global_position + fx_offset, 1.4)

	var stats = {
		"damage": damage,
		"crit_chance": crit_chance,
		"crit_damage": crit_damage,
	}
	# 合并词缀效果（吸血、附加火焰、点燃、毒等）
	for key in combat_stats:
		stats[key] = combat_stats[key]

	var attack_area = get_node_or_null("AttackArea")
	if attack_area and has_node("/root/CombatSystem"):
		get_node("/root/CombatSystem").check_player_attack(attack_area, stats)

func _on_attack_done():
	_attacking = false
	if anim_sprite:
		anim_sprite.play("idle")

func take_damage(damage: float):
	# 闪避无敌帧检测(也是 Boss AOE 防护的唯一来源,不可丢)
	if is_dodging and dodge_timer < dodge_i_frame_duration:
		print("[Player] 闪避成功！无敌帧生效")
		return

	# 职业受击机制(A1战士怒气+减伤 / A2骑士圣盾反伤)
	if has_node("/root/ClassMechanicSystem"):
		var cms = get_node("/root/ClassMechanicSystem")
		# A1战士: 受击积攒怒气
		if cms.has_method("on_player_damaged"):
			cms.on_player_damaged()
		# A1战士: 怒气技能期间减伤
		if cms.has_method("get_warrior_damage_reduction"):
			damage *= (1.0 - cms.get_warrior_damage_reduction())
		# A2骑士: 圣盾反伤(作用于减伤后的值,返回实际承受伤害)
		if cms.has_method("knight_on_take_damage"):
			damage = cms.knight_on_take_damage(damage)

	current_hp -= damage
	current_hp = clamp(current_hp, 0, max_hp)
	AudioManager.play("hit")
	hp_changed.emit(current_hp, max_hp)
	# 受击红闪（shader 实现）
	if anim_sprite:
		ShaderHelper.apply_hit_flash(anim_sprite, Color(1.5, 0.4, 0.4), 0.15)
	# 伤害数字
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -40), damage, false)
	if current_hp <= 0:
		die()

func heal(amount: float):
	current_hp += amount
	current_hp = clamp(current_hp, 0, max_hp)
	hp_changed.emit(current_hp, max_hp)
	# 治疗数字
	DamageNumber.spawn(get_parent(), global_position + Vector2(0, -40), amount, false, true)

func die():
	print("Player died")
	player_died.emit(survival_time, kills, gold)
	# 不要直接 queue_free，让 GameOver UI 接管

func get_stat(stat_name: String) -> float:
	match stat_name:
		"armor": return armor
		"max_hp": return max_hp
		"damage": return damage
		"move_speed": return move_speed
		_: return 0.0

## 获得经验值
func gain_exp(amount: float):
	# P6: 巅峰金币加成顺带影响经验？保留经验为原值；巅峰只加金币/掉率
	current_exp += amount

	# 满级后所有溢出经验进巅峰池（包括 amount 本身在 max 时）
	var max_lv = _get_max_level()
	while current_exp >= exp_to_next_level and current_level < max_lv:
		current_exp -= exp_to_next_level
		current_level += 1
		_on_level_up()

	# 满级后：剩余经验全部喂给巅峰池
	if current_level >= max_lv and current_exp > 0.0:
		var overflow = current_exp
		current_exp = 0.0
		if has_node("/root/GameState"):
			GameState.gain_paragon_exp(overflow)

## 计算下一级所需经验
func _calculate_exp_to_next_level():
	var curve = ConfigLoader.get_balance_config().get("level_curve", {})
	var base_exp = float(curve.get("base_exp", 10))
	var growth = float(curve.get("growth", 1.15))
	exp_to_next_level = base_exp * pow(growth, current_level - 1)

## 配置驱动的最高等级（默认 60）
func _get_max_level() -> int:
	var curve = ConfigLoader.get_balance_config().get("level_curve", {})
	return int(curve.get("max_level", 60))

## 升级时调用
func _on_level_up():
	print("[Player] 升级到 %d 级！" % current_level)

	# 从 balance.json 读取每级成长（持久 ARPG：等级带来基础属性成长）
	var curve = ConfigLoader.get_balance_config().get("level_curve", {})
	var stats_per_level = curve.get("stats_per_level", {})
	base_max_hp += stats_per_level.get("max_hp", 0)
	base_damage += stats_per_level.get("damage", 0)

	# 给予属性点（玩家在 CharacterPanel 分配）
	var attr_pts = int(curve.get("attribute_points_per_level", 5))
	attribute_points_unspent += attr_pts
	attribute_points_changed.emit(attribute_points_unspent)

	# 给予技能点（玩家在 SkillTreePanel 分配）
	var sp = int(curve.get("skill_points_per_level", 1))
	if sp > 0 and has_node("/root/SkillSystem"):
		get_node("/root/SkillSystem").add_skill_points(sp)

	recalculate_stats()
	current_hp = max_hp  # 升级回满血

	hp_changed.emit(current_hp, max_hp)
	_calculate_exp_to_next_level()
	level_up.emit(current_level)
	# 升级光环特效
	EffectSprite.spawn(get_parent(), "levelup", global_position, 2.0)
	# B2: 升级粒子光环
	ParticleHelper.spawn_levelup_aura(get_parent(), self)

## 击杀敌人时调用
func on_enemy_killed(enemy_data: Dictionary):
	kills += 1

	# 获得经验
	var exp = enemy_data.get("drop_table", {}).get("exp", 0)
	gain_exp(exp)

	# 获得金币
	var gold_drop = enemy_data.get("drop_table", {}).get("gold", {})
	var min_gold = gold_drop.get("min", 0)
	var max_gold = gold_drop.get("max", 0)
	var gold_amount = randi_range(min_gold, max_gold)
	gold += gold_amount

## 分配属性点
func add_attribute(attr_name: String, points: int):
	if attribute_points_unspent < points:
		push_warning("[Player] 属性点不足: %d < %d" % [attribute_points_unspent, points])
		return

	if not attributes.has(attr_name):
		push_error("[Player] 未知属性: %s" % attr_name)
		return

	attributes[attr_name] += points
	attribute_points_unspent -= points

	recalculate_stats()
	attribute_points_changed.emit(attribute_points_unspent)
	attributes_changed.emit(attributes)

	print("[Player] +%d %s (剩余点数: %d)" % [points, attr_name, attribute_points_unspent])

## 应用属性加点对数值的影响
func _apply_attribute_bonuses():
	var attr_config = ConfigLoader.get_balance_config().get("attributes", {})

	# 力量：增加伤害
	var str_val = attributes.get("strength", 0)
	if str_val > 0:
		var str_cfg = attr_config.get("strength", {})
		damage += str_val * str_cfg.get("damage_flat", 0)
		var dmg_pct = str_val * str_cfg.get("damage_percent", 0)
		damage *= (1.0 + dmg_pct)

	# 敏捷：增加攻速、暴击、闪避
	var agi_val = attributes.get("agility", 0)
	if agi_val > 0:
		var agi_cfg = attr_config.get("agility", {})
		attack_speed += agi_val * agi_cfg.get("attack_speed", 0)
		crit_chance += agi_val * agi_cfg.get("crit_chance", 0)
		# 闪避暂存到 combat_stats，供战斗系统读取
		var dodge = agi_val * agi_cfg.get("dodge", 0)
		if dodge > 0:
			combat_stats["dodge"] = dodge

	# 体质：增加生命和护甲
	var vit_val = attributes.get("vitality", 0)
	if vit_val > 0:
		var vit_cfg = attr_config.get("vitality", {})
		max_hp += vit_val * vit_cfg.get("max_hp", 0)
		armor += vit_val * vit_cfg.get("armor", 0)

	# 智力：增加法术伤害（预留，未来技能系统使用）
	var int_val = attributes.get("intelligence", 0)
	if int_val > 0:
		var int_cfg = attr_config.get("intelligence", {})
		var magic_dmg = int_val * int_cfg.get("magic_damage_flat", 0)
		if magic_dmg > 0:
			combat_stats["magic_damage"] = magic_dmg

