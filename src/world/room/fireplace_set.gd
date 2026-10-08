class_name FireplaceSet
# 壁炉:按 0.16 × 0.2 半块网格砌的石体(壁柱、过梁、烟囱腔、熏黑的炉膛)、炉床石板、台梁(投影)、
# 炉内与炉边的柴(一个网格,端面露年轮)、柴架与铸铁背板、余烬丘(decor 余烬模式)、火具架、台上摆件、牛骷髅。
# 灯、火焰片与火星粒子的位置与改造前一致(Fireplace 枢轴 (−1.5, 0, −4.4),灯在局部 (0, 0.5, 0.75))。


const PIVOT := RoomLayout.FIRE_PIVOT


static func build(tavern: Node3D) -> Array:
	# 返回要闪烁的灯([Tavern._flickers 的项])
	var fp := MeshKit.pivot(tavern, PIVOT, "Fireplace")
	RoomKit.add(fp, "Stone", "fire:stone", _stone_recipe, {&"main": WorldMaterials.stone("fireplace")}, MeshKit.LAYER_WORLD, true)
	RoomKit.add(fp, "Mantel", "fire:mantel", _mantel_recipe, {&"main": WorldMaterials.wood("beam", true)}, MeshKit.LAYER_WORLD, true)
	RoomKit.add(fp, "Logs", "fire:logs", _logs_recipe, {&"main": WorldMaterials.wood("log", true)}, MeshKit.LAYER_WORLD, true)
	RoomKit.add(fp, "Props", "fire:props", _props_recipe, {&"main": WorldMaterials.prop()}, MeshKit.LAYER_SCENERY, false)
	RoomKit.add(fp, "Embers", "fire:embers", _embers_recipe, {&"main": WorldMaterials.decor()}, MeshKit.LAYER_SCENERY, false)
	for i in 6:
		var h := 0.36 + 0.14 * ((i * 7) % 3)
		RoomKit.flame(fp, Vector2(h * 0.75, h), Vector3(-0.3 + i * 0.12, 0.08 + h / 2.0, 0.32 + (i % 2) * 0.04), 3.0, 20.0 + i)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.5, 0.75)
	light.light_color = Color(1.0, 0.56, 0.3)
	light.light_energy = 2.7
	light.omni_range = 7.0
	light.shadow_enabled = true
	light.shadow_caster_mask = MeshKit.LAYER_WORLD
	light.light_volumetric_fog_energy = 0.6
	fp.add_child(light)
	fp.add_child(Fx.embers(Vector3(0, 0.3, 0.3)))
	return [RoomKit.flicker(light, 3.5, 0.3, 50.0)]


static func _world(f: MeshForge) -> void:
	# 配方里一律写世界坐标:先把枢轴平移抵掉
	f.push(Transform3D(Basis.IDENTITY, -PIVOT))


static func _aabb_box(f: MeshForge, lo: Vector3, hi: Vector3) -> void:
	f.box(hi - lo, MeshForge.xf((lo + hi) / 2.0))


static func _stone_recipe(f: MeshForge) -> void:
	_world(f)
	f.paint(Color.WHITE, 0.9)
	for id in ["pier_l", "pier_r", "lintel", "breast"]:
		var box: Array = RoomLayout.FIRE_BOXES[id]
		_aabb_box(f, box[0], box[1])
	# 炉膛:后壁、壁柱内侧与过梁底面熏黑(顶点色 0.3,sRGB)
	var soot := Color(0.3, 0.29, 0.28)
	f.paint(soot, 0.95)
	var back: Array = RoomLayout.FIRE_BOXES["back"]
	_aabb_box(f, back[0], back[1])
	var x0 := -2.14
	var x1 := -0.86
	_aabb_box(f, Vector3(x0, 0.0, RoomLayout.FIRE_BACK_Z), Vector3(x0 + 0.002, 1.0, -3.925))
	_aabb_box(f, Vector3(x1 - 0.002, 0.0, RoomLayout.FIRE_BACK_Z), Vector3(x1, 1.0, -3.925))
	_aabb_box(f, Vector3(x0, 0.998, RoomLayout.FIRE_BACK_Z), Vector3(x1, 1.0, -3.925))
	# 炉床石板(高度不在 0.2 网格上:整块落在一层砖内)
	f.paint(Color(0.82, 0.8, 0.78), 0.9)
	_aabb_box(f, RoomLayout.HEARTH[0], RoomLayout.HEARTH[1])


