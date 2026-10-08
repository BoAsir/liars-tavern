extends RefCounted
# 猫「独行枪手」:灰虎斑,额头 M 纹、白吻白胸、w 形嘴、胡须、粉三角鼻、竖瞳;三角耳从牛仔帽的耳洞穿出;
# 皮背心、浅蓝衬衫、青色方巾、枪带和右胯枪套;牛仔裤、皮护腿、尖头靴配马刺;细长虎斑尾从缝里穿出垂在椅后。

const Kit := preload("res://src/world/species/species_fox.gd")   # 衣片工具


const LOOK := {
	"id": "cat",
	"palette": {
		"fur": Color(0.36, 0.37, 0.42), "muzzle": Color(0.80, 0.79, 0.77), "dark": Color(0.1, 0.1, 0.12),
		"coat": Color(0.48, 0.62, 0.72), "accent": Color(0.20, 0.52, 0.58), "stripe": Color(0.15, 0.15, 0.18),
		"vest": Color(0.40, 0.23, 0.11), "shirt": Color(0.48, 0.62, 0.72), "hat": Color(0.3, 0.2, 0.12),
		"band": Color(0.2, 0.52, 0.58), "pants": Color(0.18, 0.26, 0.4), "shoe": Color(0.3, 0.17, 0.09),
		"nose": Color(0.72, 0.42, 0.46), "pad": Color(0.6, 0.38, 0.42), "leather": Color(0.26, 0.15, 0.08),
		"chaps": Color(0.46, 0.29, 0.15), "stitch": Color(0.76, 0.62, 0.42), "pearl": Color(0.78, 0.77, 0.72),
		"grip": Color(0.32, 0.18, 0.08), "rawhide": Color(0.62, 0.47, 0.28),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.16, 0.145, 0.155), "fur"],
			[Vector3(0.042, 0.066, -0.118), Vector3(0.056, 0.044, 0.052), "muzzle", "mirror"],   # 白吻两瓣
			[Vector3(0, 0.035, -0.1), Vector3(0.056, 0.038, 0.05), "muzzle"],                    # 下巴
			[Vector3(0, 0.0, -0.05), Vector3(0.06, 0.035, 0.06), "muzzle"],                      # 白喉
		],
		"blend": 0.035,
		"nose": {"pos": Vector3(0, 0.092, -0.168), "radii": Vector3(0.016, 0.011, 0.01), "color": "nose"},
		"mouth": {"kind": "w", "pos": Vector3(0, 0.06, -0.165), "width": 0.05, "thickness": 0.0026},
		"whiskers": true, "whisker_color": "muzzle", "whisker_root": Vector3(0.05, 0.075, -0.155),
	},
	"eyes": {"pos": Vector3(0.062, 0.162, -0.13), "size": Vector3(0.042, 0.046, 0.02), "iris": Color(0.62, 0.68, 0.22),
		"pupil": 1, "lid_rest": 0.2, "lashes": false},
	"brows": {"pos": Vector3(0.064, 0.215, -0.14), "color": "stripe", "width": 0.05, "thickness": 0.009},
	"ears": {"kind": "cat", "pivot": Vector3(0.1, 0.25, 0.0), "rot": Vector3(0, 0, -14),
		"size": Vector3(0.058, 0.1, 0.02), "inner": "nose"},
	# 帽子往前挪 4 mm:后檐离头心 ≤0.22
	"hat": {"kind": "cowboy", "pivot": Vector3(0, 0.255, 0.006), "rot": Vector3(-6, 0, 6), "brim": 0.24, "band": "band"},
	"neck": {"base": Vector3(0, 0.55, -0.02), "radius": 0.072, "color": "muzzle"},
	# 躯干是浅蓝衬衫(胸口 V 字露白毛);皮背心、方巾、枪带都在 extras 里按衣片画
	"body": {"build": "slim", "coat": "shirt", "belly": "shirt", "pants": "pants", "vest": "shirt", "shirt": "muzzle",
		"buttons": 0, "neckwear": "none", "collar": "shirt"},
	"arms": {"sleeve": "shirt", "cuff": "shirt"},
	"paws": {"color": "fur", "pads": "pad", "fingers": 4, "length": 0.03},
	"legs": {"pants": "pants", "foot": "cowboy", "shoe": "shoe"},
	"tail": {"path": [Vector3(0, 0.5, 0.25), Vector3(0, 0.5, 0.34), Vector3(0, 0.48, 0.42), Vector3(0.01, 0.34, 0.46),
		Vector3(0.0, 0.2, 0.45), Vector3(-0.02, 0.12, 0.42), Vector3(-0.04, 0.14, 0.38)], "radius": 0.022, "tip_radius": 0.015,
		"color": "fur", "tip": "stripe", "tip_from": 0.85, "sway_range": Vector2(0.4, 1.0)},
	"anim": {"look_pitch_min": -0.45, "blink_speed": 1.0},
}

