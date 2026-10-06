class_name PostFx
extends CanvasLayer
# 全屏后处理层(位于 3D 之上、界面之下):紧张度(暗角/去饱和/色差)、闪光染色。
# 每个通道只留一个补间(新的打断旧的);reset() 打断全部并回到平静画面,切换屏幕时由 main 调用。


const SHADER := preload("res://src/world/shaders/post_fx.gdshader")
const BASE_VIGNETTE := 0.32
const CLEAR_FLASH := Color(1, 0.1, 0.05, 0.0)

var _rect: ColorRect
var _mat: ShaderMaterial
var _tension_tween: Tween = null
var _pulse_tween: Tween = null
var _flash_tween: Tween = null


func _ready() -> void:
	layer = 1
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)
	# 显式初始化全部参数:get_shader_parameter 对未设置的参数返回 null
	_apply_calm()


func reset(duration := 0.0) -> void:
	# 打断旧屏幕留下的演出补间(举枪紧张、色差脉冲、中弹染红),在 duration 秒内回到平静(0 = 立即)。
	# 被打断的 fade_to 不会再返回:等它的演出协程随旧屏幕一起释放
	_kill(_pulse_tween)
	_kill(_flash_tween)
	if duration <= 0.0:
		_kill(_tension_tween)
		_apply_calm()
		return
	set_tension(0.0, duration)
	var flash_now: Color = _mat.get_shader_parameter("flash_color")
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, flash_now, Color(flash_now, 0.0), duration)


func set_tension(amount: float, duration := 0.6) -> void:
	# 0 = 平静;1 = 举枪时的极限紧张
	_kill(_tension_tween)
	_tension_tween = create_tween().set_parallel()
	_tween_param(_tension_tween, "vignette", _param("vignette"), lerpf(BASE_VIGNETTE, 0.92, amount), duration)
	_tween_param(_tension_tween, "desaturate", _param("desaturate"), amount * 0.55, duration)
	_tween_param(_tension_tween, "aberration", _param("aberration"), amount * 0.9, duration)


func pulse_aberration(peak: float, duration: float) -> void:
	# 冲到峰值再从峰值缓缓回落(回落段的起点必须是峰值,不能取建补间时的当前值)
	_kill(_pulse_tween)
	_pulse_tween = create_tween()
	var base := _param("aberration")
	_tween_param(_pulse_tween, "aberration", base, peak, duration * 0.2)
	_tween_param(_pulse_tween, "aberration", peak, base, duration * 0.8)


func flash(color: Color, duration: float) -> void:
	_kill(_flash_tween)
	_set_flash(color)
	_flash_tween = create_tween()
	_flash_tween.tween_method(func(a: float): _set_flash(Color(color, a)),
		color.a, 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)


func fade_to(color: Color, duration: float) -> void:
	_kill(_flash_tween)
	var from: Color = _mat.get_shader_parameter("flash_color")
	var tween := create_tween()
	_flash_tween = tween
	tween.tween_method(_set_flash, from, color, duration)
	await tween.finished


func _apply_calm() -> void:
	_mat.set_shader_parameter("vignette", BASE_VIGNETTE)
	_mat.set_shader_parameter("desaturate", 0.0)
	_mat.set_shader_parameter("aberration", 0.0)
	_set_flash(CLEAR_FLASH)


func _param(param: String) -> float:
	return _mat.get_shader_parameter(param)


func _set_flash(color: Color) -> void:
	_mat.set_shader_parameter("flash_color", color)


func _tween_param(tween: Tween, param: String, from: float, to: float, duration: float) -> void:
	tween.tween_method(func(v: float): _mat.set_shader_parameter(param, v), from, to, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
