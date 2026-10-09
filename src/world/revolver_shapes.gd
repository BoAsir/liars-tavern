class_name RevolverShapes
# 左轮专用的程序化几何:侧面轮廓的拼接小工具(圆弧、贝塞尔、锯齿)、鼓起的握把片(domed_panel)、
# 开着弹膛口的转轮前脸(holed_disc)与弹膛内壁(bore)、带槽线的转轮外壁(fluted_wall)。
# 与 MeshShapes 一样是纯函数,返回 Mesh.ARRAY_* 数组交给 MeshBatch;正面按 Godot 约定为"从外侧看顺时针"。

const SLAB_CREASE_DEG := 38.0   # 厚板轮廓上转角小于它的顶点按圆滑处理
const SLAB_ROUND := 0.45        # 倒角靠正面那条边的法线:水平分量只留这么多,像圆角的起点
const SLAB_SIDE_TILT := 0.3     # 倒角根(侧壁上下沿)的法线略朝外翻,侧壁看上去微微鼓
const PANEL_CROWN := 3.0        # 握把片隆起的指数:越大顶越平、边越陡


# —— 轮廓拼接(XY 平面,逆时针为正) ——

static func arc(center: Vector2, radius: float, from_deg: float, to_deg: float, steps: int) -> PackedVector2Array:
	# 圆弧上的点(含两端)
	var points := PackedVector2Array()
	for i in steps + 1:
		points.append(center + Vector2.from_angle(deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))) * radius)
	return points


static func bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, steps: int) -> PackedVector2Array:
	# 三次贝塞尔曲线上的点(含两端):握把背弧、扳机这类顺滑的弯
	var points := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		var u := 1.0 - t
		points.append(p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t)
	return points


static func teeth(from: Vector2, to: Vector2, count: int, height: float) -> PackedVector2Array:
	# from → to 之间的锯齿(击锤尖上的防滑齿)。逆时针轮廓的外侧在行进方向的右手边,齿尖朝那边
	var dir := (to - from).normalized()
	var outward := Vector2(dir.y, -dir.x) * height
	var points := PackedVector2Array()
	for i in count:
		var a := from.lerp(to, float(i) / count)
		var b := from.lerp(to, float(i + 1) / count)
		points.append(a)
		points.append((a + b) / 2.0 + outward)
	points.append(to)
	return points


static func join(parts: Array) -> PackedVector2Array:
	# 依次拼接多段点列,去掉重合的相邻点(重复点会生成零面积的侧壁)
	var out := PackedVector2Array()
	for part in parts:
		for p in (part as PackedVector2Array):
			if out.is_empty() or not out[out.size() - 1].is_equal_approx(p):
				out.append(p)
	if out.size() > 1 and out[0].is_equal_approx(out[out.size() - 1]):
		out.remove_at(out.size() - 1)
	return out


static func ccw(polygon: PackedVector2Array) -> PackedVector2Array:
	# 统一成逆时针(鼓起的握把片按逆时针轮廓算正面)
	var area := 0.0
	for i in polygon.size():
		area += polygon[i].cross(polygon[(i + 1) % polygon.size()])
	if area >= 0.0:
		return polygon
	var out := polygon.duplicate()
	out.reverse()
	return out


# —— 圆边厚板(机匣、握把芯、扳机护圈、击锤的侧面轮廓 + 厚度) ——

