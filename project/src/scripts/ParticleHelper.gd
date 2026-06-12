extends Node
class_name ParticleHelper
## 粒子特效工具类 - 用GPUParticles2D生成各类战斗特效
## 所有粒子都是一次性的(one_shot=true),播完自动销毁


## 命中迸溅粒子 - 用于普通攻击命中
static func spawn_hit_particles(parent: Node, pos: Vector2, color: Color = Color.WHITE) -> void:
	var particles = GPUParticles2D.new()
	particles.global_position = pos
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 12
	particles.lifetime = 0.4
	particles.emitting = false  # 先不发射,等加入树后再发射

	var material = ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 80.0
	material.initial_velocity_max = 150.0
	material.gravity = Vector3(0, 400, 0)
	material.scale_min = 2.0
	material.scale_max = 4.0

	# 颜色渐变: 起始颜色 -> 透明
	var gradient = Gradient.new()
	gradient.add_point(0.0, color)
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	particles.process_material = material
	parent.add_child(particles)
	particles.emitting = true

	# 0.5秒后销毁(留足粒子生命周期)
	particles.get_tree().create_timer(0.5).timeout.connect(
		func():
			if is_instance_valid(particles):
				particles.queue_free()
	)


## 敌人死亡爆裂粒子 - 更大更炸裂
static func spawn_death_burst(
	parent: Node, pos: Vector2, color: Color = Color(1.0, 0.3, 0.3)
) -> void:
	var particles = GPUParticles2D.new()
	particles.global_position = pos
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 30
	particles.lifetime = 0.6
	particles.emitting = false

	var material = ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 120.0
	material.initial_velocity_max = 250.0
	material.gravity = Vector3(0, 500, 0)
	material.scale_min = 3.0
	material.scale_max = 6.0
	material.damping_min = 10.0
	material.damping_max = 20.0

	var gradient = Gradient.new()
	gradient.add_point(0.0, color)
	gradient.add_point(0.5, Color(color.r * 0.8, color.g * 0.5, color.b * 0.2, 0.8))
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	particles.process_material = material
	parent.add_child(particles)
	particles.emitting = true

	particles.get_tree().create_timer(0.8).timeout.connect(
		func():
			if is_instance_valid(particles):
				particles.queue_free()
	)


