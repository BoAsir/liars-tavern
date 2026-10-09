extends RefCounted
# 猫「独行枪手」:灰虎斑,额头 M 纹、白吻白胸、w 形嘴、粉三角鼻、竖椭圆瞳;三角耳从牛仔帽的耳洞穿出;
# 皮背心、浅蓝衬衫、青色方巾、宽枪带配大银扣、右胯枪套;牛仔裤、圆头牛仔靴;细长虎斑尾从缝里穿出垂在椅后。
# 动森式:去掉胡须、珍珠扣、缝线、银扣花、子弹、皮护腿与马刺。

const Kit := preload("res://src/world/species/species_fox.gd")   # 衣片工具


const LOOK := {
	"id": "cat",
	"gun_clearance": 0.316,   # 持枪净空(米,已含动森式大头的放大):按举枪流程实测最小值(含抖耳)再留 ≥4 mm
	"palette": {
		"fur": Color(0.36, 0.37, 0.42), "muzzle": Color(0.80, 0.79, 0.77), "dark": Color(0.1, 0.1, 0.12),
		"coat": Color(0.48, 0.62, 0.72), "accent": Color(0.20, 0.52, 0.58), "stripe": Color(0.15, 0.15, 0.18),
		"vest": Color(0.40, 0.23, 0.11), "shirt": Color(0.48, 0.62, 0.72), "hat": Color(0.3, 0.2, 0.12),
		"band": Color(0.2, 0.52, 0.58), "pants": Color(0.18, 0.26, 0.4), "shoe": Color(0.3, 0.17, 0.09),
		"nose": Color(0.72, 0.42, 0.46), "pad": Color(0.6, 0.38, 0.42), "leather": Color(0.26, 0.15, 0.08),
		"chaps": Color(0.46, 0.29, 0.15), "stitch": Color(0.76, 0.62, 0.42), "pearl": Color(0.78, 0.77, 0.72),
		"grip": Color(0.32, 0.18, 0.08), "rawhide": Color(0.62, 0.47, 0.28), "blush": Color(0.86, 0.6, 0.62),
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
		"blush": true,
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

# 虎斑纹:头上的贴花条(方位角°, 高度),半宽°。动森式:脸上不画颊纹(大眼旁边一道深线像划痕),只留额头 M 纹和后脑横纹
const HEAD_STRIPES := [
	[[Vector2(0, 0.19), Vector2(0, 0.255)], 4.0],                                      # 额头 M 纹中线
	[[Vector2(9, 0.198), Vector2(13, 0.255)], 3.4, "mirror"],                          # M 纹内侧两笔
	[[Vector2(25, 0.208), Vector2(32, 0.25)], 3.0, "mirror"],                          # M 纹外侧两笔(眉梢上方)
	[[Vector2(96, 0.205), Vector2(130, 0.21), Vector2(166, 0.204)], 5.4, "mirror"],    # 后脑三道横纹
	[[Vector2(100, 0.152), Vector2(134, 0.152), Vector2(168, 0.146)], 5.4, "mirror"],
	[[Vector2(106, 0.098), Vector2(140, 0.092), Vector2(170, 0.086)], 5.0, "mirror"],
	[[Vector2(180, 0.215), Vector2(180, 0.06)], 4.4],                                  # 后颈中线
]


static func extras(f: MeshForge, part: String, look: Dictionary, pal: Dictionary) -> void:
	match part:
		"head":
			_head(f, look, pal)
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


static func _body(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	var c := PatronBuilder.BODY_CENTER
	var k := PatronBuilder.BLOB_K
	var shapes := PatronBuilder.body_shapes(look, pal)
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
	# 枪带:斜挎在腰上,右胯低;正面一个大银扣
	PatronBuilder.paint(f, pal, "leather", 0.55, PatronBuilder.LEATHER)
	Kit.panel(f, c, shapes, k, func(u: float, v: float) -> Vector3:
		var a := u * 360.0
		var y := 0.075 - 0.035 * sin(deg_to_rad(a))
		return Kit.aim(c, a, y + lerpf(0.022, -0.022, v)), 22, 1, 0.009, Callable(), true, true)
	var buckle := Kit.surface_point(c, shapes, k, Kit.aim(c, -6.0, 0.075 + 0.0037), 0.0175)
	PatronBuilder.paint(f, pal, "silver", 0.45, PatronBuilder.METAL, 1.0)
	f.sphere(1.0, 12, PatronBuilder.xf(buckle, Vector3(-12, 6, 4), Vector3(0.03, 0.024, 0.008)))
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
	# 右胯枪套:搭在大腿外侧,顺着大腿朝前,露出木枪柄(靴子是 PatronBuilder 的牛仔靴款)
	var leather := PatronBuilder.color(pal, "leather")
	PatronBuilder.paint(f, pal, "leather", 0.7, PatronBuilder.LEATHER)
	f.blob(Vector3(0.2, 0.53, 0.02), [[Vector3(0.198, 0.54, 0.07), Vector3(0.02, 0.04, 0.045), leather],
		[Vector3(0.2, 0.525, 0.0), Vector3(0.018, 0.03, 0.048), leather]], 12, 8, 0.014)
	PatronBuilder.paint(f, pal, "grip", 0.7, PatronBuilder.LEATHER)
	f.loft(PackedVector3Array([Vector3(0.198, 0.565, 0.1), Vector3(0.2, 0.588, 0.122), Vector3(0.202, 0.6, 0.13)]),
		PackedVector2Array([Vector2(0.014, 0.018), Vector2(0.014, 0.019), Vector2(0.013, 0.018)]), 8)
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
