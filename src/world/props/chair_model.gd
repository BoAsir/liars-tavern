class_name ChairModel
# 酒客坐的椅子:西部酒馆的温莎椅——马鞍形座面、外撇的旋制椅腿加 H 形横撑、纺锤条椅背、两端起耳的弓形搭脑。
# 原点在座位地面,面朝 -Z(牌桌),座面高约 0.475 米,椅背在 +Z 一侧(酒客的尾巴绕着这个外形走,尺寸别随意放大)。
# 所有椅子共用一个缓存网格、一种木材一个表面:酒客中途加入、复活时直接取用,不在对局中拼装。
# 木纹顺着各部件自己的 Y 轴走(旋制件本来就沿 Y 车出来);座面、搭脑先转进"木纹坐标系"再放回原位,纹理顺着椅宽。


const SEGMENTS_LEG := 8
const SEGMENTS_POST := 10
const SEGMENTS_SPINDLE := 6
const SEGMENTS_SEAT := 28
# 座面:单位圆盘的剖面(半径比例, 相对座面顶的高度),再按超椭圆拉成座面轮廓;顶面压出坐窝
const SEAT_TOP := 0.476
const SEAT_PROFILE := [
	Vector2(0.0, -0.046), Vector2(0.82, -0.046), Vector2(0.95, -0.0435), Vector2(0.99, -0.036), Vector2(1.0, -0.024),
	Vector2(0.99, -0.012), Vector2(0.962, -0.0035), Vector2(0.91, 0.0), Vector2(0.7, 0.0), Vector2(0.45, 0.0),
	Vector2(0.2, 0.0), Vector2(0.0, 0.0),
]
const SEAT_HALF := Vector2(0.235, 0.2175)    # 座面半宽(x)、半深(z)
const SEAT_CENTER_Z := 0.1425
const SEAT_ROUNDNESS := Vector2(2.6, 5.0)    # 超椭圆指数:前缘圆润,后缘近乎平直(立柱、纺锤条都插在后缘)
const SADDLE_DEPTH := 0.011                  # 坐窝深度,窝心略偏后
const SADDLE_CENTER := 0.2
const SADDLE_SPREAD := Vector2(0.8, 0.85)
const SADDLE_BAND := 0.01                    # 只有顶面这么厚的一层跟着压下去,侧边的圆角不变形
# 椅腿(x 取正的一侧,另一侧镜像):脚 → 插进座面底;花样是剖面表(半径, 长度比例)。
# 腿往外撇,脚底圆面跟着斜了:脚心抬高一点,斜面最低的边正好着地
const FRONT_LEG := [Vector3(0.2, 0.0018, -0.048), Vector3(0.165, 0.445, -0.012)]
const BACK_LEG := [Vector3(0.2, 0.0018, 0.335), Vector3(0.165, 0.445, 0.3)]
const LEG_PROFILE := [
	Vector2(0.0, 0.0), Vector2(0.016, 0.0), Vector2(0.0175, 0.025), Vector2(0.0168, 0.14), Vector2(0.02, 0.33),
	Vector2(0.016, 0.39), Vector2(0.0215, 0.41), Vector2(0.0165, 0.43), Vector2(0.0205, 0.58), Vector2(0.0232, 0.71),
	Vector2(0.0175, 0.86), Vector2(0.0195, 0.9), Vector2(0.0155, 0.95), Vector2(0.0, 1.0),
]
const STRETCHER_AT := 0.41                   # 横撑接在椅腿的这道圆环上(长度比例)
const STRETCHER_PROFILE := [
	Vector2(0.0, 0.0), Vector2(0.0092, 0.0), Vector2(0.0102, 0.1), Vector2(0.0132, 0.5), Vector2(0.0102, 0.9),
	Vector2(0.0092, 1.0), Vector2(0.0, 1.0),
]
# 椅背:两根立柱 + 纺锤条,上端都插进搭脑
const POST := [Vector3(0.18, 0.446, 0.322), Vector3(0.198, 0.995, 0.35)]
const POST_PROFILE := [
	Vector2(0.0, 0.0), Vector2(0.019, 0.0), Vector2(0.0215, 0.05), Vector2(0.0245, 0.14), Vector2(0.02, 0.22),
	Vector2(0.0155, 0.27), Vector2(0.0198, 0.29), Vector2(0.0158, 0.31), Vector2(0.0168, 0.55), Vector2(0.0172, 0.8),
	Vector2(0.0152, 0.95), Vector2(0.0, 1.0),
]
const SPINDLE_XS := [-0.12, -0.06, 0.0, 0.06, 0.12]
const SPINDLE_FAN := 1.1                     # 纺锤条到顶上张开一点
const SPINDLE_BOTTOM := Vector2(0.451, 0.326)   # 插进座面的高度、z
const SPINDLE_INTO_RAIL := 0.012
const SPINDLE_PROFILE := [
	Vector2(0.0, 0.0), Vector2(0.0085, 0.0), Vector2(0.0105, 0.3), Vector2(0.0092, 0.55), Vector2(0.0075, 0.85),
	Vector2(0.0072, 1.0), Vector2(0.0, 1.0),
]
# 搭脑:正视轮廓(x, y)——下沿微拱,两端向上翻成圆耳,顶边中间稍凹;拉出厚度后往后弯成弓形
const CREST_OUTLINE := [
	Vector2(-0.201, 0.976), Vector2(-0.137, 0.962), Vector2(-0.069, 0.954), Vector2(0.0, 0.952), Vector2(0.069, 0.954),
	Vector2(0.137, 0.962), Vector2(0.201, 0.976), Vector2(0.218, 0.984), Vector2(0.231, 0.996), Vector2(0.238, 1.012),
	Vector2(0.235, 1.029), Vector2(0.223, 1.041), Vector2(0.208, 1.046), Vector2(0.167, 1.04), Vector2(0.118, 1.034),
	Vector2(0.059, 1.036), Vector2(0.0, 1.038), Vector2(-0.059, 1.036), Vector2(-0.118, 1.034), Vector2(-0.167, 1.04),
	Vector2(-0.208, 1.046), Vector2(-0.223, 1.041), Vector2(-0.235, 1.029), Vector2(-0.238, 1.012), Vector2(-0.231, 0.996),
	Vector2(-0.218, 0.984),
]
const CREST_HALF_WIDTH := 0.238
const CREST_Z := 0.345                       # 搭脑两端的中心 z;中间往后弓出 CREST_BOW
const CREST_BOW := 0.018
const CREST_DEPTH := 0.026
const CREST_BEVEL := 0.007
# 木纹坐标系:部件的 Y 轴 = 椅子的 X 轴(座面、搭脑的纹理顺着椅宽)
const GRAIN_X := Transform3D(Basis(Vector3.BACK, -PI / 2.0), Vector3.ZERO)
# 各部件的顶点色:同一种木材,腿和撑压暗一点,座面、搭脑是被坐、被摸得最多的亮面
const TINT_LEGS := Color(0.8, 0.78, 0.76)
const TINT_BACK := Color(0.9, 0.88, 0.86)


