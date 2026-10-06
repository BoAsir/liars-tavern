extends GutTest


func test_my_seat_is_angle_zero_and_others_go_clockwise():
	assert_almost_eq(SeatLayout.seat_angle(2, 2, 4), 0.0, 0.0001)
	assert_almost_eq(SeatLayout.seat_angle(3, 2, 4), TAU / 4.0, 0.0001)
	assert_almost_eq(SeatLayout.seat_angle(1, 2, 4), TAU * 3.0 / 4.0, 0.0001)
	assert_almost_eq(SeatLayout.seat_angle(1, 0, 2), PI, 0.0001)


func test_direction_maps_zero_to_camera_side_and_next_seat_to_left():
	assert_almost_eq(SeatLayout.direction(0.0).distance_to(Vector3(0, 0, 1)), 0.0, 0.0001)
	assert_almost_eq(SeatLayout.direction(PI / 2.0).distance_to(Vector3(-1, 0, 0)), 0.0, 0.0001)


func test_seat_position_on_radius_at_floor():
	var pos := SeatLayout.seat_position(PI, 2.0)
	assert_almost_eq(pos.distance_to(Vector3(0, 0, -2)), 0.0, 0.0001)


func test_fan_single_card_is_centered_and_flat():
	var slots := SeatLayout.fan_slots(1)
	assert_eq(slots.size(), 1)
	assert_eq(slots[0]["x"], 0.0)
	assert_eq(slots[0]["rot"], 0.0)


func test_fan_is_symmetric_with_outer_cards_lower():
	var slots := SeatLayout.fan_slots(5)
	assert_eq(slots.size(), 5)
	for i in 5:
		assert_almost_eq(slots[i]["x"], -slots[4 - i]["x"], 0.0001)
		assert_almost_eq(slots[i]["rot"], -slots[4 - i]["rot"], 0.0001)
	assert_almost_eq(slots[2]["x"], 0.0, 0.0001)
	assert_lt(slots[0]["x"], slots[1]["x"])
	assert_lt(slots[0]["y"], slots[2]["y"])
	assert_gt(slots[0]["rot"], 0.0, "left card tilts counter-clockwise")


func test_fan_empty():
	assert_eq(SeatLayout.fan_slots(0), [])


func test_pile_offsets_stay_in_ring_and_are_deterministic():
	for i in 40:
		var a := SeatLayout.pile_offset(i, 7)
		var r: float = a["pos"].length()
		assert_between(r, SeatLayout.PILE_INNER, SeatLayout.PILE_OUTER)
		assert_eq(a, SeatLayout.pile_offset(i, 7))
	assert_ne(SeatLayout.pile_offset(0, 7), SeatLayout.pile_offset(0, 8))


func test_reveal_slots_centered():
	var xs := SeatLayout.reveal_slots(3, 0.1)
	assert_eq(xs.size(), 3)
	assert_almost_eq(xs[0], -0.1, 0.0001)
	assert_almost_eq(xs[1], 0.0, 0.0001)
	assert_almost_eq(xs[2], 0.1, 0.0001)