## 暴击特殊粒子 - 金色星爆
static func spawn_crit_particles(parent: Node, pos: Vector2) -> void:
	var particles = GPUParticles2D.new()
	particles.global_position = pos
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 20
	particles.lifetime = 0.5
	particles.emitting = false

	var material = ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 100.0
	material.initial_velocity_max = 200.0
	material.gravity = Vector3(0, 100, 0)  # 较轻的重力,营造爆裂感
	material.scale_min = 4.0
	material.scale_max = 7.0
	material.angular_velocity_min = -360.0
	material.angular_velocity_max = 360.0

	# 金色渐变
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.95, 0.2, 1.0))  # 亮金色
	gradient.add_point(0.5, Color(1.0, 0.7, 0.1, 0.8))
	gradient.add_point(1.0, Color(1.0, 0.5, 0.0, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	particles.process_material = material
	parent.add_child(particles)
	particles.emitting = true

	particles.get_tree().create_timer(0.6).timeout.connect(
		func():
			if is_instance_valid(particles):
				particles.queue_free()
	)


## 升级光环粒子 - 环绕玩家上升的金色光点
static func spawn_levelup_aura(parent: Node, node: Node2D) -> void:
	var particles = GPUParticles2D.new()
	particles.global_position = node.global_position
	particles.one_shot = true
	particles.explosiveness = 0.0  # 连续发射,营造光环上升感
	particles.amount = 50
	particles.lifetime = 1.5
	particles.preprocess = 0.2
	particles.emitting = false

	var material = ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	material.emission_ring_axis = Vector3(0, 0, 1)
	material.emission_ring_height = 1.0
	material.emission_ring_radius = 40.0
	material.emission_ring_inner_radius = 30.0
	material.direction = Vector3(0, -1, 0)
	material.spread = 15.0
	material.initial_velocity_min = 80.0
	material.initial_velocity_max = 120.0
	material.gravity = Vector3(0, -50, 0)  # 负重力,向上飘
	material.scale_min = 2.5
	material.scale_max = 4.5

	# 金色光芒渐变
	var gradient = Gradient.new()
	gradient.add_point(0.0, Color(1.0, 0.9, 0.3, 0.0))
	gradient.add_point(0.2, Color(1.0, 0.95, 0.5, 1.0))
	gradient.add_point(0.8, Color(1.0, 0.8, 0.2, 0.8))
	gradient.add_point(1.0, Color(1.0, 0.7, 0.1, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	particles.process_material = material
	parent.add_child(particles)
	particles.emitting = true

	particles.get_tree().create_timer(2.0).timeout.connect(
		func():
			if is_instance_valid(particles):
				particles.queue_free()
	)


## 装备掉落闪烁 - 按稀有度颜色
static func spawn_pickup_sparkle(parent: Node, pos: Vector2, rarity: String) -> void:
	# 根据稀有度决定颜色
	var color = _get_rarity_color(rarity)

	var particles = GPUParticles2D.new()
	particles.global_position = pos
	particles.one_shot = true
	particles.explosiveness = 0.8
	particles.amount = 25
	particles.lifetime = 0.8
	particles.emitting = false

	var material = ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 60.0
	material.initial_velocity_max = 120.0
	material.gravity = Vector3(0, 150, 0)
	material.scale_min = 3.0
	material.scale_max = 5.0
	material.angular_velocity_min = -180.0
	material.angular_velocity_max = 180.0

	var gradient = Gradient.new()
	gradient.add_point(0.0, color)
	gradient.add_point(0.6, Color(color.r * 1.2, color.g * 1.2, color.b * 1.2, 0.9))
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	var gradient_texture = GradientTexture1D.new()
	gradient_texture.gradient = gradient
	material.color_ramp = gradient_texture

	particles.process_material = material
	parent.add_child(particles)
	particles.emitting = true

	particles.get_tree().create_timer(1.0).timeout.connect(
		func():
			if is_instance_valid(particles):
				particles.queue_free()
	)


## 辅助:获取稀有度对应颜色（A1 收口：委托 Schema 单一真源）
static func _get_rarity_color(rarity: String) -> Color:
	return Schema.rarity_color(rarity)


# ============================================================
# A3: 元素配色 + 攻击拖尾 + 技能特效 + Boss 入场演出
# 元素配色与 art-spec.md §4 一致
# ============================================================

const ELEMENT_COLORS := {
	"fire": Color("#FF6B2A"),
	"ignite": Color("#FF6B2A"),
	"poison": Color("#7FBF3F"),
	"ice": Color("#7FD4FF"),
	"freeze": Color("#7FD4FF"),
	"lightning": Color("#9BE6FF"),
	"chain": Color("#9BE6FF"),
	"shadow": Color("#9B4DCA"),
	"void": Color("#9B4DCA"),
	"physical": Color("#FFE08A"),
	"crit": Color("#FFE08A"),
}


static func element_color(element: String) -> Color:
	return ELEMENT_COLORS.get(element, Color.WHITE)


## 攻击挥砍拖尾 - 沿攻击方向的弧形残影（用 Line2D + 渐隐 tween）
## from: 起点(角色), dir: 朝向(单位向量), length: 挥砍半径, color: 元素色
static func spawn_slash_trail(
	parent: Node, from: Vector2, dir: Vector2, length: float = 70.0, color: Color = Color("#FFE08A")
) -> void:
	if parent == null:
		return
	var line = Line2D.new()
	line.width = 8.0
	line.default_color = color
	line.z_index = 40
	# 用一段弧线模拟挥砍轨迹（垂直于 dir 的扇形采样）
	var base_angle = dir.angle()
	var arc = deg_to_rad(80.0)
	var steps = 8
	for i in range(steps + 1):
		var a = base_angle - arc * 0.5 + arc * (float(i) / steps)
		line.add_point(from + Vector2(cos(a), sin(a)) * length)
	# 宽度递减曲线
	var curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.2))
	line.width_curve = curve
	parent.add_child(line)
	var tw = line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.18)
	tw.tween_callback(line.queue_free)


## 冲刺/闪避残影 - 在指定位置留一个角色轮廓快照，渐隐
static func spawn_dash_afterimage(
	parent: Node,
	pos: Vector2,
	sprite_tex: Texture2D = null,
	color: Color = Color(0.6, 0.8, 1.0, 0.5),
	flip_h: bool = false
) -> void:
	if parent == null:
		return
	var ghost: CanvasItem
	if sprite_tex != null:
		var s = Sprite2D.new()
		s.texture = sprite_tex
		s.flip_h = flip_h
		s.scale = Vector2(2.6, 2.6)
		s.global_position = pos
		ghost = s
	else:
		# 无纹理回退：用 Polygon2D 画一个角色轮廓近似（Node2D 系，可设 global_position）
		var poly = Polygon2D.new()
		poly.polygon = PackedVector2Array(
			[Vector2(-20, -32), Vector2(20, -32), Vector2(20, 32), Vector2(-20, 32)]
		)
		poly.global_position = pos
		ghost = poly
	ghost.modulate = color
	ghost.z_index = 30
	parent.add_child(ghost)
	var tw = ghost.create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.25)
	tw.tween_callback(ghost.queue_free)


