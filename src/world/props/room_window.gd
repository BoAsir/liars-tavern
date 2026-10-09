class_name RoomWindow
# 右墙的月光窗:两扇对开的格子窗(窗框、中间对口梃、窗棂分成 4 × 3 小格)嵌在墙厚正中,窗台板压在腰线上,
# 窗洞上有过梁(两侧立柱由 RoomWalls 立);屋里挂一对束起的天鹅绒窗帘(RoomCurtains);
# 窗外是一块不受光照、不投影的夜空幕布(room_sky.gdshader 按视线方向画,像天空盒一样无限远)。
# 不装玻璃(大块透明面贵):窗框、窗棂投影,月光在地上投出窗格的影子。


const SASH_W := -Tavern.WALL_THICKNESS / 2.0   # 窗扇在墙厚正中
const SASH_DEPTH := 0.05
const FRAME_STILE := 0.055
const FRAME_SILL := 0.075
const MEETING_STILE := 0.06
const MUNTIN := Vector2(0.022, 0.03)
const MUNTIN_ROWS := 3
const HEADER_HEIGHT := 0.16
const STOOL_HORN := 0.1                         # 窗台板两头伸进立柱
const STOOL := [Vector2(-0.1, 1.12), Vector2(0.088, 1.12), Vector2(0.1, 1.13), Vector2(0.1, 1.152),
	Vector2(0.09, 1.165), Vector2(-0.1, 1.165)]
const LATCH := Vector3(0.012, 0.07, 0.012)
const SKY_W := -0.55                            # 夜空幕布在墙内表面往外这么远
const SKY_SIZE := Vector2(2.8, 2.4)
const SASH_TINT := Color(0.36, 0.38, 0.35)
const HEADER_TINT := Color(0.5, 0.46, 0.43)
const STOOL_TINT := Color(0.62, 0.56, 0.5)


static func opening() -> Rect2:
	# 窗洞在右墙局部坐标里的范围 (u, v)
	var u0 := RoomShapes.u_of(RoomShapes.Wall.RIGHT, Tavern.WINDOW_Z - Tavern.WINDOW_SIZE.x / 2.0)
	return Rect2(u0, Tavern.WINDOW_BOTTOM, Tavern.WINDOW_SIZE.x, Tavern.WINDOW_SIZE.y)


static func wall_blocks() -> Array[Rect2]:
	# 右墙扣掉窗洞后的四块墙体
	var win := opening()
	var length := RoomShapes.WALL_LENGTH
	var top := Tavern.ROOM_HEIGHT
	return [Rect2(0.0, 0.0, win.position.x, top), Rect2(win.position.x, 0.0, win.size.x, win.position.y),
		Rect2(win.position.x, win.end.y, win.size.x, top - win.end.y), Rect2(win.end.x, 0.0, length - win.end.x, top)]


static func add_shell(shell: MeshBatch) -> void:
	# 不投影:插销、夜空幕布、窗帘
	var xf := RoomShapes.wall_frame(RoomShapes.Wall.RIGHT)
	_add_latch(shell, xf)
	_add_sky(shell, xf)
	RoomCurtains.add_to(shell, xf, opening())


static func add_frame(frame: MeshBatch) -> void:
	# 投影:过梁、窗台板、窗扇
	var xf := RoomShapes.wall_frame(RoomShapes.Wall.RIGHT)
	_add_header_and_stool(frame, xf)
	_add_sash(frame, xf)


static func _add_header_and_stool(frame: MeshBatch, xf: Transform3D) -> void:
	var win := opening()
	var timber := RoomMaterials.timber()
	var header := RoomShapes.timber(Vector2(RoomWalls.POST.y, HEADER_HEIGHT), win.size.x, 0.012)
	var header_at := Vector3(win.get_center().x, win.end.y + HEADER_HEIGHT / 2.0, RoomWalls.POST.y / 2.0)
	frame.add_arrays(header, timber, xf * RoomShapes.along_u(header_at), RoomShapes.tint(HEADER_TINT))
	var stool := MeshShapes.extrude(PackedVector2Array(STOOL), win.size.x + STOOL_HORN * 2.0)
	frame.add_arrays(stool, timber, xf * RoomShapes.along_u(Vector3(win.get_center().x, 0.0, 0.0)),
		RoomShapes.tint(STOOL_TINT))


