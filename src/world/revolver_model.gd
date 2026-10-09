class_name RevolverModel
# 左轮的静态网格,按"投不投影"分批合并、按 key 缓存(四把枪、每局重建都共用同一份,对局中不再拼装):
#   frame  机匣、顶梁、护盾、枪管、退壳杆套筒、握把芯与象牙握把片——投射阴影;
#   trim   扳机护圈、扳机、准星、螺丝、转轮轴、徽章、枪口膛线这类小件——不投影;
#   hammer 击锤(击锤尖带防滑齿)——小件,不投影。转轮见 RevolverDrum。
# 整把枪共用一份材质(revolver_finish.gdshader),每批一个表面;部件的表面工艺写在顶点色里(tint)。
# 侧面轮廓按 (f, y) 给出:f = 向前的距离(= -z),y 向上;拉伸厚度沿 X(枪的左右)。原点在握把。

enum Finish { BLUED, CASE, BRASS, BRIGHT, BORE, IVORY }

const SHADER := preload("res://src/world/shaders/revolver_finish.gdshader")
const FINISH_STEPS := 8.0                # 与着色器一致:顶点色 alpha = 工艺编号 / 8
const SIDE_ROT := Vector3(0, 90, 0)      # 侧面轮廓(XY 平面)转到枪身:X → 向前,拉伸方向 → 枪的左右
const AXIAL_ROT := Vector3(-90, 0, 0)    # 绕 Y 的回转体转到沿枪管方向:剖面高度 → 向前
const BARREL_Y := 0.058                  # 枪管轴线高度(= Revolver3D.MUZZLE_POS.y)
const DRUM_AXIS_Y := 0.045               # 转轮轴高度(= Revolver3D.DRUM_POS.y)
const BARREL_SEGMENTS := 20
const SMALL_SEGMENTS := 10
# 各部件的半宽(米)与拉伸倒角
const FRAME_HALF := 0.0092
const STRAP_HALF := 0.007        # 顶梁比机匣窄,前端搭在前柱上,两侧露出一道台阶
const GRIP_HALF := 0.0062        # 握把芯(黄铜前带、背带):比机匣窄得多,两侧主要是握把片,芯只露出一道边
const GUARD_HALF := 0.0058
const TRIGGER_HALF := 0.0026
const HAMMER_HALF := 0.0042
const SIGHT_HALF := 0.0012
const PANEL_HEIGHT := 0.0098     # 握把片鼓起的高度(传给着色器,边缘泛黄按它归一)
const PANEL_RINGS := [1.0, 0.97, 0.91, 0.82, 0.68, 0.5, 0.28]
const PANEL_CENTER := Vector2(-0.034, -0.026)
# 握把下半截按"犁柄"往后弯:以握把根部为轴,越往下转得越多(GRIP_RAKE_DEG);同时略缩短,抵消后弯带来的加长
const GRIP_PIVOT := Vector2(-0.022, 0.012)
const GRIP_RAKE_DEG := 4.0
const GRIP_BEND_SPAN := 0.04     # 从握把根部往下这么远转满
const GRIP_SQUASH := 0.9
const EJECTOR_AT := Vector2(0.0068, 0.0478)   # 退壳杆套筒轴线的 (x, y):枪管右下方
const EJECTOR_RADIUS := 0.0042