## 技能释放特效 - 按元素类型生成不同色调的爆发粒子
## element: fire/poison/ice/lightning/shadow/physical
static func spawn_skill_burst(
	parent: Node, pos: Vector2, element: String = "physical", scale_mult: float = 1.0
) -> void:
	var color = element_color(element)
	var particles = GPUParticles2D.new()
	particles.global_position = pos
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = int(24 * scale_mult)
	particles.lifetime = 0.5
	particles.emitting = false

	var material = ParticleProcessMaterial.new()
	material.particle_flag_disable_z = true
	material.direction = Vector3(0, -1, 0)
	material.spread = 180.0
	material.initial_velocity_min = 90.0 * scale_mult
	material.initial_velocity_max = 180.0 * scale_mult
	# 元素决定重力方向：火/雷向上飘，毒/冰下沉
	match element:
		"fire", "ignite", "lightning", "chain":
			material.gravity = Vector3(0, -60, 0)
		"poison", "ice", "freeze":
			material.gravity = Vector3(0, 200, 0)
		_:
			material.gravity = Vector3(0, 80, 0)
	material.scale_min = 3.0 * scale_mult
	material.scale_max = 6.0 * scale_mult

	var gradient = Gradient.new()
	gradient.add_point(0.0, color)
	gradient.add_point(0.6, Color(color.r, color.g, color.b, 0.7))
	gradient.add_point(1.0, Color(color.r, color.g, color.b, 0.0))
	var gtex = GradientTexture1D.new()
	gtex.gradient = gradient
	material.color_ramp = gtex

	particles.process_material = material
	parent.add_child(particles)
	particles.emitting = true
	particles.get_tree().create_timer(0.7).timeout.connect(
		func():
			if is_instance_valid(particles):
				particles.queue_free()
	)


## Boss 入场演出 - 地面冲击波环 + 屏幕暗角脉冲（配合 FeedbackSystem 震屏）
## 返回总演出时长（秒），调用方可据此延迟开战
static func spawn_boss_entrance(
	parent: Node, pos: Vector2, tint: Color = Color(1.0, 0.4, 0.3)
) -> float:
	if parent == null:
		return 0.0
	# 扩散冲击波环（Line2D 圆环放大 + 渐隐）
	for ring_i in range(3):
		var ring = Line2D.new()
		ring.width = 6.0
		ring.default_color = tint
		ring.z_index = 35
		ring.closed = true
		var seg = 32
		var r0 = 20.0
		for i in range(seg):
			var a = TAU * float(i) / seg
			ring.add_point(Vector2(cos(a), sin(a)) * r0)
		ring.global_position = pos
		parent.add_child(ring)
		var delay = ring_i * 0.18
		var tw = ring.create_tween()
		tw.tween_interval(delay)
		tw.tween_property(ring, "scale", Vector2(8, 8), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(
			Tween.EASE_OUT
		)
		tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.5)
		tw.tween_callback(ring.queue_free)
	# 升腾的能量粒子柱
	spawn_skill_burst(parent, pos, "shadow", 2.0)
	return 0.9


