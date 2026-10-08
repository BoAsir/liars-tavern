extends RefCounted
# 羊驼「披毯客」:小颅骨、长脸、前伸的吻(分开的上唇、两颗下门牙)、头顶一大团卷毛、大眼长睫毛;
# 香蕉耳从卷毛里竖起;卷毛顶上一顶用颏绳戴着的迷你草帽;毛团凸起的绒毛躯干、脖根一圈蓬松毛领、
# 左肩斜披到右胯的宽条纹织毯(贴着身体、胯侧打结垂流苏)、绿松石波洛领绳;绒腿套着一圈圈堆起的毛线腿套、两趾软蹄;长脖子。


const LOOK := {
	"id": "alpaca",
	"palette": {
		"fur": Color(0.78, 0.66, 0.5), "muzzle": Color(0.80, 0.74, 0.62), "dark": Color(0.35, 0.26, 0.18),
		"fleece": Color(0.80, 0.70, 0.55), "coat": Color(0.76, 0.64, 0.48), "accent": Color(0.25, 0.6, 0.58),
		"blanket": Color(0.70, 0.16, 0.14), "mustard": Color(0.76, 0.58, 0.18), "teal": Color(0.16, 0.46, 0.48),
		"cream": Color(0.80, 0.75, 0.62), "weft": Color(0.24, 0.14, 0.10), "straw": Color(0.78, 0.66, 0.38),
		"band": Color(0.70, 0.16, 0.14), "pants": Color(0.74, 0.62, 0.46), "warmer": Color(0.80, 0.72, 0.58),
		"nose": Color(0.3, 0.2, 0.16), "hoof": Color(0.22, 0.16, 0.12), "pad": Color(0.4, 0.3, 0.22),
		"tooth": Color(0.80, 0.78, 0.70),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.13, 0.14, 0.135), "fur"],
			[Vector3(0, 0.225, 0.005), Vector3(0.11, 0.07, 0.11), "fleece"],     # 卷毛团的底(上面的小卷在 extras 里)
			[Vector3(0, 0.075, -0.1), Vector3(0.075, 0.08, 0.09), "muzzle"],    # 长脸
			[Vector3(0, 0.025, -0.13), Vector3(0.05, 0.03, 0.07), "muzzle"],    # 下巴
		],
		"blend": 0.045,
		"snout": {"path": [Vector3(0, 0.07, -0.11), Vector3(0, 0.06, -0.17), Vector3(0, 0.056, -0.214)],
			"radii": [Vector2(0.062, 0.064), Vector2(0.052, 0.056), Vector2(0.043, 0.047)], "color": "muzzle"},
		"nose": {"pos": Vector3(0, 0.083, -0.248), "radii": Vector3(0.022, 0.011, 0.01), "color": "nose"},
		"mouth": {"kind": "smile", "pos": Vector3(0, 0.036, -0.252), "width": 0.042},
	},
	"eyes": {"pos": Vector3(0.068, 0.15, -0.105), "size": Vector3(0.042, 0.046, 0.02), "iris": Color(0.24, 0.16, 0.1),
		"pupil": 2, "lid_rest": 0.15, "lashes": true, "yaw": 22.0},
	"brows": {"pos": Vector3(0.07, 0.2, -0.11), "color": "dark", "width": 0.045, "thickness": 0.008},
	"ears": {"kind": "banana", "pivot": Vector3(0.1, 0.27, 0.0), "rot": Vector3(0, 0, -12),
		"size": Vector3(0.03, 0.168, 0.018), "inner": "dark"},
	"hat": {"kind": "straw", "pivot": Vector3(0, 0.335, 0.0), "rot": Vector3(-6, 0, 0), "crown_radius": 0.05, "brim": 0.072,
		"band": "band"},
	"neck": {"base": Vector3(0, 0.44, -0.04), "radius": 0.07, "color": "fur"},
	"body": {"build": "round", "coat": "coat", "belly": "coat", "pants": "pants",
		"buttons": 0, "neckwear": "bolo", "neckwear_color": "accent", "collar": "fleece",
		# 绒毛团:背上、肩后、腰侧、肚前几团鼓起(平滑并集出蓬松的轮廓)
		"shapes": [[Vector3(0.12, 0.43, 0.07), Vector3(0.08, 0.07, 0.07), "fleece", "mirror"],
			[Vector3(0, 0.3, 0.1), Vector3(0.11, 0.1, 0.065), "coat"],
			[Vector3(0.175, 0.28, 0.03), Vector3(0.06, 0.08, 0.075), "coat", "mirror"],
			[Vector3(0, 0.13, 0.11), Vector3(0.13, 0.08, 0.07), "fleece"],
			[Vector3(0.12, 0.1, -0.15), Vector3(0.075, 0.075, 0.07), "fleece", "mirror"]]},
	"arms": {"sleeve": "coat", "cuff": "fleece"},
	"paws": {"color": "fur", "pads": "pad", "fingers": 2, "length": 0.03},
	"legs": {"pants": "pants", "foot": "hoof", "foot_color": "hoof"},
	"tail": {"path": [Vector3(0, 0.5, 0.25), Vector3(0, 0.52, 0.29), Vector3(0, 0.515, 0.32)], "radius": 0.042, "tip_radius": 0.03,
		"bulge": 0.012, "color": "fleece", "sway_range": Vector2(0.0, 1.0)},
	"anim": {"look_pitch_min": -0.45, "blink_speed": 1.0},
}