# 机匣:前柱 + 转轮窗口 + 后部(击锤座),窗口顶上由顶梁封住
const FRAME_OUTLINE := [
	Vector2(-0.010, 0.0118), Vector2(0.046, 0.0118),
	Vector2(0.054, 0.0128), Vector2(0.0615, 0.0158), Vector2(0.0675, 0.0208), Vector2(0.0715, 0.0268),
	Vector2(0.0738, 0.032), Vector2(0.0745, 0.0352),
	Vector2(0.0745, 0.0712), Vector2(0.0573, 0.0712),
	Vector2(0.0573, 0.0213), Vector2(0.0105, 0.0213), Vector2(0.0105, 0.0712),
	Vector2(-0.004, 0.0712), Vector2(-0.008, 0.0735), Vector2(-0.014, 0.0738), Vector2(-0.020, 0.0730),
	Vector2(-0.026, 0.0715), Vector2(-0.0305, 0.0688), Vector2(-0.0335, 0.0645), Vector2(-0.0348, 0.0595),
	Vector2(-0.0346, 0.054), Vector2(-0.0335, 0.046), Vector2(-0.031, 0.036), Vector2(-0.0265, 0.026),
	Vector2(-0.020, 0.017),
]
const STRAP_OUTLINE := [
	Vector2(-0.004, 0.0688), Vector2(0.0738, 0.0688), Vector2(0.0741, 0.0745), Vector2(0.0731, 0.0776),
	Vector2(0.0706, 0.0792), Vector2(0.0673, 0.0797), Vector2(0.008, 0.0797), Vector2(0.0025, 0.0791),
	Vector2(-0.003, 0.0774), Vector2(-0.0075, 0.0752), Vector2(-0.0098, 0.0736),
]
# 回转体剖面 (半径, f)
const SHIELD_PROFILE := [
	Vector2(0.0, -0.0025), Vector2(0.0158, -0.0025), Vector2(0.0188, -0.0019), Vector2(0.0204, -0.0004),
	Vector2(0.021, 0.0018), Vector2(0.021, 0.0118), Vector2(0.021, 0.0118), Vector2(0.0, 0.0118),
]
const COLLAR_PROFILE := [Vector2(0.0106, 0.0738), Vector2(0.0106, 0.0764), Vector2(0.0099, 0.0776), Vector2(0.0086, 0.0778)]
const BARREL_PROFILE := [
	Vector2(0.0088, 0.070), Vector2(0.0086, 0.14), Vector2(0.0084, 0.2115), Vector2(0.0087, 0.2175),
	Vector2(0.0092, 0.2208), Vector2(0.0094, 0.2245), Vector2(0.0093, 0.2298), Vector2(0.0089, 0.2332),
	Vector2(0.0081, 0.2348), Vector2(0.0072, 0.235), Vector2(0.0055, 0.235), Vector2(0.0055, 0.235),
	Vector2(0.0047, 0.2342),
]
const MUZZLE_BORE_PROFILE := [Vector2(0.0047, 0.2342), Vector2(0.0047, 0.222), Vector2(0.0, 0.222)]
const EJECTOR_PROFILE := [
	Vector2(0.0042, 0.071), Vector2(0.0042, 0.1455), Vector2(0.004, 0.1492), Vector2(0.0033, 0.1518),
	Vector2(0.0021, 0.1533), Vector2(0.0, 0.1537),
]
const PIN_PROFILE := [
	Vector2(0.0024, 0.054), Vector2(0.0024, 0.0748), Vector2(0.0031, 0.0752), Vector2(0.0034, 0.0758),
	Vector2(0.0034, 0.0806), Vector2(0.0029, 0.0814), Vector2(0.0, 0.0816),
]
# 握把芯:前带往下 → 握把底 → 犁柄形的背带往上 → 击锤后方的背带上端 → 埋进机匣
const GRIP_OUTLINE := [
	Vector2(-0.004, 0.0135), Vector2(-0.0055, 0.004), Vector2(-0.0085, -0.010), Vector2(-0.0125, -0.026),
	Vector2(-0.0165, -0.042), Vector2(-0.020, -0.056), Vector2(-0.0225, -0.066), Vector2(-0.0238, -0.0712),
	Vector2(-0.0262, -0.0746), Vector2(-0.032, -0.0772), Vector2(-0.040, -0.0788), Vector2(-0.048, -0.0792),
	Vector2(-0.0545, -0.0782), Vector2(-0.0592, -0.0752), Vector2(-0.0612, -0.0705), Vector2(-0.0605, -0.060),
	Vector2(-0.0575, -0.045), Vector2(-0.053, -0.028), Vector2(-0.048, -0.010), Vector2(-0.0435, 0.008),
	Vector2(-0.040, 0.026), Vector2(-0.0378, 0.042), Vector2(-0.0368, 0.050), Vector2(-0.0358, 0.0555),
	Vector2(-0.034, 0.0582), Vector2(-0.0318, 0.0575), Vector2(-0.026, 0.050), Vector2(-0.018, 0.034),
	Vector2(-0.010, 0.020),
]
const PANEL_OUTLINE := [
	Vector2(-0.0085, 0.0095), Vector2(-0.0108, -0.004), Vector2(-0.0142, -0.022), Vector2(-0.0178, -0.040),
	Vector2(-0.0212, -0.056), Vector2(-0.0236, -0.0655), Vector2(-0.0262, -0.0708), Vector2(-0.031, -0.074),
	Vector2(-0.040, -0.0757), Vector2(-0.048, -0.0761), Vector2(-0.0535, -0.0751), Vector2(-0.0568, -0.0722),
	Vector2(-0.0578, -0.064), Vector2(-0.0556, -0.048), Vector2(-0.0513, -0.031), Vector2(-0.0464, -0.013),
	Vector2(-0.042, 0.004), Vector2(-0.0386, 0.019), Vector2(-0.0362, 0.0275), Vector2(-0.0318, 0.0292),
	Vector2(-0.0272, 0.0262), Vector2(-0.0228, 0.0198), Vector2(-0.0168, 0.0142), Vector2(-0.0118, 0.011),
]
# 扳机护圈:机匣底面下方的半个椭圆环,前端顶住机匣前部,后端并入握把前带
const GUARD_CENTER := Vector2(0.0197, 0.0128)
const GUARD_OUTER := Vector2(0.0265, 0.031)
const GUARD_INNER := Vector2(0.0222, 0.0266)
const GUARD_STEPS := 18
const TRIGGER_OUTLINE := [
	Vector2(0.016, 0.0135), Vector2(0.0158, 0.0065), Vector2(0.0148, 0.0005), Vector2(0.0128, -0.0052),
	Vector2(0.0105, -0.0095), Vector2(0.0125, -0.0098), Vector2(0.0165, -0.0062), Vector2(0.0195, -0.0005),
	Vector2(0.0208, 0.006), Vector2(0.0205, 0.0135),
]
const SIGHT_OUTLINE := [
	Vector2(0.2105, 0.0655), Vector2(0.2272, 0.0655), Vector2(0.2266, 0.0688), Vector2(0.2245, 0.0712),
	Vector2(0.2205, 0.0724), Vector2(0.2165, 0.0722), Vector2(0.2128, 0.0704), Vector2(0.2108, 0.0678),
]
# 螺丝:[(f, y), 所在表面的半宽, 左右(-1 左 / 1 右 / 0 两侧), 槽口角度]
const SCREWS := [
	[Vector2(-0.022, 0.06), FRAME_HALF, 0, 20.0],      # 击锤轴
	[Vector2(0.0005, 0.0175), FRAME_HALF, 0, -35.0],   # 制动杆
	[Vector2(0.0182, 0.0163), FRAME_HALF, 0, 75.0],    # 扳机轴
	[Vector2(0.0665, 0.0415), FRAME_HALF, -1, 0.0],    # 转轮轴横销
]
const SCREW_PROFILE := [Vector2(0.0024, -0.0004), Vector2(0.0022, 0.0002), Vector2(0.0015, 0.00055), Vector2(0.0, 0.0007)]
const MEDALLION_PROFILE := [
	Vector2(0.0046, -0.0004), Vector2(0.0046, 0.0006), Vector2(0.0038, 0.001), Vector2(0.0028, 0.0009),
	Vector2(0.0, 0.0014),
]
const EJECTOR_HEAD_PROFILE := [Vector2(0.0032, 0.0), Vector2(0.0032, 0.0011), Vector2(0.0025, 0.0021), Vector2(0.0, 0.0023)]
const EJECTOR_HEAD_F := 0.128
const EJECTOR_SCREW_F := 0.1435


