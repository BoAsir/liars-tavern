extends RefCounted
# 主菜单「开一桌」标题行上的玩法三段切换:互斥的小号切换按钮,按 GameMode.ALL 的顺序排、预选传入的玩法。
# 挤在标题行里不另占一行(1280×720 下面板不用滚动),所以每种状态的样式都换成小内边距:
# 按钮的最小尺寸取各状态样式里最大的那个。切到别的玩法回调 on_select(mode),被挤掉的按钮不回调。


const FONT_SIZE := 15
const PADDING := Vector2(10, 4)   # 左右, 上下
const BORDER_WIDTH := 1
const RADIUS := 6
const FOCUS_RING_WIDTH := 2
const FOCUS_RING_EXPAND := 2

# 没选中的暗木底细描边,选中的用主按钮的酒红底;不要投影,挤在标题行里不显脏
const NORMAL_BG := Color(0.16, 0.11, 0.07)
const HOVER_BG := Color(0.26, 0.17, 0.09)
const PRESSED_BG := Color(0.42, 0.09, 0.08)
const HOVER_PRESSED_BG := Color(0.58, 0.13, 0.1)
const DISABLED_BG := Color(0.1, 0.08, 0.07, 0.8)
const NORMAL_BORDER_ALPHA := 0.45
const DISABLED_BORDER_ALPHA := 0.3


static func build(selected: String, on_select: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var group := ButtonGroup.new()
	for mode in GameMode.ALL:
		row.add_child(_button(mode, group, mode == selected, on_select))
	return row


static func _button(mode: String, group: ButtonGroup, pressed: bool, on_select: Callable) -> Button:
	var button := Button.new()
	button.text = GameMode.short_label(mode)
	button.tooltip_text = GameMode.summary(mode)
	button.toggle_mode = true
	button.button_group = group
	button.button_pressed = pressed
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", FONT_SIZE)
	_style(button)
	button.toggled.connect(func(on: bool):
		if on:
			on_select.call(mode))
	return button


static func _style(button: Button) -> void:
	var states := {
		"normal": [NORMAL_BG, Color(UiTheme.BRASS, NORMAL_BORDER_ALPHA)],
		"hover": [HOVER_BG, UiTheme.BRASS_BRIGHT],
		"pressed": [PRESSED_BG, UiTheme.BRASS_BRIGHT],
		"hover_pressed": [HOVER_PRESSED_BG, UiTheme.BRASS_BRIGHT],
		"disabled": [DISABLED_BG, Color(UiTheme.BRASS, DISABLED_BORDER_ALPHA)],
		"focus": [Color.TRANSPARENT, UiTheme.BRASS_BRIGHT],
	}
	for state: String in states:
		var box := UiTheme.panel_box(states[state][0], states[state][1], BORDER_WIDTH, RADIUS)
		box.content_margin_left = PADDING.x
		box.content_margin_right = PADDING.x
		box.content_margin_top = PADDING.y
		box.content_margin_bottom = PADDING.y
		if state == "focus":
			_as_focus_ring(box)
		button.add_theme_stylebox_override(state, box)
	button.add_theme_color_override("font_color", UiTheme.PARCHMENT_DIM)
	button.add_theme_color_override("font_pressed_color", UiTheme.PARCHMENT)
	button.add_theme_color_override("font_hover_pressed_color", UiTheme.PARCHMENT)


static func _as_focus_ring(box: StyleBoxFlat) -> void:
	# 键盘焦点只画一圈亮黄铜框,略向外扩,压在选中/悬停的底色上也看得见
	box.draw_center = false
	box.set_border_width_all(FOCUS_RING_WIDTH)
	box.expand_margin_left = FOCUS_RING_EXPAND
	box.expand_margin_right = FOCUS_RING_EXPAND
	box.expand_margin_top = FOCUS_RING_EXPAND
	box.expand_margin_bottom = FOCUS_RING_EXPAND