static func slab(polygon: PackedVector2Array, depth: float, bevel: float, crease_deg := SLAB_CREASE_DEG) -> Array:
	# 与 MeshShapes.extrude 相同的"轮廓沿 Z 拉伸 + 前后两面倒角",区别在法线:
	#   侧壁在转角小于 crease_deg 的顶点上共用平均法线,弧形轮廓(护圈、握把背弧)光滑而不是一条条棱面;
	#   倒角从侧壁一侧渐变到正面一侧,看上去像车圆的边,而不是一道 45° 的硬斜面。尖角处仍保持硬边
	var outline := ccw(polygon)
	var count := outline.size()
	var half := depth / 2.0
	var b := minf(bevel, half * 0.95)
	var face := _inset_ccw(outline, b)
	# 正面按内缩后的轮廓三角化:按原轮廓切的细长三角形在内缩后可能翻面(凹弧、锯齿处);
	# 内缩轮廓自相交(三角化失败)时才退回原轮廓
	var tris := Geometry2D.triangulate_polygon(face)
	if tris.is_empty():
		tris = Geometry2D.triangulate_polygon(outline)
	tris = _ccw_triangles(face, tris)
	var edge_n := PackedVector2Array()
	for i in count:
		var d := outline[(i + 1) % count] - outline[i]
		edge_n.append(Vector2(d.y, -d.x).normalized())
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	for side in [1.0, -1.0]:
		var base := verts.size()
		for p in face:
			verts.append(Vector3(p.x, p.y, half * side))
			normals.append(Vector3(0, 0, side))
			uvs.append(p)
		for t in range(0, tris.size(), 3):
			var order := [0, 2, 1] if side > 0.0 else [0, 1, 2]
			for k in order:
				indices.append(base + tris[t + k])
	# 每圈 = [轮廓, z, 法线的 z 分量, 法线水平分量的比例]:正面边 → 倒角根 → 侧壁 → 另一侧
	var rings := [[face, half, 1.0, SLAB_ROUND], [outline, half - b, SLAB_SIDE_TILT, 1.0],
		[outline, -half + b, -SLAB_SIDE_TILT, 1.0], [face, -half, -1.0, SLAB_ROUND]]
	var cos_crease := cos(deg_to_rad(crease_deg))
	for e in count:
		var e2 := (e + 1) % count
		var n_a := _vertex_normal(edge_n, e, e, cos_crease)
		var n_b := _vertex_normal(edge_n, e2, e, cos_crease)
		for r in rings.size() - 1:
			var base := verts.size()
			for row in [rings[r], rings[r + 1]]:
				var ring: PackedVector2Array = row[0]
				verts.append(Vector3(ring[e].x, ring[e].y, row[1]))
				verts.append(Vector3(ring[e2].x, ring[e2].y, row[1]))
				normals.append(Vector3(n_a.x * row[3], n_a.y * row[3], row[2]).normalized())
				normals.append(Vector3(n_b.x * row[3], n_b.y * row[3], row[2]).normalized())
				uvs.append_array([ring[e], ring[e2]])
			indices.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	return _arrays(verts, normals, uvs, indices)


static func _ccw_triangles(points: PackedVector2Array, tris: PackedInt32Array) -> PackedInt32Array:
	# 三角化结果逐个统一成逆时针,正面朝向才可靠
	var out := tris.duplicate()
	for t in range(0, out.size(), 3):
		var a := points[out[t]]
		if (points[out[t + 1]] - a).cross(points[out[t + 2]] - a) < 0.0:
			var swap := out[t + 1]
			out[t + 1] = out[t + 2]
			out[t + 2] = swap
	return out


static func _vertex_normal(edge_n: PackedVector2Array, vertex: int, edge: int, cos_crease: float) -> Vector2:
	# 顶点 vertex 上、属于边 edge 的侧壁法线:与相邻边夹角小(弧线上)就取两边平均,否则就用本边法线(硬边)
	var count := edge_n.size()
	var other := (vertex - 1 + count) % count if vertex == edge else vertex
	if edge_n[edge].dot(edge_n[other]) < cos_crease:
		return edge_n[edge]
	return (edge_n[edge] + edge_n[other]).normalized()


