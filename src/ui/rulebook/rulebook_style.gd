class_name RulebookStyle
# 说明书外框的外观:书的页签、章节目录按钮与分隔线。只管样式,不连信号(信号与状态在 Rulebook)。


const TAB_FONT_SIZE := 18
const TAB_RADIUS := 8
const NAV_FONT_SIZE := 19


static func tab(button: Button, first: bool, last: bool) -> void:
	# 连在一起的分段页签:只有两端圆角,相邻页签共用一条边框;正在看的那本黄铜底
	var normal := UiTheme.panel_box(Color(0, 0, 0, 0.25), Color(UiTheme.BRASS, 0.5), 1, 0)
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 5
	normal.content_margin_bottom = 6
	normal.border_width_left = 1 if first else 0
	normal.corner_radius_top_left = TAB_RADIUS if first else 0
	normal.corner_radius_bottom_left = TAB_RADIUS if first else 0
	normal.corner_radius_top_right = TAB_RADIUS if last else 0
	normal.corner_radius_bottom_right = TAB_RADIUS if last else 0
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(UiTheme.BRASS, 0.1)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(UiTheme.BRASS, 0.26)
	pressed.border_color = UiTheme.BRASS_BRIGHT
	var focus: StyleBoxFlat = normal.duplicate()
	focus.draw_center = false
	focus.border_color = Color(UiTheme.BRASS_BRIGHT, 0.7)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_size_override("font_size", TAB_FONT_SIZE)
	button.add_theme_color_override("font_color", UiTheme.PARCHMENT_DIM)
	# 聚焦但没选中的页签不能用主题的亮黄铜字,否则看着像选中了
	button.add_theme_color_override("font_focus_color", UiTheme.PARCHMENT)
	button.add_theme_color_override("font_hover_color", UiTheme.PARCHMENT)
	button.add_theme_color_override("font_pressed_color", UiTheme.BRASS_BRIGHT)
	button.add_theme_color_override("font_hover_pressed_color", UiTheme.BRASS_BRIGHT)


static func nav_button(button: Button) -> void:
	# 章节目录:透明底,选中的一章黄铜底加左边条
	var normal := UiTheme.flat(Color(0, 0, 0, 0), 6)
	normal.content_margin_left = 14
	normal.content_margin_right = 10
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(UiTheme.BRASS, 0.08)
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = Color(UiTheme.BRASS, 0.16)
	pressed.border_color = UiTheme.BRASS_BRIGHT
	pressed.border_width_left = 3
	var focus: StyleBoxFlat = normal.duplicate()
	focus.draw_center = false
	focus.border_color = Color(UiTheme.BRASS_BRIGHT, 0.7)
	focus.set_border_width_all(1)
	for state in ["normal", "disabled"]:
		button.add_theme_stylebox_override(state, normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover_pressed", pressed)
	button.add_theme_stylebox_override("focus", focus)
	button.add_theme_font_size_override("font_size", NAV_FONT_SIZE)
	button.add_theme_color_override("font_color", UiTheme.PARCHMENT_DIM)
	button.add_theme_color_override("font_pressed_color", UiTheme.BRASS_BRIGHT)
	button.add_theme_color_override("font_hover_pressed_color", UiTheme.BRASS_BRIGHT)


static func divider(horizontal: bool) -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(UiTheme.BRASS, 0.35)
	line.custom_minimum_size = Vector2(0, 1) if horizontal else Vector2(1, 0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line
