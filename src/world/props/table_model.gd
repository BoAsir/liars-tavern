class_name TableModel
# 牌桌的几何与材质:厚实的圆桌面(桌沿带线脚)、皮革软包边(缝线、黄铜泡钉)、压住绒布边的黄铜嵌线、绒布、
# 桌裙,旋制的花瓶形中柱与四只落在黄铜脚杯里的弯脚。
# 桌面一带随半径变化,网格按半径缓存(换桌时直接取用);中柱各半径同样尺寸,桌脚在大桌上稍微撑开。每个半径两个网格:
#   solid:木、皮,投射阴影;trim:绒布与黄铜细节,不投影(不必为每盏有阴影的灯再画一遍)。
# 剖面表都是相对某个基准点的偏移(米),外侧在行进方向的右手边(MeshShapes.lathe 的约定)。


const FELT_INSET := 0.13        # 桌布半径 = 桌面半径 - 这么多(出牌区与旧桌一致)
const FELT_LIFT := 0.002        # 桌布面高出 TABLE_TOP:牌(最低 TABLE_TOP + 0.003)平放在上面不穿模
const FELT_WELL := 0.004        # 桌布底下的木面下沉这么多:两层面不贴在一起,远处不闪
const WELL_MARGIN := 0.002      # 下沉区比桌布宽一点,台阶藏在黄铜嵌线底下
# felt.gdshader 里刺绣圈的默认值,对应默认桌布半径;换桌面大小时按比例缩放
const FELT_RINGS := {"radius": 0.8, "inner_ring": 0.28, "outer_ring": 0.70}
const TOP_THICKNESS := 0.068
const APRON_INSET := 0.17       # 桌裙外皮离桌沿
const SEGMENTS := 96            # 桌面一带的圆周分段:半径 1.45 时弦高也不到 1 毫米
const PEDESTAL_SEGMENTS := 32
const NAIL_SPACING := 0.045     # 包边下沿黄铜泡钉的间距
const NAIL_SEGMENTS := 5
const PANEL_LENGTH := 0.12      # 软包分格长度(着色器按 UV.x 的整数格画接缝)
const STITCHES_PER_PANEL := 16
const FOOT_ANGLES := [45.0, 135.0, 225.0, 315.0]   # 四只脚朝向座位之间
const FOOT_TINT := Color(0.78, 0.76, 0.74)   # 桌脚、桌裙比桌面略深(同一木材按顶点色压暗)

