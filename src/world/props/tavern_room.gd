class_name TavernRoom
# 房间本体:木板地面、木构架墙(立柱、顶梁、斜撑、护墙板、灰泥)、梁 + 龙骨 + 木板的天花板、
# 前墙的大门、右墙的月光窗(窗帘、窗外夜空)与月光。
# 全部合成两个网格:Shell 不投影(地面、天花板、墙面、护墙板、门、窗帘、夜空),Frame 投影
# (木构架、梁与龙骨、窗框窗棂、右墙墙体 —— 月光只从窗洞进屋,窗格的影子落在地上)。
# 网格按 key 缓存,开场拼装一次。


static func build(tavern: Tavern) -> void:
	var room := MeshKit.pivot(tavern, Vector3.ZERO, "Room")
	MeshBatch.instance(room, shell_mesh(), {}, "Shell", false)
	MeshBatch.instance(room, frame_mesh(), {}, "Frame")
	_add_moonlight(tavern)


static func shell_mesh() -> ArrayMesh:
	return MeshBatch.cached("room:shell", func(batch: MeshBatch) -> void:
		RoomCeiling.add_shell(batch)
		RoomWalls.add_shell(batch)
		RoomWindow.add_shell(batch)
		RoomDoor.add_shell(batch))


static func frame_mesh() -> ArrayMesh:
	return MeshBatch.cached("room:frame", func(batch: MeshBatch) -> void:
		RoomCeiling.add_frame(batch)
		RoomWalls.add_frame(batch)
		RoomWindow.add_frame(batch))


static func _add_moonlight(tavern: Tavern) -> void:
	# 月光从窗外斜射进屋:体积雾里形成一道冷色光柱,窗棂投下影子。参数由灯光调校维护,原样保留
	var center := Vector3(Tavern.ROOM_HALF - Tavern.WALL_THICKNESS / 2.0,
		Tavern.WINDOW_BOTTOM + Tavern.WINDOW_SIZE.y / 2.0, Tavern.WINDOW_Z)
	var moon := SpotLight3D.new()
	moon.light_color = Color(0.5, 0.62, 1.0)
	moon.light_energy = 3.0
	moon.spot_range = 9.0
	moon.spot_angle = 24.0
	moon.shadow_enabled = true
	moon.light_volumetric_fog_energy = 2.5
	tavern.add_child(moon)
	moon.look_at_from_position(center + Vector3(2.2, 1.5, 0.6), Vector3(0.5, 0.2, -0.6))
