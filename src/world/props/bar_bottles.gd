class_name BarBottles
# 酒架上的酒:回转体剖面做出各种剪影——波尔多瓶(高肩)、勃艮第瓶(溜肩)、方肩威士忌瓶、扁方瓶(瓶身捏成圆角长方)、
# 粗陶壶(带把手、上下两色釉)、圆底药水瓶(细长颈)、矮胖的朗姆瓶、宽底的船长醒酒瓶(玻璃塞);
# 朝外的半圈酒标(扁方瓶贴一张平的),软木塞、封蜡或锡箔帽。像真的酒吧那样同款成组地排在三层酒架上。
# 全部合进一个网格、按材质分四个表面(玻璃、酒标、瓶帽、陶器),不投影。坐标为吧台本地。


const KINDS := ["wine", "burgundy", "whiskey", "flask", "jug", "potion", "squat", "decanter"]
const SEGMENTS := 8                  # 瓶身一圈的分段:瓶子在屏幕上只有十来个像素宽
const FLASK_SEGMENTS := 12           # 扁方瓶要捏出圆角,分段多一些
const CAP_SEGMENTS := 6
const LABEL_ARC := TAU * 0.4         # 酒标包住朝外的一段弧
const LABEL_SEGMENTS := 4
const LABEL_LIFT := 0.0012           # 酒标浮出瓶身,避免共面闪烁
const SHELF_X := 0.15                # 瓶子立在搁板上的 x(离墙)
const BAYS := [Vector2(-1.57, -0.05), Vector2(0.05, 1.57)]   # 两格酒架的 z 范围(让开立板)
const SEED := 3131
# 各款:[高度范围, 半径范围, 玻璃色候选, 瓶帽候选, 每组几只]
const STYLES := {
	"wine": [Vector2(0.28, 0.31), Vector2(0.034, 0.036), ["green", "dark_green", "ruby"], ["foil", "cork"], Vector2i(3, 5)],
	"burgundy": [Vector2(0.27, 0.3), Vector2(0.036, 0.038), ["dark_green", "amber", "green"], ["foil", "wax_red"], Vector2i(2, 4)],
	"whiskey": [Vector2(0.26, 0.3), Vector2(0.035, 0.038), ["amber", "brown", "clear"], ["wax_red", "wax_black", "cork"], Vector2i(2, 4)],
	"flask": [Vector2(0.2, 0.24), Vector2(0.04, 0.044), ["clear", "amber", "brown"], ["cork", "foil"], Vector2i(2, 3)],
	"jug": [Vector2(0.2, 0.25), Vector2(0.05, 0.056), ["clear"], ["cork"], Vector2i(1, 2)],
	"potion": [Vector2(0.2, 0.25), Vector2(0.04, 0.045), ["violet", "teal", "blue", "ruby"], ["cork", "wax_green"], Vector2i(2, 3)],
	"squat": [Vector2(0.2, 0.23), Vector2(0.045, 0.05), ["brown", "amber", "dark_green"], ["wax_black", "wax_red"], Vector2i(2, 3)],
	"decanter": [Vector2(0.22, 0.25), Vector2(0.038, 0.042), ["clear", "amber"], ["stopper"], Vector2i(1, 1)],
}
# 摆放时各款被选中的权重
const WEIGHTS := {"wine": 3.0, "burgundy": 2.0, "whiskey": 3.0, "flask": 1.5, "jug": 1.0, "potion": 1.5, "squat": 1.5,
	"decanter": 0.8}
const GLASS := {
	"green": Color(0.22, 0.44, 0.17), "dark_green": Color(0.11, 0.26, 0.11), "amber": Color(0.7, 0.4, 0.1),
	"brown": Color(0.4, 0.21, 0.07), "ruby": Color(0.44, 0.06, 0.08), "clear": Color(0.8, 0.82, 0.78),
	"blue": Color(0.17, 0.28, 0.62), "violet": Color(0.4, 0.18, 0.5), "teal": Color(0.1, 0.5, 0.46),
}
const PAPER := [Color(0.93, 0.87, 0.72), Color(0.96, 0.94, 0.88), Color(0.82, 0.72, 0.52), Color(0.18, 0.15, 0.13),
	Color(0.62, 0.16, 0.11)]
