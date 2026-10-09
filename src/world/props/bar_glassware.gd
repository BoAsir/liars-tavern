class_name BarGlassware
# 吧台上的杯与酒:前吧台面上两杯冒泡沫的啤酒(一杯正在酒头下接着)、两只箍铁圈的木酒杯、一瓶威士忌配两只小酒杯、
# 一块叠好的擦杯布;背吧台面上一排倒扣在布上晾干的啤酒杯、一只大陶壶;最低一层搁板下挂着一排倒挂的木酒杯。
# 都是小件,放进不投影的批次。坐标为吧台本地。


const COUNTER_Y := BarCounter.TOP_Y
const BACK_Y := BarBack.CABINET_TOP
const BEER := Color(0.78, 0.46, 0.1)
const WHISKEY := Color(0.72, 0.38, 0.1)
const CLOTH := Color(0.86, 0.82, 0.72)
const STRIPE := Color(0.55, 0.12, 0.08)
const FILL_UNIT := 0.5               # 玻璃着色器:顶点色 alpha = 液面高度 / 0.5 米
const PINT_HEIGHT := 0.15
const PINT_RADIUS := 0.034
const TANKARD_HEIGHT := 0.13
const TANKARD_RADIUS := 0.042
const SEGMENTS := 14
# 前吧台面:[类别, 位置(台面上), 绕 Y 转角]
const COUNTER_ITEMS := [
	["pint", Vector3(1.2, 0, 0.5), 0.0], ["tankard", Vector3(1.12, 0, -0.34), 120.0],
	["tankard", Vector3(1.22, 0, -1.3), 200.0], ["shot", Vector3(1.24, 0, -0.78), 0.0],
	["shot", Vector3(1.17, 0, -0.68), 0.0],
]
const TAP_GLASS_AT := Vector3(0.958, BarCounter.TOP_Y + 0.014, 0.95 + BarCounter.TAP_SPACING)   # 酒头下滴水盘上
const WHISKEY_AT := Vector3(1.08, 0, -0.84)
const TOWEL_AT := Vector3(1.0, 0, 0.42)
# 背吧台面上倒扣的玻璃杯与陶壶
const DRYING_ROW := [0.48, 0.57, 0.66, 0.75, 0.84]
const DRYING_X := 0.33
const JUG_AT := Vector3(0.2, 0, 1.36)
# 挂在最低一层搁板下的木酒杯:让开托架(z = ±0.42、±1.2)与正中立板(z = 0)
const HANGING_Z := [-0.31, -0.17, 0.17, 0.31, 0.62, 0.8, 0.98]
const HANGING_X := 0.12


static func add_to(batch: MeshBatch) -> void:
	for item in COUNTER_ITEMS:
		var at: Vector3 = item[1] + Vector3(0, COUNTER_Y, 0)
		match item[0]:
			"pint":
				_pint(batch, at, PINT_HEIGHT - 0.012)
			"tankard":
				_tankard(batch, at, item[2], true)
			"shot":
				_shot(batch, at)
	_pint(batch, TAP_GLASS_AT, PINT_HEIGHT * 0.55)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	BarBottles.add_bottle(batch, "whiskey", WHISKEY_AT + Vector3(0, COUNTER_Y, 0), 0.28, 0.037, BarBottles.GLASS["amber"],
		"wax_red", BarBottles.PAPER[0], rng)
	_towel(batch, TOWEL_AT + Vector3(0, COUNTER_Y, 0))
	_drying_row(batch)
	BarBottles.add_bottle(batch, "jug", JUG_AT + Vector3(0, BACK_Y, 0), 0.3, 0.07, Color.WHITE, "cork", Color.WHITE, rng)
	for z in HANGING_Z:
		_hanging_tankard(batch, Vector3(HANGING_X, 0, z), z)


# —— 杯子 ——

