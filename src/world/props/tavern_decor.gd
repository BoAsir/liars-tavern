class_name TavernDecor
# 散落的陈设:右后角的木桶堆(含一只横倒的桶)。


const BARREL_SPOTS := [Vector3(3.7, 0, -3.6), Vector3(3.1, 0, -3.9), Vector3(3.85, 0, -2.9)]


static func build(tavern: Tavern) -> void:
	var decor := MeshKit.pivot(tavern, Vector3.ZERO, "Decor")
	for i in BARREL_SPOTS.size():
		var barrel := MeshKit.pivot(decor, BARREL_SPOTS[i], "Barrel")
		barrel.rotation.y = i * 1.3
		MeshKit.add(barrel, MeshKit.cylinder(0.27, 0.27, 0.8, 24), WorldMaterials.wood("barrel"), Vector3(0, 0.4, 0),
			Vector3.ZERO, Vector3(1, 1, 1))
		MeshKit.add(barrel, MeshKit.cylinder(0.3, 0.3, 0.5, 24), WorldMaterials.wood("barrel"), Vector3(0, 0.4, 0))
		for y in [0.12, 0.68]:
			MeshKit.add(barrel, MeshKit.torus(0.275, 0.3, 32), WorldMaterials.iron(), Vector3(0, y, 0),
				Vector3.ZERO, Vector3(1, 0.6, 1))
	MeshKit.add(decor, MeshKit.cylinder(0.27, 0.27, 0.8, 24), WorldMaterials.wood("barrel"),
		Vector3(3.4, 0.27, -3.0), Vector3(90, 30, 0))
