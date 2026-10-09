class_name PatronFace
# 酒客的五官(头部坐标,贴着 PatronHead 捏出来的头型):眼睛(眼白 + 虹膜/瞳孔/高光由着色器画)、
# 上眼睑(眨眼与表情靠转动眼睑,不压扁眼珠)、眉毛、各表情的嘴、出局时的叉叉眼。
# 眼睛与眼睑各自挂在眼心处的枢轴上:眼珠转动看人,眼睑绕眼心的 X 轴开合、绕前后轴倾斜(生气/担心)。
# 嘴按"口鼻局部角度"(u 向右、v 向上,以口鼻轴为正前方)画在口鼻表面上,换头型时自动贴合。


const EYE_SINK := 0.5          # 眼珠半径埋进头里的比例(露出前面一半多)
const EYE_TURN := 0.1          # 平时两眼略朝外(弧度)
const EYE_SEGMENTS := 16
const IRIS_ANGLE := 0.74       # 虹膜覆盖的半角(弧度):卡通大眼
const IRIS_LIFT := 1.008       # 虹膜贴在眼白外面一点,不闪烁
const LID_RADIUS := 1.12       # 眼睑球壳半径(眼珠半径的倍数)
const LID_EDGE := 0.95         # 眼睑全开时边缘的位置(从正前方往上的角度,弧度)
const LID_BACK := 3.0          # 眼睑球壳往后一直包到这里:闭眼转下来时眼珠上方仍被盖住
const LID_SPAN := 1.45         # 眼睑左右覆盖的半角
const LID_CLOSED := -0.85      # 闭眼时边缘转到正前方下方这么多
const LASH_SPAN := 1.12        # 睫毛线(眼睑边的深色描边)左右的半角
const LASH_WIDTH := 0.085      # 睫毛线粗细(眼珠半径的倍数)
const X_SIZE := 0.62           # 叉叉眼的大小(眼睑半径的倍数)
const MOUTH_LIFT := 0.0006     # 嘴各层离口鼻表面的高度:口腔 < 舌头/牙齿 < 描边
const INNER_LIFT := 0.0011
const LINE_LIFT := 0.0004
const LINE_WIDTH := 0.0026
const LINE_HEIGHT := 0.0009
const PHILTRUM_TOP := -0.11    # 人中从鼻子下沿(口鼻局部俯仰角)开始
const EXPRESSIONS := ["neutral", "angry", "worried", "happy", "smug", "dead"]


# —— 眼睛 ——

static func eye_rest(spec: Dictionary, shape: Callable, side: float) -> Transform3D:
	# 眼心与平时朝向(头部坐标):眼珠一半埋进头里,看向正前方略朝外
	var e: Dictionary = spec["eyes"]
	var r: float = e["radius"]
	var yaw: float = side * e["yaw"]
	var surface := PatronHead.point(shape, yaw, e["pitch"])
	var center := surface - PatronHead.normal(shape, yaw, e["pitch"]) * r * EYE_SINK
	var forward := Vector3(side * sin(EYE_TURN), -0.04, -cos(EYE_TURN)).normalized()
	return Transform3D(Basis.looking_at(forward, Vector3.UP), center)


static func build_eye(batch: MeshBatch, spec: Dictionary) -> void:
	# 眼白与虹膜都按单位尺寸建模、靠变换缩放:部件坐标(CUSTOM0)是单位球 / 单位虹膜盘,着色器据此画瞳孔与高光
	var r: float = spec["eyes"]["radius"]
	var sclera := PatronGeo.sphere(Vector3.ONE, EYE_SEGMENTS, 10)
	batch.add_arrays(sclera, PatronSkin.SLOT, Transform3D(Basis().scaled(Vector3.ONE * r), Vector3.ZERO),
		PatronSkin.tag(PatronSkin.EYE))
	var iris_radius := sin(IRIS_ANGLE) * r * IRIS_LIFT
	batch.add_arrays(_iris_disc(), PatronSkin.SLOT, Transform3D(Basis().scaled(Vector3.ONE * iris_radius), Vector3.ZERO),
		PatronSkin.tag(PatronSkin.IRIS))


static func _iris_disc() -> Array:
	# 单位虹膜盘:xy 在单位圆内,z 贴着(缩放后)眼球表面往外鼓
	var depth := 1.0 / sin(IRIS_ANGLE)
	return PatronGeo.grid(func(s: float, t: float) -> Vector3:
			var a := s * TAU
			var q := Vector2(cos(a), sin(a)) * t
			return Vector3(q.x, q.y, -sqrt(depth * depth - q.length_squared())),
		EYE_SEGMENTS, 5, Vector3(0, 0, 0), true)


