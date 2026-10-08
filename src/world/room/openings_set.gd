class_name OpeningsSet
# 门窗:右墙月光窗(窗套、窗台、2×3 窗棂、窗台上的仙人掌与油灯、黄铜帘杆、两幅酒红窗帘,全在 LAYER_MOON 上给月光投影;
# 不要玻璃)、窗外夜景板(x 5.4,自发光,不投影,不在月光层)与月光;
# 前墙弹簧门(门套、两扇百叶门、门槛)、门廊地板与对面街景板(自发光,不投影)。


const WINDOW_PIVOT := RoomLayout.WINDOW_CENTER
const DOOR_Z := RoomLayout.INNER
const CURTAIN := Color(0.40, 0.08, 0.08)
const GRAIN_ALONG_Y := Basis(Vector3.BACK, PI / 2.0)


static func build(tavern: Node3D) -> void:
	_window(tavern)
	_door(tavern)


# —— 窗 ——

static func _window(tavern: Node3D) -> void:
	var window := MeshKit.pivot(tavern, WINDOW_PIVOT, "Window")
	RoomKit.add(window, "Frame", "window:frame", _frame_recipe,
		{&"wood": WorldMaterials.wood("dark", true), &"prop": WorldMaterials.prop()}, MeshKit.LAYER_MOON, true)
	RoomKit.add(window, "Curtains", "window:curtains", _curtain_recipe, {&"main": WorldMaterials.decor()}, MeshKit.LAYER_MOON, true)
	# 窗外夜景:布景层,不投影,挡不住月光
	RoomKit.add(tavern, "WindowView", "window:view", _view_recipe, {&"main": WorldMaterials.decor()}, MeshKit.LAYER_SCENERY, false)
	# 月光从窗外斜射进屋:体积雾里形成一道冷色光柱,窗棂投下影子。只有窗组给月光投影
	var moon := SpotLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.5, 0.62, 1.0)
	moon.light_energy = 3.0
	moon.spot_range = 9.0
	moon.spot_angle = 24.0
	moon.shadow_enabled = true
	moon.shadow_caster_mask = MeshKit.LAYER_MOON
	moon.light_volumetric_fog_energy = 3.2
	tavern.add_child(moon)
	moon.look_at_from_position(RoomLayout.MOON_POS, RoomLayout.MOON_TARGET)


static func _local(f: MeshForge) -> void:
	f.push(Transform3D(Basis.IDENTITY, -WINDOW_PIVOT))


