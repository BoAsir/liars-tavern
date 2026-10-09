class_name PatronEars
# 酒客的耳朵(耳朵枢轴坐标:原点在耳根,+Y 沿耳朵往上,-Z 朝前)。
# 耳廓是一圈"月牙形"截面从耳根扫到耳尖:正面凹进去(耳窝)、背面鼓出来;耳窝里铺一片内耳色,
# 狐狸、猫的耳窝里再长几簇浅色绒毛;狐狸耳尖是深色的。耳朵枢轴绕 X 轴转 = 抖耳朵、表情时耷拉。


const AROUND := 14
const ALONG := 8
const DEPTH := 0.016          # 耳根处的厚度
const CUP := 0.36             # 耳窝凹进去的深度(占半宽比例)
const SINK := 0.012           # 耳根埋进头里多少,和头接得上
const INNER_LIFT := 0.0013    # 内耳色贴在耳窝上方一点


static func pivot(spec: Dictionary, shape: Callable, side: float) -> Transform3D:
	# 耳根处的局部坐标系(头部坐标):Y 沿头顶表面法线,-Z 朝前;再按物种外倾(tilt)、前后倒(lean)
	var e: Dictionary = spec["ears"]
	var yaw: float = side * e["yaw"]
	var n := PatronHead.normal(shape, yaw, e["pitch"])
	var origin := PatronHead.point(shape, yaw, e["pitch"]) - n * SINK
	var forward := (Vector3.FORWARD - n * Vector3.FORWARD.dot(n)).normalized()
	var basis := Basis.looking_at(forward, n)
	basis = basis * Basis(Vector3.BACK, -side * deg_to_rad(e["tilt"])) * Basis(Vector3.RIGHT, deg_to_rad(e["lean"]))
	return Transform3D(basis, origin)


static func ear(spec: Dictionary) -> Array:
	var e: Dictionary = spec["ears"]
	var kind: String = e["kind"]
	var h: float = e["height"]
	var w: float = e["width"]
	var tip: float = e.get("tip", 0.0)
	var bend: float = e.get("bend", 0.0)
	var at := func(a: float, t: float) -> Vector3: return _shell_point(kind, h, w, bend, a, t)
	var shell := PatronGeo.grid(func(s: float, t: float) -> Vector3: return at.call(s * TAU, t),
		AROUND, ALONG, Vector3(0, h * 0.3, DEPTH), true)
	var parts := [PatronGeo.colored(shell, func(v: Vector3) -> Color:
		var dark := smoothstep(1.0 - tip - 0.1, 1.0 - tip + 0.06, v.y / h) if tip > 0.0 else 0.0
		return PatronSkin.tag(PatronSkin.FUR, 0.0, dark))]
	var inner_slot: int = PatronSkin.SLOT_NAMES[e.get("inner", "inner")]
	var inner := PatronGeo.grid(func(s: float, t: float) -> Vector3:
			return at.call(lerpf(0.22, 0.78, s) * PI, lerpf(0.05, 0.8, t)) + Vector3(0, 0, -INNER_LIFT),
		6, 7, Vector3(0, h * 0.3, DEPTH * 2.0))
	parts.append(PatronGeo.colored(inner, func(_v: Vector3) -> Color: return PatronSkin.tag(inner_slot)))
	if e.get("tuft", false):
		parts.append(_tufts(h, w))
	return PatronGeo.concat(parts)


static func _shell_point(kind: String, h: float, w: float, bend: float, a: float, t: float) -> Vector3:
	# a:绕截面一圈的角度(sin a > 0 为正面);t:耳根 0 → 耳尖 1
	var half_w := w * 0.5 * _width(kind, t)
	var half_d := DEPTH * 0.5 * (1.0 - 0.6 * t)
	var s := sin(a)
	var p := Vector3(half_w * cos(a), t * h, -half_d * s + CUP * half_w * s * s)
	if bend != 0.0:
		p = Basis(Vector3.RIGHT, bend * t * t) * p
	return p


static func _width(kind: String, t: float) -> float:
	# 耳廓宽度随高度的变化(1 = 耳根全宽):尖耳两侧略外鼓,圆耳是半圆,垂耳是宽叶片
	match kind:
		"round":
			return sqrt(maxf(1.0 - t * t, 0.0))
		"floppy":
			return pow(1.0 - t, 1.1) * (1.0 + 0.35 * sin(PI * t))
		"cat":
			return pow(1.0 - t, 0.9) * (1.0 + 0.18 * sin(PI * t))
	return pow(1.0 - t, 0.85) * (1.0 + 0.25 * sin(PI * t))


static func _tufts(h: float, w: float) -> Array:
	# 耳窝里往上、往外翘的几簇浅色绒毛
	var parts := []
	for k in 3:
		var x := (k - 1) * w * 0.16
		var path := PackedVector3Array([Vector3(x, h * 0.06, -0.001), Vector3(x * 1.3, h * 0.22, -0.004),
			Vector3(x * 1.9 + (k - 1) * 0.003, h * 0.38 - absf(k - 1) * h * 0.07, -0.006)])
		var tube := MeshShapes.tube(PatronGeo.smooth_path(path, 3), PatronGeo.resample(PackedFloat32Array([0.0042, 0.003, 0.0003]), 7),
			6, false)
		parts.append(PatronGeo.colored(tube, func(_v: Vector3) -> Color: return PatronSkin.tag(PatronSkin.FUR, 1.0)))
	return PatronGeo.concat(parts)
