class_name RevolverModel
# 左轮的网格配方(纯数组运算,可在工作线程跑):单动左轮,原点 = 握持点(爪心),枪管沿 −Z,+Y 向上。
# 机身(钢、黄铜、暗膛 + 胡桃木握把)、转轮(5 个完全一样的弹膛,网格五重对称)、击锤各一份,所有左轮共享。
# 尺寸见 2026-10-07-visual-overhaul-p3-props.md §2.1;转轮在 DRUM_POS、击锤在 HAMMER_PIVOT 的局部坐标里建。
# 动森式玩具枪(2026-10-08):枪管加粗、枪口冠大圆角,机匣与击锤倒角加大,护圈与背带加粗,去掉螺丝等碎件;
# 转轮外轮廓与握把下端不动(REST_* 由测试按这两处的顶点校验,角色举枪依赖 BARREL_Y / MUZZLE_POS / DRUM_POS)。


const BARREL_Y := 0.073          # 枪管轴线高度
const BARREL_ROOT_Z := -0.067    # 枪管根部(机匣前块后面)
const CROWN_Z := -0.255          # 枪口冠
const DRUM_POS := Vector3(0, 0.055, -0.042)
const DRUM_RADIUS := 0.031
const DRUM_LENGTH := 0.050
const CHAMBER_RADIUS := BARREL_Y - 0.055   # 弹膛中心离转轮轴 0.018:12 点的弹膛与枪管同轴
const CHAMBER_HOLE := 0.0065
const CHAMBER_DEPTH := 0.004
const FLUTE_DEPTH := 0.0045
const FLUTE_HALF_WIDTH := 0.22   # 弧度
const DRUM_STEPS := 120          # 轮廓点数:10 的倍数,弹膛线与凹槽线都落在点上
const HAMMER_PIVOT := Vector3(0, 0.086, 0.010)
const MUZZLE_POS := Vector3(0, BARREL_Y, -0.259)


static func _p(f: MeshForge, entry: String) -> void:
	WorldMaterials.paint_prop(f, entry)


static func _side(points_zy: Array) -> PackedVector2Array:
	# 侧视轮廓 (z, y) → extrude 的 (u, y);配合 _side_xf 把挤出方向转到 X
	var out := PackedVector2Array()
	for p: Vector2 in points_zy:
		out.append(Vector2(-p.x, p.y))
	return out


static func _side_xf(x := 0.0) -> Transform3D:
	# extrude 的局部 (u, y, w) → 枪的 (w + x, y, −u)
	return Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(x, 0, 0))


static func chamber_angle(i: int) -> float:
	# 第一个弹膛在 12 点,与枪管同轴
	return PI / 2.0 + TAU * i / Revolver.CHAMBERS


static func chamber_offset(i: int) -> Vector3:
	var a := chamber_angle(i)
	return Vector3(cos(a), sin(a), 0) * CHAMBER_RADIUS


# —— 机身 ——

