extends RefCounted
# 猪「铁路司炉」:圆脸带腮肉、上翘圆角鼻盘、凹陷椭圆鼻孔、腮红;软三角耳往前下折;蓝白条纹司机帽;
# 牛仔背带工装裤(胸兜、铜扣)、红格衬衫卷袖、红领巾;厚底工靴;小螺旋尾;脸颊一抹煤灰。

const Kit := preload("res://src/world/species/species_fox.gd")   # 衣片工具


const LOOK := {
	"id": "pig",
	"gun_clearance": 0.221,   # 持枪净空(米,已含 Q 版头的放大):按举枪流程实测最小值(含抖耳)再留 ≥4 mm
	"palette": {
		"fur": Color(0.76, 0.47, 0.45), "muzzle": Color(0.80, 0.55, 0.52), "dark": Color(0.45, 0.2, 0.2),
		"coat": Color(0.20, 0.30, 0.48), "accent": Color(0.70, 0.16, 0.14), "shirt": Color(0.62, 0.14, 0.12),
		"hat": Color(0.18, 0.26, 0.44), "cream": Color(0.78, 0.76, 0.7), "pants": Color(0.20, 0.30, 0.48),
		"snout": Color(0.80, 0.55, 0.52), "blush": Color(0.80, 0.42, 0.42), "soot": Color(0.2, 0.16, 0.15),
		"shoe": Color(0.22, 0.13, 0.08), "pad": Color(0.55, 0.3, 0.3), "nose": Color(0.3, 0.12, 0.14),
		"denim_dark": Color(0.15, 0.22, 0.36), "stitch": Color(0.72, 0.52, 0.22),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.17, 0.155, 0.165), "fur"],
			[Vector3(0.09, 0.05, -0.06), Vector3(0.08, 0.066, 0.07), "fur", "mirror"],      # 腮肉
			[Vector3(0.1, 0.08, -0.1), Vector3(0.035, 0.025, 0.02), "blush", "mirror"],     # 腮红
			[Vector3(0, 0.085, -0.13), Vector3(0.05, 0.042, 0.04), "fur"],                  # 鼻盘根
		],
		"blend": 0.04,
		"mouth": {"kind": "smile", "pos": Vector3(0, 0.03, -0.165), "width": 0.06},
	},
	"eyes": {"pos": Vector3(0.068, 0.17, -0.135), "size": Vector3(0.034, 0.038, 0.017), "iris": Color(0.32, 0.22, 0.14),
		"pupil": 0, "lid_rest": 0.12, "lashes": true},
	"brows": {"pos": Vector3(0.068, 0.222, -0.145), "color": "dark"},
	"ears": {"kind": "floppy", "pivot": Vector3(0.12, 0.215, -0.02), "rot": Vector3(-35, 0, -42),
		"size": Vector3(0.05, 0.11, 0.012), "inner": "blush"},
	"hat": {"kind": "conductor", "pivot": Vector3(0, 0.25, 0.0), "rot": Vector3(-10, 0, -6), "radius": 0.13,
		"stripe_a": "hat", "stripe_b": "cream", "visor": "dark"},
	"neck": {"base": Vector3(0, 0.55, -0.02), "radius": 0.08, "color": "fur"},
	# 躯干整体是红格衬衫(格纹材质);工装裤的裤腰、胸兜、背带、铜扣和领巾都在 extras 里按衣片画
	"body": {"build": "round", "coat": "shirt", "belly": "shirt", "pants": "pants", "material": 6.0,
		"buttons": 0, "neckwear": "none", "collar": "shirt"},
	"arms": {"sleeve": "shirt", "cuff": "shirt", "forearm": "fur", "material": 6.0},
	"paws": {"color": "paw", "pads": "pad", "fingers": 3, "length": 0.026},
	"legs": {"pants": "pants", "foot": "boot", "shoe": "shoe"},
	"tail": {"path": [Vector3(0, 0.5, 0.25), Vector3(0.02, 0.53, 0.29), Vector3(-0.01, 0.56, 0.31), Vector3(-0.02, 0.53, 0.33),
		Vector3(0.01, 0.52, 0.34)], "radius": 0.014, "tip_radius": 0.008, "color": "fur", "sway_range": Vector2(0.2, 1.0)},
	"anim": {"look_pitch_min": -0.45, "blink_speed": 1.0},
}


