class_name RoomCurtains
# 窗帘:铁杆(两头黄铜杆头,托架钉在窗洞两侧的立柱上)挂一对天鹅绒窗帘,半腰用金色绳子束到两边:
# 上半截垂成弧形的帘口,下半截散开垂到窗台上方。帘布是一张按褶皱起伏的网格(双面渲染),不投影。
# 坐标都是右墙局部坐标(u 沿墙、v 向上、w 朝屋里)。


const ROD_V := 2.64
const ROD_W := 0.15            # 杆子离墙
const ROD_RADIUS := 0.011
const ROD_OVERHANG := 0.38     # 杆子伸出窗洞两侧
const FINIAL_RADIUS := 0.024
const RING := Vector2(0.016, 0.021)
const RINGS_PER_PANEL := 6
const TOP_DROP := 0.024        # 帘布顶边挂在吊环下沿
const TIE_V := 1.6
const HEM_V := 1.24            # 帘布下摆,在窗台上方
const OUTER_INSET := 0.04      # 帘布外缘离杆头
const TOP_REACH := 0.36        # 帘口:顶边盖进窗洞多少
const TIE_REACH := -0.07       # 束起处在窗洞外侧
const HEM_REACH := 0.07
const FOLDS := 4.5
const FOLD_DEPTH := 0.014
const MAX_GATHER := 2.8        # 褶皱起伏随收拢程度加深的上限
const TIE_PULL := 0.025        # 绳子把帘布往墙边拉
const COLUMNS := 28
const ROWS_ABOVE_TIE := 9
const ROWS_BELOW_TIE := 7
const CORD_RADIUS := 0.008
const TASSEL := [Vector2(0.0, -0.1), Vector2(0.022, -0.1), Vector2(0.017, -0.035), Vector2(0.009, -0.012),
	Vector2(0.013, 0.0), Vector2(0.011, 0.012), Vector2(0.0, 0.017)]


static func add_to(shell: MeshBatch, xf: Transform3D, win: Rect2) -> void:
	_add_rod(shell, xf, win)
	for side in [-1.0, 1.0]:
		var edge := win.position.x if side < 0.0 else win.end.x
		var into: float = -side   # 从这一侧指向窗洞中间
		shell.add_arrays(_panel(edge, into), RoomMaterials.velvet(), xf, Color.WHITE)
		_add_tieback(shell, xf, edge, into)


static func _add_rod(shell: MeshBatch, xf: Transform3D, win: Rect2) -> void:
	var iron := WorldMaterials.iron()
	var u0 := win.position.x - ROD_OVERHANG
	var u1 := win.end.x + ROD_OVERHANG
	var rod := MeshShapes.tube(PackedVector3Array([Vector3(u0, ROD_V, ROD_W), Vector3(u1, ROD_V, ROD_W)]), ROD_RADIUS, 8)
	shell.add_arrays(rod, iron, xf)
	for u in [u0, u1]:
		shell.add(MeshKit.sphere(FINIAL_RADIUS, 10), WorldMaterials.brass(), xf * Transform3D(Basis(), Vector3(u, ROD_V, ROD_W)))
	# 托架:从窗洞两侧立柱的正面伸出来托住杆子
	for u in [win.position.x - RoomWalls.POST.x / 2.0, win.end.x + RoomWalls.POST.x / 2.0]:
		var path := PackedVector3Array([Vector3(u, ROD_V - 0.05, RoomWalls.POST.y), Vector3(u, ROD_V - 0.05, ROD_W - 0.02),
			Vector3(u, ROD_V, ROD_W)])
		shell.add_arrays(MeshShapes.tube(path, 0.007, 6), iron, xf)
	var ring := MeshKit.torus(RING.x, RING.y, 8)
	ring.ring_segments = 4
	for side in [-1.0, 1.0]:
		var edge := win.position.x if side < 0.0 else win.end.x
		for i in RINGS_PER_PANEL:
			var u := lerpf(_outer_u(edge, -side), edge - side * TOP_REACH, float(i) / (RINGS_PER_PANEL - 1))
			shell.add(ring, iron, xf * MeshBatch.xform_of(Vector3(u, ROD_V, ROD_W), Vector3(0, 0, 90)))


static func _outer_u(edge: float, into: float) -> float:
	return edge - into * (ROD_OVERHANG - OUTER_INSET)