static func lid(spec: Dictionary, side: float, marks: Vector2) -> Array:
	# 上眼睑(眼心坐标,与眼睛的平时朝向一致):一片绕 X 轴的球壳带 + 边缘一道深色睫毛线;
	# 绕 X 轴转动即开合。marks:眼周毛色(浅色比例, 深色比例)
	var e: Dictionary = spec["eyes"]
	var radius: float = e["radius"] * LID_RADIUS
	var shell := PatronGeo.grid(func(s: float, t: float) -> Vector3:
			return _lid_point(radius, lerpf(-LID_SPAN, LID_SPAN, s), lerpf(LID_EDGE, LID_BACK, t)),
		14, 10, Vector3.ZERO)
	var parts := [PatronGeo.colored(shell, func(_v: Vector3) -> Color:
		return PatronSkin.tag(PatronSkin.FUR, marks.x, marks.y))]
	var line := PackedVector3Array()
	for i in 13:
		line.append(_lid_point(radius, lerpf(-LASH_SPAN, LASH_SPAN, i / 12.0), LID_EDGE))
	var widths := PatronGeo.resample(PackedFloat32Array([0.3, 1.0, 1.0, 1.0, 0.3]), line.size())
	var lash_radius: float = e["radius"] * LASH_WIDTH
	parts.append(_tagged(MeshShapes.tube(line, _scaled(widths, lash_radius), 6, true), PatronSkin.LASH))
	for k in int(e.get("lashes", 0)):
		parts.append(_lash(radius, side, k))
	return PatronGeo.concat(parts)


static func _lid_point(radius: float, across: float, up: float) -> Vector3:
	# across:左右(绕 Y 方向的角度);up:从正前方往上翻的角度
	return radius * Vector3(sin(across), cos(across) * sin(up), -cos(across) * cos(up))


static func _lash(radius: float, side: float, k: int) -> Array:
	# 外眼角往外上方翘的一根睫毛(猪)
	var across := side * (0.62 + k * 0.2)
	var root := _lid_point(radius, across, LID_EDGE)
	var out := Vector3(side * 0.7, 0.75, -0.25).normalized()
	var path := PackedVector3Array([root, root + out * 0.0045 + Vector3(0, 0.0012, 0), root + out * 0.0075 + Vector3(side * 0.0025, 0.0, 0)])
	return _tagged(MeshShapes.tube(path, PackedFloat32Array([0.0016, 0.001, 0.0003]), 5, false), PatronSkin.LASH)


static func lid_angle(openness: float) -> float:
	# 开度(0 闭 ~ 1 全开)→ 眼睑绕 X 轴的转角:负值往下盖
	return (1.0 - clampf(openness, 0.0, 1.0)) * (LID_CLOSED - LID_EDGE)


static func x_eyes(spec: Dictionary, shape: Callable) -> Array:
	# 出局的叉叉眼(头部坐标):画在闭上的眼睑表面上
	var radius: float = spec["eyes"]["radius"] * LID_RADIUS + 0.0008
	var parts := []
	for side in [-1.0, 1.0]:
		var rest := eye_rest(spec, shape, side)
		for diagonal in [-1.0, 1.0]:
			var path := PackedVector3Array()
			var normals := PackedVector3Array()
			for i in 7:
				var k := lerpf(-1.0, 1.0, i / 6.0) * X_SIZE
				var d := Vector3(k, diagonal * k, -1.0).normalized()
				path.append(rest * (d * radius))
				normals.append(rest.basis * d)
			var widths := PackedFloat32Array([0.003, 0.007, 0.008, 0.008, 0.008, 0.007, 0.003])
			parts.append(_tagged(PatronGeo.stroke(path, normals, widths, 0.0018), PatronSkin.LASH))
	return PatronGeo.concat(parts)


# —— 眉毛 ——

static func brow_frame(spec: Dictionary, shape: Callable, side: float) -> Transform3D:
	var b: Dictionary = spec["brows"]
	return PatronHead.frame(shape, side * b["yaw"], b["pitch"])


