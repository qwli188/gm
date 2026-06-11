extends Node
class_name ShaderHelper
## Shader 效果工具类 - 封装常用 shader 调用，简化使用
## 用法: ShaderHelper.apply_hit_flash(sprite, Color.RED, 0.8)

# ============ 稀有度描边发光 ============


## 应用稀有度描边（给装备图标/掉落物）
## rarity: "common"|"rare"|"epic"|"legendary"|"mythic"（见 Schema.RARITIES）
## A1 收口：描边色一律取 Schema.rarity_color，强度/宽度按 rank 派生
static func apply_rarity_glow(node: CanvasItem, rarity: String) -> void:
	var shader := load("res://shaders/rarity_outline.gdshader") as Shader
	if not shader:
		push_error("ShaderHelper: rarity_outline.gdshader not found")
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader

	var r := rarity.to_lower()
	var rank := Schema.rarity_rank(r)
	if rank < 0:
		push_warning("ShaderHelper: unknown rarity '%s', using common" % rarity)
		rank = 0
		r = "common"
	# 描边色 = Schema 真源；宽度/辉光随稀有度等级递增
	mat.set_shader_parameter("outline_color", Schema.rarity_color(r))
	mat.set_shader_parameter("outline_width", float(Schema.rarity_border_width(r)))
	# 辉光：common 无辉光，往上递增；传奇/神话有脉动
	var glow_levels := [0.0, 0.5, 0.8, 1.5, 2.0]
	var glow: float = glow_levels[rank]
	mat.set_shader_parameter("glow_intensity", glow)
	if rank >= 3:
		mat.set_shader_parameter("pulse_speed", 2.5 + (rank - 3) * 1.0)

	node.material = mat


# ============ A4: 通用精灵润色（描边 + 落地阴影，不占 material 槽）============


## 给角色/敌人精灵加一个椭圆落地阴影（独立子节点，不碰 material，
## 因此与受击闪白/状态叠色 shader 共存）。重复调用幂等（同名节点只建一次）。
## owner_node: 挂阴影的父节点（一般是 Player/Enemy 这个 CharacterBody2D）
## width/height: 阴影椭圆尺寸；y_offset: 相对原点的垂直偏移（脚下）
static func ensure_drop_shadow(
	owner_node: Node2D, width: float = 40.0, height: float = 14.0, y_offset: float = 28.0
) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		return
	if owner_node.has_node("DropShadow"):
		return
	var shadow := _make_ellipse_shadow(width, height)
	shadow.name = "DropShadow"
	shadow.position = Vector2(0, y_offset)
	shadow.z_index = -1  # 永远在角色脚下
	owner_node.add_child(shadow)


static func _make_ellipse_shadow(width: float, height: float) -> Node2D:
	# 用 Polygon2D 画椭圆，半透明黑，营造贴地阴影
	var poly := Polygon2D.new()
	var pts := PackedVector2Array()
	var steps := 16
	for i in range(steps):
		var a := TAU * float(i) / steps
		pts.append(Vector2(cos(a) * width * 0.5, sin(a) * height * 0.5))
	poly.polygon = pts
	poly.color = Color(0, 0, 0, 0.35)
	return poly


# ============ 受击闪白 ============


## 应用受击闪白（替代 modulate）
## duration: 闪白持续时间（秒）
## flash_color: 闪烁颜色（默认白色）
static func apply_hit_flash(
	node: CanvasItem, flash_color: Color = Color.WHITE, duration: float = 0.15
) -> void:
	var shader := load("res://shaders/hit_flash.gdshader") as Shader
	if not shader:
		push_error("ShaderHelper: hit_flash.gdshader not found")
		return

	# 如果已有 ShaderMaterial 且是 hit_flash，复用；否则创建新的
	var mat: ShaderMaterial
	if (
		node.material
		and node.material is ShaderMaterial
		and (node.material as ShaderMaterial).shader == shader
	):
		mat = node.material as ShaderMaterial
	else:
		mat = ShaderMaterial.new()
		mat.shader = shader
		node.material = mat

	mat.set_shader_parameter("flash_color", flash_color)

	# Tween 动画: flash_amount 0→1→0
	var tween := node.create_tween()
	tween.tween_method(
		func(val: float): mat.set_shader_parameter("flash_amount", val), 0.0, 1.0, duration * 0.4
	)
	tween.tween_method(
		func(val: float): mat.set_shader_parameter("flash_amount", val), 1.0, 0.0, duration * 0.6
	)


