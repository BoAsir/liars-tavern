class_name DecorWalls
# 墙上的东西:前墙正中的黑板(木框、粉笔槽、粉笔与板擦)、黑板右边钉着的两张通缉令、前墙右角的置物架
# (铁托架、书、陶罐、锡盒)、右墙的风景油画与飞镖盘(两支飞镖扎在盘上)、后墙壁炉右边的狐狸绅士肖像。
# 画面全由 decor_canvas.gdshader 程序化绘制;画框是四根斜接的倒角木条(油画外框描金、内衬深色)。
# 都贴着墙、很薄,影子几乎看不见:全部进不投影的细节批。坐标用墙面局部系(RoomShapes.wall_frame)。


const PLASTER_GAP := 0.003                 # 贴在灰泥上的纸、板离墙面的距离
const CHALKBOARD := {"x": 0.0, "v": 1.74, "size": Vector2(1.1, 0.7)}
const POSTERS := [[2.24, 1.74, 3.0, 0.2], [2.52, 1.6, -5.0, 0.7]]   # [世界 x, 高, 歪斜角, 种子]
const POSTER_SIZE := Vector2(0.3, 0.42)
const LANDSCAPE := {"z": 2.46, "v": 1.8, "size": Vector2(0.62, 0.44), "seed": 0.0}
const SMALL_LANDSCAPE := {"z": 3.66, "v": 1.74, "size": Vector2(0.4, 0.3), "seed": 0.9}   # 左墙,衣帽架上方
const HORSESHOE := {"x": -2.8, "v": 2.5}   # 门楣上方,开口朝上留住好运
const HORSESHOE_RADIUS := Vector2(0.085, 0.095)
const PORTRAIT := {"x": 0.6, "v": 1.82, "size": Vector2(0.4, 0.52)}
const DARTBOARD := {"z": -2.45, "v": 1.72}
const DART_RADIUS := 0.225                 # 与 decor_canvas.gdshader 的 dart_radius 一致
const GILT_FRAME := Vector2(0.07, 0.035)   # 宽 × 厚
const LINER := Vector2(0.025, 0.018)
const GILT_TINT := Color(0.95, 0.78, 0.5)
const LINER_TINT := Color(0.3, 0.24, 0.2)
const BOARD_FRAME_TINT := Color(0.6, 0.52, 0.45)


static func add_to(detail: MeshBatch) -> void:
	_add_chalkboard(detail)
	_add_posters(detail)
	_add_painting(detail, RoomShapes.Wall.RIGHT, RoomShapes.u_of(RoomShapes.Wall.RIGHT, LANDSCAPE["z"]), LANDSCAPE["v"],
		LANDSCAPE["size"], DecorMaterials.CANVAS_LANDSCAPE, LANDSCAPE["seed"])
	_add_painting(detail, RoomShapes.Wall.LEFT, RoomShapes.u_of(RoomShapes.Wall.LEFT, SMALL_LANDSCAPE["z"]),
		SMALL_LANDSCAPE["v"], SMALL_LANDSCAPE["size"], DecorMaterials.CANVAS_LANDSCAPE, SMALL_LANDSCAPE["seed"])
	_add_painting(detail, RoomShapes.Wall.BACK, RoomShapes.u_of(RoomShapes.Wall.BACK, PORTRAIT["x"]), PORTRAIT["v"],
		PORTRAIT["size"], DecorMaterials.CANVAS_PORTRAIT)
	_add_horseshoe(detail)
	_add_dartboard(detail)
	DecorShelf.add_to(detail)


static func on_wall(wall: RoomShapes.Wall, u: float, v: float, w: float, roll_deg := 0.0) -> Transform3D:
	# 墙面局部 (u, v, w) → 世界;roll 绕墙面法线转(歪着钉的纸)
	return RoomShapes.wall_frame(wall) * Transform3D(Basis(Vector3.BACK, deg_to_rad(roll_deg)), Vector3(u, v, w))


static func add_frame(batch: MeshBatch, slot: Variant, xf: Transform3D, inner: Vector2, profile: Vector2,
		tint: Color, bevel := 0.008) -> void:
	# 四根斜接的木条围住 inner 大小的洞;xf 的原点在框背面中心,木条朝 +Z 凸出 profile.y
	var o := inner / 2.0 + Vector2.ONE * profile.x
	var i := inner / 2.0
	var outer_pts := [Vector2(-o.x, -o.y), Vector2(o.x, -o.y), Vector2(o.x, o.y), Vector2(-o.x, o.y)]
	var inner_pts := [Vector2(-i.x, -i.y), Vector2(i.x, -i.y), Vector2(i.x, i.y), Vector2(-i.x, i.y)]
	for k in 4:
		var k2 := (k + 1) % 4
		var member := PackedVector2Array([outer_pts[k], outer_pts[k2], inner_pts[k2], inner_pts[k]])
		var arrays := MeshShapes.extrude(member, profile.y, bevel)
		batch.add_arrays(arrays, slot, xf * Transform3D(Basis(), Vector3(0, 0, profile.y / 2.0)),
			RoomShapes.tint(tint, RoomShapes.GRAIN_X if k % 2 == 0 else RoomShapes.GRAIN_Y))