static func pint_arrays() -> Array:
	# 啤酒杯:实心的回转体(不透明玻璃,杯口封在液面高度);底部厚、上部微微鼓出一圈(诺尼克杯)
	var r := PINT_RADIUS
	var h := PINT_HEIGHT
	return MeshShapes.lathe(PackedVector2Array([Vector2(0, 0), Vector2(r * 0.8, 0), Vector2(r * 0.84, 0.006),
		Vector2(r * 1.02, h * 0.74), Vector2(r * 1.1, h * 0.83), Vector2(r * 1.04, h * 0.9), Vector2(r * 1.06, h),
		Vector2(r * 0.98, h), Vector2(r * 0.97, h - 0.008), Vector2(0, h - 0.008)]), SEGMENTS)


static func _pint(batch: MeshBatch, at: Vector3, level: float) -> void:
	batch.add_part(pint_arrays(), BarMaterials.glass(), at, Vector3.ZERO, Vector3.ONE,
		Color(BEER.r, BEER.g, BEER.b, level / FILL_UNIT))
	# 泡沫:从液面鼓到杯口上方,边上微微溢出
	var r := PINT_RADIUS * 1.0
	var foam := PackedVector2Array([Vector2(0, level - 0.004), Vector2(r, level - 0.004), Vector2(r * 1.04, level + 0.008),
		Vector2(r * 0.8, level + 0.02), Vector2(r * 0.4, level + 0.026), Vector2(0, level + 0.027)])
	batch.add_part(MeshShapes.lathe(foam, SEGMENTS), BarMaterials.foam(), at)


static func _shot(batch: MeshBatch, at: Vector3) -> void:
	var profile := PackedVector2Array([Vector2(0, 0), Vector2(0.019, 0), Vector2(0.02, 0.012), Vector2(0.023, 0.05),
		Vector2(0.021, 0.05), Vector2(0.02, 0.042), Vector2(0, 0.042)])
	batch.add_part(MeshShapes.lathe(profile, 10), BarMaterials.glass(), at, Vector3.ZERO, Vector3.ONE,
		Color(WHISKEY.r, WHISKEY.g, WHISKEY.b, 0.036 / FILL_UNIT))


static func tankard_arrays() -> Array:
	# 木酒杯:鼓肚的桶形,杯口内收一圈(液面/杯底封在里面)
	var r := TANKARD_RADIUS
	var h := TANKARD_HEIGHT
	return MeshShapes.lathe(PackedVector2Array([Vector2(0, 0), Vector2(r * 0.94, 0), Vector2(r, 0.008), Vector2(r * 1.04, h * 0.5),
		Vector2(r * 0.98, h), Vector2(r * 0.84, h), Vector2(r * 0.84, h - 0.012), Vector2(0, h - 0.012)]), SEGMENTS)


static func _tankard(batch: MeshBatch, at: Vector3, turn: float, foam: bool) -> void:
	var rot := Vector3(0, turn, 0)
	batch.add_part(tankard_arrays(), BarMaterials.keg(), at, rot)
	var r := TANKARD_RADIUS
	for y in [0.018, TANKARD_HEIGHT - 0.022]:
		var radius := r * (1.0 + 0.04 * (1.0 - absf(y / TANKARD_HEIGHT - 0.5) * 2.0)) + 0.002
		var hoop := PackedVector2Array([Vector2(radius, y - 0.006), Vector2(radius, y + 0.006)])
		batch.add_part(MeshShapes.lathe(hoop, SEGMENTS), WorldMaterials.iron(), at, rot)
	batch.add_part(MeshShapes.tube(_handle_path(), 0.007, 6), BarMaterials.keg(), at, rot)
	if foam:
		var h := TANKARD_HEIGHT
		var cap := PackedVector2Array([Vector2(0, h - 0.014), Vector2(r * 0.86, h - 0.014), Vector2(r * 0.9, h + 0.006),
			Vector2(r * 0.55, h + 0.018), Vector2(0, h + 0.02)])
		batch.add_part(MeshShapes.lathe(cap, SEGMENTS), BarMaterials.foam(), at, rot)


