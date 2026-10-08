extends GutTest
# RoomKit 的圆润形体(动森式卡通):圆角截面、平滑法线挤出、圆角盒子——尺寸不变、绕序与 Godot 基础体一致、法线单位长度且平滑。


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


func test_round_rect_is_ccw_and_fits_the_size():
	var pts := RoomKit.round_rect(0.3, 0.2, 0.05, 3)
	assert_eq(pts.size(), 16)
	var area := 0.0
	var lo := Vector2(INF, INF)
	var hi := -lo
	for k in pts.size():
		area += pts[k].x * pts[(k + 1) % pts.size()].y - pts[(k + 1) % pts.size()].x * pts[k].y
		lo = lo.min(pts[k])
		hi = hi.max(pts[k])
	assert_gt(area, 0.0, "逆时针")
	assert_almost_eq(hi.x - lo.x, 0.3, 1e-5)
	assert_almost_eq(hi.y - lo.y, 0.2, 1e-5)


func test_rounded_box_keeps_its_size_winds_like_godot_and_has_unit_normals():
	var arrays: Array = MeshForge.run(func(f: MeshForge): RoomKit.rounded_box(f, Vector3(0.4, 0.2, 0.3), 0.05))[&"main"]
	assert_almost_eq(_winding_sign(arrays), _godot_sign(), 0.01)
	var box := MeshForge.commit({&"main": arrays}).get_aabb()
	assert_almost_eq(box.size.x, 0.4, 1e-5)
	assert_almost_eq(box.size.y, 0.2, 1e-5)
	assert_almost_eq(box.size.z, 0.3, 1e-5)
	for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		assert_almost_eq(n.length(), 1.0, 1e-5)
	assert_eq(arrays[Mesh.ARRAY_INDEX].size() / 3, 300)


func test_rounded_box_corners_are_cut_by_the_radius():
	var arrays: Array = MeshForge.run(func(f: MeshForge): RoomKit.rounded_box(f, Vector3(1, 1, 1), 0.2))[&"main"]
	var far := 0.0
	for p: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
		far = maxf(far, p.length())
	assert_almost_eq(far, Vector3(0.3, 0.3, 0.3).length() + 0.2, 1e-4, "角是 1/8 球")


func test_extrude_smooth_winds_like_godot_and_shares_normals_on_round_corners():
	var profile := RoomKit.round_rect(0.2, 0.1, 0.03, 3)
	var arrays: Array = MeshForge.run(func(f: MeshForge): RoomKit.extrude_smooth(f, profile, 0.5))[&"main"]
	assert_almost_eq(_winding_sign(arrays), _godot_sign(), 0.01)
	var box := MeshForge.commit({&"main": arrays}).get_aabb()
	assert_almost_eq(box.size.x, 0.5, 1e-5)
	# 圆角上相邻两条边在共同顶点处法线一致(第 0 条边的终点 = 第 1 条边的起点)
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert_almost_eq(n[2].distance_to(n[4]), 0.0, 1e-5)
	var cw := profile.duplicate()
	cw.reverse()
	var arrays_cw: Array = MeshForge.run(func(f: MeshForge): RoomKit.extrude_smooth(f, cw, 0.5))[&"main"]
	assert_almost_eq(_winding_sign(arrays_cw), _godot_sign(), 0.01, "顺时针给的截面也按外法线算")
