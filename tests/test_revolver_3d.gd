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
