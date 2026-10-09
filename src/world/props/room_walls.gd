class_name RoomWalls
# 四面墙:木构架(角柱、立柱、压在柱头上接住天花板龙骨的顶梁、斜撑)+ 护墙板(踢脚线、上下冒头、立梃、
# 凸起的芯板、腰线)+ 灰泥。每面墙在自己的局部坐标里搭(RoomShapes.wall_frame)。
# 门、窗两侧的立柱兼作门框窗框;后墙的壁炉开间、左墙的吧台段给别的区域让位(吧台段不立柱子,只有贴墙的护墙板)。
# 右墙的灰泥是有厚度的盒子并投影:月光只能从窗洞照进屋;其余墙面朝屋里单面、不投影。


const POST := Vector2(0.16, 0.07)          # 立柱:沿墙宽 × 凸出墙面
const CORNER_POST := 0.17
const PLATE := Vector2(0.15, 0.2)          # 顶梁:凸出墙面 × 高
const PLATE_BOTTOM := 3.06
const PLATE_COVE := 0.05                 # 顶梁下沿凹圆线脚的半径
const BRACE := Vector2(0.11, 0.05)         # 斜撑截面:宽 × 凸出墙面
const BRACE_RISE := 0.7                    # 斜撑 45° 上升的高度(= 水平跨度)
const BRACE_BURY := 0.08                   # 斜撑两头埋进立柱、顶梁的长度
const BASEBOARD_TOP := 0.15
const RAIL_HEIGHT := 0.1
const TOP_RAIL_BOTTOM := 0.93
const PLASTER_BOTTOM := 1.07               # 灰泥下缘藏在腰线后面
const FRAME_DEPTH := 0.02                  # 冒头、立梃凸出墙面
const PANEL_DEPTH := 0.018
const PANEL_BEVEL := 0.008
const PANEL_OVERLAP := 0.004               # 芯板四边略压进框里,不留缝
const PANEL_TARGET := 0.6                  # 芯板目标宽度
const STILE_WIDTH := 0.07
const FIREPLACE_BAY_X := Vector2(-2.75, -0.25)   # 后墙让给壁炉的开间(世界 x)
const BACK_POST_X := 2.3                   # 后墙右侧两盏壁灯之间的立柱
const FRONT_POST_X := 3.0
const SIDE_POST_Z := [-3.0, 1.0, 3.0]      # 右墙落在大梁梁头下的立柱(z = -1 的梁头在窗洞上方,不立柱)
const LEFT_POST_Z := 3.0                   # 左墙其余梁头在吧台段或壁灯旁,只有托木
const BASEBOARD := [Vector2(0, 0), Vector2(0.026, 0), Vector2(0.026, 0.118), Vector2(0.02, 0.134),
	Vector2(0.01, 0.146), Vector2(0, 0.15)]
const CHAIR_RAIL := [Vector2(0, 1.04), Vector2(0.022, 1.04), Vector2(0.03, 1.048), Vector2(0.04, 1.062),
	Vector2(0.046, 1.08), Vector2(0.042, 1.098), Vector2(0.03, 1.11), Vector2(0.016, 1.12), Vector2(0, 1.12)]

const POST_TINT := Color(0.5, 0.46, 0.43)
const PANEL_TINT := Color(0.78, 0.72, 0.66)
const FRAME_TINT := Color(0.66, 0.6, 0.55)
const TRIM_TINT := Color(0.56, 0.5, 0.46)


static func add_shell(shell: MeshBatch) -> void:
	# 不投影:前、后、左墙的灰泥面,四面墙的护墙板
	var rng := RandomNumberGenerator.new()
	rng.seed = 4401
	for wall in RoomShapes.WALLS:
		var xf := RoomShapes.wall_frame(wall)
		if wall != RoomShapes.Wall.RIGHT:
			_add_plaster_faces(shell, wall, xf)
		for span in free_spans(layout(wall)):
			_add_wainscot(shell, xf, span, rng)


static func add_frame(frame: MeshBatch) -> void:
	# 投影:木构架与右墙墙体
	_add_window_wall(frame)
	for wall in RoomShapes.WALLS:
		var xf := RoomShapes.wall_frame(wall)
		_add_posts(frame, xf, layout(wall))
		_add_plates(frame, xf, wall)
	_add_corner_posts(frame)


static func layout(wall: RoomShapes.Wall) -> Dictionary:
	# posts:立柱中心 u;braces:[立柱 u, 斜撑朝向 ±1];gaps:不做护墙板的区段
	var half := POST.x / 2.0
	match wall:
		RoomShapes.Wall.BACK:
			var bay := fireplace_bay()
			var mid := RoomShapes.u_of(wall, BACK_POST_X)
			return {"posts": [bay.x - half, bay.y + half, mid], "braces": [[mid, -1.0], [mid, 1.0]], "gaps": [bay]}
		RoomShapes.Wall.RIGHT:
			var win := RoomWindow.opening()
			var posts: Array = [win.position.x - half, win.end.x + half]
			for z in SIDE_POST_Z:
				posts.append(RoomShapes.u_of(wall, z))
			return {"posts": posts, "braces": [[posts[2], 1.0], [posts[4], 1.0]], "gaps": []}
		RoomShapes.Wall.FRONT:
			var door := RoomDoor.opening()
			var post := RoomShapes.u_of(wall, FRONT_POST_X)
			return {"posts": [post, door.position.x - half, door.end.x + half], "braces": [[post, -1.0]],
				"gaps": [Vector2(door.position.x, door.end.x)]}
	var left := RoomShapes.u_of(wall, LEFT_POST_Z)
	return {"posts": [left], "braces": [[left, -1.0]], "gaps": []}


