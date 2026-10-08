class_name PatronParts
# 酒客的静态部件:物种外观表与各部件的合批配方(MeshForge)。每个动画枢轴下的静态零件合成一份共享网格,
# 按「物种:部件」缓存;耳朵、帽子的枢轴变换也在这里。动画逻辑在 Patron 中。


const SPECIES := [
	{
		"id": "fox", "label": "狐狸",
		"fur": Color(0.86, 0.4, 0.13), "muzzle": Color(0.96, 0.9, 0.8), "dark": Color(0.18, 0.08, 0.04),
		"coat": Color(0.13, 0.17, 0.3), "accent": Color(0.82, 0.62, 0.25), "hat": "top", "ears": "pointy",
	},
	{
		"id": "bear", "label": "熊",
		"fur": Color(0.36, 0.21, 0.11), "muzzle": Color(0.66, 0.5, 0.34), "dark": Color(0.12, 0.07, 0.04),
		"coat": Color(0.42, 0.11, 0.09), "accent": Color(0.86, 0.76, 0.52), "hat": "bowler", "ears": "round",
	},
	{
		"id": "pig", "label": "猪",
		"fur": Color(0.93, 0.6, 0.58), "muzzle": Color(0.98, 0.68, 0.66), "dark": Color(0.45, 0.2, 0.2),
		"coat": Color(0.2, 0.3, 0.17), "accent": Color(0.85, 0.3, 0.22), "hat": "cap", "ears": "floppy",
	},
	{
		"id": "cat", "label": "猫",
		"fur": Color(0.46, 0.47, 0.52), "muzzle": Color(0.88, 0.87, 0.85), "dark": Color(0.1, 0.1, 0.12),
		"coat": Color(0.3, 0.22, 0.38), "accent": Color(0.42, 0.66, 0.72), "hat": "cowboy", "ears": "cat",
	},
]


static func species(index: int) -> Dictionary:
	return SPECIES[posmod(index, SPECIES.size())]


static func first_free_species(used: Array) -> int:
	# 新酒客取第一个没人用的物种,同桌不撞脸;物种全被占用(人数超过物种数)时才轮流重复
	for i in SPECIES.size():
		if not used.has(i):
			return i
	return posmod(used.size(), SPECIES.size())


# —— 调色板:部件键 → [sRGB 颜色, 粗糙度, 金属度] ——

const NOSE := Color(0.05, 0.04, 0.04)
const EYE_WHITE := Color(0.97, 0.96, 0.93)
const PUPIL := Color(0.03, 0.03, 0.04)
const BRASS := Color(0.78, 0.56, 0.24)   # = WorldMaterials.brass()
const LAPEL_DARKEN := 0.35   # 翻领用压暗的外套色:浅色强调色做翻领会在胸前拼出一个突兀的「A」字


static func palette(spec: Dictionary) -> Dictionary:
	return {
		"fur": [spec["fur"], 0.75, 0.0], "muzzle": [spec["muzzle"], 0.8, 0.0], "dark": [spec["dark"], 0.6, 0.0],
		"coat": [spec["coat"], 0.85, 0.0], "accent": [spec["accent"], 0.5, 0.0],
		"nose": [NOSE, 0.15, 0.0], "white": [EYE_WHITE, 0.25, 0.0], "pupil": [PUPIL, 0.1, 0.0],
		"hat": [spec["dark"].darkened(0.4), 0.7, 0.0], "lapel": [spec["coat"].darkened(LAPEL_DARKEN), 0.8, 0.0],
		"brass": [BRASS, 0.32, 1.0],
	}


static func _paint(f: MeshForge, pal: Dictionary, key: String) -> void:
	f.paint(pal[key][0], pal[key][1], pal[key][2])


