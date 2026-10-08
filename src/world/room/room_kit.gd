class_name RoomKit
# 房间构建器共用的小工具:挂合批网格(层与投影一次设好)、火焰公告板、道具调色板。


# 道具调色板:sRGB albedo、粗糙度、金属度(prop.gdshader 的顶点 PBR)。
# 动森式温馨卡通(2026-10-08):明度高、饱和中等的粉彩暖色;哑光为主,金属件是缎面;最暗的颜色也带色相(深靛、深棕)
const BRASS := [Color(0.80, 0.66, 0.36), 0.48, 0.65]
const OLD_BRASS := [Color(0.72, 0.58, 0.33), 0.55, 0.6]
const IRON := [Color(0.27, 0.26, 0.32), 0.62, 0.35]
const TIN := [Color(0.66, 0.68, 0.72), 0.5, 0.45]
const BONE := [Color(0.80, 0.76, 0.66), 0.75, 0.0]
const HORN := [Color(0.60, 0.52, 0.42), 0.6, 0.0]
const WAX := [Color(0.80, 0.75, 0.63), 0.6, 0.0]
const CLAY := [Color(0.78, 0.47, 0.33), 0.75, 0.0]
const CACTUS := [Color(0.42, 0.64, 0.38), 0.75, 0.0]
const LEATHER := [Color(0.56, 0.34, 0.21), 0.7, 0.0]
const FELT_HAT := [Color(0.46, 0.33, 0.23), 0.85, 0.0]
const COAT := [Color(0.54, 0.42, 0.31), 0.9, 0.0]
const GILT := [Color(0.80, 0.65, 0.34), 0.48, 0.6]
const GLASS_DARK := [Color(0.30, 0.44, 0.34), 0.25, 0.0]
const ROPE := [Color(0.74, 0.62, 0.42), 0.9, 0.0]
const FOAM := [Color(0.80, 0.78, 0.70), 0.65, 0.0]
const BEER := [Color(0.80, 0.56, 0.22), 0.4, 0.0]
const PEWTER := [Color(0.62, 0.63, 0.67), 0.5, 0.45]
const BLACK := [Color(0.22, 0.20, 0.25), 0.55, 0.0]
const CREAM := [Color(0.80, 0.74, 0.61), 0.65, 0.0]
const RED_PAINT := [Color(0.77, 0.34, 0.29), 0.6, 0.0]
const LAMP_GLASS := [Color(0.78, 0.76, 0.66), 0.3, 0.0]


static func paint(f: MeshForge, swatch: Array, ao := 1.0) -> void:
	f.paint(swatch[0], swatch[1], swatch[2])
	f.ao = ao


static func add(parent: Node3D, node_name: String, key: String, recipe: Callable, materials: Dictionary, layers: int,
		casts: bool, pos := Vector3.ZERO) -> MeshInstance3D:
	# 合批网格(MeshForge.cached,同 key 共享)挂到 parent 下;layers 与投影一次设好
	var inst := MeshKit.add(parent, MeshForge.cached(key, recipe, materials), null, pos, Vector3.ZERO, Vector3.ONE,
		MeshKit.SHADOW_ON if casts else MeshKit.SHADOW_OFF)
	inst.name = node_name
	inst.layers = layers
	return inst


static func flame(parent: Node3D, size: Vector2, pos: Vector3, intensity: float, seed: float) -> MeshInstance3D:
	# 火焰公告板:共用一份材质,强度与种子按实例设定(同 Tavern._flame)
	var inst := MeshKit.add(parent, MeshKit.quad(size), WorldMaterials.flame(), pos, Vector3.ZERO, Vector3.ONE, MeshKit.SHADOW_OFF)
	inst.set_instance_shader_parameter("intensity", intensity)
	inst.set_instance_shader_parameter("seed", seed)
	return inst


static func flicker(light: Light3D, speed: float, depth: float, seed: float) -> Dictionary:
	# Tavern._flickers 的一项
	return {"light": light, "base": light.light_energy, "speed": speed, "depth": depth, "seed": seed}


static func decor_paint(f: MeshForge, mode: int, param := 0.0, tint := Color.WHITE, ao := 1.0) -> void:
	# decor 材质:UV2 = (模式, 参数),COLOR = 色调 + AO
	f.paint(tint, float(mode), param)
	f.ao = ao


static func ring_profile(points: Array) -> PackedVector2Array:
	return PackedVector2Array(points)


# —— 圆润形体(动森式卡通,2026-10-08):圆角截面、平滑法线的挤出、圆角盒子。纯数组运算,工作线程里可用 ——

static func round_rect(w: float, h: float, r: float, segs := 3, center := Vector2.ZERO) -> PackedVector2Array:
	# 圆角矩形截面(z 宽 w、y 高 h、圆角半径 r,每个角 segs 段),逆时针;r 夹到短边一半以内
	r = clampf(r, 0.0, minf(w, h) * 0.5 - 1e-4)
	var x := w / 2.0 - r
	var y := h / 2.0 - r
	var out := PackedVector2Array()
	var corners := [Vector2(x, -y), Vector2(x, y), Vector2(-x, y), Vector2(-x, -y)]
	for c in 4:
		var a0 := -PI / 2.0 + c * PI / 2.0
		for k in segs + 1:
			var a := a0 + (PI / 2.0) * k / segs
			out.append(center + corners[c] + Vector2(cos(a), sin(a)) * r)
	return out


