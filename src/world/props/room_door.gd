class_name RoomDoor
# 前墙(本机座位身后)的大门:粗木门框(两侧立柱由 RoomWalls 立,这里加门楣、门洞内衬、门槛),
# 竖拼的门板(倒角拼缝)、屋内一面三道横带 + 两道斜撑(Z 字),两条矛头形铁合页带着铆钉,
# 拉环、门闩与门扣。门板退进墙厚里一点,门洞内侧有内衬板,斜着看也不露空。坐标为前墙局部坐标。


const CENTER_X := -2.8                     # 门洞中心(世界 x):前墙左段,离 -1.7 的壁灯够远
const SIZE := Vector2(1.0, 2.1)
const LEAF_RECESS := 0.04                  # 门板屋内一面退进墙面
const LEAF_THICKNESS := 0.045
const PLANKS := 5
const PLANK_BEVEL := 0.008
const LINTEL := Vector2(0.09, 0.18)        # 门楣:凸出墙面 × 高
const LINING_DEPTH := 0.1
const LINING_THICKNESS := 0.02
const LEDGE_V := [0.32, 1.05, 1.78]        # 横带中心高度
const LEDGE := Vector2(0.028, 0.13)        # 横带:厚 × 高
const LEDGE_INSET := 0.05
const BRACE := Vector2(0.024, 0.11)
const STRAP_LENGTH := 0.74
const STRAP_THICKNESS := 0.006
const STRAP_WIDTH := 0.044
const RIVETS_PER_STRAP := 4
const RIVET := Vector2(0.009, 0.006)        # 半径 × 高
const KNUCKLE := Vector2(0.016, 0.13)      # 合页轴:半径 × 长
const RING_AT := Vector2(0.78, 1.28)       # 拉环在门洞里的 (u 比例, v):中间横带与斜撑之间
const LATCH_RISE := 0.16                   # 门闩在拉环上方
const LATCH_BAR := Vector3(0.24, 0.022, 0.014)
const THRESHOLD := Vector3(1.08, 0.022, 0.2)
const LEAF_TINT := Color(0.74, 0.62, 0.5)
const LEDGE_TINT := Color(0.64, 0.55, 0.46)
const FRAME_TINT := Color(0.5, 0.46, 0.43)


static func opening() -> Rect2:
	# 门洞在前墙局部坐标里的范围 (u, v)
	var u0 := RoomShapes.u_of(RoomShapes.Wall.FRONT, CENTER_X) - SIZE.x / 2.0
	return Rect2(u0, 0.0, SIZE.x, SIZE.y)


static func add_shell(shell: MeshBatch) -> void:
	var xf := RoomShapes.wall_frame(RoomShapes.Wall.FRONT)
	var door := opening()
	_add_frame(shell, xf, door)
	_add_leaf(shell, xf, door)
	_add_ledges(shell, xf, door)
	_add_hinges(shell, xf, door)
	_add_ring_and_latch(shell, xf, door)


static func _add_frame(shell: MeshBatch, xf: Transform3D, door: Rect2) -> void:
	var timber := RoomMaterials.timber()
	# 门楣压在两侧立柱上,比立柱凸出一点
	var lintel_len := door.size.x + RoomWalls.POST.x * 2.0
	var lintel := RoomShapes.timber(LINTEL, lintel_len, 0.015)
	shell.add_arrays(lintel, timber, xf * RoomShapes.along_u(Vector3(door.get_center().x, door.end.y + LINTEL.y / 2.0,
		LINTEL.x / 2.0)), RoomShapes.tint(FRAME_TINT))
	# 门洞内衬:两侧与顶上,从墙面退到门板后面
	var lining_w := -LINING_DEPTH / 2.0
	for u in [door.position.x + LINING_THICKNESS / 2.0, door.end.x - LINING_THICKNESS / 2.0]:
		var side := MeshKit.box(Vector3(LINING_THICKNESS, door.size.y, LINING_DEPTH))
		shell.add(side, timber, xf * Transform3D(Basis(), Vector3(u, door.size.y / 2.0, lining_w)), RoomShapes.tint(FRAME_TINT))
	var head := MeshKit.box(Vector3(door.size.x, LINING_THICKNESS, LINING_DEPTH))
	shell.add(head, timber, xf * Transform3D(Basis(), Vector3(door.get_center().x, door.end.y - LINING_THICKNESS / 2.0,
		lining_w)), RoomShapes.tint(FRAME_TINT, RoomShapes.GRAIN_X))
	var sill := RoomShapes.timber(Vector2(THRESHOLD.z, THRESHOLD.y), THRESHOLD.x, 0.008)
	shell.add_arrays(sill, timber, xf * RoomShapes.along_u(Vector3(door.get_center().x, THRESHOLD.y / 2.0, 0.0)),
		RoomShapes.tint(LEDGE_TINT))


static func _add_leaf(shell: MeshBatch, xf: Transform3D, door: Rect2) -> void:
	# 竖拼门板:每块单独倒角,拼缝处自然形成 V 形槽
	var width := (door.size.x - LINING_THICKNESS * 2.0) / PLANKS
	var w := -LEAF_RECESS - LEAF_THICKNESS / 2.0
	for i in PLANKS:
		var u := door.position.x + LINING_THICKNESS + width * (i + 0.5)
		var plank := RoomShapes.timber(Vector2(width, LEAF_THICKNESS), door.size.y - LINING_THICKNESS, PLANK_BEVEL)
		shell.add_arrays(plank, RoomMaterials.timber(), xf * RoomShapes.upright(Vector3(u, (door.size.y - LINING_THICKNESS) / 2.0, w)),
			RoomShapes.tint(LEAF_TINT * (0.94 + 0.04 * (i % 3))))


