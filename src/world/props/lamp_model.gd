class_name LampModel
# 牌桌正上方的台球桌式吊灯:天花板上的黄铜吊盒、一串铁链、搪瓷灯罩(圆顶接外撇的裙边,外绿内奶白,
# 顶与裙边交界处一道黄铜箍,口沿黄铜卷边)、黄铜灯帽与灯座、发光的梨形灯泡。
# 原点在天花板吊点(LampPivot),灯罩中心在吊点下 drop + 0.1 米;灯光的位置与参数保持原样(另有会话在调灯光)。
# 两个缓存网格:外罩投影;链条、灯座、灯泡、内壁等细件不投影(灯泡把聚光灯整个包住,投影会挡光)。


const SHADE_SEGMENTS := 48
const SMALL_SEGMENTS := 16
const SHADE_BELOW_DROP := 0.1     # 灯罩中心在 drop 之下这么多(灯光按它定位)
const SHADE_WALL := 0.004
# 搪瓷灯罩外壁(半径, 相对灯罩中心的高度):从口沿往上——浅锥形的裙边、膝弯、陡起的圆顶,收到灯帽底下
const SHADE_OUTER := [
	Vector2(0.375, -0.094), Vector2(0.368, -0.088), Vector2(0.345, -0.075), Vector2(0.3, -0.052),
	Vector2(0.255, -0.03), Vector2(0.215, -0.009), Vector2(0.192, 0.006), Vector2(0.18, 0.024), Vector2(0.173, 0.05),
	Vector2(0.165, 0.076), Vector2(0.15, 0.1), Vector2(0.128, 0.121), Vector2(0.1, 0.137), Vector2(0.075, 0.147),
	Vector2(0.058, 0.151),
]
const RIM := Vector3(0.372, -0.094, 0.0068)    # 口沿卷边铜圈:半径、高度、粗细
const BAND := Vector3(0.19, 0.009, 0.0042)     # 裙边与圆顶交界处的铜箍
const RING_SIDES := 8
# 灯罩顶上的黄铜帽:底面圆心 → 外缘(压在圆顶上)→ 箍 → 圆顶 → 顶尖
const CAP_PROFILE := [
	Vector2(0.0, 0.142), Vector2(0.083, 0.142), Vector2(0.086, 0.148), Vector2(0.084, 0.157), Vector2(0.073, 0.163),
	Vector2(0.056, 0.171), Vector2(0.04, 0.179), Vector2(0.025, 0.185), Vector2(0.018, 0.189), Vector2(0.016, 0.199),
	Vector2(0.0, 0.201),
]
const CAP_EYE := Vector2(0.21, 0.011)          # 帽顶吊环:高度、半径
# 灯座(黄铜,从灯罩内顶往下)与梨形灯泡(灯泡底略低于口沿,越肩机位也看得见那一点亮)
const SOCKET_PROFILE := [
	Vector2(0.0, 0.03), Vector2(0.021, 0.03), Vector2(0.024, 0.036), Vector2(0.024, 0.08), Vector2(0.019, 0.09),
	Vector2(0.019, 0.15), Vector2(0.0, 0.15),
]
const BULB_PROFILE := [
	Vector2(0.0, -0.112), Vector2(0.02, -0.106), Vector2(0.036, -0.092), Vector2(0.045, -0.072),
	Vector2(0.045, -0.052), Vector2(0.037, -0.033), Vector2(0.025, -0.016), Vector2(0.017, 0.0), Vector2(0.016, 0.032),
	Vector2(0.0, 0.032),
]
# 天花板吊盒(相对吊点)与它下面的吊环
const CANOPY_PROFILE := [
	Vector2(0.0, -0.06), Vector2(0.022, -0.059), Vector2(0.03, -0.054), Vector2(0.05, -0.046), Vector2(0.07, -0.032),
	Vector2(0.082, -0.016), Vector2(0.088, -0.006), Vector2(0.094, -0.002), Vector2(0.095, 0.0), Vector2(0.0, 0.0),
]
const CANOPY_EYE_Y := -0.07
const EYE_WIRE := 0.0034
# 链环:直段半长、半圆半径(中心线)、线径;相邻两环互相垂直。环做得粗大些,远景里仍看得出是链条
const LINK_HALF := 0.015
const LINK_BEND := 0.011
const LINK_WIRE := 0.004
const LINK_SIDES := 4
const ENAMEL_GREEN := Color(0.1, 0.36, 0.25)    # 偏冷的翠绿:暖色灯光下不至于发黑发褐
const ENAMEL_CREAM := Color(0.6, 0.54, 0.43)    # 内壁离罩里的补光只有几厘米:压暗一些,仰视时是暖光而不是一块白斑
const INNER_GLOW := 0.05          # 内壁一点自发光:像被灯泡照透的白瓷;明暗主要还是靠罩里的补光
const BULB_COLOR := Color(1.0, 0.82, 0.55)
const BULB_ENERGY := 9.0