static func build(parent: Node3D) -> void:
	MeshBatch.instance(parent, mesh(), {}, "Chair")


static func mesh() -> ArrayMesh:
	return MeshBatch.cached("chair", func(b: MeshBatch) -> void:
		var wood := TableModel.turned_wood()
		_add_seat(b, wood)
		_add_legs(b, wood)
		_add_back(b, wood))


# —— 座面 ——

static func _add_seat(b: MeshBatch, wood: Material) -> void:
	var disc := MeshShapes.lathe(PackedVector2Array(SEAT_PROFILE), SEGMENTS_SEAT)
	var seat := MeshShapes.deform(disc, _seat_point)
	b.add_arrays(TableShapes.transformed(seat, GRAIN_X.affine_inverse()), wood, GRAIN_X, Color.WHITE, 0.31)


static func _seat_point(v: Vector3) -> Vector3:
	# 单位圆盘上的点 → 座面:按方位取超椭圆轮廓上的点、按半径比例缩放;顶面那一层压出马鞍形坐窝
	var r := Vector2(v.x, v.z).length()
	var c := v.x / maxf(r, 1e-6)
	var s := v.z / maxf(r, 1e-6)
	var n := SEAT_ROUNDNESS.y if s > 0.0 else SEAT_ROUNDNESS.x
	var edge := Vector2(signf(c) * pow(absf(c), 2.0 / n), signf(s) * pow(absf(s), 2.0 / n)) * SEAT_HALF
	var p := edge * r
	var top_band := clampf(1.0 + v.y / SADDLE_BAND, 0.0, 1.0)
	return Vector3(p.x, SEAT_TOP + v.y - _saddle(p / SEAT_HALF) * top_band, SEAT_CENTER_Z + p.y)


