extends Node2D
## 副本地形生成器 - 阶段A2
## 根据区域类型动态生成障碍物、互动元素、环境装饰
## 挂载到副本场景，由DungeonFlow调用

# 地形元素容器
var obstacles: Array = []
var interactables: Array = []

# 区域颜色主题
const REGION_THEMES = {
	"crypt": {"obstacle": Color(0.3, 0.3, 0.4), "accent": Color(0.5, 0.5, 0.7)},
	"forge": {"obstacle": Color(0.4, 0.2, 0.1), "accent": Color(0.9, 0.4, 0.1)},
	"ice": {"obstacle": Color(0.6, 0.8, 0.9), "accent": Color(0.4, 0.7, 1.0)},
	"swamp": {"obstacle": Color(0.3, 0.4, 0.2), "accent": Color(0.4, 0.6, 0.2)},
	"void": {"obstacle": Color(0.3, 0.1, 0.4), "accent": Color(0.6, 0.2, 0.8)},
	"field": {"obstacle": Color(0.4, 0.35, 0.25), "accent": Color(0.6, 0.5, 0.3)}
}

## 生成地形（DungeonFlow.start_dungeon时调用）
func generate_terrain(region: String, parent: Node2D):
	var theme = REGION_THEMES.get(region, REGION_THEMES["crypt"])

	match region:
		"crypt":
			_generate_crypt(parent, theme)
		"forge":
			_generate_forge(parent, theme)
		"ice":
			_generate_ice(parent, theme)
		"swamp":
			_generate_swamp(parent, theme)
		"void":
			_generate_void(parent, theme)
		"field":
			_generate_field(parent, theme)
		_:
			_generate_crypt(parent, theme)

	print("[DungeonTerrain] 生成%s地形: %d障碍物, %d互动元素" % [region, obstacles.size(), interactables.size()])

# ────────────────────────────────────────────────────────────
# 各区域地形生成
# ────────────────────────────────────────────────────────────

## 王陵：4石柱 + 中央祭坛 + 骨堆
func _generate_crypt(parent: Node2D, theme: Dictionary):
	# 4个石柱（矩形布局）
	var pillar_positions = [
		Vector2(-200, -150), Vector2(200, -150),
		Vector2(-200, 150), Vector2(200, 150)
	]
	for pos in pillar_positions:
		_create_obstacle(parent, pos, Vector2(48, 48), theme.obstacle, "石柱")

	# 中央祭坛（Boss出现点标记）
	_create_decoration(parent, Vector2(0, 0), Vector2(80, 80), theme.accent, "石棺祭坛")

	# 2个骨堆（互动）
	_create_interactable(parent, Vector2(-300, 0), "骨堆", "gold")
	_create_interactable(parent, Vector2(300, 0), "骨堆", "gold")

## 熔炉：3熔炉 + 矿车轨道
func _generate_forge(parent: Node2D, theme: Dictionary):
	# 3个大熔炉
	var forge_positions = [Vector2(-250, -100), Vector2(0, -180), Vector2(250, -100)]
	for pos in forge_positions:
		_create_obstacle(parent, pos, Vector2(64, 80), theme.obstacle, "熔炉")
		# 熔炉顶部火光
		_create_decoration(parent, pos + Vector2(0, -50), Vector2(40, 20), theme.accent, "火光")

	# 矿车轨道（横向装饰）
	_create_decoration(parent, Vector2(0, 200), Vector2(600, 16), Color(0.3, 0.25, 0.2), "矿车轨道")

	# 矿石堆（互动-采集材料）
	_create_interactable(parent, Vector2(-350, 100), "矿石堆", "material")
	_create_interactable(parent, Vector2(350, 100), "矿石堆", "material")

## 冰封：城墙 + 火盆 + 冰锥陷阱
func _generate_ice(parent: Node2D, theme: Dictionary):
	# 崩塌城墙（掩体）
	_create_obstacle(parent, Vector2(-250, 0), Vector2(48, 200), theme.obstacle, "城墙")
	_create_obstacle(parent, Vector2(250, 0), Vector2(48, 200), theme.obstacle, "城墙")

	# 冰霜结晶（会扩散）
	_create_obstacle(parent, Vector2(0, -200), Vector2(56, 56), theme.accent, "冰晶")

	# 火盆（互动-温暖buff）
	_create_interactable(parent, Vector2(-150, 150), "火盆", "buff_warm")
	_create_interactable(parent, Vector2(150, 150), "火盆", "buff_warm")

