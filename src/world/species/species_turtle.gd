extends RefCounted
# 乌龟「老淘金客」:光秃圆头(斑驳老皮、额纹、颈褶、几块老人斑)、短钝角质喙、厚眼睑、白色海象胡、黄铜圆眼镜;
# 没有耳朵,软毡宽松帽(帽冠打补丁);橄榄棕背甲(盾片中心浅、生长环纹、缝深、甲缘一圈缘盾),
# 米黄腹甲代替衬衫前襟(中缝与横缝),红黑格法兰绒衬衫与袖子,棕背带配铜扣;卡其裤膝上补丁、旧靴;小尖尾藏在甲缘下。


const LOOK := {
	"id": "turtle",
	"palette": {
		"fur": Color(0.37, 0.47, 0.25), "muzzle": Color(0.58, 0.60, 0.39), "dark": Color(0.2, 0.24, 0.12),
		"fur_back": Color(0.32, 0.42, 0.22), "spot": Color(0.30, 0.38, 0.19), "beak": Color(0.56, 0.52, 0.34),
		"coat": Color(0.55, 0.16, 0.12), "accent": Color(0.40, 0.25, 0.13), "shell": Color(0.38, 0.32, 0.17),
		"shell_light": Color(0.58, 0.50, 0.27), "groove": Color(0.15, 0.12, 0.07), "rim": Color(0.30, 0.25, 0.13),
		"plastron": Color(0.76, 0.68, 0.42), "hat": Color(0.36, 0.3, 0.22), "band": Color(0.24, 0.18, 0.12),
		"patch": Color(0.46, 0.36, 0.22), "pants": Color(0.62, 0.55, 0.38), "pants_patch": Color(0.42, 0.34, 0.22),
		"shoe": Color(0.3, 0.2, 0.12), "mustache": Color(0.78, 0.76, 0.71), "nose": Color(0.22, 0.26, 0.14),
		"pad": Color(0.3, 0.38, 0.2), "thread": Color(0.70, 0.64, 0.48),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.155, 0.15, 0.16), "fur"],
			[Vector3(0, 0.15, 0.045), Vector3(0.13, 0.12, 0.12), "fur_back"],   # 后脑压暗
			[Vector3(0, 0.045, -0.06), Vector3(0.12, 0.06, 0.1), "muzzle"],     # 下颌浅色
			[Vector3(0, 0.075, -0.11), Vector3(0.09, 0.062, 0.075), "muzzle"],  # 短钝喙
			[Vector3(0, 0.095, -0.145), Vector3(0.062, 0.04, 0.045), "beak"],   # 角质上喙
			# 老人斑:贴着头皮的几块深色小斑(只改颜色,几乎不鼓)
			[Vector3(0.05, 0.255, 0.0), Vector3(0.035, 0.012, 0.03), "spot"],
			[Vector3(-0.07, 0.235, 0.05), Vector3(0.03, 0.012, 0.028), "spot"],
			[Vector3(0.0, 0.2, 0.115), Vector3(0.04, 0.03, 0.012), "spot"],
			[Vector3(0.115, 0.17, 0.065), Vector3(0.012, 0.03, 0.03), "spot"],
		],
		"blend": 0.045,
		"material": 2.0,   # 皮革类:大块斑驳,老龟皮不发亮、不发平
		"mouth": {"kind": "line", "pos": Vector3(0, 0.035, -0.17), "width": 0.07},
	},
	"eyes": {"pos": Vector3(0.062, 0.165, -0.13), "size": Vector3(0.036, 0.04, 0.018), "iris": Color(0.42, 0.32, 0.12),
		"pupil": 0, "lid_rest": 0.38, "lashes": false},
	"brows": {"pos": Vector3(0.064, 0.215, -0.14), "color": "mustache", "width": 0.05, "thickness": 0.012},
	"ears": {"kind": "none"},
	"hat": {"kind": "slouch", "pivot": Vector3(0, 0.25, 0.01), "rot": Vector3(-4, 0, 3), "brim": 0.19, "band": "band"},
	"neck": {"base": Vector3(0, 0.55, -0.02), "radius": 0.07, "color": "fur"},
	"body": {"build": "stocky", "coat": "coat", "belly": "coat", "pants": "pants",
		"buttons": 0, "neckwear": "none", "collar": "coat"},
	"arms": {"sleeve": "coat", "cuff": "coat", "material": 6.0},
	"paws": {"color": "fur", "pads": "pad", "fingers": 3, "length": 0.026},
	"legs": {"pants": "pants", "foot": "boot", "shoe": "shoe"},
	# 小尖尾:贴着座面上方往后探出一点,藏在甲缘下(不进座面)
	"tail": {"path": [Vector3(0, 0.5, 0.22), Vector3(0, 0.5, 0.27), Vector3(0, 0.485, 0.31)], "radius": 0.022, "tip_radius": 0.005,
		"color": "fur", "sway_range": Vector2(0.0, 1.0), "sway": 0.06},
	"anim": {"look_pitch_min": -0.45, "blink_speed": 0.62, "die_body_rot": Vector3(-0.05, 0.25, -0.85)},
}

