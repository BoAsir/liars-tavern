class_name PatronBuilder
# 酒客部件的合批配方:把物种外观数据(species/*.gd 的 LOOK)变成每个动画枢轴下的一份网格。
# 躯干、脖子、手臂、爪子、拳头、腿和尾巴在这里;头、眼、眉、耳在 PatronHeadBuilder,帽子在 PatronHatBuilder。
# 坐标:body 在 Body 枢轴(HIP)局部;neck 在 Neck 枢轴局部(单位高);arm 在肩枢轴局部(沿 -Z);
# paw / fist 在 Hand 局部;legs(含尾巴)在 Patron 根(座位坐标)。全部纯数组运算,可在工作线程跑。
# 物种特件(龟壳、披毯、子弹带……)由物种脚本的 extras(f, part, look, pal) 补上。

# 材质类(写进 CUSTOM0.x,patron.gdshader 按它叠花纹)
const FUR := 0.0
const CLOTH := 1.0
const LEATHER := 2.0
const METAL := 3.0
const SCALE := 4.0
const SHELL := 5.0
const PLAID := 6.0
const STRAW := 7.0
const KNIT := 8.0
const SMOOTH := 9.0

const BODY_CENTER := Vector3(0, 0.25, 0)
const SLEEVE_END := -0.35     # 袖口压住爪腕(Hand 在 -ARM_LENGTH = -0.4)
const PAW_PITCH := 27.0       # 坐着时手臂俯 ≈27°,张开的爪反向烘焙这个角度,掌面才平贴桌面
const BLOB_K := 0.035

# 体型:pelvis / belly / chest 三个椭球 [中心, 半径]
const BUILDS := {
	"slim": [[Vector3(0, 0.02, 0.0), Vector3(0.18, 0.12, 0.16)], [Vector3(0, 0.15, -0.025), Vector3(0.185, 0.15, 0.165)],
		[Vector3(0, 0.33, -0.01), Vector3(0.19, 0.17, 0.15)]],
	"round": [[Vector3(0, 0.02, 0.0), Vector3(0.19, 0.12, 0.17)], [Vector3(0, 0.14, -0.05), Vector3(0.21, 0.17, 0.195)],
		[Vector3(0, 0.33, -0.01), Vector3(0.195, 0.17, 0.155)]],
	"big": [[Vector3(0, 0.02, 0.0), Vector3(0.2, 0.12, 0.18)], [Vector3(0, 0.15, -0.065), Vector3(0.235, 0.19, 0.215)],
		[Vector3(0, 0.34, -0.015), Vector3(0.2, 0.17, 0.16)]],
	"stocky": [[Vector3(0, 0.02, 0.0), Vector3(0.19, 0.12, 0.17)], [Vector3(0, 0.15, -0.03), Vector3(0.2, 0.15, 0.175)],
		[Vector3(0, 0.33, -0.01), Vector3(0.205, 0.17, 0.155)]],
}


# —— 调色 ——

static func color(pal: Dictionary, key: String) -> Color:
	return pal.get(key, pal.get("fur", Color(0.5, 0.5, 0.5)))


static func paint(f: MeshForge, pal: Dictionary, key: String, rough := 0.75, mat := FUR, metal := 0.0) -> void:
	f.paint(color(pal, key), rough, metal)
	f.custom = Vector4(mat, 0.0, f.custom.z, 0.0)


static func start(f: MeshForge, part_seed := 0.0) -> void:
	# 所有酒客网格写满同一种顶点格式(CUSTOM0 浮点),哪个物种第一次出现都不编译新管线
	f.write_custom = true
	f.custom = Vector4(0, 0, part_seed, 0)


