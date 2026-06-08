extends Node2D
class_name DamageNumber
## 漂浮伤害数字 - 显示后上浮淡出并销毁
## 用法: DamageNumber.spawn(parent, pos, amount, is_crit)

static func spawn(parent: Node, pos: Vector2, amount: float, is_crit: bool = false, is_heal: bool = false) -> void:
	var node := Node2D.new()
	node.set_script(load("res://scripts/DamageNumber.gd"))
	node.global_position = pos
	parent.add_child(node)
	node._setup(amount, is_crit, is_heal)

var _label: Label
var _life: float = 0.0
const DURATION := 0.8

func _setup(amount: float, is_crit: bool, is_heal: bool) -> void:
	_label = Label.new()
	_label.text = ("+" if is_heal else "") + str(int(round(amount)))
	var color := Color(1, 1, 1)
	var fsize := 22
	if is_heal:
		color = Color(0.4, 1.0, 0.4)
	elif is_crit:
		color = Color(1.0, 0.85, 0.2)
		fsize = 34
		_label.text += "!"
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_font_size_override("font_size", fsize)
	_label.position = Vector2(-20, -20)
	_label.z_index = 100
	add_child(_label)
	# 随机水平偏移
	position.x += randf_range(-12, 12)

func _process(delta: float) -> void:
	_life += delta
	var t := _life / DURATION
	position.y -= 60 * delta
	if _label:
		_label.modulate.a = 1.0 - t
	if _life >= DURATION:
		queue_free()
