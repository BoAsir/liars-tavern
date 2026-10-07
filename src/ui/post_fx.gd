class_name PostFx
extends CanvasLayer
# 全屏后处理层(位于 3D 之上、界面之下):紧张度(暗角/去饱和/色差)、闪光染色。
# 每个通道只留一个补间(新的打断旧的);reset() 打断全部并回到平静画面,切换屏幕时由 main 调用。
# 两个全屏矩形同一时刻只显示一个:去饱和或色差生效时用读屏幕的完整着色器,
# 平时用只叠加的着色器(读屏幕要先整屏拷贝一次,4K 下约 2 毫秒/帧)。


const SHADER := preload("res://src/world/shaders/post_fx.gdshader")
const OVERLAY_SHADER := preload("res://src/world/shaders/post_fx_overlay.gdshader")
const BASE_VIGNETTE := 0.32
const CLEAR_FLASH := Color(1, 0.1, 0.05, 0.0)
const SCREEN_EPSILON := 0.001   # 去饱和、色差低于此值视为关闭,不必读屏幕

var _rect: ColorRect
var _mat: ShaderMaterial
var _overlay_rect: ColorRect
var _overlay_mat: ShaderMaterial
var _tension_tween: Tween = null
var _pulse_tween: Tween = null
var _flash_tween: Tween = null


func _ready() -> void:
	layer = 1
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect = _full_rect(_mat)
	_overlay_mat = ShaderMaterial.new()
	_overlay_mat.shader = OVERLAY_SHADER
	_overlay_rect = _full_rect(_overlay_mat)
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


func reads_screen() -> bool:
	return _rect.visible


func _full_rect(mat: ShaderMaterial) -> ColorRect:
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = mat
	add_child(rect)
	return rect


func _apply_calm() -> void:
	_set_param("vignette", BASE_VIGNETTE)
	_set_param("desaturate", 0.0)
	_set_param("aberration", 0.0)
	_set_flash(CLEAR_FLASH)


func _param(param: String) -> float:
	return _mat.get_shader_parameter(param)


func _set_param(param: String, value: Variant) -> void:
	_mat.set_shader_parameter(param, value)
	_overlay_mat.set_shader_parameter(param, value)
	if param == "desaturate" or param == "aberration":
		var screen := _level("desaturate") > SCREEN_EPSILON or _level("aberration") > SCREEN_EPSILON
		_rect.visible = screen
		_overlay_rect.visible = not screen


func _level(param: String) -> float:
	# 初始化途中另一个参数可能还没设(返回 null),当作 0
	var value: Variant = _mat.get_shader_parameter(param)
	return value if value is float else 0.0


func _set_flash(color: Color) -> void:
	_set_param("flash_color", color)


func _tween_param(tween: Tween, param: String, from: float, to: float, duration: float) -> void:
	tween.tween_method(func(v: float): _set_param(param, v), from, to, duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


static func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
