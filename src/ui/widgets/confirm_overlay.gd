class_name ConfirmOverlay
extends ColorRect
# 模态确认框:半透明遮罩 + 黄铜描边面板。确认/取消后自动关闭。


signal confirmed
signal cancelled

var _message := ""
var _confirm_text := ""
var _cancel_text := ""


func _init(message: String, confirm_text := "确定", cancel_text := "取消") -> void:
	_message = message
	_confirm_text = confirm_text
	_cancel_text = cancel_text


func _ready() -> void:
	color = Color(0, 0, 0, 0.55)
	set_anchors_preset(Control.PRESET_FULL_RECT)
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
	if _cancel_text != "":
		var cancel := UiTheme.button(_cancel_text)
		cancel.pressed.connect(_close.bind(false))
		row.add_child(cancel)
	var ok := UiTheme.button(_confirm_text, true)
	ok.pressed.connect(_close.bind(true))
	row.add_child(ok)
	ok.grab_focus.call_deferred()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close(false)


func _close(accepted: bool) -> void:
	Sfx.play("ui_click")
	if accepted:
		confirmed.emit()
	else:
		cancelled.emit()
	queue_free()