static func add_canvas(batch: MeshBatch, xf: Transform3D, size: Vector2, mode: float, seed := -1.0) -> void:
	var tint := Color(1, 1, 1, mode)
	batch.add_arrays(MeshKit.quad(size).get_mesh_arrays(), DecorMaterials.canvas(), xf, tint, seed)


# —— 黑板 ——

static func _add_chalkboard(detail: MeshBatch) -> void:
	var wall := RoomShapes.Wall.FRONT
	var size: Vector2 = CHALKBOARD["size"]
	var xf := on_wall(wall, RoomShapes.u_of(wall, CHALKBOARD["x"]), CHALKBOARD["v"], PLASTER_GAP)
	var backing := MeshShapes.rounded_box(Vector3(size.x + 0.02, size.y + 0.02, 0.012), 0.004, 1)
	detail.add_arrays(backing, RoomMaterials.timber(), xf * Transform3D(Basis(), Vector3(0, 0, 0.006)),
		RoomShapes.tint(LINER_TINT, RoomShapes.GRAIN_X))
	add_canvas(detail, xf * Transform3D(Basis(), Vector3(0, 0, 0.014)), size, DecorMaterials.CANVAS_CHALK)
	add_frame(detail, RoomMaterials.timber(), xf, size, Vector2(0.06, 0.03), BOARD_FRAME_TINT)
	# 粉笔槽:框下沿伸出的一条窄板,上面一截粉笔、一块板擦
	var ledge_v := -size.y / 2.0 - 0.06
	var ledge := MeshShapes.rounded_box(Vector3(size.x * 0.8, 0.018, 0.07), 0.005, 1)
	detail.add_arrays(ledge, RoomMaterials.timber(), xf * Transform3D(Basis(), Vector3(0, ledge_v, 0.035)),
		RoomShapes.tint(BOARD_FRAME_TINT, RoomShapes.GRAIN_X))
	var chalk := MeshShapes.tube(PackedVector3Array([Vector3(-0.03, 0, 0), Vector3(0.03, 0, 0)]), 0.006, 6)
	detail.add_arrays(chalk, DecorMaterials.matte(), xf * MeshBatch.xform_of(Vector3(-0.2, ledge_v + 0.015, 0.045),
		Vector3(0, 12, 0)), Color(0.92, 0.9, 0.84))
	var eraser := MeshShapes.rounded_box(Vector3(0.12, 0.03, 0.045), 0.006, 1)
	detail.add_arrays(eraser, DecorMaterials.matte(), xf * MeshBatch.xform_of(Vector3(0.24, ledge_v + 0.024, 0.04),
		Vector3(0, -6, 0)), Color(0.55, 0.38, 0.24))


# —— 通缉令 ——

static func _add_posters(detail: MeshBatch) -> void:
	var wall := RoomShapes.Wall.FRONT
	for i in POSTERS.size():
		var spec: Array = POSTERS[i]
		var xf := on_wall(wall, RoomShapes.u_of(wall, spec[0]), spec[1], PLASTER_GAP + i * 0.002, spec[2])
		add_canvas(detail, xf, POSTER_SIZE, DecorMaterials.CANVAS_POSTER, spec[3])
		# 四角的钉子(左下角那颗掉了,纸角微微翘着——只是少一颗钉)
		for corner in [Vector2(-1, 1), Vector2(1, 1), Vector2(1, -1)]:
			var at := Vector3(corner.x * (POSTER_SIZE.x / 2.0 - 0.02), corner.y * (POSTER_SIZE.y / 2.0 - 0.02), 0.002)
			var nail := MeshShapes.lathe(PackedVector2Array([Vector2(0.006, 0.0), Vector2(0.005, 0.003), Vector2(0.0, 0.004)]), 6)
			detail.add_arrays(nail, WorldMaterials.iron(), xf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), at))


# —— 油画 ——

