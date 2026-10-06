class_name CountdownRing
extends Control
# 环形倒计时:剩余比例画成黄铜圆弧,最后 10 秒变红并轻微脉动。


const WARN_SECONDS := 10.0

var remaining := 0.0
var total := 30.0
var _font: Font


func _init() -> void:
	custom_minimum_size = Vector2(50, 50)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = UiTheme.body_font()   # 衬线字体是旧式数字(30 像 3o),倒计时用正文字体的等高数字


func set_time(p_remaining: float, p_total: float) -> void:
	remaining = maxf(p_remaining, 0.0)
	total = maxf(p_total, 0.001)
	queue_redraw()


func _draw() -> void:
	var center := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - 4.0
	var warn := remaining <= WARN_SECONDS
	var color := UiTheme.LIE if warn else UiTheme.BRASS
	if warn:
		radius += sin(Time.get_ticks_msec() / 90.0) * 1.2
	draw_circle(center, radius + 3.0, Color(0, 0, 0, 0.55))
	draw_arc(center, radius, 0.0, TAU, 64, Color(color, 0.2), 4.0, true)
	var frac := clampf(remaining / total, 0.0, 1.0)
	if frac > 0.0:
		draw_arc(center, radius, -PI / 2.0, -PI / 2.0 + TAU * frac, 64, color, 4.0, true)
	var text := str(ceili(remaining))
	var font_size := 22
	var text_size := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(_font, center + Vector2(-text_size.x / 2.0, font_size * 0.36), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, UiTheme.PARCHMENT if not warn else UiTheme.LIE)