# —— 材质与缓存 ——

static func material() -> ShaderMaterial:
	return WorldMaterials.cached("revolver:finish", func():
		var mat := ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("panel_height", PANEL_HEIGHT)
		return mat)


static func tint(finish: Finish, shade := 1.0) -> Color:
	# 部件的表面工艺编进顶点色 alpha;shade 让同一工艺的个别部件略深/略亮
	return Color(shade, shade, shade, finish / FINISH_STEPS)


static func frame_mesh() -> ArrayMesh:
	return MeshBatch.cached("revolver:frame", func(b: MeshBatch) -> void:
		_add_frame(b)
		_add_barrel(b)
		_add_grip(b))


static func trim_mesh() -> ArrayMesh:
	return MeshBatch.cached("revolver:trim", func(b: MeshBatch) -> void:
		_add_trigger_group(b)
		_add_small_parts(b)
		_add_screws(b))


static func hammer_mesh() -> ArrayMesh:
	# 击锤网格在击锤枢轴的本地坐标里(轮廓相对击锤轴)
	return MeshBatch.cached("revolver:hammer", func(b: MeshBatch) -> void:
		side(b, hammer_outline(), HAMMER_HALF, 0.0005, Finish.CASE))


# —— 部件 ——

static func _add_frame(b: MeshBatch) -> void:
	side(b, FRAME_OUTLINE, FRAME_HALF, 0.0016, Finish.CASE)
	side(b, STRAP_OUTLINE, STRAP_HALF, 0.0022, Finish.CASE)
	axial(b, SHIELD_PROFILE, BARREL_SEGMENTS, Vector2(0, DRUM_AXIS_Y), Finish.CASE)
	axial(b, COLLAR_PROFILE, BARREL_SEGMENTS, Vector2(0, BARREL_Y), Finish.CASE)


