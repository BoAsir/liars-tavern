class_name PatronHatBuilder
# 酒客的帽子(合批配方,Hat 枢轴局部;帽子是一个子树,出局时整顶打飞成一个散落物)。
# 帽冠与帽檐都是车削轮廓,卷边、压痕、前捏靠 displace 小幅变形;帽带是单独一圈车削。
# 两侧卷起的帽檐给太阳穴处的枪管让路(|x| ≥ 0.15 处帽檐 y ≥ 0.2,在 Head 局部、放大前量)。



static func hat(f: MeshForge, look: Dictionary, pal: Dictionary, hooks: GDScript) -> void:
	PatronBuilder.start(f, 0.9)
	# Q 版:帽子跟头一起放大(枢轴位置由 Patron 换算)。帽檐卷边用 displace 按原尺寸写,所以先按原尺寸建好再整体缩放
	var from := f.mark()
	var h: Dictionary = look.get("hat", {})
	match h.get("kind", "none"):
		"top":
			_top(f, pal, h)
		"bowler":
			_bowler(f, pal, h)
		"cowboy":
			_cowboy(f, pal, h)
		"conductor":
			_conductor(f, pal, h)
		"pillbox":
			_pillbox(f, pal, h)
		"slouch":
			_slouch(f, pal, h)
		"straw":
			_straw(f, pal, h)
		"flat":
			_flat(f, pal, h)
	hooks.extras(f, "hat", look, pal)
	f.displace(from, func(p: Vector3) -> Vector3: return p * Vector3(PatronParts.HEAD_SCALE, PatronParts.HAT_SCALE_Y, PatronParts.HEAD_SCALE))


static func _brim(f: MeshForge, inner: float, outer: float, thick: float, segs := 40) -> int:
	# 平帽檐(上下两面 + 外缘),返回 mark 方便后面整体变形
	var from := f.mark()
	f.lathe(PackedVector2Array([Vector2(inner, -thick * 0.5), Vector2(outer, -thick * 0.5), Vector2(outer + thick * 0.4, 0.0),
		Vector2(outer, thick * 0.5), Vector2(inner, thick * 0.5)]), segs, PackedInt32Array([1, 3]))
	return from


static func _side_curl(amount: float, outer: float, sharp := 2.0) -> Callable:
	# 两侧(±x)往上卷:越靠外缘、越靠两侧卷得越高
	return func(p: Vector3) -> Vector3:
		var r := Vector2(p.x, p.z).length()
		var side := pow(absf(p.x) / maxf(r, 1e-5), sharp)
		var edge := clampf((r - outer * 0.55) / (outer * 0.45), 0.0, 1.0)
		return p + Vector3(0, amount * side * edge * edge, 0)


static func _top(f: MeshForge, pal: Dictionary, h: Dictionary) -> void:
	# 礼帽:收腰帽冠 + 两侧卷起的窄檐 + 帽带
	var crown: Array = h.get("crown", [0.082, 0.21])
	var brim: float = h.get("brim", 0.118)
	PatronBuilder.paint(f, pal, "hat", 0.65, PatronBuilder.CLOTH)
	var from := _brim(f, crown[0] * 0.8, brim, 0.012)
	f.displace(from, _side_curl(h.get("curl", 0.022), brim))
	var r: float = crown[0]
	var top: float = crown[1]
	f.lathe(PackedVector2Array([Vector2(r * 1.02, 0.0), Vector2(r * 0.94, top * 0.45), Vector2(r * 1.0, top * 0.92),
		Vector2(r * 1.04, top), Vector2(0.0, top)]), 32, PackedInt32Array([3]))
	PatronBuilder.paint(f, pal, h.get("band", "band"), 0.5, PatronBuilder.CLOTH)
	f.lathe(PackedVector2Array([Vector2(r * 1.03, 0.008), Vector2(r * 0.99, 0.036)]), 32)


static func _bowler(f: MeshForge, pal: Dictionary, h: Dictionary) -> void:
	# 圆顶礼帽:半球冠 + 外缘卷边的檐
	var brim: float = h.get("brim", 0.14)
	var crown: float = h.get("crown_radius", 0.112)
	PatronBuilder.paint(f, pal, "hat", 0.6, PatronBuilder.CLOTH)
	var from := _brim(f, crown * 0.8, brim, 0.012)
	f.displace(from, func(p: Vector3) -> Vector3:
		var r := Vector2(p.x, p.z).length()
		return p + Vector3(0, 0.014 * smoothstep(brim * 0.8, brim, r) * (0.6 + 0.4 * absf(p.x) / maxf(r, 1e-5)), 0))
	var profile := PackedVector2Array()
	for i in 9:
		var a := PI * 0.5 * i / 8.0
		profile.append(Vector2(cos(a) * crown, 0.004 + sin(a) * crown * 1.12))
	f.lathe(profile, 32)
	PatronBuilder.paint(f, pal, h.get("band", "band"), 0.5, PatronBuilder.CLOTH)
	f.lathe(PackedVector2Array([Vector2(crown * 1.02, 0.008), Vector2(crown * 1.0, 0.032)]), 32)


