class_name MeshForge
extends RefCounted
# 合批构建器:把多个部件写进同一组顶点数组(纯数组运算,可在工作线程跑),主线程 commit 成共享 ArrayMesh。
# 顶点布局:COLOR.rgb = sRGB albedo、COLOR.a = 烘焙 AO;UV2 = (roughness, metallic);
# CUSTOM0 = (部件原始局部坐标 xyz, 种子 w),只在该 surface 有部件开了 part_space 时才写(木纹等物体空间着色器用)。
# 旧基础体逐顶点复刻 Godot 的 PrimitiveMesh(运行时读 PrimitiveMesh 的数组在 Metal 上要从 GPU 回读,每次约 1.2 ms)。
# 配方(recipe: func(f: MeshForge))只用 MeshForge 的方法加数学运算:不建 Node/Resource、不用全局 randf()、不碰 autoload。

const CAPS_TOP := 1      # 与 MeshKit.CAPS_* 取值一致
const CAPS_BOTTOM := 2
const CAPS_BOTH := 3
const CUSTOM0_FORMAT := Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT

static var _cache := {}       # key -> ArrayMesh
static var _jobs := {}        # key -> _Job(后台预建中)

# —— 绘制状态(作用于之后加入的部件)——
var color := Color.WHITE      # sRGB albedo,口径同 StandardMaterial3D.albedo_color
var ao := 1.0
var rough := 0.7
var metal := 0.0
var part_space := false
var seed := 0.0

var _surfaces := {}           # StringName -> _Surface(按首次使用顺序)
var _order: Array[StringName] = []
var _current: _Surface
var _stack: Array[Transform3D] = [Transform3D.IDENTITY]


class _Surface:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uv2 := PackedVector2Array()
	var custom0 := PackedFloat32Array()
	var indices := PackedInt32Array()
	var has_custom := false


class _Job:
	var key: String
	var recipe: Callable
	var materials: Dictionary
	var task_id := -1
	var built: Dictionary


func _init() -> void:
	surface(&"main")


# —— 状态 ——

func paint(c: Color, r: float, m := 0.0) -> MeshForge:
	color = c
	rough = r
	metal = m
	return self


func surface(surface_name: StringName) -> MeshForge:
	# 切换 / 新建 surface:一个 surface 一个材质槽、一次 draw
	if not _surfaces.has(surface_name):
		_surfaces[surface_name] = _Surface.new()
		_order.append(surface_name)
	_current = _surfaces[surface_name]
	return self


func push(t: Transform3D) -> MeshForge:
	_stack.append(_stack.back() * t)
	return self


func pop() -> MeshForge:
	if _stack.size() > 1:
		_stack.pop_back()
	return self


static func xf(pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	# 与 Node3D(position / rotation_degrees / scale)以及 MeshKit.add 同口径
	var rot := Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scale), pos)


func vertex_count() -> int:
	var n := 0
	for s in _surfaces.values():
		n += s.vertices.size()
	return n


# —— 旧基础体:逐顶点复刻 Godot primitive_meshes.cpp,参数与 MeshKit 同名函数一致 ——

func sphere(radius: float, segments := 24, t := Transform3D.IDENTITY) -> MeshForge:
	return _sphere(radius, radius * 2.0, segments, maxi(segments / 2, 6), false, t)


func hemisphere(radius: float, segments := 24, t := Transform3D.IDENTITY) -> MeshForge:
	return _sphere(radius, radius, segments, maxi(segments / 2, 6), true, t)


func _sphere(radius: float, height: float, radial: int, rings: int, is_hemisphere: bool, t: Transform3D) -> MeshForge:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var scale := height * (1.0 if is_hemisphere else 0.5)
	var point := 0
	var thisrow := 0
	var prevrow := 0
	for j in rings + 2:
		var v := float(j) / (rings + 1)
		var w := sin(PI * v)
		var y := scale * cos(PI * v)
		for i in radial + 1:
			var u := float(i) / radial
			var x := sin(u * TAU)
			var z := cos(u * TAU)
			if is_hemisphere and y < 0.0:
				points.append(Vector3(x * radius * w, 0.0, z * radius * w))
				normals.append(Vector3(0.0, -1.0, 0.0))
			else:
				points.append(Vector3(x * radius * w, y, z * radius * w))
				normals.append(Vector3(x * w * scale, radius * (y / scale), z * w * scale).normalized())
			point += 1
			if i > 0 and j > 0:
				indices.append_array([prevrow + i - 1, prevrow + i, thisrow + i - 1, prevrow + i, thisrow + i, thisrow + i - 1])
		prevrow = thisrow
		thisrow = point
	return _append(points, normals, indices, t)


