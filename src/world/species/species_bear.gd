extends RefCounted
# 熊「酒馆老板」:宽扁头、短圆吻、圆三角鼻;圆杯耳在圆顶礼帽檐下;酒红丝绒背心、奶油衬衫卷袖加红袖箍、
# 深棕蝴蝶结、怀表链、大圆肚;格纹裤、光脚;左肩搭一条红条纹吧台毛巾。

const Kit := preload("res://src/world/species/species_fox.gd")   # 衣片工具


const LOOK := {
	"id": "bear",
	"palette": {
		"fur": Color(0.36, 0.21, 0.11), "muzzle": Color(0.66, 0.50, 0.34), "dark": Color(0.12, 0.07, 0.04),
		"coat": Color(0.42, 0.11, 0.09), "accent": Color(0.30, 0.16, 0.08), "vest": Color(0.42, 0.11, 0.09),
		"shirt": Color(0.80, 0.74, 0.62), "hat": Color(0.1, 0.08, 0.07), "band": Color(0.42, 0.11, 0.09),
		"pants": Color(0.46, 0.36, 0.22), "armband": Color(0.62, 0.12, 0.1), "towel": Color(0.78, 0.74, 0.66),
		"stripe": Color(0.62, 0.12, 0.1), "pad": Color(0.2, 0.12, 0.08), "vest_back": Color(0.26, 0.08, 0.07),
		"piping": Color(0.30, 0.06, 0.05),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.18, 0.15, 0.165), "fur"],
			[Vector3(0.1, 0.06, -0.04), Vector3(0.075, 0.062, 0.075), "fur", "mirror"],    # 胖腮
			[Vector3(0, 0.065, -0.125), Vector3(0.085, 0.062, 0.072), "muzzle"],           # 短圆吻
		],
		"blend": 0.045,
		"nose": {"pos": Vector3(0, 0.092, -0.192), "radii": Vector3(0.03, 0.021, 0.02), "color": "nose"},
		"mouth": {"kind": "smile", "pos": Vector3(0, 0.04, -0.185), "width": 0.05},
	},
	"eyes": {"pos": Vector3(0.07, 0.162, -0.14), "size": Vector3(0.036, 0.04, 0.018), "iris": Color(0.32, 0.18, 0.08),
		"pupil": 0, "lid_rest": 0.15, "lashes": false},
	"brows": {"pos": Vector3(0.072, 0.214, -0.15), "color": "dark", "width": 0.06, "thickness": 0.013},
	"ears": {"kind": "round", "pivot": Vector3(0.14, 0.19, 0.01), "rot": Vector3(0, 0, -18),
		"size": Vector3(0.055, 0.052, 0.03), "inner": "muzzle"},
	"hat": {"kind": "bowler", "pivot": Vector3(0, 0.258, 0.01), "rot": Vector3(-6, 0, 4), "brim": 0.14, "crown_radius": 0.112, "band": "band"},
	"neck": {"base": Vector3(0, 0.55, -0.02), "radius": 0.08, "color": "fur"},
	# 躯干是奶油衬衫加一个更鼓的大圆肚;背心、扣子、领子、蝴蝶结、表链、毛巾都在 extras 里按衣片画
	"body": {"build": "big", "coat": "shirt", "belly": "shirt", "pants": "pants", "vest": "shirt", "shirt": "shirt",
		"buttons": 0, "neckwear": "none", "chain": false, "collar": "shirt",
		"shapes": [[Vector3(0, 0.13, -0.1), Vector3(0.215, 0.165, 0.205), "shirt"]]},
	"arms": {"sleeve": "shirt", "cuff": "shirt", "forearm": "fur"},
	"paws": {"color": "paw", "pads": "pad", "fingers": 4, "length": 0.026},
	"legs": {"pants": "pants", "foot": "bare", "foot_color": "paw", "material": 6.0},
	"tail": {"path": [Vector3(0, 0.5, 0.26), Vector3(0, 0.49, 0.3)], "radius": 0.045, "tip_radius": 0.035,
		"color": "fur", "sway_range": Vector2(0.0, 1.0)},
	"anim": {"look_pitch_min": -0.45, "blink_speed": 1.0},
}