# 软包边(相对 (桌沿半径, 桌面高度)):从桌沿木线里的收口出发,翻过外侧圆鼓与拱顶,落到内侧赛道木面以下。
# 拱顶只高出桌面 1.4 厘米:酒客的爪子就搭在这一圈上,太高会陷进去;内侧 2 厘米几乎贴平,放在桌边的左轮不会插进皮面
const RAIL_PROFILE := [
	Vector2(-0.007, -0.024), Vector2(-0.001, -0.019), Vector2(0.003, -0.011), Vector2(0.004, -0.004),
	Vector2(0.002, 0.003), Vector2(-0.004, 0.009), Vector2(-0.012, 0.0125), Vector2(-0.022, 0.014),
	Vector2(-0.032, 0.0135), Vector2(-0.042, 0.011), Vector2(-0.052, 0.007), Vector2(-0.06, 0.0035),
	Vector2(-0.066, 0.001), Vector2(-0.071, -0.001),
]
const RAIL_NAIL_SEGMENT := 1      # 泡钉钉在剖面第 1~2 点之间:皮面收进木线的下沿
const RAIL_STITCH_POINTS := [5, 10]   # 两道缝线压在拱顶两侧
const RAIL_CROWN_POINT := 7
# 桌沿线脚(相对 (桌沿半径, 桌面高度)):底面外缘 → 下圆线 → 凹槽 → 上小圆线 → 收进软包边底下
const TOP_EDGE := [
	Vector2(-0.03, -0.068), Vector2(-0.016, -0.066), Vector2(-0.006, -0.06), Vector2(-0.001, -0.052),
	Vector2(0.0, -0.045), Vector2(-0.002, -0.04), Vector2(-0.007, -0.037), Vector2(-0.007, -0.034),
	Vector2(-0.003, -0.031), Vector2(-0.002, -0.027), Vector2(-0.006, -0.024),
]
const RACETRACK_EDGE := -0.068    # 软包边底下的暗台在这里抬回桌面高度(相对桌沿)
const RAIL_LEDGE := -0.024        # 暗台的高度(相对桌面):软包边的下沿收在这里
# 黄铜嵌线:压住桌布边缘的半圆线条(相对 (桌布半径, 桌面高度)),最高只高出桌面 6 毫米
const INLAY_PROFILE := [
	Vector2(0.011, -0.001), Vector2(0.0095, 0.0025), Vector2(0.0065, 0.005), Vector2(0.003, 0.006),
	Vector2(-0.001, 0.0055), Vector2(-0.004, 0.0035), Vector2(-0.0055, 0.0015), Vector2(-0.006, 0.0),
]
# 桌裙(相对 (桌裙外皮半径, 桌面底面)):内壁 → 底面 → 下沿圆线 → 外壁
const APRON_PROFILE := [
	Vector2(-0.022, 0.0), Vector2(-0.022, -0.085), Vector2(-0.022, -0.085), Vector2(0.004, -0.085),
	Vector2(0.008, -0.081), Vector2(0.009, -0.075), Vector2(0.006, -0.069), Vector2(0.0, -0.066),
	Vector2(0.0, -0.066), Vector2(0.0, 0.0),
]
# 旋制中柱(半径, 高度):脚墩 → 凹槽、圆线 → 花瓶状柱身 → 细颈、圆环 → 喇叭口托座(顶块另接到桌面底面)
const PEDESTAL_PROFILE := [
	Vector2(0.0, 0.1), Vector2(0.15, 0.1), Vector2(0.15, 0.1), Vector2(0.158, 0.125), Vector2(0.152, 0.155),
	Vector2(0.135, 0.172), Vector2(0.118, 0.18), Vector2(0.112, 0.19), Vector2(0.122, 0.2), Vector2(0.124, 0.212),
	Vector2(0.112, 0.222), Vector2(0.098, 0.232), Vector2(0.108, 0.27), Vector2(0.126, 0.32), Vector2(0.132, 0.36),
	Vector2(0.124, 0.4), Vector2(0.102, 0.44), Vector2(0.078, 0.48), Vector2(0.064, 0.515), Vector2(0.06, 0.545),
	Vector2(0.072, 0.556), Vector2(0.078, 0.566), Vector2(0.072, 0.576), Vector2(0.064, 0.588), Vector2(0.066, 0.6),
	Vector2(0.084, 0.622), Vector2(0.11, 0.642), Vector2(0.128, 0.652), Vector2(0.13, 0.66), Vector2(0.13, 0.66),
]
const PEDESTAL_TOP_RADIUS := 0.13
const PEDESTAL_INTO_TOP := 0.002   # 顶块伸进桌面底面一点,接缝处不漏光
# 中柱上的黄铜:顶块外的一道铜箍、花瓶柱身底下的一圈铜环
const PEDESTAL_BAND := [
	Vector2(0.13, 0.662), Vector2(0.135, 0.665), Vector2(0.137, 0.67), Vector2(0.137, 0.694),
	Vector2(0.135, 0.699), Vector2(0.13, 0.702),
]
const PEDESTAL_RING := Vector3(0.124, 0.206, 0.0075)   # 半径、高度、铜环粗细
# 桌脚:从脚墩底下伸出,先微微拱起(膝)再顺势扫向地面,脚尖落进黄铜脚杯。沿中心线扫出的管子,
# 每点 (离中柱轴线的水平距离, 高度, 截面半径);截面横向压扁成椭圆,侧看饱满、俯看不臃肿
const FOOT_PATH := [
	Vector3(0.07, 0.13, 0.05), Vector3(0.12, 0.148, 0.048), Vector3(0.17, 0.155, 0.045), Vector3(0.22, 0.15, 0.041),
	Vector3(0.27, 0.133, 0.036), Vector3(0.32, 0.106, 0.031), Vector3(0.37, 0.076, 0.027), Vector3(0.415, 0.05, 0.023),
	Vector3(0.455, 0.034, 0.021), Vector3(0.49, 0.026, 0.0195), Vector3(0.5, 0.024, 0.019),
]
const FOOT_FLATTEN := 0.82
const FOOT_SIDES := 10
# 脚尖底下的黄铜脚杯(半径, 高度):杯底 → 杯壁 → 收口的圆边 → 杯口(脚尖插在里面)
const FOOT_CUP_PROFILE := [
	Vector2(0.0, 0.0), Vector2(0.025, 0.0), Vector2(0.0285, 0.003), Vector2(0.029, 0.019), Vector2(0.0272, 0.024),
	Vector2(0.0225, 0.0255), Vector2(0.0, 0.0255),
]
const FOOT_CUP_AT := 0.5        # 脚杯中心离中柱轴线的距离
const FOOT_CUP_SEGMENTS := 12
const FOOT_ROOT := 0.15         # 脚墩外缘:桌脚从这里往外的一段可以按桌面大小伸长
const FOOT_SPREAD := 0.55       # 桌面半径每大 1 米,桌脚伸出的长度多这么多比例(德州大桌不至于头重脚轻)
const BRASS_RING_SIDES := 8