static func body(f: MeshForge) -> void:
	var xf := MeshForge.xf
	# 胡桃木犁柄握把:向后倾、下端外撇,截面 24 点 × 10 环
	f.surface(&"grip")
	f.part_space = true
	f.paint(Color.WHITE, 0.5)
	var grip := _grip_rings()
	f.loft(grip[0], grip[1], 24, Vector2i(1, 1), Transform3D.IDENTITY, PackedColorArray(), Vector2(-1, -1), Vector3.RIGHT)
	f.part_space = false
	f.surface(&"metal")
	_p(f, "steel")
	# 机匣后块:防退护板、击锤座、背带顶(10 点侧轮廓)
	f.extrude(_side([Vector2(-0.017, 0.016), Vector2(-0.017, 0.095), Vector2(0.0, 0.095), Vector2(0.006, 0.091),
		Vector2(0.015, 0.074), Vector2(0.020, 0.048), Vector2(0.020, 0.022), Vector2(0.016, 0.006),
		Vector2(-0.003, 0.002), Vector2(-0.012, 0.010)]), 0.031, 0.0045, _side_xf())
	# 机匣前块(枪管从这里出去)与上下梁:框住转轮
	f.extrude(_side([Vector2(-0.067, 0.016), Vector2(-0.067, 0.095), Vector2(-0.079, 0.095), Vector2(-0.086, 0.089),
		Vector2(-0.087, 0.052), Vector2(-0.080, 0.030), Vector2(-0.072, 0.016)]), 0.030, 0.0045, _side_xf())
	f.extrude(_side([Vector2(-0.069, 0.088), Vector2(-0.015, 0.088), Vector2(-0.015, 0.095), Vector2(-0.069, 0.095)]),
		0.018, 0.003, _side_xf())
	f.extrude(_side([Vector2(-0.069, 0.016), Vector2(-0.015, 0.016), Vector2(-0.015, 0.0235), Vector2(-0.069, 0.0235)]),
		0.022, 0.003, _side_xf())
	# 枪管:根部加粗段 + 主管(玩具式加粗)+ 4 mm 大圆角的枪口冠,车削 32 段(车削轴 +Y 转到 −Z)
	var barrel_xf := Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(0, BARREL_Y, BARREL_ROOT_Z))
	var length := BARREL_ROOT_Z - CROWN_Z
	var barrel := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.0148, 0.0), Vector2(0.0148, 0.016), Vector2(0.0128, 0.022)])
	for k in 6:
		var a := PI / 2.0 * k / 5.0
		barrel.append(Vector2(0.0128 - 0.004 + cos(a) * 0.004, length - 0.004 + sin(a) * 0.004))
	barrel.append(Vector2(0.0055, length))
	f.lathe(barrel, 32, PackedInt32Array([1, 2]), barrel_xf)
	_p(f, "steel_dark")
	f.lathe(PackedVector2Array([Vector2(0.0055, length), Vector2(0.0055, length - 0.008), Vector2(0.0, length - 0.008)]),
		16, PackedInt32Array([1]), barrel_xf)
	_p(f, "steel")
	# 转轮轴销(从前块伸出一点)
	f.cylinder(0.0035, 0.0035, 0.008, 10, MeshForge.CAPS_BOTH, xf.call(DRUM_POS + Vector3(0, 0, -0.087 - DRUM_POS.z), Vector3(90, 0, 0)))
	# 退壳杆护套(右侧,贴着枪管下沿)与杆头
	var ejector := Vector3(0.0095, 0.0585, 0.0)
	f.cylinder(0.0058, 0.0058, 0.116, 16, MeshForge.CAPS_BOTH, xf.call(ejector + Vector3(0, 0, -0.138), Vector3(90, 0, 0)))
	f.sphere(0.0058, 12, xf.call(ejector + Vector3(0, 0, -0.196)))
	# 半月形准星刀片
	var sight := []
	for k in 9:
		var a := PI * k / 8.0
		sight.append(Vector2(-0.242 + cos(a) * 0.0065, BARREL_Y + 0.009 + sin(a) * 0.0105))
	f.extrude(_side(sight), 0.005, 0.0016, _side_xf())
	# 扳机:新月形,厚 4 mm
	_p(f, "steel")
	f.extrude(_side([Vector2(-0.021, 0.018), Vector2(-0.026, 0.011), Vector2(-0.029, 0.003), Vector2(-0.0285, -0.004),
		Vector2(-0.0255, -0.0065), Vector2(-0.0235, -0.001), Vector2(-0.021, 0.007), Vector2(-0.0155, 0.018)]),
		0.0055, 0.0018, _side_xf())
	# 黄铜护圈与背带
	_p(f, "brass")
	f.tube(PackedVector3Array([Vector3(0, 0.018, -0.050), Vector3(0, 0.008, -0.0505), Vector3(0, -0.003, -0.0475),
		Vector3(0, -0.011, -0.0395), Vector3(0, -0.0145, -0.0285), Vector3(0, -0.012, -0.0175), Vector3(0, -0.005, -0.0105),
		Vector3(0, 0.004, -0.0075)]), 0.0048, 10)
	var back := PackedVector3Array()
	var path: PackedVector3Array = grip[0]
	var radii: PackedVector2Array = grip[1]
	for i in range(1, path.size() - 1):
		back.append(path[i] + Vector3(0, 0, radii[i].y - 0.0012))
	f.tube(back, 0.0038, 8)
	# 底帽
	var bottom: Vector3 = path[path.size() - 1]
	f.sphere(0.0185, 16, xf.call(bottom + Vector3(0, -0.0005, 0), Vector3(-14, 0, 0), Vector3(0.97, 0.36, 1.08)))


static func _grip_rings() -> Array:
	# [路径, 半径(横向半宽, 前后半深)]:y 0.022 → −0.074,向后倾,下端撇得更开
	var ys := [0.022, 0.010, -0.002, -0.014, -0.026, -0.038, -0.050, -0.060, -0.068, -0.074]
	var zs := [0.004, 0.006, 0.009, 0.011, 0.014, 0.017, 0.021, 0.025, 0.029, 0.033]
	var wx := [0.0125, 0.013, 0.0135, 0.014, 0.0145, 0.015, 0.0158, 0.0165, 0.017, 0.0165]
	var dz := [0.0155, 0.016, 0.0165, 0.017, 0.0175, 0.018, 0.0185, 0.019, 0.019, 0.018]
	var path := PackedVector3Array()
	var radii := PackedVector2Array()
	for i in ys.size():
		path.append(Vector3(0, ys[i], zs[i]))
		radii.append(Vector2(wx[i], dz[i]))
	return [path, radii]


# —— 转轮(DRUM_POS 局部,轴沿 Z)——

