class_name PokerPrompts
extends PanelContainer
# 底部中间的座位提示(规格 §6.4、§2.6、§2.8),不是模态框:不挡房主的「散局」,按钮 FOCUS_NONE,
# 正在按的空格 / 回车不会误触。四种:
# 输光(「你的筹码输光了」+「再领 2000」「观战」+ 下一手开始的倒计时)、观战(常驻「领取 2000 上桌」)、
# 等待下一手(「已入座,下一手开始发牌」)、离座(「你已离座」+「回到牌桌」)。只发信号。


signal rebuy_pressed
signal spectate_pressed
signal sit_in_pressed

const BUST := "bust"
const SPECTATE := "spectate"
const WAITING := "waiting"
const AWAY := "away"
const MESSAGES := {
	BUST: "你的筹码输光了",
	SPECTATE: "观战中",
	WAITING: "已入座,下一手开始发牌",
	AWAY: "你已离座",
}
const REBUY_TEXT := "再领 %s" % PokerRules.STARTING_STACK
const SEAT_TEXT := "领取 %s 上桌" % PokerRules.STARTING_STACK
const SPECTATE_TEXT := "观战"
const SIT_IN_TEXT := "回到牌桌"
const COUNTDOWN_HINT := "秒后开下一手 · Esc 观战"
const MESSAGE_FONT := 20
const BUTTON_FONT := 19
const PADDING := Vector2(18, 8)

var _mode := ""
var _message: Label
var _rebuy_button: Button
var _spectate_button: Button
var _sit_in_button: Button
var _ring: CountdownRing
var _countdown_label: Label


func _ready() -> void:
	var style := UiTheme.panel_box(UiTheme.PANEL_SOFT, Color(UiTheme.BRASS, 0.5), 1, 12)
	style.content_margin_left = PADDING.x
	style.content_margin_right = PADDING.x
	style.content_margin_top = PADDING.y
	style.content_margin_bottom = PADDING.y
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_message = UiTheme.label("", MESSAGE_FONT, UiTheme.PARCHMENT, UiTheme.display_font())
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_message)
	box.add_child(_build_buttons())
	box.add_child(_build_countdown())


func _build_buttons() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rebuy_button = _button(REBUY_TEXT, true, func(): rebuy_pressed.emit())
	_spectate_button = _button(SPECTATE_TEXT, false, func(): spectate_pressed.emit())
	_sit_in_button = _button(SIT_IN_TEXT, true, func(): sit_in_pressed.emit())
	for button in [_rebuy_button, _spectate_button, _sit_in_button]:
		row.add_child(button)
	return row


func _build_countdown() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring = CountdownRing.new()
	_ring.custom_minimum_size = Vector2(36, 36)
	row.add_child(_ring)
	_countdown_label = UiTheme.label(COUNTDOWN_HINT, 14, UiTheme.MUTED)
	_countdown_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_countdown_label)
	return row


func _button(text: String, primary: bool, on_pressed: Callable) -> Button:
	var button := UiTheme.button(text, primary)
	button.add_theme_font_size_override("font_size", BUTTON_FONT)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button


func show_mode(mode: String) -> void:
	_mode = mode
	_message.text = MESSAGES.get(mode, "")
	_rebuy_button.visible = mode == BUST or mode == SPECTATE
	_rebuy_button.text = REBUY_TEXT if mode == BUST else SEAT_TEXT
	_spectate_button.visible = mode == BUST
	_sit_in_button.visible = mode == AWAY
	_ring.get_parent().visible = mode == BUST
	_ring.visible = mode == BUST


func mode() -> String:
	return _mode


func set_countdown(remaining: float, total: float) -> void:
	# 输光后到下一手开始的时间(PokerPacing.BUST_DECISION):不选不会卡住牌局,只是不发牌给他
	_ring.set_time(remaining, total)