static func fireplace_bay() -> Vector2:
	return Vector2(RoomShapes.u_of(RoomShapes.Wall.BACK, FIREPLACE_BAY_X.x),
		RoomShapes.u_of(RoomShapes.Wall.BACK, FIREPLACE_BAY_X.y))


static func free_spans(plan: Dictionary) -> Array[Vector2]:
	# 角柱之间扣掉立柱与让位区段,剩下的一段段做护墙板
	var blocks: Array[Vector2] = []
	for post in plan["posts"]:
		blocks.append(Vector2(post - POST.x / 2.0, post + POST.x / 2.0))
	for gap in plan["gaps"]:
		blocks.append(gap)
	blocks.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var spans: Array[Vector2] = []
	var start := CORNER_POST
	for block in blocks:
		if block.x > start + 0.01:
			spans.append(Vector2(start, block.x))
		start = maxf(start, block.y)
	if RoomShapes.WALL_LENGTH - CORNER_POST > start + 0.01:
		spans.append(Vector2(start, RoomShapes.WALL_LENGTH - CORNER_POST))
	return spans


# —— 灰泥 ——

static func _add_window_wall(frame: MeshBatch) -> void:
	# 右墙:有厚度、投影的墙体,窗洞四周四块
	var xf := RoomShapes.wall_frame(RoomShapes.Wall.RIGHT)
	var depth := Tavern.WALL_THICKNESS
	for rect in RoomWindow.wall_blocks():
		var center := Vector3(rect.get_center().x, rect.get_center().y, -depth / 2.0)
		frame.add(MeshKit.box(Vector3(rect.size.x, rect.size.y, depth)), RoomMaterials.plaster(),
			xf * Transform3D(Basis(), center))


static func _add_plaster_faces(shell: MeshBatch, wall: RoomShapes.Wall, xf: Transform3D) -> void:
	for rect in _plaster_rects(wall):
		var center := Vector3(rect.get_center().x, rect.get_center().y, 0.0)
		shell.add(MeshKit.quad(rect.size), RoomMaterials.plaster(), xf * Transform3D(Basis(), center))


static func _plaster_rects(wall: RoomShapes.Wall) -> Array[Rect2]:
	var length := RoomShapes.WALL_LENGTH
	var top := Tavern.ROOM_HEIGHT
	var upper := Rect2(0.0, PLASTER_BOTTOM, length, top - PLASTER_BOTTOM)
	match wall:
		RoomShapes.Wall.BACK:
			var bay := fireplace_bay()
			return [upper, Rect2(bay.x, 0.0, bay.y - bay.x, PLASTER_BOTTOM)]
		RoomShapes.Wall.FRONT:
			var door := RoomDoor.opening()
			return [Rect2(0.0, PLASTER_BOTTOM, door.position.x, top - PLASTER_BOTTOM),
				Rect2(door.position.x, door.end.y, door.size.x, top - door.end.y),
				Rect2(door.end.x, PLASTER_BOTTOM, length - door.end.x, top - PLASTER_BOTTOM)]
	return [upper]


# —— 护墙板 ——

static func _add_wainscot(shell: MeshBatch, xf: Transform3D, span: Vector2, rng: RandomNumberGenerator) -> void:
	var timber := RoomMaterials.timber()
	add_run(shell, timber, xf, PackedVector2Array(BASEBOARD), span, TRIM_TINT)
	add_run(shell, timber, xf, PackedVector2Array(CHAIR_RAIL), span, TRIM_TINT)
	for v in [BASEBOARD_TOP, TOP_RAIL_BOTTOM]:
		var rail := RoomShapes.timber(Vector2(FRAME_DEPTH, RAIL_HEIGHT), span.y - span.x, 0.004)
		var center := Vector3((span.x + span.y) / 2.0, v + RAIL_HEIGHT / 2.0, FRAME_DEPTH / 2.0)
		shell.add_arrays(rail, timber, xf * RoomShapes.along_u(center), RoomShapes.tint(FRAME_TINT))
	_add_panels(shell, xf, span, rng)


