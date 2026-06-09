extends Node
## UI主题生成器 - 生成统一的暗色奇幻风主题
## 使用代码生成 Theme 资源，避免依赖编辑器手动操作

## 主题色调
const COLOR_BG_DARK = Color("#1A1A1A")       # 主背景（深黑）
const COLOR_BG_PANEL = Color("#242424")      # 面板背景（深灰）
const COLOR_BG_INPUT = Color("#2A2A2A")      # 输入框背景
const COLOR_BG_BUTTON = Color("#3A3A3A")     # 按钮默认
const COLOR_BG_BUTTON_HOVER = Color("#4A4A4A")  # 按钮悬停
const COLOR_BG_BUTTON_PRESSED = Color("#2A2A2A") # 按钮按下

const COLOR_BORDER = Color("#555555")        # 边框颜色
const COLOR_BORDER_FOCUS = Color("#888888")  # 聚焦边框

const COLOR_TEXT_PRIMARY = Color("#EEEEEE")  # 主文本（亮白）
const COLOR_TEXT_SECONDARY = Color("#AAAAAA") # 次要文本（灰）
const COLOR_TEXT_DISABLED = Color("#666666")  # 禁用文本

const COLOR_ACCENT = Color("#E8A317")        # 强调色（金色）
const COLOR_ACCENT_HOVER = Color("#FFC840")  # 强调色悬停

## 字体大小
const FONT_SIZE_TITLE = 28
const FONT_SIZE_SUBTITLE = 20
const FONT_SIZE_NORMAL = 16
const FONT_SIZE_SMALL = 14
const FONT_SIZE_TINY = 12

## 间距
const MARGIN_NORMAL = 8
const MARGIN_LARGE = 16
const PADDING_BUTTON = 8

## 生成的主题实例（单例）
var main_theme: Theme = null

func _ready():
	print("[ThemeGenerator] 初始化主题生成器")
	main_theme = generate_theme()

## ============ 主题生成 ============
## 生成完整主题
func generate_theme() -> Theme:
	var theme = Theme.new()

	# Panel 样式
	theme.set_stylebox("panel", "Panel", _create_panel_style())
	theme.set_stylebox("panel", "PanelContainer", _create_panel_style())

	# Button 样式
	theme.set_stylebox("normal", "Button", _create_button_style(COLOR_BG_BUTTON))
	theme.set_stylebox("hover", "Button", _create_button_style(COLOR_BG_BUTTON_HOVER))
	theme.set_stylebox("pressed", "Button", _create_button_style(COLOR_BG_BUTTON_PRESSED))
	theme.set_stylebox("disabled", "Button", _create_button_style(COLOR_BG_BUTTON, 0.5))
	theme.set_color("font_color", "Button", COLOR_TEXT_PRIMARY)
	theme.set_color("font_hover_color", "Button", COLOR_ACCENT_HOVER)
	theme.set_color("font_pressed_color", "Button", COLOR_TEXT_PRIMARY)
	theme.set_color("font_disabled_color", "Button", COLOR_TEXT_DISABLED)
	theme.set_font_size("font_size", "Button", FONT_SIZE_NORMAL)

	# Label 样式
	theme.set_color("font_color", "Label", COLOR_TEXT_PRIMARY)
	theme.set_font_size("font_size", "Label", FONT_SIZE_NORMAL)

	# RichTextLabel 样式
	theme.set_color("default_color", "RichTextLabel", COLOR_TEXT_PRIMARY)
	theme.set_font_size("normal_font_size", "RichTextLabel", FONT_SIZE_NORMAL)

	# ProgressBar 样式
	theme.set_stylebox("background", "ProgressBar", _create_progress_bg())
	theme.set_stylebox("fill", "ProgressBar", _create_progress_fill())

	# LineEdit 样式
	theme.set_stylebox("normal", "LineEdit", _create_input_style())
	theme.set_stylebox("focus", "LineEdit", _create_input_style_focus())
	theme.set_color("font_color", "LineEdit", COLOR_TEXT_PRIMARY)
	theme.set_font_size("font_size", "LineEdit", FONT_SIZE_NORMAL)

	# ScrollContainer 样式
	theme.set_stylebox("panel", "ScrollContainer", _create_transparent_style())

	# VBoxContainer/HBoxContainer 间距
	theme.set_constant("separation", "VBoxContainer", MARGIN_NORMAL)
	theme.set_constant("separation", "HBoxContainer", MARGIN_NORMAL)

	# Tooltip 样式
	theme.set_stylebox("panel", "TooltipPanel", _create_tooltip_style())
	theme.set_color("font_color", "TooltipLabel", COLOR_TEXT_PRIMARY)
	theme.set_font_size("font_size", "TooltipLabel", FONT_SIZE_SMALL)

	# PopupMenu 样式
	theme.set_stylebox("panel", "PopupMenu", _create_panel_style())
	theme.set_stylebox("hover", "PopupMenu", _create_button_style(COLOR_BG_BUTTON_HOVER))
	theme.set_color("font_color", "PopupMenu", COLOR_TEXT_PRIMARY)
	theme.set_color("font_hover_color", "PopupMenu", COLOR_ACCENT_HOVER)
	theme.set_font_size("font_size", "PopupMenu", FONT_SIZE_NORMAL)

	print("[ThemeGenerator] 主题生成完成")
	return theme