# 虎斑纹:头上的贴花条(方位角°, 高度),半宽°
const HEAD_STRIPES := [
	[[Vector2(0, 0.192), Vector2(0, 0.252)], 3.2],                                     # 额头 M 纹中线
	[[Vector2(8, 0.2), Vector2(12, 0.25)], 2.6, "mirror"],                             # M 纹内侧两笔
	[[Vector2(47, 0.152), Vector2(65, 0.142), Vector2(84, 0.126)], 4.2, "mirror"],     # 颊纹(眼角往后)
	[[Vector2(52, 0.108), Vector2(70, 0.098), Vector2(88, 0.086)], 3.6, "mirror"],
	[[Vector2(96, 0.205), Vector2(130, 0.21), Vector2(166, 0.204)], 4.6, "mirror"],    # 后脑三道横纹
	[[Vector2(100, 0.152), Vector2(134, 0.152), Vector2(168, 0.146)], 4.6, "mirror"],
	[[Vector2(106, 0.098), Vector2(140, 0.092), Vector2(170, 0.086)], 4.2, "mirror"],
	[[Vector2(180, 0.215), Vector2(180, 0.06)], 3.6],                                  # 后颈中线
]


static func extras(f: MeshForge, part: String, look: Dictionary, pal: Dictionary) -> void:
	match part:
		"head":
			_head(f, look, pal)
		"hat":
			_ear_rings(f, look, pal)
		"body":
			_body(f, look, pal)
		"legs":
			_legs(f, look, pal)


