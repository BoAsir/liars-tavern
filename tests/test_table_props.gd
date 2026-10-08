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
