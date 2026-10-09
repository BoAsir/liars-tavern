class_name PatronHats
# 酒客的帽子(帽子坐标:原点在帽底中心,+Y 朝上,-Z 朝前;尺寸已乘物种表的 size)。
# 帽檐、帽冠都是回转体剖面再变形:帽檐两侧上卷、牛仔帽冠顶压出中缝与前面两个捏痕、鸭舌帽前倾;
# 帽冠底部封一片内衬,出局时帽子被打飞翻过来也看得到帽里,不会透空。


const SEGMENTS := 32
# 剖面 (半径, 高度),沿剖面走时外侧在右手边
const TOP_BRIM := [Vector2(0.085, -0.004), Vector2(0.15, -0.004), Vector2(0.158, 0.003), Vector2(0.151, 0.009), Vector2(0.092, 0.007)]
const TOP_CROWN := [Vector2(0.094, 0.0), Vector2(0.091, 0.07), Vector2(0.096, 0.168), Vector2(0.098, 0.182), Vector2(0.092, 0.19), Vector2(0.0, 0.192)]
const TOP_BAND := Vector3(0.0935, 0.008, 0.042)        # (贴着帽冠的半径, 下沿, 上沿)
const BOWLER_BRIM := [Vector2(0.09, -0.003), Vector2(0.14, -0.003), Vector2(0.148, 0.004), Vector2(0.142, 0.01), Vector2(0.1, 0.006)]
const BOWLER_CROWN := [Vector2(0.104, 0.0), Vector2(0.106, 0.04), Vector2(0.1, 0.082), Vector2(0.083, 0.116), Vector2(0.05, 0.137), Vector2(0.0, 0.144)]
const BOWLER_BAND := Vector3(0.1055, 0.006, 0.03)
const COWBOY_BRIM := [Vector2(0.08, -0.004), Vector2(0.236, -0.004), Vector2(0.243, 0.003), Vector2(0.237, 0.008), Vector2(0.09, 0.006)]
const COWBOY_CROWN := [Vector2(0.086, 0.0), Vector2(0.089, 0.06), Vector2(0.085, 0.108), Vector2(0.07, 0.128), Vector2(0.0, 0.126)]
const COWBOY_BAND := Vector3(0.0885, 0.006, 0.027)
const VISOR_INNER := 0.13      # 鸭舌帽帽舌:内外半径、左右张角(弧度)、前端下弯、整片上翘(弧度)
const VISOR_OUTER := 0.215
const VISOR_SPAN := 0.95
const VISOR_DROOP := 0.022
const VISOR_LIFT := 0.12
const VISOR_POINTS := 10
const CAP_CROWN := [Vector2(0.0, -0.002), Vector2(0.128, -0.002), Vector2(0.15, 0.012), Vector2(0.146, 0.03), Vector2(0.112, 0.05), Vector2(0.05, 0.062), Vector2(0.0, 0.064)]


static func build(spec: Dictionary) -> Array:
	var h: Dictionary = spec["hat"]
	var size: float = h.get("size", 1.0)
	var parts := []
	match h["kind"]:
		"top":
			parts = _classic(TOP_BRIM, TOP_CROWN, TOP_BAND, 0.024, 0.0, 0.9)
		"bowler":
			parts = _classic(BOWLER_BRIM, BOWLER_CROWN, BOWLER_BAND, 0.028, 0.0, 0.92)
		"cowboy":
			parts = _cowboy()
		"cap":
			parts = _cap()
	var hat := PatronGeo.concat(parts)
	return PatronGeo.transformed(hat, Transform3D(Basis().scaled(Vector3.ONE * size), Vector3.ZERO))


static func _classic(brim: Array, crown: Array, band: Vector3, curl: float, droop: float, oval: float) -> Array:
	# 礼帽、圆顶礼帽:椭圆的帽冠 + 两侧上卷的帽檐 + 一圈缎带 + 帽里
	var squash := Transform3D(Basis().scaled(Vector3(1, 1, oval)), Vector3.ZERO)
	var outer: float = brim[1].x
	return [
		_tagged(PatronGeo.transformed(_curled(_lathe(brim), crown[0].x, outer, curl, droop), squash), PatronSkin.HAT),
		_tagged(PatronGeo.transformed(_lathe(crown), squash), PatronSkin.HAT),
		_tagged(PatronGeo.transformed(_band(band), squash), PatronSkin.HAT_BAND),
		_tagged(PatronGeo.transformed(_lining(crown[0].x), squash), PatronSkin.LINING),
	]


