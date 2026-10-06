class_name PostFx
extends CanvasLayer
# 全屏后处理层(位于 3D 之上、界面之下):紧张度(暗角/去饱和/色差)、闪光染色。


const SHADER := preload("res://src/world/shaders/post_fx.gdshader")
const BASE_VIGNETTE := 0.32

var _rect: ColorRect
var _mat: ShaderMaterial
var _tension_tween: Tween = null


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
	var defaults := {"vignette": BASE_VIGNETTE, "desaturate": 0.0, "aberration": 0.0}
	for param in defaults:
		_mat.set_shader_parameter(param, defaults[param])
	_mat.set_shader_parameter("flash_color", Color(1, 0.1, 0.05, 0.0))


func set_tension(amount: float, duration := 0.6) -> void:
	# 0 = 平静;1 = 举枪时的极限紧张
	if _tension_tween != null and _tension_tween.is_valid():
		_tension_tween.kill()
	_tension_tween = create_tween().set_parallel()
	_tween_param(_tension_tween, "vignette", lerpf(BASE_VIGNETTE, 0.92, amount), duration)
	_tween_param(_tension_tween, "desaturate", amount * 0.55, duration)
	_tween_param(_tension_tween, "aberration", amount * 0.9, duration)


func pulse_aberration(peak: float, duration: float) -> void:
	var tween := create_tween()
	var base: float = _mat.get_shader_parameter("aberration")
	_tween_param(tween, "aberration", peak, duration * 0.2)
	_tween_param(tween, "aberration", base, duration * 0.8)


func flash(color: Color, duration: float) -> void:
	_mat.set_shader_parameter("flash_color", color)
	var tween := create_tween()
	tween.tween_method(func(a: float): _mat.set_shader_parameter("flash_color", Color(color, a)),
		color.a, 0.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_EXPO)


func fade_to(color: Color, duration: float) -> void:
	var tween := create_tween()
	var from: Color = _mat.get_shader_parameter("flash_color")
	tween.tween_method(func(c: Color): _mat.set_shader_parameter("flash_color", c), from, color, duration)
	await tween.finished


func _tween_param(tween: Tween, param: String, to: float, duration: float) -> void:
	var from: float = _mat.get_shader_parameter(param)
	tween.tween_method(func(v: float): _mat.set_shader_parameter(param, v), from, to, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

