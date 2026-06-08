extends Node
## GameManager - 协调游戏流程和UI系统

@onready var player: CharacterBody2D = get_parent().get_node("Player")
@onready var level_up_ui: Control = get_parent().get_node("UILayer/LevelUpUI")
@onready var equipment_pickup: Control = get_parent().get_node("UILayer/EquipmentPickup")
@onready var game_over: Control = get_parent().get_node("UILayer/GameOver")

# 玩家已学习的技能
var learned_skills: Dictionary = {}

func _ready():
	# 生成可视化战斗地图（铺地块+障碍物）
	_generate_battle_map()

	# 连接玩家信号
	if player:
		player.level_up.connect(_on_player_level_up)
		player.player_died.connect(_on_player_died)

	# 连接UI信号
	if level_up_ui:
		level_up_ui.skill_selected.connect(_on_skill_selected)

	if equipment_pickup:
		equipment_pickup.equipment_equipped.connect(_on_equipment_equipped)
		equipment_pickup.equipment_discarded.connect(_on_equipment_discarded)

	print("[GameManager] 游戏管理器初始化完成")

	# 重置主动技能系统并注册职业起手技能
	if has_node("/root/ActiveSkillSystem"):
		get_node("/root/ActiveSkillSystem").reset()
	_grant_starting_skill()

## 授予职业起手技能
func _grant_starting_skill():
	if not has_node("/root/GameState"):
		return
	var cls = get_node("/root/GameState").get_current_class()
	var start_skill_id = cls.get("starting_skill", "")
	if start_skill_id == "":
		return
	var skill = ConfigLoader.get_skill_by_id(start_skill_id)
	if skill.is_empty():
		return
	learned_skills[start_skill_id] = 1
	_apply_skill_effect(start_skill_id, 1)
	print("[GameManager] 授予起手技能: %s" % skill.get("display_name", ""))

## 玩家升级时触发
func _on_player_level_up(new_level: int):
	print("[GameManager] 玩家升级到 %d 级，显示技能选择" % new_level)

	# 从技能池随机抽取3个技能
	var skill_choices = _draw_random_skills(3)

	if skill_choices.size() == 3:
		level_up_ui.show_level_up(skill_choices)
	else:
		push_error("[GameManager] 技能抽取失败，技能数量不足3个")

## 从技能池随机抽取技能（按当前职业过滤）
func _draw_random_skills(count: int) -> Array:
	# 按职业过滤可用技能池
	var class_id = ""
	if has_node("/root/GameState"):
		class_id = get_node("/root/GameState").selected_class_id
	var skills_data = ConfigLoader.get_skills_for_class(class_id)
	if skills_data.is_empty():
		# 兜底：用全部技能
		skills_data = ConfigLoader.skills_data.get("skills", [])
	if skills_data.is_empty():
		push_error("[GameManager] 技能配置为空")
		return []

	# 过滤掉已满级的技能
	var available_skills = []
	for skill in skills_data:
		var skill_id = skill.get("id", "")
		var current_level = learned_skills.get(skill_id, 0)
		var max_level = skill.get("max_level", 5)
		if current_level < max_level:
			available_skills.append(skill)

	if available_skills.size() < count:
		push_warning("[GameManager] 可用技能不足 %d 个，只有 %d 个" % [count, available_skills.size()])
		return available_skills

	# 随机抽取
	var choices = []
	var indices = range(available_skills.size())
	indices.shuffle()
	for i in range(count):
		choices.append(available_skills[indices[i]])
	return choices

## 玩家选择技能后
func _on_skill_selected(skill_id: String):
	print("[GameManager] 玩家选择技能: %s" % skill_id)

	# 增加技能等级
	var current_level = learned_skills.get(skill_id, 0)
	learned_skills[skill_id] = current_level + 1

	# 应用技能效果
	_apply_skill_effect(skill_id, learned_skills[skill_id])

## 应用技能效果到玩家
func _apply_skill_effect(skill_id: String, level: int):
	var skill_data = _get_skill_by_id(skill_id)
	if skill_data.is_empty():
		push_error("[GameManager] 技能ID不存在: %s" % skill_id)
		return

	var effect = skill_data.get("effect", {})
	var kind = effect.get("kind", "")

	print("[GameManager] 应用技能效果: %s (等级 %d)" % [skill_data.get("display_name", ""), level])

	# 根据技能类型应用效果
	match kind:
		"add_stat":
			var stat = effect.get("stat", "")
			var value = effect.get("value", 0)
			var level_scaling = skill_data.get("level_scaling", {})
			var value_per_level = level_scaling.get("value_per_level", 0)
			var total_value = value + (value_per_level * (level - 1))
			_apply_stat_to_player(stat, total_value, false)

		"mult_stat":
			var stat = effect.get("stat", "")
			var value = effect.get("value", 0.0)
			var level_scaling = skill_data.get("level_scaling", {})
			var value_per_level = level_scaling.get("value_per_level", 0.0)
			var total_value = value + (value_per_level * (level - 1))
			_apply_stat_to_player(stat, total_value, true)

		"buff":
			# 临时增益类，注册为被动属性（简化：直接加属性）
			var stat = effect.get("stat", "")
			var value = effect.get("value", 0.0)
			_apply_stat_to_player(stat, value, true)

		"projectile", "melee_swing", "summon", "aura", "dash":
			# 主动技能：注册到主动技能系统自动释放
			if has_node("/root/ActiveSkillSystem"):
				get_node("/root/ActiveSkillSystem").register_skill(skill_data, level)
			print("[GameManager] 注册主动技能: %s" % skill_data.get("display_name", ""))

		"execute":
			# 斩杀类被动，记录到玩家（战斗系统读取）
			if player:
				player.set_meta("execute_threshold", effect.get("threshold", 0.15))
				player.set_meta("execute_bonus", effect.get("bonus_mult", 2.0))

		_:
			push_warning("[GameManager] 未知技能效果类型: %s" % kind)

