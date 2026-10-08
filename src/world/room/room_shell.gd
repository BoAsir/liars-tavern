class_name RoomShell
# 房间壳:地板、天花板、四面墙(灰泥墙体 + 框芯护墙板 + 踢脚线 / 墙裙压条 / 顶线)、梁、角柱、墙柱、斜撑与托架。
# 三面实墙每面三个网格(节点名 Wall<面><Wainscot|Plaster|Rail>,护墙板与灰泥不投影,线脚投影);
# 窗墙按洞口分四段(WindowWall0..3)加一条线脚,全部在 LAYER_MOON 上给月光投影。
# 地板、天花板、木构是布景(LAYER_SCENERY,不投影);网格都走 MeshForge.cached,多个 Tavern 共享。


const BASE_PROFILE := [Vector2(0.015, 0.0), Vector2(0.042, 0.0), Vector2(0.042, 0.112), Vector2(0.03, 0.14), Vector2(0.015, 0.14)]
const RAIL_DEPTH := 0.06   # 墙裙压条盖板离灰泥面


static func build(tavern: Node3D) -> Node3D:
	var room := MeshKit.pivot(tavern, Vector3.ZERO, "Room")
	var size := Tavern.ROOM_HALF * 2.0
	var floor := MeshKit.add(room, MeshKit.plane(Vector2(size, size)), WorldMaterials.wood("floor"), Vector3.ZERO, Vector3.ZERO,
		Vector3.ONE, MeshKit.SHADOW_OFF)
	floor.name = "Floor"
	floor.layers = MeshKit.LAYER_SCENERY
	var ceiling := MeshKit.add(room, MeshKit.plane(Vector2(size, size)), WorldMaterials.wood("ceiling"),
		Vector3(0, Tavern.ROOM_HEIGHT, 0), Vector3(180, 0, 0), Vector3.ONE, MeshKit.SHADOW_OFF)
	ceiling.name = "Ceiling"
	ceiling.layers = MeshKit.LAYER_SCENERY
	for wall in ["back", "front", "left"]:
		var prefix: String = {"back": "WallBack", "front": "WallFront", "left": "WallLeft"}[wall]
		_add(room, prefix + "Wainscot", "room:wainscot:" + wall, _wainscot_recipe(wall, -INF, INF),
			{&"main": WorldMaterials.wood("wainscot", true)}, MeshKit.LAYER_SCENERY, false)
		_add(room, prefix + "Plaster", "room:plaster:" + wall, _plaster_recipe(wall),
			{&"main": WorldMaterials.stone("plaster")}, MeshKit.LAYER_SCENERY, false)
		_add(room, prefix + "Rail", "room:rail:" + wall, _rail_recipe(wall),
			{&"main": WorldMaterials.wood("dark", true)}, MeshKit.LAYER_WORLD, true)
	_window_wall(room)
	_add(room, "Timber", "room:timber", _timber_recipe,
		{&"main": WorldMaterials.wood("beam", true), &"iron": WorldMaterials.prop()}, MeshKit.LAYER_SCENERY, false)
	return room


static func _add(parent: Node3D, node_name: String, key: String, recipe: Callable, materials: Dictionary, layers: int,
		casts: bool) -> MeshInstance3D:
	var inst := MeshKit.add(parent, MeshForge.cached(key, recipe, materials), null, Vector3.ZERO, Vector3.ZERO, Vector3.ONE,
		MeshKit.SHADOW_ON if casts else MeshKit.SHADOW_OFF)
	inst.name = node_name
	inst.layers = layers
	return inst


# —— 墙 ——

const INNER := RoomLayout.INNER


static func wall_frame(wall: String, u: float, offset := 0.0) -> Transform3D:
	# 墙的局部坐标系:原点在灰泥面上 (u, 0),X 沿墙(屋里看向右),Z 指向屋里
	return Transform3D(RoomLayout.wall_basis(wall), RoomLayout.wall_point(wall, u, 0.0, offset))


static func wall_box(f: MeshForge, wall: String, u0: float, u1: float, y0: float, y1: float, z0: float, z1: float) -> void:
	# 墙坐标里的盒子:u 沿墙、y 离地、z 离灰泥面(正 = 屋里)
	var size := Vector3(absf(u1 - u0), y1 - y0, z1 - z0)
	f.box(size, wall_frame(wall, (u0 + u1) / 2.0) * Transform3D(Basis.IDENTITY, Vector3(0, (y0 + y1) / 2.0, (z0 + z1) / 2.0)))