static func _inner_u(edge: float, into: float, v: float) -> float:
	# 帘口内缘:顶上盖进窗洞,往下弧形收到束绳处,束绳以下散开
	var top_v := ROD_V - TOP_DROP
	if v >= TIE_V:
		var t := (top_v - v) / (top_v - TIE_V)
		return edge + into * lerpf(TOP_REACH, TIE_REACH, pow(t, 1.6))
	var s := (TIE_V - v) / (TIE_V - HEM_V)
	return edge + into * lerpf(TIE_REACH, HEM_REACH, 1.0 - (1.0 - s) * (1.0 - s))


static func _rows() -> PackedFloat32Array:
	# 束绳处正好落在一排顶点上,收口才利落
	var top_v := ROD_V - TOP_DROP
	var rows := PackedFloat32Array()
	for j in ROWS_ABOVE_TIE:
		rows.append(lerpf(top_v, TIE_V, float(j) / ROWS_ABOVE_TIE))
	for j in ROWS_BELOW_TIE + 1:
		rows.append(lerpf(TIE_V, HEM_V, float(j) / ROWS_BELOW_TIE))
	return rows


static func _depth(s: float, v: float, width: float, top_width: float) -> float:
	# 褶皱:收得越拢起伏越深;束绳附近整片被往墙边拉一点
	var gather := clampf(top_width / maxf(width, 0.01), 1.0, MAX_GATHER)
	var fold := FOLD_DEPTH * gather * sin(TAU * FOLDS * s + 0.5 * sin(v * 3.0))
	var pull := TIE_PULL * exp(-pow((v - TIE_V) / 0.18, 2.0))
	return ROD_W + fold - pull


static func _panel(edge: float, into: float) -> Array:
	var rows := _rows()
	var outer := _outer_u(edge, into)
	var top_width := absf(_inner_u(edge, into, rows[0]) - outer)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for v in rows:
		var inner := _inner_u(edge, into, v)
		var width := absf(inner - outer)
		for i in COLUMNS + 1:
			var s := float(i) / COLUMNS
			verts.append(Vector3(lerpf(outer, inner, s), v, _depth(s, v, width, top_width)))
			uvs.append(Vector2(s * top_width, rows[0] - v))
	var indices := _grid_indices(rows.size(), COLUMNS + 1, into < 0.0)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = MeshShapes.smooth_normals(verts, indices)
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays


static func _grid_indices(rows: int, columns: int, mirrored: bool) -> PackedInt32Array:
	# 从屋里看顺时针为正面;列方向朝 -u 时整张网格是镜像的,换绕序
	var indices := PackedInt32Array()
	for j in rows - 1:
		for i in columns - 1:
			var a := j * columns + i
			var b := a + 1
			var c := a + columns
			var d := c + 1
			if mirrored:
				indices.append_array([a, c, b, b, c, d])
			else:
				indices.append_array([a, b, c, b, d, c])
	return indices


static func _add_tieback(shell: MeshBatch, xf: Transform3D, edge: float, into: float) -> void:
	# 金色绳圈套住收拢的帘布,外侧垂一只流苏
	var outer := _outer_u(edge, into)
	var inner := _inner_u(edge, into, TIE_V)
	var center := Vector2((outer + inner) / 2.0, ROD_W - TIE_PULL)
	var radius := Vector2(absf(inner - outer) / 2.0 + 0.02, FOLD_DEPTH * MAX_GATHER + 0.016)
	var loop := PackedVector3Array()
	for k in 17:
		var a := TAU * k / 16.0
		loop.append(Vector3(center.x + cos(a) * radius.x, TIE_V, center.y + sin(a) * radius.y))
	var brass := WorldMaterials.brass()
	shell.add_arrays(MeshShapes.tube(loop, CORD_RADIUS, 6, false), brass, xf)
	var hang := Vector3(center.x - into * radius.x, TIE_V, center.y)
	shell.add_arrays(MeshShapes.tube(PackedVector3Array([hang, hang + Vector3(0, -0.06, 0)]), CORD_RADIUS * 0.7, 5), brass, xf)
	shell.add_arrays(MeshShapes.lathe(PackedVector2Array(TASSEL), 10), brass, xf * Transform3D(Basis(), hang + Vector3(0, -0.075, 0)))