## 沼泽：枯树 + 泥潭 + 毒花
func _generate_swamp(parent: Node2D, theme: Dictionary):
	# 中央枯树（Boss出现点）
	_create_decoration(parent, Vector2(0, 0), Vector2(72, 100), Color(0.25, 0.2, 0.15), "枯树")

	# 沼泽泥潭（减速区，半透明）
	_create_hazard(parent, Vector2(-200, 100), Vector2(120, 120), Color(0.3, 0.4, 0.2, 0.5), "泥潭")
	_create_hazard(parent, Vector2(200, 100), Vector2(120, 120), Color(0.3, 0.4, 0.2, 0.5), "泥潭")

	# 毒花（互动-清除毒池）
	_create_interactable(parent, Vector2(-250, -150), "毒花", "clear_poison")
	_create_interactable(parent, Vector2(250, -150), "毒花", "clear_poison")

## 虚空：浮空平台 + 虚空裂缝
func _generate_void(parent: Node2D, theme: Dictionary):
	# 浮空岩石（可躲避）
	var rock_positions = [
		Vector2(-180, -120), Vector2(180, -120),
		Vector2(0, 0), Vector2(-180, 120), Vector2(180, 120)
	]
	for pos in rock_positions:
		_create_obstacle(parent, pos, Vector2(56, 56), theme.obstacle, "浮空岩")

	# 虚空裂缝（危险区）
	_create_hazard(parent, Vector2(-300, 0), Vector2(40, 250), Color(0.6, 0.2, 0.8, 0.4), "虚空裂缝")
	_create_hazard(parent, Vector2(300, 0), Vector2(40, 250), Color(0.6, 0.2, 0.8, 0.4), "虚空裂缝")

	# 虚空水晶（互动-飞行buff）
	_create_interactable(parent, Vector2(0, -200), "虚空水晶", "buff_fly")

## 荒野：帐篷 + 篝火 + 补给箱
func _generate_field(parent: Node2D, theme: Dictionary):
	# 帐篷（掩体）
	_create_obstacle(parent, Vector2(-250, -100), Vector2(80, 64), theme.obstacle, "帐篷")
	_create_obstacle(parent, Vector2(250, -100), Vector2(80, 64), theme.obstacle, "帐篷")

	# 中央篝火（Boss出现点）
	_create_decoration(parent, Vector2(0, 0), Vector2(48, 48), theme.accent, "篝火")

	# 木栅栏（可破坏）
	_create_obstacle(parent, Vector2(0, 200), Vector2(300, 24), Color(0.4, 0.3, 0.2), "木栅栏")

	# 补给箱（互动-回血）+ 战鼓（互动-攻速buff）
	_create_interactable(parent, Vector2(-300, 100), "补给箱", "heal")
	_create_interactable(parent, Vector2(300, 100), "战鼓", "buff_haste")

# ────────────────────────────────────────────────────────────
# 通用元素创建
# ────────────────────────────────────────────────────────────

## 创建障碍物（StaticBody2D，阻挡移动）
func _create_obstacle(parent: Node2D, pos: Vector2, size: Vector2, color: Color, label: String):
	var obstacle = StaticBody2D.new()
	obstacle.global_position = pos
	obstacle.name = "Obstacle_" + label

	# 视觉
	var rect = ColorRect.new()
	rect.size = size
	rect.position = -size / 2
	rect.color = color
	obstacle.add_child(rect)

	# 碰撞体
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	obstacle.add_child(collision)

	parent.add_child(obstacle)
	obstacles.append(obstacle)

## 创建装饰（纯视觉，无碰撞）
func _create_decoration(parent: Node2D, pos: Vector2, size: Vector2, color: Color, label: String):
	var deco = Node2D.new()
	deco.global_position = pos
	deco.name = "Deco_" + label

	var rect = ColorRect.new()
	rect.size = size
	rect.position = -size / 2
	rect.color = color
	deco.add_child(rect)

	parent.add_child(deco)