## ============ StyleBox 生成器 ============
## Panel 样式（深色背景 + 边框）
func _create_panel_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_PANEL
	style.border_color = COLOR_BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(MARGIN_NORMAL)
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 4
	return style

## Button 样式
func _create_button_style(bg_color: Color, alpha: float = 1.0) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.bg_color.a = alpha
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = PADDING_BUTTON
	style.content_margin_right = PADDING_BUTTON
	style.content_margin_top = PADDING_BUTTON
	style.content_margin_bottom = PADDING_BUTTON
	return style

## 输入框样式
func _create_input_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_INPUT
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(MARGIN_NORMAL)
	return style

## 输入框聚焦样式
func _create_input_style_focus() -> StyleBoxFlat:
	var style = _create_input_style()
	style.border_color = COLOR_BORDER_FOCUS
	style.set_border_width_all(2)
	return style

## ProgressBar 背景
func _create_progress_bg() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
	style.border_color = COLOR_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	return style

## ProgressBar 填充（通用，可在运行时覆盖颜色）
func _create_progress_fill() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#44AA44")  # 默认绿色
	style.set_corner_radius_all(2)
	return style

## Tooltip 样式
func _create_tooltip_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.95)
	style.border_color = COLOR_ACCENT
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(MARGIN_NORMAL)
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 6
	return style

## 透明样式（ScrollContainer 等）
func _create_transparent_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.draw_center = false
	return style

## ============ 特殊样式生成 ============
## 生成血条样式（红色渐变）
func create_health_bar_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#CC3333")
	style.set_corner_radius_all(2)
	return style

## 生成法力条样式（蓝色渐变）
func create_mana_bar_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#3366CC")
	style.set_corner_radius_all(2)
	return style

## 生成经验条样式（金色渐变）
func create_exp_bar_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_ACCENT
	style.set_corner_radius_all(2)
	return style

## 生成职业资源条样式（可自定义颜色）
func create_class_resource_bar_style(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style

## ============ 应用主题到节点 ============
## 应用主题到节点（递归）
func apply_theme_to_node(node: Node):
	if node is Control:
		node.theme = main_theme
	for child in node.get_children():
		apply_theme_to_node(child)

## ============ 工具函数 ============
## 创建带样式的 Panel
func create_styled_panel() -> Panel:
	var panel = Panel.new()
	panel.add_theme_stylebox_override("panel", _create_panel_style())
	return panel

## 创建带样式的 Button
func create_styled_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.theme = main_theme
	return btn

## 创建标题 Label
func create_title_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE_TITLE)
	label.add_theme_color_override("font_color", COLOR_ACCENT)
	return label

## 创建副标题 Label
func create_subtitle_label(text: String) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", FONT_SIZE_SUBTITLE)
	label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	return label

## 获取主题（供外部调用）
func get_main_theme() -> Theme:
	if main_theme == null:
		main_theme = generate_theme()
	return main_theme