static func prebuild(radius: float) -> void:
	# 开场就把该半径的网格建好放进缓存:对局中换桌只换网格,不在游戏中途拼装
	solid_mesh(radius)
	trim_mesh(radius)
	felt_material(radius)


static func solid_mesh(radius: float) -> ArrayMesh:
	return MeshBatch.cached("table_solid:%.3f" % radius, func(b: MeshBatch) -> void:
		_add_top(b, radius)
		_add_rail(b, radius)
		_add_apron(b, radius)
		_add_pedestal(b)
		_add_feet(b, radius))


static func trim_mesh(radius: float) -> ArrayMesh:
	return MeshBatch.cached("table_trim:%.3f" % radius, func(b: MeshBatch) -> void:
		_add_felt(b, radius)
		_add_inlay(b, radius)
		_add_nails(b, radius)
		_add_base_brass(b, radius))


static func felt_radius(radius: float) -> float:
	return radius - FELT_INSET


# —— 材质 ——

static func felt_material(radius: float) -> ShaderMaterial:
	# 桌布刺绣圈按桌布半径等比缩放;默认桌面直接用共享材质
	var felt_r := felt_radius(radius)
	var default_r := felt_radius(SeatLayout.TABLE_RADIUS)
	if is_equal_approx(felt_r, default_r):
		return WorldMaterials.felt()
	return WorldMaterials.cached("table_felt:%.3f" % felt_r, func():
		var mat: ShaderMaterial = WorldMaterials.felt().duplicate()
		for param in FELT_RINGS:
			mat.set_shader_parameter(param, FELT_RINGS[param] * felt_r / default_r)
		return mat)


static func leather() -> ShaderMaterial:
	return WorldMaterials.cached("table_leather", func():
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://src/world/shaders/table_leather.gdshader")
		var profile := _rail_profile(0.0)
		mat.set_shader_parameter("panel_length", PANEL_LENGTH)
		mat.set_shader_parameter("stitches_per_panel", float(STITCHES_PER_PANEL))
		mat.set_shader_parameter("stitch_rows", Vector2(TableShapes.profile_length(profile, RAIL_STITCH_POINTS[0]),
			TableShapes.profile_length(profile, RAIL_STITCH_POINTS[1])))
		mat.set_shader_parameter("crown_at", TableShapes.profile_length(profile, RAIL_CROWN_POINT))
		return mat)


static func turned_wood() -> ShaderMaterial:
	# 旋制件(中柱、椅腿、椅背条)的深色胡桃木:纤维顺着竖直的轴线走,清漆半亮
	return WorldMaterials.wood_with("turned", {
		"color_dark": Color(0.06, 0.032, 0.02), "color_light": Color(0.2, 0.11, 0.055),
		"scale": 1.0, "ring_frequency": 14.0, "grain_axis": 1, "across_axis": 0,
		"roughness_base": 0.6, "varnish": 0.4, "wear": 0.35,
	})


# —— 桌面(随半径) ——

static func _add_top(b: MeshBatch, radius: float) -> void:
	var top := SeatLayout.TABLE_TOP
	var bottom := top - TOP_THICKNESS
	var inner := radius + RACETRACK_EDGE
	var well := felt_radius(radius) + WELL_MARGIN
	var profile := TableShapes.joined([Vector2(0.0, bottom), TableShapes.shifted(TOP_EDGE, Vector2(radius, top)),
		Vector2(inner, top + RAIL_LEDGE), Vector2(inner, top), Vector2(inner, top), Vector2(well, top), Vector2(well, top),
		Vector2(well, top - FELT_WELL), Vector2(well, top - FELT_WELL), Vector2(0.0, top - FELT_WELL)])
	b.add_part(MeshShapes.lathe(profile, SEGMENTS), WorldMaterials.wood("table"))


static func _rail_profile(radius: float) -> PackedVector2Array:
	return TableShapes.shifted(RAIL_PROFILE, Vector2(radius, SeatLayout.TABLE_TOP))


static func _add_rail(b: MeshBatch, radius: float) -> void:
	# UV.x 换成"第几格":一圈按分格长度取整,接缝首尾相接
	var panels := maxi(8, roundi(TAU * radius / PANEL_LENGTH))
	var arrays := TableShapes.with_uv_x(MeshShapes.lathe(_rail_profile(radius), SEGMENTS), float(panels))
	b.add_part(arrays, leather())


static func _add_apron(b: MeshBatch, radius: float) -> void:
	var profile := TableShapes.shifted(APRON_PROFILE,
		Vector2(radius - APRON_INSET, SeatLayout.TABLE_TOP - TOP_THICKNESS))
	b.add_part(MeshShapes.lathe(profile, SEGMENTS / 2), WorldMaterials.wood("table"), Vector3.ZERO, Vector3.ZERO,
		Vector3.ONE, FOOT_TINT)