static func xf(pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	return MeshForge.xf(pos, rot_deg, scale)


static func shapes_colored(shapes: Array, pal: Dictionary) -> Array:
	# 外观数据里的形体用调色板键写颜色:[中心, 半径, 颜色键, 可选 "mirror"] → blob 用的 [中心, 半径, Color, ...]
	var out := []
	for s in shapes:
		var item := [s[0], s[1], color(pal, s[2])]
		if s.size() > 3:
			item.append(s[3])
		out.append(item)
	return out


# —— 躯干与服装 ——

static func body_shapes(look: Dictionary, pal: Dictionary) -> Array:
	var body: Dictionary = look["body"]
	var build: Array = BUILDS[body.get("build", "slim")]
	var shapes := [
		[build[0][0], build[0][1], color(pal, body.get("pants", "pants"))],
		[build[1][0], build[1][1], color(pal, body.get("belly", "coat"))],
		[build[2][0], build[2][1], color(pal, body.get("coat", "coat"))],
		[Vector3(0.14, 0.47, -0.01), Vector3(0.11, 0.075, 0.1), color(pal, body.get("coat", "coat")), "mirror"],
		[Vector3(0, 0.53, -0.02), Vector3(0.1, 0.05, 0.09), color(pal, body.get("collar", body.get("coat", "coat")))],
	]
	if body.has("shirt"):
		# 衬衫前襟:胸前一片扁椭球,颜色按最近形体取,边缘自然过渡
		shapes.append([Vector3(0, 0.4, -0.1), Vector3(0.07, 0.12, 0.06), color(pal, body["shirt"])])
	if body.has("vest"):
		shapes.append([Vector3(0, 0.22, -0.07), Vector3(0.17, 0.15, 0.12), color(pal, body["vest"])])
	for extra in body.get("shapes", []):
		var item := [extra[0], extra[1], color(pal, extra[2])]
		if extra.size() > 3:
			item.append(extra[3])
		shapes.append(item)
	return shapes


static func body(f: MeshForge, look: Dictionary, pal: Dictionary, hooks: GDScript) -> void:
	start(f, 0.1)
	var b: Dictionary = look["body"]
	var shapes := body_shapes(look, pal)
	paint(f, pal, b.get("coat", "coat"), 0.85, b.get("material", CLOTH))
	f.blob(BODY_CENTER, shapes, 36, 22, BLOB_K)
	if b.get("lapels", false):
		_lapels(f, pal, b, shapes)
	var buttons: int = b.get("buttons", 0)
	if buttons > 0:
		paint(f, pal, "brass", 0.32, METAL, 1.0)
		for i in buttons:
			var y := 0.3 - i * (0.22 / maxf(buttons - 1, 1))
			var p := MeshForge.blob_surface(BODY_CENTER, Vector3(0, y, -1.0) - Vector3(0, BODY_CENTER.y, 0), shapes, BLOB_K)
			f.sphere(0.012, 8, xf(p + Vector3(0, 0, 0.004)))
	_neckwear(f, pal, b)
	if b.get("chain", false):
		# 怀表链:从背心扣子垂到侧边口袋的悬链线
		paint(f, pal, "brass", 0.3, METAL, 1.0)
		var a := MeshForge.blob_surface(BODY_CENTER, Vector3(0, 0.0, -1), shapes, BLOB_K)
		var c := MeshForge.blob_surface(BODY_CENTER, Vector3(0.75, -0.05, -0.8), shapes, BLOB_K)
		var chain := PackedVector3Array()
		for i in 9:
			var t := i / 8.0
			var p := a.lerp(c, t)
			p.y -= sin(t * PI) * 0.035
			p.z -= 0.006
			chain.append(p)
		f.tube(chain, 0.0028, 5)
	hooks.extras(f, "body", look, pal)


static func _lapels(f: MeshForge, pal: Dictionary, b: Dictionary, shapes: Array) -> void:
	# 翻领:两片贴着胸前斜放的扁片,压暗的外套色
	paint(f, pal, b.get("lapel", "lapel"), 0.8, CLOTH)
	for side: float in [-1.0, 1.0]:
		var top := MeshForge.blob_surface(BODY_CENTER, Vector3(0.12 * side, 0.27, -1), shapes, BLOB_K)
		var bottom := MeshForge.blob_surface(BODY_CENTER, Vector3(0.03 * side, 0.02, -1), shapes, BLOB_K)
		var path := PackedVector3Array([top + Vector3(0, 0, -0.004), (top + bottom) * 0.5 + Vector3(0, 0, -0.012),
			bottom + Vector3(0, 0, -0.004)])
		f.loft(path, PackedVector2Array([Vector2(0.006, 0.03), Vector2(0.006, 0.026), Vector2(0.005, 0.006)]), 6)


static func _neckwear(f: MeshForge, pal: Dictionary, b: Dictionary) -> void:
	var kind: String = b.get("neckwear", "none")
	var key: String = b.get("neckwear_color", "accent")
	var at := Vector3(0, 0.535, -0.11)
	match kind:
		"bowtie":
			paint(f, pal, key, 0.55, CLOTH)
			f.blob(at, [[at + Vector3(0.028, 0, 0), Vector3(0.03, 0.022, 0.012), color(pal, key), "mirror"],
				[at, Vector3(0.012, 0.012, 0.013), color(pal, key).darkened(0.25)]], 14, 8, 0.008)
		"cravat":
			paint(f, pal, key, 0.6, CLOTH)
			f.blob(at + Vector3(0, -0.04, -0.01), [[at + Vector3(0, -0.01, -0.01), Vector3(0.035, 0.03, 0.022), color(pal, key)],
				[at + Vector3(0, -0.065, -0.012), Vector3(0.028, 0.045, 0.016), color(pal, key)]], 14, 10, 0.012)
			paint(f, pal, "gem", 0.15, METAL, 0.6)
			f.sphere(0.008, 8, xf(at + Vector3(0, -0.03, -0.035)))
		"bandana":
			paint(f, pal, key, 0.7, CLOTH)
			f.torus(0.07, 0.1, 18, xf(Vector3(0, 0.55, -0.02), Vector3.ZERO, Vector3(1.0, 0.5, 1.0)))
			f.loft(PackedVector3Array([at + Vector3(0, 0.0, -0.005), at + Vector3(0, -0.06, -0.02), at + Vector3(0, -0.11, -0.025)]),
				PackedVector2Array([Vector2(0.012, 0.06), Vector2(0.01, 0.04), Vector2(0.004, 0.006)]), 6)
		"neckerchief":
			paint(f, pal, key, 0.7, CLOTH)
			f.torus(0.072, 0.098, 18, xf(Vector3(0, 0.552, -0.02), Vector3.ZERO, Vector3(1.0, 0.45, 1.0)))
			f.sphere(0.02, 10, xf(at + Vector3(0.02, -0.01, -0.01), Vector3.ZERO, Vector3(1.2, 1.0, 0.8)))
		"bolo":
			paint(f, pal, "dark", 0.6, LEATHER)
			for side: float in [-1.0, 1.0]:
				f.tube(PackedVector3Array([Vector3(0.06 * side, 0.55, -0.08), at + Vector3(0.008 * side, -0.05, -0.02),
					at + Vector3(0.012 * side, -0.14, -0.03)]), 0.003, 5)
			paint(f, pal, key, 0.3, METAL, 0.3)
			f.cylinder(0.018, 0.018, 0.006, 12, MeshForge.CAPS_BOTH, xf(at + Vector3(0, -0.05, -0.03), Vector3(90, 0, 0)))


# —— 脖子 ——

static func neck(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	# 单位高的车削体(y 从 0 到 1),Patron 每帧按领口到头的距离拉长;光滑皮毛,拉长 8 倍也不出条纹
	start(f, 0.2)
	var r: float = look["neck"].get("radius", 0.075)
	paint(f, pal, look["neck"].get("color", "fur"), 0.75, SMOOTH)
	f.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(r * 1.12, 0.0), Vector2(r, 0.5), Vector2(r * 0.96, 1.0),
		Vector2(0.0, 1.0)]), 16)