static func _inset_ccw(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	# 逆时针多边形逐点沿角平分线内缩(斜接),顶点与原轮廓一一对应
	var out := PackedVector2Array()
	var count := polygon.size()
	for i in count:
		var prev := polygon[i] - polygon[(i - 1 + count) % count]
		var next := polygon[(i + 1) % count] - polygon[i]
		var n1 := Vector2(-prev.y, prev.x).normalized()
		var n2 := Vector2(-next.y, next.x).normalized()
		var bisector := (n1 + n2).normalized()
		out.append(polygon[i] + bisector * amount / maxf(bisector.dot(n1), 0.25))
	return out


# —— 鼓起的握把片 ——

static func domed_panel(outline: PackedVector2Array, center: Vector2, height: float, rings: PackedFloat32Array) -> Array:
	# XY 平面上的轮廓(逆时针、相对 center 呈星形)向 +Z 鼓起:轮廓一圈圈按比例 s 缩向中心,
	# 高度 = height × √(1 - s^PANEL_CROWN)(中间饱满、边缘圆润地收下去),中心一个顶点收口。
	# 最外一圈略低于 z=0,贴进握把芯的侧面不露缝。rings:由外向内的缩放比例,首项为 1
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var count := outline.size()
	for s in rings:
		var z := height * sqrt(maxf(1.0 - pow(s, PANEL_CROWN), 0.0)) if s < 1.0 else -height * 0.04
		for p in outline:
			var q := center + (p - center) * s
			verts.append(Vector3(q.x, q.y, z))
			uvs.append(q)
	verts.append(Vector3(center.x, center.y, height))
	uvs.append(center)
	var indices := PackedInt32Array()
	for r in rings.size() - 1:
		for i in count:
			var o0 := r * count + i
			var o1 := r * count + (i + 1) % count
			# 逆时针轮廓从 +Z 看:(外, 内, 下一个外) 为顺时针 = 正面朝 +Z
			indices.append_array([o0, o0 + count, o1, o1, o0 + count, o1 + count])
	var tip := verts.size() - 1
	var last := (rings.size() - 1) * count
	for i in count:
		indices.append_array([last + i, tip, last + (i + 1) % count])
	return _arrays(verts, MeshShapes.smooth_normals(verts, indices), uvs, indices)


# —— 转轮前脸与弹膛 ——

static func sector_rays(holes: int, hole_circle: float, radius: float, samples: int) -> PackedFloat32Array:
	# 前脸按孔切成扇形后,从孔心发出的射线方向(相对扇形中线、指向外的角度,升序):
	# samples 条等角射线(偶数,含指向圆心的一条)+ 恰好射向扇形两个外角的两条,外框的角点都被采到,
	# 前脸边缘不缺角。弹膛内壁用同一组方向,孔边与内壁口的顶点一一重合
	var rays := PackedFloat32Array()
	for j in samples:
		rays.append(TAU * j / samples)
	var half := PI / holes
	for side in [-1.0, 1.0]:
		var corner := Vector2.from_angle(half * side) * radius - Vector2(hole_circle, 0.0)
		rays.append(fposmod(corner.angle(), TAU))
	rays.sort()
	var out := PackedFloat32Array()
	for a in rays:
		if out.is_empty() or a - out[out.size() - 1] > 1e-4:
			out.append(a)
	return out


static func holed_disc(radius: float, holes: int, hole_circle: float, hole_radius: float, rays: PackedFloat32Array,
		start_deg: float) -> Array:
	# XY 平面上半径 radius 的圆盘,在半径 hole_circle 的圆周上均匀开 holes 个圆孔(第一个在 start_deg 方位),
	# 正面朝 -Z。每个扇形里孔边一点连到同方向射线与扇形外框的交点;相邻扇形的公共边上点位对称重合,不裂缝
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	var sector := TAU / holes
	var count := rays.size()
	for k in holes:
		var theta := deg_to_rad(start_deg) + k * sector
		var hole := Vector2.from_angle(theta) * hole_circle
		var edges := [Vector2.from_angle(theta - sector / 2.0 + PI / 2.0), Vector2.from_angle(theta + sector / 2.0 - PI / 2.0)]
		var base := verts.size()
		for a in rays:
			var dir := Vector2.from_angle(theta + a)
			var inner := hole + dir * hole_radius
			var outer := hole + dir * _ray_to_sector(hole, dir, radius, edges)
			verts.append(Vector3(inner.x, inner.y, 0.0))
			verts.append(Vector3(outer.x, outer.y, 0.0))
		for j in count:
			var i0 := base + j * 2
			var i1 := base + ((j + 1) % count) * 2
			# 绕孔心逆时针排列:XY 平面里逆时针 = 从 -Z 看顺时针 = 正面朝 -Z
			indices.append_array([i0, i0 + 1, i1 + 1, i0, i1 + 1, i1])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.FORWARD)
	var uvs := PackedVector2Array()
	for v in verts:
		uvs.append(Vector2(v.x, v.y))
	return _arrays(verts, normals, uvs, indices)


