extends GutTest
# 桌面道具不穿帮:牌堆与翻牌行的牌都在毡面之上(底牌曾陷进桌布 0.3 mm、和毡面抢深度);牌背的弹孔数等于膛数。


func test_pile_and_reveal_cards_sit_above_the_felt():
	# 牌底(中面 − 半个牌厚)高出毡面,相邻两层不相交
	for seed in 20:
		for i in 30:
			var bottom := CardTable.pile_transform(i, seed).origin.y - Card3D.THICKNESS / 2.0
			assert_gte(bottom, SeatLayout.FELT_TOP + 0.0002, "牌堆第 %d 张的牌底" % i)
			if i > 0:
				var below := CardTable.pile_transform(i - 1, seed).origin.y + Card3D.THICKNESS / 2.0
				assert_gt(bottom, below, "第 %d 张不和下面那张相交" % i)
	for n in [1, 2, 3, 4]:
		for i in n:
			var bottom := CardTable.reveal_transform(i, n).origin.y - Card3D.THICKNESS / 2.0
			assert_gte(bottom, SeatLayout.FELT_TOP + 0.0002, "翻牌行")


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


func _part_points(gun: Revolver3D, part: String) -> PackedVector3Array:
	# 静置枪的转轮顶点 / 握把底帽顶点(全局坐标)
	var out := PackedVector3Array()
	var inst: MeshInstance3D = gun.get_node("Body/Drum/DrumMesh" if part == "drum" else "Body/BodyMesh")
	for s in inst.mesh.get_surface_count():
		for v: Vector3 in inst.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
			if part == "drum" or v.y < -0.066:
				out.append(inst.global_transform * v)
	return out


func test_resting_guns_lie_on_felt_and_table():
	# 转轮压在毡面上、底帽落在毡面外的木桌面上:不悬空也不陷桌(按网格顶点精确算)
	for count in [2, 3, 4]:
		var world := _world(count)
		for pid in world.revolvers:
			var label := "%d 人局 %d 号座" % [count, pid]
			var drum := _part_points(world.revolvers[pid], "drum")
			var cap := _part_points(world.revolvers[pid], "cap")
			var drum_low := INF
			var drum_far := 0.0
			for v in drum:
				if v.y < drum_low:
					drum_low = v.y
					drum_far = Vector2(v.x, v.z).length()
			var cap_low := INF
			var cap_near := INF
			for v in cap:
				cap_low = minf(cap_low, v.y)
				cap_near = minf(cap_near, Vector2(v.x, v.z).length())
			assert_almost_eq(drum_low, SeatLayout.FELT_TOP, 0.001, label + " 转轮最低点在毡面上")
			assert_lt(drum_far, SeatLayout.FELT_RADIUS, label + " 转轮着地处在毡面范围内")
			assert_almost_eq(cap_low, SeatLayout.TABLE_TOP, 0.001, label + " 底帽落在木桌面上")
			assert_gt(cap_near, SeatLayout.FELT_RADIUS, label + " 底帽在毡面外")
			assert_gte(_lowest_point(world.revolvers[pid]), SeatLayout.TABLE_TOP - 0.0005, label + " 不陷桌")


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
