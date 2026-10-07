class_name DealerButton3D
extends Node3D
# 庄家按钮:白色圆片写「D」。字按本机视角正立(同桌上的牌);换座位时绕桌心沿圆弧滑过去,
# 直线会从公共牌架上穿过。


const RADIUS := 0.05
const THICKNESS := 0.014
const FACE := Color(0.95, 0.93, 0.88)
const RIM := Color(0.72, 0.7, 0.66)
const INK := Color(0.12, 0.09, 0.07)
const LETTER_PIXEL := 0.0005       # Label3D 每像素多少米:96 号字约 4.8 厘米高
const LETTER_FONT_SIZE := 96
const LETTER_LIFT := 0.0006        # 字贴在顶面上方一点,免得与顶面 Z 冲突

var _tween: Tween = null


func _init() -> void:
	var face := StandardMaterial3D.new()
	face.albedo_color = FACE
	face.roughness = 0.35
	var rim := StandardMaterial3D.new()
	rim.albedo_color = RIM
	rim.roughness = 0.5
	var disc := MeshKit.add(self, MeshKit.cylinder(RADIUS, RADIUS, THICKNESS, 40), rim, Vector3(0, THICKNESS / 2.0, 0))
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var top := MeshKit.add(self, MeshKit.cylinder(RADIUS * 0.86, RADIUS * 0.86, 0.002, 40), face,
		Vector3(0, THICKNESS + 0.001, 0))
	top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var letter := Label3D.new()
	letter.text = "D"
	letter.font_size = LETTER_FONT_SIZE
	letter.pixel_size = LETTER_PIXEL
	letter.modulate = INK
	letter.outline_size = 0
	letter.shaded = true
	letter.double_sided = false
	# 平躺在顶面上:字面朝上,字头朝 −Z(本机视角正立)
	letter.rotation_degrees = Vector3(-90, 0, 0)
	letter.position = Vector3(0, THICKNESS + 0.002 + LETTER_LIFT, 0)
	add_child(letter)


func move_to(target: Vector3, duration: float) -> Tween:
	# 绕桌心按角度与半径插值滑到目标;duration ≤ 0 时直接落位(返回 null)
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if duration <= 0.0:
		position = target
		return null
	var from := position
	var from_angle := TableWorld.angle_of(from)
	var to_angle := TableWorld.angle_of(target)
	var from_radius := Vector2(from.x, from.z).length()
	var to_radius := Vector2(target.x, target.z).length()
	_tween = create_tween()
	_tween.tween_method(func(t: float):
		var flat := SeatLayout.direction(lerp_angle(from_angle, to_angle, t)) * lerpf(from_radius, to_radius, t)
		position = Vector3(flat.x, lerpf(from.y, target.y, t), flat.z),
		0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	return _tween
