class_name PatronParts
# 酒客的静态部件构建:物种外观表、椅子、耳朵、帽子、口鼻。动画逻辑在 Patron 中。


const SPECIES := [
	{
		"id": "fox", "label": "狐狸",
		"fur": Color(0.86, 0.4, 0.13), "muzzle": Color(0.96, 0.9, 0.8), "dark": Color(0.18, 0.08, 0.04),
		"coat": Color(0.13, 0.17, 0.3), "accent": Color(0.82, 0.62, 0.25), "hat": "top", "ears": "pointy",
	},
	{
		"id": "bear", "label": "熊",
		"fur": Color(0.36, 0.21, 0.11), "muzzle": Color(0.66, 0.5, 0.34), "dark": Color(0.12, 0.07, 0.04),
		"coat": Color(0.42, 0.11, 0.09), "accent": Color(0.86, 0.76, 0.52), "hat": "bowler", "ears": "round",
	},
	{
		"id": "pig", "label": "猪",
		"fur": Color(0.93, 0.6, 0.58), "muzzle": Color(0.98, 0.68, 0.66), "dark": Color(0.45, 0.2, 0.2),
		"coat": Color(0.2, 0.3, 0.17), "accent": Color(0.85, 0.3, 0.22), "hat": "cap", "ears": "floppy",
	},
	{
		"id": "cat", "label": "猫",
		"fur": Color(0.46, 0.47, 0.52), "muzzle": Color(0.88, 0.87, 0.85), "dark": Color(0.1, 0.1, 0.12),
		"coat": Color(0.3, 0.22, 0.38), "accent": Color(0.42, 0.66, 0.72), "hat": "cowboy", "ears": "cat",
	},
]


static func species(index: int) -> Dictionary:
	return SPECIES[posmod(index, SPECIES.size())]


static func first_free_species(used: Array) -> int:
	# 新酒客取第一个没人用的物种,同桌不撞脸;物种全被占用(人数超过物种数)时才轮流重复
	for i in SPECIES.size():
		if not used.has(i):
			return i
	return posmod(used.size(), SPECIES.size())


static func build_chair(parent: Node3D) -> void:
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


static func build_ears(head: Node3D, kind: String, fur: Material, inner: Material) -> Array:
	# 返回耳朵枢轴数组(用于抖耳朵动画)
	var pivots := []
	for side in [-1.0, 1.0]:
		var pivot := MeshKit.pivot(head, Vector3(0.1 * side, 0.25, 0.0))
		match kind:
			"pointy":
				pivot.rotation_degrees = Vector3(0, 0, -22 * side)
				MeshKit.add(pivot, MeshKit.cylinder(0.0, 0.055, 0.15, 12), fur, Vector3(0, 0.05, 0))
				MeshKit.add(pivot, MeshKit.cylinder(0.0, 0.032, 0.09, 10), inner, Vector3(0, 0.035, -0.022))
			"round":
				pivot.position = Vector3(0.12 * side, 0.24, 0.01)
				MeshKit.add(pivot, MeshKit.sphere(0.058, 14), fur, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.55))
				MeshKit.add(pivot, MeshKit.sphere(0.034, 12), inner, Vector3(0, -0.004, -0.02), Vector3.ZERO,
					Vector3(1, 1, 0.4))
			"floppy":
				pivot.position = Vector3(0.11 * side, 0.24, -0.02)
				pivot.rotation_degrees = Vector3(-55, 0, -30 * side)
				MeshKit.add(pivot, MeshKit.prism(Vector3(0.1, 0.11, 0.02)), fur, Vector3(0, 0.05, 0))
			"cat":
				pivot.rotation_degrees = Vector3(0, 0, -14 * side)
				MeshKit.add(pivot, MeshKit.cylinder(0.0, 0.058, 0.1, 4), fur, Vector3(0, 0.035, 0), Vector3(0, 45, 0))
				MeshKit.add(pivot, MeshKit.cylinder(0.0, 0.034, 0.06, 4), inner, Vector3(0, 0.022, -0.018), Vector3(0, 45, 0))
		pivots.append(pivot)
	return pivots


