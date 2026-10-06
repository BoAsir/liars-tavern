class_name UiTheme
# 界面设计令牌:配色、字体、按钮/面板/输入框样式。所有屏幕共用一个 Theme。
# 风格:暗木酒馆 + 黄铜描边 + 羊皮纸文字;"真/假"语义色用于翻牌判定。


const INK := Color(0.07, 0.05, 0.04)
const PANEL := Color(0.09, 0.065, 0.05, 0.9)
const PANEL_SOFT := Color(0.09, 0.065, 0.05, 0.72)
const PARCHMENT := Color(0.93, 0.86, 0.72)
const PARCHMENT_DIM := Color(0.72, 0.64, 0.52)
const BRASS := Color(0.82, 0.62, 0.28)
const BRASS_BRIGHT := Color(1.0, 0.8, 0.42)
const BLOOD := Color(0.86, 0.22, 0.16)
const TRUTH := Color(0.42, 0.86, 0.48)
const LIE := Color(0.95, 0.3, 0.22)
const MUTED := Color(0.55, 0.5, 0.45)

const SCROLLBAR_WIDTH := 6.0

const FONT_TITLE_NAMES := ["Xingkai SC", "STXingkai", "Weibei SC", "STKaiti", "KaiTi", "Kaiti SC", "serif"]
const FONT_DISPLAY_NAMES := ["Weibei SC", "STKaiti", "Kaiti SC", "KaiTi", "Songti SC", "SimSun", "serif"]
const FONT_BODY_NAMES := ["PingFang SC", "Hiragino Sans GB", "Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"]
const FONT_LATIN_NAMES := ["Big Caslon", "Bodoni 72", "Didot", "Georgia", "Times New Roman", "serif"]

static var _theme: Theme = null
static var _fonts := {}


static func clear_cache() -> void:
	_theme = null
	_fonts = {}


static func title_font() -> Font:
	return _font("title", FONT_TITLE_NAMES, 400)


static func display_font() -> Font:
	return _font("display", FONT_DISPLAY_NAMES, 700)


static func body_font() -> Font:
	return _font("body", FONT_BODY_NAMES, 400)


static func latin_font() -> Font:
	return _font("latin", FONT_LATIN_NAMES, 700)


static func theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	_theme.default_font = body_font()
	_theme.default_font_size = 18
	_theme.set_color("font_color", "Label", PARCHMENT)
	_theme.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	_theme.set_constant("shadow_offset_x", "Label", 1)
	_theme.set_constant("shadow_offset_y", "Label", 2)
	_button_styles()
	_input_styles()
	_theme.set_stylebox("panel", "PanelContainer", panel_box(PANEL, BRASS, 2, 10))
	_theme.set_stylebox("panel", "Panel", panel_box(PANEL, BRASS, 2, 10))
	# 滚动条要有宽度:平面样式默认没有内容边距,宽度会是 0,列表能滚却看不见滚动条
	_theme.set_stylebox("grabber", "VScrollBar", _scroll_part(Color(BRASS, 0.5)))
	_theme.set_stylebox("grabber_highlight", "VScrollBar", _scroll_part(BRASS))
	_theme.set_stylebox("grabber_pressed", "VScrollBar", _scroll_part(BRASS_BRIGHT))
	_theme.set_stylebox("scroll", "VScrollBar", _scroll_part(Color(0, 0, 0, 0.25)))
	_theme.set_color("font_color", "TooltipLabel", PARCHMENT)
	_theme.set_stylebox("panel", "TooltipPanel", panel_box(INK, BRASS, 1, 6))
	return _theme


static func _button_styles() -> void:
	var normal := panel_box(Color(0.16, 0.11, 0.07), BRASS, 2, 8)
	normal.shadow_color = Color(0, 0, 0, 0.5)
	normal.shadow_size = 6
	normal.shadow_offset = Vector2(0, 3)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(0.26, 0.17, 0.09)
	hover.border_color = BRASS_BRIGHT
	hover.shadow_size = 10
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(0.1, 0.07, 0.05)
	pressed.shadow_size = 2
	pressed.shadow_offset = Vector2(0, 1)
	var disabled: StyleBoxFlat = normal.duplicate()
	disabled.bg_color = Color(0.1, 0.08, 0.07, 0.8)
	disabled.border_color = Color(BRASS, 0.3)
	disabled.shadow_size = 0
	var focus: StyleBoxFlat = normal.duplicate()
	focus.draw_center = false
	focus.border_color = BRASS_BRIGHT
	focus.set_border_width_all(2)
	focus.expand_margin_left = 3
	focus.expand_margin_right = 3
	focus.expand_margin_top = 3
	focus.expand_margin_bottom = 3
	_theme.set_stylebox("normal", "Button", normal)
	_theme.set_stylebox("hover", "Button", hover)
	_theme.set_stylebox("pressed", "Button", pressed)
	_theme.set_stylebox("hover_pressed", "Button", pressed)
	_theme.set_stylebox("disabled", "Button", disabled)
	_theme.set_stylebox("focus", "Button", focus)
	_theme.set_color("font_color", "Button", PARCHMENT)
	_theme.set_color("font_hover_color", "Button", BRASS_BRIGHT)
	_theme.set_color("font_pressed_color", "Button", BRASS)
	_theme.set_color("font_hover_pressed_color", "Button", BRASS_BRIGHT)
	_theme.set_color("font_disabled_color", "Button", Color(PARCHMENT, 0.35))
	_theme.set_color("font_focus_color", "Button", BRASS_BRIGHT)
	_theme.set_font("font", "Button", display_font())
	_theme.set_font_size("font_size", "Button", 22)