# ============================================================
# 动态光照辅助 (mobile/forward_plus 渲染器, gl_compatibility 下静默无效)
# ============================================================


## 创建一个一次性 PointLight2D 闪光，自动渐隐销毁
## 用途：暴击命中、技能释放、捡到稀有装备等瞬时光效
static func spawn_flash_light(
	parent: Node,
	pos: Vector2,
	color: Color = Color(1, 0.8, 0.3),
	radius: float = 200.0,
	duration: float = 0.3,
	energy: float = 1.5
) -> void:
	if parent == null:
		return
	var light := PointLight2D.new()
	light.global_position = pos
	light.color = color
	light.energy = energy
	light.texture_scale = radius / 256.0  # 默认光照纹理 ~256px
	light.shadow_enabled = false
	# 用一张白色径向渐变作为光照纹理：用 GradientTexture2D 程序化生成
	var grad := Gradient.new()
	grad.add_point(0.0, Color(1, 1, 1, 1))
	grad.add_point(1.0, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	light.texture = tex
	parent.add_child(light)

	# 渐隐 + 销毁
	var tw := light.create_tween()
	tw.tween_property(light, "energy", 0.0, duration)
	tw.tween_callback(light.queue_free)


## 给 Boss 节点附加常驻光环（跟随 Boss 移动）
## 调用方负责保留返回的 PointLight2D 引用，Boss 死亡时 queue_free
static func attach_boss_aura(
	boss_node: Node2D,
	color: Color = Color(1.0, 0.3, 0.2),
	radius: float = 320.0,
	energy: float = 1.2
) -> PointLight2D:
	if boss_node == null:
		return null
	var light := PointLight2D.new()
	light.color = color
	light.energy = energy
	light.texture_scale = radius / 256.0
	light.shadow_enabled = false

	var grad := Gradient.new()
	grad.add_point(0.0, Color(1, 1, 1, 1))
	grad.add_point(0.6, Color(1, 1, 1, 0.4))
	grad.add_point(1.0, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	light.texture = tex
	boss_node.add_child(light)

	# 缓慢脉冲让光环有"生命感"
	var tw := light.create_tween().set_loops()
	tw.tween_property(light, "energy", energy * 1.3, 1.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(light, "energy", energy * 0.85, 1.2).set_trans(Tween.TRANS_SINE)
	return light


## 装备拾取的稀有度光晕（捡起瞬间一闪 + 持续微光直到被捡走）
## 用途：DropItem 节点上的小光源，提示稀有度
static func attach_drop_glow(drop_node: Node2D, rarity: String = "common") -> PointLight2D:
	if drop_node == null:
		return null
	var color := _get_rarity_color(rarity)
	var light := PointLight2D.new()
	light.color = color
	light.energy = 0.8
	light.texture_scale = 0.5
	light.shadow_enabled = false

	var grad := Gradient.new()
	grad.add_point(0.0, Color(1, 1, 1, 1))
	grad.add_point(1.0, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	light.texture = tex
	drop_node.add_child(light)

	# 呼吸效果
	var tw := light.create_tween().set_loops()
	tw.tween_property(light, "energy", 1.2, 0.8).set_trans(Tween.TRANS_SINE)
	tw.tween_property(light, "energy", 0.6, 0.8).set_trans(Tween.TRANS_SINE)
	return light


## 玩家技能释放的爆炸光（瞬时强光，强度按技能等级缩放）
static func spawn_skill_burst_light(
	parent: Node,
	pos: Vector2,
	element: String = "fire",
	radius: float = 350.0,
	duration: float = 0.5
) -> void:
	var color := element_color(element)
	# 高能量瞬时光 + 略大半径
	spawn_flash_light(parent, pos, color, radius, duration, 2.5)
