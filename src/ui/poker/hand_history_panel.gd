class_name HandHistoryPanel
extends PanelContainer
# 牌局记录(右上「记录 · H」):一手一页,默认翻到最近一手;← / → 或两侧按钮翻页,Esc / H / 「关闭」收起。
# 每页:第几手、5 张公共牌、每个被发到牌的人——名字、两张手牌(含弃牌的,一手结束后才有)、牌型、这一手的输赢。
# 不是模态框:开着时牌局照常进行,轮到自己的快捷键照样能用。记录来自 PokerScreenState.history(已清洗)。


signal closed

const HOTKEY := KEY_H
const WIDTH := 600.0
const BOARD_CARD := Vector2(36, 50)
const HOLE_CARD := Vector2(34, 48)
const TITLE_FONT := 22
const NAME_FONT := 16
const INFO_FONT := 14
const RESULT_FONT := 17
const ROW_GAP := 6
const PADDING := Vector2(18, 12)
const BACKGROUND_ALPHA := 0.96
const EMPTY_TEXT := "还没有打完的牌局"
const FOLDED_TEXT := "弃牌"
const LEFT_TEXT := "已离开"
const PREV_TEXT := "上一手"
const NEXT_TEXT := "下一手"
const CLOSE_TEXT := "关闭"
const HINT := "← → 翻页 · Esc / H 关闭"

var _records: Array = []
var _index := -1
var _title: Label
var _board: CardStrip
var _rows: VBoxContainer
var _prev: Button
var _next: Button


static func result_text(delta: int) -> String:
	return ChipText.signed(delta) if delta != 0 else "0"


static func title_text(record: Dictionary, index: int, count: int) -> String:
	return "牌局记录 · 第 %d 手(%d/%d)" % [record.get("hand", 0), index + 1, count]


func _ready() -> void:
	var style := UiTheme.panel_box(Color(UiTheme.PANEL_SOFT, BACKGROUND_ALPHA), Color(UiTheme.BRASS, 0.7), 2, 14)
	style.content_margin_left = PADDING.x
	style.content_margin_right = PADDING.x
	style.content_margin_top = PADDING.y
	style.content_margin_bottom = PADDING.y
	add_theme_stylebox_override("panel", style)
	custom_minimum_size.x = WIDTH
	# 画面正中:锚点都在中心、偏移为 0,按内容大小向四周长(set_anchors_preset 会保住旧位置,不用它)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		set_anchor(side, 0.5)
		set_offset(side, 0.0)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_title = UiTheme.label("", TITLE_FONT, UiTheme.BRASS_BRIGHT, UiTheme.title_font())
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	var board_row := HBoxContainer.new()
	board_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(board_row)
	_board = CardStrip.new(PokerRules.BOARD_CARDS, BOARD_CARD)
	board_row.add_child(_board)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", ROW_GAP)
	box.add_child(_rows)
	box.add_child(_build_footer())
	var hint := UiTheme.label(HINT, 13, UiTheme.MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)
	_show()


func _build_footer() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	_prev = _button(PREV_TEXT, func(): page(-1))
	_next = _button(NEXT_TEXT, func(): page(1))
	row.add_child(_prev)
	row.add_child(_button(CLOSE_TEXT, close))
	row.add_child(_next)
	return row


func _button(text: String, on_pressed: Callable) -> Button:
	var button := UiTheme.button(text)
	button.add_theme_font_size_override("font_size", 16)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(on_pressed)
	return button


func set_records(records: Array, jump_to_latest := true) -> void:
	# 有新的一手打完时追加;打开时默认翻到最近一手
	_records = records
	if jump_to_latest or _index >= _records.size():
		_index = _records.size() - 1
	if is_node_ready():
		_show()


func page(step: int) -> void:
	if _records.is_empty():
		return
	_index = clampi(_index + step, 0, _records.size() - 1)
	_show()


func index() -> int:
	return _index


func row_count() -> int:
	return _rows.get_child_count()


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.is_action_pressed("ui_cancel") or event.keycode == HOTKEY:
		get_viewport().set_input_as_handled()
		close()
	elif event.keycode == KEY_LEFT or event.keycode == KEY_RIGHT:
		get_viewport().set_input_as_handled()
		page(-1 if event.keycode == KEY_LEFT else 1)


func _show() -> void:
	for old in _rows.get_children():
		_rows.remove_child(old)
		old.free()
	_prev.disabled = _index <= 0
	_next.disabled = _index < 0 or _index >= _records.size() - 1
	if _index < 0:
		_title.text = EMPTY_TEXT
		_board.set_cards([])
		return
	var record: Dictionary = _records[_index]
	_title.text = title_text(record, _index, _records.size())
	_board.set_cards(record["board"])
	for row in record["players"]:
		_rows.add_child(_row(row))


func _row(row: Dictionary) -> HBoxContainer:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	var dim: bool = row["folded"] or row["left"]
	if dim:
		line.modulate.a = 0.7
	var strip := CardStrip.new(0, HOLE_CARD)
	strip.set_cards(row["cards"])
	line.add_child(strip)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(text)
	var name_label := UiTheme.label(row["name"], NAME_FONT, UiTheme.PARCHMENT, UiTheme.display_font())
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	text.add_child(name_label)
	var tags := []
	if row["hand_name"] != "":
		tags.append(row["hand_name"])
	if row["folded"]:
		tags.append(FOLDED_TEXT)
	if row["left"]:
		tags.append(LEFT_TEXT)
	text.add_child(UiTheme.label(" · ".join(tags), INFO_FONT, UiTheme.BRASS_BRIGHT if not dim else UiTheme.PARCHMENT_DIM))
	var delta: int = row["delta"]
	var color := UiTheme.TRUTH if delta > 0 else (UiTheme.LIE if delta < 0 else UiTheme.PARCHMENT_DIM)
	var result := UiTheme.label(result_text(delta), RESULT_FONT, color, UiTheme.display_font())
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	result.custom_minimum_size.x = 90
	line.add_child(result)
	return line