static func brow(spec: Dictionary, shape: Callable, side: float) -> Array:
	# 眉毛(眉毛枢轴坐标):沿眉弓的一道弯弯的笔画,内端粗、外端尖;枢轴绕法线转 = 挑眉/皱眉
	var b: Dictionary = spec["brows"]
	var frame := brow_frame(spec, shape, side)
	var path := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in 7:
		var k := i / 6.0
		var yaw: float = side * (b["yaw"] + (k - 0.5) * b["span"])
		var pitch: float = b["pitch"] + 0.03 * (1.0 - pow(k * 2.0 - 1.0, 2.0))
		path.append(frame.affine_inverse() * PatronHead.point(shape, yaw, pitch, 0.0006))
		normals.append(frame.basis.inverse() * PatronHead.normal(shape, yaw, pitch))
	var widths := _scaled(PackedFloat32Array([0.75, 1.0, 1.0, 0.92, 0.75, 0.5, 0.12]), b["width"])
	return _tagged(PatronGeo.stroke(path, normals, widths, b["height"], 4), PatronSkin.DARK)


# —— 嘴 ——

static func mouth(spec: Dictionary, shape: Callable, expression: String) -> Array:
	# 某个表情的嘴(头部坐标):张开的嘴 = 口腔 + 舌头/牙齿 + 上下描边;闭着的嘴 = 一道描边;外加人中
	var m: Dictionary = spec["mouth"]
	var snout := Basis.looking_at(PatronHead.snout_axis(spec), Vector3.UP)
	var curves := _curves(m["kind"], expression)
	var width: float = m["width"] * curves["width"]
	var drop: float = m["drop"]
	var at := func(x: float, v: float, lift: float) -> Vector3:
		return PatronHead.point_at(shape, snout * PatronHead.dir(x * width, -drop + v), lift)
	var up: Callable = curves["up"]
	var parts := []
	if curves.has("low"):
		var low: Callable = curves["low"]
		parts.append(_mouth_fill(at, up, low, 0.0, 1.0, 0.0, 1.0, MOUTH_LIFT, PatronSkin.MOUTH))
		if curves.get("teeth", false):
			parts.append(_mouth_fill(at, up, low, 0.06, 0.94, 0.0, 0.3, INNER_LIFT, PatronSkin.TEETH))
		if curves.get("tongue", false):
			parts.append(_mouth_fill(at, up, low, 0.24, 0.76, 0.52, 1.0, INNER_LIFT, PatronSkin.TONGUE))
		parts.append(_mouth_line(at, shape, snout, width, drop, low))
	parts.append(_mouth_line(at, shape, snout, width, drop, up))
	if m["kind"] != "pig":
		parts.append(_philtrum(shape, snout, drop, up))
	if curves.get("fangs", false) and m["kind"] == "cat":
		parts.append(_fangs(at, up, low_or(curves)))
	if expression == "dead":
		parts.append(_hanging_tongue(at, up))
	return PatronGeo.concat(parts)


static func low_or(curves: Dictionary) -> Callable:
	return curves.get("low", curves["up"])


static func _curves(kind: String, expression: String) -> Dictionary:
	# 嘴形:x ∈ [-1, 1] 从左嘴角到右嘴角,返回相对嘴线中心的俯仰偏移(弧度,正为上)
	var pig := kind == "pig"
	match expression:
		"happy":
			return {"width": 1.0, "tongue": true,
				"up": func(x: float) -> float: return -0.025 * sin(PI * absf(x)) + 0.06 * x * x if not pig else 0.05 * x * x,
				"low": func(x: float) -> float: return 0.05 * x * x - 0.17 * sqrt(maxf(1.0 - x * x, 0.0))}
		"angry":
			return {"width": 0.9, "teeth": true, "fangs": true,
				"up": func(x: float) -> float: return -0.01 - 0.04 * x * x,
				"low": func(x: float) -> float: return -0.05 - 0.07 * (1.0 - pow(x, 4.0)) - 0.04 * x * x}
		"worried":
			return {"width": 0.72,
				"up": func(x: float) -> float: return 0.012 * sin(3.0 * PI * x) - 0.04 * x * x,
				"low": func(x: float) -> float: return -0.04 * x * x - 0.075 * (1.0 - x * x)}
		"smug":
			return {"width": 0.95,
				"up": func(x: float) -> float: return 0.085 * x * x - 0.02 * sin(PI * x) if x > 0.0 else -0.04 * sin(PI * absf(x))}
		"dead":
			return {"width": 0.62,
				"up": func(x: float) -> float: return -0.01 - 0.02 * x * x,
				"low": func(x: float) -> float: return -0.03 - 0.08 * (1.0 - x * x)}
	# neutral:动物的"ω"嘴(猪是一道浅笑)
	return {"width": 1.0,
		"up": func(x: float) -> float: return -0.045 * sin(PI * absf(x)) + 0.012 * absf(x) if not pig else 0.035 * x * x}


