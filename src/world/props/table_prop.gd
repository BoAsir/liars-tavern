class_name TableProp
# 牌桌:台面(封闭圆盘,桌面在 r ≤ 半径 + 0.03 内严格平整,外缘圆鼻边)、裙板、瓶状桌柱、四条 cabriole 弯腿与爪球足、
# 齐平的黄铜嵌条、毡面。台面、裙板、嵌条与毡面跟着桌面半径重建(按半径缓存网格);桌柱与腿不随半径变。
# 节点:Table(桌根,原点在桌心地面)下 TableTop(木纹 table / dark + prop 三个 surface)、TableBase(turned + prop)、
# Felt(毡面材质,不投影;放在桌根原点,毡面着色器的 obj_pos 以桌心为原点)。


const SEGMENTS := 96
const FLAT_REACH := 0.03       # 桌面在 r ≤ 半径 + FLAT_REACH 内严格平整(爪心落在 r≈0.92±0.058)
const NOSE := 0.016            # 圆鼻边半径:外沿在 半径 + 0.046(骗子酒馆桌 0.996)
const THICKNESS := 0.045       # 台面厚度
const FELT_THICKNESS := SeatLayout.FELT_TOP - SeatLayout.TABLE_TOP
const FELT_EDGE := 0.003       # 毡面边缘圆角
const INLAY := Vector2(-0.007, 0.008)   # 黄铜嵌条的内外半径(相对桌面半径),只高出台面 0.5 mm
const LEG_COUNT := 4


static func build(parent: Node3D) -> Node3D:
	var table := MeshKit.pivot(parent, Vector3.ZERO, "Table")
	MeshKit.add(table, top_mesh(SeatLayout.TABLE_RADIUS), null).name = "TableTop"
	MeshKit.add(table, MeshForge.cached("prop:table_base", base_recipe,
		{&"turned": WorldMaterials.wood("turned", true), &"metal": WorldMaterials.prop()}), null).name = "TableBase"
	var felt := MeshKit.add(table, felt_mesh(SeatLayout.TABLE_RADIUS), felt_material(SeatLayout.TABLE_RADIUS),
		Vector3.ZERO, Vector3.ZERO, Vector3.ONE, MeshKit.SHADOW_OFF)
	felt.name = "Felt"
	return table


static func set_radius(table: Node3D, radius: float) -> void:
	# 桌面、包边、铜嵌条与毡面按半径换网格(缓存);桌面高度、桌柱与腿不变
	(table.get_node("TableTop") as MeshInstance3D).mesh = top_mesh(radius)
	var felt: MeshInstance3D = table.get_node("Felt")
	felt.mesh = felt_mesh(radius)
	felt.material_override = felt_material(radius)


static func felt_radius(radius: float) -> float:
	# 毡面外沿到桌沿的木边宽度不变(骗子酒馆桌 0.95 → 0.82)
	return SeatLayout.FELT_RADIUS + (radius - SeatLayout.TABLE_RADIUS)


static func felt_material(radius: float) -> ShaderMaterial:
	return WorldMaterials.felt() if is_equal_approx(radius, SeatLayout.TABLE_RADIUS) \
		else WorldMaterials.felt_sized(felt_radius(radius))


static func top_mesh(radius: float) -> ArrayMesh:
	return MeshForge.cached("prop:table_top:%.3f" % radius, func(f: MeshForge): top_recipe(f, radius),
		{&"table": WorldMaterials.wood("table"), &"dark": WorldMaterials.wood("dark"), &"metal": WorldMaterials.prop()})


static func felt_mesh(radius: float) -> ArrayMesh:
	return MeshForge.cached("prop:table_felt:%.3f" % radius, func(f: MeshForge): felt_recipe(f, radius))


static func profile(radius: float) -> PackedVector2Array:
	# 台面车削轮廓 (r, y),自下而上(底面从桌心往外 → 外缘 → 圆鼻边 → 桌面回到桌心),封闭圆盘
	var top := SeatLayout.TABLE_TOP
	var flat := radius + FLAT_REACH
	var outer := flat + NOSE
	var pts := PackedVector2Array([Vector2(0.0, top - THICKNESS), Vector2(radius - 0.06, top - THICKNESS),
		Vector2(outer - 0.008, top - THICKNESS), Vector2(outer - 0.002, top - THICKNESS + 0.003),
		Vector2(outer, top - THICKNESS + 0.009), Vector2(outer, top - NOSE)])
	for k in range(1, 9):
		var a := PI / 2.0 * k / 8.0
		pts.append(Vector2(flat + cos(a) * NOSE, top - NOSE + sin(a) * NOSE))
	pts.append(Vector2(radius - 0.15, top))
	pts.append(Vector2(0.0, top))
	return pts