static func _add_panels(shell: MeshBatch, xf: Transform3D, span: Vector2, rng: RandomNumberGenerator) -> void:
	# 立梃把一段护墙板等分成若干块凸起的芯板(两端由立柱/角柱收口)
	var timber := RoomMaterials.timber()
	var count := maxi(1, roundi((span.y - span.x) / PANEL_TARGET))
	var width := (span.y - span.x - (count - 1) * STILE_WIDTH) / count
	var v0 := BASEBOARD_TOP + RAIL_HEIGHT
	var v1 := TOP_RAIL_BOTTOM
	for i in count:
		var u0 := span.x + i * (width + STILE_WIDTH)
		var panel := RoomShapes.board(Vector3(width + PANEL_OVERLAP, v1 - v0 + PANEL_OVERLAP, PANEL_DEPTH), PANEL_BEVEL)
		var shade := PANEL_TINT * rng.randf_range(0.9, 1.06)
		shell.add_arrays(panel, timber, xf * Transform3D(Basis(), Vector3(u0 + width / 2.0, (v0 + v1) / 2.0, PANEL_DEPTH / 2.0)),
			RoomShapes.tint(shade, RoomShapes.GRAIN_Y))
		if i > 0:
			var stile := RoomShapes.timber(Vector2(STILE_WIDTH, FRAME_DEPTH), v1 - v0, 0.004)
			var center := Vector3(u0 - STILE_WIDTH / 2.0, (v0 + v1) / 2.0, FRAME_DEPTH / 2.0)
			shell.add_arrays(stile, timber, xf * RoomShapes.upright(center), RoomShapes.tint(FRAME_TINT))


static func add_run(batch: MeshBatch, slot: Variant, xf: Transform3D, profile: PackedVector2Array, span: Vector2,
		color: Color) -> void:
	# 线脚:剖面 (w, v) 沿墙从 span.x 拉到 span.y
	var arrays := MeshShapes.extrude(profile, span.y - span.x)
	batch.add_arrays(arrays, slot, xf * RoomShapes.along_u(Vector3((span.x + span.y) / 2.0, 0.0, 0.0)),
		RoomShapes.tint(color))


# —— 木构架 ——

static func _add_posts(frame: MeshBatch, xf: Transform3D, plan: Dictionary) -> void:
	var timber := RoomMaterials.timber()
	for u in plan["posts"]:
		var post := RoomShapes.timber(POST, PLATE_BOTTOM, 0.012)
		frame.add_arrays(post, timber, xf * RoomShapes.upright(Vector3(u, PLATE_BOTTOM / 2.0, POST.y / 2.0)),
			RoomShapes.tint(POST_TINT))
	for brace in plan["braces"]:
		_add_brace(frame, xf, brace[0], brace[1])


static func _add_brace(frame: MeshBatch, xf: Transform3D, post_u: float, direction: float) -> void:
	# 45° 斜撑:下端顶住立柱,上端顶住顶梁,两头各埋进去一截
	var length := BRACE_RISE * sqrt(2.0) + BRACE_BURY * 2.0
	var center := Vector3(post_u + direction * (POST.x / 2.0 + BRACE_RISE / 2.0), PLATE_BOTTOM - BRACE_RISE / 2.0,
		BRACE.y / 2.0)
	var brace := RoomShapes.timber(BRACE, length, 0.01)
	frame.add_arrays(brace, RoomMaterials.timber(), xf * RoomShapes.slanted(center, Vector2(direction, 1.0)),
		RoomShapes.tint(POST_TINT))


static func _add_plates(frame: MeshBatch, xf: Transform3D, wall: RoomShapes.Wall) -> void:
	# 顶梁沿墙通长;左右墙的顶梁顶到前后墙的顶梁为止,角上不重叠。后墙在壁炉开间断开(烟囱穿过)
	var runs: Array[Vector2] = [Vector2(0.0, RoomShapes.WALL_LENGTH)]
	if wall == RoomShapes.Wall.RIGHT or wall == RoomShapes.Wall.LEFT:
		runs = [Vector2(PLATE.x, RoomShapes.WALL_LENGTH - PLATE.x)]
	elif wall == RoomShapes.Wall.BACK:
		var bay := fireplace_bay()
		runs = [Vector2(0.0, bay.x), Vector2(bay.y, RoomShapes.WALL_LENGTH)]
	var profile := plate_profile()
	for run in runs:
		add_run(frame, RoomMaterials.timber(), xf, profile, run, POST_TINT)


static func plate_profile() -> PackedVector2Array:
	# 顶梁兼作檐口线脚:下沿朝屋里的棱挖一道凹圆(cove),顶上挑出一道压檐,和天花板交接处不再是生硬的方角
	var b := PLATE_BOTTOM
	var t := PLATE_BOTTOM + PLATE.y
	var p := PLATE.x
	return RoomShapes.joined([Vector2(0.0, b),
		RoomShapes.arc(Vector2(p, b), Vector2.ONE * PLATE_COVE, 180.0, 90.0, 5),
		Vector2(p, t - 0.04), Vector2(p + 0.012, t - 0.034), Vector2(p + 0.02, t - 0.02), Vector2(p + 0.022, t),
		Vector2(0.0, t)])


static func _add_corner_posts(frame: MeshBatch) -> void:
	var offset := RoomShapes.INNER - CORNER_POST / 2.0
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var post := RoomShapes.timber(Vector2(CORNER_POST, CORNER_POST), PLATE_BOTTOM, 0.018)
			frame.add_arrays(post, RoomMaterials.timber(),
				RoomShapes.upright(Vector3(sx * offset, PLATE_BOTTOM / 2.0, sz * offset)), RoomShapes.tint(POST_TINT))
