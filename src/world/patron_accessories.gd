class_name PatronAccessories
# 酒客脸上的招牌小物(头部坐标,合进头部细节批次,不投影):圆框眼镜(兔子)、单片眼镜带链(猫头鹰)、
# 金耳环(浣熊)、烟斗(熊)。物种表 "accessories" 列出要戴哪些;位置都按物种的眼睛、耳朵、嘴算,换头型自动贴合。


const WIRE := 0.0017            # 金属细丝(镜框、链子)的半径
const RIM_SIDES := 6
const RING_POINTS := 24
const LENS_FORWARD := 1.2       # 镜片平面在眼心前方多远(眼珠半径的倍数):盖在眼睑外面
const LENS_RADIUS := 1.32       # 镜框半径(眼珠半径的倍数)
const MONOCLE_RIM := 0.0028
const CHAIN_LINKS := 14
const CHAIN_DROP := 0.13        # 单片眼镜链垂到眼睛下方多远
const EARRING_RADIUS := 0.011
const EARRING_AT := Vector2(0.14, 0.78)   # 耳洞的位置:离耳廓中线(耳根全宽的比例)、沿耳朵高度的比例
const PIPE_STEM := 0.075        # 烟斗:烟杆长、烟斗锅的尺寸
const PIPE_BOWL := Vector2(0.014, 0.03)


static func build(spec: Dictionary, shape: Callable) -> Array:
	var parts := []
	for kind in spec.get("accessories", []):
		match kind:
			"spectacles":
				parts.append(spectacles(spec, shape))
			"monocle":
				parts.append(monocle(spec, shape))
			"earring":
				parts.append(earring(spec, shape))
			"pipe":
				parts.append(pipe(spec, shape))
	return parts


# —— 眼镜 ——

static func lens_frame(spec: Dictionary, shape: Callable, side: float) -> Transform3D:
	# 镜框平面(头部坐标):原点在镜片中心,-Z 朝前;正对前方(不随两眼外转),两片镜框才在一个平面上
	var rest := PatronFace.eye_rest(spec, shape, side)
	var r: float = spec["eyes"]["radius"]
	var center := rest.origin + Vector3(0, 0, -r * LENS_FORWARD)
	return Transform3D(Basis(), center)


static func spectacles(spec: Dictionary, shape: Callable) -> Array:
	# 圆框眼镜:两个镜圈 + 拱起的鼻梁 + 往后搭到耳边的镜腿
	var r: float = spec["eyes"]["radius"] * LENS_RADIUS
	var parts := []
	var inner := {}
	for side in [-1.0, 1.0]:
		var frame := lens_frame(spec, shape, side)
		parts.append(_ring(frame, r, WIRE))
		inner[side] = frame * Vector3(-side * r, 0.0, 0.0)
		var outer := frame * Vector3(side * r, r * 0.15, 0.0)
		var temple := PatronHead.point(shape, side * 1.45, spec["eyes"]["pitch"] + 0.08, 0.004)
		var mid := outer.lerp(temple, 0.5) + (outer - PatronHead.CENTER).normalized() * 0.006
		parts.append(_wire(PackedVector3Array([outer, mid, temple]), WIRE * 0.9))
	var bridge_top: Vector3 = (inner[-1.0] + inner[1.0]) / 2.0 + Vector3(0, r * 0.35, 0.002)
	parts.append(_wire(PackedVector3Array([inner[-1.0], bridge_top, inner[1.0]]), WIRE))
	return _tagged(PatronGeo.concat(parts), PatronSkin.BRASS)


static func monocle(spec: Dictionary, shape: Callable) -> Array:
	# 单片眼镜(右眼):粗一点的金圈 + 一根从镜圈外下沿垂下、在腮边打个弯的细链
	var r: float = spec["eyes"]["radius"] * LENS_RADIUS
	var frame := lens_frame(spec, shape, 1.0)
	var start := frame * Vector3(r * 0.7, -r * 0.7, 0.0)
	var cheek := PatronHead.point(shape, 0.95, spec["eyes"]["pitch"] - 0.45, 0.012)
	var low := cheek + Vector3(0.01, -CHAIN_DROP * 0.6, 0.02)
	var path := PatronGeo.smooth_path(PackedVector3Array([start, start.lerp(cheek, 0.5) + Vector3(0, -0.01, -0.004), cheek, low]),
		CHAIN_LINKS / 3)
	return _tagged(PatronGeo.concat([_ring(frame, r, MONOCLE_RIM), _wire(path, WIRE * 0.8)]), PatronSkin.BRASS)