static func _add_felt(b: MeshBatch, radius: float) -> void:
	var r := felt_radius(radius)
	var top := SeatLayout.TABLE_TOP + FELT_LIFT
	var profile := PackedVector2Array([Vector2(r, SeatLayout.TABLE_TOP - FELT_WELL), Vector2(r, top), Vector2(r, top),
		Vector2(0.0, top)])
	b.add_part(MeshShapes.lathe(profile, SEGMENTS), felt_material(radius))


static func _add_inlay(b: MeshBatch, radius: float) -> void:
	var profile := TableShapes.shifted(INLAY_PROFILE, Vector2(felt_radius(radius), SeatLayout.TABLE_TOP))
	b.add_part(MeshShapes.lathe(profile, SEGMENTS), WorldMaterials.brass())


static func _add_nails(b: MeshBatch, radius: float) -> void:
	# 黄铜泡钉:沿包边下沿一圈,钉帽顺着皮面的外法线
	var profile := _rail_profile(radius)
	var a := profile[RAIL_NAIL_SEGMENT]
	var c := profile[RAIL_NAIL_SEGMENT + 1]
	var spot := (a + c) / 2.0
	var normal := Vector2(c.y - a.y, -(c.x - a.x)).normalized()
	var head := MeshShapes.lathe(PackedVector2Array([Vector2(0.0055, -0.001), Vector2(0.0042, 0.0022),
		Vector2(0.0, 0.0032)]), NAIL_SEGMENTS)
	var count := maxi(24, roundi(TAU * radius / NAIL_SPACING))
	for i in count:
		var angle := TAU * (i + 0.5) / count
		var out := Vector3(cos(angle), 0.0, sin(angle))
		var axis := (out * normal.x + Vector3.UP * normal.y).normalized()
		var pos := out * spot.x + Vector3.UP * spot.y
		b.add_arrays(head, WorldMaterials.brass(), Transform3D(Basis(Quaternion(Vector3.UP, axis)), pos))


# —— 中柱与桌脚(中柱各半径相同,桌脚在大桌上稍微撑开) ——

static func _add_pedestal(b: MeshBatch) -> void:
	var top := SeatLayout.TABLE_TOP - TOP_THICKNESS + PEDESTAL_INTO_TOP
	var profile := TableShapes.joined([PEDESTAL_PROFILE, Vector2(PEDESTAL_TOP_RADIUS, top),
		Vector2(PEDESTAL_TOP_RADIUS, top), Vector2(0.0, top)])
	b.add_part(MeshShapes.lathe(profile, PEDESTAL_SEGMENTS), turned_wood())


static func _foot_reach(radius: float) -> float:
	# 桌脚伸出脚墩那一段的长度比例:默认桌面为 1,大桌稍微撑开一点(中柱本身不变)
	return 1.0 + maxf(radius - SeatLayout.TABLE_RADIUS, 0.0) * FOOT_SPREAD


static func _spread(u: float, radius: float) -> float:
	return u if u <= FOOT_ROOT else FOOT_ROOT + (u - FOOT_ROOT) * _foot_reach(radius)


static func _add_feet(b: MeshBatch, radius: float) -> void:
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for p in FOOT_PATH:
		path.append(Vector3(_spread(p.x, radius), p.y, 0.0))
		radii.append(p.z)
	var foot := MeshShapes.deform(MeshShapes.tube(path, radii, FOOT_SIDES), func(v: Vector3) -> Vector3:
		return Vector3(v.x, v.y, v.z * FOOT_FLATTEN))
	for i in FOOT_ANGLES.size():
		b.add_part(foot, WorldMaterials.wood("table"), Vector3.ZERO, Vector3(0, FOOT_ANGLES[i], 0), Vector3.ONE,
			FOOT_TINT, 0.2 + i * 0.17)


static func _add_base_brass(b: MeshBatch, radius: float) -> void:
	var brass := WorldMaterials.brass()
	b.add_part(MeshShapes.lathe(PackedVector2Array(PEDESTAL_BAND), PEDESTAL_SEGMENTS), brass)
	var ring := MeshKit.torus(PEDESTAL_RING.x - PEDESTAL_RING.z, PEDESTAL_RING.x + PEDESTAL_RING.z, PEDESTAL_SEGMENTS)
	ring.ring_segments = BRASS_RING_SIDES
	b.add_part(ring, brass, Vector3(0, PEDESTAL_RING.y, 0))
	var cup := MeshShapes.lathe(PackedVector2Array(FOOT_CUP_PROFILE), FOOT_CUP_SEGMENTS)
	for angle in FOOT_ANGLES:
		var dir := Basis(Vector3.UP, deg_to_rad(angle))
		b.add_arrays(cup, brass, Transform3D(Basis.IDENTITY, dir * Vector3(_spread(FOOT_CUP_AT, radius), 0.0, 0.0)))