## 创建危险区（Area2D，进入受伤/减速）
func _create_hazard(parent: Node2D, pos: Vector2, size: Vector2, color: Color, label: String):
	var hazard = Area2D.new()
	hazard.global_position = pos
	hazard.name = "Hazard_" + label
	hazard.set_meta("hazard_type", label)

	var rect = ColorRect.new()
	rect.size = size
	rect.position = -size / 2
	rect.color = color
	hazard.add_child(rect)

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	hazard.add_child(collision)

	parent.add_child(hazard)

## 创建互动元素（Area2D，F键交互）
func _create_interactable(parent: Node2D, pos: Vector2, label: String, action: String):
	var inter = Area2D.new()
	inter.global_position = pos
	inter.name = "Interact_" + label
	inter.set_meta("action", action)
	inter.set_meta("used", false)
	inter.add_to_group("interactable")

	# 视觉（发光方块）
	var rect = ColorRect.new()
	rect.size = Vector2(32, 32)
	rect.position = Vector2(-16, -16)
	rect.color = Color(1.0, 0.85, 0.3, 0.9)
	inter.add_child(rect)

	# 标签
	var name_label = Label.new()
	name_label.text = label
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.position = Vector2(-20, -36)
	inter.add_child(name_label)

	# 碰撞体（交互范围）
	var collision = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 40
	collision.shape = shape
	inter.add_child(collision)

	parent.add_child(inter)
	interactables.append(inter)

## 清理地形
func clear_terrain():
	for o in obstacles:
		if is_instance_valid(o):
			o.queue_free()
	for i in interactables:
		if is_instance_valid(i):
			i.queue_free()
	obstacles.clear()
	interactables.clear()


# ============================================================
# 阶段C: 互动元素F键处理
# ============================================================

var _player_ref: Node2D = null

func _process(_delta):
	# F键交互检测
	if Input.is_action_just_pressed("interact"):
		_try_interact()

func _try_interact():
	if not _player_ref or not is_instance_valid(_player_ref):
		_player_ref = get_tree().get_first_node_in_group("player")
		if not _player_ref:
			return

	# 查找最近的未使用互动元素（40范围内）
	for inter in interactables:
		if not is_instance_valid(inter):
			continue
		if inter.get_meta("used", false):
			continue

		var dist = _player_ref.global_position.distance_to(inter.global_position)
		if dist <= 50:
			_execute_interaction(inter)
			break

func _execute_interaction(inter: Area2D):
	var action = inter.get_meta("action", "")
	inter.set_meta("used", true)

	match action:
		"gold":
			var amount = 50 + randi() % 50
			# 局内金币加到本局收益（Player.gold），局末由 Victory/GameOver 结算转入钱包
			if is_instance_valid(_player_ref):
				_player_ref.gold += amount
			_show_interact_feedback(inter, "+%d 金币" % amount, Color.GOLD)
		"material":
			if has_node("/root/GameState"):
				GameState.add_material("rune_shard", 2)
			_show_interact_feedback(inter, "+2 符文碎片", Color(0.6, 0.8, 1.0))
		"heal":
			if _player_ref.has_method("heal"):
				_player_ref.heal(_player_ref.max_hp * 0.2)
			_show_interact_feedback(inter, "+20% 生命", Color(0.4, 1.0, 0.4))
		"buff_warm":
			# 火盆: 给玩家+15%伤害持续30秒
			_apply_player_buff("warm", "damage_mult", 0.15, 30.0)
			_show_interact_feedback(inter, "战意涌现 +15% 伤害 (30s)", Color(1.0, 0.55, 0.2))
		"buff_fly":
			# 战鼓: 给玩家+25%攻速持续25秒
			_apply_player_buff("fly", "attack_speed_mult", 0.25, 25.0)
			_show_interact_feedback(inter, "战鼓震响 +25% 攻速 (25s)", Color(1.0, 0.85, 0.3))
		"buff_haste":
			# 急速符文: +30%移速持续20秒
			_apply_player_buff("haste", "move_speed_mult", 0.30, 20.0)
			_show_interact_feedback(inter, "急速 +30% 移速 (20s)", Color(0.4, 0.9, 1.0))
		"clear_poison":
			# 净化:清除附近所有敌人的中毒/点燃 + 玩家自身DOT清空
			if is_instance_valid(_player_ref):
				if "ignite_dps" in _player_ref:
					_player_ref.ignite_dps = 0.0
					_player_ref.ignite_timer = 0.0
				if "poison_dps" in _player_ref:
					_player_ref.poison_dps = 0.0
					_player_ref.poison_timer = 0.0
			# 净化半径200内的所有"危险池"
			var purified = 0
			for danger in get_tree().get_nodes_in_group("danger_zone"):
				if not is_instance_valid(danger):
					continue
				if danger.global_position.distance_to(inter.global_position) <= 220.0:
					danger.queue_free()
					purified += 1
			_show_interact_feedback(inter, "净化 (清除%d个毒池)" % purified, Color(0.4, 0.9, 0.2))
		_:
			_show_interact_feedback(inter, "已使用", Color.WHITE)

	# 互动元素变暗表示已使用
	for child in inter.get_children():
		if child is ColorRect:
			child.color = Color(0.3, 0.3, 0.3, 0.5)