static func _cowboy() -> Array:
	# 牛仔帽:宽檐两侧高高卷起、前后微微下垂;帽冠顶上一道中缝、前面两侧捏扁;帽带上一枚镶石的银扣
	var crown := MeshShapes.deform(_lathe(COWBOY_CROWN), func(v: Vector3) -> Vector3:
		var top := smoothstep(0.075, 0.125, v.y)
		var crease := 0.022 * exp(-pow(v.x / 0.03, 2.0)) * top
		var pinch := 1.0 - 0.2 * smoothstep(0.05, 0.12, v.y) * smoothstep(0.0, -0.085, v.z)
		return Vector3(v.x * pinch, v.y - crease, v.z))
	var squash := Transform3D(Basis().scaled(Vector3(1, 1, 0.88)), Vector3.ZERO)
	var concho := PatronGeo.frame_at(Vector3(-0.055, 0.017, -0.07), Vector3(-0.6, 0, -0.8))
	return [
		_tagged(PatronGeo.transformed(_curled(_lathe(COWBOY_BRIM), 0.086, 0.236, 0.075, 0.014), squash), PatronSkin.HAT),
		_tagged(PatronGeo.transformed(crown, squash), PatronSkin.HAT),
		_tagged(PatronGeo.transformed(_band(COWBOY_BAND), squash), PatronSkin.HAT_BAND),
		_tagged(PatronGeo.transformed(_lining(0.086), squash), PatronSkin.LINING),
		_tagged(PatronGeo.transformed(PatronGeo.sphere(Vector3(0.011, 0.011, 0.003), 10, 5), concho), PatronSkin.BRASS),
		_tagged(PatronGeo.transformed(PatronGeo.sphere(Vector3(0.005, 0.005, 0.003), 8, 4),
			concho.translated_local(Vector3(0, 0, -0.002))), PatronSkin.STONE),
	]


static func _cap() -> Array:
	# 鸭舌帽(报童帽):蓬松的帽顶往前探,前面一片下弯的帽舌,顶上一颗包布扣
	var crown := MeshShapes.deform(_lathe(CAP_CROWN), func(v: Vector3) -> Vector3:
		var lift := v.y / 0.064
		return Vector3(v.x * 1.03, v.y + 0.008 * smoothstep(0.0, -0.12, v.z), v.z - 0.03 * lift))
	var visor_outline := PackedVector2Array()
	for i in VISOR_POINTS + 1:
		var a := lerpf(-VISOR_SPAN, VISOR_SPAN, float(i) / VISOR_POINTS)
		visor_outline.append(Vector2(sin(a) * VISOR_OUTER, cos(a) * VISOR_OUTER))
	for i in VISOR_POINTS + 1:
		var a := lerpf(VISOR_SPAN, -VISOR_SPAN, float(i) / VISOR_POINTS)
		visor_outline.append(Vector2(sin(a) * VISOR_INNER, cos(a) * VISOR_INNER))
	# 帽舌往前略微下弯;整片抬在帽口上方一点,低头的帽子前沿也不会扎进额头
	var visor := MeshShapes.deform(MeshShapes.extrude(visor_outline, 0.007, 0.002), func(v: Vector3) -> Vector3:
		return Vector3(v.x, v.y, v.z - VISOR_DROOP * pow(maxf(v.y - VISOR_INNER, 0.0) / (VISOR_OUTER - VISOR_INNER), 2.0)))
	var visor_place := Transform3D(Basis(Vector3.RIGHT, -PI / 2.0).rotated(Vector3.RIGHT, VISOR_LIFT), Vector3(0, 0.012, 0.0))
	return [
		_tagged(crown, PatronSkin.HAT),
		_tagged(PatronGeo.transformed(visor, visor_place), PatronSkin.HAT),
		_tagged(PatronGeo.sphere(Vector3(0.013, 0.007, 0.013), 10, 5), PatronSkin.HAT_BAND, Vector3(0, 0.063, -0.028)),
	]


# —— 工具 ——

static func _lathe(profile: Array) -> Array:
	return MeshShapes.lathe(PackedVector2Array(profile), SEGMENTS)


static func _curled(arrays: Array, inner: float, outer: float, curl: float, droop: float) -> Array:
	# 帽檐变形:越往外越翘,左右两侧上卷(curl),前后下垂(droop)
	return MeshShapes.deform(arrays, func(v: Vector3) -> Vector3:
		var r := Vector2(v.x, v.z).length()
		var k := smoothstep(inner, outer, r)
		var side := v.x * v.x / maxf(r * r, 1e-6)
		return Vector3(v.x, v.y + k * k * (curl * side - droop * (1.0 - side)), v.z))


static func _band(band: Vector3) -> Array:
	# 帽带:贴着帽冠外面的一圈,略鼓出来
	var r := band.x
	var profile := [Vector2(r, band.y), Vector2(r + 0.0022, band.y + 0.001), Vector2(r + 0.0018, band.z - 0.001), Vector2(r - 0.0005, band.z)]
	return _lathe(profile)


static func _lining(radius: float) -> Array:
	# 帽里:帽冠底部朝下的一片圆
	return _lathe([Vector2(0.0, 0.002), Vector2(radius, 0.002)])


static func _tagged(arrays: Array, slot: int, offset := Vector3.ZERO) -> Array:
	var moved := PatronGeo.transformed(arrays, Transform3D(Basis(), offset)) if offset != Vector3.ZERO else arrays
	return PatronGeo.colored(moved, func(_v: Vector3) -> Color: return PatronSkin.tag(slot))