static func wall_extrude(f: MeshForge, wall: String, u0: float, u1: float, profile: Array) -> void:
	# 沿墙挤出线脚:profile 在墙坐标 (z 离墙, y 离地) 里
	f.extrude_x(PackedVector2Array(profile), absf(u1 - u0), wall_frame(wall, (u0 + u1) / 2.0))


static func _wainscot_recipe(wall: String, u_min: float, u_max: float, top := RoomLayout.WAINSCOT_TOP) -> Callable:
	# 框芯护墙板的面板(贴在灰泥面上 1.5 cm 厚);每个墙段单独拟合整数块面板:CUSTOM0.x = 拉伸后的 u
	return func(f: MeshForge):
		f.part_space = true
		f.paint(Color.WHITE, 0.66)
		var k := 0
		for seg in RoomLayout.wainscot_segments(wall):
			var mid: float = (seg[0] + seg[1]) / 2.0
			if mid < u_min or mid > u_max:
				continue
			var length: float = absf(seg[1] - seg[0])
			var pitch := RoomLayout.panel_fit(length, 0.62)
			var stretch := 0.62 / pitch
			f.part_basis = Basis.from_scale(Vector3(stretch, 1.0, 1.0))
			f.part_origin = Vector3(stretch * length / 2.0, top / 2.0, 0.0)
			f.seed = k * 3.1 + wall.length()
			wall_box(f, wall, seg[0], seg[1], 0.0, top, 0.0, RoomLayout.WAINSCOT_PROUD)
			k += 1
		f.part_basis = Basis.IDENTITY
		f.part_origin = Vector3.ZERO


static func _plaster_recipe(wall: String) -> Callable:
	# 墙体(0.2 厚,整高):护墙板与线脚贴在它前面;前墙按门洞拆三块
	return func(f: MeshForge):
		var h := Tavern.ROOM_HEIGHT
		var e := Tavern.ROOM_HALF
		match wall:
			"front":
				wall_box(f, wall, -e, RoomLayout.DOOR_X0, 0.0, h, -0.2, 0.0)
				wall_box(f, wall, RoomLayout.DOOR_X1, e, 0.0, h, -0.2, 0.0)
				wall_box(f, wall, RoomLayout.DOOR_X0, RoomLayout.DOOR_X1, RoomLayout.DOOR_HEIGHT, h, -0.2, 0.0)
			_:
				wall_box(f, wall, -e, e, 0.0, h, -0.2, 0.0)


static func _rail_recipe(wall: String, u_min := -INF, u_max := INF) -> Callable:
	# 踢脚线、墙裙压条(盖板 + 四分之一圆线)、顶线(凹弧);在墙柱、门套、壁炉、后吧处断开,顶线在梁两侧断开
	return func(f: MeshForge):
		f.part_space = true
		f.paint(Color.WHITE, 0.7)
		var segs: Array = RoomLayout.wainscot_segments(wall)
		var k := 0
		for seg in segs:
			var mid: float = (seg[0] + seg[1]) / 2.0
			if mid < u_min or mid > u_max:
				continue
			f.seed = 40.0 + k
			wall_extrude(f, wall, seg[0], seg[1], BASE_PROFILE)
			var under_window: bool = wall == "right" and mid > RoomLayout.WINDOW_Z0 and mid < RoomLayout.WINDOW_Z1
			if not under_window:
				wall_extrude(f, wall, seg[0], seg[1], chair_rail_profile())
			k += 1
		for seg in crown_segments(wall):
			var mid: float = (seg[0] + seg[1]) / 2.0
			if mid < u_min or mid > u_max:
				continue
			f.seed = 70.0 + k
			wall_extrude(f, wall, seg[0], seg[1], crown_profile())
			k += 1
		if wall == "back":
			# 顶线绕烟囱腔:正面一段 + 两侧回头
			var breast: Array = RoomLayout.FIRE_BOXES["breast"]
			var depth: float = breast[1].z + INNER   # 烟囱腔凸出墙面 0.32
			f.extrude_x(crown_profile_packed(), breast[1].x - breast[0].x + 0.24,
				Transform3D(Basis.IDENTITY, Vector3((breast[0].x + breast[1].x) / 2.0, 0.0, breast[1].z)))
			for side in [-1, 1]:
				var x: float = breast[0].x if side < 0 else breast[1].x
				var b := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(side, 0, 0))
				f.extrude_x(crown_profile_packed(), depth, Transform3D(b, Vector3(x, 0.0, -INNER + depth / 2.0)))
		f.part_space = false