# —— 耳环、烟斗 ——

static func earring(spec: Dictionary, shape: Callable) -> Array:
	# 左耳靠近耳尖的下沿穿一只金圈耳环(挂在头上而不是耳朵上:耳朵网格两侧共用,只戴一只)。
	# 圈在耳廓平面里、大半垂在耳缘外面;耳尖已伸出头的轮廓,耳环不会碰到腮帮
	var e: Dictionary = spec["ears"]
	var ear := PatronEars.pivot(spec, shape, -1.0)
	var basis := ear.basis.orthonormalized()
	var low_edge := -1.0 if basis.x.y >= 0.0 else 1.0
	var hole := ear * Vector3(low_edge * e["width"] * EARRING_AT.x, e["height"] * EARRING_AT.y, -0.002)
	var hoop := Transform3D(basis, hole + basis.x * low_edge * EARRING_RADIUS * 0.7)
	return _tagged(_ring(hoop, EARRING_RADIUS, WIRE * 1.3), PatronSkin.BRASS)


static func pipe(spec: Dictionary, shape: Callable) -> Array:
	# 叼在嘴角(酒客左边)的烟斗:细烟杆往前下方伸出,末端竖一只烟斗锅,锅口深色
	var m: Dictionary = spec["mouth"]
	var snout := Basis.looking_at(PatronHead.snout_axis(spec), Vector3.UP)
	var corner := PatronHead.point_at(shape, snout * PatronHead.dir(-0.8 * m["width"], -m["drop"]), -0.004)
	var out := (snout * Vector3(-0.45, -0.35, -1.0)).normalized()
	var end := corner + out * PIPE_STEM
	var stem := _wire(PackedVector3Array([corner, corner.lerp(end, 0.5) + Vector3(0, -0.004, 0), end]), 0.0032)
	var bowl_profile := PackedVector2Array([Vector2(0, 0), Vector2(PIPE_BOWL.x * 0.75, 0), Vector2(PIPE_BOWL.x, PIPE_BOWL.y * 0.5),
		Vector2(PIPE_BOWL.x * 0.95, PIPE_BOWL.y), Vector2(PIPE_BOWL.x * 0.7, PIPE_BOWL.y), Vector2(PIPE_BOWL.x * 0.7, PIPE_BOWL.y * 0.75),
		Vector2(0, PIPE_BOWL.y * 0.75)])
	var bowl := MeshShapes.lathe(bowl_profile, 12)
	var bowl_at := Transform3D(Basis(), end + Vector3(0, -PIPE_BOWL.y * 0.25, 0))
	var ash := PatronGeo.sphere(Vector3(PIPE_BOWL.x * 0.7, 0.001, PIPE_BOWL.x * 0.7), 8, 3)
	return PatronGeo.concat([
		_tagged(stem, PatronSkin.LASH),
		_tagged(PatronGeo.transformed(bowl, bowl_at), PatronSkin.WOOD),
		_tagged(PatronGeo.transformed(ash, bowl_at.translated(Vector3(0, PIPE_BOWL.y * 0.76, 0))), PatronSkin.MOUTH),
	])


# —— 工具 ——

static func _ring(frame: Transform3D, radius: float, wire: float) -> Array:
	# frame 的 XY 平面上一个圆圈(细管首尾相接)
	var path := PackedVector3Array()
	for i in RING_POINTS + 1:
		var a := TAU * i / RING_POINTS
		path.append(frame * Vector3(cos(a) * radius, sin(a) * radius, 0.0))
	return MeshShapes.tube(path, wire, RIM_SIDES, false)


static func _wire(points: PackedVector3Array, radius: float) -> Array:
	return MeshShapes.tube(PatronGeo.smooth_path(points, 4) if points.size() < 5 else points, radius, RIM_SIDES, true)


static func _tagged(arrays: Array, slot: int) -> Array:
	return PatronGeo.colored(arrays, func(_v: Vector3) -> Color: return PatronSkin.tag(slot))
