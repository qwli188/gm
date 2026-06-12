extends Area2D
## 通用交互区域 - 用于场景里"走到附近可交互"的物件
## (副本传送门/领地建筑/野外采集点等)
##
## 用法：场景脚本 new() 一个，setup() 配置图标/标签/数据，连接 interacted 信号。
## 玩家(explorer 组)进入范围 → 浮出名牌 + "[E]" 提示 + 物件轻微放大高亮；
## 玩家在范围内按 E 或左键点击该物件 → 发 interacted(payload)。

signal interacted(payload: Dictionary)

var payload: Dictionary = {}
var _label_text: String = ""
var _sprite: Sprite2D = null
var _name_label: Label = null
var _player_inside: bool = false
var _base_scale: Vector2 = Vector2(1, 1)


## icon_tex: 物件精灵；label: 名牌文字；data: 触发时回传的负载；radius: 交互半径
func setup(icon_tex: Texture2D, label: String, data: Dictionary, radius: float = 70.0) -> void:
	payload = data
	_label_text = label
	input_pickable = true  # 支持左键点击

	# 碰撞形状（圆形交互范围）
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = radius
	col.shape = shape
	add_child(col)

	# 物件精灵
	_sprite = Sprite2D.new()
	if icon_tex:
		_sprite.texture = icon_tex
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(2.2, 2.2)
	_base_scale = _sprite.scale
	add_child(_sprite)

	# 名牌（默认隐藏，靠近才显示）
	_name_label = Label.new()
	_name_label.text = label
	_name_label.position = Vector2(-50, -64)
	_name_label.custom_minimum_size = Vector2(100, 0)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	_name_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.visible = false
	add_child(_name_label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	input_event.connect(_on_input_event)


func _process(_delta):
	# 玩家在范围内时按 E 触发
	if _player_inside and Input.is_action_just_pressed("interact"):
		_fire()


func _on_body_entered(body):
	if body.is_in_group("explorer"):
		_player_inside = true
		if _name_label:
			_name_label.text = "%s  [E]" % _label_text
			_name_label.visible = true
		if _sprite:
			_sprite.scale = _base_scale * 1.15  # 高亮放大


func _on_body_exited(body):
	if body.is_in_group("explorer"):
		_player_inside = false
		if _name_label:
			_name_label.visible = false
		if _sprite:
			_sprite.scale = _base_scale


## 左键点击物件：仅当玩家已在范围内才触发（避免隔屏点击）
func _on_input_event(_viewport, event, _shape_idx):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _player_inside:
			_fire()


func _fire():
	interacted.emit(payload)


## 触发后移除该交互点（采集/开箱后消失）
func consume():
	queue_free()