static func _mouth_fill(at: Callable, up: Callable, low: Callable, s0: float, s1: float, t0: float, t1: float,
		lift: float, slot: int) -> Array:
	var arrays := PatronGeo.grid(func(s: float, t: float) -> Vector3:
			var x := lerpf(-1.0, 1.0, lerpf(s0, s1, s))
			var v := lerpf(up.call(x), low.call(x), lerpf(t0, t1, t))
			return at.call(x, v, lift),
		12, 4, PatronHead.CENTER)
	return _tagged(arrays, slot)


static func _mouth_line(at: Callable, shape: Callable, snout: Basis, width: float, drop: float, curve: Callable) -> Array:
	var path := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in 15:
		var x := lerpf(-1.0, 1.0, i / 14.0)
		var v: float = curve.call(x)
		path.append(at.call(x, v, LINE_LIFT))
		normals.append(PatronHead.normal_at(shape, snout * PatronHead.dir(x * width, -drop + v)))
	var widths := PatronGeo.resample(PackedFloat32Array([0.35, 1.0, 1.0, 1.0, 0.35]), path.size())
	return _tagged(PatronGeo.stroke(path, normals, _scaled(widths, LINE_WIDTH), LINE_HEIGHT, 3), PatronSkin.LASH)


static func _philtrum(shape: Callable, snout: Basis, drop: float, up: Callable) -> Array:
	# 人中:鼻子下沿到嘴线中点的一小竖
	var path := PackedVector3Array()
	var normals := PackedVector3Array()
	var bottom: float = -drop + up.call(0.0)
	for i in 4:
		var d := snout * PatronHead.dir(0.0, lerpf(PHILTRUM_TOP, bottom, i / 3.0))
		path.append(PatronHead.point_at(shape, d, LINE_LIFT))
		normals.append(PatronHead.normal_at(shape, d))
	var widths := _scaled(PackedFloat32Array([0.6, 0.9, 0.9, 0.6]), LINE_WIDTH)
	return _tagged(PatronGeo.stroke(path, normals, widths, LINE_HEIGHT, 3), PatronSkin.LASH)


static func _fangs(at: Callable, up: Callable, low: Callable) -> Array:
	# 龇牙时上排两颗小尖牙
	var parts := []
	for x in [-0.42, 0.42]:
		var top: Vector3 = at.call(x - 0.07, up.call(x), INNER_LIFT + 0.0002)
		var top2: Vector3 = at.call(x + 0.07, up.call(x), INNER_LIFT + 0.0002)
		var tip: Vector3 = at.call(x, lerpf(up.call(x), low.call(x), 0.55), INNER_LIFT + 0.0002)
		var normal := (top2 - top).cross(tip - top).normalized()
		parts.append(_tagged(_triangle(top, top2, tip, normal), PatronSkin.TEETH))
	return PatronGeo.concat(parts)


static func _hanging_tongue(at: Callable, up: Callable) -> Array:
	# 出局时吐出来的舌头:从嘴里垂到下巴一侧
	var path := PackedVector3Array()
	var normals := PackedVector3Array()
	for i in 6:
		var k := i / 5.0
		var p: Vector3 = at.call(0.25 + k * 0.12, up.call(0.25) - 0.04 - k * 0.2, INNER_LIFT + 0.002 * k)
		path.append(p)
		normals.append((p - PatronHead.CENTER).normalized())
	var widths := PackedFloat32Array([0.016, 0.019, 0.02, 0.019, 0.015, 0.004])
	return _tagged(PatronGeo.stroke(path, normals, widths, 0.004, 4), PatronSkin.TONGUE)


# —— 工具 ——

static func _triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([a, b, c])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([normal, normal, normal])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
	# 正面朝外(Godot 顺时针为正面):法线按 (b-a)×(c-a) 算的,绕序取 a, c, b
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1])
	return arrays


static func _scaled(values: PackedFloat32Array, k: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for v in values:
		out.append(v * k)
	return out


static func _tagged(arrays: Array, slot: int) -> Array:
	return PatronGeo.colored(arrays, func(_v: Vector3) -> Color: return PatronSkin.tag(slot))
