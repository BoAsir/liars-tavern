extends RefCounted
# 狐狸「老千绅士」:窄额长尖吻、白颊连成围嘴;礼帽夹在两耳之间、藏青燕尾服、金锦缎背心、奶油领巾、怀表链;
# 蓬松大尾巴从左侧翻过座面垂下,尾尖白;帽带上插一张 A 牌。
# 本文件后半段是「衣片工具」(贴身衣片、背带、贴花):熊、猪、猫的脚本 preload 本文件共用。


const LOOK := {
	"id": "fox",
	"palette": {
		"fur": Color(0.80, 0.40, 0.14), "muzzle": Color(0.80, 0.74, 0.62), "dark": Color(0.18, 0.08, 0.04),
		"coat": Color(0.13, 0.17, 0.30), "accent": Color(0.70, 0.52, 0.22), "vest": Color(0.66, 0.48, 0.18),
		"shirt": Color(0.78, 0.74, 0.64), "hat": Color(0.1, 0.08, 0.08), "band": Color(0.62, 0.16, 0.14),
		"pants": Color(0.12, 0.15, 0.26), "shoe": Color(0.07, 0.06, 0.06), "pad": Color(0.22, 0.1, 0.08),
		"card": Color(0.78, 0.76, 0.7), "lapel": Color(0.07, 0.09, 0.17), "vest_dark": Color(0.42, 0.27, 0.08),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.165, 0.15, 0.16), "fur"],                  # 主颅骨,中心就是头心
			[Vector3(0, 0.13, 0.05), Vector3(0.14, 0.13, 0.12), "fur_back"],            # 后脑压暗一点
			[Vector3(0.085, 0.06, -0.045), Vector3(0.082, 0.062, 0.078), "muzzle", "mirror"],   # 白颊
			[Vector3(0, 0.072, -0.12), Vector3(0.062, 0.05, 0.075), "muzzle"],          # 吻根
			[Vector3(0, 0.02, -0.06), Vector3(0.07, 0.045, 0.07), "muzzle"],            # 下巴连到喉咙的白围嘴
		],
		"blend": 0.04,
		"snout": {"path": [Vector3(0, 0.082, -0.13), Vector3(0, 0.084, -0.2), Vector3(0, 0.086, -0.26)],
			"radii": [Vector2(0.05, 0.046), Vector2(0.034, 0.03), Vector2(0.02, 0.019)], "color": "muzzle"},
		"nose": {"pos": Vector3(0, 0.094, -0.276), "radii": Vector3(0.021, 0.017, 0.016), "color": "nose"},
		"mouth": {"kind": "smirk", "pos": Vector3(0, 0.058, -0.2), "width": 0.062},
	},
	"eyes": {"pos": Vector3(0.064, 0.168, -0.128), "size": Vector3(0.04, 0.046, 0.02), "iris": Color(0.80, 0.52, 0.12),
		"pupil": 0, "lid_rest": 0.18, "lashes": false},
	"brows": {"pos": Vector3(0.064, 0.224, -0.142), "color": "dark"},
	"ears": {"kind": "pointy", "pivot": Vector3(0.135, 0.21, 0.0), "rot": Vector3(0, 0, -28),
		"size": Vector3(0.05, 0.15, 0.02), "inner": "muzzle", "tip": "dark"},
	"hat": {"kind": "top", "pivot": Vector3(0, 0.255, -0.01), "rot": Vector3(-6, 0, 3), "crown": [0.082, 0.21], "brim": 0.118,
		"curl": 0.022, "band": "band"},
	"neck": {"base": Vector3(0, 0.55, -0.02), "radius": 0.075, "color": "muzzle"},
	# 背心、翻领、扣子、领巾、表链都在 extras 里按衣片画(贴着躯干表面、有厚度),这里只留躯干形体
	"body": {"build": "slim", "coat": "coat", "belly": "coat", "pants": "pants", "shirt": "shirt", "vest": "coat",
		"lapels": false, "buttons": 0, "neckwear": "none", "chain": false, "collar": "coat"},
	"arms": {"sleeve": "coat", "cuff": "shirt"},
	"paws": {"color": "dark", "pads": "pad", "fingers": 4, "length": 0.03},
	"legs": {"pants": "pants", "foot": "spats", "shoe": "shoe", "spats": "shirt"},
	"tail": {"path": [Vector3(-0.04, 0.5, 0.24), Vector3(-0.17, 0.55, 0.26), Vector3(-0.29, 0.5, 0.24), Vector3(-0.34, 0.38, 0.22),
		Vector3(-0.35, 0.24, 0.24), Vector3(-0.32, 0.12, 0.3)], "radius": 0.04, "tip_radius": 0.03, "bulge": 0.045,
		"color": "fur", "tip": "muzzle", "tip_from": 0.8, "sway_range": Vector2(0.45, 1.0)},
	"anim": {"look_pitch_min": -0.45, "blink_speed": 1.0},
}


