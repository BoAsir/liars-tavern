class_name ConfirmOverlay
extends ColorRect
# 模态确认框:半透明遮罩 + 黄铜描边面板。确认/取消后自动关闭。
# 遮罩吞掉鼠标与未处理的按键:打开期间背后屏幕的快捷键(选牌/出牌/质疑/离开)不会生效。


signal confirmed
signal cancelled

var _message := ""
var _confirm_text := ""
var _cancel_text := ""
var _closed := false
var _previous_focus: Control = null


func _init(message: String, confirm_text := "确定", cancel_text := "取消") -> void:
	_message = message
	_confirm_text = confirm_text
	_cancel_text = cancel_text


func _ready() -> void:
	color = Color(0, 0, 0, 0.55)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	var label := UiTheme.label(_message, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	var buttons: Array[Button] = []
	if _cancel_text != "":
		var cancel := UiTheme.button(_cancel_text)
		cancel.pressed.connect(_close.bind(false))
		row.add_child(cancel)
		buttons.append(cancel)
	var ok := UiTheme.button(_confirm_text, true)
	ok.pressed.connect(_close.bind(true))
	row.add_child(ok)
	buttons.append(ok)
	_trap_focus(buttons)
	_take_focus.call_deferred(ok)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func dismiss() -> void:
	# 屏幕切换时由 main 收走:不发确认/取消信号,也不播音效
	_closed = true
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	# Esc 取消;其余按键一律吞掉。按钮通过焦点照常收到 Enter/空格(GUI 先于这里处理)
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close(false)
	elif event is InputEventKey:
		get_viewport().set_input_as_handled()


func _trap_focus(buttons: Array[Button]) -> void:
	# 确认框和背后的屏幕共用一个根控件,Tab/方向键默认会把焦点挪到屏幕的按钮上去;
	# 把每个按钮的焦点邻居都指回框内,键盘就出不去了
	for i in buttons.size():
		var button := buttons[i]
		var next := buttons[(i + 1) % buttons.size()]
		var prev := buttons[(i - 1 + buttons.size()) % buttons.size()]
		button.focus_next = button.get_path_to(next)
		button.focus_previous = button.get_path_to(prev)
		button.focus_neighbor_right = button.get_path_to(next)
		button.focus_neighbor_left = button.get_path_to(prev)
		button.focus_neighbor_top = button.get_path_to(button)
		button.focus_neighbor_bottom = button.get_path_to(button)


func _take_focus(button: Button) -> void:
	# 延迟到同一帧里新屏幕设定的默认焦点之后:记下它,关闭时还回去,纯键盘也能接着操作
	if _closed or not is_inside_tree():
		return
	_previous_focus = get_viewport().gui_get_focus_owner()
	button.grab_focus()


func _close(accepted: bool) -> void:
	if _closed:
		return  # 同一帧里连点、键盘与鼠标同时确认:只算一次
	_closed = true
	Sfx.play("ui_click")
	if is_instance_valid(_previous_focus) and _previous_focus.is_visible_in_tree():
		_previous_focus.grab_focus()
	if accepted:
		confirmed.emit()
	else:
		cancelled.emit()
	queue_free()
