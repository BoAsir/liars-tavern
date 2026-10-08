extends GutTest
# 桌面道具不穿帮:牌堆与翻牌行的牌都在毡面之上(底牌曾陷进桌布 0.3 mm、和毡面抢深度);牌背的弹孔数等于膛数。


func test_pile_and_reveal_cards_sit_above_the_felt():
	for i in 21:
		assert_gte(CardTable.pile_y(i) - Card3D.GAP, SeatLayout.FELT_TOP + 0.0003, "牌堆第 %d 张的背面" % i)
	assert_gte(CardTable.REVEAL_Y - Card3D.GAP, SeatLayout.FELT_TOP + 0.0003, "翻牌行")


func test_felt_matches_the_layout_constants():
	var tavern := Tavern.new()
	add_child_autofree(tavern)
	var felt: MeshInstance3D = tavern.get_node("Table/Felt")
	var mesh: CylinderMesh = felt.mesh
	assert_almost_eq(felt.position.y + mesh.height / 2.0, SeatLayout.FELT_TOP, 0.00001)
	assert_almost_eq(mesh.top_radius, SeatLayout.FELT_RADIUS, 0.00001)


func test_card_back_has_one_hole_per_chamber():
	assert_eq(CardFaces.chamber_points(Vector2.ZERO, 44.0).size(), Revolver.CHAMBERS)


# —— 左轮 ——

const FAST_CLOCK := 8.0


func after_each():
	Engine.time_scale = 1.0


func _lowest_point(root: Node3D) -> float:
	# 节点下所有网格顶点的最低世界高度(无头测试里网格数组在 CPU 上,可以直接读)
	var lowest := INF
	for inst: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		for v in inst.mesh.get_faces():
			lowest = minf(lowest, (inst.global_transform * v).y)
	return lowest


func _world(count: int) -> TableWorld:
	var world := TableWorld.new(null)
	add_child_autofree(world)
	var players := []
	for pid in range(1, count + 1):
		players.append({"pid": pid})
	world.arrange(players, 1, true, true)
	return world


func test_resting_revolvers_lie_on_the_felt_not_in_it():
	for count in [2, 3, 4]:
		var world := _world(count)
		for pid in world.revolvers:
			assert_gte(_lowest_point(world.revolvers[pid]), SeatLayout.FELT_TOP - 0.0005, "%d 人局 %d 号座" % [count, pid])


func test_dropped_gun_lands_on_the_table():
	var world := _world(2)
	var patron: Patron = world.patrons[2]
	var gun: Revolver3D = world.revolvers[2]
	Engine.time_scale = FAST_CLOCK
	await wait_seconds(0.8)   # 等登场缩放动画放完
	await patron.pick_up(gun, 0.05)
	patron.die(gun, world)
	await wait_seconds(1.0)
	var flat := Vector2(gun.global_position.x, gun.global_position.z)
	assert_lt(flat.length(), SeatLayout.TABLE_RADIUS, "落在桌面范围内")
	assert_gte(_lowest_point(gun), SeatLayout.FELT_TOP - 0.0005, "不陷进桌布")


func test_muzzle_rests_against_the_temple_not_inside_the_head():
	var world := _world(4)
	Engine.time_scale = FAST_CLOCK
	await wait_seconds(0.8)   # 等登场缩放动画(0.55 s)放完,角色才是正常大小
	for pid in world.patrons:
		var patron: Patron = world.patrons[pid]
		var gun: Revolver3D = world.revolvers[pid]
		await patron.pick_up(gun, 0.05)
		await patron.raise_gun_to_head(gun, 0.05)
		var gap := gun.muzzle_transform().origin.distance_to(patron.head_position())
		assert_between(gap, 0.172, 0.2, "%s 枪口到头心" % PatronParts.species(patron.species_index)["id"])
