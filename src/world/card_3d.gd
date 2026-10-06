class_name Card3D
extends Node3D
# 3D 卡牌:正反两面四边形(本地 +Y 为正面法线,宽沿 X、高沿 Z,牌顶朝 -Z)。
# 支持翻面、弧线飞行、悬停抬起、选中高亮,以及射线拾取(纯数学,无需物理体)。


const WIDTH := 0.12
const HEIGHT := 0.1733
const GAP := 0.0007
const CARD_SHADER := preload("res://src/world/shaders/card.gdshader")

static var _materials := {}

var kind := CardFaces.BACK     # 正面牌型;BACK 表示未知(他人的牌)
var _front: MeshInstance3D
var _back: MeshInstance3D
var _glow_tween: Tween = null


static func material_for(face_kind: int) -> ShaderMaterial:
	if not _materials.has(face_kind):
		var mat := ShaderMaterial.new()
		mat.shader = CARD_SHADER
		mat.set_shader_parameter("card_texture", CardFaces.texture(face_kind))
		_materials[face_kind] = mat
	return _materials[face_kind]


static func clear_materials() -> void:
	_materials = {}


static func refresh_materials() -> void:
	# 牌面纹理异步生成完毕后刷新已缓存的材质
	for face_kind in _materials:
		_materials[face_kind].set_shader_parameter("card_texture", CardFaces.texture(face_kind))


func _init() -> void:
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(WIDTH, HEIGHT)
	_front = MeshInstance3D.new()
	_front.mesh = mesh
	_front.position.y = GAP
	_front.material_override = material_for(CardFaces.BACK)
	add_child(_front)
	_back = MeshInstance3D.new()
	_back.mesh = mesh
	_back.position.y = -GAP
	_back.rotation.z = PI
	_back.material_override = material_for(CardFaces.BACK)
	add_child(_back)
	set_glow(0.0)


func set_kind(face_kind: int) -> void:
	kind = face_kind
	_front.material_override = material_for(face_kind)


func set_both_faces(face_kind: int) -> void:
	# 桌心立牌:两面都显示目标牌,旋转时任何角度都看得到
	set_kind(face_kind)
	_back.material_override = material_for(face_kind)


func set_glow(amount: float, color := Color(1.0, 0.82, 0.4)) -> void:
	for mesh in [_front, _back]:
		mesh.set_instance_shader_parameter("glow", amount)
		mesh.set_instance_shader_parameter("glow_color", color)


func pulse_glow(color: Color, peak: float, duration: float) -> void:
	if _glow_tween != null and _glow_tween.is_valid():
		_glow_tween.kill()
	_glow_tween = create_tween()
	_glow_tween.tween_method(func(v: float): set_glow(v, color), 0.0, peak, duration * 0.25)
	_glow_tween.tween_method(func(v: float): set_glow(v, color), peak, peak * 0.45, duration * 0.75)


func fly_to(target: Transform3D, duration: float, arc_height := 0.12, spin := 0.0) -> Tween:
	# 二次贝塞尔弧线飞行;旋转用四元数插值,可附加绕法线的旋转
	var from := global_transform
	var mid := (from.origin + target.origin) / 2.0 + Vector3.UP * arc_height
	var from_q := from.basis.get_rotation_quaternion()
	var to_q := target.basis.get_rotation_quaternion()
	var to_scale := target.basis.get_scale()
	var from_scale := from.basis.get_scale()
	var tween := create_tween()
	tween.tween_method(func(t: float):
		var p := from.origin.lerp(mid, t).lerp(mid.lerp(target.origin, t), t)
		var q := from_q.slerp(to_q, t)
		if spin != 0.0:
			q = q * Quaternion(Vector3.UP, spin * sin(t * PI))
		global_transform = Transform3D(Basis(q).scaled(from_scale.lerp(to_scale, t)), p),
		0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween


func flip_to_face(duration: float, lift := 0.05) -> Tween:
	# 抬起 → 绕牌的纵轴翻转 180° → 落下
	var start := transform
	var tween := create_tween()
	tween.tween_method(func(t: float):
		var angle := PI * t
		var offset := Vector3.UP * sin(t * PI) * lift
		transform = Transform3D(start.basis * Basis(Vector3.BACK, angle), start.origin + offset),
		0.0, 1.0, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	return tween


func ray_hit_distance(origin: Vector3, direction: Vector3) -> float:
	# 射线与牌面矩形求交:返回沿射线距离,未命中返回 -1
	var inv := global_transform.affine_inverse()
	var local_origin := inv * origin
	var local_dir := inv.basis * direction
	if absf(local_dir.y) < 0.00001:
		return -1.0
	var t := -local_origin.y / local_dir.y
	if t <= 0.0:
		return -1.0
	var hit := local_origin + local_dir * t
	if absf(hit.x) > WIDTH / 2.0 or absf(hit.z) > HEIGHT / 2.0:
		return -1.0
	return (global_transform * hit).distance_to(origin)
