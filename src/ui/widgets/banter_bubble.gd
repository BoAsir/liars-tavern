class_name BanterBubble
extends PanelContainer
# 快捷语气泡(规格 2026-10-08 丢番茄与快捷语 §5):圆角奶油色气泡,底部小三角指向说话人;
# 文字跟着动物话的音节一个字一个字出现(时间表来自 AnimalVoice.layout 的 reveal),说完停 HOLD 秒后淡出自毁。
# 气泡一开始就按整句排版(只是没显示的字先藏起来),逐字出现时大小不跳。纯展示:不接收鼠标。


const HOLD := 2.5             # 声音结束后停留(秒)
const FADE := 0.35
const TAIL_LENGTH := 12.0
const FONT_SIZE := 22
const SMALL_SCALE := 0.85     # 本机自己的气泡略小(规格 §5:不挡自己的手牌)
const BG := Color(0.99, 0.95, 0.86)
const BORDER := Color(0.55, 0.36, 0.14)

var text := ""
var _reveal := PackedFloat32Array()
var _duration := 0.0
var _small := false
var _elapsed := 0.0
var _label: Label
var _fading := false


func _init(p_text: String, reveal: PackedFloat32Array, duration: float, small := false) -> void:
	text = p_text
	_reveal = reveal
	_duration = duration
	_small = small
	name = "BanterBubble"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := UiTheme.panel_box(BG, BORDER, 2, 18)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	add_theme_stylebox_override("panel", style)
	_label = UiTheme.label(text, FONT_SIZE, UiTheme.INK, UiTheme.display_font())
	_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING   # 按整句排版,藏起来的字也占位
	_label.visible_characters = 0
	add_child(_label)
	resized.connect(_update_pivot)
	_update_pivot()
	var target := Vector2.ONE * (SMALL_SCALE if _small else 1.0)
	scale = target * 0.4
	modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "scale", target, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 1.0, 0.1)
	_update_reveal()


func _process(delta: float) -> void:
	_elapsed += delta
	_update_reveal()
	if not _fading and _elapsed >= _duration + HOLD:
		_fading = true
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, FADE)
		tween.tween_callback(queue_free)


func _update_reveal() -> void:
	if _label != null:
		_label.visible_characters = shown_characters(_reveal, _elapsed)


static func shown_characters(reveal: PackedFloat32Array, elapsed: float) -> int:
	# 到 elapsed 为止该显示几个字(reveal[i] 是第 i 个字出现的时刻,单调不减)
	var count := 0
	while count < reveal.size() and reveal[count] <= elapsed:
		count += 1
	return count


func is_fully_shown() -> bool:
	return _label != null and _label.visible_characters >= text.length()


func lifetime() -> float:
	return _duration + HOLD + FADE


func _update_pivot() -> void:
	var laid_out := size.max(get_combined_minimum_size())
	pivot_offset = Vector2(laid_out.x / 2.0, laid_out.y + TAIL_LENGTH)


func _draw() -> void:
	# 底部小三角(圆润一点:两腰稍弯)
	var tip := Vector2(size.x / 2.0 - 4.0, size.y + TAIL_LENGTH)
	var base_l := Vector2(size.x / 2.0 - 11.0, size.y - 2.0)
	var base_r := Vector2(size.x / 2.0 + 9.0, size.y - 2.0)
	draw_colored_polygon(PackedVector2Array([base_l, base_r, tip]), BG)
	draw_polyline(PackedVector2Array([base_l, tip, base_r]), BORDER, 2.0, true)
