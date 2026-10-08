class_name PokerSettlement
extends ColorRect
# 散局结算面板(规格 §6.5):标题「散局结算」,行放进 ScrollContainer 最多显示 8 行(离开的人也在列表里,可能超过 8 行)。
# 列宽:名次 70、名字(自适应、省略号;离开的人标灰「已离开」)、筹码 90、领取 60、盈亏 100(赢绿、输红,带正负号与千分位)。
# 按钮:房主「回到等待厅」,其他人「离开房间」。只发信号,不直接调用 Net / Sfx。


signal lobby_pressed
signal leave_pressed

const MAX_VISIBLE_ROWS := 8
const ROW_HEIGHT := 34.0
const COLUMN_PLACE := 70.0
const COLUMN_STACK := 90.0
const COLUMN_BUYINS := 60.0
const COLUMN_NET := 100.0
const PANEL_WIDTH := 560.0
const LEFT_TEXT := "已离开"
const HOST_TEXT := "回到等待厅"
const GUEST_TEXT := "离开房间"
const TITLE := "散局结算"
const FOCUS_KEYS := ["ui_accept", "ui_focus_next", "ui_focus_prev", "ui_left", "ui_right", "ui_up", "ui_down"]

var _ranking: Array = []
var _is_host := false
var _rows: VBoxContainer
var _scroll: ScrollContainer
var _primary: Button = null


static func rank(results: Variant) -> Array:
	# 结算行来自网络:坏条目丢掉,坏字段当默认值;按盈亏降序,同盈亏保持原顺序;另加 place
	var rows := []
	if results is Array:
		for row in results:
			if row is Dictionary:
				rows.append(_clean(row))
	var order := range(rows.size())
	order.sort_custom(func(a: int, b: int) -> bool:
		return rows[a]["net"] > rows[b]["net"] or (rows[a]["net"] == rows[b]["net"] and a < b))
	var ranking := []
	for index in order:
		var entry: Dictionary = rows[index]
		entry["place"] = ranking.size() + 1
		ranking.append(entry)
	return ranking


static func visible_rows(count: int) -> int:
	return mini(count, MAX_VISIBLE_ROWS)


static func _clean(row: Dictionary) -> Dictionary:
	return {
		"name": row["name"] if row.get("name") is String else "?",
		"stack": row["stack"] if row.get("stack") is int else 0,
		"buyins": row["buyins"] if row.get("buyins") is int else 0,
		"net": row["net"] if row.get("net") is int else 0,
		"left": row.get("left") is bool and row["left"],
	}


func _init(results: Array, is_host: bool) -> void:
	_ranking = rank(results)
	_is_host = is_host


func _ready() -> void:
	color = Color(0, 0, 0, 0.0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := _build_panel()
	center.add_child(panel)
	_play_intro(panel)
	_focus_default.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	# 焦点落空时(如说明书合上后),这些键先把焦点交给默认按钮
	if get_viewport().gui_get_focus_owner() != null or not _is_focus_key(event):
		return
	get_viewport().set_input_as_handled()
	_primary.grab_focus()


# —— 构建 ——

func _build_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	var style := UiTheme.panel_box(Color(0.07, 0.05, 0.04, 0.94), UiTheme.BRASS_BRIGHT, 2, 16)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 24
	style.content_margin_bottom = 24
	style.shadow_color = Color(0, 0, 0, 0.7)
	style.shadow_size = 30
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var title := UiTheme.label(TITLE, 40, UiTheme.BRASS_BRIGHT, UiTheme.title_font())
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(_header_row())
	box.add_child(_build_rows())
	box.add_child(_build_buttons())
	return panel


func _header_row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for col in [["名次", COLUMN_PLACE], ["名字", 0.0], ["筹码", COLUMN_STACK], ["领取", COLUMN_BUYINS], ["盈亏", COLUMN_NET]]:
		var label := UiTheme.label(col[0], 14, UiTheme.MUTED)
		_place_column(label, col[1])
		row.add_child(label)
	return row


func _build_rows() -> ScrollContainer:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(0, visible_rows(_ranking.size()) * ROW_HEIGHT)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 0)
	_scroll.add_child(_rows)
	for entry in _ranking:
		_rows.add_child(_rank_row(entry))
	return _scroll


func _rank_row(entry: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.add_theme_constant_override("separation", 12)
	var first: bool = entry["place"] == 1
	var place := UiTheme.label("第 %d 名" % entry["place"], 15, UiTheme.BRASS if first else UiTheme.MUTED)
	_place_column(place, COLUMN_PLACE)
	row.add_child(place)
	var name_label := UiTheme.label(entry["name"], 18, UiTheme.MUTED if entry["left"] else UiTheme.PARCHMENT, UiTheme.display_font())
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_place_column(name_label, 0.0)
	row.add_child(name_label)
	if entry["left"]:
		var left := UiTheme.label(LEFT_TEXT, 13, UiTheme.MUTED)
		left.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(left)
	var stack := UiTheme.label(ChipText.format(entry["stack"]), 16, UiTheme.PARCHMENT_DIM)
	_place_column(stack, COLUMN_STACK)
	row.add_child(stack)
	var buyins := UiTheme.label("%d 次" % entry["buyins"], 15, UiTheme.PARCHMENT_DIM)
	_place_column(buyins, COLUMN_BUYINS)
	row.add_child(buyins)
	var net: int = entry["net"]
	var net_label := UiTheme.label(ChipText.signed(net), 17, UiTheme.TRUTH if net > 0 else (UiTheme.LIE if net < 0 else UiTheme.PARCHMENT_DIM),
		UiTheme.body_font())
	_place_column(net_label, COLUMN_NET)
	row.add_child(net_label)
	return row


func _place_column(label: Label, width: float) -> void:
	# 宽度 0 的列(名字)吃掉剩余宽度
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if width > 0.0:
		label.custom_minimum_size = Vector2(width, 0)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if width != COLUMN_PLACE else HORIZONTAL_ALIGNMENT_LEFT
	else:
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _build_buttons() -> HBoxContainer:
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	if _is_host:
		_primary = UiTheme.button(HOST_TEXT, true)
		_primary.pressed.connect(func(): lobby_pressed.emit())
	else:
		_primary = UiTheme.button(GUEST_TEXT)
		_primary.pressed.connect(func(): leave_pressed.emit())
	buttons.add_child(_primary)
	if not _is_host:
		buttons.add_child(UiTheme.label("房主可带全员回等待厅", 15, UiTheme.MUTED))
	return buttons


func _play_intro(panel: PanelContainer) -> void:
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.85, 0.85)
	panel.resized.connect(func(): panel.pivot_offset = panel.size / 2.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "color:a", 0.55, 0.5)
	tween.tween_property(panel, "modulate:a", 1.0, 0.45)
	tween.tween_property(panel, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# —— 焦点 ——

func _focus_default() -> void:
	if not is_inside_tree():
		return
	# 说明书/确认框正拿着焦点时不抢
	var focused := get_viewport().gui_get_focus_owner()
	if focused == null or not focused.is_visible_in_tree():
		_primary.grab_focus()


func _is_focus_key(event: InputEvent) -> bool:
	return FOCUS_KEYS.any(func(action: String): return event.is_action_pressed(action))