# 织毯:绕躯干一整圈的斜带(左肩 → 胸前 → 右胯 → 背后 → 左肩),截面横向贴着身体
const SASH_FROM := Vector3(0, 0.29, 0.0)
const SASH_AXIS := Vector3(-0.5, 1.0, 0.0)   # 指向左肩(左 = -X)
const SASH_WIDTH := 0.17
const SASH_KNOT := 0.41                      # 结打在右胯侧(圈参数,见 _sash_dir)
# 色带(沿毯子长度):[颜色键, 长度 m]
const SASH_BANDS := [["blanket", 0.065], ["weft", 0.007], ["mustard", 0.02], ["teal", 0.018], ["cream", 0.011],
	["teal", 0.018], ["mustard", 0.02], ["weft", 0.007]]
const SASH_COLS := [[-0.5, 0.0], [-0.45, 0.009], [-0.3, 0.015], [0.0, 0.017], [0.3, 0.015], [0.45, 0.009], [0.5, 0.0]]


static func extras(f: MeshForge, part: String, look: Dictionary, pal: Dictionary) -> void:
	match part:
		"head":
			_head(f, look, pal)
		"hat":
			_strap(f, look, pal)
		"body":
			var shapes := PatronBuilder.body_shapes(look, pal)
			_ruff(f, pal)
			_sash(f, pal, shapes)
		"legs":
			_warmers(f, pal)


# —— 头:卷毛、分开的上唇、下门牙 ——