func cylinder(top_r: float, bottom_r: float, height: float, segments := 32, caps := CAPS_BOTH,
		t := Transform3D.IDENTITY) -> MeshForge:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var rings := 1   # MeshKit.cylinder 固定 rings = 1
	var side_normal_y := (bottom_r - top_r) / height
	var point := 0
	var thisrow := 0
	var prevrow := 0
	for j in rings + 2:
		var v := float(j) / (rings + 1)
		var radius := top_r + (bottom_r - top_r) * v
		var y := height * 0.5 - height * v
		for i in segments + 1:
			var u := float(i) / segments
			var x := sin(u * TAU)
			var z := cos(u * TAU)
			points.append(Vector3(x * radius, y, z * radius))
			normals.append(Vector3(x, side_normal_y, z).normalized())
			point += 1
			if i > 0 and j > 0:
				indices.append_array([prevrow + i - 1, prevrow + i, thisrow + i - 1, prevrow + i, thisrow + i, thisrow + i - 1])
		prevrow = thisrow
		thisrow = point
	if caps & CAPS_TOP and top_r > 0.0:
		var y := height * 0.5
		thisrow = point
		points.append(Vector3(0.0, y, 0.0))
		normals.append(Vector3.UP)
		point += 1
		for i in segments + 1:
			var r := float(i) / segments
			points.append(Vector3(sin(r * TAU) * top_r, y, cos(r * TAU) * top_r))
			normals.append(Vector3.UP)
			point += 1
			if i > 0:
				indices.append_array([thisrow, point - 1, point - 2])
	if caps & CAPS_BOTTOM and bottom_r > 0.0:
		var y := height * -0.5
		thisrow = point
		points.append(Vector3(0.0, y, 0.0))
		normals.append(Vector3.DOWN)
		point += 1
		for i in segments + 1:
			var r := float(i) / segments
			points.append(Vector3(sin(r * TAU) * bottom_r, y, cos(r * TAU) * bottom_r))
			normals.append(Vector3.DOWN)
			point += 1
			if i > 0:
				indices.append_array([thisrow, point - 2, point - 1])
	return _append(points, normals, indices, t)


func capsule(radius: float, height: float, segments := 20, t := Transform3D.IDENTITY) -> MeshForge:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var rings := 6   # MeshKit.capsule 固定 rings = 6
	height = maxf(height, radius * 2.0)
	var point := 0
	# 上半球
	var thisrow := 0
	var prevrow := 0
	for j in rings + 2:
		var v := float(j) / (rings + 1)
		var w := 1.0 if j == rings + 1 else sin(0.5 * PI * v)
		var y := 0.0 if j == rings + 1 else cos(0.5 * PI * v)
		for i in segments + 1:
			var p := _capsule_dir(i, segments, w, y)
			points.append(p * radius + Vector3(0.0, 0.5 * height - radius, 0.0))
			normals.append(p)
			point += 1
			if i > 0 and j > 0:
				indices.append_array([prevrow + i - 1, prevrow + i, thisrow + i - 1, prevrow + i, thisrow + i, thisrow + i - 1])
		prevrow = thisrow
		thisrow = point
	# 圆柱段
	thisrow = point
	prevrow = 0
	for j in rings + 2:
		var v := float(j) / (rings + 1)
		var y := (0.5 * height - radius) - (height - 2.0 * radius) * v
		for i in segments + 1:
			var d := _capsule_dir(i, segments, 1.0, 0.0)
			points.append(Vector3(d.x * radius, y, d.z * radius))
			normals.append(Vector3(d.x, 0.0, d.z))
			point += 1
			if i > 0 and j > 0:
				indices.append_array([prevrow + i - 1, prevrow + i, thisrow + i - 1, prevrow + i, thisrow + i, thisrow + i - 1])
		prevrow = thisrow
		thisrow = point
	# 下半球
	thisrow = point
	prevrow = 0
	for j in rings + 2:
		var v := float(j) / (rings + 1)
		var w := 0.0 if j == rings + 1 else cos(0.5 * PI * v)
		var y := -1.0 if j == rings + 1 else -sin(0.5 * PI * v)
		for i in segments + 1:
			var p := _capsule_dir(i, segments, w, y)
			points.append(p * radius + Vector3(0.0, -0.5 * height + radius, 0.0))
			normals.append(p)
			point += 1
			if i > 0 and j > 0:
				indices.append_array([prevrow + i - 1, prevrow + i, thisrow + i - 1, prevrow + i, thisrow + i, thisrow + i - 1])
		prevrow = thisrow
		thisrow = point
	return _append(points, normals, indices, t)


