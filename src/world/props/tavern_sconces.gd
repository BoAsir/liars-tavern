class_name TavernSconces
# 壁灯:四面墙上的黄铜壁灯,玻璃灯罩里一簇火苗,补亮房间四周,避免只有牌桌一圈亮。


# [墙内表面上的位置, 朝向房间的偏航角]
const SCONCES := [
	[Vector3(-1.7, Tavern.SCONCE_HEIGHT, 4.4), 0.0], [Vector3(1.7, Tavern.SCONCE_HEIGHT, 4.4), 0.0],
	[Vector3(1.4, Tavern.SCONCE_HEIGHT, -4.4), PI], [Vector3(3.2, Tavern.SCONCE_HEIGHT, -4.4), PI],
	[Vector3(-4.4, Tavern.SCONCE_HEIGHT, 2.0), -PI / 2.0], [Vector3(-4.4, Tavern.SCONCE_HEIGHT, -3.1), -PI / 2.0],
	[Vector3(4.4, Tavern.SCONCE_HEIGHT, 1.7), PI / 2.0],
]


static func build(tavern: Tavern) -> void:
	var sconces := MeshKit.pivot(tavern, Vector3.ZERO, "Sconces")
	for i in SCONCES.size():
		_sconce(tavern, sconces, SCONCES[i][0], SCONCES[i][1], 60.0 + i)


static func _sconce(tavern: Tavern, parent: Node3D, wall_point: Vector3, yaw: float, seed: float) -> void:
	# 本地 -Z 指向房间内:黄铜底板 + 弯臂 + 玻璃灯罩里的一簇火苗。
	# 灯光挂在名为 Sconce 的节点下(tools/perf_probe.gd 按父节点名前缀找壁灯的灯光)
	var root := MeshKit.pivot(parent, wall_point, "Sconce")
	root.rotation.y = yaw
	MeshKit.add(root, MeshKit.box(Vector3(0.1, 0.22, 0.02)), WorldMaterials.brass(), Vector3(0, 0, -0.01))
	MeshKit.add(root, MeshKit.cylinder(0.008, 0.008, 0.14, 8), WorldMaterials.brass(), Vector3(0, -0.04, -0.08),
		Vector3(90, 0, 0))
	MeshKit.add(root, MeshKit.cylinder(0.04, 0.022, 0.035, 16), WorldMaterials.brass(), Vector3(0, -0.03, -0.15))
	MeshKit.add(root, MeshKit.cylinder(0.032, 0.036, 0.12, 16), WorldMaterials.glass(Color(1.0, 0.92, 0.8)),
		Vector3(0, 0.045, -0.15))
	MeshKit.add(root, MeshKit.quad(Vector2(0.035, 0.07)), WorldMaterials.flame(3.5, seed), Vector3(0, 0.03, -0.15))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.05, -0.2)
	light.light_color = Color(1.0, 0.74, 0.48)
	light.light_energy = 1.0
	light.omni_range = 4.6
	light.light_volumetric_fog_energy = 0.5
	root.add_child(light)
	tavern.add_flicker(light, 4.0, 0.12, seed)
