class_name DecorStorage
# 角落里的杂货:左后角(壁炉与吧台之间)摞着的板条木箱和靠着的粮袋,右前角(门的另一侧)的粮袋堆与靠墙的扫帚。
# 木箱:深色箱体 + 每面三条留缝的板条 + 四角立的护角条;粮袋:回转体鼓成袋形再捏出褶子与歪斜,
# 袋口扎一圈麻绳、上面翻出一撮布头。木箱、粮袋投影,扫帚细长也投影(影子落在墙角很有生活感)。


const CRATE_SLATS := 3
const SLAT_THICKNESS := 0.016
const SLAT_GAP := 0.012
const BATTEN := 0.045
const CRATE_BODY_TINT := Color(0.34, 0.27, 0.22)
const CRATE_SLAT_TINT := Color(0.9, 0.8, 0.66)
const CRATE_BATTEN_TINT := Color(0.74, 0.64, 0.53)

# 木箱:[位置, 绕 Y 转角, 尺寸]
const CRATES := [
	[Vector3(-3.85, 0.0, -3.92), 6.0, Vector3(0.56, 0.46, 0.46)],
	[Vector3(-3.32, 0.0, -4.0), -9.0, Vector3(0.48, 0.38, 0.4)],
	[Vector3(-3.82, 0.46, -3.94), 21.0, Vector3(0.42, 0.34, 0.36)],
	[Vector3(3.5, 0.0, 3.62), -14.0, Vector3(0.44, 0.34, 0.38)],
]
# 粮袋:[位置, 绕 Y 转角, 缩放, 歪斜(朝局部 +X 倒), 染色]
const SACKS := [
	[Vector3(-3.95, 0.0, -3.38), 30.0, 1.0, 0.1, Color(1.0, 0.97, 0.92)],
	[Vector3(-3.5, 0.0, -3.5), -40.0, 0.86, 0.16, Color(0.9, 0.86, 0.78)],
	[Vector3(3.98, 0.0, 3.95), 10.0, 1.05, 0.08, Color(0.95, 0.9, 0.82)],
	[Vector3(3.95, 0.0, 3.38), 120.0, 0.9, 0.18, Color(1.0, 0.95, 0.85)],
	[Vector3(3.48, 0.34, 3.62), 70.0, 0.62, 0.05, Color(0.82, 0.78, 0.7)],
]
const SACK_PROFILE := [Vector2(0.0, 0.0), Vector2(0.17, 0.0), Vector2(0.23, 0.04), Vector2(0.26, 0.13),
	Vector2(0.25, 0.27), Vector2(0.2, 0.4), Vector2(0.12, 0.49), Vector2(0.05, 0.545), Vector2(0.045, 0.56),
	Vector2(0.07, 0.6), Vector2(0.085, 0.65), Vector2(0.06, 0.68), Vector2(0.0, 0.67)]
const SACK_NECK := 0.552
const TWINE_TINT := Color(0.72, 0.6, 0.4)
const BROOM_FOOT := Vector3(3.26, 0.0, 4.16)
const BROOM_TOP := Vector3(3.2, 1.4, 4.384)   # 柄头靠在腰线上方的灰泥上
const STRAW_TINT := Color(0.8, 0.66, 0.36)
const HANDLE_TINT := Color(0.7, 0.58, 0.46)


static func add_to(props: MeshBatch) -> void:
	for spec in CRATES:
		add_crate(props, MeshBatch.xform_of(spec[0], Vector3(0, spec[1], 0)), spec[2])
	var sack := sack_arrays()
	for spec in SACKS:
		_add_sack(props, sack, spec)
	_add_broom(props)


# —— 木箱 ——

static func add_crate(batch: MeshBatch, xf: Transform3D, size: Vector3) -> void:
	# 原点在箱底中心
	var timber := RoomMaterials.timber()
	var body := MeshKit.box(size - Vector3.ONE * SLAT_THICKNESS * 2.0)
	batch.add(body, timber, xf * Transform3D(Basis(), Vector3(0, size.y / 2.0, 0)), RoomShapes.tint(CRATE_BODY_TINT))
	# 四个侧面 + 顶面的板条:板条沿面的长边
	for face in [[Vector3.RIGHT, size.z, size.y], [Vector3.LEFT, size.z, size.y], [Vector3.BACK, size.x, size.y],
			[Vector3.FORWARD, size.x, size.y], [Vector3.UP, size.x, size.z]]:
		_add_slats(batch, xf, size, face[0], face[1], face[2])
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			# 护角条停在顶面板条下面,不和板条共面闪烁
			var batten_h := size.y - SLAT_THICKNESS
			var batten := RoomShapes.timber(Vector2(BATTEN, BATTEN), batten_h, 0.006)
			var at := Vector3(sx * (size.x / 2.0 - BATTEN / 2.0 + 0.004), batten_h / 2.0, sz * (size.z / 2.0 - BATTEN / 2.0 + 0.004))
			batch.add_arrays(batten, timber, xf * RoomShapes.upright(at), RoomShapes.tint(CRATE_BATTEN_TINT))


