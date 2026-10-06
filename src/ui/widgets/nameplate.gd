class_name Nameplate
extends PanelContainer
# 对手头顶铭牌:名字、手牌数、六膛弹巢;轮到其行动时黄铜高亮,出局后变灰。


var _name: Label
var _cards: Label
var _dots: ChamberDots
var _style: StyleBoxFlat


func _init(display_name: String) -> void:
	_style = UiTheme.panel_box(UiTheme.PANEL_SOFT, Color(UiTheme.BRASS, 0.45), 1, 10)
	_style.content_margin_left = 12
	_style.content_margin_right = 12
	_style.content_margin_top = 6
	_style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", _style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	add_child(box)
	_name = UiTheme.label(display_name, 18, UiTheme.PARCHMENT, UiTheme.display_font())
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	_cards = UiTheme.label("", 14, UiTheme.PARCHMENT_DIM)
	row.add_child(_cards)
	_dots = ChamberDots.new(4.0)
	row.add_child(_dots)


func set_info(hand_count: int, shots_fired: int, alive: bool, active: bool) -> void:
	_cards.text = "手牌 %d" % hand_count if alive else "出局"
	_dots.fired = shots_fired
	_dots.dead = not alive
	_style.border_color = UiTheme.BRASS_BRIGHT if active else Color(UiTheme.BRASS, 0.45)
	_style.set_border_width_all(2 if active else 1)
	_style.bg_color = Color(0.25, 0.15, 0.06, 0.85) if active else UiTheme.PANEL_SOFT
	modulate = Color(0.6, 0.6, 0.6, 0.75) if not alive else Color.WHITE
