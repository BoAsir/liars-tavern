extends GutTest
# MeshKit 网格缓存:同参数返回同一份只读网格(相同网格 + 相同材质才会被 Forward+ 自动实例化),
# 参数量化到 0.1 mm;缓存网格永远不被改写。


func after_each():
	MeshKit.clear_cache()


func test_same_parameters_share_one_mesh():
	assert_same(MeshKit.box(Vector3(0.1, 0.2, 0.3)), MeshKit.box(Vector3(0.1, 0.2, 0.3)))
	assert_same(MeshKit.cylinder(0.02, 0.03, 0.4, 12), MeshKit.cylinder(0.02, 0.03, 0.4, 12))
	assert_same(MeshKit.sphere(0.05, 16), MeshKit.sphere(0.05, 16))
	assert_same(MeshKit.capsule(0.05, 0.3), MeshKit.capsule(0.05, 0.3))
	assert_same(MeshKit.torus(0.1, 0.12, 24), MeshKit.torus(0.1, 0.12, 24))
	assert_same(MeshKit.prism(Vector3(0.1, 0.1, 0.02)), MeshKit.prism(Vector3(0.1, 0.1, 0.02)))
	assert_same(MeshKit.plane(Vector2(0.2, 0.3)), MeshKit.plane(Vector2(0.2, 0.3)))
	assert_same(MeshKit.quad(Vector2(0.2, 0.3)), MeshKit.quad(Vector2(0.2, 0.3)))


func test_different_parameters_get_different_meshes():
	assert_not_same(MeshKit.box(Vector3(0.1, 0.2, 0.3)), MeshKit.box(Vector3(0.1, 0.2, 0.31)))
	assert_not_same(MeshKit.sphere(0.05, 16), MeshKit.sphere(0.05, 18))
	assert_not_same(MeshKit.plane(Vector2(0.2, 0.3)), MeshKit.quad(Vector2(0.2, 0.3)), "类型不同")


func test_parameters_are_quantized_to_a_tenth_of_a_millimetre():
	var a := MeshKit.box(Vector3(0.1, 0.1, 0.1))
	assert_same(MeshKit.box(Vector3(0.10004, 0.1, 0.1)), a)
	assert_not_same(MeshKit.box(Vector3(0.10006, 0.1, 0.1)), a)
	assert_almost_eq(MeshKit.box(Vector3(0.10006, 0.1, 0.1)).size.x, 0.1001, 0.0000001, "网格按量化后的值建")


func test_hemisphere_does_not_touch_the_cached_sphere():
	var sphere := MeshKit.sphere(0.1, 20)
	var hemi := MeshKit.hemisphere(0.1, 20)
	assert_not_same(hemi, sphere)
	assert_false(sphere.is_hemisphere)
	assert_almost_eq(sphere.height, 0.2, 0.0001)
	assert_true(hemi.is_hemisphere)
	assert_almost_eq(hemi.height, 0.1, 0.0001)
	assert_eq(hemi.rings, maxi(20 / 2, 6))
	assert_same(MeshKit.hemisphere(0.1, 20), hemi)


func test_cylinder_caps_are_part_of_the_key():
	var both := MeshKit.cylinder(0.07, 0.36, 0.2, 48)
	var top := MeshKit.cylinder(0.07, 0.36, 0.2, 48, MeshKit.CAPS_TOP)
	assert_not_same(top, both)
	assert_true(both.cap_top and both.cap_bottom)
	assert_true(top.cap_top)
	assert_false(top.cap_bottom)


func test_building_the_tavern_and_patrons_never_mutates_cached_meshes():
	var tavern := Tavern.new()
	add_child_autofree(tavern)
	var world := TableWorld.new(null)
	add_child_autofree(world)
	world.arrange([{"pid": 1}, {"pid": 2}, {"pid": 3}, {"pid": 4}], 1, true, true)
	assert_eq(MeshKit.audit_cache(), PackedStringArray())


func test_clear_cache_empties_it():
	var a := MeshKit.box(Vector3(0.5, 0.5, 0.5))
	MeshKit.clear_cache()
	assert_not_same(MeshKit.box(Vector3(0.5, 0.5, 0.5)), a)
