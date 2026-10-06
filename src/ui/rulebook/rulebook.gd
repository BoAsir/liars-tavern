class_name Rulebook
extends ColorRect
# 说明书:模态遮罩 + 书本式面板。左侧章节目录,右侧正文(可滚动),底部翻页。
# 对局中打开不会暂停游戏;遮罩吞掉鼠标与未处理的按键,避免误触牌桌快捷键。
# F1 / Esc / 点遮罩 / 「合上」关闭;← → 或 PageUp/PageDown 翻页。


signal closed

const HOTKEY := RulebookContent.HOTKEY
const PANEL_SIZE := Vector2(980, 600)      # 最小尺寸;高度随窗口放大到 PANEL_MAX_HEIGHT
const PANEL_MAX_HEIGHT := 760.0
const PANEL_MARGIN := 40.0
const NAV_WIDTH := 200.0
const NUMERALS := ["壹", "贰", "叁", "肆", "伍", "陆", "柒", "捌", "玖", "拾"]

var _in_match := false
var _sections: Array[Dictionary] = []
var _current := -1
var _closing := false
var _panel: PanelContainer
var _nav_buttons: Array[Button] = []
var _number: Label
var _title: Label
var _tagline: Label
var _scroll: ScrollContainer
var _content: VBoxContainer
var _page_label: Label
var _prev: Button
var _next: Button
var _fade: Tween = null
var _previous_focus: Control = null


func _init(in_match := false) -> void:
	_in_match = in_match


func _ready() -> void:
	_sections = RulebookContent.sections()
	color = Color(0, 0, 0, 0.6)
	# 已在树内:必须连同偏移一起重置,只设锚点会保留当前的零尺寸矩形
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_fit_panel)
	_fit_panel()
	show_section(0)
	# 接管键盘焦点:否则背后聚焦的控件(昵称框、结算按钮、确认框)仍会收到按键;合上时归还
	_previous_focus = get_viewport().gui_get_focus_owner()
	_nav_buttons[_current].grab_focus()
	_play_open()


func current_section() -> int:
	return _current


func show_section(index: int) -> void:
	if index == _current or index < 0 or index >= _sections.size():
		return
	_current = index
	var section := _sections[index]
	_number.text = NUMERALS[index] if index < NUMERALS.size() else str(index + 1)
	_title.text = section["title"]
	_tagline.text = section.get("tagline", "")
	for child in _content.get_children():
		child.free()  # 立即释放:正文里没有会触发翻页的控件,不必等到帧末
	for block in section["blocks"]:
		_content.add_child(RulebookBlocks.build(block))
	_scroll.scroll_vertical = 0
	for i in _nav_buttons.size():
		_nav_buttons[i].set_pressed_no_signal(i == index)
	var focused := get_viewport().gui_get_focus_owner()
	if focused is Button and focused in _nav_buttons:  # 先判类型:类型化数组查找别的控件会报错
		_nav_buttons[index].grab_focus()
	_page_label.text = "%d / %d" % [index + 1, _sections.size()]
	_prev.disabled = index == 0
	_next.disabled = index == _sections.size() - 1
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_content.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(_content, "modulate:a", 1.0, 0.22)


func turn_page(step: int) -> void:
	var target := clampi(_current + step, 0, _sections.size() - 1)
	if target != _current:
		Sfx.play("flip")
		show_section(target)


func close() -> void:
	if _closing:
		return
	_closing = true
	Sfx.play("ui_click")
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	else:
		get_viewport().gui_release_focus()
	closed.emit()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.15)
	tween.tween_callback(queue_free)


# —— 输入 ——

func _input(event: InputEvent) -> void:
	# 先于 GUI 焦点导航处理:关闭与翻页
	if _closing:
		return
	if event.is_action_pressed("ui_cancel") or _is_key(event, HOTKEY):
		get_viewport().set_input_as_handled()
		close()
	elif _is_key(event, KEY_RIGHT) or _is_key(event, KEY_PAGEDOWN):
		get_viewport().set_input_as_handled()
		turn_page(1)
	elif _is_key(event, KEY_LEFT) or _is_key(event, KEY_PAGEUP):
		get_viewport().set_input_as_handled()
		turn_page(-1)


func _unhandled_input(event: InputEvent) -> void:
	# 说明书在最上层:按钮没用到的按键一律吞掉,牌桌的选牌/出牌/质疑快捷键不会在背后生效。
	# 合上的淡出期间也继续吞,连按两下 Esc 不会漏到牌桌弹出「离开」确认
	if event is InputEventKey:
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	# 面板会拦下自己范围内的点击,能到这里的是遮罩空白处
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		close()


static func is_hotkey(event: InputEvent) -> bool:
	return _is_key(event, HOTKEY)


