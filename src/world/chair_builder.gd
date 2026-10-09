class_name ChairBuilder
# 酒客的椅子:车削温莎椅(圆润鞍形座面、收腰圆头的车削腿与靠背柱、三根纺锤靠背杆、弧形顶梁、腿间横撑)。
# 所有酒客与主菜单空椅子共用一份网格(自动实例化),木纹按每根木件自己的方向走。
# 布局尺寸沿用旧椅子(尾巴走法、测试、出局姿势都依赖它们),公开成常量。
# 动森式(2026-10-08):腿、柱、纺锤杆、横撑和顶梁都加粗,柱头圆球更大,像胖胖的玩具椅;布局尺寸不变。

const SEAT_Y := Vector2(0.425, 0.475)    # 座面底、座面顶
const SEAT_HALF_X := 0.24
const SEAT_Z := Vector2(-0.08, 0.36)
const FRONT_LEG_Z := -0.04
const BACK_LEG_Z := 0.32
const LEG_X := 0.2
const LEG_RADIUS := 0.026
const POST_Z := 0.34                     # 靠背柱
const BACK_GAP_TOP := 0.53               # 靠背杆底端:座面与靠背之间留 5.5 cm 的缝(细尾巴从这里穿出)
const TOP := 1.1
const GRAIN_ALONG_Y := Basis(Vector3.BACK, PI / 2.0)   # 把部件的竖直方向转到木纹方向(预设 dark 的纹理沿 X)


static func mesh() -> ArrayMesh:
	return MeshForge.cached("chair", recipe, {&"main": WorldMaterials.wood("dark", true)})


static func recipe(f: MeshForge) -> void:
	f.part_space = true
	# 座面:扁椭球平滑并集,前缘圆、后部略微兜起
	f.part_basis = Basis.IDENTITY
	f.seed = 0.1
	var seat_mid := (SEAT_Y.x + SEAT_Y.y) * 0.5
	var half := (SEAT_Y.y - SEAT_Y.x) * 0.5
	f.blob(Vector3(0, seat_mid, 0.14), [[Vector3(0, seat_mid, 0.14), Vector3(SEAT_HALF_X, half, 0.22), Color.WHITE],
		[Vector3(0, seat_mid + 0.004, 0.3), Vector3(0.2, half * 0.9, 0.07), Color.WHITE]], 20, 8, 0.012)
	# 四条车削腿与横撑
	f.part_basis = GRAIN_ALONG_Y
	for x in [-LEG_X, LEG_X]:
		for z in [FRONT_LEG_Z, BACK_LEG_Z]:
			f.seed = 0.2 + x + z
			f.lathe(_turned(SEAT_Y.x + 0.002, 0.02, LEG_RADIUS), 7, PackedInt32Array(), MeshForge.xf(Vector3(x, 0, z)))
		f.seed = 0.4 + x
		f.cylinder(0.013, 0.013, BACK_LEG_Z - FRONT_LEG_Z, 8, MeshForge.CAPS_NONE,
			MeshForge.xf(Vector3(x, 0.16, (FRONT_LEG_Z + BACK_LEG_Z) * 0.5), Vector3(90, 0, 0)))
	f.seed = 0.5
	f.cylinder(0.013, 0.013, LEG_X * 2.0, 8, MeshForge.CAPS_NONE, MeshForge.xf(Vector3(0, 0.2, (FRONT_LEG_Z + BACK_LEG_Z) * 0.5), Vector3(0, 0, 90)))
	# 靠背柱(顶端圆头)与三根纺锤杆
	for x in [-LEG_X, LEG_X]:
		f.seed = 0.6 + x
		var post := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.024, 0.0), Vector2(0.02, 0.3),
			Vector2(0.024, 0.5), Vector2(0.02, 0.55), Vector2(0.0, 0.55)])
		f.lathe(post, 8, PackedInt32Array(), MeshForge.xf(Vector3(x, SEAT_Y.y - 0.02, POST_Z)))
		f.sphere(0.034, 6, MeshForge.xf(Vector3(x, SEAT_Y.y + 0.56, POST_Z)))
	for x in [-0.1, 0.0, 0.1]:
		f.seed = 0.8 + x
		var spindle := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.011, 0.0), Vector2(0.017, 0.2), Vector2(0.011, 0.44),
			Vector2(0.0, 0.44)])
		f.lathe(spindle, 6, PackedInt32Array(), MeshForge.xf(Vector3(x, BACK_GAP_TOP, POST_Z + 0.005)))
	# 弧形顶梁:两柱之间往后弯
	f.part_basis = Basis.IDENTITY
	f.seed = 0.9
	var rail := PackedVector3Array()
	var radii := PackedVector2Array()
	for i in 5:
		var t := i / 4.0
		rail.append(Vector3(lerpf(-LEG_X - 0.02, LEG_X + 0.02, t), 0.995 + sin(t * PI) * 0.012, POST_Z + 0.004 + sin(t * PI) * 0.03))
		radii.append(Vector2(0.05, 0.022))
	f.loft(rail, radii, 6, Vector2i(1, 1), Transform3D.IDENTITY, PackedColorArray(), Vector2(-1, -1), Vector3.UP)


static func _turned(height: float, thin: float, thick: float) -> PackedVector2Array:
	# 车削腿的轮廓(自下而上):脚头、收腰、鼓腹、颈、顶端
	return PackedVector2Array([Vector2(0.0, 0.0), Vector2(thin * 1.1, 0.0), Vector2(thin * 0.85, height * 0.25),
		Vector2(thick, height * 0.5), Vector2(thin * 0.9, height * 0.8), Vector2(thick * 0.85, height), Vector2(0.0, height)])


static func solids() -> Array:
	# 给「不穿椅子」的测试:[["box", 中心, 半尺寸] 或 ["cyl", 底中心, 半径, 高]]
	var out := [["box", Vector3(0, (SEAT_Y.x + SEAT_Y.y) * 0.5, (SEAT_Z.x + SEAT_Z.y) * 0.5),
		Vector3(SEAT_HALF_X, (SEAT_Y.y - SEAT_Y.x) * 0.5, (SEAT_Z.y - SEAT_Z.x) * 0.5)]]
	for x in [-LEG_X, LEG_X]:
		for z in [FRONT_LEG_Z, BACK_LEG_Z]:
			out.append(["cyl", Vector3(x, 0, z), LEG_RADIUS, SEAT_Y.x])
		out.append(["cyl", Vector3(x, SEAT_Y.y, POST_Z), LEG_RADIUS, TOP - SEAT_Y.y])
	out.append(["box", Vector3(0, (BACK_GAP_TOP + TOP) * 0.5, POST_Z), Vector3(0.12, (TOP - BACK_GAP_TOP) * 0.5, 0.015)])
	return out