static func top_recipe(f: MeshForge, radius: float) -> void:
	var top := SeatLayout.TABLE_TOP
	f.surface(&"table")
	f.lathe(profile(radius), SEGMENTS)
	# 裙板(深色木,底边一道串珠线脚):挂在台面下,跟着半径走
	f.surface(&"dark")
	f.lathe(PackedVector2Array([Vector2(radius - 0.09, top - THICKNESS - 0.001), Vector2(radius - 0.09, top - 0.125),
		Vector2(radius - 0.068, top - 0.125), Vector2(radius - 0.062, top - 0.121), Vector2(radius - 0.059, top - 0.114),
		Vector2(radius - 0.062, top - 0.107), Vector2(radius - 0.07, top - 0.103), Vector2(radius - 0.07, top - THICKNESS - 0.001)]),
		SEGMENTS, PackedInt32Array([1, 2, 6]))
	# 齐平的黄铜嵌条:只高出台面 0.5 mm(爪子就搭在这一圈上)
	f.surface(&"metal")
	WorldMaterials.paint_prop(f, "brass")
	var r0 := radius + INLAY.x
	var r1 := radius + INLAY.y
	f.lathe(PackedVector2Array([Vector2(r1, top - 0.0005), Vector2(r1, top + 0.0005), Vector2(r0, top + 0.0005),
		Vector2(r0, top - 0.0005)]), SEGMENTS, PackedInt32Array([1, 2]))


static func felt_recipe(f: MeshForge, radius: float) -> void:
	# 车削垫:顶面 = FELT_TOP,边缘 3 mm 圆角,外沿 = 毡面半径 − 2 mm
	var top := SeatLayout.TABLE_TOP
	var outer := felt_radius(radius) - 0.002
	var pts := PackedVector2Array([Vector2(0.0, top), Vector2(outer, top), Vector2(outer, top + FELT_THICKNESS - FELT_EDGE)])
	for k in range(1, 5):
		var a := PI / 2.0 * k / 4.0
		pts.append(Vector2(outer - FELT_EDGE + cos(a) * FELT_EDGE, top + FELT_THICKNESS - FELT_EDGE + sin(a) * FELT_EDGE))
	pts.append(Vector2(0.0, SeatLayout.FELT_TOP))
	f.lathe(pts, SEGMENTS, PackedInt32Array([1]))


static func base_recipe(f: MeshForge) -> void:
	# 瓶状桌柱(y 0.10–0.66,三道环)+ 柱头托盘 + 四条 cabriole 弯腿(朝 45° + k·90°,落在座位之间)+ 黄铜柱箍与爪球足
	var top := SeatLayout.TABLE_TOP
	f.surface(&"turned")
	f.part_space = true
	f.lathe(PackedVector2Array([Vector2(0.0, 0.06), Vector2(0.15, 0.06), Vector2(0.155, 0.10), Vector2(0.13, 0.13),
		Vector2(0.10, 0.15), Vector2(0.115, 0.17), Vector2(0.09, 0.19), Vector2(0.12, 0.27), Vector2(0.13, 0.34),
		Vector2(0.11, 0.42), Vector2(0.075, 0.49), Vector2(0.092, 0.51), Vector2(0.07, 0.53), Vector2(0.06, 0.58),
		Vector2(0.07, 0.62), Vector2(0.095, 0.64), Vector2(0.085, 0.652), Vector2(0.12, 0.668), Vector2(0.16, 0.69),
		Vector2(0.21, 0.70), Vector2(0.22, 0.71), Vector2(0.22, top - THICKNESS - 0.001), Vector2(0.0, top - THICKNESS - 0.001)]),
		40, PackedInt32Array([1, 2, 4, 5, 6, 11, 12, 15, 16, 20, 21]))
	for k in LEG_COUNT:
		var yaw := PI / 4.0 + k * PI / 2.0
		var dir := Vector3(sin(yaw), 0, cos(yaw))
		var path := PackedVector3Array()
		var radii := PackedVector2Array()
		var stations := [[0.10, 0.17, 0.052], [0.17, 0.165, 0.05], [0.24, 0.14, 0.046], [0.29, 0.10, 0.036],
			[0.33, 0.065, 0.027], [0.365, 0.045, 0.021], [0.395, 0.04, 0.02], [0.415, 0.045, 0.021]]
		for st in stations:
			path.append(dir * st[0] + Vector3(0, st[1], 0))
			radii.append(Vector2(st[2], st[2] * 0.8))
		f.seed = float(k)
		f.loft(path, radii, 12, Vector2i(1, 1), Transform3D.IDENTITY, PackedColorArray(), Vector2(-1, -1), Vector3.UP)
	f.part_space = false
	f.seed = 0.0
	f.surface(&"metal")
	WorldMaterials.paint_prop(f, "brass")
	f.lathe(PackedVector2Array([Vector2(0.086, 0.650), Vector2(0.104, 0.653), Vector2(0.108, 0.660), Vector2(0.104, 0.667),
		Vector2(0.086, 0.670)]), 40)
	for k in LEG_COUNT:
		var yaw := PI / 4.0 + k * PI / 2.0
		var dir := Vector3(sin(yaw), 0, cos(yaw))
		var ball := dir * 0.418 + Vector3(0, 0.026, 0)
		f.sphere(0.026, 16, MeshForge.xf(ball))
		# 三根爪趾扣住球顶
		for toe in 3:
			var side := (toe - 1) * 0.55
			var toe_dir := (dir * cos(side) + Vector3(dir.z, 0, -dir.x) * sin(side)).normalized()
			f.tube(PackedVector3Array([ball + Vector3(0, 0.03, 0) - dir * 0.01, ball + toe_dir * 0.02 + Vector3(0, 0.022, 0),
				ball + toe_dir * 0.028 + Vector3(0, 0.006, 0)]), 0.0055, 6)