static func _input_styles() -> void:
	var box := panel_box(Color(0.04, 0.03, 0.025, 0.85), Color(BRASS, 0.55), 1, 6)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	var focus: StyleBoxFlat = box.duplicate()
	focus.border_color = BRASS_BRIGHT
	focus.set_border_width_all(2)
	_theme.set_stylebox("normal", "LineEdit", box)
	_theme.set_stylebox("focus", "LineEdit", focus)
	_theme.set_stylebox("read_only", "LineEdit", box)
	_theme.set_color("font_color", "LineEdit", PARCHMENT)
	_theme.set_color("font_placeholder_color", "LineEdit", Color(PARCHMENT, 0.35))
	_theme.set_color("caret_color", "LineEdit", BRASS_BRIGHT)
	_theme.set_color("selection_color", "LineEdit", Color(BRASS, 0.35))


static func panel_box(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 18
	box.content_margin_right = 18
	box.content_margin_top = 14
	box.content_margin_bottom = 14
	box.anti_aliasing = true
	return box


static func screen_panel(bg_alpha: float, margins: Vector2, border := Color(BRASS, 0.7)) -> StyleBoxFlat:
	# 屏幕主面板(主菜单 / 等待厅 / 结算):暗木底 + 黄铜描边 + 柔和投影;margins = (左右, 上下)
	var box := panel_box(Color(INK, bg_alpha), border, 2, 14)
	box.content_margin_left = margins.x
	box.content_margin_right = margins.x
	box.content_margin_top = margins.y
	box.content_margin_bottom = margins.y
	box.shadow_color = Color(0, 0, 0, 0.55)
	box.shadow_size = 24
	return box


static func side_column(host: Control, at_right: bool, side_margin: int, edge_margin: int) -> VBoxContainer:
	# 屏幕侧边面板的外框:贴左/右边、竖直居中;窗口放不下时整列滚动,底部的控件永远不会被裁掉。
	# 返回的列里放面板;列的父节点就是 ScrollContainer
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_right" if at_right else "margin_left", side_margin)
	margin.add_theme_constant_override("margin_top", edge_margin)
	margin.add_theme_constant_override("margin_bottom", edge_margin)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_SHRINK_END if at_right else Control.SIZE_SHRINK_BEGIN
	scroll.follow_focus = true
	scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	# 不裁剪:面板投影与入场滑动都会超出滚动区;真放不下而滚动时,多出的部分只会画进上下留白
	scroll.clip_contents = false
	margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll.add_child(column)
	return column


static func flat(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	return box


static func _scroll_part(color: Color) -> StyleBoxFlat:
	var box := flat(color, 4)
	box.content_margin_left = SCROLLBAR_WIDTH / 2.0
	box.content_margin_right = SCROLLBAR_WIDTH / 2.0
	return box


static func label(text: String, size := 18, color := PARCHMENT, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


static func button(text: String, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if primary:
		var normal: StyleBoxFlat = theme().get_stylebox("normal", "Button").duplicate()
		normal.bg_color = Color(0.42, 0.09, 0.08)
		normal.border_color = BRASS_BRIGHT
		var hover: StyleBoxFlat = theme().get_stylebox("hover", "Button").duplicate()
		hover.bg_color = Color(0.58, 0.13, 0.1)
		b.add_theme_stylebox_override("normal", normal)
		b.add_theme_stylebox_override("hover", hover)
	return b


static func _font(key: String, names: Array, weight: int) -> Font:
	if not _fonts.has(key):
		var font := SystemFont.new()
		font.font_names = PackedStringArray(names)
		font.font_weight = weight
		_fonts[key] = font
	return _fonts[key]