## 应用属性到玩家
func _apply_stat_to_player(stat: String, value: float, is_multiplier: bool):
	if not player:
		return

	match stat:
		"max_hp":
			if is_multiplier:
				player.max_hp *= (1.0 + value)
			else:
				player.max_hp += value
			player.current_hp = player.max_hp  # 回满血
			player.hp_changed.emit(player.current_hp, player.max_hp)

		"move_speed":
			if is_multiplier:
				player.move_speed *= (1.0 + value)
			else:
				player.move_speed += value

		"damage":
			if is_multiplier:
				player.base_damage *= (1.0 + value)
			else:
				player.base_damage += value

		_:
			push_warning("[GameManager] 未知属性: %s" % stat)

	print("[GameManager] 应用属性: %s %s %s" % [stat, "×" if is_multiplier else "+", value])

## 根据ID查找技能
func _get_skill_by_id(skill_id: String) -> Dictionary:
	var skills = ConfigLoader.skills_data.get("skills", [])
	for skill in skills:
		if skill.get("id", "") == skill_id:
			return skill
	return {}

## 玩家死亡时触发
func _on_player_died(time: float, kill_count: int, gold_earned: int):
	print("[GameManager] 玩家死亡，显示GameOver界面")
	game_over.show_game_over(time, kill_count, gold_earned)

## 装备被装备
func _on_equipment_equipped(item_data: Dictionary):
	print("[GameManager] 装备已装备: %s" % item_data.get("display_name", ""))

## 装备被丢弃
func _on_equipment_discarded():
	print("[GameManager] 装备已丢弃")

## 显示装备拾取UI
func show_equipment_pickup(item_data: Dictionary, slot):
	if equipment_pickup:
		equipment_pickup.show_equipment(item_data, slot)

## ============== 可视化地图生成 ==============
const TILE_SIZE = 64
const MAP_WIDTH = 30
const MAP_HEIGHT = 20

func _generate_battle_map():
	var dungeon_id = GameState.selected_dungeon if GameState.selected_dungeon != "" else "dungeon_crypt_1"
	var dungeon = ConfigLoader.get_dungeon_by_id(dungeon_id)
	var region = dungeon.get("region", "field") if not dungeon.is_empty() else "field"

	var main_scene = get_parent()
	var map_w = MAP_WIDTH * TILE_SIZE
	var map_h = MAP_HEIGHT * TILE_SIZE
	# 以玩家出生点为地图中心
	var center = Vector2(960, 540)
	if player:
		center = player.global_position
	var origin = center - Vector2(map_w / 2, map_h / 2)

	# 地块铺地面
	var floor_tex = SpriteLibrary.get_tile(region, false)
	var ground = Node2D.new()
	ground.name = "BattleGround"
	ground.z_index = -20
	main_scene.add_child(ground)
	if floor_tex:
		for ty in range(MAP_HEIGHT):
			for tx in range(MAP_WIDTH):
				var s = Sprite2D.new()
				s.texture = floor_tex
				s.centered = false
				s.position = origin + Vector2(tx * TILE_SIZE, ty * TILE_SIZE)
				s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				ground.add_child(s)
	else:
		# 回退：纯色背景
		var bg = ColorRect.new()
		bg.size = Vector2(map_w, map_h)
		bg.position = origin
		bg.color = Color(0.15, 0.15, 0.18)
		ground.add_child(bg)

	# 障碍物（使用生成的障碍物精灵 + 碰撞）
	_create_obstacles(region, main_scene, map_w, map_h, center)

	print("[GameManager] 生成 %s 区域地图（%dx%d 格）" % [region, MAP_WIDTH, MAP_HEIGHT])

func _create_obstacles(region: String, parent: Node, map_w: float, map_h: float, center: Vector2):
	var obs_tex = SpriteLibrary.get_tile(region, true)
	var count = 14
	for i in range(count):
		var angle = randf() * TAU
		var distance = randf_range(220, min(map_w, map_h) / 2.2)
		var pos = center + Vector2(cos(angle), sin(angle)) * distance

		var holder = Node2D.new()
		holder.position = pos
		holder.z_index = -3

		if obs_tex:
			var spr = Sprite2D.new()
			spr.texture = obs_tex
			spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			spr.scale = Vector2(1.2, 1.2)
			holder.add_child(spr)
		else:
			var cr = ColorRect.new()
			cr.size = Vector2(60, 60)
			cr.position = Vector2(-30, -30)
			cr.color = Color(0.3, 0.3, 0.35)
			holder.add_child(cr)

		# 碰撞体
		var body = StaticBody2D.new()
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(56, 56)
		col.shape = shape
		body.add_child(col)
		holder.add_child(body)

		parent.add_child(holder)