static func _add_barrel(b: MeshBatch) -> void:
	axial(b, BARREL_PROFILE, BARREL_SEGMENTS, Vector2(0, BARREL_Y), Finish.BLUED)
	axial(b, EJECTOR_PROFILE, 12, EJECTOR_AT, Finish.BLUED)


static func _add_grip(b: MeshBatch) -> void:
	side(b, raked(GRIP_OUTLINE), GRIP_HALF, 0.0018, Finish.BRASS)
	var panel := RevolverShapes.domed_panel(RevolverShapes.ccw(raked(PANEL_OUTLINE)), rake_point(PANEL_CENTER),
		PANEL_HEIGHT, PackedFloat32Array(PANEL_RINGS))
	# 右片直接转过去;左片先沿鼓起方向镜像(MeshBatch 会把镜像部件的三角形翻回正面)
	b.add_part(panel, material(), Vector3(GRIP_HALF, 0, 0), SIDE_ROT, Vector3.ONE, tint(Finish.IVORY))
	b.add_part(panel, material(), Vector3(-GRIP_HALF, 0, 0), SIDE_ROT, Vector3(1, 1, -1), tint(Finish.IVORY))


static func _add_trigger_group(b: MeshBatch) -> void:
	side(b, guard_outline(), GUARD_HALF, 0.0015, Finish.BRASS)
	side(b, TRIGGER_OUTLINE, TRIGGER_HALF, 0.0007, Finish.CASE)


static func _add_small_parts(b: MeshBatch) -> void:
	side(b, SIGHT_OUTLINE, SIGHT_HALF, 0.0004, Finish.BRASS)
	axial(b, MUZZLE_BORE_PROFILE, BARREL_SEGMENTS, Vector2(0, BARREL_Y), Finish.BORE)
	axial(b, PIN_PROFILE, SMALL_SEGMENTS, Vector2(0, DRUM_AXIS_Y), Finish.BRIGHT)
	# 退壳杆:套筒右侧的槽缝与杆头、套筒前端的固定螺丝
	var ejector_side := EJECTOR_AT.x + EJECTOR_RADIUS
	b.add_part(MeshKit.box(Vector3(0.0005, 0.0014, 0.048)), material(),
		Vector3(ejector_side, EJECTOR_AT.y, -(EJECTOR_HEAD_F - 0.024)), Vector3.ZERO, Vector3.ONE, tint(Finish.BORE))
	lateral(b, EJECTOR_HEAD_PROFILE, SMALL_SEGMENTS, Vector3(ejector_side - 0.0006, EJECTOR_AT.y, -EJECTOR_HEAD_F), 1.0,
		Finish.BRIGHT)
	_screw(b, Vector3(ejector_side, EJECTOR_AT.y, -EJECTOR_SCREW_F), 1.0, 90.0)
	# 顶梁后端的照门槽
	b.add_part(MeshKit.box(Vector3(0.0016, 0.0006, 0.013)), material(), Vector3(0, 0.0797, -0.0035), Vector3.ZERO,
		Vector3.ONE, tint(Finish.BORE))
	# 握把片上的黄铜徽章
	var crown := PANEL_HEIGHT + GRIP_HALF
	for s in [-1.0, 1.0]:
		var center := rake_point(PANEL_CENTER)
		lateral(b, MEDALLION_PROFILE, 12, Vector3(crown * s, center.y, -center.x), s, Finish.BRASS)


static func _add_screws(b: MeshBatch) -> void:
	for screw in SCREWS:
		var at: Vector2 = screw[0]
		var sides: Array = [-1.0, 1.0] if screw[2] == 0 else [float(screw[2])]
		for s in sides:
			_screw(b, Vector3((screw[1] as float) * s, at.y, -at.x), s, screw[3])