# —— 手臂与爪子 ——

static func arm(f: MeshForge, look: Dictionary, pal: Dictionary, hooks: GDScript) -> void:
	# 袖子:肩 → 肘(略往下弯)→ 袖口,沿 -Z;袖口一圈换色。卷袖的物种(bear/pig)小臂露出皮毛
	start(f, 0.3)
	var a: Dictionary = look["arms"]
	var sleeve := color(pal, a.get("sleeve", "coat"))
	var cuff := color(pal, a.get("cuff", a.get("sleeve", "coat")))
	var forearm: String = a.get("forearm", "")
	var path := PackedVector3Array([Vector3(0, 0.005, 0.02), Vector3(0, 0, -0.06), Vector3(0, -0.012, -0.18),
		Vector3(0, -0.006, -0.27), Vector3(0, 0, -0.31), Vector3(0, 0, -0.312), Vector3(0, 0, SLEEVE_END)])
	var radii := PackedVector2Array([Vector2(0.07, 0.07), Vector2(0.066, 0.064), Vector2(0.054, 0.052),
		Vector2(0.052, 0.05), Vector2(0.056, 0.054), Vector2(0.06, 0.058), Vector2(0.058, 0.056)])
	var colors := PackedColorArray()
	for i in path.size():
		var c := sleeve
		if forearm != "" and i >= 3:
			c = color(pal, forearm)
		elif i >= 5:
			c = cuff
		colors.append(Color(c.r, c.g, c.b, 1.0))
	if forearm != "":
		# 卷到小臂的袖口:袖子本身到肘下为止,外面一圈卷边
		paint(f, pal, a.get("sleeve", "coat"), 0.85, a.get("material", CLOTH))
		f.loft(path.slice(0, 4), radii.slice(0, 4), 14, Vector2i(1, 0), Transform3D.IDENTITY, colors.slice(0, 3) + PackedColorArray([colors[2]]))
		paint(f, pal, a.get("cuff", a.get("sleeve", "coat")), 0.85, CLOTH)
		f.torus(0.052, 0.068, 16, xf(Vector3(0, -0.008, -0.2), Vector3(90, 0, 0)))
		paint(f, pal, forearm, 0.75, FUR)
		f.loft(path.slice(2), PackedVector2Array([Vector2(0.046, 0.044), Vector2(0.044, 0.042), Vector2(0.046, 0.044),
			Vector2(0.047, 0.045), Vector2(0.046, 0.044)]), 12, Vector2i(0, 1))
	else:
		paint(f, pal, a.get("sleeve", "coat"), 0.85, a.get("material", CLOTH))
		f.loft(path, radii, 14, Vector2i(1, 1), Transform3D.IDENTITY, colors)
	hooks.extras(f, "arm", look, pal)