static func _add_painting(detail: MeshBatch, wall: RoomShapes.Wall, u: float, v: float, size: Vector2, mode: float,
		seed := 0.0) -> void:
	# 画面退在描金外框与深色内衬后面;外框比内衬厚,形成一级级往里收的台阶
	var xf := on_wall(wall, u, v, PLASTER_GAP)
	add_canvas(detail, xf * Transform3D(Basis(), Vector3(0, 0, 0.012)), size, mode, seed)
	add_frame(detail, RoomMaterials.timber(), xf, size, LINER, LINER_TINT, 0.005)
	add_frame(detail, DecorMaterials.gilt(), xf, size + Vector2.ONE * LINER.x * 2.0, GILT_FRAME, GILT_TINT, 0.012)


# —— 马蹄铁 ——

static func _add_horseshoe(detail: MeshBatch) -> void:
	# 开口朝上的 U 形铁条,两脚末端外撇,钉在门楣上方的墙上;三颗钉头
	var wall := RoomShapes.Wall.FRONT
	var xf := on_wall(wall, RoomShapes.u_of(wall, HORSESHOE["x"]), HORSESHOE["v"], 0.012)
	var path := PackedVector3Array()
	for k in 13:
		var a := deg_to_rad(lerpf(160.0, 380.0, float(k) / 12.0))
		path.append(Vector3(cos(a) * HORSESHOE_RADIUS.x, sin(a) * HORSESHOE_RADIUS.y, 0.0))
	path.insert(0, path[0] + Vector3(-0.008, 0.018, 0.0))
	path.append(path[path.size() - 1] + Vector3(0.008, 0.018, 0.0))
	detail.add_arrays(MeshShapes.tube(path, 0.012, 6), WorldMaterials.iron(), xf)
	for at in [Vector3(-0.068, -0.05, 0.011), Vector3(0.0, -0.095, 0.011), Vector3(0.068, -0.05, 0.011)]:
		detail.add(MeshKit.sphere(0.007, 6), WorldMaterials.iron(), xf * Transform3D(Basis(), at))


# —— 飞镖盘 ——

static func _add_dartboard(detail: MeshBatch) -> void:
	var wall := RoomShapes.Wall.RIGHT
	var xf := on_wall(wall, RoomShapes.u_of(wall, DARTBOARD["z"]), DARTBOARD["v"], PLASTER_GAP)
	var backing := MeshShapes.rounded_box(Vector3(0.6, 0.6, 0.02), 0.012, 2)
	detail.add_arrays(backing, RoomMaterials.timber(), xf * Transform3D(Basis(), Vector3(0, 0, 0.01)),
		RoomShapes.tint(LINER_TINT, RoomShapes.GRAIN_Y))
	# 盘面:回转体的顶面朝屋里(局部 Y → 墙面法线),着色器按部件坐标的极坐标画格子
	var board := MeshShapes.lathe(PackedVector2Array([Vector2(DART_RADIUS * 1.02, 0.0), Vector2(DART_RADIUS * 1.02, 0.03),
		Vector2(DART_RADIUS * 1.02, 0.03), Vector2(DART_RADIUS, 0.038), Vector2(DART_RADIUS, 0.038), Vector2(0.0, 0.038)]), 40)
	var face_xf := xf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0, 0.02))
	detail.add_arrays(board, DecorMaterials.canvas(), face_xf, Color(1, 1, 1, DecorMaterials.CANVAS_DARTBOARD))
	for spec in [[Vector2(0.05, 0.07), Vector3(8, -6, 0)], [Vector2(-0.09, -0.03), Vector3(-5, 10, 0)]]:
		_add_dart(detail, xf * MeshBatch.xform_of(Vector3(spec[0].x, spec[0].y, 0.058), spec[1]))


static func _add_dart(detail: MeshBatch, xf: Transform3D) -> void:
	# 飞镖沿局部 +Z 伸出盘面:钢尖埋进盘里、黄铜镖身、杆、十字尾翼
	var body := PackedVector3Array([Vector3(0, 0, -0.012), Vector3(0, 0, 0.0), Vector3(0, 0, 0.05), Vector3(0, 0, 0.1)])
	detail.add_arrays(MeshShapes.tube(body, PackedFloat32Array([0.002, 0.005, 0.005, 0.0025]), 8), WorldMaterials.brass(), xf)
	var fin := MeshShapes.extrude(PackedVector2Array([Vector2(0, 0), Vector2(0.018, 0.012), Vector2(0.018, 0.045),
		Vector2(0, 0.04)]), 0.0015)
	for k in 4:
		var basis := Basis(Vector3.BACK, k * PI / 2.0) * Basis(Vector3.RIGHT, PI / 2.0)
		detail.add_arrays(fin, DecorMaterials.matte(), xf * Transform3D(basis, Vector3(0, 0, 0.058)), Color(0.7, 0.12, 0.1))
