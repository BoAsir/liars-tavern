class_name FireplaceMantel
# 壁炉台上的摆设:正中一座拱顶木壳座钟(奶白钟面、黄铜钟圈、刻度与指针)、两侧黄铜烛台(未点燃的蜡烛
# 挂着蜡泪)、右边几只上釉的陶罐、左边一摞旧书;烟囱上一块盾形木牌挂着鹿角。都不投影(在横梁的影子里)。
# 坐标为壁炉本地;台面在 MANTEL_TOP,可用进深从烟囱石面到横梁前沿。


const CLOCK_AT := Vector3(0, 0, 0.645)
const CLOCK_SIZE := Vector3(0.24, 0.2, 0.11)
const DIAL_RADIUS := 0.072
const CANDLESTICK_X := 0.5
const SHELF_Z := 0.66
const PLAQUE_HEIGHT := 2.24
const WAX := Color(0.93, 0.87, 0.74)
# 陶罐:[位置 (x, z), 釉色, 形状]
const JARS := [
	[Vector2(0.74, 0.62), Color(0.2, 0.31, 0.48), "tall"],
	[Vector2(0.92, 0.7), Color(0.3, 0.42, 0.24), "squat"],
	[Vector2(0.86, 0.56), Color(0.58, 0.33, 0.12), "flask"],
]
# 书:[尺寸, 封皮颜色, 绕 Y 的转角]
const BOOKS := [
	[Vector3(0.22, 0.034, 0.16), Color(0.42, 0.12, 0.1), 4.0],
	[Vector3(0.2, 0.03, 0.15), Color(0.16, 0.26, 0.18), -7.0],
	[Vector3(0.17, 0.026, 0.13), Color(0.36, 0.25, 0.14), 12.0],
]


static func add_to(batch: MeshBatch) -> void:
	var top := TavernFireplace.MANTEL_TOP
	_clock(batch, Vector3(CLOCK_AT.x, top, CLOCK_AT.z))
	for side in [-1.0, 1.0]:
		_candlestick(batch, Vector3(side * CANDLESTICK_X, top, SHELF_Z), 0.13 + 0.02 * side)
	for jar in JARS:
		_jar(batch, Vector3(jar[0].x, top, jar[0].y), jar[1], jar[2])
	_books(batch, Vector3(-0.84, top, SHELF_Z))
	_antlers(batch, Vector3(0, PLAQUE_HEIGHT, TavernFireplace.CHIMNEY_DEPTH + FireplaceMasonry.PROUD + 0.03))


# —— 座钟 ——

static func _clock(batch: MeshBatch, base: Vector3) -> void:
	var oak := FireplaceMaterials.oak()
	var brass := WorldMaterials.brass()
	var tint := Color(0.62, 0.42, 0.3)
	batch.add_part(MeshShapes.rounded_box(Vector3(0.3, 0.03, 0.14), 0.008, 2), oak, base + Vector3(0, 0.015, 0),
		Vector3.ZERO, Vector3.ONE, tint, 0.1)
	batch.add_part(MeshShapes.rounded_box(CLOCK_SIZE, 0.012, 2), oak, base + Vector3(0, 0.03 + CLOCK_SIZE.y / 2.0, 0),
		Vector3.ZERO, Vector3.ONE, tint, 0.2)
	var hood_y := 0.03 + CLOCK_SIZE.y
	batch.add_part(MeshShapes.extrude(_arch(CLOCK_SIZE.x / 2.0, 0.085, 10), CLOCK_SIZE.z - 0.006, 0.008), oak,
		base + Vector3(0, hood_y, 0), Vector3.ZERO, Vector3.ONE, tint, 0.3)
	batch.add_part(MeshKit.sphere(0.016, 10), brass, base + Vector3(0, hood_y + 0.1, 0))
	for x in [-1.0, 1.0]:
		batch.add_part(MeshKit.sphere(0.011, 8), brass, base + Vector3(x * 0.135, 0.03, 0.055))
	var dial := base + Vector3(0, 0.03 + CLOCK_SIZE.y * 0.56, CLOCK_SIZE.z / 2.0)
	batch.add_part(MeshKit.cylinder(DIAL_RADIUS, DIAL_RADIUS, 0.006, 24), FireplaceMaterials.clock_face(), dial,
		Vector3(90, 0, 0))
	batch.add_part(MeshKit.torus(DIAL_RADIUS - 0.002, DIAL_RADIUS + 0.011, 24), brass, dial + Vector3(0, 0, 0.003),
		Vector3(90, 0, 0), Vector3(1, 0.6, 1))
	_dial_marks(batch, dial + Vector3(0, 0, 0.004))


