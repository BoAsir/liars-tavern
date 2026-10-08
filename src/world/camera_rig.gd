class_name CameraRig
extends Node3D
# 相机运镜:平滑移动/环绕/跟随、震屏(创伤值衰减)、待机呼吸、鼠标视差。
# 本节点承载"目标机位",子相机叠加震屏与呼吸偏移,互不干扰。


const DEFAULT_FOV := 66.0   # 竖直视角(度);第一人称另用 TableWorld.FIRST_PERSON_FOV
const SHAKE_DECAY := 2.2
const SHAKE_MAX_OFFSET := 0.05
const SHAKE_MAX_ROLL := 0.05
const BREATH_AMPLITUDE := 0.004
const PARALLAX_YAW := 0.05
const PARALLAX_PITCH := 0.03

var camera: Camera3D
var fill_light: OmniLight3D
var parallax_enabled := false

var _trauma := 0.0
var _time := 0.0
var _move_tween: Tween = null
var _fov_tween: Tween = null
var _fill_tween: Tween = null
var _orbit_active := false
var _orbit_center := Vector3.ZERO
var _orbit_radius := 3.0
var _orbit_height := 2.0
var _orbit_speed := 0.08
var _orbit_angle := 0.0
var _follow: Callable = Callable()   # 跟随机位:每帧调用它取目标变换(第一人称跟着自己的头);空 = 不跟随
var _follow_from := Transform3D.IDENTITY
var _follow_weight := 1.0            # 从开始跟随时的机位过渡到跟随目标的进度(补间驱动)
var _parallax := Vector2.ZERO
var _noise := FastNoiseLite.new()


func _ready() -> void:
	camera = Camera3D.new()
	camera.fov = DEFAULT_FOV
	camera.near = 0.03
	camera.far = 40.0
	camera.cull_mask &= ~MeshKit.LAYER_LOCAL_HIDDEN   # 第一人称藏起来的自己头上的小件
	camera.current = true
	add_child(camera)
	# 第三人称补光:跟随镜头,照亮背对主光的自己角色与手牌;只在座位机位开启
	fill_light = OmniLight3D.new()
	fill_light.position = Vector3(0.0, 0.25, 0.1)
	fill_light.light_color = Color(1.0, 0.86, 0.7)
	fill_light.light_energy = 0.0
	fill_light.light_specular = 0.25
	fill_light.omni_range = 3.2
	fill_light.omni_attenuation = 1.4
	fill_light.light_volumetric_fog_energy = 0.0
	camera.add_child(fill_light)
	_noise.frequency = 2.0


func _process(delta: float) -> void:
	_time += delta
	if _orbit_active:
		_orbit_angle += _orbit_speed * delta
		var pos := _orbit_center + Vector3(sin(_orbit_angle) * _orbit_radius, _orbit_height, cos(_orbit_angle) * _orbit_radius)
		global_transform = _look(pos, _orbit_center)
	elif _follow.is_valid():
		# 到位后直接贴着目标:第一人称的眼睛本身已经平滑(脖子是临界阻尼弹簧,前倾按插值),再加一层会拖影
		var target: Transform3D = _follow.call()
		global_transform = _follow_from.interpolate_with(target, _follow_weight) if _follow_weight < 1.0 else target
	_trauma = maxf(_trauma - SHAKE_DECAY * delta, 0.0)
	var shake := _trauma * _trauma
	var offset := Vector3(
		_noise.get_noise_2d(_time * 25.0, 0.0),
		_noise.get_noise_2d(_time * 25.0, 50.0),
		0.0) * SHAKE_MAX_OFFSET * shake
	var roll := _noise.get_noise_2d(_time * 25.0, 100.0) * SHAKE_MAX_ROLL * shake
	var breath := Vector3(0, sin(_time * 1.1) * BREATH_AMPLITUDE, 0)
	var target_parallax := Vector2.ZERO
	if parallax_enabled:
		var vp := get_viewport()
		var size := vp.get_visible_rect().size
		if size.x > 0.0:
			target_parallax = (vp.get_mouse_position() / size - Vector2(0.5, 0.5)) * 2.0
	_parallax = _parallax.lerp(target_parallax.clamp(-Vector2.ONE, Vector2.ONE), minf(delta * 3.0, 1.0))
	camera.position = offset + breath
	camera.rotation = Vector3(-_parallax.y * PARALLAX_PITCH + sin(_time * 0.7) * 0.003,
		-_parallax.x * PARALLAX_YAW, roll)


# —— 机位 ——

func move_to(target: Transform3D, duration: float, trans := Tween.TRANS_CUBIC,
		ease := Tween.EASE_IN_OUT) -> Tween:
	_orbit_active = false
	_follow = Callable()
	_kill(_move_tween)
	var from := global_transform
	_move_tween = create_tween()
	_move_tween.tween_method(func(t: float): global_transform = from.interpolate_with(target, t),
		0.0, 1.0, maxf(duration, 0.001)).set_trans(trans).set_ease(ease)
	return _move_tween


func look_from(pos: Vector3, target: Vector3, duration: float, trans := Tween.TRANS_CUBIC,
		ease := Tween.EASE_IN_OUT) -> Tween:
	return move_to(_look(pos, target), duration, trans, ease)


func snap(pos: Vector3, target: Vector3) -> void:
	_orbit_active = false
	_follow = Callable()
	_kill(_move_tween)
	global_transform = _look(pos, target)


func orbit(center: Vector3, radius: float, height: float, speed: float, blend := 2.0,
		start_angle := NAN) -> void:
	# 先平滑移到环绕轨道上的起始角度(默认 = 镜头当前所在方位),再开始匀速环绕
	_orbit_center = center
	_orbit_radius = radius
	_orbit_height = height
	_orbit_speed = speed
	var rel := global_position - center
	_orbit_angle = atan2(rel.x, rel.z) if is_nan(start_angle) else start_angle
	var start := center + Vector3(sin(_orbit_angle) * radius, height, cos(_orbit_angle) * radius)
	var tween := look_from(start, center, blend)
	tween.finished.connect(func(): _orbit_active = true)


func follow(source: Callable, duration: float, trans := Tween.TRANS_CUBIC, ease := Tween.EASE_IN_OUT) -> Tween:
	# 跟随一个会动的机位(source 每帧返回目标变换):先在 duration 内从当前机位平滑过渡过去,之后每帧贴着它走。
	# move_to / snap / orbit 会停止跟随。返回过渡用的补间(可 await .finished)
	_orbit_active = false
	_kill(_move_tween)
	_follow = source
	_follow_from = global_transform
	_follow_weight = 0.0
	_move_tween = create_tween()
	_move_tween.tween_property(self, "_follow_weight", 1.0, maxf(duration, 0.001)).set_trans(trans).set_ease(ease)
	return _move_tween


func is_following(source := Callable()) -> bool:
	# 正在跟随(给了 source 时:正在跟随它)
	return _follow.is_valid() and (source.is_null() or _follow == source)


func stop_follow(source := Callable()) -> void:
	# 停在当前位置不再跟随(给了 source 时:只在跟随的正是它时才停)
	if is_following(source):
		_follow = Callable()


func set_fill(energy: float, duration := 0.6) -> void:
	_kill(_fill_tween)
	_fill_tween = create_tween()
	_fill_tween.tween_property(fill_light, "light_energy", energy, duration)


func set_fov(fov: float, duration: float) -> void:
	_kill(_fov_tween)
	_fov_tween = create_tween()
	_fov_tween.tween_property(camera, "fov", fov, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func shake(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


static func _look(pos: Vector3, target: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(target - pos, Vector3.UP), pos)


func _kill(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()
