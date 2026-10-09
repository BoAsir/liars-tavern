class_name PatronGeo
# 酒客建模的几何工具(补充 MeshShapes):参数曲面网格、贴着曲面的"笔画"(眉毛、嘴线、翻领、链子)、
# 逐顶点烘焙颜色(毛皮斑纹、遮蔽)。全部返回 Mesh.ARRAY_* 数组,交给 MeshBatch.add_arrays。
# 绕序:先按 (s, t) 网格连好三角形,再按"从 inside 点指向外"的多数票决定是否整体翻转——
# 生成函数不必关心参数方向,曲面始终朝外。


const WELD_EPS := 1e-7


static func grid(fn: Callable, ns: int, nt: int, inside: Vector3, closed_s := false, uv_fn := Callable()) -> Array:
	# fn(s, t) -> Vector3,s、t ∈ [0, 1];ns × nt 个格子。UV = 沿两个参数方向累计的弧长(米),布料图案按米取样;
	# 给了 uv_fn(s, t) -> Vector2 时改用它(例如西装按绕脊柱的角度取 U,细条纹才是竖直的)。
	# closed_s:s 方向首尾相接(绕一圈的曲面),接缝处顶点重合,平滑法线按位置焊接后看不出接缝
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for j in nt + 1:
		for i in ns + 1:
			var s := float(i) / ns
			var t := float(j) / nt
			verts.append(fn.call(s, t))
			if uv_fn.is_valid():
				uvs.append(uv_fn.call(s, t))
	var row := ns + 1
	var indices := PackedInt32Array()
	for j in nt:
		for i in ns:
			var a := j * row + i
			_add_triangle(verts, indices, a, a + 1, a + row)
			_add_triangle(verts, indices, a + 1, a + row + 1, a + row)
	_orient(verts, indices, inside)
	return _finish(verts, indices, uvs if uv_fn.is_valid() else _arc_uvs(verts, ns, nt))


static func stroke(path: PackedVector3Array, normals: PackedVector3Array, widths: PackedFloat32Array,
		height: float, across := 4) -> Array:
	# 贴在曲面上的一道"笔画":沿 path 走,横截面是宽 widths[i]、高 height 的半圆拱(底边贴着曲面)。
	# 眉毛、嘴线、翻领边、表链等;两端宽度给 0 即自然收尖
	var n := path.size()
	var fn := func(s: float, t: float) -> Vector3:
		var f := s * (n - 1)
		var i := mini(int(f), n - 2)
		var k := f - i
		var p := path[i].lerp(path[i + 1], k)
		var nrm := normals[i].lerp(normals[i + 1], k).normalized()
		var tangent := (path[i + 1] - path[i]).normalized()
		var side := tangent.cross(nrm).normalized()
		var w := lerpf(widths[i], widths[i + 1], k) * 0.5
		var x := t * 2.0 - 1.0
		return p + side * w * x + nrm * height * sqrt(maxf(1.0 - x * x, 0.0))
	var inside := Vector3.ZERO
	for i in n:
		inside += path[i] - normals[i] * 0.05
	return grid(fn, n - 1, across, inside / n)


static func colored(arrays: Array, fn: Callable) -> Array:
	# 逐顶点颜色:fn(顶点位置) -> Color(PatronSkin.tag 的格式)。斑纹、渐变、烘焙遮蔽
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	colors.resize(verts.size())
	for i in verts.size():
		colors[i] = fn.call(verts[i])
	var out := arrays.duplicate()
	out[Mesh.ARRAY_COLOR] = colors
	return out


static func transformed(arrays: Array, xform: Transform3D) -> Array:
	# 把部件预先摆进父部件的坐标系(合成一个子装配,部件坐标 CUSTOM0 就是装配坐标)
	var out := arrays.duplicate()
	out[Mesh.ARRAY_VERTEX] = xform * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	var normals: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	var normal_basis := xform.basis.inverse().transposed()
	for i in normals.size():
		normals[i] = (normal_basis * normals[i]).normalized()
	out[Mesh.ARRAY_NORMAL] = normals
	if xform.basis.determinant() < 0.0:
		var indices: PackedInt32Array = (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).duplicate()
		for t in range(0, indices.size(), 3):
			var swap := indices[t + 1]
			indices[t + 1] = indices[t + 2]
			indices[t + 2] = swap
		out[Mesh.ARRAY_INDEX] = indices
	return out


