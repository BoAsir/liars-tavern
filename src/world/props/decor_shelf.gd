class_name DecorShelf
# 前墙右角的置物架:一块厚木板搭在两只卷边铁托架上,上面一排高矮不一的书(两本歪靠着)、
# 一摞平放的书、两只釉面陶罐(带木塞)、一只锡盒。全部进不投影的细节批。坐标为前墙局部系。


const AT_X := 3.62                         # 架子中心(世界 x):右前角,离 x = 3 的立柱、角柱都有余地
const BOARD_V := 1.55
const BOARD := Vector3(0.86, 0.035, 0.22)
const BRACKET_U := 0.3                     # 托架离架子中心
const BOARD_TINT := Color(0.66, 0.56, 0.47)
const BOOKS_FROM := -0.38                  # 第一本书的左边缘(沿架子)
const BOOK_GAP := 0.003
# 书:[高, 厚, 深, 往左歪的角度, 颜色]。从左往右依次立着,歪的那本靠在左边邻居身上
const BOOKS := [
	[0.24, 0.045, 0.16, 0.0, Color(0.42, 0.12, 0.1)],
	[0.21, 0.038, 0.15, 0.0, Color(0.16, 0.24, 0.16)],
	[0.25, 0.05, 0.17, 0.0, Color(0.5, 0.36, 0.2)],
	[0.2, 0.035, 0.15, 0.0, Color(0.14, 0.17, 0.3)],
	[0.22, 0.04, 0.16, 0.0, Color(0.36, 0.1, 0.14)],
	[0.215, 0.042, 0.15, 22.0, Color(0.22, 0.3, 0.24)],
]
const FLAT_STACK_X := 0.315
# 平放的一摞:[宽, 深, 厚, 转角, 颜色]
const FLAT_STACK := [[0.21, 0.19, 0.045, -4.0, Color(0.3, 0.18, 0.12)], [0.19, 0.16, 0.035, 5.0, Color(0.5, 0.42, 0.28)]]
const CROCK := [Vector2(0.0, 0.0), Vector2(0.045, 0.0), Vector2(0.06, 0.02), Vector2(0.066, 0.07), Vector2(0.058, 0.12),
	Vector2(0.04, 0.14), Vector2(0.036, 0.15), Vector2(0.04, 0.16), Vector2(0.036, 0.165), Vector2(0.0, 0.165)]


static func add_to(detail: MeshBatch) -> void:
	var wall := RoomShapes.Wall.FRONT
	var xf := DecorWalls.on_wall(wall, RoomShapes.u_of(wall, AT_X), BOARD_V, 0.0)
	var board := MeshShapes.rounded_box(BOARD, 0.008, 2)
	detail.add_arrays(board, RoomMaterials.timber(), xf * Transform3D(Basis(), Vector3(0, 0, BOARD.z / 2.0)),
		RoomShapes.tint(BOARD_TINT, RoomShapes.GRAIN_X))
	for u in [-BRACKET_U, BRACKET_U]:
		_add_bracket(detail, xf * Transform3D(Basis(), Vector3(u, -BOARD.y / 2.0, 0)))
	var top := xf * Transform3D(Basis(), Vector3(0, BOARD.y / 2.0, 0))
	_add_books(detail, top)
	for spec in [[0.035, 1.0, Color(0.5, 0.34, 0.2)], [0.148, 0.72, Color(0.24, 0.3, 0.32)]]:
		_add_crock(detail, top * Transform3D(Basis.from_scale(Vector3.ONE * spec[1]), Vector3(spec[0], 0, 0.1)), spec[2])
	var stack_top := _add_flat_stack(detail, top)
	var tin := MeshShapes.rounded_box(Vector3(0.11, 0.06, 0.08), 0.008, 2)
	detail.add_arrays(tin, DecorMaterials.glazed(), top * MeshBatch.xform_of(Vector3(FLAT_STACK_X, stack_top + 0.03, 0.1),
		Vector3(0, 12, 0)), Color(0.55, 0.16, 0.12))