static func bore(hole_radius: float, chamfer: float, depth: float, rays: PackedFloat32Array, start_rad: float) -> Array:
	# 从 z=0 的孔口沿 +Z 向里的盲孔:一圈倒角、内壁、孔底。法线朝孔内(从孔口看进去是正面)。
	# rays 与 start_rad 同 holed_disc 的扇形射线,孔口那圈顶点与前脸的孔边重合
	var rings := [[hole_radius + chamfer, 0.0], [hole_radius, chamfer], [hole_radius, depth]]
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var count := rays.size()
	for r in rings.size():
		var ring_radius: float = rings[r][0]
		for a in rays:
			var dir := Vector2.from_angle(start_rad + a)
			verts.append(Vector3(dir.x * ring_radius, dir.y * ring_radius, rings[r][1]))
			# 倒角斜面朝孔口与轴心之间,内壁朝轴心
			normals.append((Vector3(-dir.x, -dir.y, -1.0) if r == 0 else Vector3(-dir.x, -dir.y, 0.0)).normalized())
	var indices := PackedInt32Array()
	for r in rings.size() - 1:
		for j in count:
			var a0 := r * count + j
			var a1 := r * count + (j + 1) % count
			indices.append_array([a0, a1, a1 + count, a0, a1 + count, a0 + count])
	var bottom := verts.size()
	verts.append(Vector3(0.0, 0.0, depth))
	normals.append(Vector3.FORWARD)
	var last := (rings.size() - 1) * count
	for j in count:
		indices.append_array([last + j, last + (j + 1) % count, bottom])
	var uvs := PackedVector2Array()
	uvs.resize(verts.size())
	return _arrays(verts, normals, uvs, indices)


static func _ray_to_sector(origin: Vector2, dir: Vector2, radius: float, edges: Array) -> float:
	# 从扇形内一点沿 dir 射到扇形边界(外圆弧或两条过圆心的半径边)的距离;edges 为两条边指向扇形内侧的法线
	var along := origin.dot(dir)
	var t := -along + sqrt(along * along - origin.length_squared() + radius * radius)
	for normal in edges:
		var facing := (normal as Vector2).dot(dir)
		if facing < -1e-6:
			t = minf(t, -(normal as Vector2).dot(origin) / facing)
	return t


# —— 带槽线的转轮外壁 ——

static func fluted_wall(profile: PackedVector2Array, flute_depth: PackedFloat32Array, flutes: int,
		columns: PackedFloat32Array, column_depth: PackedFloat32Array, phase_deg: float) -> Array:
	# 绕 Z 轴的筒壁:profile 为 (半径, z) 沿轴向排列的行(z 从后往前递减),每行有自己的槽深 flute_depth
	# (两端为 0,槽线不切到端面)。每个弹膛间距按 columns(0..1 的不等距采样,0.5 为槽线中心)取点,
	# column_depth 为该列的槽深比例。phase_deg:第一条槽线中心的方位角。法线按位置焊接平滑,槽线是圆润的凹槽
	var pitch := TAU / flutes
	var angles := PackedFloat32Array()
	var depths := PackedFloat32Array()
	for k in flutes:
		for c in columns.size():
			angles.append(deg_to_rad(phase_deg) + (k + columns[c] - 0.5) * pitch)
			depths.append(column_depth[c])
	angles.append(angles[0] + TAU)
	depths.append(depths[0])
	var ring := angles.size()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for r in profile.size():
		for c in ring:
			var radius := profile[r].x - flute_depth[r] * depths[c]
			verts.append(Vector3(cos(angles[c]) * radius, sin(angles[c]) * radius, profile[r].y))
			uvs.append(Vector2(float(c) / (ring - 1), profile[r].y))
	var indices := PackedInt32Array()
	for r in profile.size() - 1:
		for c in ring - 1:
			var a := r * ring + c
			var b := a + ring
			# 列按逆时针、行沿 -Z 推进:(a, a+1, b) 从外侧看为顺时针
			indices.append_array([a, a + 1, b, a + 1, b + 1, b])
	return _arrays(verts, MeshShapes.smooth_normals(verts, indices), uvs, indices)


static func _arrays(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		indices: PackedInt32Array) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