static func extras(f: MeshForge, part: String, look: Dictionary, pal: Dictionary) -> void:
	match part:
		"hat":
			# 帽带上插一张 A 牌(斜插在右侧)
			PatronBuilder.paint(f, pal, "card", 0.6, PatronBuilder.CLOTH)
			f.box(Vector3(0.004, 0.07, 0.048), PatronBuilder.xf(Vector3(0.086, 0.06, 0.02), Vector3(0, -10, -12)))
			PatronBuilder.paint(f, pal, "band", 0.5, PatronBuilder.CLOTH)
			f.box(Vector3(0.005, 0.016, 0.012), PatronBuilder.xf(Vector3(0.087, 0.07, 0.02), Vector3(0, -10, -12)))
		"body":
			_body(f, look, pal)
		"head":
			# 腮边三簇毛:往后下方梳的软尖簇
			PatronBuilder.paint(f, pal, "muzzle", 0.8, PatronBuilder.FUR)
			for side: float in [-1.0, 1.0]:
				for k in 3:
					var root := Vector3(0.12 * side, 0.04 + k * 0.022, -0.04 + k * 0.012)
					var tip := root + Vector3((0.036 - k * 0.008) * side, -0.026 + k * 0.004, 0.02)
					f.loft(PackedVector3Array([root, root.lerp(tip, 0.5) + Vector3(0.003 * side, 0.003, 0), tip]),
						PackedVector2Array([Vector2(0.022, 0.016), Vector2(0.014, 0.011), Vector2(0.005, 0.005)]), 6)


