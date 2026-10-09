class_name DecorBarrels
# 右后角的酒桶堆:三只立着的桶(一大两小)+ 一只横躺在木楔上、桶头装着黄铜龙头的桶。
# 桶身由一块块鼓肚的桶板拼成(回转体切片,两侧边缘往里收,板缝自然成一道道 V 形槽),
# 上下各两道铁箍,桶头是退进桶口的木圆盘(露出一圈桶口),一只桶侧面有木塞。
# 桶身、铁箍投影;木塞、龙头这类小件进不投影的细节批。


const STAVES := 16
const STAVE_SEGMENTS := 3                  # 每块桶板横向细分:两侧收边 + 中间鼓起
const STAVE_GROOVE := 0.006                # 板缝处往里收的深度
const PROFILE_ROWS := 8
const CHIME := 0.025                       # 桶头退进桶口的深度
const STAVE_THICKNESS := 0.018
const HOOP_WIDTH := 0.045
const HOOP_PROUD := 0.004                  # 铁箍凸出桶面
const HOOP_AT := [0.09, 0.24, 0.76, 0.91]  # 铁箍高度(占桶高的比例)
const STAVE_TINT := Color(0.86, 0.72, 0.58)
const HEAD_TINT := Color(0.74, 0.62, 0.5)
const CHOCK_TINT := Color(0.6, 0.52, 0.45)

# [位置, 绕 Y 转角(度), 高, 桶口半径, 鼓肚半径]
const STANDING := [
	[Vector3(3.92, 0.0, -3.88), 20.0, 0.86, 0.25, 0.3],
	[Vector3(3.32, 0.0, -3.96), 75.0, 0.74, 0.22, 0.26],
	[Vector3(4.0, 0.0, -3.28), 140.0, 0.62, 0.19, 0.225],
]
const LYING := [Vector3(3.22, 0.0, -3.1), 40.0, 0.8, 0.23, 0.275]


static func add_to(props: MeshBatch, detail: MeshBatch) -> void:
	for spec in STANDING:
		var xf := MeshBatch.xform_of(spec[0], Vector3(0, spec[1], 0))
		_add_barrel(props, xf, spec[2], spec[3], spec[4])
	_add_bung(detail, STANDING[0])
	_add_lying(props, detail)


static func radius_at(y: float, height: float, end_radius: float, belly: float) -> float:
	# 桶身外轮廓:两头收、中间鼓的抛物线
	var t := (y / height - 0.5) * 2.0
	return end_radius + (belly - end_radius) * (1.0 - t * t)


static func _add_barrel(props: MeshBatch, xf: Transform3D, height: float, end_radius: float, belly: float) -> void:
	var timber := RoomMaterials.timber()
	var stave := _stave(height, end_radius, belly)
	for i in STAVES:
		var shade := STAVE_TINT * (0.86 + 0.14 * fposmod(sin(i * 7.31) * 13.7, 1.0))
		props.add_arrays(stave, timber, xf * Transform3D(Basis(Vector3.UP, TAU * i / STAVES), Vector3.ZERO),
			RoomShapes.tint(shade, RoomShapes.GRAIN_Y))
	for v in [CHIME, height - CHIME]:
		var head := MeshShapes.lathe(PackedVector2Array([Vector2(end_radius - STAVE_THICKNESS * 0.6, 0.0), Vector2(0.0, 0.0)]),
			20)
		# 下面的桶头朝下(翻转),上面的朝上
		var flip := Basis(Vector3.RIGHT, PI) if v < height / 2.0 else Basis()
		props.add_arrays(head, timber, xf * Transform3D(flip, Vector3(0, v, 0)), RoomShapes.tint(HEAD_TINT, RoomShapes.GRAIN_Z))
	for k in HOOP_AT:
		_add_hoop(props, xf, height * k, height, end_radius, belly)


static func _stave(height: float, end_radius: float, belly: float) -> Array:
	# 一块桶板:外鼓面 + 上下桶口的端面 + 往里一小截内壁(桶头之上露出的部分)
	var inner := end_radius - STAVE_THICKNESS
	var profile := PackedVector2Array([Vector2(inner, CHIME + 0.01), Vector2(inner, 0.0), Vector2(inner, 0.0)])
	for i in PROFILE_ROWS + 1:
		var y := height * i / PROFILE_ROWS
		var r := radius_at(y, height, end_radius, belly)
		if i == 0 or i == PROFILE_ROWS:
			profile.append(Vector2(r, y))
		profile.append(Vector2(r, y))
	profile.append_array([Vector2(inner, height), Vector2(inner, height), Vector2(inner, height - CHIME - 0.01)])
	var arc := TAU / STAVES
	return _grooved(MeshShapes.lathe(profile, STAVE_SEGMENTS, arc), arc)