static func concat(parts: Array) -> Array:
	# 把几块(已在同一坐标系里的)数组拼成一块:顶点、法线、UV、顶点色首尾相接,索引按偏移重排
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	for part in parts:
		var src: PackedVector3Array = part[Mesh.ARRAY_VERTEX]
		var base := verts.size()
		verts.append_array(src)
		normals.append_array(part[Mesh.ARRAY_NORMAL])
		var part_uvs: Variant = part[Mesh.ARRAY_TEX_UV]
		if part_uvs != null and (part_uvs as PackedVector2Array).size() == src.size():
			uvs.append_array(part_uvs)
		else:
			var blank := PackedVector2Array()
			blank.resize(src.size())
			uvs.append_array(blank)
		var part_colors: Variant = part[Mesh.ARRAY_COLOR]
		if part_colors != null and (part_colors as PackedColorArray).size() == src.size():
			colors.append_array(part_colors)
		else:
			var white := PackedColorArray()
			white.resize(src.size())
			white.fill(Color.WHITE)
			colors.append_array(white)
		for index in (part[Mesh.ARRAY_INDEX] as PackedInt32Array):
			indices.append(index + base)
	var out := _finish_raw(verts, normals, uvs, indices)
	out[Mesh.ARRAY_COLOR] = colors
	return out


static func sphere(radius: Vector3, segments := 16, rings := 10) -> Array:
	# 椭球(轴半径 radius),极点在 ±Y
	return ellipsoid_fn(func(d: Vector3) -> Vector3: return d * radius, segments, rings)


static func ellipsoid_fn(fn: Callable, segments := 24, rings := 16, inside := Vector3.ZERO) -> Array:
	# 单位球面上的方向 d(极点 ±Y)经 fn(d) 映射到曲面:头、口鼻、肚子这类"捏出来"的形状。
	# 法线按映射后的形状重算(位置焊接,接缝与极点处平滑);inside 为形状内部的一点(定朝向)
	var sphere_fn := func(s: float, t: float) -> Vector3:
		var lat := PI * (t - 0.5)
		var lon := TAU * s
		return fn.call(Vector3(cos(lat) * sin(lon), sin(lat), cos(lat) * cos(lon)))
	return grid(sphere_fn, segments, rings, inside, true)


static func revolve_fn(fn: Callable, segments: int, rings: int, inside: Vector3) -> Array:
	# fn(angle, t) -> Vector3:绕某根轴一圈的曲面(angle ∈ [0, TAU),t ∈ [0, 1]),例如沿袖子的截面
	return grid(func(s: float, t: float) -> Vector3: return fn.call(s * TAU, t), segments, rings, inside, true)


static func sweep(path: PackedVector3Array, radius_fn: Callable, sides := 8) -> Array:
	# 沿路径扫出截面:radius_fn(s, angle) -> 半径,s ∈ [0, 1] 为沿程位置,angle 为绕路径的角度
	# (半径可随角度起伏:蓬松的尾巴)。平行移动标架不扭转;UV = (绕一圈的比例, s);末端半径不为 0 时封口
	var n := path.size()
	var tangents := PackedVector3Array()
	for i in n:
		tangents.append((path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized())
	var normal := tangents[0].cross(Vector3.UP if absf(tangents[0].y) < 0.9 else Vector3.RIGHT).normalized()
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	for i in n:
		if i > 0 and not tangents[i - 1].is_equal_approx(tangents[i]):
			normal = Quaternion(tangents[i - 1], tangents[i]) * normal
		normal = (normal - tangents[i] * normal.dot(tangents[i])).normalized()
		var binormal := tangents[i].cross(normal)
		var s := float(i) / (n - 1)
		for k in sides + 1:
			var a := TAU * k / sides
			verts.append(path[i] + (normal * cos(a) + binormal * sin(a)) * radius_fn.call(s, a))
			uvs.append(Vector2(float(k) / sides, s))
	var ring := sides + 1
	var indices := PackedInt32Array()
	for i in n - 1:
		for k in sides:
			var v00 := i * ring + k
			indices.append_array([v00, v00 + ring, v00 + 1, v00 + 1, v00 + ring, v00 + ring + 1])
	if radius_fn.call(1.0, 0.0) > 0.0:
		var center := verts.size()
		verts.append(path[n - 1])
		uvs.append(Vector2(0.5, 1.0))
		for k in sides:
			indices.append_array([center, (n - 1) * ring + k + 1, (n - 1) * ring + k])
	return _finish(verts, indices, uvs)


static func smooth_path(points: PackedVector3Array, per_segment := 4) -> PackedVector3Array:
	# Catmull-Rom 平滑折线:少量控制点画出圆润的尾巴、腿、链子
	var out := PackedVector3Array()
	var n := points.size()
	for i in n - 1:
		var p0 := points[maxi(i - 1, 0)]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[mini(i + 2, n - 1)]
		for k in per_segment:
			var t := float(k) / per_segment
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * (2.0 * p1 + (p2 - p0) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (3.0 * p1 - p0 - 3.0 * p2 + p3) * t3))
	out.append(points[n - 1])
	return out


