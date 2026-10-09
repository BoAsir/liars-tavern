class_name RoomCeiling
# 地板、天花板与屋顶结构:四根大梁横跨左右墙(梁头下有托木),梁上一排龙骨顺前后方向铺、两头搁在前后墙的
# 顶梁上,龙骨上是天花板木板。壁炉烟囱穿过天花板处,龙骨截断在一根横向的承接梁上。
# 正中留空(两根梁、两根龙骨之间):吊灯的吊盒挂在天花板木板上,不被梁挡住。


const BEAM_Z := [-3.0, -1.0, 1.0, 3.0]
const BEAM := Vector2(0.22, 0.28)          # 宽 × 高
const BEAM_BOTTOM := 2.98
const JOIST := Vector2(0.1, 0.14)          # 宽 × 高(底面 = 顶梁顶面)
const JOIST_SPACING := 0.6
const JOIST_PAIRS := 7                     # x = ±0.3、±0.9 … ±3.9
const TRIMMER_Z := -3.45                   # 烟囱前的承接梁(壁炉地盘到 z = -3.5 为止)
const CORBEL_WIDTH := 0.16
const CORBEL_REACH := 0.3                  # 托木伸出墙面
const CORBEL_BOTTOM := 2.72                # 吧台段的高度上限是 2.7
const CORBEL_LIP := 0.04
const BEAM_TINT := Color(0.46, 0.42, 0.4)
const JOIST_TINT := Color(0.55, 0.5, 0.47)


static func add_shell(shell: MeshBatch) -> void:
	_add_floor_and_ceiling(shell)


static func add_frame(frame: MeshBatch) -> void:
	_add_beams(frame)
	_add_joists(frame)
	_add_corbels(frame)


static func joist_xs() -> Array[float]:
	var xs: Array[float] = []
	for i in JOIST_PAIRS:
		var x := JOIST_SPACING * (i + 0.5)
		xs.append_array([-x, x])
	return xs


static func _add_floor_and_ceiling(shell: MeshBatch) -> void:
	var size := Vector2.ONE * RoomShapes.WALL_LENGTH
	# 地板木板顺 Z 铺(从座位看过去一条条伸向壁炉);天花板木板顺 X,与龙骨垂直
	shell.add(MeshKit.plane(size), RoomMaterials.floor_boards(), MeshBatch.xform_of(Vector3.ZERO, Vector3(0, 90, 0)))
	shell.add(MeshKit.plane(size), RoomMaterials.ceiling_boards(),
		MeshBatch.xform_of(Vector3(0, Tavern.ROOM_HEIGHT, 0), Vector3(180, 0, 0)))


static func _add_beams(frame: MeshBatch) -> void:
	var length := RoomShapes.WALL_LENGTH - 0.002
	for z in BEAM_Z:
		var beam := RoomShapes.timber(BEAM, length, 0.025)
		frame.add_arrays(beam, RoomMaterials.timber(),
			RoomShapes.along_x(Vector3(0, BEAM_BOTTOM + BEAM.y / 2.0, z)), RoomShapes.tint(BEAM_TINT))


static func _add_joists(frame: MeshBatch) -> void:
	var y := Tavern.ROOM_HEIGHT - JOIST.y / 2.0
	var back := -RoomShapes.INNER
	var front := RoomShapes.INNER
	var cut_from := INF
	var cut_to := -INF
	for x in joist_xs():
		var in_chimney := x + JOIST.x / 2.0 > RoomWalls.FIREPLACE_BAY_X.x and x - JOIST.x / 2.0 < RoomWalls.FIREPLACE_BAY_X.y
		var start := TRIMMER_Z + JOIST.x / 2.0 if in_chimney else back
		_add_joist_z(frame, x, start, front, y)
		if in_chimney:
			cut_from = minf(cut_from, x)
			cut_to = maxf(cut_to, x)
	# 承接梁:两头顶到被截断那几根两侧的整根龙骨
	var trimmer_from := cut_from - JOIST_SPACING + JOIST.x / 2.0
	var trimmer_to := cut_to + JOIST_SPACING - JOIST.x / 2.0
	var trimmer := RoomShapes.timber(JOIST, trimmer_to - trimmer_from, 0.012)
	frame.add_arrays(trimmer, RoomMaterials.timber(),
		RoomShapes.along_x(Vector3((trimmer_from + trimmer_to) / 2.0, y, TRIMMER_Z)), RoomShapes.tint(BEAM_TINT))


static func _add_joist_z(frame: MeshBatch, x: float, z0: float, z1: float, y: float) -> void:
	var joist := RoomShapes.timber(JOIST, z1 - z0, 0.012)
	frame.add_arrays(joist, RoomMaterials.timber(), Transform3D(Basis(), Vector3(x, y, (z0 + z1) / 2.0)),
		RoomShapes.tint(JOIST_TINT))


static func _add_corbels(frame: MeshBatch) -> void:
	# 左右墙上每个梁头下一块托木:侧面是 1/4 椭圆弧,顶面托住梁底
	var profile := RoomShapes.joined([Vector2(0.0, BEAM_BOTTOM), Vector2(CORBEL_REACH, BEAM_BOTTOM),
		RoomShapes.arc(Vector2(0.0, BEAM_BOTTOM - CORBEL_LIP), Vector2(CORBEL_REACH, BEAM_BOTTOM - CORBEL_LIP - CORBEL_BOTTOM),
			0.0, -90.0, 6)])
	var corbel := MeshShapes.extrude(profile, CORBEL_WIDTH, 0.01)
	for wall in [RoomShapes.Wall.RIGHT, RoomShapes.Wall.LEFT]:
		var xf := RoomShapes.wall_frame(wall)
		for z in BEAM_Z:
			frame.add_arrays(corbel, RoomMaterials.timber(),
				xf * RoomShapes.along_u(Vector3(RoomShapes.u_of(wall, z), 0.0, 0.0)), RoomShapes.tint(BEAM_TINT))
