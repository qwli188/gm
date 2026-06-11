extends HBoxContainer
## 职业资源条组件 - 通用的资源显示条（怒气/法力/精准层数/潜行/圣盾等）
## 可配置颜色、图标、数值范围

## 资源类型配置
enum ResourceType { MANA, RAGE, ENERGY, COMBO, HOLY, CUSTOM }  # 法力（蓝）  # 怒气（红）  # 能量（黄）  # 连击点数（橙）  # 圣盾值（金）  # 自定义

## 配置
@export var resource_type: ResourceType = ResourceType.MANA
@export var resource_name: String = "资源"
@export var custom_color: Color = Color.WHITE
@export var show_label: bool = true
@export var show_percentage: bool = false
@export var bar_height: int = 20
@export var bar_width: int = 200

## 运行时状态
var current_value: float = 0.0
var max_value: float = 100.0

## 节点引用
var label: Label
var progress_bar: ProgressBar


func _ready():
	_setup_ui()
	_apply_style()
	update_display()


## ============ 初始化 ============
func _setup_ui():
	# 清空已有子节点
	for child in get_children():
		child.queue_free()

	# 创建标签（可选）
	if show_label:
		label = Label.new()
		label.text = resource_name
		label.custom_minimum_size = Vector2(60, bar_height)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(label)

	# 创建进度条
	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size = Vector2(bar_width, bar_height)
	progress_bar.max_value = 100.0
	progress_bar.value = 0.0
	progress_bar.show_percentage = show_percentage
	add_child(progress_bar)


## 应用样式（根据资源类型）
func _apply_style():
	if not progress_bar:
		return

	var color = _get_resource_color()
	var bg_style = _create_bg_style()
	var fill_style = _create_fill_style(color)

	progress_bar.add_theme_stylebox_override("background", bg_style)
	progress_bar.add_theme_stylebox_override("fill", fill_style)

	if label:
		label.add_theme_color_override("font_color", color)


## 获取资源颜色
func _get_resource_color() -> Color:
	match resource_type:
		ResourceType.MANA:
			return Color("#3366CC")  # 蓝色
		ResourceType.RAGE:
			return Color("#CC3333")  # 红色
		ResourceType.ENERGY:
			return Color("#CCAA33")  # 黄色
		ResourceType.COMBO:
			return Color("#FF8833")  # 橙色
		ResourceType.HOLY:
			return Color("#FFD700")  # 金色
		ResourceType.CUSTOM:
			return custom_color
		_:
			return Color.WHITE


## 创建背景样式
func _create_bg_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.border_color = Color(0.3, 0.3, 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style


## 创建填充样式
func _create_fill_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style


## ============ 公共接口 ============
## 设置资源值
func set_resource_value(current: float, maximum: float):
	current_value = current
	max_value = maximum
	update_display()


## 更新显示
func update_display():
	if not progress_bar:
		return
	progress_bar.max_value = max_value
	progress_bar.value = current_value

	# 更新标签文本（如果需要）
	if label and not show_percentage:
		if max_value > 0:
			label.text = "%s: %d/%d" % [resource_name, int(current_value), int(max_value)]
		else:
			label.text = "%s: %d" % [resource_name, int(current_value)]


## 设置资源类型（运行时切换）
func set_resource_type(type: ResourceType):
	resource_type = type
	_apply_style()
	update_display()


## 设置自定义颜色
func set_custom_color(color: Color):
	custom_color = color
	if resource_type == ResourceType.CUSTOM:
		_apply_style()


## 设置资源名称
func set_resource_name(name: String):
	resource_name = name
	if label:
		update_display()


## ============ 动画效果 ============
## 闪烁效果（资源变化时）
func flash_effect(duration: float = 0.3):
	if not progress_bar:
		return
	var tween = create_tween()
	var original_color = _get_resource_color()
	var flash_color = original_color.lightened(0.3)

	# 获取当前样式并修改
	var fill_style = progress_bar.get_theme_stylebox("fill")
	if fill_style is StyleBoxFlat:
		tween.tween_property(fill_style, "bg_color", flash_color, duration * 0.5)
		tween.tween_property(fill_style, "bg_color", original_color, duration * 0.5)


## 平滑过渡到新值
func smooth_set_value(target: float, duration: float = 0.2):
	if not progress_bar:
		return
	var tween = create_tween()
	tween.tween_property(progress_bar, "value", target, duration)
	current_value = target