# 背甲:身体局部的椭球帽(绕 +Z 轴取极角 0..SHELL_EDGE),后表面 z ≤ 0.20(坐直不顶靠背柱)
const SHELL_C := Vector3(0, 0.25, 0.0)
const SHELL_R := Vector3(0.235, 0.28, 0.188)
const SHELL_EDGE := 1.3
const SHELL_DOME := 0.006
# 盾片中心(背甲单位圆盘坐标 u = x 向、v = y 向):5 块椎盾 + 每侧 4 块肋盾
const SCUTES := [Vector2(0, -0.62), Vector2(0, -0.31), Vector2(0, 0.0), Vector2(0, 0.31), Vector2(0, 0.62),
	Vector2(0.5, -0.5), Vector2(0.52, -0.17), Vector2(0.52, 0.17), Vector2(0.5, 0.5),
	Vector2(-0.5, -0.5), Vector2(-0.52, -0.17), Vector2(-0.52, 0.17), Vector2(-0.5, 0.5)]
const MARGINALS := 18
# 腹甲:按身体表面投影的盾形片(中心、半宽、半高),中缝 + 三道横缝
const PLASTRON_Y := 0.29
const PLASTRON_HALF := Vector2(0.14, 0.215)
const PLASTRON_SEAMS := [-0.55, -0.05, 0.45]


static func extras(f: MeshForge, part: String, look: Dictionary, pal: Dictionary) -> void:
	match part:
		"head":
			_head(f, look, pal)
		"hat":
			_hat(f, pal)
		"body":
			var shapes := PatronBuilder.body_shapes(look, pal)
			_shell(f, pal)
			_plastron(f, pal, shapes)
			_suspenders(f, pal, shapes)
		"legs":
			_patches(f, pal)


# —— 头:海象胡、眼镜、额纹、颈褶 ——