## 移除受击闪白 shader（恢复正常）
static func remove_hit_flash(node: CanvasItem) -> void:
	if node.material and node.material is ShaderMaterial:
		var mat := node.material as ShaderMaterial
		if mat.shader and mat.shader.resource_path.ends_with("hit_flash.gdshader"):
			node.material = null


# ============ 状态层叠加 ============


## 应用状态效果层（冰冻/中毒/点燃）
## status: "freeze"|"poison"|"ignite"
## intensity: 效果强度 (0.0-1.0)
static func apply_status_overlay(node: CanvasItem, status: String, intensity: float = 0.6) -> void:
	var shader := load("res://shaders/status_overlay.gdshader") as Shader
	if not shader:
		push_error("ShaderHelper: status_overlay.gdshader not found")
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader

	var status_type := 0
	match status.to_lower():
		"freeze":
			status_type = 1
		"poison":
			status_type = 2
		"ignite":
			status_type = 3
		_:
			push_warning("ShaderHelper: unknown status '%s'" % status)
			return

	mat.set_shader_parameter("status_type", status_type)
	mat.set_shader_parameter("effect_intensity", intensity)
	node.material = mat


## 移除状态层效果
static func remove_status_overlay(node: CanvasItem) -> void:
	if node.material and node.material is ShaderMaterial:
		var mat := node.material as ShaderMaterial
		if mat.shader and mat.shader.resource_path.ends_with("status_overlay.gdshader"):
			node.material = null


# ============ Boss 溶解 ============


## 开始 Boss 溶解动画（死亡/登场）
## direction: "in" (登场: 1→0) 或 "out" (死亡: 0→1)
## duration: 动画时长
## edge_color: 溶解边缘颜色
static func apply_dissolve(
	node: CanvasItem,
	direction: String = "out",
	duration: float = 1.2,
	edge_color: Color = Color(1.0, 0.5, 0.0)
) -> Tween:
	var shader := load("res://shaders/dissolve.gdshader") as Shader
	if not shader:
		push_error("ShaderHelper: dissolve.gdshader not found")
		return null

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("edge_color", edge_color)
	mat.set_shader_parameter("edge_width", 0.08)
	mat.set_shader_parameter("noise_scale", 8.0)
	node.material = mat

	var start_val := 1.0 if direction == "in" else 0.0
	var end_val := 0.0 if direction == "in" else 1.0
	mat.set_shader_parameter("dissolve_amount", start_val)

	var tween := node.create_tween()
	tween.tween_method(
		func(val: float): mat.set_shader_parameter("dissolve_amount", val),
		start_val,
		end_val,
		duration
	)
	return tween


# ============ 暗角/氛围 ============


## 创建全屏暗角（需要一个 ColorRect 节点覆盖全屏）
## parent: 要添加暗角的父节点（通常是 CanvasLayer）
## intensity: 暗角强度
## color: 暗角颜色
static func create_vignette(
	parent: Node, intensity: float = 0.6, vignette_color: Color = Color.BLACK
) -> ColorRect:
	var shader := load("res://shaders/vignette.gdshader") as Shader
	if not shader:
		push_error("ShaderHelper: vignette.gdshader not found")
		return null

	var rect := ColorRect.new()
	rect.name = "Vignette"
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("vignette_intensity", intensity)
	mat.set_shader_parameter("vignette_radius", 0.7)
	mat.set_shader_parameter("vignette_color", vignette_color)
	rect.material = mat

	parent.add_child(rect)
	return rect


## 动态调整暗角强度（配合死亡之雾等机制）
static func tween_vignette_intensity(
	vignette: ColorRect, target_intensity: float, duration: float = 1.0
) -> Tween:
	if not vignette or not vignette.material or not vignette.material is ShaderMaterial:
		push_error("ShaderHelper: invalid vignette node")
		return null

	var mat := vignette.material as ShaderMaterial
	var current := mat.get_shader_parameter("vignette_intensity") as float
	var tween := vignette.create_tween()
	tween.tween_method(
		func(val: float): mat.set_shader_parameter("vignette_intensity", val),
		current,
		target_intensity,
		duration
	)
	return tween