static func _handle_path() -> PackedVector3Array:
	# 侧面 D 形把手(朝部件 +X)
	var r := TANKARD_RADIUS
	var h := TANKARD_HEIGHT
	return PackedVector3Array([Vector3(r * 0.95, h * 0.82, 0), Vector3(r * 1.55, h * 0.8, 0), Vector3(r * 1.8, h * 0.62, 0),
		Vector3(r * 1.75, h * 0.36, 0), Vector3(r * 1.5, h * 0.24, 0), Vector3(r * 0.98, h * 0.22, 0)])


static func _hanging_tankard(batch: MeshBatch, at: Vector3, z: float) -> void:
	# 倒挂:杯底朝上贴近搁板,把手朝房间、挂在搁板底下的铁钩上
	var shelf_bottom := BarBack.SHELVES[0] - BarBack.SHELF_THICKNESS
	var top := shelf_bottom - 0.03
	var rot := Vector3(180, 0, 0)
	var center := Vector3(at.x, top, z)
	batch.add_part(tankard_arrays(), BarMaterials.keg(), center, rot, Vector3.ONE, Color(0.85, 0.8, 0.78), fposmod(z, 1.0))
	for y in [0.018, TANKARD_HEIGHT - 0.022]:
		var radius := TANKARD_RADIUS + 0.002
		var hoop := PackedVector2Array([Vector2(radius, y - 0.006), Vector2(radius, y + 0.006)])
		batch.add_part(MeshShapes.lathe(hoop, 10), WorldMaterials.iron(), center, rot)
	batch.add_part(MeshShapes.tube(_handle_path(), 0.007, 6), BarMaterials.keg(), center, rot)
	# 铁钩:从搁板底下垂下来,弯进把手(倒挂后把手最高点在杯底下方 0.22 × 杯高)
	var hook_x := at.x + TANKARD_RADIUS * 1.6
	var catch_y := top - TANKARD_HEIGHT * 0.22
	var hook := PackedVector3Array([Vector3(hook_x, shelf_bottom, z), Vector3(hook_x, catch_y + 0.006, z),
		Vector3(hook_x - 0.008, catch_y - 0.004, z), Vector3(hook_x - 0.018, catch_y + 0.002, z)])
	batch.add_part(MeshShapes.tube(hook, 0.0028, 5), WorldMaterials.iron())


static func _drying_row(batch: MeshBatch) -> void:
	# 背吧台面上一块条纹布,上面倒扣一排晾干的空啤酒杯
	var z0: float = DRYING_ROW[0] - 0.06
	var z1: float = DRYING_ROW[-1] + 0.06
	_cloth(batch, Vector3(DRYING_X, BACK_Y, (z0 + z1) / 2.0), Vector2(0.15, z1 - z0))
	for i in DRYING_ROW.size():
		var z: float = DRYING_ROW[i]
		var at := Vector3(DRYING_X + (0.012 if i % 2 == 0 else -0.01), BACK_Y + 0.004 + PINT_HEIGHT, z)
		batch.add_part(pint_arrays(), BarMaterials.glass(), at, Vector3(180, 0, 0), Vector3.ONE,
			Color(0.78, 0.9, 0.86, 0.0))


static func _towel(batch: MeshBatch, at: Vector3) -> void:
	# 叠成长条的擦杯布,斜放在台面上
	_cloth(batch, at, Vector2(0.12, 0.22), 24.0)


static func _cloth(batch: MeshBatch, at: Vector3, size: Vector2, turn := 0.0) -> void:
	var thickness := 0.008
	var rot := Vector3(0, turn, 0)
	batch.add_part(MeshShapes.rounded_box(Vector3(size.x, thickness, size.y), 0.003, 1), BarMaterials.ceramic(),
		at + Vector3(0, thickness / 2.0, 0), rot, Vector3.ONE, CLOTH)
	# 两道红条纹:薄薄一层浮在布面上
	for side in [-1.0, 1.0]:
		var offset := Basis.from_euler(Vector3(0, deg_to_rad(turn), 0)) * Vector3(0, 0, side * size.y * 0.32)
		batch.add_part(MeshKit.box(Vector3(size.x + 0.001, 0.001, 0.014)), BarMaterials.ceramic(),
			at + offset + Vector3(0, thickness + 0.0004, 0), rot, Vector3.ONE, STRIPE)