func _show_interact_feedback(inter: Area2D, text: String, color: Color):
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", color)
	label.global_position = inter.global_position + Vector2(-30, -50)
	label.z_index = 100
	get_parent().add_child(label)

	var tween = label.create_tween()
	tween.tween_property(label, "global_position:y", label.global_position.y - 40, 1.0)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)

	if has_node("/root/AudioManager"):
		AudioManager.play("coin")

## 通用玩家buff(限时倍率加成,可叠加多种)
## stat_key: "damage_mult" / "attack_speed_mult" / "move_speed_mult"
func _apply_player_buff(buff_id: String, stat_key: String, value: float, duration: float):
	if not is_instance_valid(_player_ref):
		return
	# 用 meta 存当前激活的 buff,避免重复叠加同名 buff
	var active = _player_ref.get_meta("active_buffs", {})
	if active.has(buff_id):
		# 已有同名 buff: 刷新持续时间,不叠加数值
		active[buff_id]["timer"] = duration
		_player_ref.set_meta("active_buffs", active)
		return
	# 应用倍率到玩家属性
	match stat_key:
		"damage_mult":
			_player_ref.damage *= (1.0 + value)
		"attack_speed_mult":
			_player_ref.attack_speed = min(3.0, _player_ref.attack_speed * (1.0 + value))
		"move_speed_mult":
			_player_ref.move_speed *= (1.0 + value)
	active[buff_id] = {
		"stat": stat_key,
		"value": value,
		"timer": duration,
	}
	_player_ref.set_meta("active_buffs", active)
	# 启动一个一次性 Timer 在 duration 结束时回退
	var t = Timer.new()
	t.wait_time = duration
	t.one_shot = true
	t.autostart = true
	add_child(t)
	t.timeout.connect(func():
		if not is_instance_valid(_player_ref):
			t.queue_free()
			return
		var ab = _player_ref.get_meta("active_buffs", {})
		if not ab.has(buff_id):
			t.queue_free()
			return
		var b = ab[buff_id]
		# 回退倍率(假设期间属性没被其他系统改写,简化做法)
		match b["stat"]:
			"damage_mult":
				_player_ref.damage /= (1.0 + b["value"])
			"attack_speed_mult":
				_player_ref.attack_speed /= (1.0 + b["value"])
			"move_speed_mult":
				_player_ref.move_speed /= (1.0 + b["value"])
		ab.erase(buff_id)
		_player_ref.set_meta("active_buffs", ab)
		t.queue_free()
	)
	# 视觉反馈:玩家身上短暂粒子
	if has_node("/root/ParticleHelper") or ResourceLoader.exists("res://scripts/ParticleHelper.gd"):
		ParticleHelper.spawn_levelup_aura(_player_ref.get_parent(), _player_ref)
