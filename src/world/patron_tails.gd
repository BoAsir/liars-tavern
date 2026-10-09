class_name PatronTails
# 酒客的尾巴(座位坐标,数组以尾根 root() 为原点;Patron 在尾根处挂一个枢轴让尾巴轻轻摆)。
# 尾巴从臀后出来,贴着椅面上方绕到椅子侧面再垂下(side 决定哪一侧),全程不穿过椅子的包络:
# 椅面 x∈[-0.24,0.24]、y∈[0.42,0.48]、z∈[-0.08,0.36];椅背 y∈[0.48,1.1]、z∈[0.30,0.38]。
# 控制点按右侧(+X)给出,side = -1 时左右镜像。


# 蓬松大尾巴(狐狸):[控制点, 半径];中段最粗,末端一截浅色、收成圆润的尖
const BUSHY := [
	[Vector3(0.05, 0.575, 0.2), 0.03], [Vector3(0.17, 0.585, 0.228), 0.05], [Vector3(0.27, 0.575, 0.222), 0.064],
	[Vector3(0.345, 0.51, 0.225), 0.076], [Vector3(0.37, 0.385, 0.185), 0.084], [Vector3(0.362, 0.26, 0.125), 0.084],
	[Vector3(0.338, 0.155, 0.045), 0.078], [Vector3(0.312, 0.118, -0.055), 0.066], [Vector3(0.292, 0.15, -0.13), 0.048],
	[Vector3(0.282, 0.198, -0.162), 0.024], [Vector3(0.28, 0.215, -0.17), 0.0],
]
# 细长尾巴(猫):垂到地面附近再往上勾成问号
const SLENDER := [
	[Vector3(0.05, 0.57, 0.2), 0.026], [Vector3(0.17, 0.575, 0.24), 0.025], [Vector3(0.275, 0.55, 0.24), 0.024],
	[Vector3(0.305, 0.43, 0.21), 0.023], [Vector3(0.305, 0.29, 0.17), 0.022], [Vector3(0.295, 0.16, 0.1), 0.021],
	[Vector3(0.285, 0.105, 0.0), 0.02], [Vector3(0.29, 0.14, -0.08), 0.019], [Vector3(0.295, 0.24, -0.1), 0.018],
	[Vector3(0.295, 0.3, -0.075), 0.0],
]
const CURL_ROOT := Vector3(0.2, 0.575, 0.24)   # 猪尾:从臀侧伸出,在椅面外侧卷两圈半
const CURL_TURNS := 2.5
const CURL_COIL := 0.017
const PUFF_ROOT := Vector3(0.0, 0.535, 0.248)  # 兔子的绒球尾巴:坐在臀后、椅背前的空当里
const PUFF_LUMPS := 0.13      # 绒球表面一团团的起伏
const FLUFF := 0.11           # 大尾巴表面一绺绺毛的起伏(占半径比例)
const CLUMP := 0.05           # 沿尾巴一簇簇毛的粗细起伏
const TIP_RAGGED := 0.035     # 浅色尾尖边缘的参差(沿程比例)
const RING_EDGE := 0.2        # 环纹边缘的软硬(sin 值的过渡宽度)与随角度的轻微倾斜
const RING_WOBBLE := 0.5
const SIDES := 12
const BUSHY_SIDES := 16
const PER_SEGMENT := 3
const BUSHY_PER_SEGMENT := 4


static func root(spec: Dictionary) -> Vector3:
	var t: Dictionary = spec.get("tail", {})
	var side: float = t.get("side", 1.0)
	match t.get("kind", ""):
		"bushy":
			return BUSHY[0][0] * Vector3(side, 1, 1)
		"slender":
			return SLENDER[0][0] * Vector3(side, 1, 1)
		"curl":
			return CURL_ROOT * Vector3(side, 1, 1)
		"puff":
			return PUFF_ROOT
	return Vector3.ZERO


static func puff(t: Dictionary) -> Array:
	# 兔子尾巴:一团蓬松的浅色绒球(表面几团起伏,不是光溜溜的球)
	var r: float = t.get("radius", 0.045)
	var arrays := PatronGeo.ellipsoid_fn(func(d: Vector3) -> Vector3:
		var lon := atan2(d.x, d.z)
		var lumps := sin(lon * 5.0 + d.y * 3.0) * sin(d.y * 6.0 + lon) * PUFF_LUMPS
		return d * r * (1.0 + lumps) * Vector3(1.0, 0.95, 0.85), 14, 10)
	return PatronGeo.colored(arrays, func(_v: Vector3) -> Color: return PatronSkin.tag(PatronSkin.FUR, 1.0))


