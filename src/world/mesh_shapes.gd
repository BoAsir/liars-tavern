class_name MeshShapes
# 程序化几何生成器:回转体(lathe)、沿路径的管子(tube)、平面多边形拉伸(extrude)、圆角盒(rounded_box)、
# 顶点变形(deform)。全部是纯函数,返回 Mesh.ARRAY_* 数组:交给 MeshBatch.add_arrays / add_part 合批,
# 或 to_mesh 单独成网格。单位米。
# 绕序:Godot 以"从外侧看顺时针"为正面。下面先按外法线 = 逆时针叉积思考,写三角形时统一交换后两个顶点。


static func to_mesh(arrays: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# —— 回转体 ——

static func lathe(profile: PackedVector2Array, segments := 24, arc := TAU) -> Array:
	# 剖面点 (半径, 高度) 绕 Y 轴旋转一周(或 arc 弧度)。沿剖面行进时"外侧在右手边":
	# 例如从底面圆心出发 → 向外 → 向上 → 顶面收回圆心。半径为 0 的端点自然收口;
	# 相邻两个相同的点 = 硬折边(两侧各用自己那段的法线),不重复则平滑过渡。
	var n := profile.size()
	var ring := segments + 1
	var normals2 := PackedVector2Array()
	var lengths := PackedFloat32Array()
	var travelled := 0.0
	for i in n:
		var prev := (profile[i] - profile[i - 1]).normalized() if i > 0 else Vector2.ZERO
		var next := (profile[i + 1] - profile[i]).normalized() if i < n - 1 else Vector2.ZERO
		var t := prev + next
		normals2.append(Vector2(t.y, -t.x).normalized())
		if i > 0:
			travelled += profile[i].distance_to(profile[i - 1])
		lengths.append(travelled)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in n:
		for j in ring:
			var a := arc * j / segments
			var c := cos(a)
			var s := sin(a)
			verts.append(Vector3(profile[i].x * c, profile[i].y, profile[i].x * s))
			normals.append(Vector3(normals2[i].x * c, normals2[i].y, normals2[i].x * s))
			uvs.append(Vector2(float(j) / segments, lengths[i]))
	var indices := PackedInt32Array()
	for i in n - 1:
		if profile[i].is_equal_approx(profile[i + 1]):
			continue
		for j in segments:
			var v00 := i * ring + j
			var v01 := v00 + 1
			var v10 := v00 + ring
			var v11 := v10 + 1
			if profile[i].x > 0.0:
				indices.append_array([v00, v01, v10])
			if profile[i + 1].x > 0.0:
				indices.append_array([v01, v11, v10])
	return _arrays(verts, normals, uvs, indices)


# —— 管子 ——

static func tube(path: PackedVector3Array, radius: Variant, sides := 8, caps := true) -> Array:
	# 沿折线扫出圆截面的管子(平行移动标架,不扭转)。radius:统一半径(float)或逐点半径(PackedFloat32Array)。
	# 链条、提手、尾巴、胡须、弯曲的椅背条都用它
	var n := path.size()
	var radii := PackedFloat32Array()
	for i in n:
		radii.append(radius[i] if radius is PackedFloat32Array or radius is Array else float(radius))
	var tangents := PackedVector3Array()
	for i in n:
		var a := path[maxi(i - 1, 0)]
		var b := path[mini(i + 1, n - 1)]
		tangents.append((b - a).normalized())
	var normal := tangents[0].cross(Vector3.UP if absf(tangents[0].y) < 0.9 else Vector3.RIGHT).normalized()
	var ring := sides + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var travelled := 0.0
	for i in n:
		if i > 0:
			normal = (Quaternion(tangents[i - 1], tangents[i]) * normal) if not tangents[i - 1].is_equal_approx(tangents[i]) else normal
			normal = (normal - tangents[i] * normal.dot(tangents[i])).normalized()
			travelled += path[i].distance_to(path[i - 1])
		var binormal := tangents[i].cross(normal)
		for k in ring:
			var a := TAU * k / sides
			var dir := normal * cos(a) + binormal * sin(a)
			verts.append(path[i] + dir * radii[i])
			normals.append(dir)
			uvs.append(Vector2(float(k) / sides, travelled))
	var indices := PackedInt32Array()
	for i in n - 1:
		for k in sides:
			var v00 := i * ring + k
			var v01 := v00 + 1
			var v10 := v00 + ring
			var v11 := v10 + 1
			indices.append_array([v00, v10, v01, v01, v10, v11])
	if caps:
		_tube_cap(verts, normals, uvs, indices, path[0], -tangents[0], 0, sides, true)
		_tube_cap(verts, normals, uvs, indices, path[n - 1], tangents[n - 1], (n - 1) * ring, sides, false)
	return _arrays(verts, normals, uvs, indices)


static func _tube_cap(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		indices: PackedInt32Array, center: Vector3, facing: Vector3, ring_start: int, sides: int, start: bool) -> void:
	var c := verts.size()
	verts.append(center)
	normals.append(facing)
	uvs.append(Vector2(0.5, 0.5))
	for k in sides + 1:
		verts.append(verts[ring_start + k])
		normals.append(facing)
		uvs.append(Vector2(0.5, 0.5))
	for k in sides:
		if start:
			indices.append_array([c, c + 1 + k, c + 2 + k])
		else:
			indices.append_array([c, c + 2 + k, c + 1 + k])


# —— 拉伸 ——

static func extrude(polygon: PackedVector2Array, depth: float, bevel := 0.0) -> Array:
	# XY 平面上的多边形沿 Z 拉伸,z ∈ [-depth/2, depth/2]。bevel > 0 时前后两面四周倒一圈 45° 斜角。
	# 枪身侧面轮廓、翻领、招牌、拱门、椅背板这类"剪影 + 厚度"的形状都用它
	var outline := polygon if _signed_area(polygon) >= 0.0 else _reversed(polygon)
	var tris := Geometry2D.triangulate_polygon(outline)
	var half := depth / 2.0
	var b := minf(bevel, half * 0.95)
	var face := _inset(outline, b) if b > 0.0 else outline
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
			if side > 0.0:
				indices.append_array([base + tris[t], base + tris[t + 2], base + tris[t + 1]])
			else:
				indices.append_array([base + tris[t], base + tris[t + 1], base + tris[t + 2]])
	# 侧壁(以及斜角):逐条边一圈圈连起来,每个四边形独立顶点,保持硬边
	var rings := [[face, half], [outline, half - b], [outline, -half + b], [face, -half]] if b > 0.0 \
		else [[outline, half], [outline, -half]]
	var travelled := 0.0
	var count := outline.size()
	for e in count:
		var e2 := (e + 1) % count
		var edge := outline[e2] - outline[e]
		var out2 := Vector2(edge.y, -edge.x).normalized()
		for r in rings.size() - 1:
			var top: Array = rings[r]
			var bottom: Array = rings[r + 1]
			var pa: Vector2 = top[0][e]
			var pb: Vector2 = top[0][e2]
			var pc: Vector2 = bottom[0][e]
			var pd: Vector2 = bottom[0][e2]
			var za: float = top[1]
			var zc: float = bottom[1]
			var nz := 0.0
			if b > 0.0 and r == 0:
				nz = 1.0
			elif b > 0.0 and r == rings.size() - 2:
				nz = -1.0
			var normal := Vector3(out2.x, out2.y, nz).normalized()
			var base := verts.size()
			verts.append_array([Vector3(pa.x, pa.y, za), Vector3(pb.x, pb.y, za), Vector3(pc.x, pc.y, zc), Vector3(pd.x, pd.y, zc)])
			for k in 4:
				normals.append(normal)
			var len := edge.length()
			uvs.append_array([Vector2(travelled, za), Vector2(travelled + len, za), Vector2(travelled, zc), Vector2(travelled + len, zc)])
			indices.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
		travelled += edge.length()
	return _arrays(verts, normals, uvs, indices)


static func _signed_area(polygon: PackedVector2Array) -> float:
	var area := 0.0
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		area += a.x * b.y - b.x * a.y
	return area / 2.0


static func _reversed(polygon: PackedVector2Array) -> PackedVector2Array:
	var out := polygon.duplicate()
	out.reverse()
	return out


static func _inset(polygon: PackedVector2Array, amount: float) -> PackedVector2Array:
	# 逆时针多边形逐点沿角平分线内缩(斜接),顶点一一对应,斜角四边形才连得上
	var out := PackedVector2Array()
	var count := polygon.size()
	for i in count:
		var prev := polygon[i] - polygon[(i - 1 + count) % count]
		var next := polygon[(i + 1) % count] - polygon[i]
		var n1 := Vector2(-prev.y, prev.x).normalized()
		var n2 := Vector2(-next.y, next.x).normalized()
		var bisector := (n1 + n2).normalized()
		var cos_half := maxf(bisector.dot(n1), 0.25)
		out.append(polygon[i] + bisector * amount / cos_half)
	return out


# —— 圆角盒 ——

static func rounded_box(size: Vector3, radius: float, segments := 3) -> Array:
	# 棱和角都是半径 radius 的圆弧(segments 段),法线平滑:家具、木箱、书本不再像积木
	var half := size / 2.0
	var r := clampf(radius, 0.0005, minf(half.x, minf(half.y, half.z)))
	var coords := [_axis_coords(half.x, r, segments), _axis_coords(half.y, r, segments), _axis_coords(half.z, r, segments)]
	var inner := half - Vector3.ONE * r
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	# 每个面:(法线轴, 符号, u 轴, v 轴),u × v = 外法线
	for face in [[0, 1.0, 1, 2], [0, -1.0, 2, 1], [1, 1.0, 2, 0], [1, -1.0, 0, 2], [2, 1.0, 0, 1], [2, -1.0, 1, 0]]:
		var axis: int = face[0]
		var us: PackedFloat32Array = coords[face[2]]
		var vs: PackedFloat32Array = coords[face[3]]
		var base := verts.size()
		for j in vs.size():
			for i in us.size():
				var p := Vector3.ZERO
				p[axis] = half[axis] * face[1]
				p[face[2]] = us[i]
				p[face[3]] = vs[j]
				var core := p.clamp(-inner, inner)
				var dir := (p - core).normalized()
				verts.append(core + dir * r)
				normals.append(dir)
				uvs.append(Vector2(us[i], vs[j]))
		var row := us.size()
		for j in vs.size() - 1:
			for i in row - 1:
				var a := base + j * row + i
				indices.append_array([a, a + row, a + 1, a + 1, a + row, a + row + 1])
	return _arrays(verts, normals, uvs, indices)


static func _axis_coords(half: float, r: float, segments: int) -> PackedFloat32Array:
	# 一个轴上的采样:左圆弧(segments+1 个点)→ 平直段 → 右圆弧
	var coords := PackedFloat32Array()
	for k in segments + 1:
		coords.append(-(half - r) - r * cos(PI / 2.0 * k / segments))
	for k in segments + 1:
		coords.append((half - r) + r * sin(PI / 2.0 * k / segments))
	return coords


# —— 变形 ——

static func deform(arrays: Array, fn: Callable) -> Array:
	# 逐顶点 fn(Vector3) -> Vector3 移动顶点,再按位置焊接重算平滑法线(球体接缝处不会出现折痕)。
	# 头型、腮帮、麻袋、坐垫这类有机形状:先拿球体/圆角盒,再捏
	var verts: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	for i in verts.size():
		verts[i] = fn.call(verts[i])
	var out := arrays.duplicate()
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = smooth_normals(verts, arrays[Mesh.ARRAY_INDEX])
	out[Mesh.ARRAY_TANGENT] = null
	return out


static func smooth_normals(verts: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
	var weld := {}    # 量化位置 -> 累加法线
	var keys := []
	keys.resize(verts.size())
	for i in verts.size():
		keys[i] = Vector3i((verts[i] * 20000.0).round())
		if not weld.has(keys[i]):
			weld[keys[i]] = Vector3.ZERO
	for t in range(0, indices.size(), 3):
		var a := verts[indices[t]]
		var b := verts[indices[t + 1]]
		var c := verts[indices[t + 2]]
		# Godot 正面为顺时针:外法线与叉积反向;叉积长度即面积权重
		var face := (c - a).cross(b - a)
		for k in 3:
			weld[keys[indices[t + k]]] += face
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	for i in verts.size():
		normals[i] = (weld[keys[i]] as Vector3).normalized()
	return normals


static func _arrays(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		indices: PackedInt32Array) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