static func _add_bracket(detail: MeshBatch, xf: Transform3D) -> void:
	# 卷边铁托架:贴墙的竖条 + 托住板底的横条 + 一道 S 形卷曲的斜撑
	var iron := WorldMaterials.iron()
	var arm := PackedVector3Array([Vector3(0, -0.16, 0.012), Vector3(0, -0.006, 0.012), Vector3(0, -0.006, BOARD.z * 0.85)])
	detail.add_arrays(MeshShapes.tube(arm, 0.007, 6), iron, xf)
	var scroll := PackedVector3Array()
	for i in 9:
		var t := float(i) / 8.0
		var curl := sin(t * PI) * 0.025
		scroll.append(Vector3(0, -0.15 + t * 0.14 + curl, 0.014 + t * BOARD.z * 0.7 - curl * 0.6))
	detail.add_arrays(MeshShapes.tube(scroll, 0.005, 6), iron, xf)


static func _add_books(detail: MeshBatch, top: Transform3D) -> void:
	# 书立在板上(书脊朝外);cursor 是上一本的右边缘
	var cursor := BOOKS_FROM
	for spec in BOOKS:
		var size := Vector3(spec[1], spec[0], spec[2])
		var lean := deg_to_rad(spec[3])
		var center := Vector2(cursor + BOOK_GAP + size.x / 2.0, size.y / 2.0)
		if lean > 0.0:
			# 绕左下角往左倒,书顶的左角正好靠在邻居的右边上
			var pivot := cursor + size.y * sin(lean)
			center = Vector2(pivot + size.x / 2.0 * cos(lean) - size.y / 2.0 * sin(lean),
				size.x / 2.0 * sin(lean) + size.y / 2.0 * cos(lean))
		var xf := top * Transform3D(Basis(Vector3.BACK, lean), Vector3(center.x, center.y, size.z / 2.0 + 0.015))
		detail.add_arrays(MeshShapes.rounded_box(size, 0.004, 1), DecorMaterials.matte(), xf, spec[4])
		_add_book_bands(detail, xf, size)
		cursor = center.x + size.x / 2.0


static func _add_flat_stack(detail: MeshBatch, top: Transform3D) -> float:
	# 平放的一摞书,返回摞顶高度(锡盒放在上面)
	var y := 0.0
	for spec in FLAT_STACK:
		var size := Vector3(spec[0], spec[2], spec[1])
		var book := MeshShapes.rounded_box(size, 0.004, 1)
		detail.add_arrays(book, DecorMaterials.matte(), top * MeshBatch.xform_of(Vector3(FLAT_STACK_X, y + size.y / 2.0,
			0.11), Vector3(0, spec[3], 0)), spec[4])
		y += size.y
	return y


static func _add_book_bands(detail: MeshBatch, xf: Transform3D, size: Vector3) -> void:
	# 书脊上两道烫金横纹
	for v in [0.3, 0.7]:
		var band := MeshShapes.rounded_box(Vector3(size.x * 1.02, 0.008, 0.004), 0.001, 1)
		detail.add_arrays(band, DecorMaterials.gilt(), xf * Transform3D(Basis(), Vector3(0, (v - 0.5) * size.y, size.z / 2.0)),
			Color(0.9, 0.72, 0.4))


static func _add_crock(detail: MeshBatch, xf: Transform3D, color: Color) -> void:
	detail.add_arrays(MeshShapes.lathe(PackedVector2Array(CROCK), 16), DecorMaterials.glazed(), xf, color)
	var cork := MeshShapes.lathe(PackedVector2Array([Vector2(0.0, 0.15), Vector2(0.033, 0.15), Vector2(0.036, 0.185),
		Vector2(0.0, 0.188)]), 10)
	detail.add_arrays(cork, DecorMaterials.matte(), xf, Color(0.62, 0.46, 0.3))