static func _xf(pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	return MeshForge.xf(pos, rot_deg, scale)


# —— 共享网格 ——

static func part_mesh(spec: Dictionary, part: String, recipe: Callable) -> ArrayMesh:
	# 酒客部件网格:按「物种:部件」缓存,所有酒客共用 WorldMaterials.patron()
	return MeshForge.cached("patron:%s:%s" % [spec["id"], part], recipe, {&"main": WorldMaterials.patron()})


static func shared_mesh(part: String, recipe: Callable) -> ArrayMesh:
	# 与物种无关的部件(眼白、瞳孔、× 标记)
	return MeshForge.cached("patron:any:" + part, recipe, {&"main": WorldMaterials.patron()})


static func chair_mesh() -> ArrayMesh:
	return MeshForge.cached("chair", chair_recipe, {&"main": WorldMaterials.wood("dark", true)})


static func chair_recipe(f: MeshForge) -> void:
	f.part_space = true   # 木纹按每根木件自己的局部坐标算,和合并前一样
	f.box(Vector3(0.48, 0.05, 0.44), _xf(Vector3(0, 0.45, 0.14)))
	for x in [-0.2, 0.2]:
		for z in [-0.04, 0.32]:
			f.cylinder(0.02, 0.018, 0.45, 8, MeshForge.CAPS_BOTH, _xf(Vector3(x, 0.225, z)))
		f.cylinder(0.022, 0.022, 0.62, 8, MeshForge.CAPS_BOTH, _xf(Vector3(x, 0.76, 0.34)))
		f.sphere(0.03, 10, _xf(Vector3(x, 1.08, 0.34)))
	f.box(Vector3(0.44, 0.09, 0.035), _xf(Vector3(0, 1.0, 0.34)))
	for x in [-0.1, 0.0, 0.1]:
		f.box(Vector3(0.035, 0.42, 0.02), _xf(Vector3(x, 0.74, 0.34)))


# —— 配方(坐标与合并前的 MeshKit.add 一一对应)——

static func body_recipe(f: MeshForge, pal: Dictionary) -> void:
	_paint(f, pal, "coat")
	f.capsule(0.2, 0.62, 20, _xf(Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1, 1, 0.85)))
	f.sphere(0.19, 20, _xf(Vector3(0, 0.12, -0.05), Vector3.ZERO, Vector3(1.05, 0.85, 0.95)))
	# 衬衫前襟 + 领结
	_paint(f, pal, "white")
	f.sphere(0.09, 16, _xf(Vector3(0, 0.43, -0.15), Vector3(-10, 0, 0), Vector3(0.75, 1.15, 0.35)))
	_paint(f, pal, "accent")
	for side in [-1.0, 1.0]:
		f.prism(Vector3(0.05, 0.05, 0.02), _xf(Vector3(0.026 * side, 0.535, -0.175), Vector3(-10, 0, -90 * side)))
	f.sphere(0.013, 8, _xf(Vector3(0, 0.535, -0.18)))
	_paint(f, pal, "lapel")
	for side in [-1.0, 1.0]:
		f.box(Vector3(0.05, 0.24, 0.02), _xf(Vector3(0.06 * side, 0.43, -0.17), Vector3(-8, 0, 18 * side)))
	_paint(f, pal, "brass")
	for y in [0.3, 0.2, 0.1]:
		f.sphere(0.014, 8, _xf(Vector3(0, y, -0.205 + (0.3 - y) * 0.15)))
	# 宽肩 + 领口
	_paint(f, pal, "coat")
	f.sphere(0.2, 20, _xf(Vector3(0, 0.47, -0.01), Vector3.ZERO, Vector3(1.22, 0.55, 0.85)))
	f.torus(0.075, 0.1, 24, _xf(Vector3(0, 0.565, -0.02)))


static func neck_recipe(f: MeshForge, pal: Dictionary) -> void:
	# 单位高的圆柱(y 从 0 到 1),Patron 每帧按领口到头的距离拉长
	_paint(f, pal, "fur")
	f.cylinder(0.075, 0.085, 1.0, 16, MeshForge.CAPS_BOTH, _xf(Vector3(0, 0.5, 0)))