static func _body(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	var c := PatronBuilder.BODY_CENTER
	var k := PatronBuilder.BLOB_K
	var shapes := PatronBuilder.body_shapes(look, pal)
	# 衬衫立领:一圈奶油色盖住脖子根
	PatronBuilder.paint(f, pal, "shirt", 0.7, PatronBuilder.CLOTH)
	f.lathe(PackedVector2Array([Vector2(0.084, 0.53), Vector2(0.09, 0.56), Vector2(0.088, 0.592), Vector2(0.078, 0.598)]), 20,
		PackedInt32Array(), PatronBuilder.xf(Vector3(0, 0, -0.02)))
	# 燕尾服后领:从两侧翻领根绕到脖子后面,后高前低
	PatronBuilder.paint(f, pal, "lapel", 0.45, PatronBuilder.CLOTH)
	var collar := PackedVector3Array()
	var collar_r := PackedVector2Array()
	for i in 11:
		var a := deg_to_rad(lerpf(40.0, 320.0, i / 10.0))
		var back := 0.5 - 0.5 * cos(a)
		collar.append(Vector3(sin(a) * 0.1, 0.548 + 0.02 * back, -cos(a) * 0.098 - 0.02))
		collar_r.append(Vector2(0.018 + 0.012 * back, 0.008))
	f.loft(collar, collar_r, 8)
	# 金锦缎背心:左右两片在胸前合拢,V 领露出衬衫与领巾,下摆两个尖角;右片压左片
	for side: float in [-1.0, 1.0]:
		PatronBuilder.paint(f, pal, "vest", 0.5, PatronBuilder.CLOTH)
		panel(f, c, shapes, k, func(u: float, v: float) -> Vector3:
			var y := lerpf(0.46, lerpf(0.02, 0.11, u), v)
			var a_in := lerpf(22.0, -2.0, clampf((0.46 - y) / 0.2, 0.0, 1.0))
			return aim(c, lerpf(a_in, 46.0, u) * side, y), 6, 10, 0.0065 if side > 0.0 else 0.0055,
			func(u: float, _v: float) -> Color:
				return pal["vest"].lerp(pal["vest_dark"], smoothstep(0.75, 1.0, u)))
	# 背心扣子:合缝处一排三颗铜扣
	PatronBuilder.paint(f, pal, "brass", 0.3, PatronBuilder.METAL, 1.0)
	for i in 3:
		var p := surface_point(c, shapes, k, aim(c, 0.0, 0.26 - i * 0.065), 0.011)
		f.sphere(0.0095, 10, PatronBuilder.xf(p, Vector3.ZERO, Vector3(1.0, 1.0, 0.7)))
	# 怀表链:从中间扣眼垂到右侧口袋,口袋上露出半个表
	var chain := PackedVector3Array()
	for i in 9:
		var t := i / 8.0
		var p := surface_point(c, shapes, k, aim(c, lerpf(1.0, 30.0, t), lerpf(0.2, 0.15, t) - sin(t * PI) * 0.045), 0.0095)
		chain.append(p)
	f.tube(chain, 0.0028, 5)
	var fob := surface_point(c, shapes, k, aim(c, 31.0, 0.155), 0.012)
	f.cylinder(0.014, 0.014, 0.006, 12, MeshForge.CAPS_BOTH, PatronBuilder.xf(fob, Vector3(80, 0, -25)))
	# 背心口袋:两道深金滚边
	PatronBuilder.paint(f, pal, "vest_dark", 0.5, PatronBuilder.CLOTH)
	for side: float in [-1.0, 1.0]:
		panel(f, c, shapes, k, func(u: float, v: float) -> Vector3:
			return aim(c, lerpf(20.0, 38.0, u) * side, lerpf(0.17, 0.155, v) - u * 0.01), 3, 1, 0.0085)
	# 翻领:沿外套前襟从肩头斜到腰,上宽下窄,缎面压暗
	PatronBuilder.paint(f, pal, "lapel", 0.4, PatronBuilder.CLOTH)
	for side: float in [-1.0, 1.0]:
		panel(f, c, shapes, k, func(u: float, v: float) -> Vector3:
			var y := lerpf(0.54, 0.18, v)
			var w := lerpf(24.0, 6.0, v) * (1.0 - 0.35 * smoothstep(0.1, 0.0, v))
			return aim(c, (lerpf(27.0, 47.0, v) + (u - 0.3) * w) * side, y), 3, 8, 0.011)
	# 领巾:领口打一个蓬松的结,往下垂到背心 V 领里,别一颗红宝石别针
	var knot := surface_point(c, shapes, k, aim(c, 0.0, 0.5), 0.0)
	var puff := surface_point(c, shapes, k, aim(c, 0.0, 0.44), 0.0)
	var drop := surface_point(c, shapes, k, aim(c, 0.0, 0.37), 0.0)
	var cream := PatronBuilder.color(pal, "shirt")
	PatronBuilder.paint(f, pal, "shirt", 0.65, PatronBuilder.CLOTH)
	f.blob(Vector3(0, 0.5, knot.z - 0.005), [
		[Vector3(0, 0.548, -0.11), Vector3(0.04, 0.026, 0.026), cream],
		[Vector3(0.022, puff.y + 0.01, puff.z - 0.01), Vector3(0.034, 0.042, 0.024), cream, "mirror"],
		[Vector3(0, drop.y, drop.z - 0.008), Vector3(0.032, 0.04, 0.018), cream.darkened(0.06)],
	], 18, 12, 0.014)
	PatronBuilder.paint(f, pal, "brass", 0.3, PatronBuilder.METAL, 1.0)
	f.cylinder(0.011, 0.011, 0.004, 10, MeshForge.CAPS_BOTH, PatronBuilder.xf(Vector3(0, puff.y + 0.005, puff.z - 0.03), Vector3(90, 0, 0)))
	PatronBuilder.paint(f, pal, "gem", 0.12, PatronBuilder.METAL, 0.6)
	f.sphere(0.0085, 10, PatronBuilder.xf(Vector3(0, puff.y + 0.005, puff.z - 0.034)))
	# 燕尾:从后腰两侧垂到座面外、椅腿外的两片长尾,上宽下尖
	PatronBuilder.paint(f, pal, "coat", 0.85, PatronBuilder.CLOTH)
	for side: float in [-1.0, 1.0]:
		var root := surface_point(c, shapes, k, Vector3(0.55 * side, -0.3, 0.75), -0.01)
		f.loft(PackedVector3Array([root, Vector3(0.22 * side, 0.02, 0.15), Vector3(0.275 * side, -0.1, 0.15),
			Vector3(0.28 * side, -0.2, 0.13), Vector3(0.275 * side, -0.27, 0.11)]),
			PackedVector2Array([Vector2(0.012, 0.06), Vector2(0.01, 0.062), Vector2(0.009, 0.055), Vector2(0.008, 0.04),
			Vector2(0.006, 0.012)]), 8, Vector2i(1, 1), PatronBuilder.xf(), PackedColorArray(), Vector2(-1, -1), Vector3(side, 0, 0))


# —— 衣片工具 ——
# 衣服贴着平滑并集躯干长:从躯干里的原点打射线取表面点,沿法线外推几毫米成一块有厚度的衣片
# (边缘一圈圆角侧壁,像缝起来的布边)。方向参数 aim(原点, 方位角, 高度):方位 0 = 正前方(-Z),正值转向 +X。

static func aim(origin: Vector3, a_deg: float, y: float, r := 0.2) -> Vector3:
	var a := deg_to_rad(a_deg)
	return Vector3(sin(a) * r, y - origin.y, -cos(a) * r)


static func surface_point(origin: Vector3, shapes: Array, k: float, dir: Vector3, off := 0.0) -> Vector3:
	# 表面点沿法线外推 off(法线由旁边两条射线的落点叉乘得到)
	var p := MeshForge.blob_surface(origin, dir, shapes, k)
	if off == 0.0:
		return p
	var d := dir.normalized()
	var side := d.cross(Vector3.UP if absf(d.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := side.cross(d).normalized()
	var a := MeshForge.blob_surface(origin, d + side * 0.02, shapes, k) - p
	var b := MeshForge.blob_surface(origin, d + up * 0.02, shapes, k) - p
	var n := a.cross(b).normalized()
	if n.dot(p - origin) < 0.0:
		n = -n
	return p + n * off


static func panel(f: MeshForge, origin: Vector3, shapes: Array, k: float, dir: Callable, nu: int, nv: int, off := 0.006,
		colors := Callable(), rim := true, wrap := false) -> Array:
	# 贴身衣片:dir(u, v) 给 (u, v) ∈ [0,1]² 的射线方向;colors(u, v) 可选逐顶点颜色;
	# rim 为 false 时不做侧壁(贴花);wrap 时 u 首尾相接(绕一圈的腰带、裤腰)。返回 [外表面点行, 法线行]
	var surf := []
	for j in nv + 1:
		var row := PackedVector3Array()
		for i in nu + 1:
			row.append(MeshForge.blob_surface(origin, dir.call(float(i) / nu, float(j) / nv), shapes, k))
		surf.append(row)
	var normals := _grid_normals(surf, origin, wrap)
	var outer := []
	var cols := []
	for j in nv + 1:
		var row := PackedVector3Array()
		var crow := PackedColorArray()
		for i in nu + 1:
			row.append(surf[j][i] + normals[j][i] * off)
			if colors.is_valid():
				var col: Color = colors.call(float(i) / nu, float(j) / nv)
				crow.append(Color(col.r, col.g, col.b, 1.0))
		outer.append(row)
		cols.append(crow)
	sheet(f, outer, normals, cols if colors.is_valid() else [])
	if rim:
		_rim(f, surf, normals, off, wrap, cols if colors.is_valid() else [])
	return [outer, normals]


static func sheet(f: MeshForge, rows: Array, normals: Array, colors := []) -> void:
	# 相邻两行点连成三角带;绕序按法线自动定(Godot 正面为顺时针)
	var pts := PackedVector3Array()
	var nrm := PackedVector3Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var stride: int = rows[0].size()
	for j in rows.size():
		pts.append_array(rows[j])
		nrm.append_array(normals[j])
		if not colors.is_empty():
			col.append_array(colors[j])
	for j in rows.size() - 1:
		for i in stride - 1:
			var a := j * stride + i
			_tri(idx, pts, nrm, a, a + 1, a + stride)
			_tri(idx, pts, nrm, a + 1, a + stride + 1, a + stride)
	f._append(pts, nrm, idx, Transform3D.IDENTITY, col)


static func _tri(idx: PackedInt32Array, pts: PackedVector3Array, nrm: PackedVector3Array, a: int, b: int, c: int) -> void:
	var g := (pts[b] - pts[a]).cross(pts[c] - pts[a])
	if g.length_squared() < 1e-14:
		return
	if g.dot(nrm[a] + nrm[b] + nrm[c]) > 0.0:
		idx.append_array([a, c, b])
	else:
		idx.append_array([a, b, c])


static func _grid_normals(rows: Array, origin: Vector3, wrap: bool) -> Array:
	var nv := rows.size() - 1
	var nu: int = rows[0].size() - 1
	var out := []
	for j in nv + 1:
		var row := PackedVector3Array()
		for i in nu + 1:
			var i0 := maxi(i - 1, 0)
			var i1 := mini(i + 1, nu)
			if wrap:
				i0 = nu - 1 if i == 0 else i - 1
				i1 = 1 if i == nu else i + 1
			var du: Vector3 = rows[j][i1] - rows[j][i0]
			var dv: Vector3 = rows[mini(j + 1, nv)][i] - rows[maxi(j - 1, 0)][i]
			var n := du.cross(dv)
			var p: Vector3 = rows[j][i]
			n = n.normalized() if n.length_squared() > 1e-12 else (p - origin).normalized()
			if n.dot(p - origin) < 0.0:
				n = -n
			row.append(n)
		out.append(row)
	return out


static func _rim(f: MeshForge, surf: Array, normals: Array, off: float, wrap: bool, colors: Array) -> void:
	# 衣片边缘的圆角侧壁:外表面 → 半高外鼓 → 埋进躯干
	var nv := surf.size() - 1
	var nu: int = surf[0].size() - 1
	var loops := []   # 每条环:[[j, i, 内侧邻点 j, i], ...]
	if wrap:
		var top := []
		var bottom := []
		for i in nu + 1:
			top.append([0, i, 1, i])
			bottom.append([nv, i, nv - 1, i])
		loops = [top, bottom]
	else:
		var ring := []
		for i in nu + 1:
			ring.append([0, i, 1, i])
		for j in range(1, nv + 1):
			ring.append([j, nu, j, nu - 1])
		for i in range(nu - 1, -1, -1):
			ring.append([nv, i, nv - 1, i])
		for j in range(nv - 1, -1, -1):
			ring.append([j, 0, j, 1])
		loops = [ring]
	for ring: Array in loops:
		var r0 := PackedVector3Array()
		var r1 := PackedVector3Array()
		var r2 := PackedVector3Array()
		var n0 := PackedVector3Array()
		var n1 := PackedVector3Array()
		var n2 := PackedVector3Array()
		var c0 := PackedColorArray()
		for e: Array in ring:
			var p: Vector3 = surf[e[0]][e[1]]
			var n: Vector3 = normals[e[0]][e[1]]
			var o: Vector3 = p - surf[e[2]][e[3]]
			o = o - n * o.dot(n)
			o = o.normalized() if o.length_squared() > 1e-12 else n
			r0.append(p + n * off)
			r1.append(p + n * off * 0.4 + o * off * 0.45)
			r2.append(p - n * 0.004 + o * off * 0.25)
			n0.append((n + o * 0.7).normalized())
			n1.append((o + n * 0.3).normalized())
			n2.append(o)
			if not colors.is_empty():
				c0.append(colors[e[0]][e[1]])
		sheet(f, [r0, r1, r2], [n0, n1, n2], [] if colors.is_empty() else [c0, c0, c0])


static func band(f: MeshForge, origin: Vector3, shapes: Array, k: float, dirs: Array, half_width_deg: float, nv: int,
		off := 0.006, colors := Callable(), rim := true, taper := 0.0) -> Array:
	# 背带、毛巾、斑纹这类贴身长条:沿一串控制方向(折线插值)走,左右各 half_width_deg 宽;
	# taper > 0 时两头收尖(虎斑纹),rim 为 false 时是不带侧壁的贴花
	var count := dirs.size()
	return panel(f, origin, shapes, k, func(u: float, v: float) -> Vector3:
		var s := v * (count - 1)
		var i := mini(int(s), count - 2)
		var d: Vector3 = (dirs[i] as Vector3).normalized().lerp((dirs[i + 1] as Vector3).normalized(), s - i).normalized()
		var tangent: Vector3 = (dirs[i + 1] as Vector3).normalized() - (dirs[i] as Vector3).normalized()
		var side := d.cross(tangent).normalized()
		var w := deg_to_rad(half_width_deg) * lerpf(1.0, maxf(sin(v * PI), 0.12), taper)
		return d + side * w * (u * 2.0 - 1.0), 2, nv, off, colors, rim)