static func hermite(knots: Array, x: float, column: int) -> float:
	# 分段三次插值:knots 为按 x(第 0 列)递增的行,取第 column 列在 x 处的值;斜率取相邻两点的差商,
	# 曲线经过每个控制点、过渡圆滑(躯干轮廓、袖子粗细)
	var n := knots.size()
	var i := 0
	while i < n - 2 and x > knots[i + 1][0]:
		i += 1
	var x0: float = knots[i][0]
	var x1: float = knots[i + 1][0]
	var h := maxf(x1 - x0, 1e-6)
	var f := clampf((x - x0) / h, 0.0, 1.0)
	var v0: float = knots[i][column]
	var v1: float = knots[i + 1][column]
	var m0 := _slope(knots, i, column) * h
	var m1 := _slope(knots, i + 1, column) * h
	var f2 := f * f
	var f3 := f2 * f
	return (2.0 * f3 - 3.0 * f2 + 1.0) * v0 + (f3 - 2.0 * f2 + f) * m0 + (-2.0 * f3 + 3.0 * f2) * v1 + (f3 - f2) * m1


static func _slope(knots: Array, i: int, column: int) -> float:
	var a: Array = knots[maxi(i - 1, 0)]
	var b: Array = knots[mini(i + 1, knots.size() - 1)]
	return (b[column] - a[column]) / maxf(b[0] - a[0], 1e-6)


static func frame_at(origin: Vector3, outward: Vector3, up_hint := Vector3.UP) -> Transform3D:
	# 曲面上一点的局部坐标系:-Z 朝外(法线),Y 尽量朝 up_hint;贴在曲面上的扣子、口袋、徽章在这个系里建模
	var n := outward.normalized()
	var hint := up_hint if absf(up_hint.normalized().dot(n)) < 0.98 else Vector3.FORWARD
	var up := (hint - n * hint.dot(n)).normalized()
	return Transform3D(Basis(up.cross(-n).normalized(), up, -n), origin)


static func resample(values: PackedFloat32Array, count: int) -> PackedFloat32Array:
	# 把少量控制值线性插值成 count 个(给平滑后的路径配半径)
	var out := PackedFloat32Array()
	for i in count:
		var f := float(i) / maxf(count - 1, 1) * (values.size() - 1)
		var k := mini(int(f), values.size() - 2)
		out.append(lerpf(values[k], values[k + 1], f - k))
	return out


# —— 内部 ——

static func _add_triangle(verts: PackedVector3Array, indices: PackedInt32Array, a: int, b: int, c: int) -> void:
	# 跳过退化三角形(球面极点处整行顶点重合),不白占三角形预算
	if (verts[c] - verts[a]).cross(verts[b] - verts[a]).length_squared() > WELD_EPS * WELD_EPS:
		indices.append_array([a, b, c])


static func _orient(verts: PackedVector3Array, indices: PackedInt32Array, inside: Vector3) -> void:
	# Godot 正面为顺时针:外法线 ∝ (c-a)×(b-a)。多数三角形朝向 inside 时整体翻转
	var votes := 0.0
	for t in range(0, indices.size(), 3):
		var a := verts[indices[t]]
		var face := (verts[indices[t + 2]] - a).cross(verts[indices[t + 1]] - a)
		var centroid := (a + verts[indices[t + 1]] + verts[indices[t + 2]]) / 3.0
		votes += signf(face.dot(centroid - inside)) if face.length_squared() > WELD_EPS * WELD_EPS else 0.0
	if votes >= 0.0:
		return
	for t in range(0, indices.size(), 3):
		var swap := indices[t + 1]
		indices[t + 1] = indices[t + 2]
		indices[t + 2] = swap


static func _arc_uvs(verts: PackedVector3Array, ns: int, nt: int) -> PackedVector2Array:
	var row := ns + 1
	var uvs := PackedVector2Array()
	uvs.resize(verts.size())
	for j in nt + 1:
		var u := 0.0
		for i in row:
			if i > 0:
				u += verts[j * row + i].distance_to(verts[j * row + i - 1])
			uvs[j * row + i].x = u
	for i in row:
		var v := 0.0
		for j in nt + 1:
			if j > 0:
				v += verts[j * row + i].distance_to(verts[(j - 1) * row + i])
			uvs[j * row + i].y = v
	return uvs


static func _finish(verts: PackedVector3Array, indices: PackedInt32Array, uvs: PackedVector2Array) -> Array:
	return _finish_raw(verts, MeshShapes.smooth_normals(verts, indices), uvs, indices)


static func _finish_raw(verts: PackedVector3Array, normals: PackedVector3Array, uvs: PackedVector2Array,
		indices: PackedInt32Array) -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
