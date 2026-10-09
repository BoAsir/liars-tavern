extends GutTest
# 程序化几何与合批:生成的三角形都朝外(按 Godot 顺时针正面约定)、合批按槽位分表面、
# 部件坐标与种子写进自定义通道、镜像部件不翻面、缓存的网格只建一次。


const FACES_OUT_TOLERANCE := 0.0


# —— 生成器朝向 ——

func test_lathe_faces_outward():
	var profile := PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0), Vector2(0.05, 0), Vector2(0.06, 0.1),
		Vector2(0.02, 0.18), Vector2(0, 0.2)])
	_assert_faces_out(MeshShapes.lathe(profile, 12), "回转体")


func test_lathe_crease_keeps_flat_bottom_normal():
	var arrays := MeshShapes.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.05, 0), Vector2(0.05, 0), Vector2(0.05, 0.1)]), 8)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_almost_eq(normals[9], Vector3.DOWN, Vector3.ONE * 0.001, "折边前的底面边缘法线朝下")
	assert_almost_eq(normals[18].y, 0.0, 0.001, "折边后的侧壁法线水平")


func test_tube_faces_outward_along_a_bent_path():
	var path := PackedVector3Array([Vector3.ZERO, Vector3(0, 0.1, 0), Vector3(0.05, 0.18, 0.02), Vector3(0.12, 0.2, 0.05)])
	_assert_faces_out(MeshShapes.tube(path, PackedFloat32Array([0.02, 0.018, 0.012, 0.004]), 8), "管子")


func test_extrude_faces_outward_with_and_without_bevel():
	var arch := PackedVector2Array([Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(0.5, 0.6), Vector2(0.3, 0.85),
		Vector2(0, 0.95), Vector2(-0.3, 0.85), Vector2(-0.5, 0.6)])
	_assert_faces_out(MeshShapes.extrude(arch, 0.1), "拉伸")
	_assert_faces_out(MeshShapes.extrude(arch, 0.1, 0.02), "带斜角的拉伸")
	var clockwise := arch.duplicate()
	clockwise.reverse()
	_assert_faces_out(MeshShapes.extrude(clockwise, 0.1, 0.02), "顺时针给出的轮廓")


func test_rounded_box_faces_outward_and_keeps_its_size():
	var arrays := MeshShapes.rounded_box(Vector3(0.4, 0.1, 0.2), 0.02, 3)
	_assert_faces_out(arrays, "圆角盒")
	var aabb := _aabb(arrays[Mesh.ARRAY_VERTEX])
	assert_almost_eq(aabb.size, Vector3(0.4, 0.1, 0.2), Vector3.ONE * 0.0005, "外形尺寸不变")


func test_deform_recomputes_outward_normals():
	var sphere := SphereMesh.new()
	var squashed := MeshShapes.deform(sphere.get_mesh_arrays(), func(v: Vector3) -> Vector3:
		return Vector3(v.x * 1.4, v.y * 0.6 + v.x * v.x * 0.3, v.z))
	_assert_faces_out(squashed, "变形后的球")


# —— 合批 ——

func test_batch_merges_parts_per_slot():
	var wood := StandardMaterial3D.new()
	var brass := StandardMaterial3D.new()
	var batch := MeshBatch.new()
	batch.add_part(MeshKit.box(Vector3.ONE * 0.1), wood, Vector3(0, 0, 0))
	batch.add_part(MeshKit.box(Vector3.ONE * 0.1), wood, Vector3(1, 0, 0))
	batch.add_part(MeshKit.sphere(0.05, 8), brass, Vector3(0, 1, 0))
	var mesh := batch.build()
	assert_eq(mesh.get_surface_count(), 2, "同材质合成一个表面")
	assert_eq(mesh.surface_get_material(0), wood)
	assert_eq(mesh.surface_get_material(1), brass)
	assert_eq(batch.triangle_count(), 12 * 2 + _triangles(MeshKit.sphere(0.05, 8).get_mesh_arrays()))


func test_batch_moves_vertices_but_keeps_part_local_coordinates():
	var batch := MeshBatch.new()
	batch.add_part(MeshKit.box(Vector3(0.2, 0.2, 0.2)), "wood", Vector3(3, 0, 0), Vector3(0, 90, 0))
	var arrays := batch.build().surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var local: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var seeds: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
	assert_almost_eq(_aabb(verts).get_center(), Vector3(3, 0, 0), Vector3.ONE * 0.001, "顶点移到摆放位置")
	assert_eq(local.size(), verts.size() * 3, "每个顶点三个分量的部件坐标")
	assert_lt(absf(local[0]), 0.1001, "部件坐标仍是合并前的物体坐标")
	assert_true(seeds[0] >= MeshBatch.LOCAL_MARKER and seeds[0] < MeshBatch.LOCAL_MARKER + 1.0, "种子带合批标记")


func test_batch_mirrored_parts_still_face_outward():
	var batch := MeshBatch.new()
	batch.add_part(MeshKit.sphere(0.1, 10), "fur", Vector3(0.2, 0, 0), Vector3.ZERO, Vector3(-1, 1, 1))
	_assert_faces_out(batch.build().surface_get_arrays(0), "镜像的部件")


func test_named_slots_take_instance_materials():
	var batch := MeshBatch.new()
	batch.add_part(MeshKit.box(Vector3.ONE * 0.1), "coat")
	batch.add_part(MeshKit.box(Vector3.ONE * 0.1), "fur", Vector3.UP)
	var mesh := batch.build()
	var parent := Node3D.new()
	add_child_autofree(parent)
	var coat := StandardMaterial3D.new()
	var fur := StandardMaterial3D.new()
	var inst := MeshBatch.instance(parent, mesh, {"coat": coat, "fur": fur}, "Body")
	assert_eq(inst.name, &"Body")
	assert_eq(inst.get_surface_override_material(0), coat)
	assert_eq(inst.get_surface_override_material(1), fur)
	assert_null(mesh.surface_get_material(0), "网格本身不带材质,可被多个实例共用")


func test_cached_meshes_are_built_once():
	MeshBatch.clear_cache()
	var builds := [0]
	var build := func(batch: MeshBatch) -> void:
		builds[0] += 1
		batch.add_part(MeshKit.box(Vector3.ONE * 0.1), "wood")
	var first := MeshBatch.cached("test:box", build)
	var second := MeshBatch.cached("test:box", build)
	assert_same(first, second)
	assert_eq(builds[0], 1)
	MeshBatch.clear_cache()


# —— 工具 ——

func _assert_faces_out(arrays: Array, label: String) -> void:
	# Godot 正面为顺时针:三角形 (a,b,c) 的外法线 ∝ (c-a)×(b-a),应与顶点法线同向
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var wrong := 0
	var checked := 0
	for t in range(0, indices.size(), 3):
		var a := verts[indices[t]]
		var b := verts[indices[t + 1]]
		var c := verts[indices[t + 2]]
		var face := (c - a).cross(b - a)
		if face.length() < 1e-9:
			continue
		checked += 1
		var avg := normals[indices[t]] + normals[indices[t + 1]] + normals[indices[t + 2]]
		if face.normalized().dot(avg.normalized()) <= FACES_OUT_TOLERANCE:
			wrong += 1
	assert_gt(checked, 0, label + ":有三角形")
	assert_eq(wrong, 0, label + ":所有三角形朝外(%d/%d 朝内)" % [wrong, checked])


func _aabb(verts: PackedVector3Array) -> AABB:
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	return box


func _triangles(arrays: Array) -> int:
	return (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
