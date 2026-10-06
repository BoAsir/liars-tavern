class_name MeshKit
# 程序化建模小工具:用基础几何体快速拼装模型。所有尺寸单位为米。


static func add(parent: Node3D, mesh: Mesh, material: Material, pos := Vector3.ZERO,
		rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.position = pos
	inst.rotation_degrees = rot_deg
	inst.scale = scale
	parent.add_child(inst)
	return inst


static func pivot(parent: Node3D, pos := Vector3.ZERO, node_name := "") -> Node3D:
	var node := Node3D.new()
	if node_name != "":
		node.name = node_name
	node.position = pos
	parent.add_child(node)
	return node


static func box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


static func cylinder(top_radius: float, bottom_radius: float, height: float, segments := 32) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


static func sphere(radius: float, segments := 24) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = maxi(segments / 2, 6)
	return mesh


static func hemisphere(radius: float, segments := 24) -> SphereMesh:
	var mesh := sphere(radius, segments)
	mesh.is_hemisphere = true
	mesh.height = radius
	return mesh


static func capsule(radius: float, height: float, segments := 20) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = segments
	mesh.rings = 6
	return mesh


static func torus(inner_radius: float, outer_radius: float, segments := 32) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = segments
	mesh.ring_segments = 12
	return mesh


static func plane(size: Vector2) -> PlaneMesh:
	var mesh := PlaneMesh.new()
	mesh.size = size
	return mesh


static func quad(size: Vector2) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = size
	return mesh


static func prism(size: Vector3) -> PrismMesh:
	var mesh := PrismMesh.new()
	mesh.size = size
	return mesh
