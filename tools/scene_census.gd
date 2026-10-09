extends RefCounted
# 场景清点:按节点树数可见网格、MultiMesh 实例、唯一材质、投影物、灯与三角形。
# 性能探针打印、预算测试断言都用它。tools/ 不进导出包,所以不声明 class_name,用 preload 取用。


static func count(root: Node) -> Dictionary:
	var census := {
		"meshes": 0, "multimesh_instances": 0, "materials": 0, "shadow_casters": 0,
		"lights": 0, "shadow_lights": 0, "triangles": 0,
	}
	var materials := {}
	for node in [root] + root.find_children("*", "", true, false):
		if node is Light3D and node.is_visible_in_tree():
			census["lights"] += 1
			if node.shadow_enabled:
				census["shadow_lights"] += 1
		if not (node is GeometryInstance3D) or not node.is_visible_in_tree():
			continue
		var geometry: GeometryInstance3D = node
		if geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			census["shadow_casters"] += 1
		if geometry.material_override != null:
			materials[geometry.material_override] = true
		if node is MeshInstance3D:
			census["meshes"] += 1
			_count_mesh(node, node.mesh, materials, census)
		elif node is MultiMeshInstance3D and node.multimesh != null:
			var multimesh: MultiMesh = node.multimesh
			var instances := multimesh.visible_instance_count
			census["multimesh_instances"] += instances if instances >= 0 else multimesh.instance_count
			_count_mesh(null, multimesh.mesh, materials, census)
	census["materials"] = materials.size()
	return census


static func _count_mesh(inst: MeshInstance3D, mesh: Mesh, materials: Dictionary, census: Dictionary) -> void:
	if mesh == null:
		return
	census["triangles"] += mesh.get_faces().size() / 3
	for surface in mesh.get_surface_count():
		var surface_material := mesh.surface_get_material(surface)
		if surface_material != null:
			materials[surface_material] = true
		if inst != null:
			var override := inst.get_surface_override_material(surface)
			if override != null:
				materials[override] = true