static func _add_ledges(shell: MeshBatch, xf: Transform3D, door: Rect2) -> void:
	# 三道横带钉在门板屋内一面,横带之间两道斜撑(下端在合页一侧)
	var timber := RoomMaterials.timber()
	var span := Vector2(door.position.x + LEDGE_INSET, door.end.x - LEDGE_INSET)
	var w := -LEAF_RECESS + LEDGE.x / 2.0
	for v in LEDGE_V:
		var ledge := RoomShapes.timber(LEDGE, span.y - span.x, 0.006)
		shell.add_arrays(ledge, timber, xf * RoomShapes.along_u(Vector3((span.x + span.y) / 2.0, v, w)),
			RoomShapes.tint(LEDGE_TINT))
	for k in LEDGE_V.size() - 1:
		var low := Vector2(span.x + BRACE.y, LEDGE_V[k] + LEDGE.y / 2.0)
		var high := Vector2(span.y - BRACE.y, LEDGE_V[k + 1] - LEDGE.y / 2.0)
		var center := (low + high) / 2.0
		var brace := RoomShapes.timber(Vector2(BRACE.y, BRACE.x), low.distance_to(high) + BRACE.y, 0.006)
		shell.add_arrays(brace, timber, xf * RoomShapes.slanted(Vector3(center.x, center.y, -LEAF_RECESS + BRACE.x / 2.0),
			high - low), RoomShapes.tint(LEDGE_TINT))


static func _add_hinges(shell: MeshBatch, xf: Transform3D, door: Rect2) -> void:
	# 矛头形铁合页压在上下两道横带上,合页轴贴着门洞一侧
	var iron := WorldMaterials.iron()
	var strap := MeshShapes.extrude(_strap_outline(), STRAP_THICKNESS, 0.0015)
	var rivet := MeshShapes.lathe(PackedVector2Array([Vector2(RIVET.x, 0), Vector2(RIVET.x * 0.7, RIVET.y * 0.75),
		Vector2(0, RIVET.y)]), 6)
	var w := -LEAF_RECESS + LEDGE.x + STRAP_THICKNESS / 2.0
	for v in [LEDGE_V[0], LEDGE_V[LEDGE_V.size() - 1]]:
		var start := door.position.x + LINING_THICKNESS
		shell.add_arrays(strap, iron, xf * Transform3D(Basis(), Vector3(start, v, w)))
		for k in RIVETS_PER_STRAP:
			var u := start + STRAP_LENGTH * (0.12 + 0.22 * k)
			shell.add_arrays(rivet, iron, xf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(u, v, w + STRAP_THICKNESS / 2.0)))
		shell.add(MeshKit.cylinder(KNUCKLE.x, KNUCKLE.x, KNUCKLE.y, 10), iron,
			xf * Transform3D(Basis(), Vector3(door.position.x + LINING_THICKNESS, v, w)))


static func _strap_outline() -> PackedVector2Array:
	# 合页带(局部 x 从合页轴往门里伸):渐细的带子,末端一个矛头
	var half := STRAP_WIDTH / 2.0
	var neck := STRAP_LENGTH * 0.86
	return PackedVector2Array([Vector2(0, -half), Vector2(neck, -half * 0.7), Vector2(neck - 0.02, -half * 1.6),
		Vector2(STRAP_LENGTH, 0), Vector2(neck - 0.02, half * 1.6), Vector2(neck, half * 0.7), Vector2(0, half)])


static func _add_ring_and_latch(shell: MeshBatch, xf: Transform3D, door: Rect2) -> void:
	# 拉环:圆形底板 + 垂下的铁环;门闩:横杆搭进门框立柱上的门扣
	var iron := WorldMaterials.iron()
	var face := -LEAF_RECESS
	var ring_u := door.position.x + door.size.x * RING_AT.x
	var plate := MeshShapes.lathe(PackedVector2Array([Vector2(0.045, 0), Vector2(0.04, 0.006), Vector2(0.012, 0.01),
		Vector2(0.01, 0.022), Vector2(0, 0.024)]), 12)
	shell.add_arrays(plate, iron, xf * Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(ring_u, RING_AT.y, face)))
	var ring := MeshKit.torus(0.05, 0.062, 14)
	ring.ring_segments = 6
	shell.add(ring, iron, xf * MeshBatch.xform_of(Vector3(ring_u, RING_AT.y - 0.055, face + 0.018), Vector3(90, 0, 0)))
	var bar_v := RING_AT.y + LATCH_RISE
	var bar := MeshKit.box(Vector3(LATCH_BAR.x, LATCH_BAR.y, LATCH_BAR.z))
	shell.add(bar, iron, xf * Transform3D(Basis(), Vector3(door.end.x - LINING_THICKNESS - LATCH_BAR.x / 2.0 - 0.01, bar_v,
		face + LATCH_BAR.z / 2.0)))
	var keeper := MeshKit.box(Vector3(0.026, 0.05, 0.026))
	shell.add(keeper, iron, xf * Transform3D(Basis(), Vector3(door.end.x - LINING_THICKNESS - 0.013, bar_v, face + 0.013)))
