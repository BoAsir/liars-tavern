extends GutTest
# SceneCensus:按节点树清点可见网格、MultiMesh 实例、唯一材质、投影物、灯与三角形(性能预算与探针共用)。

const SceneCensus := preload("res://tools/scene_census.gd")


func _mesh(parent: Node, mesh: Mesh, material: Material = null) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	parent.add_child(inst)
	return inst


func _root() -> Node3D:
	var root := Node3D.new()
	add_child_autofree(root)
	return root


func test_counts_visible_meshes_only():
	var root := _root()
	_mesh(root, BoxMesh.new())
	_mesh(root, BoxMesh.new()).visible = false
	var hidden_parent := Node3D.new()
	hidden_parent.visible = false
	root.add_child(hidden_parent)
	_mesh(hidden_parent, BoxMesh.new())
	assert_eq(SceneCensus.count(root)["meshes"], 1)


func test_counts_unique_materials_across_override_surface_override_and_mesh():
	var root := _root()
	var shared := StandardMaterial3D.new()
	_mesh(root, BoxMesh.new(), shared)
	_mesh(root, BoxMesh.new(), shared)
	var on_surface := BoxMesh.new()
	on_surface.material = StandardMaterial3D.new()
	_mesh(root, on_surface)
	var surface_override := _mesh(root, BoxMesh.new())
	surface_override.set_surface_override_material(0, StandardMaterial3D.new())
	assert_eq(SceneCensus.count(root)["materials"], 3)


func test_counts_shadow_casters_and_lights():
	var root := _root()
	_mesh(root, BoxMesh.new())
	_mesh(root, BoxMesh.new()).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var lamp := OmniLight3D.new()
	lamp.shadow_enabled = true
	root.add_child(lamp)
	root.add_child(SpotLight3D.new())
	var census := SceneCensus.count(root)
	assert_eq(census["shadow_casters"], 1)
	assert_eq(census["lights"], 2)
	assert_eq(census["shadow_lights"], 1)


func test_counts_multimesh_instances():
	var root := _root()
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = BoxMesh.new()
	multimesh.instance_count = 7
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = multimesh
	root.add_child(inst)
	multimesh.visible_instance_count = 5
	assert_eq(SceneCensus.count(root)["multimesh_instances"], 5, "visible_instance_count 优先")
	multimesh.visible_instance_count = -1
	assert_eq(SceneCensus.count(root)["multimesh_instances"], 7)


func test_counts_triangles():
	var root := _root()
	_mesh(root, BoxMesh.new())   # 6 面 × 2 个三角形
	assert_eq(SceneCensus.count(root)["triangles"], 12)


func test_empty_tree_counts_zero():
	var census := SceneCensus.count(_root())
	for key in ["meshes", "multimesh_instances", "materials", "shadow_casters", "lights", "shadow_lights", "triangles"]:
		assert_eq(census[key], 0, key)