static func paw(f: MeshForge, look: Dictionary, pal: Dictionary, side: float) -> void:
	# 张开的爪:掌心 + 指头(猴子长、猪 3 根粗指)+ 拇指;反向烘焙坐姿的手臂俯角,掌面平贴桌面
	start(f, 0.4 + side * 0.05)
	var p: Dictionary = look["paws"]
	var fur := color(pal, p.get("color", "paw"))
	var pad := color(pal, p.get("pads", "pad"))
	var fingers: int = p.get("fingers", 4)
	var length: float = p.get("length", 0.032)
	var shapes := [[Vector3(0, -0.004, -0.004), Vector3(0.054, 0.034, 0.056), fur],
		[Vector3(0, -0.03, -0.012), Vector3(0.034, 0.012, 0.03), pad]]
	for i in fingers:
		var t := (i - (fingers - 1) * 0.5) / maxf(fingers - 1, 1)
		var x := t * (0.07 if fingers > 3 else 0.06)
		shapes.append([Vector3(x, -0.012, -0.05 - length * 0.5), Vector3(0.016 if fingers > 3 else 0.021, 0.016, length * 0.75), fur])
	shapes.append([Vector3(0.052 * side, -0.006, -0.012), Vector3(0.018, 0.016, 0.026), fur])   # 拇指朝身体内侧
	paint(f, pal, p.get("color", "paw"), 0.75, FUR)
	f.blob(Vector3(0, -0.004, -0.01), shapes, 24, 14, 0.014, xf(Vector3.ZERO, Vector3(PAW_PITCH, 0, 0)))
	if p.get("claws", "") != "":
		paint(f, pal, p["claws"], 0.4, LEATHER)
		for i in fingers:
			var t := (i - (fingers - 1) * 0.5) / maxf(fingers - 1, 1)
			f.cylinder(0.0, 0.006, 0.014, 6, MeshForge.CAPS_BOTH,
				xf(Vector3(t * 0.07, -0.016, -0.05 - length * 1.25), Vector3(PAW_PITCH - 90, 0, 0)))