const CAP_COLORS := {"cork": Color(0.7, 0.53, 0.34), "wax_red": Color(0.6, 0.08, 0.06), "wax_black": Color(0.1, 0.09, 0.09),
	"foil": Color(0.8, 0.64, 0.3), "wax_green": Color(0.17, 0.34, 0.17)}
const JUG_GLAZE := [Color(0.42, 0.28, 0.17), Color(0.86, 0.8, 0.66)]   # 下半截褐釉、上半截奶白盐釉


static func add_to(batch: MeshBatch) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for y in BarBack.SHELVES:
		for bay in BAYS:
			_fill_shelf(batch, y, bay, rng)


static func _fill_shelf(batch: MeshBatch, y: float, bay: Vector2, rng: RandomNumberGenerator) -> void:
	# 从一端排到另一端:每次挑一款、排一组同色同高的,组与组之间空一小段
	var z := bay.x + rng.randf_range(0.0, 0.04)
	while true:
		var kind := _pick_kind(rng)
		var style: Array = STYLES[kind]
		var count := rng.randi_range(style[4].x, style[4].y)
		var height := rng.randf_range(style[0].x, style[0].y)
		var radius := rng.randf_range(style[1].x, style[1].y)
		var colors: Array = style[2]
		var caps: Array = style[3]
		var glass: Color = GLASS[colors[rng.randi() % colors.size()]]
		var cap: String = caps[rng.randi() % caps.size()]
		var paper: Color = PAPER[rng.randi() % PAPER.size()]
		var footprint := radius * _footprint(kind)
		for i in count:
			if z + footprint * 2.0 > bay.y:
				return
			var at := Vector3(SHELF_X + rng.randf_range(-0.012, 0.012), y, z + footprint)
			add_bottle(batch, kind, at, height * rng.randf_range(0.98, 1.02), radius, glass, cap, paper, rng)
			z += footprint * 2.0 + rng.randf_range(0.006, 0.016)
		z += rng.randf_range(0.03, 0.09)