static func _capsule_dir(i: int, segments: int, w: float, y: float) -> Vector3:
	var x := 0.0
	var z := 1.0
	if i != segments:
		var u := float(i) / segments
		x = -sin(u * TAU)
		z = cos(u * TAU)
	return Vector3(x * w, y, -z * w)


func box(size: Vector3, t := Transform3D.IDENTITY) -> MeshForge:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var start := size * -0.5
	var point := 0
	# 前 + 后
	var y := start.y
	var thisrow := point
	var prevrow := 0
	for j in 2:
		var x := start.x
		for i in 2:
			points.append(Vector3(x, -y, -start.z))
			normals.append(Vector3(0.0, 0.0, 1.0))
			points.append(Vector3(-x, -y, start.z))
			normals.append(Vector3(0.0, 0.0, -1.0))
			point += 2
			if i > 0 and j > 0:
				_quad_pair(indices, prevrow, thisrow, i * 2)
			x += size.x
		y += size.y
		prevrow = thisrow
		thisrow = point
	# 右 + 左
	y = start.y
	thisrow = point
	prevrow = 0
	for j in 2:
		var z := start.z
		for i in 2:
			points.append(Vector3(-start.x, -y, -z))
			normals.append(Vector3(1.0, 0.0, 0.0))
			points.append(Vector3(start.x, -y, z))
			normals.append(Vector3(-1.0, 0.0, 0.0))
			point += 2
			if i > 0 and j > 0:
				_quad_pair(indices, prevrow, thisrow, i * 2)
			z += size.z
		y += size.y
		prevrow = thisrow
		thisrow = point
	# 上 + 下
	var z := start.z
	thisrow = point
	prevrow = 0
	for j in 2:
		var x := start.x
		for i in 2:
			points.append(Vector3(-x, -start.y, -z))
			normals.append(Vector3(0.0, 1.0, 0.0))
			points.append(Vector3(x, start.y, -z))
			normals.append(Vector3(0.0, -1.0, 0.0))
			point += 2
			if i > 0 and j > 0:
				_quad_pair(indices, prevrow, thisrow, i * 2)
			x += size.x
		z += size.z
		prevrow = thisrow
		thisrow = point
	return _append(points, normals, indices, t)


static func _quad_pair(indices: PackedInt32Array, prevrow: int, thisrow: int, i2: int) -> void:
	# 盒子与棱柱:同一行交替存放的两个面各出一个四边形
	indices.append_array([prevrow + i2 - 2, prevrow + i2, thisrow + i2 - 2, prevrow + i2, thisrow + i2, thisrow + i2 - 2])
	indices.append_array([prevrow + i2 - 1, prevrow + i2 + 1, thisrow + i2 - 1, prevrow + i2 + 1, thisrow + i2 + 1, thisrow + i2 - 1])


func torus(inner: float, outer: float, segments := 32, t := Transform3D.IDENTITY) -> MeshForge:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var rings := segments
	var ring_segments := 12   # MeshKit.torus 固定 ring_segments = 12
	var min_r := minf(inner, outer)
	var max_r := maxf(inner, outer)
	var radius := (max_r - min_r) * 0.5
	for i in rings + 1:
		var prevrow := (i - 1) * (ring_segments + 1)
		var thisrow := i * (ring_segments + 1)
		var angi := float(i) / rings * TAU
		var ni := Vector2(0.0, -1.0) if i == rings else Vector2(-sin(angi), -cos(angi))
		for j in ring_segments + 1:
			var angj := float(j) / ring_segments * TAU
			var nj := Vector2(-1.0, 0.0) if j == ring_segments else Vector2(-cos(angj), sin(angj))
			var nk := nj * radius + Vector2(min_r + radius, 0.0)
			points.append(Vector3(ni.x * nk.x, nk.y, ni.y * nk.x))
			normals.append(Vector3(ni.x * nj.x, nj.y, ni.y * nj.x))
			if i > 0 and j > 0:
				indices.append_array([thisrow + j - 1, prevrow + j, prevrow + j - 1, thisrow + j - 1, thisrow + j, prevrow + j])
	return _append(points, normals, indices, t)