static func drum_outline() -> PackedVector2Array:
	# 圆周上 5 道弧形凹槽(在弹膛之间);第 0 点在 12 点的弹膛线上,每 DRUM_STEPS/10 点一条弹膛线或凹槽线
	var out := PackedVector2Array()
	for k in DRUM_STEPS:
		var a := PI / 2.0 + TAU * k / DRUM_STEPS
		var sector := TAU / Revolver.CHAMBERS
		var delta := absf(wrapf(a - PI / 2.0 - sector / 2.0, -sector / 2.0, sector / 2.0))
		var r := DRUM_RADIUS
		if delta < FLUTE_HALF_WIDTH:
			r -= FLUTE_DEPTH * sqrt(1.0 - pow(delta / FLUTE_HALF_WIDTH, 2.0))
		out.append(Vector2(cos(a), sin(a)) * r)
	return out


static func drum(f: MeshForge) -> void:
	var xf := MeshForge.xf
	f.surface(&"metal")
	_p(f, "steel")
	var outline := drum_outline()
	var bevel := 0.0038   # 玩具式大倒角(只缩端面,侧面外轮廓不变)
	var half := DRUM_LENGTH / 2.0
	# 侧面、后端倒角与后端面;前端面另外拼(带 5 个弹膛孔)
	f.extrude(outline, DRUM_LENGTH, bevel, Transform3D.IDENTITY, Vector2i(0, 1))
	var inset := MeshForge.extrude_inset(outline, bevel)
	# 前端面:10 个 36° 半扇区,每块沿弹膛线切开,弹膛的半圆是它边界上的缺口(简单多边形,直接三角化)
	var steps := DRUM_STEPS / (Revolver.CHAMBERS * 2)
	var half_a := PackedVector2Array([Vector2.ZERO])
	var u := Vector2(0, 1)              # 12 点弹膛线
	var v := Vector2(-1, 0)             # 朝角度增大一侧
	var c := u * CHAMBER_RADIUS
	for k in 9:
		var phi := PI * k / 8.0
		half_a.append(c - u * cos(phi) * CHAMBER_HOLE + v * sin(phi) * CHAMBER_HOLE)
	for k in steps + 1:
		half_a.append(inset[k])
	var tris := Geometry2D.triangulate_polygon(half_a)
	var flute_dir := Vector2(cos(PI / 2.0 + PI / Revolver.CHAMBERS), sin(PI / 2.0 + PI / Revolver.CHAMBERS))
	var half_b := PackedVector2Array()
	for p in half_a:
		half_b.append(flute_dir * (2.0 * p.dot(flute_dir)) - p)   # 沿凹槽线镜像
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in Revolver.CHAMBERS:
		var rot := Transform2D(TAU * i / Revolver.CHAMBERS, Vector2.ZERO)
		for part in 2:
			var poly := half_a if part == 0 else half_b
			var base := points.size()
			for p in poly:
				var q := rot * p
				points.append(Vector3(q.x, q.y, -half))
				normals.append(Vector3(0, 0, -1))
			for k in range(0, tris.size(), 3):
				# 端面朝 −Z(三角化结果从 +Z 看逆时针,从 −Z 看正好是 Godot 的正面);镜像那半块绕序相反
				if part == 0:
					indices.append_array([base + tris[k], base + tris[k + 1], base + tris[k + 2]])
				else:
					indices.append_array([base + tris[k], base + tris[k + 2], base + tris[k + 1]])
	f.raw(points, normals, PackedVector2Array(), indices)
	# 弹膛孔:4 mm 深的暗色小杯,完全相同;后端被防退护板挡住,不显示弹壳
	_p(f, "steel_dark")
	for i in Revolver.CHAMBERS:
		var a := chamber_angle(i)
		var cup := Transform3D(Basis(Vector3.BACK, a - PI / 2.0) * Basis(Vector3.RIGHT, PI / 2.0), chamber_offset(i) + Vector3(0, 0, -half))
		f.lathe(PackedVector2Array([Vector2(0.0, CHAMBER_DEPTH), Vector2(CHAMBER_HOLE, CHAMBER_DEPTH), Vector2(CHAMBER_HOLE, 0.0)]),
			16, PackedInt32Array([1]), cup)
	# 轴心:前端面中间的轴套
	_p(f, "steel")
	f.cylinder(0.0045, 0.005, 0.0016, 20, MeshForge.CAPS_BOTH, xf.call(Vector3(0, 0, -half - 0.0008), Vector3(90, 0, 0)))


# —— 击锤(HAMMER_PIVOT 局部)——

static func hammer(f: MeshForge) -> void:
	f.surface(&"metal")
	_p(f, "steel")
	f.extrude(_side([Vector2(-0.007, -0.006), Vector2(0.004, -0.009), Vector2(0.010, 0.002), Vector2(0.016, 0.010),
		Vector2(0.024, 0.0155), Vector2(0.0295, 0.0165), Vector2(0.0285, 0.0215), Vector2(0.020, 0.024),
		Vector2(0.010, 0.0215), Vector2(0.002, 0.016), Vector2(-0.004, 0.008)]), 0.0105, 0.003, _side_xf())