static func _add_slats(batch: MeshBatch, xf: Transform3D, size: Vector3, normal: Vector3, length: float,
		height: float) -> void:
	# 一面三条板条:局部 X 沿板长、Y 沿面的另一边、Z 沿法线朝外
	var slat_h := (height - SLAT_GAP * (CRATE_SLATS - 1)) / CRATE_SLATS
	var z_axis := normal
	var x_axis := Vector3.RIGHT if absf(normal.x) < 0.5 else Vector3.BACK
	var y_axis := z_axis.cross(x_axis)
	var basis := Basis(x_axis, y_axis, z_axis)
	var half_extent := Vector3(size.x, size.y, size.z) / 2.0
	var out := absf(normal.dot(half_extent)) - SLAT_THICKNESS / 2.0
	for i in CRATE_SLATS:
		var offset := -height / 2.0 + slat_h / 2.0 + i * (slat_h + SLAT_GAP)
		var center := Vector3(0, size.y / 2.0, 0) + normal * out + y_axis * offset
		var slat := RoomShapes.board(Vector3(length - 0.006, slat_h, SLAT_THICKNESS), 0.004)
		var shade := CRATE_SLAT_TINT * (0.88 + 0.12 * fposmod(sin(i * 3.7 + normal.x * 5.0 + normal.z * 2.0) * 9.1, 1.0))
		batch.add_arrays(slat, RoomMaterials.timber(), xf * Transform3D(basis, center), RoomShapes.tint(shade, RoomShapes.GRAIN_X))


# —— 粮袋 ——

static func sack_arrays() -> Array:
	# 袋形回转体,再捏出几道竖褶、底部压扁的鼓包;每只袋子复用这一份,靠缩放、歪斜、转角区分
	var base := MeshShapes.lathe(PackedVector2Array(SACK_PROFILE), 16)
	return MeshShapes.deform(base, func(v: Vector3) -> Vector3:
		var a := atan2(v.z, v.x)
		var body := clampf(v.y / SACK_NECK, 0.0, 1.0)
		var folds := 1.0 + 0.06 * sin(a * 5.0 + v.y * 9.0) * body * (1.0 - body) * 4.0
		var lumps := 1.0 + 0.05 * sin(a * 2.0 + 1.3) * (1.0 - body)
		return Vector3(v.x * folds * lumps, v.y, v.z * folds * lumps))


static func _add_sack(props: MeshBatch, sack: Array, spec: Array) -> void:
	var scale: float = spec[2]
	var lean: float = spec[3]
	# 歪斜:越往上越朝 +X 倒,像靠着东西瘫软下来
	var shear := Basis(Vector3(1, 0, 0), Vector3(lean, 0.92, 0), Vector3(0, 0, 1))
	var xf := MeshBatch.xform_of(spec[0], Vector3(0, spec[1], 0)) * Transform3D(shear.scaled(Vector3.ONE * scale), Vector3.ZERO)
	props.add_arrays(sack, DecorMaterials.burlap(), xf, spec[4])
	var twine := MeshKit.torus(0.04, 0.056, 12)
	twine.ring_segments = 5
	props.add(twine, DecorMaterials.matte(), xf * Transform3D(Basis(), Vector3(0, SACK_NECK, 0)), TWINE_TINT)


# —— 扫帚 ——

static func _add_broom(props: MeshBatch) -> void:
	# 木柄靠在前墙上;扫帚头是压扁的稻草锥,上面扎两道麻绳
	var axis := (BROOM_TOP - BROOM_FOOT).normalized()
	var head_top := BROOM_FOOT + axis * 0.36
	props.add_arrays(MeshShapes.tube(PackedVector3Array([head_top - axis * 0.1, BROOM_TOP]), 0.014, 8),
		RoomMaterials.timber(), Transform3D.IDENTITY, RoomShapes.tint(HANDLE_TINT, RoomShapes.GRAIN_Y))
	var straw := MeshShapes.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.13, 0.0), Vector2(0.12, 0.05),
		Vector2(0.06, 0.24), Vector2(0.032, 0.32), Vector2(0.028, 0.36), Vector2(0.0, 0.365)]), 14)
	var basis := Basis(Quaternion(Vector3.UP, axis)) * Basis.from_scale(Vector3(1.0, 1.0, 0.45))
	var foot := BROOM_FOOT + Vector3(0, 0.014, 0)   # 斜靠时底盘一侧会压低,抬高一点不穿地
	props.add_arrays(straw, DecorMaterials.matte(), Transform3D(basis, foot), STRAW_TINT)
	for h in [0.26, 0.3]:
		var band := MeshKit.torus(0.03, 0.04, 10)
		band.ring_segments = 4
		props.add(band, DecorMaterials.matte(), Transform3D(basis, foot + axis * h), Color(0.42, 0.22, 0.12))