static func head_recipe(f: MeshForge, pal: Dictionary, spec: Dictionary) -> void:
	_paint(f, pal, "fur")
	f.sphere(0.17, 28, _xf(Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1, 0.95, 1)))
	_paint(f, pal, "muzzle")
	f.sphere(0.12, 20, _xf(Vector3(0, 0.08, -0.07), Vector3.ZERO, Vector3(1.05, 0.8, 0.9)))
	if spec["id"] == "pig":
		f.cylinder(0.056, 0.06, 0.06, 20, MeshForge.CAPS_BOTH, _xf(Vector3(0, 0.075, -0.17), Vector3(90, 0, 0)))
		_paint(f, pal, "dark")
		for side in [-1.0, 1.0]:
			f.sphere(0.013, 8, _xf(Vector3(0.02 * side, 0.075, -0.2), Vector3.ZERO, Vector3(1, 1.4, 0.5)))
		return
	var length := 1.25 if spec["id"] == "fox" else 0.9
	f.sphere(0.085, 18, _xf(Vector3(0, 0.07, -0.13), Vector3.ZERO, Vector3(1.1, 0.78, length)))
	_paint(f, pal, "nose")
	f.sphere(0.026, 12, _xf(Vector3(0, 0.1, -0.13 - 0.085 * length)))
	_paint(f, pal, "dark")
	f.box(Vector3(0.05, 0.006, 0.01), _xf(Vector3(0, 0.035, -0.19)))
	if spec["id"] == "cat":
		_paint(f, pal, "muzzle")
		for side in [-1.0, 1.0]:
			for k in 2:
				f.cylinder(0.0015, 0.0015, 0.12, 4, MeshForge.CAPS_BOTH,
					_xf(Vector3(0.09 * side, 0.07 - k * 0.02, -0.16), Vector3(0, 0, 90 + (8 - k * 16) * side)))


static func eye_white_recipe(f: MeshForge) -> void:
	f.paint(EYE_WHITE, 0.25)
	f.sphere(0.042, 18, _xf(Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.1, 0.8)))


static func pupil_recipe(f: MeshForge) -> void:
	f.paint(PUPIL, 0.1)
	f.sphere(0.021, 12)


static func marks_recipe(f: MeshForge) -> void:
	# 出局时的 × 眼
	f.paint(PUPIL, 0.1)
	for angle in [45.0, -45.0]:
		f.box(Vector3(0.055, 0.009, 0.01), _xf(Vector3.ZERO, Vector3(0, 0, angle)))


static func brow_recipe(f: MeshForge, pal: Dictionary) -> void:
	_paint(f, pal, "dark")
	f.box(Vector3(0.062, 0.013, 0.018))


static func arm_recipe(f: MeshForge, pal: Dictionary) -> void:
	# 手臂沿 -Z 伸出 ARM_LENGTH;左右两只几何相同
	_paint(f, pal, "coat")
	f.sphere(0.07, 14)
	f.capsule(0.055, 0.4, 20, _xf(Vector3(0, 0, -0.2), Vector3(90, 0, 0)))
	_paint(f, pal, "muzzle")
	f.cylinder(0.06, 0.06, 0.05, 16, MeshForge.CAPS_BOTH, _xf(Vector3(0, 0, -0.36), Vector3(90, 0, 0)))


static func paw_recipe(f: MeshForge, pal: Dictionary, radius: float, scale: Vector3) -> void:
	_paint(f, pal, "fur")
	f.sphere(radius, 16, _xf(Vector3.ZERO, Vector3.ZERO, scale))


