extends GutTest
# 物种表:德州一桌最多 8 人,8 个物种互不相同、各自都能建出来、每个都在每人预算之内;
# 同物种的酒客共用网格;没有耳朵的物种(青蛙)不建耳朵节点;喙也随表情换形;举枪时枪管对着太阳穴、不穿过帽子。


const SEATS := 8
const PATRON_BUDGET := [40, 25000]     # 与 test_model_budget 一致:每名酒客(含椅子)
const SHADOW_SHARE := 0.6              # 投影三角形占每人三角形预算的上限比例
const SETTLE := 1.2
const MUZZLE_NEAR := 0.09              # 米:举枪后枪口离太阳穴不超过这么远


func _species_index(id: String) -> int:
	for i in PatronParts.SPECIES.size():
		if PatronParts.species(i)["id"] == id:
			return i
	return -1


func test_eight_distinct_species_with_their_own_names():
	assert_eq(PatronParts.SPECIES.size(), SEATS, "8 个物种,坐满德州一桌")
	var ids := {}
	var labels := {}
	for spec in PatronParts.SPECIES:
		ids[spec["id"]] = true
		labels[spec["label"]] = true
	assert_eq(ids.size(), SEATS, "物种 id 互不相同")
	assert_eq(labels.size(), SEATS, "中文名互不相同")


func test_the_original_four_keep_their_indices():
	assert_eq(["fox", "bear", "pig", "cat"], PatronParts.SPECIES.slice(0, 4).map(func(s): return s["id"]))


func test_first_free_species_fills_eight_seats_without_repeats():
	var used := []
	for seat in SEATS:
		used.append(PatronParts.first_free_species(used))
	used.sort()
	assert_eq(used, range(SEATS), "8 个座位各拿一个不同的物种")


func test_every_species_builds_and_stays_within_the_patron_budget():
	PatronParts.prewarm()
	for i in PatronParts.SPECIES.size():
		var patron := Patron.new(i)
		add_child_autofree(patron)
		var stats := _stats(patron)
		var id: String = PatronParts.species(i)["id"]
		assert_lte(stats["surfaces"], PATRON_BUDGET[0], "%s 的表面数" % id)
		assert_lte(stats["triangles"], PATRON_BUDGET[1], "%s 的三角形数" % id)
		assert_lte(stats["shadow"], int(PATRON_BUDGET[1] * SHADOW_SHARE), "%s 投影的三角形数" % id)
		assert_gt((patron.head.get_node("Hat") as MeshInstance3D).mesh.get_surface_count(), 0, "%s 戴着帽子" % id)


func test_patrons_of_each_species_share_cached_meshes():
	for i in PatronParts.SPECIES.size():
		var a := Patron.new(i)
		var b := Patron.new(i)
		add_child_autofree(a)
		add_child_autofree(b)
		var meshes_a := _meshes(a)
		var meshes_b := _meshes(b)
		assert_eq(meshes_a, meshes_b, "%s:两人的每个网格都是同一份缓存" % PatronParts.species(i)["id"])
		assert_ne(a.skin_material(), b.skin_material(), "各自一份材质(出局单独褪色)")


func test_earless_species_has_no_ear_nodes():
	var frog := Patron.new(_species_index("frog"))
	add_child_autofree(frog)
	assert_null(frog.head.get_node_or_null("EarL"), "青蛙没有耳朵")
	frog.set_expression("worried")
	frog._face._apply()
	assert_eq(frog.expression(), "worried", "没有耳朵也照样换表情")


func test_beak_opens_with_the_expression():
	var owl := Patron.new(_species_index("owl"))
	add_child_autofree(owl)
	var mouth: MeshInstance3D = owl.head.get_node("Mouth")
	var closed := mouth.mesh
	owl.set_expression("happy")
	assert_ne(mouth.mesh, closed, "笑的时候下喙张开")


func test_death_fades_a_new_species_toward_grey():
	var raccoon := Patron.new(_species_index("raccoon"))
	add_child_autofree(raccoon)
	raccoon.die()
	await wait_seconds(PatronSkin.FADE_TIME + 0.2)
	assert_almost_eq(float(raccoon.skin_material().get_shader_parameter("death")), 1.0, 0.01, "褪成灰色")


func test_gun_barrel_points_at_the_temple_below_the_hat():
	var world := TableWorld.new(null)
	add_child_autofree(world)
	world.arrange([{"pid": 1}, {"pid": 2}, {"pid": 3}, {"pid": 4}], 1, true, true)
	await wait_seconds(SETTLE)
	var shooter: Patron = world.patrons[4]
	var gun: Revolver3D = world.revolvers[4]
	await shooter.pick_up(gun, 0.2)
	await shooter.raise_gun_to_head(gun, 0.3)
	var temple := shooter.head.global_transform * shooter._temple
	var muzzle := gun.muzzle.global_position
	assert_lt(muzzle.distance_to(temple), MUZZLE_NEAR, "枪口抵在太阳穴旁")
	var hat: Node3D = shooter.head.get_node("Hat")
	assert_lt(muzzle.y, hat.global_position.y, "枪口在帽檐下面")


# —— 统计 ——

static func _stats(root: Node) -> Dictionary:
	var result := {"surfaces": 0, "triangles": 0, "shadow": 0}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var inst := node as MeshInstance3D
		if inst.mesh == null or not inst.visible:
			continue
		var triangles := 0
		for i in inst.mesh.get_surface_count():
			triangles += (inst.mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
		result["surfaces"] += inst.mesh.get_surface_count()
		result["triangles"] += triangles
		if inst.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			result["shadow"] += triangles
	return result


static func _meshes(root: Node) -> Array:
	return root.find_children("*", "MeshInstance3D", true, false).map(func(n): return (n as MeshInstance3D).mesh)
