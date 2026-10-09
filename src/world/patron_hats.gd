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
# 草编平顶硬草帽(兔子):平顶直筒 + 平直的帽檐 + 宽缎带;耳朵从帽顶两个洞里穿出来
const BOATER_BRIM := [Vector2(0.084, -0.003), Vector2(0.152, -0.003), Vector2(0.157, 0.002), Vector2(0.152, 0.007), Vector2(0.09, 0.005)]
const BOATER_CROWN := [Vector2(0.088, 0.0), Vector2(0.088, 0.054), Vector2(0.085, 0.059), Vector2(0.0, 0.06)]
const BOATER_BAND := Vector3(0.0885, 0.005, 0.03)
# 软呢帽(浣熊):帽冠顶压一道中缝、前面两侧捏扁;帽檐前低后翘;帽带上插一根羽毛
const FEDORA_BRIM := [Vector2(0.088, -0.003), Vector2(0.158, -0.003), Vector2(0.163, 0.003), Vector2(0.157, 0.008), Vector2(0.094, 0.006)]
const FEDORA_CROWN := [Vector2(0.094, 0.0), Vector2(0.095, 0.05), Vector2(0.088, 0.094), Vector2(0.07, 0.112), Vector2(0.0, 0.108)]
const FEDORA_BAND := Vector3(0.0945, 0.006, 0.03)
const FEDORA_SNAP := Vector2(0.026, 0.02)     # 帽檐前沿下压、后沿上翘的高度
# 土耳其毡帽(猫头鹰):往上略收的平顶圆台 + 顶上的扣子 + 一绺甩到一侧的流苏
const FEZ := [Vector2(0.0, 0.0), Vector2(0.068, 0.0), Vector2(0.069, 0.003), Vector2(0.057, 0.084), Vector2(0.054, 0.088), Vector2(0.0, 0.089)]
const TASSEL := [Vector3(0, 0.09, 0), Vector3(0.03, 0.094, 0.006), Vector3(0.056, 0.082, 0.014), Vector3(0.066, 0.052, 0.018)]
# 荷叶(青蛙):边缘往下垂的圆叶,缺一个楔形口;叶脉放射;叶上开一朵小荷花
const PAD_RADII := [0.0, 0.035, 0.07, 0.1, 0.122]
const PAD_THICK := 0.0045
const PAD_DROOP := 1.6           # 叶面下垂:y -= PAD_DROOP × 半径²
const PAD_NOTCH := 0.42          # 缺口的张角(弧度)
const PAD_VEINS := 9
const LOTUS_AT := Vector3(0.035, 0.0, -0.03)   # 荷花开在叶子前右侧,从正面越过眼睛也看得到
const PETAL_ASPECT := 0.33       # 花瓣宽 = 长 × 这个比例
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
		"boater":
			parts = _classic(BOATER_BRIM, BOATER_CROWN, BOATER_BAND, 0.0, 0.0, 0.94)
		"fedora":
			parts = _fedora()
		"fez":
			parts = _fez()
		"lilypad":
			parts = _lilypad()
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


static func _fedora() -> Array:
	var crown := MeshShapes.deform(_lathe(FEDORA_CROWN), func(v: Vector3) -> Vector3:
		var top := smoothstep(0.07, 0.108, v.y)
		var crease := 0.024 * exp(-pow(v.x / 0.032, 2.0)) * top
		var pinch := 1.0 - 0.18 * smoothstep(0.045, 0.1, v.y) * smoothstep(0.0, -0.09, v.z)
		return Vector3(v.x * pinch, v.y - crease, v.z))
	var brim := MeshShapes.deform(_lathe(FEDORA_BRIM), func(v: Vector3) -> Vector3:
		# 前沿往下"啪"地压下去,后沿翘起,两侧基本平
		var r := Vector2(v.x, v.z).length()
		var k := smoothstep(0.094, 0.16, r)
		var along := v.z / maxf(r, 1e-6)
		return Vector3(v.x, v.y + k * k * (FEDORA_SNAP.y * maxf(along, 0.0) - FEDORA_SNAP.x * maxf(-along, 0.0)), v.z))
	var squash := Transform3D(Basis().scaled(Vector3(1, 1, 0.9)), Vector3.ZERO)
	var feather := PatronGeo.sphere(Vector3(0.0055, 0.045, 0.0018), 10, 8)
	var feather_place := Transform3D(Basis(Vector3.BACK, 0.75) * Basis(Vector3.RIGHT, -0.5), Vector3(-0.098, 0.04, 0.035))
	return [
		_tagged(PatronGeo.transformed(brim, squash), PatronSkin.HAT),
		_tagged(PatronGeo.transformed(crown, squash), PatronSkin.HAT),
		_tagged(PatronGeo.transformed(_band(FEDORA_BAND), squash), PatronSkin.HAT_BAND),
		_tagged(PatronGeo.transformed(_lining(0.094), squash), PatronSkin.LINING),
		_tagged(PatronGeo.transformed(feather, feather_place), PatronSkin.PETAL),
	]


