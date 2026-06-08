extends Area2D
## 掉落物 - 飞向玩家并触发拾取UI，按稀有度显示特效

var item_data: Dictionary
var fly_speed: float = 400.0
var is_flying: bool = false
var target_player: Node2D
var _vfx_time: float = 0.0

func setup(data: Dictionary):
	item_data = data
	_setup_rarity_visual()

func _ready():
	body_entered.connect(_on_body_entered)
	_setup_rarity_visual()

## 根据稀有度设置视觉（颜色+特效等级）
func _setup_rarity_visual():
	var rarity = item_data.get("rarity", "common")
	var color = EquipmentSystem.get_rarity_color(rarity)
	var vfx_level = EquipmentSystem.get_rarity_vfx_level(rarity)

	var visual = get_node_or_null("Visual")
	if visual:
		visual.color = color

	# 特效等级越高，掉落物越华丽
	# level 1+ 描边光晕；level 2+ 粒子；level 3+ 光柱；level 4 脉冲全屏
	if vfx_level >= 3:
		_add_drop_beam(color)
	if vfx_level >= 2:
		_add_glow(color, vfx_level)

## 高稀有度光柱
func _add_drop_beam(color: Color):
	var beam = ColorRect.new()
	beam.name = "Beam"
	beam.color = Color(color.r, color.g, color.b, 0.35)
	beam.size = Vector2(8, 80)
	beam.position = Vector2(-4, -80)
	add_child(beam)

## 发光节点
func _add_glow(color: Color, level: int):
	var glow = ColorRect.new()
	glow.name = "Glow"
	var s = 24 + level * 6
	glow.color = Color(color.r, color.g, color.b, 0.25)
	glow.size = Vector2(s, s)
	glow.position = Vector2(-s/2.0, -s/2.0)
	add_child(glow)
	move_child(glow, 0)

func _physics_process(delta):
	# 高稀有度脉冲动画
	var beam = get_node_or_null("Beam")
	if beam:
		_vfx_time += delta
		beam.modulate.a = 0.6 + 0.4 * sin(_vfx_time * 4.0)

	if is_flying and target_player:
		var direction = (target_player.global_position - global_position).normalized()
		global_position += direction * fly_speed * delta
		if global_position.distance_to(target_player.global_position) < 20:
			pickup()

func _on_body_entered(body: Node2D):
	if body.is_in_group("player") and not is_flying:
		target_player = body
		is_flying = true

func pickup():
	if not target_player:
		queue_free()
		return
	AudioManager.play("item_drop")
	# 显示装备拾取UI
	var main_scene = get_tree().current_scene
	var game_manager = main_scene.get_node_or_null("GameManager")
	if game_manager and game_manager.has_method("show_equipment_pickup"):
		# 新体系：直接传字符串部位
		var slot = item_data.get("slot", "weapon")
		game_manager.show_equipment_pickup(item_data, slot)
	queue_free()
