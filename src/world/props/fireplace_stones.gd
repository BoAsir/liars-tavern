class_name FireplaceStones
# 砌石生成器:单块方石 = 微微鼓起的正面(扇形铺开、边缘法线外倾,着色像枕头一样圆润)+ 一圈 45° 倒角 +
# 埋进灰浆芯的侧壁(不做背面,反正看不见);以及按层错缝把一个面铺满石块、洞口与拱券处让开的排布。
# 炉体、烟囱、炉床、拱石都用它。石块轮廓在 XY 平面,石块从 z=0(埋在灰浆芯里)伸到 z=depth(正面),
# 摆放时用所在墙面的坐标系(X 向右、Y 向上、Z 朝外)变换过去。


const PILLOW := 0.42                 # 正面边缘法线外倾的程度:越大石面看起来越鼓
const MIN_AREA := 0.0016             # 裁剪后比这小的碎块不要(露出灰浆,像石缝里塞的碎石)
const MIN_EXTENT := 0.035            # 碎块包围盒最窄处
const CORNER_CUT := Vector2(0.01, 0.03)   # 方石四角随机削去的范围:不再像砖,像手工錾过的石头


# —— 单块石头 ——

static func stone(outline: PackedVector2Array, depth: float, bevel: float, bulge := 0.0) -> Array:
	var poly := _without_slivers(ccw(outline), bevel)
	var box := bounds_of(poly)
	var bv := minf(bevel, minf(box.size.x, box.size.y) * 0.22)
	var face := inset(poly, bv)
	var convex := is_convex(poly)
	if not convex and Geometry2D.triangulate_polygon(face).is_empty():
		# 凹轮廓内缩后自交(三角化失败会留下一个空心的框):这块就不倒角,正面直接用轮廓
		bv = 0.0
		face = poly
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	_front(verts, normals, indices, face, depth, bulge if convex else 0.0)
	var n := poly.size()
	for i in n:
		var j := (i + 1) % n
		var edge := poly[j] - poly[i]
		var out := Vector2(edge.y, -edge.x).normalized()
		# 倒角:法线 45°,迎光时亮出一道细边,石块的轮廓因此读得出来
		if bv > 0.0:
			quad(verts, normals, indices, [Vector3(face[i].x, face[i].y, depth), Vector3(face[j].x, face[j].y, depth),
				Vector3(poly[j].x, poly[j].y, depth - bv), Vector3(poly[i].x, poly[i].y, depth - bv)],
				Vector3(out.x, out.y, 1.0).normalized())
		quad(verts, normals, indices, [Vector3(poly[i].x, poly[i].y, depth - bv),
			Vector3(poly[j].x, poly[j].y, depth - bv), Vector3(poly[j].x, poly[j].y, 0.0),
			Vector3(poly[i].x, poly[i].y, 0.0)], Vector3(out.x, out.y, 0.0))
	return to_arrays(verts, normals, indices)


static func _without_slivers(poly: PackedVector2Array, bevel: float) -> PackedVector2Array:
	# 贴着拱券裁出来的轮廓常带几毫米长的碎边,内缩时会自交:比倒角还短的边并掉(形状最多差几毫米)
	var min_edge := bevel * 0.8
	var out := PackedVector2Array()
	for p in poly:
		if out.is_empty() or p.distance_to(out[out.size() - 1]) >= min_edge:
			out.append(p)
	while out.size() > 3 and out[0].distance_to(out[out.size() - 1]) < min_edge:
		out.remove_at(out.size() - 1)
	return out if out.size() >= 3 else poly


static func _front(verts: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array,
		face: PackedVector2Array, depth: float, bulge: float) -> void:
	# 凸轮廓从鼓起的中心扇形铺开;凹轮廓(贴着拱券裁出来的)直接三角化,只靠法线外倾显得圆润
	var center := centroid(face)
	var base := verts.size()
	for p in face:
		var out := (p - center).normalized() * PILLOW
		verts.append(Vector3(p.x, p.y, depth))
		normals.append(Vector3(out.x, out.y, 1.0).normalized())
	var tris := PackedInt32Array()
	if bulge > 0.0:
		verts.append(Vector3(center.x, center.y, depth + bulge))
		normals.append(Vector3(0, 0, 1))
		for i in face.size():
			tris.append_array([face.size(), i, (i + 1) % face.size()])
	else:
		tris = Geometry2D.triangulate_polygon(face)
	for t in range(0, tris.size(), 3):
		tri(indices, verts, base + tris[t], base + tris[t + 1], base + tris[t + 2], Vector3(0, 0, 1))


# —— 按层错缝铺石 ——

static func lay_rows(rows: Array, holes: Array, span: Vector2, joint: float, rng: RandomNumberGenerator) -> Array:
	# rows:每层一块区域(XY 多边形,通常是一条横带);holes:要让开的区域(炉口、拱券);span:石块长度范围。
	# 每层的起点随机,上下层自然错缝;洞口两侧强制断开,紧挨洞口的石块不会被切成细条。
	# 返回各块石头的轮廓(已按灰缝内缩一半)
	var stones := []
	for region in rows:
		var box := bounds_of(region)
		var cuts := _cuts(box, holes, span, rng)
		for i in cuts.size() - 1:
			var block := chipped_rect(Rect2(cuts[i], box.position.y, cuts[i + 1] - cuts[i], box.size.y), rng)
			for piece in Geometry2D.intersect_polygons(block, region):
				for part in subtract(piece, holes):
					stones.append_array(shrunk(part, joint / 2.0))
	return stones


