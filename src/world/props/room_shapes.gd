class_name RoomShapes
# 房间与陈设共用的几何小件(全部返回 MeshShapes 风格的数组,交给 MeshBatch 合批):倒角方木、弧线折点;
# 以及四面墙的局部坐标系 —— u 沿墙(从屋里看从左往右)、v 向上、w 指向屋里,原点在墙左端的墙脚。
# 木纹方向写在部件染色的 alpha 里(room_timber.gdshader 按它取纹理),部件按自然姿态建模即可。


enum Wall { BACK, RIGHT, FRONT, LEFT }

const WALLS: Array[Wall] = [Wall.BACK, Wall.RIGHT, Wall.FRONT, Wall.LEFT]
const INNER := Tavern.ROOM_HALF - Tavern.WALL_THICKNESS / 2.0   # 墙内表面离房间中心的距离
const WALL_LENGTH := INNER * 2.0
const GRAIN_Z := 1.0   # 顺纹沿局部 Z:梁、柱、线脚这些拉伸件
const GRAIN_Y := 0.5   # 顺纹沿局部 Y:竖立的板(芯板、门板、桶板)
const GRAIN_X := 0.0   # 顺纹沿局部 X


static func wall_frame(wall: Wall) -> Transform3D:
	# 墙面局部 → 世界:后墙 u = +X,右墙 u = +Z,前墙 u = -X,左墙 u = -Z;w 都指向屋里
	match wall:
		Wall.RIGHT:
			return Transform3D(Basis(Vector3.UP, -PI / 2.0), Vector3(INNER, 0.0, -INNER))
		Wall.FRONT:
			return Transform3D(Basis(Vector3.UP, PI), Vector3(INNER, 0.0, INNER))
		Wall.LEFT:
			return Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(-INNER, 0.0, INNER))
	return Transform3D(Basis.IDENTITY, Vector3(-INNER, 0.0, -INNER))


static func u_of(wall: Wall, coord: float) -> float:
	# 墙上一点的 u:后墙、前墙给世界 x,左右墙给世界 z
	match wall:
		Wall.FRONT, Wall.LEFT:
			return INNER - coord
	return coord + INNER


static func tint(color: Color, grain := GRAIN_Z) -> Color:
	return Color(color.r, color.g, color.b, grain)


# —— 摆放 ——

static func along_u(center: Vector3) -> Transform3D:
	# 拉伸件(剖面在 XY、沿 Z 拉伸)顺着墙走:剖面 x → w(朝屋里)、y → v,拉伸方向 → u
	return Transform3D(Basis(Vector3.UP, -PI / 2.0), center)


static func along_x(center: Vector3) -> Transform3D:
	# 拉伸件沿世界 X 走(横梁):剖面 x → -Z、y → Y
	return Transform3D(Basis(Vector3.UP, PI / 2.0), center)


static func upright(center: Vector3) -> Transform3D:
	# 拉伸件立起来:截面 x → X、y → -Z,拉伸方向 → Y(截面须对称)
	return Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), center)


static func slanted(center: Vector3, direction: Vector2) -> Transform3D:
	# 拉伸件斜放在墙面里(斜撑):拉伸方向 → (u, v) 平面里的 direction,截面 y → w
	var along := Vector3(direction.x, direction.y, 0.0).normalized()
	var depth := Vector3(0.0, 0.0, 1.0)
	return Transform3D(Basis(depth.cross(along), depth, along), center)


# —— 形状 ——

static func chamfered_rect(size: Vector2, chamfer: float) -> PackedVector2Array:
	var x := size.x / 2.0
	var y := size.y / 2.0
	var c := minf(chamfer, minf(x, y) * 0.9)
	return PackedVector2Array([Vector2(-x + c, -y), Vector2(x - c, -y), Vector2(x, -y + c), Vector2(x, y - c),
		Vector2(x - c, y), Vector2(-x + c, y), Vector2(-x, y - c), Vector2(-x, -y + c)])


static func timber(size: Vector2, length: float, chamfer := 0.01) -> Array:
	# 倒角方木:截面 size(局部 X × Y),沿局部 Z 长 length(居中),四条长棱倒 45° 角,端头平切
	return MeshShapes.extrude(chamfered_rect(size, chamfer), length)


static func board(size: Vector3, bevel: float) -> Array:
	# 平放的板(板面在 XY、厚度沿 Z):正反两面四周倒斜角 —— 凸起的芯板、门板、画框背板
	var x := size.x / 2.0
	var y := size.y / 2.0
	var outline := PackedVector2Array([Vector2(-x, -y), Vector2(x, -y), Vector2(x, y), Vector2(-x, y)])
	return MeshShapes.extrude(outline, size.z, bevel)


static func arc(center: Vector2, radius: Vector2, from_deg: float, to_deg: float, steps: int) -> PackedVector2Array:
	# 椭圆弧上的点(含两端),拼剖面用
	var points := PackedVector2Array()
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		points.append(center + Vector2(cos(a) * radius.x, sin(a) * radius.y))
	return points


static func joined(parts: Array) -> PackedVector2Array:
	# 把若干段点(Vector2 或 PackedVector2Array)首尾拼成一条折线
	var out := PackedVector2Array()
	for part in parts:
		if part is Vector2:
			out.append(part)
		else:
			out.append_array(part)
	return out