static func build(pivot: Node3D, tavern: Tavern, drop: float) -> void:
	var shade_y := -drop - SHADE_BELOW_DROP
	MeshBatch.instance(pivot, shade_mesh(shade_y), {}, "Shade")
	MeshBatch.instance(pivot, fittings_mesh(shade_y), {}, "Fittings", false)
	_add_lights(pivot, tavern, shade_y)


static func shade_mesh(shade_y: float) -> ArrayMesh:
	return MeshBatch.cached("lamp_shade:%.3f" % shade_y, func(b: MeshBatch) -> void:
		b.add_part(MeshShapes.lathe(_outer_profile(shade_y), SHADE_SEGMENTS), _outer_enamel()))


static func fittings_mesh(shade_y: float) -> ArrayMesh:
	return MeshBatch.cached("lamp_fittings:%.3f" % shade_y, func(b: MeshBatch) -> void:
		_add_shade_inside(b, shade_y)
		_add_brass(b, shade_y)
		_add_chain(b, shade_y)
		b.add_part(MeshShapes.lathe(TableShapes.shifted(BULB_PROFILE, Vector2(0, shade_y)), SMALL_SEGMENTS),
			WorldMaterials.emissive(BULB_COLOR, BULB_ENERGY)))


# —— 灯罩 ——

static func _outer_profile(shade_y: float) -> PackedVector2Array:
	return TableShapes.shifted(SHADE_OUTER, Vector2(0, shade_y))


static func _add_shade_inside(b: MeshBatch, shade_y: float) -> void:
	# 内壁:外壁往里缩一层壁厚、倒过来走(朝下朝里),顶上封一圈内顶
	var inner := TableShapes.offset_profile(_outer_profile(shade_y), -SHADE_WALL)
	inner.reverse()
	var profile := TableShapes.joined([Vector2(0.0, inner[0].y), inner])
	b.add_part(MeshShapes.lathe(profile, SHADE_SEGMENTS), _inner_enamel())


static func _add_brass(b: MeshBatch, shade_y: float) -> void:
	var brass := WorldMaterials.brass()
	for ring in [RIM, BAND]:
		b.add_part(_ring(ring.x, ring.z, SHADE_SEGMENTS), brass, Vector3(0, shade_y + ring.y, 0))
	b.add_part(MeshShapes.lathe(TableShapes.shifted(CAP_PROFILE, Vector2(0, shade_y)), SMALL_SEGMENTS * 2), brass)
	b.add_part(MeshShapes.lathe(TableShapes.shifted(SOCKET_PROFILE, Vector2(0, shade_y)), SMALL_SEGMENTS), brass)
	b.add_part(MeshShapes.lathe(PackedVector2Array(CANOPY_PROFILE), SMALL_SEGMENTS * 2), brass)


static func _ring(radius: float, wire: float, segments: int, sides := RING_SIDES) -> TorusMesh:
	var ring := MeshKit.torus(radius - wire, radius + wire, segments)
	ring.ring_segments = sides
	return ring


# —— 链条 ——

