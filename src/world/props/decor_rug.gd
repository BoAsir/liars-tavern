class_name DecorRug
# 牌桌下的圆地毯:一张薄薄的圆饼(边缘略微圆下去,看得出厚度),图案全在 decor_rug.gdshader 里;
# 外圈一排米白流苏,是一根根平贴地面的细条,长短、歪斜各不相同。半径盖住八人德州大桌的椅子圈。
# 地毯最高处离地 RUG_TOP(< 1 厘米),椅子腿陷进去看不出来;不投影。


const RADIUS := 2.45
const RUG_TOP := 0.008
const EDGE_ROLL := 0.014                   # 边缘圆下去的宽度
const SEGMENTS := 96
const FRINGE_COUNT := 400
const FRINGE := Vector3(0.011, 0.003, 0.05)   # 每束流苏:宽 × 离地 × 长
const FRINGE_TINT := Color(0.68, 0.62, 0.52)


static func add_to(detail: MeshBatch) -> void:
	detail.add_arrays(disc(), DecorMaterials.rug())
	_add_fringe(detail)


static func disc() -> Array:
	# 只做顶面与侧边(底面贴地看不见);侧边底部离地半毫米,不和地板抢深度
	var profile := PackedVector2Array([Vector2(RADIUS, 0.0005), Vector2(RADIUS, RUG_TOP * 0.5),
		Vector2(RADIUS - EDGE_ROLL * 0.35, RUG_TOP * 0.9), Vector2(RADIUS - EDGE_ROLL, RUG_TOP),
		Vector2(RADIUS * 0.5, RUG_TOP), Vector2(0.0, RUG_TOP)])
	return MeshShapes.lathe(profile, SEGMENTS)


static func _add_fringe(detail: MeshBatch) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2450
	var strand := MeshKit.plane(Vector2(FRINGE.x, FRINGE.z))
	for i in FRINGE_COUNT:
		var angle := TAU * (i + rng.randf_range(-0.25, 0.25)) / FRINGE_COUNT
		var length := rng.randf_range(0.75, 1.1)
		var skew := rng.randf_range(-12.0, 12.0)
		var reach := RADIUS + FRINGE.z * length * 0.5 - 0.004
		var at := Vector3(cos(angle) * reach, FRINGE.y, sin(angle) * reach)
		# 平面网格的长边沿局部 Z:转到沿半径方向,再歪一点
		var yaw := rad_to_deg(-angle) + 90.0 + skew
		var shade := FRINGE_TINT * rng.randf_range(0.85, 1.05)
		detail.add_part(strand, DecorMaterials.matte(), at, Vector3(0, yaw, 0), Vector3(1, 1, length), shade)