static func _add_sash(frame: MeshBatch, xf: Transform3D) -> void:
	# 外框 + 对口梃 + 每扇一根竖棂、两道横棂
	var win := opening()
	var u0 := win.position.x
	var u1 := win.end.x
	var uc := win.get_center().x
	var v_in0 := win.position.y + FRAME_SILL
	var v_in1 := win.end.y - FRAME_STILE
	var depth := Vector2(SASH_DEPTH, MUNTIN.y)
	for u in [u0 + FRAME_STILE / 2.0, u1 - FRAME_STILE / 2.0]:
		_upright(frame, xf, u, Vector2(win.position.y, win.end.y), Vector2(FRAME_STILE, depth.x))
	_upright(frame, xf, uc, Vector2(v_in0, v_in1), Vector2(MEETING_STILE, depth.x))
	_rail(frame, xf, Vector2(u0 + FRAME_STILE, u1 - FRAME_STILE), win.position.y + FRAME_SILL / 2.0,
		Vector2(depth.x, FRAME_SILL))
	_rail(frame, xf, Vector2(u0 + FRAME_STILE, u1 - FRAME_STILE), win.end.y - FRAME_STILE / 2.0,
		Vector2(depth.x, FRAME_STILE))
	var leaf := (u1 - u0 - FRAME_STILE * 2.0 - MEETING_STILE) / 2.0
	for u in [u0 + FRAME_STILE + leaf / 2.0, u1 - FRAME_STILE - leaf / 2.0]:
		_upright(frame, xf, u, Vector2(v_in0, v_in1), Vector2(MUNTIN.x, depth.y))
	for row in range(1, MUNTIN_ROWS):
		var v := lerpf(v_in0, v_in1, float(row) / MUNTIN_ROWS)
		_rail(frame, xf, Vector2(u0 + FRAME_STILE, u1 - FRAME_STILE), v, Vector2(depth.y, MUNTIN.x))


static func _upright(frame: MeshBatch, xf: Transform3D, u: float, span_v: Vector2, size: Vector2) -> void:
	var member := RoomShapes.timber(size, span_v.y - span_v.x, 0.005)
	var center := Vector3(u, (span_v.x + span_v.y) / 2.0, SASH_W)
	frame.add_arrays(member, RoomMaterials.timber(), xf * RoomShapes.upright(center), RoomShapes.tint(SASH_TINT))


static func _rail(frame: MeshBatch, xf: Transform3D, span_u: Vector2, v: float, size: Vector2) -> void:
	var member := RoomShapes.timber(size, span_u.y - span_u.x, 0.005)
	var center := Vector3((span_u.x + span_u.y) / 2.0, v, SASH_W)
	frame.add_arrays(member, RoomMaterials.timber(), xf * RoomShapes.along_u(center), RoomShapes.tint(SASH_TINT))


static func _add_latch(shell: MeshBatch, xf: Transform3D) -> void:
	# 对口梃上一只铁插销:竖杆 + 圆钮
	var win := opening()
	var at := Vector3(win.get_center().x, win.get_center().y, SASH_W + SASH_DEPTH / 2.0 + LATCH.z / 2.0)
	shell.add(MeshKit.box(LATCH), WorldMaterials.iron(), xf * Transform3D(Basis(), at))
	shell.add(MeshKit.sphere(0.009, 8), WorldMaterials.iron(), xf * Transform3D(Basis(), at + Vector3(0.0, -0.02, 0.012)))


static func _add_sky(shell: MeshBatch, xf: Transform3D) -> void:
	var win := opening()
	var at := Vector3(win.get_center().x, win.get_center().y, SKY_W)
	shell.add(MeshKit.quad(SKY_SIZE), RoomMaterials.sky(), xf * Transform3D(Basis(), at))
