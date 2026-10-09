class_name SconceModel
# 壁灯的造型:墙上一块带斜边的盾形深色木牌,钉着黄铜圆座,伸出一根天鹅颈弯臂(臂下挂一个卷涡),
# 托着带圆边的接蜡盘与烛插;插着一截熔过的短蜡烛,外罩一只鼓腹的防风玻璃罩。
# 局部坐标:原点在墙面,-Z 指向房间;火苗在 FLAME_POS(与旧版同一位置,灯光也不挪)。
# 所有壁灯拼成两个缓存网格(TavernSconces 按各自的墙面位置摆放):木、铜、蜡一个,玻璃一个(透明,先于火苗画)。


const FLAME_POS := Vector3(0, 0.03, -0.15)
const AXIS_Z := -0.15             # 接蜡盘、蜡烛、玻璃罩的中轴
# 木牌右半边轮廓(x ≥ 0,从底尖往上到顶心),左半边镜像
const PLAQUE_HALF := [
	Vector2(0.0, -0.178), Vector2(0.022, -0.168), Vector2(0.042, -0.148), Vector2(0.054, -0.12), Vector2(0.056, -0.09),
	Vector2(0.05, -0.05), Vector2(0.046, -0.01), Vector2(0.048, 0.03), Vector2(0.054, 0.062), Vector2(0.053, 0.085),
	Vector2(0.044, 0.103), Vector2(0.03, 0.114), Vector2(0.015, 0.119), Vector2(0.0, 0.12),
]
const PLAQUE_DEPTH := 0.016
const PLAQUE_BEVEL := 0.005
const PLAQUE_TINT := Color(0.32, 0.28, 0.26)    # 压暗:灯就在木牌跟前,原色会被照成一块浅色木板
# 木牌正面再叠一块缩小的凸起镶板(同一轮廓按中心缩放),边上一圈斜角,像车过线脚的木牌而不是一块平板
const PANEL_CENTER := Vector2(0.0, -0.03)
const PANEL_SCALE := Vector2(0.74, 0.86)
const PANEL_DEPTH := 0.006
const PANEL_BEVEL := 0.0028
const PANEL_TINT := Color(0.4, 0.35, 0.32)
const PLAQUE_FRONT := -PLAQUE_DEPTH + 0.001 - PANEL_DEPTH + 0.002   # 镶板正面(圆座贴在这里)
# 黄铜圆座(沿 +Y 车出,再转成朝房间):底盘 → 圆鼓 → 接弯臂的短颈
const BOSS_Y := -0.07
const BOSS_PROFILE := [
	Vector2(0.0, -0.002), Vector2(0.025, -0.002), Vector2(0.0262, 0.002), Vector2(0.0235, 0.006), Vector2(0.016, 0.0095),
	Vector2(0.0105, 0.012), Vector2(0.01, 0.019), Vector2(0.0, 0.0195),
]
const SEGMENTS_SMALL := 12
const SEGMENTS_ROUND := 14
# 天鹅颈弯臂:从圆座伸出,先微微下沉,再弯上来托住接蜡盘的底
const ARM_PATH := [
	Vector3(0, -0.07, -0.03), Vector3(0, -0.072, -0.055), Vector3(0, -0.08, -0.085), Vector3(0, -0.087, -0.112),
	Vector3(0, -0.084, -0.134), Vector3(0, -0.074, -0.147), Vector3(0, -0.062, -0.151),
]
const ARM_RADII := [0.0058, 0.0056, 0.0052, 0.005, 0.0048, 0.0048, 0.0046]
# 臂下的卷涡:从弯臂上垂下,绕 1.3 圈收进中心((y, z) 平面里的螺线)
const SCROLL_CENTER := Vector2(-0.104, -0.068)
const SCROLL_TURNS := 1.3
const SCROLL_RADIUS := Vector2(0.024, 0.006)     # 起点、终点的螺线半径
const SCROLL_WIRE := Vector2(0.0036, 0.0022)
const SCROLL_POINTS := 12
# 接蜡盘与烛插(半径, 相对盘底的高度):外底 → 圆边 → 盘心 → 烛插 → 插口
const CUP_Y := -0.066
const CUP_PROFILE := [
	Vector2(0.0, 0.0), Vector2(0.013, 0.0), Vector2(0.03, 0.007), Vector2(0.0378, 0.0105), Vector2(0.0385, 0.0135),
	Vector2(0.0345, 0.0142), Vector2(0.021, 0.0112), Vector2(0.0178, 0.0135), Vector2(0.0172, 0.0275),
	Vector2(0.0192, 0.0298), Vector2(0.0, 0.0298),
]
# 短蜡烛:烛芯根部略低于火苗公告板的底边
const CANDLE_TOP := -0.002
const CANDLE_LENGTH := 0.044
const CANDLE_RADIUS := 0.0135
const WAX_TINT := Color(0.95, 0.9, 0.82)
# 防风玻璃罩(半径, 高度):立在接蜡盘里,中段鼓起,口沿微微外翻;上下都敞口
const CHIMNEY_PROFILE := [
	Vector2(0.0295, -0.054), Vector2(0.034, -0.038), Vector2(0.0395, -0.015), Vector2(0.0425, 0.012),
	Vector2(0.0415, 0.042), Vector2(0.0365, 0.072), Vector2(0.0318, 0.097), Vector2(0.0322, 0.106), Vector2(0.035, 0.112),
]