static func _head(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	var hc := PatronHeadBuilder.HEAD_CENTER
	var shapes := PatronHeadBuilder.skull_shapes(look, pal)
	var k: float = look["head"].get("blend", 0.035)
	var fur := PatronBuilder.color(pal, "fur")
	var stripe := PatronBuilder.color(pal, "stripe")
	PatronBuilder.paint(f, pal, "stripe", 0.8, PatronBuilder.FUR)
	var soft := func(u: float, _v: float) -> Color:
		return fur.lerp(stripe, smoothstep(0.0, 0.5, minf(u, 1.0 - u)) * 0.95)
	for s: Array in HEAD_STRIPES:
		for side: float in ([-1.0, 1.0] if s.size() > 2 else [1.0]):
			var dirs := []
			for p: Vector2 in s[0]:
				dirs.append(Kit.aim(hc, p.x * side, p.y, 0.16))
			Kit.band(f, hc, shapes, k, dirs, s[1], 3 * (dirs.size() - 1), 0.0022, soft, false, 0.85)


static func _ear_rings(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	# 耳洞皮圈:每只耳朵沿耳廓一圈,找它穿出帽子(帽冠墙或帽檐)的高度,在那里缝一圈皮环;
	# 前后放宽 1 cm,抖耳时耳朵也不碰圈
	var hat: Dictionary = look["hat"]
	var e: Dictionary = look["ears"]
	var to_hat_base := MeshForge.xf(hat["pivot"], hat["rot"]).affine_inverse()
	PatronBuilder.paint(f, pal, "rawhide", 0.6, PatronBuilder.LEATHER)
	for side: float in [-1.0, 1.0]:
		var pivot: Vector3 = e["pivot"]
		var rot: Vector3 = e["rot"]
		var to_hat := to_hat_base * MeshForge.xf(Vector3(pivot.x * side, pivot.y, pivot.z), Vector3(rot.x, rot.y * side, rot.z * side))
		var ring := PackedVector3Array()
		for i in 17:
			var t := TAU * i / 16.0
			var h := 0.09
			while h > -0.02 and not _in_cowboy_hat(to_hat * _ear_point(t, h, 0.0)):
				h -= 0.004
			ring.append(to_hat * _ear_point(t, h + 0.004, 0.006))
		f.loft(ring, PackedVector2Array(Array(range(17)).map(func(_i: int) -> Vector2: return Vector2(0.0055, 0.0065))),
			6, Vector2i(0, 0))


static func _ear_point(t: float, h: float, grow: float) -> Vector3:
	# 猫耳(PatronHeadBuilder 的 cat 款)在耳局部高度 h 处截面上角度 t 的点;z 方向放宽 1 cm 并前移 6 mm 盖住抖耳
	var s := clampf((h + 0.02) / 0.065, 0.0, 1.0)
	var wx := lerpf(0.058, 0.0406, s) if h < 0.045 else lerpf(0.0406, 0.004, (h - 0.045) / 0.055)
	var wz := lerpf(0.02, 0.015, s) if h < 0.045 else lerpf(0.015, 0.003, (h - 0.045) / 0.055)
	return Vector3(cos(t) * (wx + grow), h, sin(t) * (wz + grow + 0.01) - 0.006)


static func _in_cowboy_hat(p: Vector3) -> bool:
	# PatronHatBuilder._cowboy 实体的近似:帽冠车削轮廓 + 两侧卷起的帽檐
	var rc := Vector2(p.x, p.z / 1.08).length()
	var crown := [Vector2(0.0, 0.105), Vector2(0.06, 0.1), Vector2(0.12, 0.09), Vector2(0.14, 0.075)]
	if p.y >= -0.006 and p.y <= 0.14:
		for i in 3:
			if p.y <= crown[i + 1].x:
				var r: float = lerpf(crown[i].y, crown[i + 1].y, clampf((p.y - crown[i].x) / (crown[i + 1].x - crown[i].x), 0.0, 1.0))
				if rc < r:
					return true
				break
	var r0 := Vector2(p.x, p.z / 0.86).length()
	if r0 < 0.08 or r0 > 0.245:
		return false
	var lean := pow(absf(p.x) / maxf(r0, 1e-5), 1.6)
	var edge := clampf((r0 - 0.1) / 0.14, 0.0, 1.0)
	var lift := (0.075 if p.x > 0.0 else 0.06) * lean * edge * edge - 0.012 * (1.0 - lean) * edge * edge
	return absf(p.y - lift) < 0.008


static func _body(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	var c := PatronBuilder.BODY_CENTER
	var k := PatronBuilder.BLOB_K
	var shapes := PatronBuilder.body_shapes(look, pal)
	# 衬衫扣子:敞开的皮背心中间一排珍珠扣
	PatronBuilder.paint(f, pal, "pearl", 0.3, PatronBuilder.SMOOTH)
	for i in 4:
		var p := Kit.surface_point(c, shapes, k, Kit.aim(c, 0.0, 0.33 - i * 0.065), 0.004)
		f.sphere(0.0065, 6, PatronBuilder.xf(p, Vector3.ZERO, Vector3(1.0, 1.0, 0.6)))
	# 皮背心:前面两片敞开(露出衬衫和白胸),袖窿、尖下摆;后片整片
	for side: float in [-1.0, 1.0]:
		PatronBuilder.paint(f, pal, "vest", 0.6, PatronBuilder.LEATHER)
		Kit.panel(f, c, shapes, k, func(u: float, v: float) -> Vector3:
			var y := lerpf(0.5, lerpf(0.04, 0.1, u), v)
			var a_in := lerpf(17.0, 10.0, clampf((0.5 - y) / 0.4, 0.0, 1.0))
			var a_out := lerpf(50.0, 100.0, smoothstep(0.44, 0.33, y))
			return Kit.aim(c, lerpf(a_in, a_out, u) * side, y), 6, 10, 0.0075)
	PatronBuilder.paint(f, pal, "vest", 0.6, PatronBuilder.LEATHER)
	Kit.panel(f, c, shapes, k, func(u: float, v: float) -> Vector3:
		var a := lerpf(100.0, 260.0, u)
		var top := lerpf(0.53, 0.33, smoothstep(45.0, 78.0, absf(a - 180.0)))
		return Kit.aim(c, a, lerpf(top, 0.1, v)), 10, 8, 0.0065)
	# 背心前襟缝线 + 两颗银扣花
	PatronBuilder.paint(f, pal, "stitch", 0.7, PatronBuilder.CLOTH)
	for side: float in [-1.0, 1.0]:
		var edge := PackedVector3Array()
		for i in 9:
			var y := lerpf(0.49, 0.06, i / 8.0)
			var a_in := lerpf(17.0, 10.0, clampf((0.5 - y) / 0.4, 0.0, 1.0))
			edge.append(Kit.surface_point(c, shapes, k, Kit.aim(c, (a_in + 3.0) * side, y), 0.0102))
		f.tube(edge, 0.0016, 4)
	PatronBuilder.paint(f, pal, "silver", 0.25, PatronBuilder.METAL, 1.0)
	for side: float in [-1.0, 1.0]:
		var p := Kit.surface_point(c, shapes, k, Kit.aim(c, 24.0 * side, 0.3), 0.011)
		f.cylinder(0.012, 0.013, 0.005, 10, MeshForge.CAPS_BOTH, PatronBuilder.xf(p, Vector3(90 - 8, 0, -24 * side)))
	# 枪带:斜挎在腰上,右胯低;背后一排铜子弹,正面银扣
	PatronBuilder.paint(f, pal, "leather", 0.55, PatronBuilder.LEATHER)
	Kit.panel(f, c, shapes, k, func(u: float, v: float) -> Vector3:
		var a := u * 360.0
		var y := 0.075 - 0.035 * sin(deg_to_rad(a))
		return Kit.aim(c, a, y + lerpf(0.022, -0.022, v)), 22, 1, 0.009, Callable(), true, true)
	PatronBuilder.paint(f, pal, "brass", 0.3, PatronBuilder.METAL, 1.0)
	for i in 8:
		var a := -165.0 + i * 14.0
		var p := Kit.surface_point(c, shapes, k, Kit.aim(c, a, 0.075 - 0.035 * sin(deg_to_rad(a))), 0.0165)
		f.cylinder(0.005, 0.0055, 0.024, 6, MeshForge.CAPS_TOP, PatronBuilder.xf(p))
	var buckle := Kit.surface_point(c, shapes, k, Kit.aim(c, -6.0, 0.075 + 0.0037), 0.0175)
	PatronBuilder.paint(f, pal, "silver", 0.25, PatronBuilder.METAL, 1.0)
	f.box(Vector3(0.046, 0.038, 0.006), PatronBuilder.xf(buckle, Vector3(-12, 6, 4)))
	PatronBuilder.paint(f, pal, "leather", 0.55, PatronBuilder.LEATHER)
	f.box(Vector3(0.03, 0.022, 0.006), PatronBuilder.xf(buckle + Vector3(0, 0, -0.002), Vector3(-12, 6, 4)))
	# 青色方巾:一圈盖住脖子根,前面垂一个三角,结打在脑后
	PatronBuilder.paint(f, pal, "accent", 0.75, PatronBuilder.CLOTH)
	f.lathe(PackedVector2Array([Vector2(0.084, 0.528), Vector2(0.092, 0.55), Vector2(0.09, 0.58), Vector2(0.08, 0.595)]), 20,
		PackedInt32Array(), PatronBuilder.xf(Vector3(0, 0, -0.02)))
	var top := Kit.surface_point(c, shapes, k, Kit.aim(c, 0.0, 0.53), 0.016)
	var mid := Kit.surface_point(c, shapes, k, Kit.aim(c, 0.0, 0.49), 0.012)
	var tip := Kit.surface_point(c, shapes, k, Kit.aim(c, 0.0, 0.445), 0.01)
	f.loft(PackedVector3Array([Vector3(0, 0.55, top.z - 0.004), top, mid, tip]),
		PackedVector2Array([Vector2(0.006, 0.08), Vector2(0.006, 0.068), Vector2(0.005, 0.04), Vector2(0.004, 0.006)]), 6, Vector2i(1, 1),
		PatronBuilder.xf(), PackedColorArray(), Vector2(-1, -1), Vector3(0, 0, -1))
	var teal := PatronBuilder.color(pal, "accent")
	f.blob(Vector3(0, 0.56, 0.072), [[Vector3(0, 0.56, 0.072), Vector3(0.02, 0.018, 0.014), teal],
		[Vector3(0.018, 0.54, 0.078), Vector3(0.012, 0.022, 0.006), teal.darkened(0.12), "mirror"]], 10, 6, 0.008)


static func _legs(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	for side: float in [-1.0, 1.0]:
		var x := 0.1 * side
		# 皮护腿:从大腿前段包到靴筒,外侧一排流苏
		PatronBuilder.paint(f, pal, "chaps", 0.6, PatronBuilder.LEATHER)
		var path := PackedVector3Array([Vector3(x, 0.49, -0.05), Vector3(x, 0.49, -0.12), Vector3(x * 1.02, 0.38, -0.155),
			Vector3(x * 1.04, 0.2, -0.16), Vector3(x * 1.04, 0.165, -0.158)])
		f.loft(path, PackedVector2Array([Vector2(0.077, 0.075), Vector2(0.068, 0.066), Vector2(0.062, 0.06), Vector2(0.057, 0.056),
			Vector2(0.058, 0.057)]), 10, Vector2i(1, 1), PatronBuilder.xf(), PackedColorArray(), Vector2(-1, -1), Vector3(0, 0, -1))
		for i in 5:
			var t := (i + 0.5) / 5.0
			var p := path[2].lerp(path[3], t)
			var r := lerpf(0.062, 0.057, t)
			var root := p + Vector3(r * side, 0, 0)
			f.tube(PackedVector3Array([root, root + Vector3(0.02 * side, -0.012, 0.004)]), 0.0035, 4)
		# 尖头靴:鞋头往前收尖,高跟,马刺(脚踝皮带 + 刺杆 + 星形刺轮)
		var at := Vector3(x * 1.04, 0.0, -0.17)
		PatronBuilder.paint(f, pal, "shoe", 0.45, PatronBuilder.LEATHER)
		f.loft(PackedVector3Array([at + Vector3(0, 0.036, -0.07), at + Vector3(0, 0.032, -0.11), at + Vector3(0, 0.034, -0.138)]),
			PackedVector2Array([Vector2(0.033, 0.042), Vector2(0.021, 0.026), Vector2(0.007, 0.008)]), 10, Vector2i(0, 1))
		PatronBuilder.paint(f, pal, "sole", 0.8, PatronBuilder.LEATHER)
		f.box(Vector3(0.062, 0.032, 0.05), PatronBuilder.xf(at + Vector3(0, 0.016, 0.048)))
		PatronBuilder.paint(f, pal, "leather", 0.55, PatronBuilder.LEATHER)
		f.lathe(PackedVector2Array([Vector2(0.053, -0.006), Vector2(0.056, 0.0), Vector2(0.053, 0.006)]), 10, PackedInt32Array(),
			PatronBuilder.xf(at + Vector3(0, 0.07, 0.0), Vector3(-14, 0, 0)))
		PatronBuilder.paint(f, pal, "silver", 0.3, PatronBuilder.METAL, 1.0)
		var hub := at + Vector3(0, 0.06, 0.098)
		f.tube(PackedVector3Array([at + Vector3(0, 0.062, 0.05), hub]), 0.003, 5)
		f.cylinder(0.007, 0.007, 0.004, 6, MeshForge.CAPS_BOTH, PatronBuilder.xf(hub, Vector3(0, 0, 90)))
		for j in 6:
			f.cylinder(0.0, 0.0028, 0.016, 4, MeshForge.CAPS_BOTTOM, PatronBuilder.xf(hub, Vector3(j * 60.0, 0, 0)) * PatronBuilder.xf(Vector3(0, 0.008, 0)))
	# 右胯枪套:搭在大腿外侧,顺着大腿朝前,露出木枪柄
	var leather := PatronBuilder.color(pal, "leather")
	PatronBuilder.paint(f, pal, "leather", 0.55, PatronBuilder.LEATHER)
	f.blob(Vector3(0.197, 0.525, 0.02), [[Vector3(0.195, 0.535, 0.07), Vector3(0.017, 0.038, 0.042), leather],
		[Vector3(0.198, 0.52, 0.005), Vector3(0.015, 0.028, 0.045), leather],
		[Vector3(0.2, 0.51, -0.045), Vector3(0.013, 0.02, 0.026), leather.darkened(0.1)]], 12, 8, 0.012)
	PatronBuilder.paint(f, pal, "stitch", 0.7, PatronBuilder.CLOTH)
	f.tube(PackedVector3Array([Vector3(0.213, 0.56, 0.085), Vector3(0.214, 0.53, 0.02), Vector3(0.214, 0.515, -0.04)]), 0.0015, 4)
	PatronBuilder.paint(f, pal, "grip", 0.5, PatronBuilder.LEATHER)
	f.loft(PackedVector3Array([Vector3(0.196, 0.56, 0.1), Vector3(0.198, 0.582, 0.122), Vector3(0.2, 0.598, 0.13)]),
		PackedVector2Array([Vector2(0.012, 0.016), Vector2(0.011, 0.017), Vector2(0.01, 0.016)]), 8)
	PatronBuilder.paint(f, pal, "brass", 0.3, PatronBuilder.METAL, 1.0)
	f.sphere(0.009, 8, PatronBuilder.xf(Vector3(0.2, 0.6, 0.131)))
	_tail_stripes(f, look, pal)


static func _tail_stripes(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	# 尾巴虎斑环:沿 LOOK 尾巴同一条折线密采样,半径大 1.5 mm 的外套一层,逐圈颜色画环纹;
	# 摆动权重按同一条折线的长度比例算,和底下的尾巴严丝合缝
	var t: Dictionary = look["tail"]
	var src := PackedVector3Array(t["path"])
	var n := src.size()
	var base: float = t["radius"]
	var tip_r: float = t["tip_radius"]
	var fur := PatronBuilder.color(pal, "fur")
	var stripe := PatronBuilder.color(pal, "stripe")
	var path := PackedVector3Array()
	var radii := PackedVector2Array()
	var colors := PackedColorArray()
	var length := 0.0
	for i in n - 1:
		var seg := src[i].distance_to(src[i + 1])
		var steps := maxi(int(ceil(seg / 0.02)), 1)
		for j in steps + (1 if i == n - 2 else 0):
			var u := float(j) / steps
			var s := (i + u) / (n - 1)
			var l := length + seg * u
			path.append(src[i].lerp(src[i + 1], u))
			var r := lerpf(base, tip_r, s) + 0.0015
			radii.append(Vector2(r, r))
			var dark: bool = s >= t.get("tip_from", 2.0) or (l > 0.07 and fposmod(l, 0.062) < 0.024)
			var col := stripe if dark else fur
			colors.append(Color(col.r, col.g, col.b, 1.0))
		length += seg
	PatronBuilder.paint(f, pal, "fur", 0.75, PatronBuilder.FUR)
	f.loft(path, radii, 8, Vector2i(1, 1), Transform3D.IDENTITY, colors, t.get("sway_range", Vector2(0.35, 1.0)))
