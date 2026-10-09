extends GutTest
# 3D 左轮:其他代码依赖的节点名、枢轴位置与常量不变;扳击锤时击锤转起、转轮转过一膛;
# 四把枪共用同一份缓存网格(每局重建不再拼装);侧放在桌上时不陷进桌布、也不悬空;
# 左轮专用的程序化几何三角形都朝外。


const HAMMER_PIVOT := Vector3(0, 0.06, 0.022)
const FELT_THICKNESS := 0.004      # 桌布顶面高出 TABLE_TOP 的厚度(TavernTable)
const MAX_HOVER := 0.006           # 侧放时最低点离桌布不超过这么多,看上去是贴着桌面的
const SHADOW_SHARE := 0.6          # 投影三角形占预算的上限
const REVOLVER_TRIANGLES := 6000
const TWEEN_WAIT := 0.3


func _gun() -> Revolver3D:
	var gun := Revolver3D.new()
	add_child_autofree(gun)
	return gun


# —— 结构与常量 ——

func test_node_structure_and_pivots_are_preserved():
	var gun := _gun()
	assert_not_null(gun.get_node_or_null("Body"), "有 Body")
	assert_eq(gun.drum, gun.get_node_or_null("Body/Drum"), "转轮枢轴是 Body/Drum")
	assert_eq(gun.hammer, gun.get_node_or_null("Body/Hammer"), "击锤枢轴是 Body/Hammer")
	assert_eq(gun.drum.position, Revolver3D.DRUM_POS, "转轮枢轴在 DRUM_POS")
	assert_eq(gun.hammer.position, HAMMER_PIVOT, "击锤枢轴位置不变")
	assert_eq(gun.muzzle.position, Revolver3D.MUZZLE_POS, "枪口标记在 MUZZLE_POS")
	assert_almost_eq(Revolver3D.BARREL_LENGTH, 0.15, 0.0001, "枪管长度常量不变")


func test_muzzle_marker_sits_at_the_barrel_tip():
	# 枪口火焰从标记点喷出:枪身网格最靠前的地方就是枪口
	var gun := _gun()
	var frame: MeshInstance3D = gun.get_node("Body/Frame")
	var front := frame.mesh.get_aabb().position.z
	assert_almost_eq(front, Revolver3D.MUZZLE_POS.z, 0.002, "枪管前端与枪口标记对齐")


func test_drum_has_one_marker_per_chamber():
	var gun := _gun()
	var mouths := gun.drum.find_children("Chamber*", "Marker3D", false, false)
	assert_eq(mouths.size(), Revolver.CHAMBERS, "每膛一个膛口标记")


# —— 动作 ——

func test_cock_hammer_raises_the_hammer_and_turns_one_chamber():
	var gun := _gun()
	gun.cock_hammer(0.05)
	await wait_seconds(TWEEN_WAIT)
	assert_almost_eq(gun.hammer.rotation.x, deg_to_rad(Revolver3D.HAMMER_COCKED_DEG), 0.001, "击锤扳起")
	assert_almost_eq(gun.drum.rotation.z, TAU / Revolver.CHAMBERS, 0.001, "转轮转过一膛")
	gun.release_hammer()
	await wait_seconds(TWEEN_WAIT)
	assert_almost_eq(gun.hammer.rotation.x, 0.0, 0.001, "击锤落下")


# —— 缓存与预算 ——

func test_revolvers_share_cached_meshes():
	var a := _meshes(_gun())
	var b := _meshes(_gun())
	assert_gt(a.size(), 0, "左轮有网格")
	assert_eq(a, b, "两把枪的每个网格都是同一份缓存")


func test_shadow_casting_share_stays_small():
	var gun := _gun()
	var shadow := 0
	for node in gun.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			for s in mi.mesh.get_surface_count():
				shadow += (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	assert_gt(shadow, 0, "枪身投影")
	assert_lte(shadow, int(REVOLVER_TRIANGLES * SHADOW_SHARE), "投影三角形不超过预算的六成")


# —— 侧放在桌上 ——

func test_lying_revolvers_rest_on_the_felt():
	var tavern := Tavern.new()
	add_child_autofree(tavern)
	var world := TableWorld.new(tavern)
	tavern.table_root.add_child(world)
	world.arrange([{"pid": 1}, {"pid": 2}, {"pid": 3}, {"pid": 4}], 1, true, true)
	var felt_top := SeatLayout.TABLE_TOP + FELT_THICKNESS
	for pid in world.revolvers:
		var lowest := _lowest_point(world.revolvers[pid])
		assert_gte(lowest, felt_top - 0.0005, "左轮 %d 不陷进桌布" % pid)
		assert_lte(lowest, felt_top + MAX_HOVER, "左轮 %d 贴着桌面,不悬空" % pid)


# —— 程序化几何 ——

func test_slab_faces_outward_on_curved_and_sharp_outlines():
	_assert_faces_out(RevolverShapes.slab(RevolverModel.guard_outline(), 0.012, 0.0015), "扳机护圈")
	_assert_faces_out(RevolverShapes.slab(RevolverModel.hammer_outline(), 0.008, 0.0005), "带齿的击锤")
	var clockwise := RevolverModel.guard_outline()
	clockwise.reverse()
	_assert_faces_out(RevolverShapes.slab(clockwise, 0.012, 0.0015), "顺时针给出的轮廓")


func test_drum_and_panel_shapes_face_outward():
	var panel := RevolverShapes.ccw(RevolverModel.raked(RevolverModel.PANEL_OUTLINE))
	_assert_faces_out(RevolverShapes.domed_panel(panel, RevolverModel.rake_point(RevolverModel.PANEL_CENTER), 0.01,
		PackedFloat32Array(RevolverModel.PANEL_RINGS)), "握把片")
	var rays := RevolverShapes.sector_rays(6, 0.013, 0.021, 12)
	_assert_faces_out(RevolverShapes.holed_disc(0.021, 6, 0.013, 0.005, rays, 90.0), "转轮前脸")


# —— 工具 ——

func _meshes(gun: Revolver3D) -> Array:
	var out := []
	for node in gun.find_children("*", "MeshInstance3D", true, false):
		out.append((node as MeshInstance3D).mesh)
	return out


func _lowest_point(gun: Revolver3D) -> float:
	var lowest := INF
	for node in gun.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		var xform := mi.global_transform
		for s in mi.mesh.get_surface_count():
			for v in (mi.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				lowest = minf(lowest, (xform * v).y)
	return lowest


func _assert_faces_out(arrays: Array, label: String) -> void:
	# Godot 正面为顺时针:三角形 (a,b,c) 的外法线 ∝ (c-a)×(b-a),应与顶点法线同向
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var wrong := 0
	var checked := 0
	for t in range(0, indices.size(), 3):
		var a := verts[indices[t]]
		var face := (verts[indices[t + 2]] - a).cross(verts[indices[t + 1]] - a)
		if face.length() < 1e-12:
			continue
		checked += 1
		var avg := normals[indices[t]] + normals[indices[t + 1]] + normals[indices[t + 2]]
		if face.normalized().dot(avg.normalized()) <= 0.0:
			wrong += 1
	assert_gt(checked, 0, label + ":有三角形")
	assert_eq(wrong, 0, label + ":所有三角形朝外(%d/%d 朝内)" % [wrong, checked])