static func _screw(b: MeshBatch, at: Vector3, s: float, slot_deg: float) -> void:
	# 圆头螺丝 + 一道槽口;at 为螺丝所在的表面点,s 为朝向(±X)
	lateral(b, SCREW_PROFILE, SMALL_SEGMENTS, at, s, Finish.BRIGHT)
	b.add_part(MeshKit.box(Vector3(0.0005, 0.0042, 0.0006)), material(), at + Vector3(0.00055 * s, 0, 0),
		Vector3(slot_deg, 0, 0), Vector3.ONE, tint(Finish.BORE))


static func raked(outline: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in outline:
		out.append(rake_point(p))
	return out


static func rake_point(p: Vector2) -> Vector2:
	# 握把根部以上(埋在机匣里的部分)不动;往下先略缩短,再按深度渐增的角度往后转,直线变成顺滑的弯
	var d := p - GRIP_PIVOT
	if d.y >= 0.0:
		return p
	d.y *= GRIP_SQUASH
	var bend := smoothstep(0.0, GRIP_BEND_SPAN, -d.y)
	return GRIP_PIVOT + d.rotated(-deg_to_rad(GRIP_RAKE_DEG) * bend)


static func guard_outline() -> PackedVector2Array:
	# 外沿从前端顺着下半圈绕到后端,再沿内沿回到前端(椭圆弧 = 单位圆弧按两轴缩放)
	var outer := RevolverShapes.arc(Vector2.ZERO, 1.0, 0.0, -180.0, GUARD_STEPS)
	var inner := RevolverShapes.arc(Vector2.ZERO, 1.0, -180.0, 0.0, GUARD_STEPS)
	var points := PackedVector2Array()
	for p in outer:
		points.append(GUARD_CENTER + p * GUARD_OUTER)
	for p in inner:
		points.append(GUARD_CENTER + p * GUARD_INNER)
	return points


static func hammer_outline() -> PackedVector2Array:
	# 相对击锤轴:轴座下半圈 → 前脸(击针头)→ 顶面 → 带防滑齿的击锤尖 → 尖下沿 → 后背回到轴座
	return RevolverShapes.join([
		RevolverShapes.arc(Vector2.ZERO, 0.0088, -150.0, -25.0, 6),
		PackedVector2Array([Vector2(0.0094, 0.0035), Vector2(0.0104, 0.0098), Vector2(0.0098, 0.0146),
			Vector2(0.0072, 0.0163), Vector2(0.0025, 0.0176), Vector2(-0.0035, 0.0204), Vector2(-0.0092, 0.0246)]),
		RevolverShapes.teeth(Vector2(-0.0098, 0.0252), Vector2(-0.0186, 0.0286), 5, 0.0007),
		PackedVector2Array([Vector2(-0.0206, 0.0284), Vector2(-0.0218, 0.0268), Vector2(-0.0216, 0.0247),
			Vector2(-0.0201, 0.0232), Vector2(-0.0166, 0.0214), Vector2(-0.0129, 0.0184), Vector2(-0.0105, 0.0134),
			Vector2(-0.0092, 0.0058)]),
	])


# —— 摆放工具 ——

static func side(b: MeshBatch, outline: Variant, half: float, bevel: float, finish: Finish) -> void:
	# 侧面轮廓 (f, y) 沿 X 拉伸成 ±half 厚
	var arrays := RevolverShapes.slab(PackedVector2Array(outline), half * 2.0, bevel)
	b.add_part(arrays, material(), Vector3.ZERO, SIDE_ROT, Vector3.ONE, tint(finish))


static func axial(b: MeshBatch, profile: Array, segments: int, axis: Vector2, finish: Finish) -> void:
	# 沿枪管方向(-Z)的回转体:profile 为 (半径, f),axis 为轴线的 (x, y)
	b.add_part(MeshShapes.lathe(PackedVector2Array(profile), segments), material(), Vector3(axis.x, axis.y, 0),
		AXIAL_ROT, Vector3.ONE, tint(finish))


static func lateral(b: MeshBatch, profile: Array, segments: int, at: Vector3, s: float, finish: Finish) -> void:
	# 沿 ±X 的回转体(螺丝头、徽章、退壳杆头):剖面高度朝 s 指的那一侧
	b.add_part(MeshShapes.lathe(PackedVector2Array(profile), segments), material(), at, Vector3(0, 0, -90.0 * s),
		Vector3.ONE, tint(finish))