static func _head(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	# 卷毛团:一团核心加上半球上按黄金角撒开的小卷,前面几卷垂到额头
	var fleece: Color = pal["fleece"]
	var shapes := [[Vector3(0, 0.255, 0.0), Vector3(0.1, 0.055, 0.1), fleece]]
	var n := 15
	for k in n:
		var y := 1.0 - (k + 0.5) / n * 0.95
		var r := sqrt(1.0 - y * y)
		var a := k * 2.39996
		var p := Vector3(0, 0.255, 0.0) + Vector3(cos(a) * r * 0.1, y * 0.055, sin(a) * r * 0.1)
		var shade := fleece.darkened(0.05 + 0.08 * fmod(k * 0.618, 1.0))
		shapes.append([p, Vector3.ONE * (0.03 + 0.008 * fmod(k * 0.37, 1.0)), shade])
	for x: float in [-0.045, 0.0, 0.045]:
		shapes.append([Vector3(x, 0.225 - absf(x) * 0.3, -0.095), Vector3(0.03, 0.028, 0.026), fleece.darkened(0.04)])
	PatronBuilder.paint(f, pal, "fleece", 0.95, PatronBuilder.FUR)
	f.blob(Vector3(0, 0.255, 0.0), shapes, 30, 18, 0.016)
	# 上唇中缝(从鼻子下到嘴线)与两颗下门牙
	PatronBuilder.paint(f, pal, "dark", 0.5, PatronBuilder.SMOOTH)
	f.tube(PackedVector3Array([Vector3(0, 0.075, -0.257), Vector3(0, 0.055, -0.259), Vector3(0, 0.038, -0.254)]), 0.0026, 4)
	PatronBuilder.paint(f, pal, "tooth", 0.4, PatronBuilder.SMOOTH)
	for side: float in [-1.0, 1.0]:
		f.box(Vector3(0.011, 0.012, 0.006), PatronBuilder.xf(Vector3(0.0065 * side, 0.027, -0.246), Vector3(-15, 0, 0)))


static func _strap(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	# 草帽颏绳:从帽檐两侧贴着脸颊绕到下巴底下(按头雕表面取点,再换到帽子局部)
	var skull := PatronHeadBuilder.skull_shapes(look, pal)
	var hat: Dictionary = look["hat"]
	var to_hat := MeshForge.xf(hat["pivot"], hat["rot"]).affine_inverse()
	var dirs := [Vector3(0.95, 0.15, -0.28), Vector3(0.82, -0.4, -0.42), Vector3(0.4, -0.8, -0.5), Vector3(0.0, -0.86, -0.52)]
	PatronBuilder.paint(f, pal, "band", 0.7, PatronBuilder.CLOTH)
	for side: float in [-1.0, 1.0]:
		var path := PackedVector3Array([Vector3(0.068 * side, 0.004, -0.004)])
		for d: Vector3 in dirs:
			var dd := Vector3(d.x * side, d.y, d.z)
			var p := MeshForge.blob_surface(PatronHeadBuilder.HEAD_CENTER, dd, skull, 0.045) + dd.normalized() * 0.004
			path.append(to_hat * p)
		f.tube(path, 0.0019, 4)


# —— 躯干:毛领、织毯 ——

static func _ruff(f: MeshForge, pal: Dictionary) -> void:
	# 脖根一圈蓬松毛领:扁圆芯 + 一圈小毛团(脖子从中间穿过)
	var fleece: Color = pal["fleece"]
	var c := Vector3(0, 0.555, -0.04)
	var shapes := [[c, Vector3(0.075, 0.03, 0.07), fleece]]
	for k in 10:
		var a := TAU * (k + 0.5) / 10.0
		shapes.append([c + Vector3(cos(a) * 0.072, 0.004 * sin(a * 3.0), sin(a) * 0.066), Vector3(0.034, 0.03, 0.032),
			fleece.darkened(0.04 * (k % 3))])
	PatronBuilder.paint(f, pal, "fleece", 0.95, PatronBuilder.FUR)
	f.blob(c, shapes, 24, 10, 0.016)


static func _sash_dir(t: float) -> Vector3:
	# 沿圈参数 t(0..1)的中心线方向:0 左肩 → 0.25 胸前 → 0.5 右胯 → 0.75 背后
	var a := SASH_AXIS.normalized()
	var phi := t * TAU
	return a * cos(phi) + Vector3(0, 0, -1) * sin(phi)


static func _sash_point(shapes: Array, t: float, w: float, lift: float) -> Vector3:
	# 毯面上一点:中心线方向沿毯宽方向偏 w(米,按到表面的距离折成角度),投到身体表面再抬 lift
	var d := _sash_dir(t)
	var across := SASH_AXIS.normalized().cross(Vector3(0, 0, -1)).normalized()
	var r := (MeshForge.blob_surface(SASH_FROM, d, shapes, PatronBuilder.BLOB_K) - SASH_FROM).length()
	var dw := (d + across * (w / r)).normalized()
	return MeshForge.blob_surface(SASH_FROM, dw, shapes, PatronBuilder.BLOB_K) + dw * lift


static func _sash(f: MeshForge, pal: Dictionary, shapes: Array) -> void:
	# 中心线先细分求弧长,色带按弧长切行(色带边界重复一行,得到硬边色带)
	var samples := 120
	var lengths := PackedFloat32Array([0.0])
	var prev := _sash_point(shapes, 0.0, 0.0, 0.0)
	for i in range(1, samples + 1):
		var p := _sash_point(shapes, float(i) / samples, 0.0, 0.0)
		lengths.append(lengths[i - 1] + p.distance_to(prev))
		prev = p
	var total := lengths[samples]
	var rows := []
	var colors := []
	var s := 0.0
	var band := 0
	while s < total - 0.001:
		var entry: Array = SASH_BANDS[band % SASH_BANDS.size()]
		var e := minf(s + float(entry[1]), total)
		var c: Color = pal[entry[0]]
		var stops := [s, e] if e - s < 0.03 else [s, (s + e) * 0.5, e]
		for at: float in stops:
			var t := _length_to_t(lengths, at)
			var row := PackedVector3Array()
			var crow := PackedColorArray()
			for col: Array in SASH_COLS:
				row.append(_sash_point(shapes, t, col[0] * SASH_WIDTH, col[1]))
				var edge := c.darkened(0.12) if absf(col[0]) > 0.4 else c
				crow.append(Color(edge.r, edge.g, edge.b, 1.0))
			rows.append(row)
			colors.append(crow)
		s = e
		band += 1
	PatronBuilder.paint(f, pal, "blanket", 0.95, PatronBuilder.CLOTH)
	_grid(f, rows, colors, SASH_FROM)
	# 右胯侧的结:一团毯子,下面垂两片短毯尾,末端一排流苏
	var knot := _sash_point(shapes, SASH_KNOT, 0.0, 0.02)
	var out := (knot - SASH_FROM).normalized()
	PatronBuilder.paint(f, pal, "blanket", 0.95, PatronBuilder.CLOTH)
	f.sphere(0.034, 10, PatronBuilder.xf(knot, Vector3(0, 0, 20), Vector3(1.0, 0.85, 0.75)))
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var top := knot + Vector3(0.0, -0.01, side * 0.025) + out * 0.006
		var bottom := top + Vector3(0.025, -0.07, side * 0.012) + out * 0.01
		PatronBuilder.paint(f, pal, "teal" if k == 0 else "mustard", 0.95, PatronBuilder.CLOTH)
		f.loft(PackedVector3Array([top, top.lerp(bottom, 0.5) + out * 0.006, bottom]),
			PackedVector2Array([Vector2(0.007, 0.03), Vector2(0.006, 0.028), Vector2(0.005, 0.026)]), 6, Vector2i(1, 1),
			Transform3D.IDENTITY, PackedColorArray(), Vector2(-1, -1), out)
		PatronBuilder.paint(f, pal, "cream", 0.9, PatronBuilder.CLOTH)
		for j in 5:
			var root := bottom + Vector3(0, 0, (j - 2) * 0.011)
			f.tube(PackedVector3Array([root, root + Vector3(0.006 + j * 0.002, -0.032, 0.0)]), 0.0028, 4)


static func _length_to_t(lengths: PackedFloat32Array, at: float) -> float:
	var n := lengths.size() - 1
	for i in n:
		if lengths[i + 1] >= at:
			var span := maxf(lengths[i + 1] - lengths[i], 1e-6)
			return (i + (at - lengths[i]) / span) / n
	return 1.0


# —— 腿:毛线腿套 ——

static func _warmers(f: MeshForge, pal: Dictionary) -> void:
	# 小腿上一圈圈堆起来的毛线腿套(放样半径一大一小交替),脚踝处收成蓬松的一团盖住蹄口
	var c: Color = pal["warmer"]
	for side: float in [-1.0, 1.0]:
		var x := 0.1 * side
		var path := PackedVector3Array()
		var radii := PackedVector2Array()
		var colors := PackedColorArray()
		var rings := 15
		for k in rings:
			var t := float(k) / (rings - 1)
			var y := lerpf(0.37, 0.06, t)
			var z := lerpf(-0.155, -0.16, smoothstep(0.38, 0.2, y)) + lerpf(0.0, 0.005, smoothstep(0.2, 0.08, y))
			var base := lerpf(0.046, 0.05, smoothstep(0.08, 0.2, y)) + lerpf(0.0, 0.006, smoothstep(0.2, 0.38, y))
			var puff := 0.017 if k % 2 == 0 else 0.006
			if k == rings - 1:
				puff = 0.022
			path.append(Vector3(x * lerpf(1.02, 1.04, t), y, z))
			radii.append(Vector2.ONE * (base + puff))
			var shade := c.darkened(0.0 if k % 2 == 0 else 0.1)
			colors.append(Color(shade.r, shade.g, shade.b, 1.0))
		PatronBuilder.paint(f, pal, "warmer", 0.95, PatronBuilder.KNIT)
		f.loft(path, radii, 12, Vector2i(1, 1), Transform3D.IDENTITY, colors)


# —— 网格工具 ——

static func _grid(f: MeshForge, rows: Array, colors: Array, inside: Vector3) -> void:
	# 行列点阵 → 三角网:法线按相邻点差分、朝离开 inside 的一侧;逐四边形按法线定绕序(Godot 顺时针为正面)
	var nr := rows.size()
	var nc: int = rows[0].size()
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	var indices := PackedInt32Array()
	for r in nr:
		for c in nc:
			var p: Vector3 = rows[r][c]
			var tr: Vector3 = rows[mini(r + 1, nr - 1)][c] - rows[maxi(r - 1, 0)][c]
			var tc: Vector3 = rows[r][mini(c + 1, nc - 1)] - rows[r][maxi(c - 1, 0)]
			var n := tr.cross(tc)
			if n.length_squared() < 1e-12:
				n = p - inside
			n = n.normalized()
			if n.dot(p - inside) < 0.0:
				n = -n
			points.append(p)
			normals.append(n)
			cols.append(colors[r][c])
	for r in nr - 1:
		for c in nc - 1:
			var a := r * nc + c
			var b := a + 1
			var d := a + nc
			var e := d + 1
			var g := (points[b] - points[a]).cross(points[d] - points[a]) + (points[e] - points[b]).cross(points[d] - points[b])
			if g.dot(normals[a] + normals[e]) > 0.0:
				indices.append_array([a, d, b, b, d, e])
			else:
				indices.append_array([a, b, d, b, e, d])
	f._append(points, normals, indices, Transform3D.IDENTITY, cols)