static func _cowboy(f: MeshForge, pal: Dictionary, h: Dictionary) -> void:
	# 牛仔帽:宽檐两侧高高卷起(右侧更高,让开太阳穴的枪管),帽冠顶部压痕、前面捏起
	var brim: float = h.get("brim", 0.24)
	PatronBuilder.paint(f, pal, "hat", 0.7, PatronBuilder.LEATHER)
	var from := _brim(f, 0.08, brim, 0.012, 48)
	f.displace(from, func(p: Vector3) -> Vector3:
		var r := Vector2(p.x, p.z).length()
		var side := pow(absf(p.x) / maxf(r, 1e-5), 1.6)
		var edge := clampf((r - 0.1) / (brim - 0.1), 0.0, 1.0)
		var lift := (0.075 if p.x > 0.0 else 0.06) * side * edge * edge
		var dip := -0.012 * (1.0 - side) * edge * edge   # 前后檐略往下压
		return Vector3(p.x, p.y + lift + dip, p.z * 0.86))
	var crown_from := f.mark()
	f.lathe(PackedVector2Array([Vector2(0.105, 0.0), Vector2(0.1, 0.06), Vector2(0.09, 0.12), Vector2(0.075, 0.14),
		Vector2(0.0, 0.115)]), 32, PackedInt32Array([3]))
	f.displace(crown_from, func(p: Vector3) -> Vector3:
		var pinch := smoothstep(0.06, 0.14, p.y) * smoothstep(0.0, -0.09, p.z) * 0.035   # 前捏
		return Vector3(p.x * (1.0 - pinch * 4.0), p.y, p.z * 1.08))
	PatronBuilder.paint(f, pal, h.get("band", "band"), 0.5, PatronBuilder.LEATHER)
	f.lathe(PackedVector2Array([Vector2(0.107, 0.012), Vector2(0.104, 0.034)]), 32)


static func _conductor(f: MeshForge, pal: Dictionary, h: Dictionary) -> void:
	# 司机帽:蓬起的软冠 + 前面短帽舌 + 条纹(按高度交替的车削圈)
	var r: float = h.get("radius", 0.135)
	var stripe_a: String = h.get("stripe_a", "hat")
	var stripe_b: String = h.get("stripe_b", "cream")
	for i in 6:
		PatronBuilder.paint(f, pal, stripe_a if i % 2 == 0 else stripe_b, 0.8, PatronBuilder.CLOTH)
		var y0 := -0.015 + i * 0.016
		var y1 := y0 + 0.016
		var r0 := r * (1.0 + 0.12 * sin(float(i) / 6.0 * PI))
		var r1 := r * (1.0 + 0.12 * sin(float(i + 1) / 6.0 * PI))
		f.lathe(PackedVector2Array([Vector2(r0, y0), Vector2(r1, y1)]), 28)
	PatronBuilder.paint(f, pal, stripe_a, 0.8, PatronBuilder.CLOTH)
	f.lathe(PackedVector2Array([Vector2(r, 0.081), Vector2(r * 0.7, 0.1), Vector2(0.0, 0.105)]), 28)
	PatronBuilder.paint(f, pal, h.get("visor", "dark"), 0.4, PatronBuilder.LEATHER)
	f.cylinder(0.1, 0.1, 0.01, 20, MeshForge.CAPS_BOTH, PatronBuilder.xf(Vector3(0, -0.012, -0.11), Vector3(-8, 0, 0), Vector3(1.0, 1.0, 0.55)))