static func fittings_mesh(placements: Array) -> ArrayMesh:
	# placements: 每盏壁灯的 Transform3D(墙面位置 + 朝向)。木、铜、蜡三个表面
	return MeshBatch.cached("sconce_fittings", func(b: MeshBatch) -> void:
		var parts := _fitting_parts()
		for i in placements.size():
			_add_fittings(b, parts, placements[i], i))


static func glass_mesh(placements: Array) -> ArrayMesh:
	return MeshBatch.cached("sconce_glass", func(b: MeshBatch) -> void:
		var chimney := MeshShapes.lathe(PackedVector2Array(CHIMNEY_PROFILE), SEGMENTS_ROUND)
		for xform in placements:
			b.add_arrays(chimney, glass_material(), xform * Transform3D(Basis.IDENTITY, Vector3(0, 0, AXIS_Z))))


static func glass_material() -> ShaderMaterial:
	# render_priority 比火苗低:玻璃先画、火苗(加色)后画,罩里的火苗不会被玻璃盖暗
	return WorldMaterials.cached("sconce_glass", func():
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://src/world/shaders/lamp_glass.gdshader")
		mat.render_priority = -1
		mat.set_shader_parameter("glow_height", FLAME_POS.y)
		return mat)


# —— 部件 ——

static func _fitting_parts() -> Dictionary:
	# 每盏壁灯都一样的几何只生成一次,按各自的位置摆放 7 遍
	return {
		"plaque": MeshShapes.extrude(_plaque_outline(), PLAQUE_DEPTH, PLAQUE_BEVEL),
		"panel": MeshShapes.extrude(_panel_outline(), PANEL_DEPTH, PANEL_BEVEL),
		"boss": MeshShapes.lathe(PackedVector2Array(BOSS_PROFILE), SEGMENTS_SMALL),
		"arm": MeshShapes.tube(PackedVector3Array(ARM_PATH), PackedFloat32Array(ARM_RADII), 6),
		"scroll": _scroll(),
		"cup": MeshShapes.lathe(PackedVector2Array(CUP_PROFILE), SEGMENTS_ROUND - 2),
		"wick": TableCandles.wick(),
	}


static func _add_fittings(b: MeshBatch, parts: Dictionary, xform: Transform3D, index: int) -> void:
	var brass := WorldMaterials.brass()
	var wax := TableCandles.wax_material()
	var seed := fposmod(index * 0.618 + 0.13, 1.0)
	b.add_arrays(parts["plaque"], TableModel.turned_wood(), xform * _at(Vector3(0, 0, -PLAQUE_DEPTH / 2.0 + 0.001)),
		PLAQUE_TINT, seed)
	b.add_arrays(parts["panel"], TableModel.turned_wood(), xform * _at(Vector3(0, 0, PLAQUE_FRONT + PANEL_DEPTH / 2.0)),
		PANEL_TINT, fposmod(seed + 0.37, 1.0))
	b.add_arrays(parts["boss"], brass, xform * Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, BOSS_Y, PLAQUE_FRONT)))
	b.add_arrays(parts["arm"], brass, xform)
	b.add_arrays(parts["scroll"], brass, xform)
	b.add_arrays(parts["cup"], brass, xform * _at(Vector3(0, CUP_Y, AXIS_Z)))
	# 每根蜡烛熔化的缺口朝向不同,烛身单独生成
	var top := xform * Transform3D(Basis.IDENTITY, Vector3(0, CANDLE_TOP, AXIS_Z))
	var notch := fposmod(index * 2.4 + 0.7, TAU)
	b.add_arrays(TableCandles.candle_body(CANDLE_LENGTH, notch, index + 0.5, CANDLE_RADIUS), wax, top, WAX_TINT, seed)
	b.add_arrays(parts["wick"], wax, top * Transform3D(Basis(Vector3.UP, notch), Vector3.ZERO), TableCandles.WICK_TINT)


static func _at(pos: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, pos)


static func _panel_outline() -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in _plaque_outline():
		out.append(PANEL_CENTER + (p - PANEL_CENTER) * PANEL_SCALE)
	return out


static func _plaque_outline() -> PackedVector2Array:
	var out := PackedVector2Array(PLAQUE_HALF)
	for i in range(PLAQUE_HALF.size() - 2, 0, -1):
		var p: Vector2 = PLAQUE_HALF[i]
		out.append(Vector2(-p.x, p.y))
	return out


static func _scroll() -> Array:
	# 卷涡:螺线从弯臂下方出发,先朝房间、再向下、回卷向墙,半径一路收小,线也越来越细
	var path := PackedVector3Array()
	var radii := PackedFloat32Array()
	for i in SCROLL_POINTS:
		var t := float(i) / (SCROLL_POINTS - 1)
		var a := t * SCROLL_TURNS * TAU
		var r := lerpf(SCROLL_RADIUS.x, SCROLL_RADIUS.y, t)
		path.append(Vector3(0, SCROLL_CENTER.x + r * cos(a), SCROLL_CENTER.y - r * sin(a)))
		radii.append(lerpf(SCROLL_WIRE.x, SCROLL_WIRE.y, t))
	return MeshShapes.tube(path, radii, 5)
