extends GutTest
# 车削温莎椅:布局尺寸沿用旧椅子(尾巴走法、出局姿势、测试都依赖),所有酒客共用一份网格,面数有上限。


func _arrays() -> Array:
	return MeshForge.run(ChairBuilder.recipe)[&"main"]


func test_layout_matches_the_old_chair():
	var v: PackedVector3Array = _arrays()[Mesh.ARRAY_VERTEX]
	var seat_top := -INF
	var top := -INF
	var max_x := 0.0
	for p in v:
		if absf(p.x) < 0.15 and p.z > 0.0 and p.z < 0.28:
			seat_top = maxf(seat_top, p.y) if p.y < 0.6 else seat_top
		top = maxf(top, p.y)
		max_x = maxf(max_x, absf(p.x))
	assert_almost_eq(seat_top, ChairBuilder.SEAT_Y.y, 0.006, "座面顶")
	assert_lte(top, ChairBuilder.TOP, "顶不高过 1.1 m")
	assert_lte(max_x, 0.26, "没有扶手,宽度不超过 0.26")


func test_backrest_leaves_a_gap_above_the_seat_for_thin_tails():
	# 座面顶到靠背杆底之间,在 |x| ≤ 0.12、靠背杆所在的 z 附近不能有木头
	for p: Vector3 in _arrays()[Mesh.ARRAY_VERTEX]:
		if absf(p.x) <= 0.12 and absf(p.z - ChairBuilder.POST_Z) < 0.03:
			assert_false(p.y > ChairBuilder.SEAT_Y.y + 0.003 and p.y < ChairBuilder.BACK_GAP_TOP - 0.001, "缝里有木头:%s" % p)
	assert_gte(ChairBuilder.BACK_GAP_TOP - ChairBuilder.SEAT_Y.y, 0.055)


func test_triangle_budget_and_one_shared_mesh():
	var idx: PackedInt32Array = _arrays()[Mesh.ARRAY_INDEX]
	assert_lte(idx.size() / 3, 1300, "椅子 ≤1300 面")
	assert_same(ChairBuilder.mesh(), ChairBuilder.mesh())
	assert_same(PatronParts.chair_mesh(), ChairBuilder.mesh())


func test_solids_cover_seat_legs_posts_and_slats():
	var solids := ChairBuilder.solids()
	assert_eq(solids.filter(func(s): return s[0] == "cyl").size(), 6, "4 条腿 + 2 根靠背柱")
	assert_eq(solids.filter(func(s): return s[0] == "box").size(), 2, "座面 + 靠背杆")
