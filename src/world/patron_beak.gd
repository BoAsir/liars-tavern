class_name PatronBeak
# 鸟类酒客(猫头鹰)的喙:上喙是带钩的弯锥(鼻子的位置,在头部细节批次里),下喙充当"嘴"——
# 每个表情一份下喙网格(张开的角度不同),张开时露出深色的口腔,换表情就是换网格,与其它物种的嘴一样。
# 坐标:先在"喙坐标"(原点在口鼻轴与脸面的交点,-Z 沿口鼻轴朝前,+Y 朝上)里建模,再放进头部坐标。


# 中心线控制点与半径:[点, 半径];从埋进脸里的喙根往前、往下弯成钩
const UPPER := [
	[Vector3(0, 0.006, 0.012), 0.019], [Vector3(0, 0.003, -0.008), 0.016], [Vector3(0, -0.005, -0.025), 0.011],
	[Vector3(0, -0.019, -0.035), 0.006], [Vector3(0, -0.032, -0.032), 0.0],
]
const LOWER := [
	[Vector3(0, -0.009, 0.008), 0.0125], [Vector3(0, -0.014, -0.008), 0.0095], [Vector3(0, -0.019, -0.018), 0.004],
	[Vector3(0, -0.02, -0.021), 0.0],
]
const HINGE := Vector3(0, -0.008, 0.006)   # 下喙绕这里张开
const FLAT := 0.74                         # 截面横向压扁(喙是侧扁的)
const TIP_SHADE := 0.72                    # 喙尖压暗一点,看得出角质的层次
const SIDES := 10
# 各表情下喙张开的角度(弧度)
const OPEN := {"neutral": 0.0, "angry": 0.3, "worried": 0.16, "happy": 0.42, "smug": 0.05, "dead": 0.5}


static func upper(spec: Dictionary, shape: Callable) -> Array:
	return PatronGeo.transformed(_horn(UPPER, _scale(spec)), place(spec, shape))


static func lower(spec: Dictionary, shape: Callable, expression: String) -> Array:
	# 某个表情的下喙(头部坐标)+ 张开时露出来的口腔(和舌头)
	var k := _scale(spec)
	var hinge := HINGE * k
	var open: float = OPEN.get(expression, 0.0)
	var swing := Transform3D(Basis(Vector3.RIGHT, -open), hinge) * Transform3D(Basis(), -hinge)
	var parts := [PatronGeo.transformed(_horn(LOWER, k), swing)]
	var mouth := PatronGeo.sphere(Vector3(0.0105, 0.007, 0.016) * k, 10, 6)
	parts.append(_tagged(PatronGeo.transformed(mouth, Transform3D(Basis(), Vector3(0, -0.008, -0.004) * k)), PatronSkin.MOUTH))
	if open > 0.2:
		var tongue := PatronGeo.sphere(Vector3(0.006, 0.003, 0.009) * k, 8, 5)
		parts.append(_tagged(PatronGeo.transformed(tongue, swing * Transform3D(Basis(), Vector3(0, -0.011, -0.006) * k)),
			PatronSkin.TONGUE))
	return PatronGeo.transformed(PatronGeo.concat(parts), place(spec, shape))


static func place(spec: Dictionary, shape: Callable) -> Transform3D:
	# 喙坐标 → 头部坐标:原点在口鼻轴碰到脸面的点
	var axis := PatronHead.snout_axis(spec)
	return Transform3D(Basis.looking_at(axis, Vector3.UP), shape.call(axis))


static func _scale(spec: Dictionary) -> float:
	return spec["nose"].get("scale", 1.0)


static func _horn(controls: Array, k: float) -> Array:
	# 控制点平滑成弯曲的中心线,扫出侧扁的锥;顶点色按沿程压暗喙尖
	var points := PackedVector3Array()
	var radii := PackedFloat32Array()
	for c in controls:
		points.append(c[0] * k)
		radii.append(c[1] * k)
	var path := PatronGeo.smooth_path(points, 3)
	var along := PatronGeo.resample(radii, path.size())
	var arrays := PatronGeo.sweep(path, func(s: float, _a: float) -> float:
		return along[mini(int(s * (along.size() - 1) + 0.5), along.size() - 1)], SIDES)
	arrays = PatronGeo.transformed(arrays, Transform3D(Basis().scaled(Vector3(FLAT, 1, 1)), Vector3.ZERO))
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var colors := PackedColorArray()
	for uv in uvs:
		colors.append(PatronSkin.tag(PatronSkin.NOSE, 0.0, 0.0, lerpf(1.0, TIP_SHADE, smoothstep(0.4, 1.0, uv.y))))
	arrays[Mesh.ARRAY_COLOR] = colors
	return arrays


static func _tagged(arrays: Array, slot: int) -> Array:
	return PatronGeo.colored(arrays, func(_v: Vector3) -> Color: return PatronSkin.tag(slot))
