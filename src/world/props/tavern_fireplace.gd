class_name TavernFireplace
# 壁炉:后墙正中偏左的石砌壁炉、炉膛里的柴火与火焰、壁炉台、烟囱,炉火光(带阴影)与火星。


static func build(tavern: Tavern) -> void:
	var z := -Tavern.ROOM_HALF + Tavern.WALL_THICKNESS / 2.0
	var fp := MeshKit.pivot(tavern, Vector3(Tavern.FIREPLACE_X, 0, z), "Fireplace")
	var stone := WorldMaterials.stone("fireplace")
	MeshKit.add(fp, MeshKit.box(Vector3(0.42, 1.0, 0.5)), stone, Vector3(-0.78, 0.5, 0.25))
	MeshKit.add(fp, MeshKit.box(Vector3(0.42, 1.0, 0.5)), stone, Vector3(0.78, 0.5, 0.25))
	MeshKit.add(fp, MeshKit.box(Vector3(1.98, 0.45, 0.55)), stone, Vector3(0, 1.22, 0.27))
	MeshKit.add(fp, MeshKit.box(Vector3(2.2, 0.08, 0.68)), WorldMaterials.wood("dark"), Vector3(0, 1.48, 0.3))
	MeshKit.add(fp, MeshKit.box(Vector3(1.2, 1.0, 0.1)), WorldMaterials.iron(), Vector3(0, 0.5, 0.05))
	MeshKit.add(fp, MeshKit.box(Vector3(1.4, 1.9, 0.42)), stone, Vector3(0, 2.47, 0.2))
	MeshKit.add(fp, MeshKit.box(Vector3(0.95, 0.04, 0.45)), WorldMaterials.iron(), Vector3(0, 0.02, 0.28))
	for i in 3:
		MeshKit.add(fp, MeshKit.cylinder(0.055, 0.06, 0.62, 12), WorldMaterials.wood("log"),
			Vector3(-0.08 + i * 0.08, 0.1 + (i % 2) * 0.07, 0.3), Vector3(90, 0, 70 + i * 22))
	MeshKit.add(fp, MeshKit.sphere(0.2, 16), WorldMaterials.emissive(Color(1.0, 0.32, 0.06), 4.0),
		Vector3(0, 0.05, 0.3), Vector3.ZERO, Vector3(1.6, 0.25, 0.8))
	for i in 6:
		var h := 0.36 + 0.14 * ((i * 7) % 3)
		MeshKit.add(fp, MeshKit.quad(Vector2(h * 0.75, h)), WorldMaterials.flame(3.0, 20.0 + i),
			Vector3(-0.3 + i * 0.12, 0.08 + h / 2.0, 0.32 + (i % 2) * 0.04))
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.5, 0.75)
	light.light_color = Color(1.0, 0.56, 0.3)
	light.light_energy = 2.7
	light.omni_range = 7.0
	light.shadow_enabled = true
	light.light_volumetric_fog_energy = 0.6
	fp.add_child(light)
	tavern.add_flicker(light, 3.5, 0.3, 50.0)
	fp.add_child(Fx.embers(Vector3(0, 0.3, 0.3)))
