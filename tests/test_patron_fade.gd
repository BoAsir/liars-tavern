extends GutTest
# 酒客合批后:所有部件共用一份酒客材质,出局褪色走实例参数 fade(帽子打飞后照样褪),不再给每个酒客复制材质。

const FADE_CHECK := 1.6   # 褪色 1.4 s,留一点余量(秒)

var world: TableWorld


func before_each():
	world = TableWorld.new(null)
	add_child_autofree(world)
	world.arrange([{"pid": 1}, {"pid": 2}], 1, true, false)


func _fade_of(g: GeometryInstance3D) -> float:
	var value: Variant = g.get_instance_shader_parameter("fade")
	return 0.0 if value == null else float(value)   # 没设过就是着色器默认值 0


func _patron_geometry(patron: Patron) -> Array:
	return patron.find_children("*", "GeometryInstance3D", true, false).filter(func(g: GeometryInstance3D):
		var mesh: Mesh = g.mesh if g is MeshInstance3D else null
		return mesh != null and mesh.get_surface_count() > 0 and mesh.surface_get_material(0) == WorldMaterials.patron())


func test_patrons_have_no_private_materials():
	# 合批前每个酒客有约 10 份自己的 StandardMaterial3D;现在只剩缓存里的共享材质
	var shared := WorldMaterials._cache.values()
	for patron: Patron in world.patrons.values():
		for inst: MeshInstance3D in patron.find_children("*", "MeshInstance3D", true, false):
			var private := inst.material_override != null and not shared.has(inst.material_override)
			assert_false(private, "私有材质: %s" % inst.get_path())


func test_die_fades_every_part_including_the_knocked_off_hat():
	var victim: Patron = world.patrons[2]
	var targets := _patron_geometry(victim)
	assert_gt(targets.size(), 10)
	victim.die()
	await wait_seconds(FADE_CHECK)
	var hats := world.get_children().filter(func(n): return n.is_in_group(Patron.DEBRIS_GROUP))
	assert_eq(hats.size(), 1, "帽子打飞成一个散落物")
	for g: GeometryInstance3D in targets:
		assert_almost_eq(_fade_of(g), 1.0, 0.01, str(g.get_path()))
	for g: GeometryInstance3D in _patron_geometry(world.patrons[1]):
		assert_almost_eq(_fade_of(g), 0.0, 0.0001, "活着的不褪色")