static func _frame_recipe(f: MeshForge) -> void:
	_local(f)
	var z0 := RoomLayout.WINDOW_Z0
	var z1 := RoomLayout.WINDOW_Z1
	var y0 := RoomLayout.WINDOW_Y0
	var y1 := RoomLayout.WINDOW_Y1
	var inner := RoomLayout.INNER
	var c := RoomLayout.WINDOW_CASING
	f.surface(&"wood")
	f.part_space = true
	f.paint(Color.WHITE, 0.72)
	var up := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	var along_z := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
	# 套线(屋里一侧,凸出 2.5 cm)
	f.seed = 1.0
	for z in [z0 - c / 2.0, z1 + c / 2.0]:
		f.extrude(RoomShell.chamfer_rect(c, 0.025, 0.006, Vector2(0, 0)), y1 + 0.12 - (y0 - 0.04),
			Transform3D(up, Vector3(inner - 0.0125, (y1 + 0.12 + y0 - 0.04) / 2.0, z)))
	# 窗头 + 小檐
	f.seed = 2.0
	f.box(Vector3(0.03, 0.12, z1 - z0 + c * 2.0 + 0.04), MeshForge.xf(Vector3(inner - 0.015, y1 + 0.06, (z0 + z1) / 2.0)))
	f.box(Vector3(0.06, 0.04, z1 - z0 + c * 2.0 + 0.1), MeshForge.xf(Vector3(inner - 0.03, y1 + 0.14, (z0 + z1) / 2.0)))
	# 窗台:x 4.30..4.62,y 1.11..1.15,z −1.70..−0.10;下面一条托木
	f.seed = 3.0
	f.extrude(RoomShell.chamfer_rect(0.32, 0.04, 0.008), 1.6, Transform3D(along_z, Vector3(4.46, 1.13, -0.9)))
	f.box(Vector3(0.025, 0.06, 1.4), MeshForge.xf(Vector3(inner - 0.0125, 1.08, -0.9)))
	# 洞口衬板(墙厚 0.2)
	f.seed = 4.0
	for z in [z0 + 0.01, z1 - 0.01]:
		f.box(Vector3(0.2, y1 - y0, 0.02), MeshForge.xf(Vector3(inner + 0.1, (y0 + y1) / 2.0, z)))
	f.box(Vector3(0.2, 0.02, z1 - z0), MeshForge.xf(Vector3(inner + 0.1, y1 - 0.01, (z0 + z1) / 2.0)))
	# 窗扇外框与窗棂(2 列 × 3 行;竖棂 z −0.9,横棂 y 1.567 / 1.983)
	f.seed = 5.0
	var sx := inner + 0.1
	f.box(Vector3(0.05, 0.05, z1 - z0), MeshForge.xf(Vector3(sx, y0 + 0.045, (z0 + z1) / 2.0)))
	f.box(Vector3(0.05, 0.05, z1 - z0), MeshForge.xf(Vector3(sx, y1 - 0.045, (z0 + z1) / 2.0)))
	for z in [z0 + 0.045, z1 - 0.045]:
		f.box(Vector3(0.05, y1 - y0, 0.05), MeshForge.xf(Vector3(sx, (y0 + y1) / 2.0, z)))
	f.box(Vector3(0.04, y1 - y0, 0.035), MeshForge.xf(Vector3(sx, (y0 + y1) / 2.0, Tavern.WINDOW_Z)))
	for y in [1.567, 1.983]:
		f.box(Vector3(0.04, 0.035, z1 - z0), MeshForge.xf(Vector3(sx, y, (z0 + z1) / 2.0)))
	f.part_space = false
	# 窗台摆件:仙人掌陶盆、未点燃的油灯;黄铜帘杆与托架
	f.surface(&"prop")
	var sill := 1.15
	var pot := Vector3(4.37, sill, -1.2)
	RoomKit.paint(f, RoomKit.CLAY)
	f.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.055, 0.085), Vector2(0.062, 0.09),
		Vector2(0.062, 0.105), Vector2(0.05, 0.105), Vector2(0.0, 0.1)]), 14, PackedInt32Array([1, 3, 4, 5]), MeshForge.xf(pot))
	RoomKit.paint(f, RoomKit.CACTUS)
	f.capsule(0.032, 0.26, 12, MeshForge.xf(pot + Vector3(0, 0.22, 0)))
	f.capsule(0.018, 0.1, 10, MeshForge.xf(pot + Vector3(0, 0.25, 0.045), Vector3(-25, 0, 0)))
	f.capsule(0.016, 0.085, 10, MeshForge.xf(pot + Vector3(0, 0.19, -0.045), Vector3(30, 0, 0)))
	var lamp := Vector3(4.37, sill, -0.55)
	RoomKit.paint(f, RoomKit.OLD_BRASS)
	f.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.05, 0.0), Vector2(0.055, 0.02), Vector2(0.045, 0.05),
		Vector2(0.02, 0.06), Vector2(0.0, 0.06)]), 14, PackedInt32Array([1]), MeshForge.xf(lamp))
	RoomKit.paint(f, RoomKit.LAMP_GLASS)
	f.lathe(PackedVector2Array([Vector2(0.0, 0.06), Vector2(0.02, 0.06), Vector2(0.038, 0.1), Vector2(0.03, 0.15),
		Vector2(0.018, 0.2), Vector2(0.0, 0.2)]), 14, PackedInt32Array(), MeshForge.xf(lamp))
	RoomKit.paint(f, RoomKit.OLD_BRASS)
	f.torus(0.008, 0.016, 10, MeshForge.xf(lamp + Vector3(0, 0.2, 0)))
	RoomKit.paint(f, RoomKit.BRASS)
	var rod_x := 4.24
	var rod_y := 2.62
	f.cylinder(0.012, 0.012, 2.3, 10, MeshForge.CAPS_BOTH, MeshForge.xf(Vector3(rod_x, rod_y, -0.9), Vector3(90, 0, 0)))
	for z in [-2.05, 0.25]:
		f.sphere(0.024, 10, MeshForge.xf(Vector3(rod_x, rod_y, z)))
	for z in [-1.9, 0.1]:
		f.box(Vector3(0.16, 0.012, 0.012), MeshForge.xf(Vector3(rod_x + 0.08, rod_y, z)))
		f.box(Vector3(0.006, 0.05, 0.03), MeshForge.xf(Vector3(inner - 0.003, rod_y, z)))


