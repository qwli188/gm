extends Node
class_name ShaderHelper
## Shader 效果工具类 - 封装常用 shader 调用，简化使用
## 用法: ShaderHelper.apply_hit_flash(sprite, Color.RED, 0.8)

# ============ 稀有度描边发光 ============

## 应用稀有度描边（给装备图标/掉落物）
## rarity: "common"|"rare"|"epic"|"legendary"|"mythic"（见 Schema.RARITIES）
static func apply_rarity_glow(node: CanvasItem, rarity: String) -> void:
	var shader := load("res://shaders/rarity_outline.gdshader") as Shader
	if not shader:
		push_error("ShaderHelper: rarity_outline.gdshader not found")
		return

	var mat := ShaderMaterial.new()
	mat.shader = shader

	# 根据稀有度设置颜色和强度
	match rarity.to_lower():
		"common":
			mat.set_shader_parameter("outline_color", Color(0.5, 0.5, 0.5))
			mat.set_shader_parameter("outline_width", 1.0)
			mat.set_shader_parameter("glow_intensity", 0.0)
		"rare":
			mat.set_shader_parameter("outline_color", Color(0.3, 0.5, 1.0))
			mat.set_shader_parameter("outline_width", 2.0)
			mat.set_shader_parameter("glow_intensity", 0.5)
		"epic":
			mat.set_shader_parameter("outline_color", Color(0.6, 0.3, 0.9))
			mat.set_shader_parameter("outline_width", 2.0)
			mat.set_shader_parameter("glow_intensity", 0.8)
		"legendary":
			mat.set_shader_parameter("outline_color", Color(1.0, 0.6, 0.0))
			mat.set_shader_parameter("outline_width", 2.5)
			mat.set_shader_parameter("glow_intensity", 1.5)
			mat.set_shader_parameter("pulse_speed", 2.5)
		"mythic":
			mat.set_shader_parameter("outline_color", Color(1.0, 0.2, 0.3))
			mat.set_shader_parameter("outline_width", 3.0)
			mat.set_shader_parameter("glow_intensity", 2.0)
			mat.set_shader_parameter("pulse_speed", 3.5)
		_:
			push_warning("ShaderHelper: unknown rarity '%s', using common" % rarity)
			mat.set_shader_parameter("outline_color", Color(0.5, 0.5, 0.5))
			mat.set_shader_parameter("outline_width", 1.0)

	node.material = mat

# ============ 受击闪白 ============

## 应用受击闪白（替代 modulate）
## duration: 闪白持续时间（秒）
## flash_color: 闪烁颜色（默认白色）
static func apply_hit_flash(node: CanvasItem, flash_color: Color = Color.WHITE, duration: float = 0.15) -> void:
	var shader := load("res://shaders/hit_flash.gdshader") as Shader
	if not shader:
		push_error("ShaderHelper: hit_flash.gdshader not found")
		return

	# 如果已有 ShaderMaterial 且是 hit_flash，复用；否则创建新的
	var mat: ShaderMaterial
	if node.material and node.material is ShaderMaterial and (node.material as ShaderMaterial).shader == shader:
		mat = node.material as ShaderMaterial
	else:
		mat = ShaderMaterial.new()
		mat.shader = shader
		node.material = mat

	mat.set_shader_parameter("flash_color", flash_color)

	# Tween 动画: flash_amount 0→1→0
	var tween := node.create_tween()
	tween.tween_method(
		func(val: float): mat.set_shader_parameter("flash_amount", val),
		0.0, 1.0, duration * 0.4
	)
	tween.tween_method(
		func(val: float): mat.set_shader_parameter("flash_amount", val),
		1.0, 0.0, duration * 0.6
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
		"freeze": status_type = 1
		"poison": status_type = 2
		"ignite": status_type = 3
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
static func apply_dissolve(node: CanvasItem, direction: String = "out", duration: float = 1.2, edge_color: Color = Color(1.0, 0.5, 0.0)) -> Tween:
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
		start_val, end_val, duration
	)
	return tween

# ============ 暗角/氛围 ============

## 创建全屏暗角（需要一个 ColorRect 节点覆盖全屏）
## parent: 要添加暗角的父节点（通常是 CanvasLayer）
## intensity: 暗角强度
## color: 暗角颜色
static func create_vignette(parent: Node, intensity: float = 0.6, vignette_color: Color = Color.BLACK) -> ColorRect:
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
static func tween_vignette_intensity(vignette: ColorRect, target_intensity: float, duration: float = 1.0) -> Tween:
	if not vignette or not vignette.material or not vignette.material is ShaderMaterial:
		push_error("ShaderHelper: invalid vignette node")
		return null

	var mat := vignette.material as ShaderMaterial
	var current := mat.get_shader_parameter("vignette_intensity") as float
	var tween := vignette.create_tween()
	tween.tween_method(
		func(val: float): mat.set_shader_parameter("vignette_intensity", val),
		current, target_intensity, duration
	)
	return tween