static func _mantel_recipe(f: MeshForge) -> void:
	_world(f)
	f.part_space = true
	f.seed = 3.0
	f.paint(Color.WHITE, 0.8)
	var lo: Vector3 = RoomLayout.MANTEL[0]
	var hi: Vector3 = RoomLayout.MANTEL[1]
	var size := hi - lo
	f.extrude(RoomShell.chamfer_rect(size.z, size.y, 0.018), size.x, MeshForge.xf((lo + hi) / 2.0))
	# 台梁下的两只托木
	for x in [-2.5, -0.5]:
		f.seed = 4.0 + x
		f.extrude(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.055, 0.0), Vector2(0.055, -0.03), Vector2(0.012, -0.13), Vector2(0.0, -0.13)]),
			0.1, Transform3D(Basis.IDENTITY, Vector3(x, lo.y, -3.92)))
	f.part_space = false


static func _log(f: MeshForge, pos: Vector3, rot_deg: Vector3, radius: float, length: float, seed: float) -> void:
	f.seed = seed
	f.cylinder(radius, radius * 1.06, length, 10, MeshForge.CAPS_BOTH, MeshForge.xf(pos, rot_deg))


static func _logs_recipe(f: MeshForge) -> void:
	_world(f)
	f.part_space = true
	f.paint(Color.WHITE, 0.95)
	# 炉内 3 根(横在柴架上)
	_log(f, Vector3(-1.62, 0.13, -4.13), Vector3(0, 12, 90), 0.055, 0.6, 1.0)
	_log(f, Vector3(-1.38, 0.13, -4.05), Vector3(0, -18, 90), 0.05, 0.56, 2.0)
	_log(f, Vector3(-1.5, 0.22, -4.10), Vector3(8, 4, 88), 0.048, 0.5, 3.0)
	# 炉边柴堆 3-2-1,顺着 z 躺
	var rows := [[0.07, [-3.27, -3.125, -2.98]], [0.19, [-3.2, -3.05]], [0.31, [-3.125]]]
	var k := 0
	for row in rows:
		for x in row[1]:
			_log(f, Vector3(x + (k % 2) * 0.01, row[0], -4.1 + (k % 3) * 0.015), Vector3(90, (k * 7) % 11 - 5.0, 0), 0.068, 0.46, 10.0 + k)
			k += 1
	f.part_space = false


static func _props_recipe(f: MeshForge) -> void:
	_world(f)
	# 铸铁背板
	RoomKit.paint(f, RoomKit.IRON, 0.5)
	f.box(Vector3(0.9, 0.7, 0.02), MeshForge.xf(Vector3(-1.5, 0.41, -4.228)))
	# 柴架 2 只:前立柱 + 顶上黄铜球 + 向后的横杆 + 脚
	for x in [-1.85, -1.15]:
		RoomKit.paint(f, RoomKit.IRON)
		f.box(Vector3(0.028, 0.32, 0.028), MeshForge.xf(Vector3(x, 0.22, -3.98)))
		f.box(Vector3(0.024, 0.024, 0.26), MeshForge.xf(Vector3(x, 0.09, -4.10)))
		f.box(Vector3(0.12, 0.018, 0.03), MeshForge.xf(Vector3(x, 0.07, -3.98)))
		RoomKit.paint(f, RoomKit.BRASS)
		f.sphere(0.028, 12, MeshForge.xf(Vector3(x, 0.40, -3.98)))
	# 火具架:底座、立杆、挂着的拨火棍与铲子
	var tx := -0.12
	var tz := -4.2
	RoomKit.paint(f, RoomKit.IRON)
	f.cylinder(0.08, 0.09, 0.025, 14, MeshForge.CAPS_BOTH, MeshForge.xf(Vector3(tx, 0.0125, tz)))
	f.cylinder(0.011, 0.011, 0.78, 8, MeshForge.CAPS_BOTH, MeshForge.xf(Vector3(tx, 0.4, tz)))
	f.box(Vector3(0.16, 0.012, 0.012), MeshForge.xf(Vector3(tx, 0.76, tz)))
	RoomKit.paint(f, RoomKit.BRASS)
	f.sphere(0.022, 10, MeshForge.xf(Vector3(tx, 0.81, tz)))
	RoomKit.paint(f, RoomKit.IRON)
	for side in [-1, 1]:
		var hx: float = tx + side * 0.065
		f.cylinder(0.007, 0.007, 0.62, 6, MeshForge.CAPS_BOTH, MeshForge.xf(Vector3(hx, 0.43, tz + 0.02), Vector3(4 * side, 0, 0)))
	f.box(Vector3(0.07, 0.09, 0.006), MeshForge.xf(Vector3(tx + 0.065, 0.11, tz + 0.03), Vector3(10, 0, 0)))
	f.box(Vector3(0.012, 0.06, 0.012), MeshForge.xf(Vector3(tx - 0.065, 0.12, tz + 0.04), Vector3(0, 0, 35)))
	# 台上摆件:黄铜烛台(未点燃)、锡杯、扑克盒;不放酒瓶
	var top := RoomLayout.MANTEL[1].y
	for x in [-2.45, -0.55]:
		RoomKit.paint(f, RoomKit.BRASS)
		f.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.045, 0.0), Vector2(0.045, 0.01), Vector2(0.016, 0.03),
			Vector2(0.011, 0.11), Vector2(0.022, 0.13), Vector2(0.024, 0.14), Vector2(0.0, 0.14)]), 14,
			PackedInt32Array([1, 2, 5]), MeshForge.xf(Vector3(x, top, -4.12)))
		RoomKit.paint(f, RoomKit.WAX)
		f.cylinder(0.012, 0.013, 0.14, 10, MeshForge.CAPS_BOTH, MeshForge.xf(Vector3(x, top + 0.21, -4.12)))
	RoomKit.paint(f, RoomKit.TIN)
	for c in [Vector3(-2.12, top, -4.04), Vector3(-1.98, top, -4.18)]:
		f.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.034, 0.085), Vector2(0.03, 0.085),
			Vector2(0.026, 0.01), Vector2(0.0, 0.01)]), 12, PackedInt32Array([1, 2, 3]), MeshForge.xf(c))
	RoomKit.paint(f, RoomKit.RED_PAINT)
	f.box(Vector3(0.095, 0.032, 0.066), MeshForge.xf(Vector3(-0.92, top + 0.016, -4.06), Vector3(0, 14, 0)))
	RoomKit.paint(f, RoomKit.CREAM)
	f.box(Vector3(0.096, 0.004, 0.04), MeshForge.xf(Vector3(-0.92, top + 0.033, -4.06), Vector3(0, 14, 0)))
	_skull(f)