static func extras(f: MeshForge, part: String, look: Dictionary, pal: Dictionary) -> void:
	match part:
		"body":
			_body(f, look, pal)
		"arm":
			# 卷袖上方一道红袖箍(左右手臂共用一份网格,袖箍是一整圈)
			PatronBuilder.paint(f, pal, "armband", 0.6, PatronBuilder.CLOTH)
			f.lathe(PackedVector2Array([Vector2(0.06, -0.011), Vector2(0.067, -0.008), Vector2(0.068, 0.008), Vector2(0.06, 0.011)]), 16,
				PackedInt32Array(), PatronBuilder.xf(Vector3(0, -0.006, -0.1), Vector3(90, 0, 0)))


static func _body(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	var c := PatronBuilder.BODY_CENTER
	var k := PatronBuilder.BLOB_K
	var shapes := PatronBuilder.body_shapes(look, pal)
	# 衬衫立领:一圈奶油色盖住脖子根,前面两片翻角
	PatronBuilder.paint(f, pal, "shirt", 0.75, PatronBuilder.CLOTH)
	f.lathe(PackedVector2Array([Vector2(0.094, 0.53), Vector2(0.1, 0.56), Vector2(0.098, 0.592), Vector2(0.088, 0.598)]), 20,
		PackedInt32Array(), PatronBuilder.xf(Vector3(0, 0, -0.02)))
	for side: float in [-1.0, 1.0]:
		f.loft(PackedVector3Array([Vector3(0.012 * side, 0.58, -0.118), Vector3(0.04 * side, 0.55, -0.122), Vector3(0.058 * side, 0.525, -0.11)]),
			PackedVector2Array([Vector2(0.004, 0.016), Vector2(0.004, 0.02), Vector2(0.003, 0.008)]), 6, Vector2i(1, 1),
			PatronBuilder.xf(), PackedColorArray(), Vector2(-1, -1), Vector3(0, 0, -1))
	# 酒红丝绒背心:前面左右两片(V 领、尖下摆、袖窿),后片压暗的缎面
	for side: float in [-1.0, 1.0]:
		PatronBuilder.paint(f, pal, "vest", 0.7, PatronBuilder.CLOTH)
		Kit.panel(f, c, shapes, k, func(u: float, v: float) -> Vector3:
			var y := lerpf(0.5, lerpf(0.03, 0.085, u), v)
			var a_in := lerpf(15.0, -2.0, clampf((0.5 - y) / 0.22, 0.0, 1.0))
			var a_out := lerpf(52.0, 100.0, smoothstep(0.44, 0.33, y))
			return Kit.aim(c, lerpf(a_in, a_out, u) * side, y), 7, 12, 0.0085 if side > 0.0 else 0.0075)
	PatronBuilder.paint(f, pal, "vest_back", 0.45, PatronBuilder.CLOTH)
	Kit.panel(f, c, shapes, k, func(u: float, v: float) -> Vector3:
		var a := lerpf(100.0, 260.0, u)
		var top := lerpf(0.53, 0.33, smoothstep(45.0, 78.0, absf(a - 180.0)))
		return Kit.aim(c, a, lerpf(top, 0.08, v)), 8, 7, 0.0065)
	# 背心滚边:前襟一条深酒红细边
	PatronBuilder.paint(f, pal, "piping", 0.6, PatronBuilder.CLOTH)
	for side: float in [-1.0, 1.0]:
		var edge := PackedVector3Array()
		for i in 9:
			var y := lerpf(0.5, 0.035, i / 8.0)
			var a_in := lerpf(15.0, -2.0, clampf((0.5 - y) / 0.22, 0.0, 1.0))
			edge.append(Kit.surface_point(c, shapes, k, Kit.aim(c, (a_in + 0.6) * side, y), 0.011 if side > 0.0 else 0.01))
		f.tube(edge, 0.0035, 5)
	# 四颗铜扣
	PatronBuilder.paint(f, pal, "brass", 0.3, PatronBuilder.METAL, 1.0)
	for i in 4:
		var p := Kit.surface_point(c, shapes, k, Kit.aim(c, 2.5, 0.3 - i * 0.07), 0.0135)
		f.sphere(0.011, 10, PatronBuilder.xf(p, Vector3.ZERO, Vector3(1.0, 1.0, 0.7)))
	# 怀表链:第二颗扣子垂到左侧口袋
	var chain := PackedVector3Array()
	for i in 9:
		var t := i / 8.0
		chain.append(Kit.surface_point(c, shapes, k, Kit.aim(c, lerpf(-3.0, -34.0, t), lerpf(0.23, 0.18, t) - sin(t * PI) * 0.05), 0.0115))
	f.tube(chain, 0.003, 5)
	# 背心口袋:两道深色口袋盖
	PatronBuilder.paint(f, pal, "piping", 0.6, PatronBuilder.CLOTH)
	for side: float in [-1.0, 1.0]:
		Kit.panel(f, c, shapes, k, func(u: float, v: float) -> Vector3:
			return Kit.aim(c, lerpf(22.0, 42.0, u) * side, lerpf(0.195, 0.175, v) - u * 0.012), 3, 1, 0.011)
	# 蝴蝶结:领口正中,两片鼓起的翼加中间的结
	var bow := Vector3(0, 0.548, -0.128)
	var brown := PatronBuilder.color(pal, "accent")
	PatronBuilder.paint(f, pal, "accent", 0.55, PatronBuilder.CLOTH)
	f.blob(bow, [[bow + Vector3(0.036, 0.0, 0.004), Vector3(0.036, 0.026, 0.014), brown, "mirror"],
		[bow + Vector3(0.05, 0.0, 0.006), Vector3(0.016, 0.03, 0.012), brown.darkened(0.15), "mirror"],
		[bow + Vector3(0, 0, -0.004), Vector3(0.015, 0.016, 0.016), brown.darkened(0.3)]], 18, 10, 0.01)
	# 左肩搭一条吧台毛巾:从背后翻过肩头垂到胸前,贴着肩和袖山;两头各两道红条纹
	var towel_shapes := shapes.duplicate()
	towel_shapes.append([Vector3(-0.21, 0.52, -0.02), Vector3(0.072, 0.075, 0.085), Color.WHITE])
	towel_shapes.append([Vector3(-0.1, 0.55, -0.02), Vector3(0.1, 0.05, 0.1), Color.WHITE])
	var towel := PatronBuilder.color(pal, "towel")
	var stripe := PatronBuilder.color(pal, "stripe")
	PatronBuilder.paint(f, pal, "towel", 0.95, PatronBuilder.KNIT)
	var rows := PackedFloat32Array()
	var edges := [0.04, 0.085, 0.12, 0.16]
	for j in 25:
		rows.append(j / 24.0)
	for e: float in edges:
		for v: float in [e, 1.0 - e]:
			rows.append(v - 0.0004)
			rows.append(v + 0.0004)
	rows.sort()
	Kit.band(f, Vector3(-0.12, 0.35, -0.01), towel_shapes, k, [Vector3(-0.02, -0.1, 0.2), Vector3(-0.01, 0.08, 0.2),
		Vector3(-0.02, 0.2, 0.08), Vector3(-0.025, 0.2, -0.06), Vector3(-0.01, 0.06, -0.2), Vector3(0.0, -0.08, -0.2), Vector3(0.0, -0.2, -0.2)],
		15.0, 0, 0.014, func(_u: float, v: float) -> Color:
			var e := minf(v, 1.0 - v)
			return stripe if (e > edges[0] and e < edges[1]) or (e > edges[2] and e < edges[3]) else towel, true, 0.0, rows)