static func _head(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	var skull := PatronHeadBuilder.skull_shapes(look, pal)
	var c := PatronHeadBuilder.HEAD_CENTER
	# 海象胡:喙下两大撮往两侧垂下,盖住嘴角
	var m: Color = pal["mustache"]
	PatronBuilder.paint(f, pal, "mustache", 0.95, PatronBuilder.FUR)
	f.blob(Vector3(0, 0.05, -0.17), [
		[Vector3(0.026, 0.058, -0.18), Vector3(0.032, 0.02, 0.022), m, "mirror"],
		[Vector3(0.056, 0.045, -0.17), Vector3(0.028, 0.026, 0.022), m, "mirror"],
		[Vector3(0.08, 0.022, -0.152), Vector3(0.02, 0.032, 0.018), m.darkened(0.05), "mirror"],
		[Vector3(0.088, -0.006, -0.138), Vector3(0.013, 0.022, 0.013), m.darkened(0.1), "mirror"],
		[Vector3(0.04, 0.036, -0.184), Vector3(0.016, 0.016, 0.014), m.darkened(0.08), "mirror"],
		[Vector3(0, 0.064, -0.184), Vector3(0.016, 0.015, 0.015), m]], 24, 14, 0.012)
	# 黄铜圆眼镜:细框、鼻梁、往后搭到头侧的镜腿
	PatronBuilder.paint(f, pal, "brass", 0.3, PatronBuilder.METAL, 1.0)
	for side: float in [-1.0, 1.0]:
		var ring := PackedVector3Array()
		var center := Vector3(0.062 * side, 0.165, -0.153)
		for k in 17:
			var a := TAU * k / 16.0
			ring.append(center + Vector3(cos(a) * 0.037, sin(a) * 0.037, -sin(a) * 0.004))
		f.tube(ring, 0.0028, 5)
		var hinge := center + Vector3(0.036 * side, 0.004, 0.004)
		var ear := MeshForge.blob_surface(c, Vector3(0.98 * side, 0.3, 0.2), skull, 0.045) + Vector3(0.004 * side, 0, 0)
		f.tube(PackedVector3Array([hinge, hinge.lerp(ear, 0.5) + Vector3(0.012 * side, 0.004, 0), ear]), 0.0022, 4)
	f.tube(PackedVector3Array([Vector3(-0.026, 0.17, -0.158), Vector3(0, 0.178, -0.166), Vector3(0.026, 0.17, -0.158)]), 0.0026, 4)
	# 额纹:眉上两道浅弧,贴着头皮
	PatronBuilder.paint(f, pal, "fur_back", 0.8, PatronBuilder.LEATHER)
	for k in 2:
		var arc := PackedVector3Array()
		for i in 7:
			var t := i / 6.0 - 0.5
			var d := Vector3(t * 0.9, 0.62 + k * 0.17 + absf(t) * -0.12, -0.78)
			arc.append(MeshForge.blob_surface(c, d, skull, 0.045))
		f.tube(arc, 0.0032, 4)
	# 颈褶:下巴下面两圈松皮
	for k in 2:
		var ring := PackedVector3Array()
		for i in 17:
			var a := TAU * i / 16.0
			ring.append(Vector3(sin(a) * (0.076 - k * 0.004), -0.012 - k * 0.022 + cos(a) * 0.006, cos(a) * (0.072 - k * 0.004) - 0.01))
		f.tube(ring, 0.0075, 5)


static func _hat(f: MeshForge, pal: Dictionary) -> void:
	# 帽冠右侧一块补丁,四角粗针脚
	PatronBuilder.paint(f, pal, "patch", 0.9, PatronBuilder.CLOTH)
	var at := Vector3(0.088, 0.062, -0.035)
	var rot := Vector3(-12, 112, 0)
	f.box(Vector3(0.05, 0.042, 0.006), PatronBuilder.xf(at, rot))
	PatronBuilder.paint(f, pal, "thread", 0.8, PatronBuilder.CLOTH)
	var basis := Basis.from_euler(rot * PI / 180.0, EULER_ORDER_YXZ)
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p: Vector3 = at + basis * Vector3(corner.x * 0.019, corner.y * 0.015, -0.0035)
		f.box(Vector3(0.012, 0.0025, 0.002), PatronBuilder.xf(p, rot + Vector3(0, 0, 45 * corner.x * corner.y)))


# —— 背甲 ——

static func _shell(f: MeshForge, pal: Dictionary) -> void:
	# 椭球帽网格:盾片按最近中心划分(Voronoi),缝里压暗下陷,盾片中心提亮微鼓,带一圈圈生长纹
	var rows := []
	var colors := []
	var light: Color = pal["shell_light"]
	var base: Color = pal["shell"]
	var groove: Color = pal["groove"]
	var na := 16
	var nb := 48
	for j in na + 1:
		var alpha := SHELL_EDGE * j / na
		var row := PackedVector3Array()
		var crow := PackedColorArray()
		for i in nb + 1:
			var beta := TAU * i / nb
			var uv := Vector2(sin(alpha) * cos(beta), sin(alpha) * sin(beta))
			var d1 := 9.0
			var d2 := 9.0
			for s: Vector2 in SCUTES:
				var d := ((uv - s) * Vector2(1.1, 1.0)).length()
				if d < d1:
					d2 = d1
					d1 = d
				elif d < d2:
					d2 = d
			var seam := 1.0 - smoothstep(0.012, 0.055, d2 - d1)
			var unit := Vector3(uv.x, uv.y, cos(alpha))
			var normal := (unit / SHELL_R).normalized()
			var lift := SHELL_DOME * (1.0 - smoothstep(0.0, 0.3, d1)) - 0.004 * seam
			row.append(SHELL_C + unit * SHELL_R + normal * lift)
			var col := light.lerp(base, smoothstep(0.02, 0.26, d1))
			col *= 0.93 + 0.07 * cos(d1 * TAU / 0.075)
			col = col.lerp(groove, seam * 0.85)
			crow.append(Color(col.r, col.g, col.b, 1.0))
		rows.append(row)
		colors.append(crow)
	PatronBuilder.paint(f, pal, "shell", 0.55, PatronBuilder.LEATHER)
	_grid(f, rows, colors, SHELL_C)
	# 甲缘:沿帽口一圈扁圆放样,缘盾之间一道深缝
	var path := PackedVector3Array()
	var ring_colors := PackedColorArray()
	var radii := PackedVector2Array()
	var rim: Color = pal["rim"]
	var stops := [0.0, 0.12, 0.88]
	for k in MARGINALS:
		for s: float in stops:
			var beta := TAU * (k + s) / MARGINALS
			path.append(SHELL_C + Vector3(sin(SHELL_EDGE) * cos(beta) * SHELL_R.x, sin(SHELL_EDGE) * sin(beta) * SHELL_R.y,
				cos(SHELL_EDGE) * SHELL_R.z))
			radii.append(Vector2(0.012, 0.018) if s > 0.0 else Vector2(0.01, 0.016))
			var col := groove if s == 0.0 else (rim if k % 2 == 0 else rim.lerp(light, 0.25))
			ring_colors.append(Color(col.r, col.g, col.b, 1.0))
	path.append(path[0])
	radii.append(radii[0])
	ring_colors.append(ring_colors[0])
	PatronBuilder.paint(f, pal, "rim", 0.55, PatronBuilder.LEATHER)
	f.loft(path, radii, 6, Vector2i(0, 0), Transform3D.IDENTITY, ring_colors, Vector2(-1, -1), Vector3(0, 0, 1))


# —— 腹甲 ——

static func _plastron_point(shapes: Array, n: Vector2, lift: float) -> Vector3:
	# 腹甲单位坐标 n(x ∈ [-1, 1] 横向、y ∈ [-1, 1] 竖向)→ 身体表面上的点再往外抬 lift;下窄上宽的盾形
	var hw := PLASTRON_HALF.x * sqrt(maxf(1.0 - pow(absf(n.y), 3.0), 0.0)) * lerpf(1.0, 0.82, smoothstep(0.0, -1.0, n.y))
	# 从身后远处近乎平行地往前投:外形尺寸基本不随胸腹曲面缩放
	var target := Vector3(n.x * hw, PLASTRON_Y + n.y * PLASTRON_HALF.y, -0.2)
	var from := Vector3(0, PLASTRON_Y, 2.0)
	var d := (target - from).normalized()
	return MeshForge.blob_surface(from, d, shapes, PatronBuilder.BLOB_K) + d * lift


static func _plastron_lift(n: Vector2) -> float:
	var e := maxf(absf(n.x), absf(n.y))
	return 0.0 if e >= 0.999 else 0.004 + 0.011 * (1.0 - pow(e, 3.0))


static func _plastron(f: MeshForge, pal: Dictionary, shapes: Array) -> void:
	var xs := [-1.0, -0.94, -0.78, -0.55, -0.3, -0.1, 0.0, 0.1, 0.3, 0.55, 0.78, 0.94, 1.0]
	var ys := [-1.0, -0.94, -0.8]
	for s: float in PLASTRON_SEAMS:
		ys.append_array([s - 0.09, s, s + 0.09])
	ys.append_array([0.75, 0.94, 1.0])
	ys.sort()
	var base: Color = pal["plastron"]
	var groove: Color = pal["groove"]
	var rows := []
	var colors := []
	for y: float in ys:
		var row := PackedVector3Array()
		var crow := PackedColorArray()
		for x: float in xs:
			var n := Vector2(x, y)
			row.append(_plastron_point(shapes, n, _plastron_lift(n)))
			var seam := 1.0 if x == 0.0 or PLASTRON_SEAMS.has(y) else 0.0
			var col := base.darkened(0.12 * smoothstep(0.6, 1.0, maxf(absf(x), absf(y))))
			col = col.lerp(groove, seam * 0.55)
			crow.append(Color(col.r, col.g, col.b, 1.0))
		rows.append(row)
		colors.append(crow)
	PatronBuilder.paint(f, pal, "plastron", 0.6, PatronBuilder.SMOOTH)
	_grid(f, rows, colors, Vector3(0, PLASTRON_Y, 0.02))


# —— 背带 ——

static func _suspenders(f: MeshForge, pal: Dictionary, shapes: Array) -> void:
	# 从前腰沿腹甲上到肩头,翻过肩塞进背甲上缘;下端铜扣扣在裤腰上
	for side: float in [-1.0, 1.0]:
		var path := PackedVector3Array()
		var from := Vector3(0.07 * side, 0.3, 0.0)
		for i in 10:
			var t := i / 9.0
			var psi := lerpf(2.05, -0.15, t)
			var d := Vector3(lerpf(0.02, 0.32, t) * side, cos(psi), -sin(psi)).normalized()
			var p := MeshForge.blob_surface(from, d, shapes, PatronBuilder.BLOB_K)
			var on_plastron := smoothstep(0.5, 0.42, p.y) * smoothstep(0.03, 0.09, p.y) * smoothstep(0.02, -0.06, p.z)
			path.append(p + d * lerpf(0.007, 0.021, on_plastron))
		PatronBuilder.paint(f, pal, "accent", 0.7, PatronBuilder.LEATHER)
		var radii := PackedVector2Array()
		for i in path.size():
			radii.append(Vector2(0.0045, 0.015))
		f.loft(path, radii, 6, Vector2i(1, 1), Transform3D.IDENTITY, PackedColorArray(), Vector2(-1, -1), Vector3(0, 0, -1))
		# 铜扣:扣在最下端
		PatronBuilder.paint(f, pal, "brass", 0.3, PatronBuilder.METAL, 1.0)
		var clip := path[0] + (path[0] - path[1]).normalized() * 0.004 + Vector3(0, 0, -0.004)
		f.box(Vector3(0.026, 0.02, 0.006), PatronBuilder.xf(clip, Vector3(-12, 0, 0)))
		f.sphere(0.0075, 8, PatronBuilder.xf(clip + Vector3(0, -0.018, 0.002)))


# —— 裤子补丁 ——

static func _patches(f: MeshForge, pal: Dictionary) -> void:
	# 左膝上一块深色补丁、右靴尖一块圆补丁,都带十字针脚
	PatronBuilder.paint(f, pal, "pants_patch", 0.9, PatronBuilder.CLOTH)
	var knee := Vector3(-0.1, 0.561, -0.075)
	f.box(Vector3(0.062, 0.008, 0.055), PatronBuilder.xf(knee, Vector3(-8, 12, 0)))
	PatronBuilder.paint(f, pal, "shoe", 0.7, PatronBuilder.LEATHER)
	var toe := Vector3(0.104, 0.072, -0.252)
	f.cylinder(0.02, 0.02, 0.006, 10, MeshForge.CAPS_BOTH, PatronBuilder.xf(toe, Vector3(-20, 0, 0)))
	PatronBuilder.paint(f, pal, "thread", 0.8, PatronBuilder.CLOTH)
	for k in 3:
		var x := -0.02 + k * 0.02
		f.box(Vector3(0.0025, 0.003, 0.012), PatronBuilder.xf(knee + Vector3(x, 0.005, 0.03), Vector3(-8, 12 + 45, 0)))
		f.box(Vector3(0.0025, 0.003, 0.012), PatronBuilder.xf(knee + Vector3(x, 0.005, -0.03), Vector3(-8, 12 - 45, 0)))


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
