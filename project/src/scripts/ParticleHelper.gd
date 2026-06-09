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
	particles.get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

## 敌人死亡爆裂粒子 - 更大更炸裂
static func spawn_death_burst(parent: Node, pos: Vector2, color: Color = Color(1.0, 0.3, 0.3)) -> void:
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

	particles.get_tree().create_timer(0.8).timeout.connect(func():
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

	particles.get_tree().create_timer(0.6).timeout.connect(func():
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

	particles.get_tree().create_timer(2.0).timeout.connect(func():
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

	particles.get_tree().create_timer(1.0).timeout.connect(func():
		if is_instance_valid(particles):
			particles.queue_free()
	)

## 辅助:获取稀有度对应颜色
static func _get_rarity_color(rarity: String) -> Color:
	match rarity:
		"legendary": return Color(1.0, 0.5, 0.0)  # 橙色
		"epic": return Color(0.7, 0.3, 1.0)  # 紫色
		"rare": return Color(0.3, 0.6, 1.0)  # 蓝色
		"magic": return Color(0.3, 1.0, 0.5)  # 绿色
		"common": return Color(0.8, 0.8, 0.8)  # 白色
		_: return Color.WHITE
