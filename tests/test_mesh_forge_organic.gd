extends GutTest
# MeshForge 有机形体:平滑并集椭球(头雕)、放样(躯干/袖/尾)、细管;法线、绕序、包围盒、逐顶点颜色与 CUSTOM0。


func _main(recipe: Callable) -> Array:
	return MeshForge.run(recipe)[&"main"]


func _winding_sign(arrays: Array) -> float:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var total := 0.0
	var count := 0
	for k in range(0, idx.size(), 3):
		var face := (v[idx[k + 1]] - v[idx[k]]).cross(v[idx[k + 2]] - v[idx[k]])
		if face.length() < 1e-10:
			continue
		total += signf(face.dot(n[idx[k]] + n[idx[k + 1]] + n[idx[k + 2]]))
		count += 1
	return total / count


func _godot_sign() -> float:
	return _winding_sign(MeshKit.sphere(0.1, 12).get_mesh_arrays())


func test_blob_covers_every_ellipsoid_and_keeps_godot_winding():
	var shapes := [[Vector3(0, 0.12, 0), Vector3(0.165, 0.15, 0.16), Color(0.8, 0.4, 0.1)],
		[Vector3(0.09, 0.06, -0.04), Vector3(0.08, 0.055, 0.07), Color(0.8, 0.74, 0.62), "mirror"]]
	var arrays := _main(func(f): f.blob(Vector3(0, 0.12, 0), shapes, 24, 12, 0.03))
	assert_almost_eq(_winding_sign(arrays), _godot_sign(), 0.05, "绕序与 Godot 基础体一致")
	var box := MeshForge.commit({&"main": arrays}).get_aabb()
	assert_gte(box.end.y, 0.12 + 0.15 - 0.002, "主颅骨顶")
	assert_gte(box.end.x, 0.09 + 0.08 - 0.003, "右腮")
	assert_lte(box.position.x, -0.09 - 0.08 + 0.003, "镜像的左腮")
	assert_lte(box.end.y, 0.12 + 0.15 + 0.03, "平滑并集最多鼓出 k")
	for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		assert_almost_eq(n.length(), 1.0, 1e-4)


func test_blob_colors_follow_the_nearest_shape():
	var fur := Color(0.8, 0.4, 0.1)
	var cream := Color(0.8, 0.74, 0.62)
	var arrays := _main(func(f): f.blob(Vector3.ZERO, [[Vector3.ZERO, Vector3(0.1, 0.1, 0.1), fur],
		[Vector3(0, 0, -0.1), Vector3(0.05, 0.05, 0.05), cream]], 24, 12, 0.02))
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var front := 0
	var back := 0
	for i in v.size():
		if v[i].z < -0.14:
			assert_lt(absf(c[i].g - cream.g), 0.02, "吻尖是吻的颜色")
			front += 1
		elif v[i].z > 0.08:
			assert_lt(absf(c[i].g - fur.g), 0.02, "后脑是毛色")
			back += 1
	assert_gt(front, 0)
	assert_gt(back, 0)


func test_loft_follows_the_path_with_elliptic_sections():
	var path := PackedVector3Array([Vector3(0, 0, 0), Vector3(0, 0, -0.2), Vector3(0, -0.05, -0.4)])
	var radii := PackedVector2Array([Vector2(0.06, 0.05), Vector2(0.05, 0.05), Vector2(0.056, 0.05)])
	var arrays := _main(func(f): f.loft(path, radii, 12))
	assert_almost_eq(_winding_sign(arrays), _godot_sign(), 0.05, "绕序与 Godot 基础体一致")
	var box := MeshForge.commit({&"main": arrays}).get_aabb()
	assert_almost_eq(box.position.z, -0.4, 0.02, "末端截面随路径下弯而倾斜")
	assert_almost_eq(box.end.z, 0.0, 0.002)
	for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		assert_almost_eq(n.length(), 1.0, 1e-4)


func test_loft_writes_sway_weight_rising_along_the_path():
	var path := PackedVector3Array()
	var radii := PackedVector2Array()
	for i in 6:
		path.append(Vector3(0, 0, -0.1 * i))
		radii.append(Vector2(0.03, 0.03))
	var arrays := _main(func(f): f.loft(path, radii, 6, Vector2i(0, 0), Transform3D.IDENTITY, PackedColorArray(), Vector2(0.4, 1.0)))
	var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in v.size():
		var along := -v[i].z / 0.5
		var w := custom[i * 4 + 1]
		if along < 0.39:
			assert_almost_eq(w, 0.0, 0.0001, "尾根不摆")
		if along > 0.99:
			assert_almost_eq(w, 1.0, 0.0001, "尾尖摆满")


func test_write_custom_stamps_every_vertex_so_patron_meshes_share_one_format():
	var built := MeshForge.run(func(f: MeshForge):
		f.write_custom = true
		f.custom = Vector4(3, 0, 0.5, 1)
		f.sphere(0.05, 8)
		f.tube(PackedVector3Array([Vector3.ZERO, Vector3(0, 0, -0.1)]), 0.002))
	var arrays: Array = built[&"main"]
	var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	assert_eq(custom.size(), arrays[Mesh.ARRAY_VERTEX].size() * 4)
	assert_eq(custom[0], 3.0)
	assert_eq(custom[custom.size() - 4], 3.0)
	assert_eq(custom[custom.size() - 1], 1.0)


func test_organic_recipes_run_on_worker_threads():
	var recipe := func(f: MeshForge):
		f.blob(Vector3.ZERO, [[Vector3.ZERO, Vector3(0.1, 0.12, 0.1), Color.WHITE]], 16, 8)
		f.loft(PackedVector3Array([Vector3.ZERO, Vector3(0, 0.3, 0)]), PackedVector2Array([Vector2(0.1, 0.1), Vector2(0.05, 0.05)]))
	MeshForge.prebuild([["test:organic", recipe]])
	await MeshForge.wait_prebuilt(get_tree())
	assert_true(MeshForge.is_cached("test:organic"))
	MeshForge.clear_cache()
