class_name ChairModel
# 酒客坐的椅子:原点在座位地面,面朝 -Z(牌桌),座面高约 0.45 米,椅背在 +Z 一侧。


static func build(parent: Node3D) -> void:
	var wood := WorldMaterials.wood("dark")
	MeshKit.add(parent, MeshKit.box(Vector3(0.48, 0.05, 0.44)), wood, Vector3(0, 0.45, 0.14))
	for x in [-0.2, 0.2]:
		for z in [-0.04, 0.32]:
			MeshKit.add(parent, MeshKit.cylinder(0.02, 0.018, 0.45, 8), wood, Vector3(x, 0.225, z))
		MeshKit.add(parent, MeshKit.cylinder(0.022, 0.022, 0.62, 8), wood, Vector3(x, 0.76, 0.34))
		MeshKit.add(parent, MeshKit.sphere(0.03, 10), wood, Vector3(x, 1.08, 0.34))
	MeshKit.add(parent, MeshKit.box(Vector3(0.44, 0.09, 0.035)), wood, Vector3(0, 1.0, 0.34))
	for x in [-0.1, 0.0, 0.1]:
		MeshKit.add(parent, MeshKit.box(Vector3(0.035, 0.42, 0.02)), wood, Vector3(x, 0.74, 0.34))
