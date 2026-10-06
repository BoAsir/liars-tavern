class_name SpeechBubble
extends PanelContainer
# 对话气泡:弹出 → 停留 → 淡出后自毁。底部带小三角指向说话者。


var _text := ""
var _color := UiTheme.INK
var _duration := 1.6


func _init(text: String, color := UiTheme.INK, duration := 1.6) -> void:
	_text = text
	_color = color
	_duration = duration


func _ready() -> void:
	var style := UiTheme.panel_box(UiTheme.PARCHMENT, Color(0.35, 0.22, 0.1), 2, 16)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 6
	add_theme_stylebox_override("panel", style)
	var label := UiTheme.label(_text, 24, _color, UiTheme.display_font())
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(label)
	pivot_offset = Vector2(size.x / 2.0, size.y)
	scale = Vector2(0.4, 0.4)
	modulate.a = 0.0
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.12)
	tween.chain().tween_interval(_duration)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(queue_free)


func _draw() -> void:
	var tip := Vector2(size.x / 2.0, size.y + 12.0)
	var base_l := Vector2(size.x / 2.0 - 10.0, size.y - 2.0)
	var base_r := Vector2(size.x / 2.0 + 10.0, size.y - 2.0)
	draw_colored_polygon(PackedVector2Array([base_l, base_r, tip]), UiTheme.PARCHMENT)
	draw_polyline(PackedVector2Array([base_l, tip, base_r]), Color(0.35, 0.22, 0.1), 2.0, true)