static func _is_key(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == keycode


# —— 布局 ——

func _build() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = PANEL_SIZE
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := UiTheme.panel_box(Color(0.07, 0.05, 0.04, 0.96), Color(UiTheme.BRASS, 0.75), 2, 14)
	style.content_margin_left = 32
	style.content_margin_right = 32
	style.content_margin_top = 22
	style.content_margin_bottom = 20
	style.shadow_color = Color(0, 0, 0, 0.6)
	style.shadow_size = 30
	_panel.add_theme_stylebox_override("panel", style)
	_panel.resized.connect(func(): _panel.pivot_offset = _panel.size / 2.0)
	center.add_child(_panel)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	_panel.add_child(root)
	root.add_child(_build_header())
	root.add_child(_rule(true))
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 26)
	root.add_child(body)
	body.add_child(_build_nav())
	body.add_child(_rule(false))
	body.add_child(_build_page())
	root.add_child(_rule(true))
	root.add_child(_build_footer())


func _fit_panel() -> void:
	var height := clampf(size.y - PANEL_MARGIN * 2.0, PANEL_SIZE.y, PANEL_MAX_HEIGHT)
	_panel.custom_minimum_size = Vector2(PANEL_SIZE.x, height)


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var title := UiTheme.label("酒馆规矩", 42, UiTheme.BRASS_BRIGHT, UiTheme.title_font())
	title.add_theme_color_override("font_shadow_color", Color(0.35, 0.05, 0.03, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 3)
	row.add_child(title)
	var subtitle := UiTheme.label("HOUSE  RULES   ·   游戏说明书", 15, UiTheme.PARCHMENT_DIM, UiTheme.latin_font())
	subtitle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subtitle.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(subtitle)
	var close_button := UiTheme.button("合上")
	close_button.add_theme_font_size_override("font_size", 17)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.pressed.connect(close)
	row.add_child(close_button)
	return row


func _build_nav() -> Control:
	var nav := VBoxContainer.new()
	nav.custom_minimum_size.x = NAV_WIDTH
	nav.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for i in _sections.size():
		var numeral: String = NUMERALS[i] if i < NUMERALS.size() else str(i + 1)
		var button := Button.new()
		button.text = "%s   %s" % [numeral, _sections[i]["title"]]
		button.toggle_mode = true
		button.button_group = group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_nav_button(button)
		button.pressed.connect(func():
			Sfx.play("flip")
			show_section(i))
		button.mouse_entered.connect(Sfx.play.bind("ui_hover"))
		nav.add_child(button)
		_nav_buttons.append(button)
	return nav


func _style_nav_button(button: Button) -> void:
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
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", UiTheme.PARCHMENT_DIM)
	button.add_theme_color_override("font_pressed_color", UiTheme.BRASS_BRIGHT)
	button.add_theme_color_override("font_hover_pressed_color", UiTheme.BRASS_BRIGHT)


func _build_page() -> Control:
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 16)
	page.add_child(heading)
	_number = UiTheme.label("", 52, Color(UiTheme.BRASS, 0.85), UiTheme.title_font())
	heading.add_child(_number)
	var titles := VBoxContainer.new()
	titles.alignment = BoxContainer.ALIGNMENT_CENTER
	titles.add_theme_constant_override("separation", 0)
	heading.add_child(titles)
	_title = UiTheme.label("", 32, UiTheme.PARCHMENT, UiTheme.display_font())
	_title.name = "SectionTitle"
	titles.add_child(_title)
	_tagline = UiTheme.label("", 15, UiTheme.MUTED)
	titles.add_child(_tagline)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(_scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 6)
	_scroll.add_child(margin)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.add_theme_constant_override("separation", 16)
	margin.add_child(_content)
	return page


func _build_footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	if _in_match:
		row.add_child(UiTheme.label("对局不会暂停,计时照常 ·", 14, UiTheme.LIE))
	var keys := UiTheme.label("← → 翻页 · %s / Esc 合上" % OS.get_keycode_string(HOTKEY), 14, UiTheme.MUTED)
	keys.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(keys)
	_prev = UiTheme.button("‹ 上一页")
	_prev.add_theme_font_size_override("font_size", 16)
	_prev.pressed.connect(turn_page.bind(-1))
	row.add_child(_prev)
	_page_label = UiTheme.label("", 16, UiTheme.PARCHMENT_DIM, UiTheme.latin_font())
	_page_label.custom_minimum_size.x = 56
	_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_page_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_page_label)
	_next = UiTheme.button("下一页 ›")
	_next.add_theme_font_size_override("font_size", 16)
	_next.pressed.connect(turn_page.bind(1))
	row.add_child(_next)
	return row


func _rule(horizontal: bool) -> ColorRect:
	var line := ColorRect.new()
	line.color = Color(UiTheme.BRASS, 0.35)
	line.custom_minimum_size = Vector2(0, 1) if horizontal else Vector2(1, 0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _play_open() -> void:
	modulate.a = 0.0
	_panel.scale = Vector2(0.96, 0.96)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 1.0, 0.18)
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("flip")
