extends GutTest
# WorldMaterials:同一预设只建一份;合并网格用的材质(酒客/道具/部件空间木纹)也走缓存,clear_cache 后重建。


func after_each():
	WorldMaterials.clear_cache()


func test_vertex_pbr_materials_are_shared():
	assert_same(WorldMaterials.patron(), WorldMaterials.patron())
	assert_same(WorldMaterials.prop(), WorldMaterials.prop())
	assert_eq(WorldMaterials.patron().shader, WorldMaterials.PATRON_SHADER)
	assert_eq(WorldMaterials.prop().shader, WorldMaterials.PROP_SHADER)


func test_part_space_wood_is_a_separate_fresh_material():
	var plain := WorldMaterials.wood("dark")
	var part := WorldMaterials.wood("dark", true)
	assert_not_same(part, plain)
	assert_same(WorldMaterials.wood("dark", true), part)
	assert_false(plain.get_shader_parameter("use_part_space"))
	assert_true(part.get_shader_parameter("use_part_space"))
	assert_eq(part.get_shader_parameter("ring_frequency"), plain.get_shader_parameter("ring_frequency"), "预设参数一致")


func test_clear_cache_rebuilds():
	var a := WorldMaterials.patron()
	WorldMaterials.clear_cache()
	assert_not_same(WorldMaterials.patron(), a)