static func _grooved(arrays: Array, arc: float) -> Array:
	# 两侧边缘往里收,相邻两块之间形成 V 形板缝;外壁法线顺着收边的斜度偏转(端面法线不动,折边保持锐利)
	var verts: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var normals: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var half := arc / 2.0
	for i in verts.size():
		var v := verts[i]
		var r := Vector2(v.x, v.z).length()
		if r < 0.001:
			continue
		var a := atan2(v.z, v.x)
		var e := (a - half) / half
		var sunk := r - STAVE_GROOVE * e * e
		verts[i] = Vector3(v.x * sunk / r, v.y, v.z * sunk / r)
		var n := normals[i]
		if absf(n.y) < 0.9:
			var tangent := Vector3(-sin(a), 0.0, cos(a))
			normals[i] = (n + tangent * (2.0 * STAVE_GROOVE * e / (half * r)) * signf(Vector2(n.x, n.z).dot(Vector2(v.x, v.z)))).normalized()
	var out := arrays.duplicate()
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	return out


static func _add_hoop(props: MeshBatch, xf: Transform3D, y: float, height: float, end_radius: float, belly: float) -> void:
	var y0 := y - HOOP_WIDTH / 2.0
	var y1 := y + HOOP_WIDTH / 2.0
	var r0 := radius_at(y0, height, end_radius, belly) + HOOP_PROUD
	var r1 := radius_at(y1, height, end_radius, belly) + HOOP_PROUD
	var profile := PackedVector2Array([Vector2(r0 - HOOP_PROUD * 2.0, y0), Vector2(r0, y0), Vector2(r0, y0),
		Vector2(r1, y1), Vector2(r1, y1), Vector2(r1 - HOOP_PROUD * 2.0, y1)])
	props.add_arrays(MeshShapes.lathe(profile, 28), WorldMaterials.iron(), xf)


static func _add_bung(detail: MeshBatch, spec: Array) -> void:
	# 大桶鼓肚处的木塞
	var xf := MeshBatch.xform_of(spec[0], Vector3(0, spec[1], 0))
	var r: float = spec[4]
	var plug := MeshShapes.lathe(PackedVector2Array([Vector2(0.026, -0.01), Vector2(0.026, 0.006), Vector2(0.022, 0.012),
		Vector2(0.0, 0.013)]), 10)
	detail.add_arrays(plug, DecorMaterials.matte(), xf * Transform3D(Basis(Vector3.FORWARD, -PI / 2.0),
		Vector3(-r, spec[2] * 0.5, 0)), Color(0.42, 0.3, 0.2))


static func _add_lying(props: MeshBatch, detail: MeshBatch) -> void:
	# 横躺的桶:轴线水平,搁在两块三角木楔上;朝屋里的桶头上装一只黄铜龙头
	var height: float = LYING[2]
	var belly: float = LYING[4]
	var base := MeshBatch.xform_of(LYING[0], Vector3(0, LYING[1], 0))
	var lift := belly + 0.035
	var barrel_xf := base * Transform3D(Basis(Vector3.FORWARD, PI / 2.0), Vector3(-height / 2.0, lift, 0))
	_add_barrel(props, barrel_xf, height, LYING[3], belly)
	# 木楔顶面挖成弧形托住桶身
	var chock := MeshShapes.extrude(PackedVector2Array([Vector2(-0.16, 0), Vector2(0.16, 0), Vector2(0.16, 0.1),
		Vector2(0.13, 0.1), Vector2(0.1, 0.074), Vector2(0.05, 0.06), Vector2(0.0, 0.056), Vector2(-0.05, 0.06),
		Vector2(-0.1, 0.074), Vector2(-0.13, 0.1), Vector2(-0.16, 0.1)]), 0.07, 0.006)
	for x in [-height * 0.3, height * 0.3]:
		props.add_arrays(chock, RoomMaterials.timber(), base * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(x, 0, 0)),
			RoomShapes.tint(CHOCK_TINT, RoomShapes.GRAIN_X))
	_add_tap(detail, base * Transform3D(Basis(), Vector3(-height / 2.0 + CHIME, lift - 0.08, 0)))


static func _add_tap(detail: MeshBatch, xf: Transform3D) -> void:
	# 龙头:伸出桶头的短管 + 下弯的出水嘴 + 顶上的十字把手(局部 -X 朝外)
	var brass := WorldMaterials.brass()
	var spout := PackedVector3Array([Vector3(0.0, 0, 0), Vector3(-0.07, 0, 0), Vector3(-0.095, -0.012, 0),
		Vector3(-0.104, -0.04, 0)])
	detail.add_arrays(MeshShapes.tube(spout, PackedFloat32Array([0.014, 0.012, 0.01, 0.009]), 10), brass, xf)
	detail.add_arrays(MeshShapes.tube(PackedVector3Array([Vector3(-0.05, 0, 0), Vector3(-0.05, 0.04, 0)]), 0.006, 8),
		brass, xf)
	detail.add_arrays(MeshShapes.tube(PackedVector3Array([Vector3(-0.05, 0.042, -0.03), Vector3(-0.05, 0.042, 0.03)]), 0.007,
		8), brass, xf)
