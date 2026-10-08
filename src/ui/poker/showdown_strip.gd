class_name ShowdownStrip
extends PanelContainer
# 摊牌条(规格 §6.1):从 reveal 到 hand_over 显示在底部中间,每人一格——名字(省略号)、2 张 ≥ 30×42 的小牌、牌型名;
# 最多 2 行 × 4 人,整体 ≤ 600×170。条目来自事件,坏条目丢掉、坏字段当空。


const COLUMNS := 4
const MAX_ENTRIES := 8
const CARD_SIZE := Vector2(30, 42)
const NAME_WIDTH := 72.0
const NAME_FONT := 13
const HAND_FONT := 12
const CELL_GAP := 3
const GRID_GAP := Vector2(6, 4)
const PADDING := Vector2(8, 6)

var _grid: GridContainer


static func sanitize(entries: Variant) -> Array:
	if not entries is Array:
		return []
	var out := []
	for entry in entries:
		if not entry is Dictionary:
			continue
		out.append({
			"name": entry["name"] if entry.get("name") is String else "?",
			"cards": CardStrip.sanitize(entry.get("cards")),
			"hand_name": entry["hand_name"] if entry.get("hand_name") is String else "",
		})
		if out.size() == MAX_ENTRIES:
			break
	return out


func _ready() -> void:
	var style := UiTheme.panel_box(UiTheme.PANEL_SOFT, Color(UiTheme.BRASS, 0.5), 1, 12)
	style.content_margin_left = PADDING.x
	style.content_margin_right = PADDING.x
	style.content_margin_top = PADDING.y
	style.content_margin_bottom = PADDING.y
	add_theme_stylebox_override("panel", style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", int(GRID_GAP.x))
	_grid.add_theme_constant_override("v_separation", int(GRID_GAP.y))
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_grid)


func set_entries(entries: Variant) -> void:
	for old in _grid.get_children():
		_grid.remove_child(old)
		old.free()   # 已出树,直接释放(queue_free 在无头测试里会留到帧末成为孤儿)
	for entry in sanitize(entries):
		_grid.add_child(_cell(entry))


func _cell(entry: Dictionary) -> HBoxContainer:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", CELL_GAP)
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var strip := CardStrip.new(0, CARD_SIZE)
	strip.set_cards(entry["cards"])
	cell.add_child(strip)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(text)
	var name_label := UiTheme.label(entry["name"], NAME_FONT, UiTheme.PARCHMENT, UiTheme.display_font())
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.custom_minimum_size.x = NAME_WIDTH
	text.add_child(name_label)
	var hand_label := UiTheme.label(entry["hand_name"], HAND_FONT, UiTheme.BRASS_BRIGHT)
	hand_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hand_label.custom_minimum_size.x = NAME_WIDTH
	text.add_child(hand_label)
	return cell
