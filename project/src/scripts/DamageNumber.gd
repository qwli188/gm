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
const DURATION := 1.0
var _is_crit: bool = false
var _bounce_tween: Tween
var _is_heal: bool = false

## 累计伤害更新：FeedbackSystem 0.3s 窗口内的同目标伤害合并
func update_amount(new_amount: float, is_crit: bool):
	if _label == null:
		return
	_is_crit = _is_crit or is_crit
	_life = max(0.0, _life - 0.3)  # 重置部分生命，使飘字续命
	_label.text = ("+" if _is_heal else "") + str(int(round(new_amount)))
	if _is_crit:
		_label.text += "!"
		_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		_label.add_theme_font_size_override("font_size", 42)
	# 弹一下表示又被打了
	if _bounce_tween:
		_bounce_tween.kill()
	_bounce_tween = create_tween()
	_label.scale = Vector2(1.3, 1.3)
	_bounce_tween.tween_property(_label, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _setup(amount: float, is_crit: bool, is_heal: bool) -> void:
	_is_crit = is_crit
	_is_heal = is_heal
	_label = Label.new()
	_label.text = ("+" if is_heal else "") + str(int(round(amount)))
	var color := Color(1, 1, 1)
	var fsize := 22
	if is_heal:
		color = Color(0.4, 1.0, 0.4)
		fsize = 24
	elif is_crit:
		color = Color(1.0, 0.85, 0.2)
		fsize = 42  # 暴击更大
		_label.text += "!"
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_label.add_theme_constant_override("outline_size", 4)
	_label.add_theme_font_size_override("font_size", fsize)
	_label.position = Vector2(-30, -20)
	_label.z_index = 100
	add_child(_label)

	# 随机水平偏移
	position.x += randf_range(-15, 15)

	# 弹跳动画: scale从1.5挤压到1.0,增强打击感
	_label.scale = Vector2(1.5, 1.5)
	_bounce_tween = create_tween()
	_bounce_tween.tween_property(_label, "scale", Vector2(1.0, 1.0), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# 暴击额外弹跳一次(连续两段弹跳)
	if is_crit:
		_bounce_tween.tween_property(_label, "scale", Vector2(1.1, 1.1), 0.08)
		_bounce_tween.tween_property(_label, "scale", Vector2(1.0, 1.0), 0.08)

func _process(delta: float) -> void:
	_life += delta
	var t := _life / DURATION

	# 上浮速度: 前半程快,后半程慢(二次缓动)
	var rise_speed = 80.0 * (1.0 - t)
	position.y -= rise_speed * delta

	# 淡出: 前60%保持不透明,后40%快速淡出
	if _label:
		if t < 0.6:
			_label.modulate.a = 1.0
		else:
			var fade_t = (t - 0.6) / 0.4
			_label.modulate.a = 1.0 - fade_t

	if _life >= DURATION:
		queue_free()