static func fist(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	# 握枪的拳头(只有右手):圆拳加指节;按旧左轮握把位置(原点 6 cm 以内)调
	start(f, 0.45)
	var fur := color(pal, look["paws"].get("color", "paw"))
	var shapes := [[Vector3(0, 0, 0.0), Vector3(0.05, 0.05, 0.052), fur]]
	for i in 4:
		shapes.append([Vector3(-0.03 + i * 0.02, 0.012, -0.044), Vector3(0.014, 0.016, 0.014), fur])
	shapes.append([Vector3(-0.045, 0.02, -0.01), Vector3(0.016, 0.02, 0.022), fur])
	paint(f, pal, look["paws"].get("color", "paw"), 0.75, FUR)
	f.blob(Vector3.ZERO, shapes, 20, 12, 0.012)


# —— 腿、鞋、尾巴(座位坐标)——

static func legs(f: MeshForge, look: Dictionary, pal: Dictionary, hooks: GDScript) -> void:
	start(f, 0.5)
	var l: Dictionary = look["legs"]
	var pants := color(pal, l.get("pants", "pants"))
	for side: float in [-1.0, 1.0]:
		var x := 0.1 * side
		var path := PackedVector3Array([Vector3(x, 0.47, 0.12), Vector3(x, 0.49, -0.02), Vector3(x, 0.49, -0.12),
			Vector3(x * 1.02, 0.38, -0.155), Vector3(x * 1.04, 0.2, -0.16), Vector3(x * 1.04, 0.08, -0.155)])
		var radii := PackedVector2Array([Vector2(0.08, 0.078), Vector2(0.074, 0.072), Vector2(0.062, 0.06),
			Vector2(0.056, 0.054), Vector2(0.05, 0.049), Vector2(0.046, 0.045)])
		paint(f, pal, l.get("pants", "pants"), 0.85, l.get("material", CLOTH))
		f.loft(path, radii, 12, Vector2i(1, 0), Transform3D.IDENTITY, PackedColorArray(), Vector2(-1, -1), Vector3(0, 0, -1))
		_shoe(f, pal, l, Vector3(x * 1.04, 0.0, -0.17), side)
	hooks.extras(f, "legs", look, pal)
	_tail(f, look, pal)


static func _shoe(f: MeshForge, pal: Dictionary, l: Dictionary, at: Vector3, side: float) -> void:
	var kind: String = l.get("foot", "oxford")
	match kind:
		"bare", "hoof", "claws":
			# 光脚:皮毛色的大脚掌加趾头(蹄子是两趾,三爪带指甲)
			var fur := color(pal, l.get("foot_color", "paw"))
			var toes := 2 if kind == "hoof" else 3
			var shapes := [[at + Vector3(0, 0.035, -0.02), Vector3(0.05, 0.035, 0.075), fur]]
			for i in toes:
				var t := (i - (toes - 1) * 0.5) / maxf(toes - 1, 1)
				shapes.append([at + Vector3(t * 0.045, 0.022, -0.085), Vector3(0.022, 0.02, 0.026), fur])
			paint(f, pal, l.get("foot_color", "paw"), 0.75, FUR)
			f.blob(at + Vector3(0, 0.035, -0.02), shapes, 18, 10, 0.012)
			if kind == "claws":
				paint(f, pal, "nose", 0.4, LEATHER)
				for i in toes:
					var t := (i - (toes - 1) * 0.5) / maxf(toes - 1, 1)
					f.cylinder(0.0, 0.007, 0.018, 6, MeshForge.CAPS_BOTH, xf(at + Vector3(t * 0.045, 0.015, -0.115), Vector3(-90, 0, 0)))
		_:
			# 鞋 / 靴:鞋身扁椭球 + 鞋底;靴子多一截靴筒
			var shoe := color(pal, l.get("shoe", "shoe"))
			paint(f, pal, l.get("shoe", "shoe"), 0.45, LEATHER)
			f.blob(at + Vector3(0, 0.04, -0.03), [[at + Vector3(0, 0.04, -0.03), Vector3(0.05, 0.04, 0.085), shoe],
				[at + Vector3(0, 0.05, 0.02), Vector3(0.048, 0.045, 0.05), shoe]], 18, 10, 0.015)
			paint(f, pal, "sole", 0.8, LEATHER)
			f.box(Vector3(0.1, 0.014, 0.17), xf(at + Vector3(0, 0.007, -0.03)))
			if kind == "boot" or kind == "cowboy":
				paint(f, pal, l.get("shoe", "shoe"), 0.45, LEATHER)
				f.cylinder(0.05, 0.055, 0.14, 12, MeshForge.CAPS_BOTH, xf(at + Vector3(0, 0.12, 0.0)))
			if kind == "spats":
				paint(f, pal, l.get("spats", "cream"), 0.8, CLOTH)
				f.cylinder(0.05, 0.052, 0.07, 12, MeshForge.CAPS_BOTH, xf(at + Vector3(0, 0.075, -0.005)))
			if kind == "cowboy":
				# 马刺
				paint(f, pal, "silver", 0.3, METAL, 1.0)
				f.torus(0.012, 0.02, 10, xf(at + Vector3(0, 0.045, 0.07), Vector3(0, 90, 0)))


static func _tail(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	var t: Dictionary = look.get("tail", {})
	if t.is_empty():
		return
	var path := PackedVector3Array(t["path"])
	var radii := PackedVector2Array()
	var base: float = t.get("radius", 0.03)
	var tip_radius: float = t.get("tip_radius", base * 0.35)
	var colors := PackedColorArray()
	var tip_from: float = t.get("tip_from", 2.0)
	for i in path.size():
		var s := float(i) / (path.size() - 1)
		var bulge: float = t.get("bulge", 0.0)
		var r := lerpf(base, tip_radius, s) + bulge * sin(s * PI)
		radii.append(Vector2(r, r))
		var c := color(pal, t.get("tip", t.get("color", "fur"))) if s >= tip_from else color(pal, t.get("color", "fur"))
		colors.append(Color(c.r, c.g, c.b, 1.0))
	paint(f, pal, t.get("color", "fur"), 0.75, t.get("material", FUR))
	var sway: Vector2 = t.get("sway_range", Vector2(0.35, 1.0))
	f.loft(path, radii, 12, Vector2i(1, 1), Transform3D.IDENTITY, colors, sway)