static func _skull(f: MeshForge) -> void:
	# 牛骷髅:颅顶、长吻、眼窝,两只弯角伸到 x −2.0 / −1.0、凸出到 z −3.86
	var c := Vector3(-1.5, 2.62, -4.04)
	var bone: Color = RoomKit.BONE[0]
	RoomKit.paint(f, RoomKit.BONE)
	f.blob(c, [
		[Vector3(0, 0.04, 0.0), Vector3(0.10, 0.08, 0.06), bone],
		[Vector3(0, -0.07, 0.035), Vector3(0.065, 0.10, 0.045), bone],
		[Vector3(0, -0.17, 0.05), Vector3(0.05, 0.05, 0.04), bone],
		[Vector3(0.07, 0.0, 0.03), Vector3(0.04, 0.04, 0.035), bone, "mirror"],
	], 28, 16, 0.03)
	RoomKit.paint(f, RoomKit.BLACK)
	for s in [-1, 1]:
		f.sphere(0.024, 10, MeshForge.xf(c + Vector3(s * 0.058, 0.0, 0.06), Vector3.ZERO, Vector3(1, 1.2, 0.6)))
		f.sphere(0.011, 8, MeshForge.xf(c + Vector3(s * 0.02, -0.2, 0.085)))
	RoomKit.paint(f, RoomKit.HORN)
	for s in [-1, 1]:
		var path := PackedVector3Array()
		var radii := PackedVector2Array()
		var pts := [Vector3(0.07, 0.07, 0.0), Vector3(0.2, 0.06, 0.05), Vector3(0.33, 0.1, 0.11), Vector3(0.43, 0.17, 0.15), Vector3(0.5, 0.25, 0.17)]
		for k in pts.size():
			var p: Vector3 = pts[k]
			path.append(c + Vector3(p.x * s, p.y, p.z))
			var r := lerpf(0.032, 0.006, float(k) / (pts.size() - 1))
			radii.append(Vector2(r, r))
		f.loft(path, radii, 10)


static func _embers_recipe(f: MeshForge) -> void:
	_world(f)
	RoomKit.decor_paint(f, 5, 1.0, Color.WHITE)
	f.sphere(1.0, 20, MeshForge.xf(Vector3(-1.5, 0.06, -4.08), Vector3.ZERO, Vector3(0.42, 0.12, 0.14)))