static func _fez() -> Array:
	var tassel := PatronGeo.smooth_path(PackedVector3Array(TASSEL), 3)
	var cord := MeshShapes.tube(tassel, 0.0022, 6, false)
	var tip: Vector3 = TASSEL[TASSEL.size() - 1]
	var threads := MeshShapes.lathe(PackedVector2Array([Vector2(0.0, -0.034), Vector2(0.009, -0.03), Vector2(0.006, -0.012),
		Vector2(0.0025, 0.0)]), 10)
	return [
		_tagged(_lathe(FEZ), PatronSkin.HAT),
		_tagged(PatronGeo.sphere(Vector3(0.007, 0.004, 0.007), 8, 4), PatronSkin.HAT_BAND, Vector3(0, 0.089, 0)),
		_tagged(cord, PatronSkin.HAT_BAND),
		_tagged(threads, PatronSkin.HAT_BAND, tip),
		_tagged(_lining(0.068), PatronSkin.LINING),
	]


static func _lilypad() -> Array:
	# 荷叶:多圈剖面的回转体(缺一个楔形口),半径越大垂得越低,软软地搭在头顶
	var outline := PackedVector2Array([Vector2(0, 0)])
	for r in PAD_RADII.slice(1):
		outline.append(Vector2(r, 0.0))
	outline.append(Vector2(PAD_RADII[-1] + 0.002, PAD_THICK * 0.5))
	for i in range(PAD_RADII.size() - 1, -1, -1):
		outline.append(Vector2(PAD_RADII[i], PAD_THICK))
	var droop := func(v: Vector3) -> Vector3: return Vector3(v.x, v.y - PAD_DROOP * (v.x * v.x + v.z * v.z), v.z)
	var turn := Transform3D(Basis(Vector3.UP, 2.3), Vector3.ZERO)   # 缺口转到左后方
	var leaf := MeshShapes.deform(PatronGeo.transformed(MeshShapes.lathe(outline, 28, TAU - PAD_NOTCH), turn), droop)
	var parts := [_tagged(leaf, PatronSkin.HAT)]
	for k in PAD_VEINS:
		var a := 2.3 + (TAU - PAD_NOTCH) * (k + 0.5) / PAD_VEINS
		var path := PackedVector3Array()
		for i in 5:
			var r: float = 0.012 + 0.1 * i / 4.0
			path.append(droop.call(Vector3(cos(a) * r, PAD_THICK + 0.0006, -sin(a) * r)))
		parts.append(_tagged(MeshShapes.tube(path, 0.0011, 4, false), PatronSkin.HAT_BAND))
	parts.append_array(_lotus(droop.call(LOTUS_AT) + Vector3(0, PAD_THICK, 0)))
	return parts


static func _lotus(at: Vector3) -> Array:
	# 荷花:外圈六片、内圈五片往上翘的花瓣 + 金色花心
	var parts := []
	for ring in [[6, 0.036, 0.5, 0.0], [5, 0.026, 0.95, 0.5]]:
		var count: int = ring[0]
		var length: float = ring[1]
		var rise: float = ring[2]
		var offset: float = ring[3]
		for k in count:
			var a := TAU * (k + offset) / count
			var petal := PatronGeo.sphere(Vector3(length * PETAL_ASPECT, 0.0035, length * 0.5), 8, 5)
			var tilt := Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, rise)
			parts.append(_tagged(PatronGeo.transformed(petal, Transform3D(tilt, at + tilt * Vector3(0, 0, -length * 0.45))),
				PatronSkin.PETAL))
	parts.append(_tagged(PatronGeo.sphere(Vector3(0.008, 0.005, 0.008), 8, 5), PatronSkin.BRASS, at + Vector3(0, 0.007, 0)))
	return parts


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
