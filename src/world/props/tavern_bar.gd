class_name TavernBar
# 吧台:左墙前的柜台与台面、黄铜踏脚杆、背后三层酒架上的酒瓶、台面上的啤酒杯,以及吧台上方的暖光。


const BOTTLE_COLORS := [Color(0.15, 0.35, 0.12), Color(0.55, 0.3, 0.05), Color(0.45, 0.05, 0.05),
	Color(0.75, 0.75, 0.7), Color(0.1, 0.15, 0.35)]


static func build(tavern: Tavern) -> void:
	var x := -Tavern.ROOM_HALF + Tavern.WALL_THICKNESS / 2.0
	var bar := MeshKit.pivot(tavern, Vector3(x, 0, -0.6), "Bar")
	MeshKit.add(bar, MeshKit.box(Vector3(0.62, 1.05, 3.4)), WorldMaterials.wood("wall_side"), Vector3(1.05, 0.525, 0))
	MeshKit.add(bar, MeshKit.box(Vector3(0.74, 0.06, 3.5)), WorldMaterials.wood("table"), Vector3(1.05, 1.08, 0))
	MeshKit.add(bar, MeshKit.cylinder(0.018, 0.018, 3.3, 12), WorldMaterials.brass(), Vector3(1.46, 0.2, 0),
		Vector3(90, 0, 0))
	for z in [-1.4, 0.0, 1.4]:
		MeshKit.add(bar, MeshKit.box(Vector3(0.12, 0.025, 0.025)), WorldMaterials.brass(), Vector3(1.4, 0.2, z))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for shelf in 3:
		var y := 1.55 + shelf * 0.45
		MeshKit.add(bar, MeshKit.box(Vector3(0.3, 0.04, 3.0)), WorldMaterials.wood("dark"), Vector3(0.22, y, 0))
		var z := -1.35
		while z < 1.35:
			var h := rng.randf_range(0.18, 0.3)
			var color: Color = BOTTLE_COLORS[rng.randi() % BOTTLE_COLORS.size()]
			_bottle(bar, Vector3(0.22, y + 0.02, z), h, color)
			z += rng.randf_range(0.1, 0.2)
	for i in 4:
		_mug(bar, Vector3(1.05 + rng.randf_range(-0.15, 0.15), 1.11, -1.2 + i * 0.7 + rng.randf_range(-0.1, 0.1)))
	var light := OmniLight3D.new()
	light.position = Vector3(0.9, 2.5, 0)
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 1.4
	light.omni_range = 3.8
	bar.add_child(light)


static func _bottle(parent: Node3D, base: Vector3, height: float, color: Color) -> void:
	var glass := WorldMaterials.glass(color)
	var body_h := height * 0.62
	MeshKit.add(parent, MeshKit.cylinder(0.035, 0.037, body_h, 14), glass, base + Vector3(0, body_h / 2.0, 0))
	MeshKit.add(parent, MeshKit.cylinder(0.012, 0.034, height * 0.14, 14), glass, base + Vector3(0, body_h + height * 0.07, 0))
	MeshKit.add(parent, MeshKit.cylinder(0.012, 0.012, height * 0.2, 10), glass, base + Vector3(0, body_h + height * 0.24, 0))
	MeshKit.add(parent, MeshKit.cylinder(0.011, 0.011, 0.025, 8), WorldMaterials.wood("grip"),
		base + Vector3(0, body_h + height * 0.35, 0))


static func _mug(parent: Node3D, base: Vector3) -> void:
	MeshKit.add(parent, MeshKit.cylinder(0.045, 0.042, 0.12, 16), WorldMaterials.wood("barrel"), base + Vector3(0, 0.06, 0))
	MeshKit.add(parent, MeshKit.cylinder(0.04, 0.04, 0.005, 16), WorldMaterials.emissive(Color(0.95, 0.85, 0.6), 0.2),
		base + Vector3(0, 0.118, 0))
	MeshKit.add(parent, MeshKit.torus(0.025, 0.035, 12), WorldMaterials.iron(), base + Vector3(0.05, 0.06, 0),
		Vector3(90, 0, 0))
