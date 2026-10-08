class_name BombCatNameplate
extends PanelContainer
# 炸弹猫对手头顶铭牌:名字 + 手牌张数(小牌背图标 × N);轮到他时黄铜高亮(被甩锅时标出还要走几回合),
# 炸飞的写「炸飞了」、断线的写「离开了」,整块变灰。


const ACTIVE_BG := Color(0.25, 0.15, 0.06, 0.85)
const DIMMED := Color(0.6, 0.6, 0.6, 0.75)

var _name: Label
var _info: Label
var _style: StyleBoxFlat


static func info_text(hand_count: int, alive: bool, exploded: bool, active: bool, turns: int) -> String:
	if not alive:
		return "炸飞了" if exploded else "离开了"
	var text := "手牌 %d" % hand_count
	if active and turns > 1:
		text += " · 还要走 %d 回合" % turns
	return text


func _init(display_name: String) -> void:
	_style = UiTheme.panel_box(UiTheme.PANEL_SOFT, Color(UiTheme.BRASS, 0.45), 1, 10)
	_style.content_margin_left = 12
	_style.content_margin_right = 12
	_style.content_margin_top = 5
	_style.content_margin_bottom = 5
	add_theme_stylebox_override("panel", _style)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	add_child(box)
	_name = UiTheme.label(display_name, 18, UiTheme.PARCHMENT, UiTheme.display_font())
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_name)
	_info = UiTheme.label("", 14, UiTheme.PARCHMENT_DIM)
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_info)


func set_info(hand_count: int, alive: bool, exploded: bool, active: bool, turns := 1) -> void:
	_info.text = info_text(hand_count, alive, exploded, active, turns)
	_info.add_theme_color_override("font_color", UiTheme.BLOOD if not alive and exploded else UiTheme.PARCHMENT_DIM)
	_style.border_color = UiTheme.BRASS_BRIGHT if active else Color(UiTheme.BRASS, 0.45)
	_style.set_border_width_all(2 if active else 1)
	_style.bg_color = ACTIVE_BG if active else UiTheme.PANEL_SOFT
	modulate = DIMMED if not alive else Color.WHITE


func info() -> String:
	return _info.text
