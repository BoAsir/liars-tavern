extends GutTest
# MeshForge 为房间补的接口:quad(UV、卷边)、extrude(截面挤出)、grid(网格面)、part_origin;
# 绕序与 Godot 基础体一致、法线为单位长度。


func _winding_sign(arrays: Array) -> float:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var total := 0.0
	var count := 0
	for k in range(0, idx.size(), 3):
		var face := (v[idx[k + 1]] - v[idx[k]]).cross(v[idx[k + 2]] - v[idx[k]])
		if face.length() < 1e-9:
			continue
		total += signf(face.dot(n[idx[k]] + n[idx[k + 1]] + n[idx[k + 2]]))
		count += 1
	return total / count


func _godot_sign() -> float:
	return _winding_sign(MeshKit.sphere(0.1, 12).get_mesh_arrays())


func test_quad_writes_uvs_inside_the_rect_and_winds_like_godot():
	var rect := Rect2(0.25, 0.5, 0.125, 0.25)
	var arrays: Array = MeshForge.run(func(f: MeshForge): f.quad(Vector2(0.3, 0.4), rect, Transform3D.IDENTITY, 0.02, 6))[&"main"]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_eq(uvs.size(), arrays[Mesh.ARRAY_VERTEX].size())
	for uv in uvs:
		assert_true(rect.grow(1e-6).has_point(uv), "UV %s 在 rect 内" % uv)
	assert_almost_eq(_winding_sign(arrays), _godot_sign(), 0.01)
	var box := MeshForge.commit({&"main": arrays}).get_aabb()
	assert_almost_eq(box.size.x, 0.3, 1e-5)
	assert_almost_eq(box.size.y, 0.4, 1e-5)
	assert_between(box.size.z, 0.019, 0.021, "卷边最多抬 curl 米")
	for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		assert_almost_eq(n.length(), 1.0, 1e-5)


func test_surface_without_uv_parts_gets_zero_uvs():
	var arrays: Array = MeshForge.run(func(f: MeshForge):
		f.box(Vector3(0.1, 0.1, 0.1))
		f.quad(Vector2(0.1, 0.1), Rect2(0.5, 0.5, 0.5, 0.5))
		f.box(Vector3(0.1, 0.1, 0.1)))[&"main"]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	assert_eq(uvs.size(), arrays[Mesh.ARRAY_VERTEX].size(), "UV 数组与顶点等长(没给 UV 的部件补 0)")
	assert_eq(uvs[0], Vector2.ZERO)


func test_extrude_closes_the_profile_and_winds_like_godot_either_way_round():
	var ccw := PackedVector2Array([Vector2(0, 0), Vector2(0.1, 0), Vector2(0.1, 0.2), Vector2(0, 0.2)])
	var cw := ccw.duplicate()
	cw.reverse()
	for profile in [ccw, cw, RoomShell.crown_profile_packed(), PackedVector2Array(RoomShell.chair_rail_profile())]:
		var arrays: Array = MeshForge.run(func(f: MeshForge): f.extrude(profile, 0.5))[&"main"]
		assert_almost_eq(_winding_sign(arrays), _godot_sign(), 0.01)
		var box := MeshForge.commit({&"main": arrays}).get_aabb()
		assert_almost_eq(box.size.x, 0.5, 1e-5, "沿局部 X 挤出")
	var arrays: Array = MeshForge.run(func(f: MeshForge): f.extrude(ccw, 0.5))[&"main"]
	assert_eq(arrays[Mesh.ARRAY_INDEX].size() / 3, 4 * 2 + 2 * 2, "4 个侧面 + 两端封口")


func test_grid_winds_like_godot():
	var rows := [PackedVector3Array([Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(2, 1, 0.2)]),
		PackedVector3Array([Vector3(0, 0, 0), Vector3(1, 0, 0.1), Vector3(2, 0, 0)])]
	var arrays: Array = MeshForge.run(func(f: MeshForge): f.grid(rows))[&"main"]
	assert_almost_eq(_winding_sign(arrays), _godot_sign(), 0.01)


func test_part_origin_offsets_the_part_space_coordinates():
	var arrays: Array = MeshForge.run(func(f: MeshForge):
		f.part_space = true
		f.part_basis = Basis.from_scale(Vector3(2, 1, 1))
		f.part_origin = Vector3(1, 0.5, 0)
		f.box(Vector3(1, 1, 1), MeshForge.xf(Vector3(5, 0, 0))))[&"main"]
	var custom: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM0]
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for k in v.size():
		var local := v[k] - Vector3(5, 0, 0)
		var expected := Vector3(local.x * 2.0 + 1.0, local.y + 0.5, local.z)
		assert_almost_eq(Vector3(custom[k * 4], custom[k * 4 + 1], custom[k * 4 + 2]).distance_to(expected), 0.0, 1e-5)