static func _add_chain(b: MeshBatch, shade_y: float) -> void:
	# 吊盒下的吊环 → 一环环首尾相扣的链条 → 灯帽上的吊环。相邻两环互相垂直、中心相距一个内径长,
	# 按两个吊环之间的距离把环距微调到正好挂满;两端的吊环也和挨着的那一环垂直
	var iron := WorldMaterials.iron()
	var top := CANOPY_EYE_Y - CAP_EYE.y + EYE_WIRE
	var bottom := shade_y + CAP_EYE.x + CAP_EYE.y - EYE_WIRE
	var link := _link_arrays()
	var outer_length := 2.0 * (LINK_HALF + LINK_BEND + LINK_WIRE)
	var inner_length := outer_length - 4.0 * LINK_WIRE
	var count := maxi(2, roundi((top - bottom - outer_length) / inner_length) + 1)
	var pitch := (top - bottom - outer_length) / (count - 1)
	for i in count:
		b.add_part(link, iron, Vector3(0, top - outer_length / 2.0 - i * pitch, 0), Vector3(0, 90.0 * (i % 2), 0))
	var eye := _ring(CAP_EYE.y, EYE_WIRE, 12, 4)
	b.add_part(eye, iron, Vector3(0, CANOPY_EYE_Y, 0), Vector3(90, 90, 0))
	var last_turned := (count - 1) % 2 == 1
	b.add_part(eye, iron, Vector3(0, shade_y + CAP_EYE.x, 0), Vector3(90, 0.0 if last_turned else 90.0, 0))


static func _link_arrays() -> Array:
	# 跑道形的环(XY 平面,长轴竖直):右侧直段中点出发,上半圆 → 左侧直段 → 下半圆 → 回到起点
	var path := PackedVector3Array([Vector3(LINK_BEND, 0, 0)])
	for p in TableShapes.arc(Vector2(0, LINK_HALF), LINK_BEND, 0.0, 180.0, 3):
		path.append(Vector3(p.x, p.y, 0))
	for p in TableShapes.arc(Vector2(0, -LINK_HALF), LINK_BEND, 180.0, 360.0, 3):
		path.append(Vector3(p.x, p.y, 0))
	path.append(Vector3(LINK_BEND, 0, 0))
	return MeshShapes.tube(path, LINK_WIRE, LINK_SIDES, false)


# —— 材质与灯光 ——

static func _outer_enamel() -> ShaderMaterial:
	# 外壁搪瓷:亮釉 + 清漆高光;朝上的面补一点反射光(见 lamp_enamel.gdshader)
	return WorldMaterials.cached("lamp_enamel:outer", func():
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://src/world/shaders/lamp_enamel.gdshader")
		mat.set_shader_parameter("enamel", ENAMEL_GREEN)
		return mat)


static func _inner_enamel() -> StandardMaterial3D:
	return WorldMaterials.cached("lamp_enamel:inner", func():
		var mat := StandardMaterial3D.new()
		mat.albedo_color = ENAMEL_CREAM
		mat.roughness = 0.35
		mat.metallic_specular = 0.5
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.86, 0.62)
		mat.emission_energy_multiplier = INNER_GLOW
		return mat)


static func _add_lights(pivot: Node3D, tavern: Tavern, shade_y: float) -> void:
	# 参数与位置保持原样(灯光调校在别处)
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, shade_y - 0.05, 0)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.light_color = Color(1.0, 0.84, 0.66)
	spot.light_energy = 3.5
	spot.spot_range = 3.4
	spot.spot_angle = 52.0
	spot.spot_angle_attenuation = 0.7
	spot.shadow_enabled = true
	spot.shadow_blur = 1.5
	spot.light_volumetric_fog_energy = 2.2
	pivot.add_child(spot)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, shade_y + 0.05, 0)
	fill.light_color = Color(1.0, 0.72, 0.45)
	fill.light_energy = 1.5
	fill.omni_range = 7.5
	fill.light_volumetric_fog_energy = 0.3
	pivot.add_child(fill)
	tavern.add_flicker(spot, 0.7, 0.04, 3.0)