static func curtain_rows(z_outer: float, z_inner: float, x: float) -> Array:
	# 一幅窗帘的网格行(自上而下):7 道褶、幅度 0.025;y 2.60 垂到 1.05,在 1.55 处向外侧收到 45%
	var rows := []
	var cols := 29
	var y_top := 2.60
	var y_tie := 1.55
	var y_bottom := 1.05
	for r in 23:
		var t := float(r) / 22.0
		var y := lerpf(y_top, y_bottom, t)
		var width: float
		if y >= y_tie:
			width = lerpf(1.0, 0.45, pow((y_top - y) / (y_top - y_tie), 1.4))
		else:
			width = lerpf(0.45, 0.62, (y_tie - y) / (y_tie - y_bottom))
		var row := PackedVector3Array()
		for k in cols:
			var u := float(k) / (cols - 1)
			var depth := 0.025 * sin(u * 7.0 * TAU) * (1.0 + (1.0 - width) * 1.2)
			var z := lerpf(z_outer, z_inner, u * width)
			row.append(Vector3(x - depth - 0.03 * (1.0 - width), y, z))
		rows.append(row)
	return rows


static func _curtain_recipe(f: MeshForge) -> void:
	_local(f)
	RoomKit.decor_paint(f, 4, 0.0, CURTAIN)
	var x := 4.24
	var zs: Array = RoomLayout.CURTAIN_Z
	f.grid(curtain_rows(zs[0].x, zs[0].y, x))
	f.grid(curtain_rows(zs[1].y, zs[1].x, x))
	# 束带
	RoomKit.decor_paint(f, 4, 0.0, Color(0.55, 0.42, 0.18))
	f.box(Vector3(0.07, 0.04, 0.3), MeshForge.xf(Vector3(x - 0.02, 1.55, zs[0].x + 0.12)))
	f.box(Vector3(0.07, 0.04, 0.3), MeshForge.xf(Vector3(x - 0.02, 1.55, zs[1].y - 0.12)))


static func _view_recipe(f: MeshForge) -> void:
	# 窗外夜景板:x 5.4,朝 −X;u 沿 +Z,v 自上而下(与 RoomLayout.moon_uv 一致)
	RoomKit.decor_paint(f, 1, 0.55)
	var zr := RoomLayout.BACKDROP_Z
	var yr := RoomLayout.BACKDROP_Y
	var face := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
	f.quad(Vector2(zr.y - zr.x, yr.y - yr.x), DecorAtlas.rect("night"),
		Transform3D(face, Vector3(RoomLayout.BACKDROP_X, (yr.x + yr.y) / 2.0, (zr.x + zr.y) / 2.0)))


# —— 前墙弹簧门 ——

static func _door(tavern: Node3D) -> void:
	RoomKit.add(tavern, "Door", "door:frame", _door_recipe,
		{&"wood": WorldMaterials.wood("dark", true), &"prop": WorldMaterials.prop()}, MeshKit.LAYER_SCENERY, false)
	RoomKit.add(tavern, "DoorView", "door:view", _street_recipe, {&"main": WorldMaterials.decor()}, MeshKit.LAYER_SCENERY, false)


static func _door_recipe(f: MeshForge) -> void:
	var x0 := RoomLayout.DOOR_X0
	var x1 := RoomLayout.DOOR_X1
	var h := RoomLayout.DOOR_HEIGHT
	var c := RoomLayout.DOOR_CASING
	var z := DOOR_Z
	f.surface(&"wood")
	f.part_space = true
	f.paint(Color.WHITE, 0.72)
	var up := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	# 侧套、脚墩、门头与檐
	f.seed = 1.0
	for x in [x0 - c / 2.0, x1 + c / 2.0]:
		f.extrude(RoomShell.chamfer_rect(0.03, c, 0.006), h + 0.16, Transform3D(up, Vector3(x, (h + 0.16) / 2.0, z - 0.015)))
		f.box(Vector3(c + 0.02, 0.2, 0.045), MeshForge.xf(Vector3(x, 0.1, z - 0.0225)))
	f.seed = 2.0
	f.box(Vector3(x1 - x0 + c * 2.0 + 0.04, 0.16, 0.035), MeshForge.xf(Vector3((x0 + x1) / 2.0, h + 0.08, z - 0.0175)))
	f.extrude(RoomShell.chamfer_rect(0.07, 0.04, 0.01), x1 - x0 + c * 2.0 + 0.14,
		Transform3D(Basis.IDENTITY, Vector3((x0 + x1) / 2.0, h + 0.18, z - 0.035)))
	# 洞口衬板与门槛
	f.seed = 3.0
	for x in [x0 + 0.01, x1 - 0.01]:
		f.box(Vector3(0.02, h, 0.2), MeshForge.xf(Vector3(x, h / 2.0, z + 0.1)))
	f.box(Vector3(x1 - x0, 0.02, 0.2), MeshForge.xf(Vector3((x0 + x1) / 2.0, h - 0.01, z + 0.1)))
	f.box(Vector3(x1 - x0, 0.02, 0.28), MeshForge.xf(Vector3((x0 + x1) / 2.0, 0.01, z + 0.1)))
	# 两扇百叶弹簧门:合页线 x −0.94 / 0.24,z 4.47,向内开 10° / 14°
	_leaf(f, Vector3(x0 + 0.01, 0.0, 4.47), 1.0, 10.0, 10.0)
	_leaf(f, Vector3(x1 - 0.01, 0.0, 4.47), -1.0, 14.0, 20.0)
	f.part_space = false
	f.part_basis = Basis.IDENTITY
	# 合页
	f.surface(&"prop")
	RoomKit.paint(f, RoomKit.OLD_BRASS)
	for hx in [x0 + 0.01, x1 - 0.01]:
		for y in [1.0, 1.55]:
			f.cylinder(0.012, 0.012, 0.09, 8, MeshForge.CAPS_BOTH, MeshForge.xf(Vector3(hx, y, 4.47)))


