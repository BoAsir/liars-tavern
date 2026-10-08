extends GutTest
# 左轮模型与规则一致:弹膛孔数等于 Revolver.CHAMBERS,每扳一次击锤转轮转一格。


func test_drum_has_one_bore_per_chamber():
	var gun := Revolver3D.new()
	add_child_autofree(gun)
	var bores := gun.drum.get_children().filter(func(n): return n.name.begins_with("Chamber"))
	assert_eq(bores.size(), Revolver.CHAMBERS)


func test_cocking_advances_the_drum_one_chamber():
	var gun := Revolver3D.new()
	add_child_autofree(gun)
	var before := gun.drum.rotation.z
	await gun.cock_hammer(0.05).finished
	assert_almost_eq(gun.drum.rotation.z - before, TAU / Revolver.CHAMBERS, 0.0001)


func test_revolver_is_three_shared_meshes():
	# 合批:机身 / 转轮 / 击锤各一个实例,所有左轮共用同一份网格(自动实例化)
	var a := Revolver3D.new()
	var b := Revolver3D.new()
	add_child_autofree(a)
	add_child_autofree(b)
	var meshes_a := a.find_children("*", "MeshInstance3D", true, false)
	var meshes_b := b.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes_a.size(), 3)
	for i in meshes_a.size():
		assert_same(meshes_a[i].mesh, meshes_b[i].mesh, meshes_a[i].name)


func test_chambers_are_markers():
	var gun := Revolver3D.new()
	add_child_autofree(gun)
	for node in gun.drum.get_children().filter(func(n): return n.name.begins_with("Chamber")):
		assert_true(node is Marker3D, node.name)


func test_spinning_stops_on_a_whole_chamber():
	var gun := Revolver3D.new()
	add_child_autofree(gun)
	await gun.spin_drum(0.05, 2.37).finished
	await gun.cock_hammer(0.05).finished
	var step := TAU / Revolver.CHAMBERS
	var rest := fposmod(gun.drum.rotation.z, step)
	assert_true(rest < 0.001 or step - rest < 0.001, "停在整格(余 %.4f)" % rest)


func test_a_chamber_lines_up_with_the_barrel():
	var gun := Revolver3D.new()
	add_child_autofree(gun)
	var chamber: Marker3D = gun.drum.get_node("Chamber1")
	var p := gun.to_local(chamber.global_position)
	assert_almost_eq(p.x, 0.0, 0.0005)
	assert_almost_eq(p.y, Revolver3D.MUZZLE_POS.y, 0.002)