func prism(size: Vector3, t := Transform3D.IDENTITY) -> MeshForge:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var ltr := 0.5   # PrismMesh.left_to_right 默认值
	var start := size * -0.5
	var point := 0
	# 前 + 后
	var y := start.y
	var thisrow := point
	var prevrow := 0
	for j in 2:
		var scale := (y - start.y) / size.y
		var scaled_x := size.x * scale
		var start_x := start.x + (1.0 - scale) * size.x * ltr
		var x := 0.0
		for i in 2:
			points.append(Vector3(start_x + x, -y, -start.z))
			normals.append(Vector3(0.0, 0.0, 1.0))
			points.append(Vector3(start_x + scaled_x - x, -y, start.z))
			normals.append(Vector3(0.0, 0.0, -1.0))
			point += 2
			if i > 0 and j == 1:
				var i2 := i * 2
				indices.append_array([prevrow + i2, thisrow + i2, thisrow + i2 - 2])
				indices.append_array([prevrow + i2 + 1, thisrow + i2 + 1, thisrow + i2 - 1])
			elif i > 0 and j > 0:
				_quad_pair(indices, prevrow, thisrow, i * 2)
			x += scale * size.x
		y += size.y
		prevrow = thisrow
		thisrow = point
	# 右 + 左(斜面)
	var normal_left := Vector3(-size.y, size.x * ltr, 0.0).normalized()
	var normal_right := Vector3(size.y, size.x * (1.0 - ltr), 0.0).normalized()
	y = start.y
	thisrow = point
	prevrow = 0
	for j in 2:
		var scale := (y - start.y) / size.y
		var left := start.x + size.x * (1.0 - scale) * ltr
		var right := left + size.x * scale
		var z := start.z
		for i in 2:
			points.append(Vector3(right, -y, -z))
			normals.append(normal_right)
			points.append(Vector3(left, -y, z))
			normals.append(normal_left)
			point += 2
			if i > 0 and j > 0:
				_quad_pair(indices, prevrow, thisrow, i * 2)
			z += size.z
		y += size.y
		prevrow = thisrow
		thisrow = point
	# 底
	var z := start.z
	thisrow = point
	prevrow = 0
	for j in 2:
		var x := start.x
		for i in 2:
			points.append(Vector3(x, start.y, -z))
			normals.append(Vector3(0.0, -1.0, 0.0))
			point += 1
			if i > 0 and j > 0:
				indices.append_array([prevrow + i - 1, prevrow + i, thisrow + i - 1, prevrow + i, thisrow + i, thisrow + i - 1])
			x += size.x
		z += size.z
		prevrow = thisrow
		thisrow = point
	return _append(points, normals, indices, t)


# —— 新几何 ——

func lathe(profile: PackedVector2Array, segments := 24, creases := PackedInt32Array(),
		t := Transform3D.IDENTITY) -> MeshForge:
	# 车削体:profile 为 (半径, 高度) 自下而上;creases 里的轮廓点复制一份做硬边;
	# 半径为 0 的端点自然收口。法线按轮廓切线解析计算
	var rows: Array[Dictionary] = []   # 每行:轮廓点与它的轮廓法线(r, y 方向)
	var n := profile.size()
	for k in n:
		var prev := profile[maxi(k - 1, 0)]
		var next := profile[mini(k + 1, n - 1)]
		if creases.has(k) and k > 0 and k < n - 1:
			rows.append({"p": profile[k], "n": _lathe_normal(prev, profile[k])})
			rows.append({"p": profile[k], "n": _lathe_normal(profile[k], next)})
		else:
			rows.append({"p": profile[k], "n": _lathe_normal(prev, next)})
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var stride := segments + 1
	for r in rows.size():
		var p: Vector2 = rows[r]["p"]
		var pn: Vector2 = rows[r]["n"]
		for i in stride:
			var a := float(i) / segments * TAU
			var dir := Vector3(sin(a), 0.0, cos(a))
			points.append(Vector3(dir.x * p.x, p.y, dir.z * p.x))
			normals.append((dir * pn.x + Vector3(0.0, pn.y, 0.0)).normalized())
			if r > 0 and i > 0 and rows[r]["p"] != rows[r - 1]["p"]:
				var a0 := (r - 1) * stride + i - 1
				var b0 := r * stride + i - 1
				indices.append_array([a0, b0, a0 + 1, a0 + 1, b0, b0 + 1])
	return _append(points, normals, indices, t)


static func _lathe_normal(a: Vector2, b: Vector2) -> Vector2:
	# 轮廓从 a 到 b(自下而上)的外法线:切线 (dr, dy) 顺时针转 90°
	var d := b - a
	if d.length_squared() < 1e-12:
		return Vector2(1.0, 0.0)
	return Vector2(d.y, -d.x).normalized()


# —— 写入 ——