static func _leaf(f: MeshForge, hinge: Vector3, dir: float, open_deg: float, seed: float) -> void:
	# 一扇门:宽 0.58,底 0.80,合页侧顶 1.75、中缝处 1.62;两根梃、弧形上冒头、下冒头、9 片百叶
	var width := 0.58
	var bottom := 0.80
	var top_hinge := 1.75
	var top_mid := 1.62
	var basis := Basis(Vector3.UP, deg_to_rad(open_deg) * dir)
	f.push(Transform3D(basis, hinge))
	f.part_basis = GRAIN_ALONG_Y
	f.seed = seed
	var stile := 0.05
	for side in [0.0, 1.0]:
		var x: float = dir * lerpf(stile / 2.0, width - stile / 2.0, side)
		var top: float = lerpf(top_hinge, top_mid, side)
		f.box(Vector3(stile, top - bottom, 0.035), MeshForge.xf(Vector3(x, (top + bottom) / 2.0, 0)))
	f.part_basis = Basis.IDENTITY
	f.seed = seed + 1.0
	f.box(Vector3(width, 0.12, 0.035), MeshForge.xf(Vector3(dir * width / 2.0, bottom + 0.06, 0)))
	# 弧形上冒头:分 6 段拼出从合页侧 1.75 降到中缝 1.62 的弧
	var segs := 6
	for k in segs:
		var u0 := float(k) / segs
		var u1 := float(k + 1) / segs
		var ya := lerpf(top_hinge, top_mid, u0 * u0 * (3.0 - 2.0 * u0))
		var yb := lerpf(top_hinge, top_mid, u1 * u1 * (3.0 - 2.0 * u1))
		var xa := dir * width * u0
		var xb := dir * width * u1
		var mid := Vector3((xa + xb) / 2.0, (ya + yb) / 2.0 - 0.05, 0)
		var ang := atan2(yb - ya, xb - xa)
		f.box(Vector3(Vector2(xb - xa, yb - ya).length() + 0.004, 0.10, 0.035), MeshForge.xf(mid, Vector3(0, 0, rad_to_deg(ang))))
	# 百叶
	for k in 9:
		var y := bottom + 0.16 + k * 0.074
		var top := lerpf(top_hinge, top_mid, 0.5) - 0.12
		if y > top:
			break
		f.box(Vector3(width - stile * 2.0, 0.055, 0.008), MeshForge.xf(Vector3(dir * width / 2.0, y, 0), Vector3(35, 0, 0)))
	f.pop()


static func _street_recipe(f: MeshForge) -> void:
	# 门廊地板(朝上)与对面街景板(z 5.8,朝 −Z);u 沿屋里看向右(−X)
	RoomKit.decor_paint(f, 1, 0.25)
	var porch := Basis(Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0))
	f.quad(Vector2(2.5, 1.2), DecorAtlas.rect("porch"), Transform3D(porch, Vector3(-0.35, 0.003, 5.2)))
	RoomKit.decor_paint(f, 1, 0.55)
	var face := Basis(Vector3(-1, 0, 0), Vector3.UP, Vector3(0, 0, -1))
	var xr := RoomLayout.STREET_X
	var yr := RoomLayout.STREET_Y
	f.quad(Vector2(xr.y - xr.x, yr.y - yr.x), DecorAtlas.rect("street"),
		Transform3D(face, Vector3((xr.x + xr.y) / 2.0, (yr.x + yr.y) / 2.0, RoomLayout.STREET_Z)))