static func extras(f: MeshForge, part: String, look: Dictionary, pal: Dictionary) -> void:
	match part:
		"head":
			_head(f, look, pal)
		"hat":
			# 帽墙正前方一枚铜徽章
			PatronBuilder.paint(f, pal, "brass", 0.3, PatronBuilder.METAL, 1.0)
			f.cylinder(0.017, 0.017, 0.005, 14, MeshForge.CAPS_BOTH, PatronBuilder.xf(Vector3(0, 0.04, -0.15), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.8)))
		"body":
			_body(f, look, pal)


static func _head(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	# 上翘的圆角鼻盘:车削的扁圆台,正面微鼓,两个深色椭圆鼻孔
	var disc := PatronBuilder.xf(Vector3(0, 0.084, -0.148), Vector3(-76, 0, 0), Vector3(1.0, 1.0, 0.8))
	PatronBuilder.paint(f, pal, "snout", 0.5, PatronBuilder.SMOOTH)
	f.lathe(PackedVector2Array([Vector2(0.046, -0.01), Vector2(0.056, 0.03), Vector2(0.056, 0.048), Vector2(0.05, 0.058),
		Vector2(0.026, 0.063), Vector2(0.0, 0.064)]), 22, PackedInt32Array(), disc)
	PatronBuilder.paint(f, pal, "nose", 0.6, PatronBuilder.SMOOTH)
	for side: float in [-1.0, 1.0]:
		f.sphere(1.0, 10, disc * PatronBuilder.xf(Vector3(0.021 * side, 0.0615, 0.0), Vector3(0, 12 * side, 0), Vector3(0.0105, 0.004, 0.0155)))
	# 左颊一抹煤灰:贴着脸的薄贴花,边缘渐隐到皮肤色
	var hc := PatronHeadBuilder.HEAD_CENTER
	var shapes := PatronHeadBuilder.skull_shapes(look, pal)
	var skin := PatronBuilder.color(pal, "fur")
	var soot := PatronBuilder.color(pal, "soot")
	PatronBuilder.paint(f, pal, "fur", 0.85, PatronBuilder.FUR)
	Kit.panel(f, hc, shapes, look["head"].get("blend", 0.04), func(u: float, v: float) -> Vector3:
		return Kit.aim(hc, lerpf(-72.0, -44.0, u) + sin(v * 5.0) * 4.0, lerpf(0.105, 0.05, v) + sin(u * 4.0) * 0.008, 0.17), 6, 4, 0.003,
		func(u: float, v: float) -> Color:
			var e := minf(minf(u, 1.0 - u), minf(v, 1.0 - v)) * 2.0
			return skin.lerp(soot, smoothstep(0.0, 0.7, e) * 0.85), false)


static func _body(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	var c := PatronBuilder.BODY_CENTER
	var k := PatronBuilder.BLOB_K
	var shapes := PatronBuilder.body_shapes(look, pal)
	# 工装裤:裤腰一圈 + 胸兜围嘴(牛仔布,布材质盖住格纹)
	PatronBuilder.paint(f, pal, "pants", 0.85, PatronBuilder.CLOTH)
	Kit.panel(f, c, shapes, k, func(u: float, v: float) -> Vector3:
		var a := u * 360.0
		return Kit.aim(c, a, lerpf(0.215 + 0.025 * cos(deg_to_rad(a)), -0.07, v)), 30, 7, 0.0075, Callable(), true, true)
	Kit.panel(f, c, shapes, k, func(u: float, v: float) -> Vector3:
		var y := lerpf(0.46, 0.2, v)
		return Kit.aim(c, lerpf(-1.0, 1.0, u) * lerpf(25.0, 33.0, v), y), 6, 6, 0.0085)
	# 胸兜:压深一点的牛仔布,外圈一道黄线
	PatronBuilder.paint(f, pal, "denim_dark", 0.85, PatronBuilder.CLOTH)
	Kit.panel(f, c, shapes, k, func(u: float, v: float) -> Vector3:
		return Kit.aim(c, lerpf(-13.0, 13.0, u), lerpf(0.41, 0.31, v) - absf(u - 0.5) * 0.012 * v), 4, 3, 0.012)
	PatronBuilder.paint(f, pal, "stitch", 0.7, PatronBuilder.CLOTH)
	var stitch := PackedVector3Array()
	for p: Vector2 in [Vector2(-11, 0.405), Vector2(-11, 0.32), Vector2(0, 0.31), Vector2(11, 0.32), Vector2(11, 0.405)]:
		stitch.append(Kit.surface_point(c, shapes, k, Kit.aim(c, p.x, p.y), 0.0145))
	f.tube(stitch, 0.0018, 4)
	var bib_edge := PackedVector3Array()
	for i in 7:
		var t := i / 6.0
		bib_edge.append(Kit.surface_point(c, shapes, k, Kit.aim(c, lerpf(-23.0, 23.0, t), 0.448), 0.0105))
	f.tube(bib_edge, 0.0016, 4)
	# 背带:从胸兜上角翻过肩头,在背后交叉成 X 落到裤腰
	PatronBuilder.paint(f, pal, "pants", 0.85, PatronBuilder.CLOTH)
	for side: float in [-1.0, 1.0]:
		Kit.band(f, c, shapes, k, [Vector3(0.07 * side, 0.2, -0.2), Vector3(0.1 * side, 0.3, -0.07), Vector3(0.1 * side, 0.3, 0.06),
			Vector3(0.06 * side, 0.15, 0.2), Vector3(-0.07 * side, -0.03, 0.2)], 5.5, 10, 0.011 if side > 0.0 else 0.0095)
	# 铜扣:背带扣在胸兜两角,裤腰两侧各一颗
	PatronBuilder.paint(f, pal, "brass", 0.28, PatronBuilder.METAL, 1.0)
	for side: float in [-1.0, 1.0]:
		var p := Kit.surface_point(c, shapes, k, Kit.aim(c, 19.0 * side, 0.43), 0.019)
		f.cylinder(0.013, 0.013, 0.007, 12, MeshForge.CAPS_BOTH, PatronBuilder.xf(p, Vector3(80, 18 * side, 0)))
		var hip := Kit.surface_point(c, shapes, k, Kit.aim(c, 84.0 * side, 0.17), 0.011)
		f.cylinder(0.011, 0.011, 0.006, 12, MeshForge.CAPS_BOTH, PatronBuilder.xf(hip, Vector3(0, 0, 90 * side)))
	# 红领巾:一圈盖住脖子根,前面偏右打个结,垂下一个三角
	PatronBuilder.paint(f, pal, "accent", 0.75, PatronBuilder.CLOTH)
	f.lathe(PackedVector2Array([Vector2(0.094, 0.528), Vector2(0.102, 0.548), Vector2(0.1, 0.578), Vector2(0.088, 0.594)]), 20,
		PackedInt32Array(), PatronBuilder.xf(Vector3(0, 0, -0.02)))
	var top := Kit.surface_point(c, shapes, k, Kit.aim(c, 0.0, 0.5), 0.016)
	var tip := Kit.surface_point(c, shapes, k, Kit.aim(c, -4.0, 0.4), 0.014)
	f.loft(PackedVector3Array([Vector3(0.015, 0.545, top.z - 0.004), top.lerp(tip, 0.5) + Vector3(0, 0, -0.004), tip]),
		PackedVector2Array([Vector2(0.007, 0.065), Vector2(0.006, 0.04), Vector2(0.004, 0.006)]), 6, Vector2i(1, 1),
		PatronBuilder.xf(), PackedColorArray(), Vector2(-1, -1), Vector3(0, 0, -1))
	var red := PatronBuilder.color(pal, "accent")
	f.blob(Vector3(0.05, 0.548, -0.112), [[Vector3(0.05, 0.548, -0.112), Vector3(0.022, 0.019, 0.016), red],
		[Vector3(0.075, 0.53, -0.108), Vector3(0.022, 0.012, 0.01), red.darkened(0.1)],
		[Vector3(0.068, 0.522, -0.118), Vector3(0.01, 0.02, 0.008), red.darkened(0.1)]], 12, 8, 0.008)