static func _arch(half_width: float, height: float, steps: int) -> PackedVector2Array:
	# 钟壳拱顶的侧影:半椭圆
	var pts := PackedVector2Array()
	for k in steps + 1:
		var a := PI * k / steps
		pts.append(Vector2(cos(a) * half_width, sin(a) * height))
	return pts


static func _dial_marks(batch: MeshBatch, center: Vector3) -> void:
	# 十二道刻度、时针分针(十点十分,钟表店里最好看的角度)、中心的铜轴
	var iron := WorldMaterials.iron()
	for i in 12:
		var a := TAU * i / 12.0
		var long := 0.014 if i % 3 == 0 else 0.009
		batch.add_part(MeshKit.box(Vector3(0.004, long, 0.002)), iron,
			center + Vector3(sin(a), cos(a), 0) * (DIAL_RADIUS - 0.012), Vector3(0, 0, -rad_to_deg(a)))
	for hand in [[0.036, 0.007, -60.0], [0.056, 0.0045, 60.0]]:
		var a := deg_to_rad(hand[2])
		batch.add_part(MeshKit.box(Vector3(hand[1], hand[0], 0.002)), iron,
			center + Vector3(sin(a), cos(a), 0) * hand[0] / 2.0 + Vector3(0, 0, 0.001), Vector3(0, 0, -hand[2]))
	batch.add_part(MeshKit.cylinder(0.006, 0.006, 0.006, 10), WorldMaterials.brass(), center + Vector3(0, 0, 0.003),
		Vector3(90, 0, 0))


# —— 烛台与蜡烛 ——

static func _candlestick(batch: MeshBatch, base: Vector3, candle_height: float) -> void:
	var stick := PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0), Vector2(0.05, 0.008), Vector2(0.038, 0.016),
		Vector2(0.02, 0.026), Vector2(0.011, 0.045), Vector2(0.009, 0.09), Vector2(0.016, 0.1), Vector2(0.009, 0.11),
		Vector2(0.008, 0.155), Vector2(0.013, 0.165), Vector2(0.028, 0.172), Vector2(0.028, 0.18), Vector2(0, 0.18)])
	batch.add_part(MeshShapes.lathe(stick, 12), WorldMaterials.brass(), base)
	var h := candle_height
	var candle := PackedVector2Array([Vector2(0, 0), Vector2(0.019, 0), Vector2(0.019, h - 0.012),
		Vector2(0.016, h), Vector2(0.011, h - 0.005), Vector2(0, h - 0.007)])
	var wax := FireplaceMaterials.matte()
	var top := base + Vector3(0, 0.18, 0)
	batch.add_part(MeshShapes.lathe(candle, 12), wax, top, Vector3.ZERO, Vector3.ONE, WAX)
	batch.add_part(MeshKit.cylinder(0.0016, 0.0016, 0.014, 4), WorldMaterials.iron(), top + Vector3(0, h - 0.002, 0))
	# 蜡泪:沿烛身淌下的两道
	for a in [0.6, 2.9]:
		var drip := Vector3(cos(a) * 0.019, h - 0.03, sin(a) * 0.019)
		batch.add_part(MeshKit.capsule(0.0045, 0.04, 6), wax, top + drip, Vector3.ZERO, Vector3.ONE, WAX)


# —— 陶罐 ——