static func _pick_kind(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for kind in WEIGHTS:
		total += WEIGHTS[kind]
	var roll := rng.randf() * total
	for kind in WEIGHTS:
		roll -= WEIGHTS[kind]
		if roll <= 0.0:
			return kind
	return KINDS[0]


static func _footprint(kind: String) -> float:
	# 最宽处相对半径(醒酒瓶底座、陶壶的鼓肚与把手更宽)
	match kind:
		"decanter":
			return 1.32
		"jug":
			return 1.35
		"squat", "potion":
			return 1.05
	return 1.0


# —— 一只瓶子 ——

static func add_bottle(batch: MeshBatch, kind: String, at: Vector3, height: float, radius: float, glass: Color,
		cap: String, paper: Color, rng: RandomNumberGenerator) -> void:
	var shape := _shape(kind, height, radius)
	var turn := Vector3(0, rng.randf_range(-25.0, 25.0), 0)
	var seed := rng.randf()
	if kind == "jug":
		batch.add_part(_two_tone(body_arrays(kind, height, radius), height * 0.55), BarMaterials.ceramic(), at, turn)
		_jug_handle(batch, at, height, radius, turn)
	else:
		var fill := 0.0 if rng.randf() < 0.12 else rng.randf_range(0.3, 0.8) * height
		var tint := Color(glass.r, glass.g, glass.b, fill / 0.5)
		batch.add_part(body_arrays(kind, height, radius), BarMaterials.glass(), at, turn, Vector3.ONE, tint, seed)
	if shape.has("label"):
		_label(batch, kind, at, shape["label"], turn, paper, rng.randf())
	_cap(batch, at, shape["neck"], cap, glass, turn)


static func body_arrays(kind: String, height: float, radius: float) -> Array:
	var profile: PackedVector2Array = _shape(kind, height, radius)["profile"]
	if kind != "flask":
		return MeshShapes.lathe(profile, SEGMENTS)
	# 扁方瓶:肩部以下捏成圆角长方形(宽面朝房间之外的两侧,窄面朝前),肩以上仍是圆的瓶颈
	var shoulder := height * 0.7
	return MeshShapes.deform(MeshShapes.lathe(profile, FLASK_SEGMENTS), func(v: Vector3) -> Vector3:
		var flat := 1.0 - smoothstep(shoulder - 0.02, shoulder + 0.02, v.y)
		var d := Vector2(v.x, v.z)
		if d.length() < 0.0001:
			return v
		var a := d.angle()
		var squircle := 1.0 / pow(pow(absf(cos(a)), 4.0) + pow(absf(sin(a)), 4.0), 0.25)
		var target := Vector2(cos(a) * squircle * 0.68, sin(a) * squircle) * d.length() * 0.9
		var p := d.lerp(target, flat)
		return Vector3(p.x, v.y, p.y))


static func _shape(kind: String, h: float, r: float) -> Dictionary:
	# 剖面点 (半径, 高度):从瓶底中心向外、向上、到瓶口收回中心;label = (下沿, 上沿, 半径);neck = (瓶口高, 瓶口半径)
	match kind:
		"burgundy":
			return {"profile": _pts(h, r, [[0, 0], [0.9, 0], [1, 0.025], [1, 0.42], [0.9, 0.56], [0.66, 0.68], [0.4, 0.77],
				[0.31, 0.83], [0.3, 0.94], [0.36, 0.95], [0.36, 0.975], [0, 0.975]]),
				"label": Vector3(0.12 * h, 0.38 * h, r), "neck": Vector2(0.975 * h, 0.3 * r)}
		"whiskey":
			return {"profile": _pts(h, r, [[0, 0], [0.94, 0], [1, 0.02], [1, 0.68], [0.94, 0.73], [0.55, 0.78], [0.38, 0.8],
				[0.36, 0.92], [0.42, 0.93], [0.42, 0.97], [0, 0.97]]),
				"label": Vector3(0.22 * h, 0.55 * h, r), "neck": Vector2(0.97 * h, 0.36 * r)}
		"flask":
			return {"profile": _pts(h, r, [[0, 0], [0.94, 0], [1, 0.03], [1, 0.66], [0.82, 0.74], [0.4, 0.8], [0.32, 0.83],
				[0.3, 0.94], [0.36, 0.95], [0.36, 0.98], [0, 0.98]]),
				"label": Vector3(0.2 * h, 0.52 * h, -r), "neck": Vector2(0.98 * h, 0.3 * r)}
		"jug":
			return {"profile": _pts(h, r, [[0, 0], [0.72, 0], [0.95, 0.08], [1.08, 0.3], [1, 0.55], [0.72, 0.72], [0.36, 0.84],
				[0.3, 0.92], [0.4, 0.95], [0.38, 0.99], [0.26, 0.99], [0.25, 0.95], [0, 0.95]]),
				"neck": Vector2(0.97 * h, 0.25 * r)}
		"potion":
			return {"profile": _pts(h, r, [[0, 0], [0.45, 0.005], [0.85, 0.08], [1.05, 0.22], [1, 0.36], [0.7, 0.47], [0.3, 0.53],
				[0.22, 0.58], [0.2, 0.88], [0.28, 0.9], [0.28, 0.94], [0, 0.94]]),
				"neck": Vector2(0.94 * h, 0.2 * r)}
		"squat":
			return {"profile": _pts(h, r, [[0, 0], [0.95, 0], [1.04, 0.04], [1.05, 0.42], [0.9, 0.56], [0.5, 0.64], [0.35, 0.67],
				[0.33, 0.9], [0.42, 0.92], [0.42, 0.97], [0, 0.97]]),
				"label": Vector3(0.1 * h, 0.38 * h, 1.05 * r), "neck": Vector2(0.97 * h, 0.33 * r)}
		"decanter":
			return {"profile": _pts(h, r, [[0, 0], [1.25, 0], [1.32, 0.03], [1.15, 0.2], [0.75, 0.45], [0.38, 0.6], [0.3, 0.66],
				[0.3, 0.8], [0.42, 0.83], [0.42, 0.85], [0, 0.85]]),
				"neck": Vector2(0.85 * h, 0.3 * r)}
	return {"profile": _pts(h, r, [[0, 0], [0.9, 0], [1, 0.025], [1, 0.6], [0.93, 0.665], [0.62, 0.71], [0.36, 0.75],
		[0.3, 0.8], [0.3, 0.93], [0.36, 0.945], [0.36, 0.97], [0, 0.97]]),
		"label": Vector3(0.18 * h, 0.5 * h, r), "neck": Vector2(0.97 * h, 0.3 * r)}


static func _pts(h: float, r: float, rel: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in rel:
		out.append(Vector2(p[0] * r, p[1] * h))
	return out


# —— 酒标、瓶帽、把手 ——

static func _label(batch: MeshBatch, kind: String, at: Vector3, band: Vector3, turn: Vector3, paper: Color,
		seed: float) -> void:
	# 半圈酒标:部件坐标从 0 量到酒标高度(着色器据此画边框与字),alpha = 酒标高度 / 0.2 米
	var height := band.y - band.x
	var tint := Color(paper.r, paper.g, paper.b, height / 0.2)
	if kind == "flask":
		var arrays := _flat_label(absf(band.z) * 1.15, height)
		batch.add_part(arrays, BarMaterials.label(), at + Vector3(0, band.x, 0), turn + Vector3(0, 90, 0), Vector3.ONE, tint, seed)
		return
	var r := band.z + LABEL_LIFT
	var arrays := MeshShapes.lathe(PackedVector2Array([Vector2(r, 0.0), Vector2(r, height)]), LABEL_SEGMENTS, LABEL_ARC)
	batch.add_part(arrays, BarMaterials.label(), at + Vector3(0, band.x, 0), turn + Vector3(0, rad_to_deg(LABEL_ARC / 2.0), 0),
		Vector3.ONE, tint, seed)


static func _flat_label(width: float, height: float) -> Array:
	# 扁方瓶正面一张平贴的酒标(朝部件 +Z;贴在宽面上,宽面在捏扁前的半径 × 0.9 处)
	var z := 0.0
	var verts := PackedVector3Array([Vector3(-width / 2.0, 0, z), Vector3(width / 2.0, 0, z), Vector3(width / 2.0, height, z),
		Vector3(-width / 2.0, height, z)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 0, 3, 2])
	return arrays


static func _cap(batch: MeshBatch, at: Vector3, neck: Vector2, style: String, glass: Color, turn: Vector3) -> void:
	var rn := neck.y
	var top := at + Vector3(0, neck.x, 0)
	if style == "stopper":
		batch.add_part(MeshKit.sphere(rn * 1.7, 8), BarMaterials.glass(), top + Vector3(0, rn * 1.4, 0), turn,
			Vector3(1, 1.15, 1), Color(glass.r, glass.g, glass.b, 0.0))
		return
	var profile: PackedVector2Array
	match style:
		"cork":
			profile = PackedVector2Array([Vector2(0, -0.006), Vector2(rn * 0.95, -0.006), Vector2(rn * 1.04, 0.016),
				Vector2(rn * 0.9, 0.022), Vector2(0, 0.022)])
		"foil":
			profile = PackedVector2Array([Vector2(rn * 1.12, -0.05), Vector2(rn * 1.12, 0.002), Vector2(rn * 0.6, 0.006),
				Vector2(0, 0.006)])
		_:
			profile = PackedVector2Array([Vector2(rn * 1.3, -0.034), Vector2(rn * 1.14, -0.028), Vector2(rn * 1.1, 0.002),
				Vector2(rn * 0.7, 0.009), Vector2(0, 0.01)])
	batch.add_part(MeshShapes.lathe(profile, CAP_SEGMENTS), BarMaterials.cap(), top, turn, Vector3.ONE, CAP_COLORS[style])


static func _jug_handle(batch: MeshBatch, at: Vector3, h: float, r: float, turn: Vector3) -> void:
	# 侧面的环形把手(朝 +Z,从侧面看得到剪影)
	var path := PackedVector3Array([Vector3(0, 0.66 * h, 0.9 * r), Vector3(0, 0.7 * h, 1.3 * r), Vector3(0, 0.6 * h, 1.55 * r),
		Vector3(0, 0.42 * h, 1.45 * r), Vector3(0, 0.3 * h, 1.05 * r)])
	var basis := Basis.from_euler(Vector3(0, deg_to_rad(turn.y), 0))
	var moved := PackedVector3Array()
	for p in path:
		moved.append(at + basis * p)
	batch.add_part(MeshShapes.tube(moved, 0.008, 6), BarMaterials.ceramic(), Vector3.ZERO, Vector3.ZERO, Vector3.ONE,
		JUG_GLAZE[1])


static func _two_tone(arrays: Array, split: float) -> Array:
	# 上下两色釉:分界处略微过渡
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	for v in verts:
		colors.append(JUG_GLAZE[0].lerp(JUG_GLAZE[1], smoothstep(split - 0.01, split + 0.01, v.y)))
	var out := arrays.duplicate()
	out[Mesh.ARRAY_COLOR] = colors
	return out
