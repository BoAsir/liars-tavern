class_name QuipMenu
extends PanelContainer
# 快捷对话的九宫格(右上「对话」按钮下面):9 句话各一个按钮,点一下发出;打开时也能按 1–9 选。
# 只发 chosen 信号,不直接调用 Net / Sfx(按键与冷却由 QuipController 管)。所有按钮 FOCUS_NONE(焦点会吃掉空格/回车)。


signal chosen(index: int)

const COLUMNS := 3
const TOP := 76.0               # 右上按钮下面
const RIGHT_MARGIN := 24.0
const BUTTON_SIZE := Vector2(150, 40)   # 最小尺寸;长句按文字撑宽,整句显示不省略
const BUTTON_FONT := 15
const HINT_FONT := 13
const HINT := "按 1–9 选择 · T 或 Esc 收起"
const COOLDOWN_HINT := "%d 秒后可以再说"
const PADDING := Vector2(10, 8)
const BACKGROUND_ALPHA := 0.95

var _buttons: Array[Button] = []
var _hint: Label


static func hint_text(cooldown_left: float) -> String:
	return COOLDOWN_HINT % ceili(cooldown_left) if cooldown_left > 0.0 else HINT


func _ready() -> void:
	var style := UiTheme.panel_box(Color(UiTheme.PANEL_SOFT, BACKGROUND_ALPHA), Color(UiTheme.BRASS, 0.6), 1, 12)
	style.content_margin_left = PADDING.x
	style.content_margin_right = PADDING.x
	style.content_margin_top = PADDING.y
	style.content_margin_bottom = PADDING.y
	add_theme_stylebox_override("panel", style)
	anchor_left = 1.0
	anchor_right = 1.0
	offset_right = -RIGHT_MARGIN
	offset_left = -RIGHT_MARGIN
	offset_top = TOP
	offset_bottom = TOP
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)
	for i in Quips.LINES.size():
		grid.add_child(_make_button(i))
	_hint = UiTheme.label(HINT, HINT_FONT, UiTheme.PARCHMENT_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)
	visible = false


func _make_button(index: int) -> Button:
	var button := UiTheme.button(Quips.LINES[index])
	button.add_theme_font_size_override("font_size", BUTTON_FONT)
	button.custom_minimum_size = BUTTON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = "%d · %s" % [index + 1, Quips.LINES[index]]
	button.pressed.connect(func(): chosen.emit(index))
	_buttons.append(button)
	return button


func is_open() -> bool:
	return visible


func open() -> void:
	visible = true


func close() -> void:
	visible = false


func toggle() -> void:
	visible = not visible


func set_cooldown(left: float) -> void:
	# 冷却中按钮变灰,提示还要等几秒
	for button in _buttons:
		button.disabled = left > 0.0
	_hint.text = hint_text(left)


func button_count() -> int:
	return _buttons.size()


func button_text(index: int) -> String:
	return _buttons[index].text
