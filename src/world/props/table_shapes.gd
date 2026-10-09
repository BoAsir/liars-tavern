class_name TableShapes
# 牌桌一带(牌桌、椅子、吊灯、烛台、壁灯)共用的造型小工具:回转剖面里的圆弧与拼接、剖面内缩一层(灯罩内壁)、
# 按长度比例车出的旋制件、把沿 +Y 建好的旋制件立到任意两点之间、只挪顶点不重算法线的变形(保留拉伸件的硬边)、
# 板件弯成弓形、部件整体换坐标系(让木纹顺着横向部件走)。


static func arc(center: Vector2, radius: float, from_deg: float, to_deg: float, steps: int) -> PackedVector2Array:
	# 圆弧上的 steps + 1 个点(含两端),角度从 +X 轴起算,逆时针为正
	var points := PackedVector2Array()
	for i in steps + 1:
		var a := deg_to_rad(lerpf(from_deg, to_deg, float(i) / steps))
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return points


static func joined(parts: Array) -> PackedVector2Array:
	# 把若干单点(Vector2)与点列按顺序拼成一条剖面
	var out := PackedVector2Array()
	for part in parts:
		if part is Vector2:
			out.append(part)
		else:
			out.append_array(part)
	return out


static func shifted(points: Array, offset: Vector2) -> PackedVector2Array:
	# 常量剖面表(相对某个基准点的偏移)平移到实际位置
	var out := PackedVector2Array()
	for p in points:
		out.append(p + offset)
	return out


static func offset_profile(profile: PackedVector2Array, distance: float) -> PackedVector2Array:
	# 沿剖面的"外侧"法线(行进方向右手边)平移 distance;负值往里缩。用于薄壳的内壁(灯罩、托盘)
	var out := PackedVector2Array()
	var n := profile.size()
	for i in n:
		var prev := (profile[i] - profile[i - 1]).normalized() if i > 0 else Vector2.ZERO
		var next := (profile[i + 1] - profile[i]).normalized() if i < n - 1 else Vector2.ZERO
		var t := (prev + next).normalized()
		out.append(profile[i] + Vector2(t.y, -t.x) * distance)
	return out


static func between(from: Vector3, to: Vector3) -> Transform3D:
	# 沿 +Y 建的部件(旋制的腿、柱)立到 from → to 这条轴上:原点落在 from,+Y 指向 to
	return Transform3D(Basis(Quaternion(Vector3.UP, (to - from).normalized())), from)


static func warp(arrays: Array, fn: Callable) -> Array:
	# 逐顶点挪动但保留原法线:拉伸件的硬边、回转体的折边不会被焊成圆角(小幅变形时法线的误差看不出来)
	var verts: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	for i in verts.size():
		verts[i] = fn.call(verts[i])
	var out := arrays.duplicate()
	out[Mesh.ARRAY_VERTEX] = verts
	return out


static func transformed(arrays: Array, xform: Transform3D) -> Array:
	# 整个部件换一个坐标系(顶点、法线一起转)。配合 MeshBatch:部件先转进"木纹坐标系"再用 xform 的逆放回原位,
	# 木纹着色器按部件坐标(CUSTOM0)取纹理,就能让纹理顺着横向的座面、搭脑走
	var out := arrays.duplicate()
	out[Mesh.ARRAY_VERTEX] = xform * (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array)
	out[Mesh.ARRAY_NORMAL] = Transform3D(xform.basis.inverse().transposed().orthonormalized(), Vector3.ZERO) \
		* (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array)
	return out


static func bowed(arrays: Array, depth: float, half_width: float) -> Array:
	# 沿 X 的板件往 +Z 弯成弓形:中间(x = 0)凸出 depth,两端(x = ±half_width)不动。
	# 法线按弯曲的斜率一起转(逆转置):拉伸件的斜角硬边保留,弯出来的面照样有明暗
	var verts: PackedVector3Array = (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).duplicate()
	var normals: PackedVector3Array = (arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array).duplicate()
	for i in verts.size():
		var u := verts[i].x / half_width
		var slope := -2.0 * depth * u / half_width
		verts[i].z += depth * (1.0 - u * u)
		normals[i] = Vector3(normals[i].x - slope * normals[i].z, normals[i].y, normals[i].z).normalized()
	var out := arrays.duplicate()
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = normals
	return out


static func turned(profile: Array, length: float, segments: int) -> Array:
	# 旋制件:剖面表的高度按长度比例(0..1)给出,同一套车削花样可做成不同长度的腿、柱、撑
	var points := PackedVector2Array()
	for p in profile:
		points.append(Vector2(p.x, p.y * length))
	return MeshShapes.lathe(points, segments)


static func with_uv_x(arrays: Array, factor: float) -> Array:
	# 回转体的 UV.x 是绕一圈的 0..1;乘上整数倍,着色器里 fract(UV.x) 就是首尾相接的一格格(软包分格、针脚)
	var uvs: PackedVector2Array = (arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array).duplicate()
	for i in uvs.size():
		uvs[i].x *= factor
	var out := arrays.duplicate()
	out[Mesh.ARRAY_TEX_UV] = uvs
	return out


static func profile_length(profile: PackedVector2Array, upto: int) -> float:
	# 剖面从起点走到第 upto 个点的路程(= 回转体在该点的 UV.y),着色器按它在剖面上定位缝线、磨亮带
	var total := 0.0
	for i in range(1, upto + 1):
		total += profile[i].distance_to(profile[i - 1])
	return total
