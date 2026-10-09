class_name BarShapes
# 吧台用的几何:型材沿长度扫出(台面圆鼻边、檐口、凹弧线脚、踢脚线)、半圆的车木壁柱、涡卷托架,
# 以及给部件定朝向的坐标系。木纹顺部件自身的 X 轴(BarMaterials.wood),所以型材沿 X 扫、长边沿 X 建,
# 摆放时再转过去;竖着的车木件用 wood_turned(木纹顺 Y)。


const SMOOTH_ANGLE := 50.0           # 型材相邻两边夹角小于此值时法线平滑(圆弧),否则是硬棱
const PILASTER_SEGMENTS := 8


static func frame(x_axis: Vector3, y_axis: Vector3, origin: Vector3) -> Transform3D:
	# 部件的 X、Y 轴分别摆到 x_axis、y_axis(Z = X × Y,右手系)
	return Transform3D(Basis(x_axis, y_axis, x_axis.cross(y_axis)), origin)


# —— 型材 ——

static func sweep(profile: PackedVector2Array, length: float) -> Array:
	# 截面 profile 在 (u, v) 平面:u = 朝外(部件 +Z)、v = 向上(部件 +Y),闭合多边形;
	# 沿部件 X 从 -length/2 扫到 length/2,两端封口
	var poly := profile if _area(profile) >= 0.0 else _reversed(profile)
	var n := poly.size()
	var edge_normals: Array[Vector2] = []
	for i in n:
		var e := poly[(i + 1) % n] - poly[i]
		edge_normals.append(Vector2(e.y, -e.x).normalized())
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var half := length / 2.0
	for i in n:
		var j := (i + 1) % n
		var na := _blend(edge_normals[i], edge_normals[(i - 1 + n) % n])
		var nb := _blend(edge_normals[i], edge_normals[j])
		var base := verts.size()
		for corner in [[poly[i], na, -half], [poly[i], na, half], [poly[j], nb, half], [poly[j], nb, -half]]:
			var p: Vector2 = corner[0]
			var nn: Vector2 = corner[1]
			verts.append(Vector3(corner[2], p.y, p.x))
			normals.append(Vector3(0.0, nn.y, nn.x))
		var out := Vector3(0.0, edge_normals[i].y, edge_normals[i].x)
		_tri(indices, verts, base, base + 1, base + 2, out)
		_tri(indices, verts, base, base + 2, base + 3, out)
	var tris := Geometry2D.triangulate_polygon(poly)
	for side in [-1.0, 1.0]:
		var base := verts.size()
		for p in poly:
			verts.append(Vector3(half * side, p.y, p.x))
			normals.append(Vector3(side, 0, 0))
		for t in range(0, tris.size(), 3):
			_tri(indices, verts, base + tris[t], base + tris[t + 1], base + tris[t + 2], Vector3(side, 0, 0))
	return _arrays(verts, normals, indices)


static func _blend(own: Vector2, neighbour: Vector2) -> Vector2:
	# 与相邻边夹角小(圆弧上的折线)就取平均,折角大就保持本边法线(硬棱)
	if absf(rad_to_deg(own.angle_to(neighbour))) < SMOOTH_ANGLE:
		return (own + neighbour).normalized()
	return own


static func arc(center: Vector2, radius: float, from_deg: float, to_deg: float, steps: int) -> PackedVector2Array:
	# 圆弧上的点(含两端),用来拼型材截面
	var pts := PackedVector2Array()
	for k in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(k) / steps))
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts


# —— 车木与托架 ——

static func pilaster(height: float, radius: float) -> Array:
	# 半圆的车木壁柱:底座方块、圆环、略带收分的柱身、颈箍、喇叭口柱头。只转半圈(朝部件 +Z),平的一面贴墙
	var r := radius
	var profile := PackedVector2Array([Vector2(0, 0), Vector2(r * 1.25, 0), Vector2(r * 1.25, 0.03),
		Vector2(r * 1.1, 0.036), Vector2(r * 1.18, 0.046), Vector2(r * 0.95, 0.058), Vector2(r * 0.88, 0.075),
		Vector2(r * 0.92, height * 0.45), Vector2(r * 0.8, height - 0.075), Vector2(r * 0.95, height - 0.065),
		Vector2(r * 0.85, height - 0.055), Vector2(r * 1.0, height - 0.035), Vector2(r * 1.25, height - 0.014),
		Vector2(r * 1.25, height), Vector2(0, height)])
	return MeshShapes.lathe(profile, PILASTER_SEGMENTS, PI)


static func scroll_bracket(reach: float, drop: float, thickness: float) -> Array:
	# 涡卷托架的侧影:顶边托住搁板/台面,前端圆鼓鼓地向下收回墙面;x 朝外、y 向下
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(reach, 0), Vector2(reach, -drop * 0.14)])
	var steps := 7
	for k in range(1, steps + 1):
		var t := float(k) / steps
		pts.append(Vector2(reach * (0.16 + 0.84 * (1.0 - t * t)), -drop * (0.14 + 0.78 * t)))
	pts.append_array([Vector2(reach * 0.26, -drop * 0.95), Vector2(reach * 0.12, -drop), Vector2(0, -drop)])
	return MeshShapes.extrude(pts, thickness, minf(thickness * 0.2, 0.006))


# —— 内部 ——

static func _area(poly: PackedVector2Array) -> float:
	var area := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		area += a.x * b.y - b.x * a.y
	return area / 2.0


static func _reversed(poly: PackedVector2Array) -> PackedVector2Array:
	var out := poly.duplicate()
	out.reverse()
	return out


static func _tri(indices: PackedInt32Array, verts: PackedVector3Array, a: int, b: int, c: int, outward: Vector3) -> void:
	# Godot 正面为顺时针:三角形 (a,b,c) 的几何外法线 ∝ (c-a)×(b-a)。与期望朝向相反就交换两个顶点
	if (verts[c] - verts[a]).cross(verts[b] - verts[a]).dot(outward) >= 0.0:
		indices.append_array([a, b, c])
	else:
		indices.append_array([a, c, b])


static func _arrays(verts: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array) -> Array:
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
