extends GutTest
# 场景预算(无头):用截图/性能探针同一个展台场景(tools/showcase.gd:4 名酒客、手牌、左轮)检查清单类指标,
# draw call 与帧时间只能由 tools/perf_probe.gd 在窗口里测。

const SceneCensus := preload("res://tools/scene_census.gd")

var _tavern: Tavern
var _showcase: Node


func before_all():
	_tavern = Tavern.new()
	add_child(_tavern)
	_showcase = load("res://tools/showcase.gd").new()
	add_child(_showcase)
	Engine.time_scale = 8.0   # 展台里有发牌、出牌、举枪等补间,无头下加速走完
	await _showcase.build(_tavern)
	Engine.time_scale = 1.0


func after_all():
	Engine.time_scale = 1.0
	_showcase.free()
	_tavern.free()


func _meshes() -> Array:
	return _tavern.find_children("*", "MeshInstance3D", true, false)


func test_small_parts_do_not_cast_shadows():
	var offenders := []
	for inst: MeshInstance3D in _meshes():
		if inst.has_meta(&"force_shadow") or inst.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		if MeshKit.caster_size(inst) < MeshKit.SMALL_CASTER:
			offenders.append("%s (%.3f m)" % [inst.get_path(), MeshKit.caster_size(inst)])
	assert_eq(offenders, [], "小于 8 cm 的件不该投影")


func test_floor_and_solid_wall_panels_do_not_cast_shadows():
	var room := _tavern.get_node("Room")
	assert_eq(room.get_node("Floor").cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	for prefix in ["WallBack", "WallFront", "WallLeft"]:
		for part in ["Wainscot", "Plaster"]:
			assert_eq(room.get_node(prefix + part).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, prefix + part)
		assert_eq(room.get_node(prefix + "Rail").cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, prefix + "Rail")


func test_window_wall_keeps_casting_so_the_moonbeam_keeps_its_shape():
	var room := _tavern.get_node("Room")
	var parts := room.get_children().filter(func(n): return String(n.name).begins_with("WindowWall"))
	assert_gt(parts.size(), 0)
	for part: MeshInstance3D in parts:
		assert_eq(part.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, part.name)


func test_paws_hats_and_cards_still_cast_shadows():
	for patron in _tavern.find_children("*", "Patron", true, false):
		var hand: Node3D = patron.right_hand
		var paw := hand.get_children().filter(func(n): return n is MeshInstance3D)
		assert_eq(paw[0].cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "爪")
	var cards := _tavern.find_children("*", "Card3D", true, false)
	assert_gt(cards.size(), 0)
	for mesh: MeshInstance3D in cards[0].find_children("*", "MeshInstance3D", true, false):
		assert_ne(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "牌")


func test_census_is_within_current_limits():
	var census := SceneCensus.count(_tavern)
	assert_lte(census["shadow_lights"], 3)
	assert_lte(census["lights"], 18)


func test_all_flames_share_one_material_with_distinct_seeds():
	var flames := _meshes().filter(func(m: MeshInstance3D):
		return m.material_override is ShaderMaterial and m.material_override.shader == WorldMaterials.FLAME_SHADER)
	assert_gt(flames.size(), 10)
	var materials := {}
	var seeds := {}
	for flame: MeshInstance3D in flames:
		materials[flame.material_override] = true
		seeds[flame.get_instance_shader_parameter("seed")] = true
	assert_eq(materials.size(), 1, "火焰共用一份材质")
	assert_eq(seeds.size(), flames.size(), "每簇火焰的种子不同,相邻火苗不同步")