static func _cuts(box: Rect2, holes: Array, span: Vector2, rng: RandomNumberGenerator) -> PackedFloat32Array:
	# 一层里各块石头的分界 x:洞口在这一层的左右边界必须断开,其余按随机长度排,太短的尾巴并进前一块
	var forced := PackedFloat32Array([box.position.x, box.end.x])
	var band := PackedVector2Array([box.position, Vector2(box.end.x, box.position.y), box.end,
		Vector2(box.position.x, box.end.y)])
	for hole in holes:
		for piece in Geometry2D.intersect_polygons(hole, band):
			var extent := bounds_of(piece)
			if extent.size.x > 0.0 and extent.size.y > box.size.y * 0.25:
				forced.append_array([extent.position.x, extent.end.x])
	forced.sort()
	var cuts := PackedFloat32Array()
	for k in forced.size() - 1:
		var x := forced[k]
		var end := forced[k + 1]
		cuts.append(x)
		if end - x < span.x * 0.5:
			continue
		x += rng.randf_range(span.x * 0.6, span.y)
		while x < end - span.x * 0.6:
			cuts.append(x)
			x += rng.randf_range(span.x, span.y)
	cuts.append(forced[forced.size() - 1])
	return cuts


static func chipped_rect(rect: Rect2, rng: RandomNumberGenerator) -> PackedVector2Array:
	# 四角各削去一小块(大小随机):八边形的轮廓读起来是錾圆了角的石头
	var a := rect.position
	var b := rect.end
	var c := [rng.randf_range(CORNER_CUT.x, CORNER_CUT.y), rng.randf_range(CORNER_CUT.x, CORNER_CUT.y),
		rng.randf_range(CORNER_CUT.x, CORNER_CUT.y), rng.randf_range(CORNER_CUT.x, CORNER_CUT.y)]
	return PackedVector2Array([Vector2(a.x + c[0], a.y), Vector2(b.x - c[1], a.y), Vector2(b.x, a.y + c[1]),
		Vector2(b.x, b.y - c[2]), Vector2(b.x - c[2], b.y), Vector2(a.x + c[3], b.y), Vector2(a.x, b.y - c[3]),
		Vector2(a.x, a.y + c[0])])


static func subtract(poly: PackedVector2Array, holes: Array) -> Array:
	var parts := [poly]
	for hole in holes:
		var next := []
		for part in parts:
			next.append_array(Geometry2D.clip_polygons(part, hole))
		parts = next
	return parts


static func shrunk(poly: PackedVector2Array, amount: float) -> Array:
	# 按灰缝宽度的一半内缩;碎得太小的不要
	var out := []
	for piece in Geometry2D.offset_polygon(poly, -amount, Geometry2D.JOIN_MITER):
		if Geometry2D.is_polygon_clockwise(piece):
			continue
		var box := bounds_of(piece)
		if absf(signed_area(piece)) >= MIN_AREA and minf(box.size.x, box.size.y) >= MIN_EXTENT:
			out.append(piece)
	return out


# —— 多边形工具 ——

static func ccw(poly: PackedVector2Array) -> PackedVector2Array:
	if signed_area(poly) >= 0.0:
		return poly
	var out := poly.duplicate()
	out.reverse()
	return out


static func signed_area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	return area / 2.0


static func centroid(poly: PackedVector2Array) -> Vector2:
	var area := 0.0
	var sum := Vector2.ZERO
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var cross := a.x * b.y - b.x * a.y
		area += cross
		sum += (a + b) * cross
	if absf(area) < 1e-9:
		return bounds_of(poly).get_center()
	return sum / (3.0 * area)


static func bounds_of(poly: PackedVector2Array) -> Rect2:
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	return box


static func is_convex(poly: PackedVector2Array) -> bool:
	var n := poly.size()
	for i in n:
		var a := poly[(i + 1) % n] - poly[i]
		var b := poly[(i + 2) % n] - poly[(i + 1) % n]
		if a.cross(b) < -1e-7:
			return false
	return true


static func inset(poly: PackedVector2Array, amount: float) -> PackedVector2Array:
	# 逆时针多边形逐点沿角平分线内缩(斜接),顶点一一对应,倒角四边形才连得上
	var out := PackedVector2Array()
	var n := poly.size()
	for i in n:
		var prev := poly[i] - poly[(i - 1 + n) % n]
		var next := poly[(i + 1) % n] - poly[i]
		var n1 := Vector2(-prev.y, prev.x).normalized()
		var n2 := Vector2(-next.y, next.x).normalized()
		var bisector := (n1 + n2).normalized()
		out.append(poly[i] + bisector * amount / maxf(bisector.dot(n1), 0.3))
	return out


# —— 网格工具 ——

static func quad(verts: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array,
		corners: Array, normal: Vector3) -> void:
	# 四个角按环绕顺序给出;法线统一(硬边),三角形按法线摆正朝向
	var base := verts.size()
	for c in corners:
		verts.append(c)
		normals.append(normal)
	tri(indices, verts, base, base + 1, base + 2, normal)
	tri(indices, verts, base, base + 2, base + 3, normal)


static func tri(indices: PackedInt32Array, verts: PackedVector3Array, a: int, b: int, c: int,
		outward: Vector3) -> void:
	# Godot 正面为顺时针:三角形 (a,b,c) 的几何外法线 ∝ (c-a)×(b-a)。与期望朝向相反就交换两个顶点
	var n := (verts[c] - verts[a]).cross(verts[b] - verts[a])
	if n.dot(outward) >= 0.0:
		indices.append_array([a, b, c])
	else:
		indices.append_array([a, c, b])


static func to_arrays(verts: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> Array:
	var uvs := PackedVector2Array()
	for v in verts:
		uvs.append(Vector2(v.x, v.y))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