static func _saddle(q: Vector2) -> float:
	# 坐窝:座面归一化坐标里的一个椭圆浅坑,窝心偏后,边缘平滑地回到原高度
	var d := Vector2(q.x / SADDLE_SPREAD.x, (q.y - SADDLE_CENTER) / SADDLE_SPREAD.y).length_squared()
	var t := clampf(1.0 - d, 0.0, 1.0)
	return SADDLE_DEPTH * t * t * (3.0 - 2.0 * t)


# —— 椅腿与横撑 ——

static func _add_legs(b: MeshBatch, wood: Material) -> void:
	var front_from: Vector3 = FRONT_LEG[0]
	var leg := TableShapes.turned(LEG_PROFILE, front_from.distance_to(FRONT_LEG[1]), SEGMENTS_LEG)
	var stretcher_ends := []
	for side in [-1.0, 1.0]:
		var mirror := Vector3(side, 1.0, 1.0)
		var legs := [[FRONT_LEG[0] * mirror, FRONT_LEG[1] * mirror], [BACK_LEG[0] * mirror, BACK_LEG[1] * mirror]]
		for ends in legs:
			b.add_arrays(leg, wood, TableShapes.between(ends[0], ends[1]), TINT_LEGS)
		var front: Vector3 = (legs[0][0] as Vector3).lerp(legs[0][1], STRETCHER_AT)
		var back: Vector3 = (legs[1][0] as Vector3).lerp(legs[1][1], STRETCHER_AT)
		_add_turned(b, wood, STRETCHER_PROFILE, front, back, SEGMENTS_LEG, TINT_LEGS)
		stretcher_ends.append((front + back) / 2.0)
	_add_turned(b, wood, STRETCHER_PROFILE, stretcher_ends[0], stretcher_ends[1], SEGMENTS_LEG, TINT_LEGS)


static func _add_turned(b: MeshBatch, wood: Material, profile: Array, from: Vector3, to: Vector3, segments: int,
		tint: Color) -> void:
	b.add_arrays(TableShapes.turned(profile, from.distance_to(to), segments), wood, TableShapes.between(from, to), tint)


# —— 椅背 ——

static func _add_back(b: MeshBatch, wood: Material) -> void:
	for side in [-1.0, 1.0]:
		var mirror := Vector3(side, 1.0, 1.0)
		_add_turned(b, wood, POST_PROFILE, POST[0] * mirror, POST[1] * mirror, SEGMENTS_POST, TINT_BACK)
	for x in SPINDLE_XS:
		var top_x: float = x * SPINDLE_FAN
		var bottom := Vector3(x, SPINDLE_BOTTOM.x, SPINDLE_BOTTOM.y)
		var top := Vector3(top_x, _crest_bottom(top_x) + SPINDLE_INTO_RAIL, _crest_z(top_x))
		_add_turned(b, wood, SPINDLE_PROFILE, bottom, top, SEGMENTS_SPINDLE, TINT_BACK)
	var crest := MeshShapes.extrude(PackedVector2Array(CREST_OUTLINE), CREST_DEPTH, CREST_BEVEL)
	crest = TableShapes.bowed(crest, CREST_BOW, CREST_HALF_WIDTH)
	crest = TableShapes.transformed(crest, Transform3D(Basis.IDENTITY, Vector3(0, 0, CREST_Z)))
	b.add_arrays(TableShapes.transformed(crest, GRAIN_X.affine_inverse()), wood, GRAIN_X, Color.WHITE, 0.67)


static func _crest_z(x: float) -> float:
	var u := x / CREST_HALF_WIDTH
	return CREST_Z + CREST_BOW * (1.0 - u * u)


static func _crest_bottom(x: float) -> float:
	# 搭脑下沿在 x 处的高度:在轮廓下沿的折线上插值
	for i in range(1, 7):
		var a: Vector2 = CREST_OUTLINE[i - 1]
		var c: Vector2 = CREST_OUTLINE[i]
		if x <= c.x:
			return lerpf(a.y, c.y, inverse_lerp(a.x, c.x, x))
	return (CREST_OUTLINE[6] as Vector2).y
