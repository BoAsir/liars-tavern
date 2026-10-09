class_name FireplaceLogs
# 劈柴生成器:整根圆木、对半劈开、劈成四瓣三种截面。树皮面圆鼓鼓地起伏、劈面平直、两端是锯口。
# 顶点色 alpha 标记部位,fireplace_log 着色器据此分别画树皮、劈开的浅色木面与年轮:
#   BARK = 1、SPLIT = 0.5、END_GRAIN = 0。截面在 XY 平面、原木圆心在原点,沿 Z 轴伸展。


const KINDS := ["round", "half", "quarter"]
const BARK := 1.0
const SPLIT := 0.5
const END_GRAIN := 0.0
const AROUND := 12                   # 整圆一圈树皮的分段
const RINGS := 4                     # 沿长度的分段:树皮可以起伏
const LUMP := 0.07                   # 树皮半径起伏的幅度(相对半径)
const END_TAPER := 0.06              # 两端略细


static func log_arrays(radius: float, length: float, kind: String, seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var phases := Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU)
	var arc := _arc_span(kind)
	var steps := maxi(3, roundi(AROUND * arc / TAU))
	var rings := []   # 每圈:树皮弧上的点(逆时针,带 z);劈开的柴另有圆心点
	for k in RINGS + 1:
		var t := float(k) / RINGS
		var z := -length / 2.0 + length * t
		var taper := 1.0 - END_TAPER * absf(2.0 * t - 1.0)
		rings.append(_arc_points(radius * taper, z, arc, steps, kind == "round", phases))
	var mesh := _Mesh.new()
	_bark(mesh, rings, kind == "round")
	if kind != "round":
		_split_faces(mesh, rings, kind == "quarter")
	for k in [0, RINGS]:
		_end_cap(mesh, rings[k], kind == "quarter", -1.0 if k == 0 else 1.0)
	var arrays := FireplaceStones.to_arrays(mesh.verts, mesh.normals, mesh.indices)
	arrays[Mesh.ARRAY_COLOR] = mesh.colors
	return arrays


class _Mesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	func vertex(pos: Vector3, normal: Vector3, kind: float) -> int:
		verts.append(pos)
		normals.append(normal)
		colors.append(Color(1, 1, 1, kind))
		return verts.size() - 1

	func quad(a: int, b: int, c: int, d: int, outward: Vector3) -> void:
		FireplaceStones.tri(indices, verts, a, b, c, outward)
		FireplaceStones.tri(indices, verts, a, c, d, outward)


static func _arc_span(kind: String) -> float:
	match kind:
		"half":
			return PI
		"quarter":
			return PI / 2.0
	return TAU


static func _arc_points(radius: float, z: float, arc: float, steps: int, closed: bool,
		phases: Vector3) -> PackedVector3Array:
	# 半径按几组正弦起伏:圆润的鼓包,不是锯齿
	var pts := PackedVector3Array()
	for i in (steps if closed else steps + 1):
		var a := arc * i / steps
		var lump := sin(a * 3.0 + phases.x) * 0.6 + sin(a * 5.0 + phases.y + z * 9.0) * 0.4
		var r := radius * (1.0 + LUMP * lump + 0.03 * sin(z * 11.0 + phases.z))
		pts.append(Vector3(cos(a) * r, sin(a) * r, z))
	return pts


static func _bark(mesh: _Mesh, rings: Array, closed: bool) -> void:
	# 树皮逐圈共用顶点,法线取径向(平滑);整根圆木首尾相接
	var per_ring := (rings[0] as PackedVector3Array).size()
	var base := mesh.verts.size()
	for ring in rings:
		for p in ring as PackedVector3Array:
			mesh.vertex(p, Vector3(p.x, p.y, 0.0).normalized(), BARK)
	var segments := per_ring if closed else per_ring - 1
	for k in rings.size() - 1:
		for i in segments:
			var j := (i + 1) % per_ring
			var a := base + k * per_ring + i
			var b := base + k * per_ring + j
			mesh.quad(a, b, b + per_ring, a + per_ring, (mesh.normals[a] + mesh.normals[b]).normalized())


static func _split_faces(mesh: _Mesh, rings: Array, quarter: bool) -> void:
	# 劈面:半劈是一条直径,四瓣是两条半径;每条边沿长度铺一条平面(硬边法线)
	for k in rings.size() - 1:
		var near := _split_edges(rings[k], quarter)
		var far := _split_edges(rings[k + 1], quarter)
		for edge in near.size():
			var e0: Array = near[edge]
			var e1: Array = far[edge]
			var dir: Vector3 = e0[1] - e0[0]
			var out := Vector3(dir.y, -dir.x, 0.0).normalized()
			mesh.quad(mesh.vertex(e0[0], out, SPLIT), mesh.vertex(e0[1], out, SPLIT),
				mesh.vertex(e1[1], out, SPLIT), mesh.vertex(e1[0], out, SPLIT), out)


static func _split_edges(ring: PackedVector3Array, quarter: bool) -> Array:
	# 截面逆时针:弧的末点 → (圆心 →) 弧的起点
	var first := ring[0]
	var last := ring[ring.size() - 1]
	if quarter:
		var center := Vector3(0, 0, first.z)
		return [[last, center], [center, first]]
	return [[last, first]]


static func _end_cap(mesh: _Mesh, ring: PackedVector3Array, quarter: bool, side: float) -> void:
	# 锯口:截面多边形从形心扇形铺开,法线沿长轴朝外
	var outline := ring.duplicate()
	if quarter:
		outline.append(Vector3(0, 0, ring[0].z))
	var center := Vector3.ZERO
	for p in outline:
		center += p
	center /= outline.size()
	var normal := Vector3(0, 0, side)
	var c := mesh.vertex(center, normal, END_GRAIN)
	var first := mesh.verts.size()
	for p in outline:
		mesh.vertex(p, normal, END_GRAIN)
	for i in outline.size():
		FireplaceStones.tri(mesh.indices, mesh.verts, c, first + i, first + (i + 1) % outline.size(), normal)
