class_name TavernRoom
# 房间本体:地板、天花板与横梁、四面墙(下半截木护墙板 + 上半截灰泥)、右墙的月光窗(含月光)。


static func build(tavern: Tavern) -> void:
	var room := MeshKit.pivot(tavern, Vector3.ZERO, "Room")
	var size := Tavern.ROOM_HALF * 2.0
	MeshKit.add(room, MeshKit.plane(Vector2(size, size)), WorldMaterials.wood("floor"))
	var ceiling := MeshKit.add(room, MeshKit.plane(Vector2(size, size)), WorldMaterials.wood("beam"),
		Vector3(0, Tavern.ROOM_HEIGHT, 0), Vector3(180, 0, 0))
	ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for z in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		MeshKit.add(room, MeshKit.box(Vector3(size, 0.24, 0.22)), WorldMaterials.wood("beam"),
			Vector3(0, Tavern.ROOM_HEIGHT - 0.12, z))
	# 后墙(壁炉)与前墙(门)、左墙(吧台)完整;右墙为窗户开洞
	var thickness := Tavern.WALL_THICKNESS
	_wall(room, Vector3(0, 0, -Tavern.ROOM_HALF), Vector3(size, 0, thickness), "wall")
	_wall(room, Vector3(0, 0, Tavern.ROOM_HALF), Vector3(size, 0, thickness), "wall")
	_wall(room, Vector3(-Tavern.ROOM_HALF, 0, 0), Vector3(thickness, 0, size), "wall_side")
	_window_wall(room)
	_build_window(tavern, room)


static func _wall(parent: Node3D, base: Vector3, extent: Vector3, wood_preset: String,
		bottom := 0.0, top := Tavern.ROOM_HEIGHT) -> void:
	# 下半截木护墙板 + 上半截灰泥,外加一道压条
	var low_top := minf(Tavern.WAINSCOT_HEIGHT, top)
	if low_top > bottom:
		var h := low_top - bottom
		MeshKit.add(parent, MeshKit.box(Vector3(extent.x, h, extent.z)), WorldMaterials.wood(wood_preset),
			base + Vector3(0, bottom + h / 2.0, 0))
	var high_bottom := maxf(Tavern.WAINSCOT_HEIGHT, bottom)
	if top > high_bottom:
		var h2 := top - high_bottom
		MeshKit.add(parent, MeshKit.box(Vector3(extent.x, h2, extent.z)), WorldMaterials.stone("plaster"),
			base + Vector3(0, high_bottom + h2 / 2.0, 0))
	if bottom < Tavern.WAINSCOT_HEIGHT and top > Tavern.WAINSCOT_HEIGHT:
		var rail := Vector3(maxf(extent.x, 0.06) + 0.04, 0.06, maxf(extent.z, 0.06) + 0.04)
		MeshKit.add(parent, MeshKit.box(rail), WorldMaterials.wood("dark"), base + Vector3(0, Tavern.WAINSCOT_HEIGHT, 0))


static func _window_wall(room: Node3D) -> void:
	var x := Tavern.ROOM_HALF
	var z0 := Tavern.WINDOW_Z - Tavern.WINDOW_SIZE.x / 2.0
	var z1 := Tavern.WINDOW_Z + Tavern.WINDOW_SIZE.x / 2.0
	var top := Tavern.WINDOW_BOTTOM + Tavern.WINDOW_SIZE.y
	var front_len := Tavern.ROOM_HALF - z1
	var back_len := z0 + Tavern.ROOM_HALF
	var thickness := Tavern.WALL_THICKNESS
	_wall(room, Vector3(x, 0, z1 + front_len / 2.0), Vector3(thickness, 0, front_len), "wall_side")
	_wall(room, Vector3(x, 0, z0 - back_len / 2.0), Vector3(thickness, 0, back_len), "wall_side")
	_wall(room, Vector3(x, 0, Tavern.WINDOW_Z), Vector3(thickness, 0, Tavern.WINDOW_SIZE.x), "wall_side", 0.0,
		Tavern.WINDOW_BOTTOM)
	_wall(room, Vector3(x, 0, Tavern.WINDOW_Z), Vector3(thickness, 0, Tavern.WINDOW_SIZE.x), "wall_side", top,
		Tavern.ROOM_HEIGHT)


# —— 月光窗 ——

static func _build_window(tavern: Tavern, room: Node3D) -> void:
	var x := Tavern.ROOM_HALF - Tavern.WALL_THICKNESS / 2.0
	var center := Vector3(x, Tavern.WINDOW_BOTTOM + Tavern.WINDOW_SIZE.y / 2.0, Tavern.WINDOW_Z)
	var frame := MeshKit.pivot(room, center, "Window")
	var wood := WorldMaterials.wood("dark")
	var w := Tavern.WINDOW_SIZE.x
	var h := Tavern.WINDOW_SIZE.y
	MeshKit.add(frame, MeshKit.box(Vector3(0.26, 0.08, w + 0.16)), wood, Vector3(0, -h / 2.0, 0))
	MeshKit.add(frame, MeshKit.box(Vector3(0.24, 0.08, w + 0.16)), wood, Vector3(0, h / 2.0, 0))
	MeshKit.add(frame, MeshKit.box(Vector3(0.24, h, 0.08)), wood, Vector3(0, 0, -w / 2.0))
	MeshKit.add(frame, MeshKit.box(Vector3(0.24, h, 0.08)), wood, Vector3(0, 0, w / 2.0))
	MeshKit.add(frame, MeshKit.box(Vector3(0.06, h, 0.04)), wood, Vector3(0, 0, 0))
	MeshKit.add(frame, MeshKit.box(Vector3(0.06, 0.04, w)), wood, Vector3(0, 0.1, 0))
	var pane := WorldMaterials.glass(Color(0.35, 0.45, 0.7))
	var pane_inst := MeshKit.add(frame, MeshKit.box(Vector3(0.01, h, w)), pane, Vector3(0.02, 0, 0))
	pane_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 月光从窗外斜射进屋:体积雾里形成一道冷色光柱,窗棂投下影子
	var moon := SpotLight3D.new()
	moon.light_color = Color(0.5, 0.62, 1.0)
	moon.light_energy = 3.0
	moon.spot_range = 9.0
	moon.spot_angle = 24.0
	moon.shadow_enabled = true
	moon.light_volumetric_fog_energy = 2.5
	tavern.add_child(moon)
	moon.look_at_from_position(center + Vector3(2.2, 1.5, 0.6), Vector3(0.5, 0.2, -0.6))