static func chair_rail_profile() -> Array:
	var pts := [Vector2(0.0, 1.075), Vector2(0.015, 1.075)]
	for k in range(1, 6):
		var a := -PI / 2.0 + k * (PI / 2.0) / 5.0
		pts.append(Vector2(0.015, 1.095) + Vector2(cos(a), sin(a)) * 0.02)
	pts.append_array([Vector2(RAIL_DEPTH, 1.10), Vector2(RAIL_DEPTH, 1.118), Vector2(RAIL_DEPTH - 0.01, RoomLayout.RAIL_TOP),
		Vector2(0.0, RoomLayout.RAIL_TOP)])
	return pts


static func crown_profile() -> Array:
	var y0 := RoomLayout.CROWN_BOTTOM
	var pts := [Vector2(0.0, y0), Vector2(0.016, y0), Vector2(0.016, y0 + 0.012)]
	var c := Vector2(0.11, y0 + 0.012)
	for k in range(1, 8):
		var a := PI - k * (PI / 2.0) / 7.0
		pts.append(c + Vector2(cos(a), sin(a)) * 0.094)
	pts.append_array([Vector2(0.122, y0 + 0.106), Vector2(0.122, Tavern.ROOM_HEIGHT), Vector2(0.0, Tavern.ROOM_HEIGHT)])
	return pts


static func crown_profile_packed() -> PackedVector2Array:
	return PackedVector2Array(crown_profile())


static func crown_segments(wall: String) -> Array:
	var c := RoomLayout.CORNER_POST_CENTER - RoomLayout.CORNER_POST / 2.0
	match wall:
		"back":
			var breast: Array = RoomLayout.FIRE_BOXES["breast"]
			return [[-c, breast[0].x], [breast[1].x, c]]
		"front":
			return [[-c, c]]
		_:
			# 侧墙:梁两侧断开
			var out := []
			var start := -c
			for z in RoomLayout.BEAM_Z:
				out.append([start, z - RoomLayout.BEAM_SIZE.x / 2.0])
				start = z + RoomLayout.BEAM_SIZE.x / 2.0
			out.append([start, c])
			return out


# —— 窗墙(右墙):四段墙体 + 护墙板 + 一条线脚,都在 LAYER_MOON 上投影 ——

static func _window_wall(room: Node3D) -> void:
	var z0 := RoomLayout.WINDOW_Z0
	var z1 := RoomLayout.WINDOW_Z1
	var y0 := RoomLayout.WINDOW_Y0
	var y1 := RoomLayout.WINDOW_Y1
	var e := Tavern.ROOM_HALF
	var h := Tavern.ROOM_HEIGHT
	# [段名, 墙体 (u0, u1, y0, y1), 护墙板墙段范围 (u_min, u_max)]
	var parts := [
		["WindowWall0", [z1, e, 0.0, h], [z1 + RoomLayout.WINDOW_CASING, INF]],
		["WindowWall1", [-e, z0, 0.0, h], [-INF, z0 - RoomLayout.WINDOW_CASING]],
		["WindowWall2", [z0, z1, 0.0, y0], [z0 - RoomLayout.WINDOW_CASING, z1 + RoomLayout.WINDOW_CASING]],
		["WindowWall3", [z0, z1, y1, h], []],
	]
	var wood := WorldMaterials.wood("wainscot", true)
	var plaster := WorldMaterials.stone("plaster")
	for part in parts:
		var body: Array = part[1]
		var plaster_inst := _add(room, part[0] + "Plaster", "room:plaster:" + part[0], func(f: MeshForge):
			wall_box(f, "right", body[0], body[1], body[2], body[3], -0.2, 0.0), {&"main": plaster}, MeshKit.LAYER_MOON, true)
		plaster_inst.set_meta(&"force_shadow", true)
		var span: Array = part[2]
		if span.is_empty():
			continue
		var top := y0 if part[0] == "WindowWall2" else RoomLayout.WAINSCOT_TOP
		_add(room, part[0] + "Wainscot", "room:wainscot:" + part[0], _wainscot_recipe("right", span[0], span[1], top),
			{&"main": wood}, MeshKit.LAYER_MOON, true)
	_add(room, "WindowWallRail", "room:rail:right", _rail_recipe("right"),
		{&"main": WorldMaterials.wood("dark", true)}, MeshKit.LAYER_MOON, true)