func _append(points: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array, t: Transform3D) -> MeshForge:
	var xform: Transform3D = _stack.back() * t
	var det := xform.basis.determinant()
	if absf(det) < 1e-9:
		return self   # 缩放退化的部件不写
	var normal_basis := xform.basis.inverse().transposed()
	var s := _current
	var base := s.vertices.size()
	var c := Color(color.r, color.g, color.b, ao)
	var pbr := Vector2(rough, metal)
	if part_space and not s.has_custom:
		s.has_custom = true
		s.custom0.resize(base * 4)   # 之前的部件补 0
	for k in points.size():
		s.vertices.append(xform * points[k])
		s.normals.append((normal_basis * normals[k]).normalized())
		s.colors.append(c)
		s.uv2.append(pbr)
		if s.has_custom:
			if part_space:
				s.custom0.append_array([points[k].x, points[k].y, points[k].z, seed])
			else:
				s.custom0.append_array([0.0, 0.0, 0.0, 0.0])
	if det < 0.0:
		# 镜像变换翻转绕序
		for k in range(0, indices.size(), 3):
			s.indices.append_array([base + indices[k], base + indices[k + 2], base + indices[k + 1]])
	else:
		for k in indices.size():
			s.indices.append(base + indices[k])
	return self


# —— 输出 ——

func build() -> Dictionary:
	# {surface 名: Mesh.ARRAY_MAX 长度的数组},纯数据,线程安全
	var out := {}
	for surface_name in _order:
		var s: _Surface = _surfaces[surface_name]
		if s.vertices.is_empty():
			continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = s.vertices
		arrays[Mesh.ARRAY_NORMAL] = s.normals
		arrays[Mesh.ARRAY_COLOR] = s.colors
		arrays[Mesh.ARRAY_TEX_UV2] = s.uv2
		arrays[Mesh.ARRAY_INDEX] = s.indices
		if s.has_custom:
			arrays[Mesh.ARRAY_CUSTOM0] = s.custom0
		out[surface_name] = arrays
	return out


static func commit(built: Dictionary, materials := {}) -> ArrayMesh:
	# 只在主线程调用;材质挂在网格的 surface 上,共享网格的实例照样自动实例化
	var mesh := ArrayMesh.new()
	for surface_name in built:
		var arrays: Array = built[surface_name]
		var flags := CUSTOM0_FORMAT if arrays[Mesh.ARRAY_CUSTOM0] != null else 0
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
		var index := mesh.get_surface_count() - 1
		mesh.surface_set_name(index, surface_name)
		if materials.has(surface_name):
			mesh.surface_set_material(index, materials[surface_name])
	return mesh


static func run(recipe: Callable) -> Dictionary:
	var forge := MeshForge.new()
	recipe.call(forge)
	return forge.build()


# —— 缓存与预建 ——

static func cached(key: String, recipe: Callable, materials := {}) -> ArrayMesh:
	if _cache.has(key):
		return _cache[key]
	var built: Dictionary
	if _jobs.has(key):
		var job: _Job = _jobs[key]
		WorkerThreadPool.wait_for_task_completion(job.task_id)   # 纯数学任务,不会死锁
		_jobs.erase(key)
		built = job.built
	else:
		built = run(recipe)
	_cache[key] = commit(built, materials)
	return _cache[key]


static func is_cached(key: String) -> bool:
	return _cache.has(key)


static func prebuild(jobs: Array) -> void:
	# jobs: [[key, recipe, materials], …]:投递到工作线程,不等待;材质在投递前由调用方建好
	for spec in jobs:
		var key: String = spec[0]
		if _cache.has(key) or _jobs.has(key):
			continue
		var job := _Job.new()
		job.key = key
		job.recipe = spec[1]
		job.materials = spec[2] if spec.size() > 2 else {}
		job.task_id = WorkerThreadPool.add_task(func(): job.built = run(job.recipe), false, "MeshForge " + key)
		_jobs[key] = job


static func wait_prebuilt(tree: SceneTree) -> void:
	# 协程:每帧轮询,完成一个就回收任务(每个任务都必须 wait 一次)并 commit 进缓存
	while not _jobs.is_empty():
		for key in _jobs.keys():
			var job: _Job = _jobs[key]
			if WorkerThreadPool.is_task_completed(job.task_id):
				WorkerThreadPool.wait_for_task_completion(job.task_id)
				_jobs.erase(key)
				_cache[key] = commit(job.built, job.materials)
		if not _jobs.is_empty():
			await tree.process_frame


static func clear_cache() -> void:
	for job: _Job in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(job.task_id)
	_jobs = {}
	_cache = {}