static func bushy(t: Dictionary) -> Array:
	var scale: float = t.get("radius", 0.084) / 0.084
	var tip: float = t.get("tip", 0.0)
	var rings: float = t.get("rings", 0)      # 浣熊:一圈圈深色环纹,尾尖也是深色
	var tip_dark: bool = rings > 0.0
	var fluff := func(s: float, angle: float) -> float:
		# 一绺绺毛:两组绕尾巴斜着走的起伏叠加,再沿尾巴一簇簇鼓起;尾根附近收平,和臀部接得上
		var locks := sin(angle * 6.0 + s * 24.0) * 0.6 + sin(angle * 11.0 - s * 40.0) * 0.4
		return 1.0 + (FLUFF * locks + CLUMP * sin(s * 55.0)) * smoothstep(0.0, 0.2, s)
	return _from_controls(BUSHY, t.get("side", 1.0), scale, fluff, func(s: float, u: float) -> Vector2:
		# 浅色尾尖:边缘随角度参差,像毛尖而不是一刀切
		var edge := 1.0 - tip + TIP_RAGGED * sin(u * TAU * 5.0)
		var at_tip := smoothstep(edge - 0.04, edge + 0.04, s)
		if not tip_dark:
			return Vector2(at_tip, 0.0)
		var band := smoothstep(-RING_EDGE, RING_EDGE, sin(s * rings * PI + RING_WOBBLE * sin(u * TAU))) * smoothstep(0.12, 0.25, s)
		return Vector2(0.0, maxf(band, at_tip) * 0.9), BUSHY_SIDES, BUSHY_PER_SEGMENT)


static func slender(t: Dictionary) -> Array:
	# 虎斑猫尾:一圈圈深色环纹
	var rings: float = t.get("rings", 0)
	var scale: float = t.get("radius", 0.026) / 0.026
	var smooth := func(_s: float, _angle: float) -> float: return 1.0
	return _from_controls(SLENDER, t.get("side", 1.0), scale, smooth, func(s: float, _u: float) -> Vector2:
		var band := smoothstep(0.55, 0.8, absf(sin(s * rings * PI))) * smoothstep(0.25, 0.4, s)
		return Vector2(0.0, band * 0.75), SIDES, PER_SEGMENT)


static func curl(t: Dictionary) -> Array:
	# 猪尾巴:沿 +X 伸出去的螺旋(卷得越来越紧),末端收尖
	var side: float = t.get("side", 1.0)
	var length: float = t.get("length", 0.16)
	var radius: float = t.get("radius", 0.012)
	var path := PackedVector3Array()
	var steps := 28
	for i in steps + 1:
		var k := float(i) / steps
		var angle := k * CURL_TURNS * TAU
		var coil := CURL_COIL * (1.0 - k * 0.45) * smoothstep(0.0, 0.15, k)
		path.append(Vector3(side * k * length * 0.5, sin(angle) * coil, -cos(angle) * coil + coil))
	var arrays := PatronGeo.sweep(path, func(s: float, _a: float) -> float: return radius * (1.0 - s * 0.6), 8)
	return PatronGeo.colored(arrays, func(_v: Vector3) -> Color: return PatronSkin.tag(PatronSkin.FUR))


static func _from_controls(controls: Array, side: float, scale: float, shape: Callable, marks: Callable,
		sides: int, per_segment: int) -> Array:
	# 控制点平滑成路径 → 扫出截面(半径按控制点插值,再乘 shape(沿程, 角度) 的起伏)→ 按沿程位置与角度上色
	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	var origin: Vector3 = controls[0][0] * Vector3(side, 1, 1)
	for c in controls:
		points.append(c[0] * Vector3(side, 1, 1) - origin)
		radii.append(c[1] * scale)
	var path := PatronGeo.smooth_path(points, per_segment)
	var along := PatronGeo.resample(radii, path.size())
	var arrays := PatronGeo.sweep(path, func(s: float, angle: float) -> float:
		var r := along[mini(int(s * (along.size() - 1) + 0.5), along.size() - 1)]
		return r * shape.call(s, angle), sides)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors := PackedColorArray()
	for uv in uvs:
		var m: Vector2 = marks.call(uv.y, uv.x)
		colors.append(PatronSkin.tag(PatronSkin.FUR, m.x, m.y))
	arrays[Mesh.ARRAY_COLOR] = colors
	return arrays
