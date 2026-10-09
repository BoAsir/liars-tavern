class_name BanterChip
extends Control
# 屏幕左侧的小圆牌:画一个番茄或对话框图标、右下角写快捷键;冷却时盖一块逐渐缩小的扇形暗影并写剩余秒数,
# 冷却中再按会抖一下、描边闪红。点击发 pressed(快捷语那枚用来开面板)。


signal pressed

const TOMATO := 0
const SPEECH := 1
const SIZE := 46.0
const RING := Color(UiTheme.BRASS, 0.75)
const SHADE := Color(0.0, 0.0, 0.0, 0.55)

var icon := TOMATO
var key_text := ""
var _cooldown := 0.0       # 剩余比例 0..1
var _seconds := 0.0
var _flash := 0.0          # 冷却中被按:描边闪红
var _jitter := 0.0         # 抖动时图标的横向偏移(像素)
var _shake_tween: Tween = null


func _init(p_icon: int, p_key: String, tip: String) -> void:
	icon = p_icon
	key_text = p_key
	tooltip_text = tip
	custom_minimum_size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	name = "TomatoChip" if p_icon == TOMATO else "SpeechChip"


func set_cooldown(seconds_left: float, total: float) -> void:
	var ratio := clampf(seconds_left / maxf(total, 0.001), 0.0, 1.0)
	if absf(ratio - _cooldown) > 0.002 or (ratio == 0.0) != (_cooldown == 0.0):
		_cooldown = ratio
		_seconds = seconds_left
		queue_redraw()


func cooling() -> bool:
	return _cooldown > 0.0


func shake() -> void:
	# 冷却中又按了:图标左右抖几下,描边闪红
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
	_shake_tween = create_tween()
	for dx in [6.0, -6.0, 4.0, -4.0, 0.0]:
		_shake_tween.tween_method(_set_jitter, _jitter, dx, 0.04)
		_jitter = dx
	_jitter = 0.0
	var flash := create_tween()
	flash.tween_method(_set_flash, 1.0, 0.0, 0.45)


func _set_jitter(value: float) -> void:
	_jitter = value
	queue_redraw()


func _set_flash(value: float) -> void:
	_flash = value
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func _draw() -> void:
	var c := Vector2(SIZE / 2.0 + _jitter, SIZE / 2.0)
	var r := SIZE / 2.0 - 1.0
	draw_circle(c, r, UiTheme.PANEL)
	if icon == TOMATO:
		_draw_tomato(c)
	else:
		_draw_speech(c)
	if _cooldown > 0.0:
		# 剩余冷却:从 12 点钟方向顺时针缩小的暗影扇形
		var points := PackedVector2Array([c])
		var steps := 24
		for i in steps + 1:
			var a := -PI / 2.0 + TAU * _cooldown * float(i) / steps
			points.append(c + Vector2(cos(a), sin(a)) * r)
		if points.size() >= 3:
			draw_colored_polygon(points, SHADE)
		var font := UiTheme.body_font()
		var text := "%.1f" % _seconds
		var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15)
		draw_string(font, c + Vector2(-size.x / 2.0, 5.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 15, UiTheme.PARCHMENT)
	var ring := RING.lerp(UiTheme.LIE, _flash)
	draw_arc(c, r, 0.0, TAU, 40, ring, 2.0 if _flash <= 0.0 else 3.0, true)
	# 右下角的快捷键
	var key_font := UiTheme.display_font()
	var badge := c + Vector2(r * 0.62, r * 0.62)
	draw_circle(badge, 10.0, UiTheme.BRASS if _cooldown <= 0.0 else UiTheme.MUTED)
	var ks := key_font.get_string_size(key_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
	draw_string(key_font, badge + Vector2(-ks.x / 2.0, 5.0), key_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 14, UiTheme.INK)


func _draw_tomato(c: Vector2) -> void:
	draw_circle(c + Vector2(0, 2), 13.0, Color(0.82, 0.18, 0.12))
	draw_circle(c + Vector2(-4, -2), 4.0, Color(0.95, 0.45, 0.35))   # 高光
	for k in 5:
		var a := -PI / 2.0 + TAU * k / 5.0
		draw_line(c + Vector2(0, -9), c + Vector2(0, -9) + Vector2(cos(a), sin(a) * 0.5) * 7.0, Color(0.3, 0.6, 0.22), 3.0, true)
	draw_line(c + Vector2(0, -10), c + Vector2(1, -15), Color(0.3, 0.5, 0.2), 2.0, true)


func _draw_speech(c: Vector2) -> void:
	var rect := Rect2(c + Vector2(-14, -11), Vector2(28, 19))
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.99, 0.95, 0.86)
	box.set_corner_radius_all(8)
	draw_style_box(box, rect)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-6, 7), c + Vector2(2, 7), c + Vector2(-8, 14)]), Color(0.99, 0.95, 0.86))
	for k in 3:
		draw_circle(c + Vector2(-7 + k * 7, -1.5), 2.2, UiTheme.INK)