static func build_snout(head: Node3D, spec: Dictionary, mats: Dictionary) -> void:
	if spec["id"] == "pig":
		MeshKit.add(head, MeshKit.cylinder(0.056, 0.06, 0.06, 20), mats["muzzle"], Vector3(0, 0.075, -0.17),
			Vector3(90, 0, 0))
		for side in [-1.0, 1.0]:
			MeshKit.add(head, MeshKit.sphere(0.013, 8), mats["dark"], Vector3(0.02 * side, 0.075, -0.2),
				Vector3.ZERO, Vector3(1, 1.4, 0.5))
		return
	var length := 1.25 if spec["id"] == "fox" else 0.9
	MeshKit.add(head, MeshKit.sphere(0.085, 18), mats["muzzle"], Vector3(0, 0.07, -0.13),
		Vector3.ZERO, Vector3(1.1, 0.78, length))
	MeshKit.add(head, MeshKit.sphere(0.026, 12), mats["nose"], Vector3(0, 0.1, -0.13 - 0.085 * length))
	MeshKit.add(head, MeshKit.box(Vector3(0.05, 0.006, 0.01)), mats["dark"], Vector3(0, 0.035, -0.19))
	if spec["id"] == "cat":
		for side in [-1.0, 1.0]:
			for k in 2:
				MeshKit.add(head, MeshKit.cylinder(0.0015, 0.0015, 0.12, 4), mats["muzzle"],
					Vector3(0.09 * side, 0.07 - k * 0.02, -0.16), Vector3(0, 0, 90 + (8 - k * 16) * side))


static func build_hat(head: Node3D, kind: String, hat_mat: Material, band_mat: Material) -> Node3D:
	var hat := MeshKit.pivot(head, Vector3(0, 0.255, 0.01), "Hat")
	hat.rotation_degrees = Vector3(-6, 0, 9)
	match kind:
		"top":
			MeshKit.add(hat, MeshKit.cylinder(0.17, 0.17, 0.012, 32), hat_mat)
			MeshKit.add(hat, MeshKit.cylinder(0.105, 0.098, 0.2, 32), hat_mat, Vector3(0, 0.1, 0))
			MeshKit.add(hat, MeshKit.cylinder(0.101, 0.101, 0.03, 32), band_mat, Vector3(0, 0.025, 0))
		"bowler":
			MeshKit.add(hat, MeshKit.cylinder(0.16, 0.16, 0.012, 32), hat_mat)
			MeshKit.add(hat, MeshKit.hemisphere(0.115, 24), hat_mat, Vector3(0, 0.006, 0), Vector3.ZERO, Vector3(1, 1.15, 1))
			MeshKit.add(hat, MeshKit.cylinder(0.117, 0.117, 0.025, 32), band_mat, Vector3(0, 0.02, 0))
		"cowboy":
			MeshKit.add(hat, MeshKit.cylinder(0.25, 0.25, 0.012, 32), hat_mat, Vector3.ZERO, Vector3.ZERO, Vector3(1, 1, 0.82))
			MeshKit.add(hat, MeshKit.torus(0.22, 0.255, 32), hat_mat, Vector3(0, 0.012, 0), Vector3.ZERO, Vector3(1, 0.8, 0.82))
			MeshKit.add(hat, MeshKit.cylinder(0.075, 0.11, 0.14, 24), hat_mat, Vector3(0, 0.07, 0))
			MeshKit.add(hat, MeshKit.cylinder(0.106, 0.112, 0.028, 24), band_mat, Vector3(0, 0.02, 0))
		"cap":
			hat.rotation_degrees = Vector3(-10, 0, -6)
			MeshKit.add(hat, MeshKit.hemisphere(0.16, 24), hat_mat, Vector3(0, -0.02, 0), Vector3.ZERO, Vector3(1.05, 0.45, 1.1))
			MeshKit.add(hat, MeshKit.cylinder(0.11, 0.11, 0.012, 24), hat_mat, Vector3(0, -0.012, -0.12),
				Vector3.ZERO, Vector3(1, 1, 0.55))
			MeshKit.add(hat, MeshKit.sphere(0.018, 10), band_mat, Vector3(0, 0.055, 0))
	return hat