static func _pillbox(f: MeshForge, pal: Dictionary, h: Dictionary) -> void:
	# 药盒帽(门童):矮圆柱 + 金箍 + 颏带
	var r: float = h.get("radius", 0.075)
	PatronBuilder.paint(f, pal, h.get("color", "coat"), 0.7, PatronBuilder.CLOTH)
	f.lathe(PackedVector2Array([Vector2(r, 0.0), Vector2(r * 0.98, 0.07), Vector2(r * 0.9, 0.08), Vector2(0.0, 0.08)]), 28, PackedInt32Array([2]))
	PatronBuilder.paint(f, pal, "brass", 0.35, PatronBuilder.METAL, 1.0)
	f.lathe(PackedVector2Array([Vector2(r * 1.02, 0.006), Vector2(r * 1.01, 0.018)]), 28)
	f.sphere(0.012, 8, PatronBuilder.xf(Vector3(0, 0.084, 0)))
	if h.get("chin_strap", true):
		PatronBuilder.paint(f, pal, "dark", 0.6, PatronBuilder.LEATHER)
		var strap: Array = h.get("strap", [Vector3(0.07, 0.0, 0.0), Vector3(0.1, -0.12, -0.04), Vector3(0.0, -0.2, -0.1)])
		for side: float in [-1.0, 1.0]:
			var path := PackedVector3Array()
			for p in strap:
				path.append(Vector3(p.x * side, p.y, p.z))
			f.tube(path, 0.003, 5)


static func _slouch(f: MeshForge, pal: Dictionary, h: Dictionary) -> void:
	# 软毡宽松帽(老淘金客):圆冠 + 前后往下垂的软檐
	var brim: float = h.get("brim", 0.19)
	PatronBuilder.paint(f, pal, "hat", 0.85, PatronBuilder.CLOTH)
	var from := _brim(f, 0.085, brim, 0.014, 40)
	f.displace(from, func(p: Vector3) -> Vector3:
		var r := Vector2(p.x, p.z).length()
		var fb := pow(absf(p.z) / maxf(r, 1e-5), 1.5)
		var edge := clampf((r - 0.1) / (brim - 0.1), 0.0, 1.0)
		return p + Vector3(0, -0.04 * fb * edge * edge + 0.012 * (1.0 - fb) * edge, 0))
	f.lathe(PackedVector2Array([Vector2(0.1, 0.0), Vector2(0.098, 0.05), Vector2(0.08, 0.1), Vector2(0.0, 0.12)]), 28)
	PatronBuilder.paint(f, pal, h.get("band", "dark"), 0.7, PatronBuilder.CLOTH)
	f.lathe(PackedVector2Array([Vector2(0.102, 0.008), Vector2(0.1, 0.03)]), 28)


static func _straw(f: MeshForge, pal: Dictionary, h: Dictionary) -> void:
	# 迷你草帽(羊驼):戴在卷毛顶上的小平顶草帽 + 颏绳
	var crown: float = h.get("crown_radius", 0.05)
	var brim: float = h.get("brim", 0.07)
	PatronBuilder.paint(f, pal, h.get("color", "straw"), 0.9, PatronBuilder.STRAW)
	_brim(f, crown * 0.8, brim, 0.008, 28)
	f.lathe(PackedVector2Array([Vector2(crown, 0.0), Vector2(crown * 0.96, 0.04), Vector2(0.0, 0.042)]), 24, PackedInt32Array([1]))
	PatronBuilder.paint(f, pal, h.get("band", "band"), 0.6, PatronBuilder.CLOTH)
	f.lathe(PackedVector2Array([Vector2(crown * 1.02, 0.004), Vector2(crown * 1.0, 0.014)]), 24)
	if h.has("strap"):
		PatronBuilder.paint(f, pal, "dark", 0.6, PatronBuilder.LEATHER)
		for side: float in [-1.0, 1.0]:
			var path := PackedVector3Array()
			for p in h["strap"]:
				path.append(Vector3(p.x * side, p.y, p.z))
			f.tube(path, 0.0022, 4)


static func _flat(f: MeshForge, pal: Dictionary, h: Dictionary) -> void:
	# 亡命徒平檐低冠帽:平直宽檐 + 矮冠 + 银扣
	var brim: float = h.get("brim", 0.19)
	PatronBuilder.paint(f, pal, "hat", 0.65, PatronBuilder.LEATHER)
	_brim(f, 0.09, brim, 0.012, 40)
	f.lathe(PackedVector2Array([Vector2(0.1, 0.0), Vector2(0.096, 0.07), Vector2(0.0, 0.074)]), 28, PackedInt32Array([1]))
	PatronBuilder.paint(f, pal, h.get("band", "band"), 0.5, PatronBuilder.LEATHER)
	f.lathe(PackedVector2Array([Vector2(0.102, 0.008), Vector2(0.099, 0.026)]), 28)
	PatronBuilder.paint(f, pal, "silver", 0.25, PatronBuilder.METAL, 1.0)
	f.box(Vector3(0.026, 0.02, 0.008), PatronBuilder.xf(Vector3(0, 0.017, -0.102)))