static func ear_recipe(f: MeshForge, pal: Dictionary, kind: String) -> void:
	# 耳朵枢轴空间里的几何(左右两只相同,枢轴变换见 ear_pivot)
	match kind:
		"pointy":
			_paint(f, pal, "fur")
			f.cylinder(0.0, 0.055, 0.15, 12, MeshForge.CAPS_BOTH, _xf(Vector3(0, 0.05, 0)))
			_paint(f, pal, "dark")
			f.cylinder(0.0, 0.032, 0.09, 10, MeshForge.CAPS_BOTH, _xf(Vector3(0, 0.035, -0.022)))
		"round":
			_paint(f, pal, "fur")
			f.sphere(0.058, 14, _xf(Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.55)))
			_paint(f, pal, "dark")
			f.sphere(0.034, 12, _xf(Vector3(0, -0.004, -0.02), Vector3.ZERO, Vector3(1, 1, 0.4)))
		"floppy":
			_paint(f, pal, "fur")
			f.prism(Vector3(0.1, 0.11, 0.02), _xf(Vector3(0, 0.05, 0)))
		"cat":
			_paint(f, pal, "fur")
			f.cylinder(0.0, 0.058, 0.1, 4, MeshForge.CAPS_BOTH, _xf(Vector3(0, 0.035, 0), Vector3(0, 45, 0)))
			_paint(f, pal, "dark")
			f.cylinder(0.0, 0.034, 0.06, 4, MeshForge.CAPS_BOTH, _xf(Vector3(0, 0.022, -0.018), Vector3(0, 45, 0)))


static func ear_pivot(kind: String, side: float) -> Transform3D:
	# 耳朵枢轴在头上的位置与朝向(抖耳朵动画转它的 rotation.x)
	match kind:
		"pointy":
			return _xf(Vector3(0.1 * side, 0.25, 0.0), Vector3(0, 0, -22 * side))
		"round":
			return _xf(Vector3(0.12 * side, 0.24, 0.01))
		"floppy":
			return _xf(Vector3(0.11 * side, 0.24, -0.02), Vector3(-55, 0, -30 * side))
		"cat":
			return _xf(Vector3(0.1 * side, 0.25, 0.0), Vector3(0, 0, -14 * side))
	return _xf(Vector3(0.1 * side, 0.25, 0.0))


static func hat_recipe(f: MeshForge, pal: Dictionary, kind: String) -> void:
	match kind:
		"top":
			_paint(f, pal, "hat")
			f.cylinder(0.17, 0.17, 0.012, 32)
			f.cylinder(0.105, 0.098, 0.2, 32, MeshForge.CAPS_BOTH, _xf(Vector3(0, 0.1, 0)))
			_paint(f, pal, "accent")
			f.cylinder(0.101, 0.101, 0.03, 32, MeshForge.CAPS_BOTH, _xf(Vector3(0, 0.025, 0)))
		"bowler":
			_paint(f, pal, "hat")
			f.cylinder(0.16, 0.16, 0.012, 32)
			f.hemisphere(0.115, 24, _xf(Vector3(0, 0.006, 0), Vector3.ZERO, Vector3(1, 1.15, 1)))
			_paint(f, pal, "accent")
			f.cylinder(0.117, 0.117, 0.025, 32, MeshForge.CAPS_BOTH, _xf(Vector3(0, 0.02, 0)))
		"cowboy":
			_paint(f, pal, "hat")
			f.cylinder(0.25, 0.25, 0.012, 32, MeshForge.CAPS_BOTH, _xf(Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.82)))
			f.torus(0.22, 0.255, 32, _xf(Vector3(0, 0.012, 0), Vector3.ZERO, Vector3(1, 0.8, 0.82)))
			f.cylinder(0.075, 0.11, 0.14, 24, MeshForge.CAPS_BOTH, _xf(Vector3(0, 0.07, 0)))
			_paint(f, pal, "accent")
			f.cylinder(0.106, 0.112, 0.028, 24, MeshForge.CAPS_BOTH, _xf(Vector3(0, 0.02, 0)))
		"cap":
			_paint(f, pal, "hat")
			f.hemisphere(0.16, 24, _xf(Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(1.05, 0.45, 1.1)))
			f.cylinder(0.11, 0.11, 0.012, 24, MeshForge.CAPS_BOTH, _xf(Vector3(0, -0.012, -0.12), Vector3.ZERO, Vector3(1, 1, 0.55)))
			_paint(f, pal, "accent")
			f.sphere(0.018, 10, _xf(Vector3(0, 0.055, 0)))


static func hat_pivot(kind: String) -> Transform3D:
	return _xf(Vector3(0, 0.255, 0.01), Vector3(-10, 0, -6) if kind == "cap" else Vector3(-6, 0, 9))