static func extrude_smooth(f: MeshForge, profile: PackedVector2Array, length: float, t := Transform3D.IDENTITY,
		crease_deg := 50.0, caps := Vector2i(1, 1)) -> void:
	# 同 MeshForge.extrude_x(截面在局部 (z, y) 平面,沿 X 挤出),但相邻两边夹角小于 crease_deg 的顶点共用平均法线:
	# 圆角截面挤出来是圆的而不是一圈小平面
	var n := profile.size()
	if n < 3:
		return
	var area := 0.0
	for k in n:
		area += profile[k].x * profile[(k + 1) % n].y - profile[(k + 1) % n].x * profile[k].y
	var orient := 1.0 if area > 0.0 else -1.0
	var en: Array[Vector2] = []
	for k in n:
		var d := profile[(k + 1) % n] - profile[k]
		en.append(Vector2(d.y, -d.x).normalized() * orient if d.length_squared() > 1e-14 else Vector2.ZERO)
	var cos_crease := cos(deg_to_rad(crease_deg))
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var hx := length * 0.5
	for k in n:
		if en[k] == Vector2.ZERO:
			continue
		var a := profile[k]
		var b := profile[(k + 1) % n]
		var prev: Vector2 = en[(k - 1 + n) % n]
		var next: Vector2 = en[(k + 1) % n]
		var na: Vector2 = (prev + en[k]).normalized() if prev.dot(en[k]) > cos_crease else en[k]
		var nb: Vector2 = (next + en[k]).normalized() if next.dot(en[k]) > cos_crease else en[k]
		var va := Vector3(0.0, na.y, na.x)
		var vb := Vector3(0.0, nb.y, nb.x)
		var base := points.size()
		points.append_array([Vector3(-hx, a.y, a.x), Vector3(hx, a.y, a.x), Vector3(-hx, b.y, b.x), Vector3(hx, b.y, b.x)])
		normals.append_array([va, va, vb, vb])
		if orient > 0.0:
			indices.append_array([base, base + 2, base + 1, base + 1, base + 2, base + 3])
		else:
			indices.append_array([base, base + 1, base + 2, base + 1, base + 3, base + 2])
	var tris := Geometry2D.triangulate_polygon(profile)
	for end in 2:
		if (end == 0 and caps.x == 0) or (end == 1 and caps.y == 0):
			continue
		var x := -hx if end == 0 else hx
		var nn := Vector3(-1.0 if end == 0 else 1.0, 0.0, 0.0)
		var base := points.size()
		for p in profile:
			points.append(Vector3(x, p.y, p.x))
			normals.append(nn)
		for k in range(0, tris.size(), 3):
			var i0 := tris[k]
			var i1 := tris[k + 1]
			var i2 := tris[k + 2]
			var face := (points[base + i1] - points[base + i0]).cross(points[base + i2] - points[base + i0])
			if face.dot(nn) > 0.0:
				indices.append_array([base + i0, base + i2, base + i1])
			else:
				indices.append_array([base + i0, base + i1, base + i2])
	f.raw(points, normals, PackedVector2Array(), indices, t)


static func rounded_box(f: MeshForge, size: Vector3, radius: float, t := Transform3D.IDENTITY, segs := 2) -> void:
	# 圆角盒子:六个面各一张网格,靠棱的格子投到半径 radius 的圆角上(棱是 1/4 圆柱、角是 1/8 球),法线平滑。
	# 每条棱 2·segs 段;segs 2 时 216 个顶点、300 个三角形
	var h := size * 0.5
	radius = clampf(radius, 0.0, minf(h.x, minf(h.y, h.z)))
	var inner := h - Vector3.ONE * radius
	var coords: Array[PackedFloat32Array] = []
	for axis in 3:
		var c := PackedFloat32Array()
		for k in range(segs, -1, -1):
			c.append(-inner[axis] - radius * tan(PI / 4.0 * k / segs))
		for k in segs + 1:
			c.append(inner[axis] + radius * tan(PI / 4.0 * k / segs))
		coords.append(c)
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	# [法线轴, 符号, u 轴, v 轴]:u × v = 外法线
	for face in [[0, 1.0, 1, 2], [0, -1.0, 2, 1], [1, 1.0, 2, 0], [1, -1.0, 0, 2], [2, 1.0, 0, 1], [2, -1.0, 1, 0]]:
		var a: int = face[0]
		var u: int = face[2]
		var v: int = face[3]
		var cu: PackedFloat32Array = coords[u]
		var cv: PackedFloat32Array = coords[v]
		var base := points.size()
		for j in cv.size():
			for i in cu.size():
				var p := Vector3.ZERO
				p[a] = face[1] * h[a]
				p[u] = cu[i]
				p[v] = cv[j]
				var q := p.clamp(-inner, inner)
				var d := p - q
				var nrm := d.normalized() if d.length_squared() > 1e-12 else Vector3.ZERO
				if nrm == Vector3.ZERO:
					nrm[a] = face[1]
				points.append(q + nrm * radius if radius > 0.0 else p)
				normals.append(nrm)
		var w := cu.size()
		for j in cv.size() - 1:
			for i in w - 1:
				var p00 := base + j * w + i
				var p10 := p00 + 1
				var p01 := p00 + w
				var p11 := p01 + 1
				indices.append_array([p00, p11, p10, p00, p01, p11])
	f.raw(points, normals, PackedVector2Array(), indices, t)