static func _jar(batch: MeshBatch, base: Vector3, glaze: Color, shape: String) -> void:
	var mat := FireplaceMaterials.glazed()
	match shape:
		"tall":
			batch.add_part(MeshShapes.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.042, 0), Vector2(0.055, 0.03),
				Vector2(0.06, 0.08), Vector2(0.05, 0.13), Vector2(0.034, 0.15), Vector2(0.034, 0.16), Vector2(0, 0.16)]), 16),
				mat, base, Vector3.ZERO, Vector3.ONE, glaze)
			batch.add_part(MeshShapes.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.042, 0), Vector2(0.042, 0.008),
				Vector2(0.03, 0.022), Vector2(0.009, 0.028), Vector2(0.013, 0.04), Vector2(0, 0.046)]), 16),
				mat, base + Vector3(0, 0.155, 0), Vector3.ZERO, Vector3.ONE, glaze.lightened(0.1))
		"squat":
			batch.add_part(MeshShapes.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0), Vector2(0.068, 0.035),
				Vector2(0.064, 0.07), Vector2(0.045, 0.09), Vector2(0.048, 0.1), Vector2(0.04, 0.1), Vector2(0.038, 0.085),
				Vector2(0, 0.085)]), 16), mat, base, Vector3.ZERO, Vector3.ONE, glaze)
		_:
			batch.add_part(MeshShapes.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.03, 0), Vector2(0.033, 0.08),
				Vector2(0.013, 0.11), Vector2(0.01, 0.14), Vector2(0.013, 0.145), Vector2(0, 0.145)]), 12),
				mat, base, Vector3.ZERO, Vector3.ONE, glaze)
			batch.add_part(MeshKit.cylinder(0.009, 0.008, 0.02, 8), FireplaceMaterials.matte(),
				base + Vector3(0, 0.15, 0), Vector3.ZERO, Vector3.ONE, Color(0.62, 0.45, 0.28))


# —— 旧书 ——

static func _books(batch: MeshBatch, base: Vector3) -> void:
	var y := 0.0
	for book in BOOKS:
		var size: Vector3 = book[0]
		batch.add_part(MeshShapes.rounded_box(size, 0.006, 1), FireplaceMaterials.matte(),
			base + Vector3(0, y + size.y / 2.0, 0), Vector3(0, book[2], 0), Vector3.ONE, book[1])
		y += size.y


# —— 鹿角 ——

static func _antlers(batch: MeshBatch, center: Vector3) -> void:
	# 盾形木牌 + 中间的角座 + 左右对称的鹿角(主干向外上方弯,分出三个叉)
	var plaque := PackedVector2Array([Vector2(-0.13, 0.13), Vector2(0.13, 0.13), Vector2(0.135, -0.02),
		Vector2(0.09, -0.12), Vector2(0.0, -0.17), Vector2(-0.09, -0.12), Vector2(-0.135, -0.02)])
	batch.add_part(MeshShapes.extrude(plaque, 0.035, 0.012), FireplaceMaterials.oak(), center, Vector3.ZERO,
		Vector3.ONE, Color(0.55, 0.38, 0.28), 0.8)
	var bone := FireplaceMaterials.bone()
	var mount := center + Vector3(0, 0.0, 0.03)
	batch.add_part(MeshShapes.deform(MeshKit.sphere(0.04, 12).get_mesh_arrays(), func(v: Vector3) -> Vector3:
		return Vector3(v.x * 1.3, v.y, v.z * 0.7)), bone, mount)
	for side in [-1.0, 1.0]:
		_antler(batch, bone, mount, side)


static func _antler(batch: MeshBatch, bone: Material, mount: Vector3, side: float) -> void:
	var beam := PackedVector3Array([Vector3(0.03, 0.01, 0.0), Vector3(0.12, 0.06, 0.05), Vector3(0.22, 0.16, 0.07),
		Vector3(0.28, 0.3, 0.05), Vector3(0.27, 0.42, 0.02)])
	var mirror := Vector3(side, 1, 1)
	batch.add_part(MeshShapes.tube(_scaled(beam, mirror), PackedFloat32Array([0.018, 0.016, 0.013, 0.01, 0.005]), 8),
		bone, mount)
	# 叉:[起点在主干上的位置, 终点]
	for tine in [[Vector3(0.07, 0.035, 0.03), Vector3(0.06, 0.1, 0.12)], [Vector3(0.15, 0.09, 0.06), Vector3(0.12, 0.24, 0.09)],
			[Vector3(0.23, 0.18, 0.07), Vector3(0.19, 0.33, 0.08)]]:
		var start: Vector3 = tine[0]
		var end: Vector3 = tine[1]
		var path := PackedVector3Array([start, start.lerp(end, 0.5) + Vector3(0.012, 0, 0.01), end])
		batch.add_part(MeshShapes.tube(_scaled(path, mirror), PackedFloat32Array([0.011, 0.008, 0.004]), 6), bone, mount)


static func _scaled(path: PackedVector3Array, factor: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for p in path:
		out.append(p * factor)
	return out