# —— 木构:梁、角柱、墙柱、斜撑、托架、梁端铁箍 ——

static func chamfer_rect(w: float, h: float, c: float, center := Vector2.ZERO) -> PackedVector2Array:
	# 倒角矩形截面(z 宽 w、y 高 h、倒角 c),逆时针
	var x := w / 2.0
	var y := h / 2.0
	return PackedVector2Array([center + Vector2(-x + c, -y), center + Vector2(x - c, -y), center + Vector2(x, -y + c),
		center + Vector2(x, y - c), center + Vector2(x - c, y), center + Vector2(-x + c, y), center + Vector2(-x, y - c),
		center + Vector2(-x, -y + c)])


static func _timber_recipe(f: MeshForge) -> void:
	f.surface(&"main")
	f.part_space = true
	f.paint(Color.WHITE, 0.8)
	var span := INNER * 2.0
	var beam_y := Tavern.ROOM_HEIGHT - RoomLayout.BEAM_SIZE.y / 2.0
	for i in RoomLayout.BEAM_Z.size():
		f.seed = 10.0 + i
		f.extrude_x(chamfer_rect(RoomLayout.BEAM_SIZE.x, RoomLayout.BEAM_SIZE.y, 0.015), span,
			Transform3D(Basis.IDENTITY, Vector3(0, beam_y, RoomLayout.BEAM_Z[i])))
	# 角柱:竖直挤出(局部 X 转到世界 Y,木纹顺着柱长)
	var up := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	var post_c := RoomLayout.CORNER_POST_CENTER
	var k := 0
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			f.seed = 20.0 + k
			f.extrude_x(chamfer_rect(RoomLayout.CORNER_POST, RoomLayout.CORNER_POST, 0.012), Tavern.ROOM_HEIGHT,
				Transform3D(up, Vector3(sx * post_c, Tavern.ROOM_HEIGHT / 2.0, sz * post_c)))
			k += 1
	# 梁端:落地墙柱 + 斜撑,或托架
	var post_h := RoomLayout.BEAM_BOTTOM
	for end in RoomLayout.beam_ends():
		var wall: String = end[0]
		var z: float = end[1]
		var side := -1.0 if wall == "left" else 1.0
		f.seed = 30.0 + k
		k += 1
		if RoomLayout.beam_support(wall, z) == RoomLayout.POST:
			var depth := RoomLayout.WALL_POST.y
			var px := side * (INNER - depth / 2.0)
			f.extrude_x(chamfer_rect(RoomLayout.WALL_POST.x, depth, 0.01), post_h,
				Transform3D(up, Vector3(px, post_h / 2.0, z)))
			# 斜撑:在梁的竖直面内从柱上 y 2.70 斜到梁底,伸到 |x| = 3.86
			var a := Vector3(side * (INNER - depth), 2.70, z)
			var b := Vector3(side * 3.86, post_h, z)
			var d := (b - a)
			var dir := d.normalized()
			var basis := Basis(dir, Vector3(0, 0, 1).cross(dir).normalized(), Vector3(0, 0, 1))
			f.extrude_x(chamfer_rect(0.09, 0.09, 0.008), d.length() + 0.08, Transform3D(basis, (a + b) / 2.0))
		else:
			var profile := [Vector2(0.0, 2.86), Vector2(0.05, 2.86)]
			var c := Vector2(0.30, 2.86)
			for j in range(1, 9):
				var ang := PI - j * (PI / 2.0) / 8.0
				profile.append(c + Vector2(cos(ang), sin(ang)) * Vector2(0.25, 0.24))
			profile.append_array([Vector2(0.30, post_h), Vector2(0.0, post_h)])
			f.extrude_x(PackedVector2Array(profile), 0.16, wall_frame(wall, z))
	f.part_space = false
	# 梁端铁箍(顶点 PBR)
	f.surface(&"iron")
	f.paint(Color(0.10, 0.10, 0.11), 0.5, 0.75)
	for z in RoomLayout.BEAM_Z:
		for sx in [-1, 1]:
			var x: float = sx * (INNER - 0.38)
			f.box(Vector3(0.05, RoomLayout.BEAM_SIZE.y + 0.012, RoomLayout.BEAM_SIZE.x + 0.012),
				MeshForge.xf(Vector3(x, beam_y, z)))
