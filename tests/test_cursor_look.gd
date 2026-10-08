extends GutTest
# SeatGaze 的纯函数:光标 → 视线目标(射线落在桌面上看桌面那一点,否则看射线上远处一点);WASD → 脖子伸出的目标偏移。


const SEAT_CAMERA := Vector3(TableWorld.THIRD_PERSON_SIDE, TableWorld.THIRD_PERSON_HEIGHT, SeatLayout.SEAT_RADIUS + TableWorld.THIRD_PERSON_BEHIND)


func test_ray_onto_the_table_looks_at_the_tabletop_point():
	var dir := (Vector3(0.2, SeatLayout.TABLE_TOP, -0.3) - SEAT_CAMERA)
	var target: Vector3 = SeatGaze.cursor_look_target(SEAT_CAMERA, dir)
	assert_almost_eq(target.y, SeatLayout.TABLE_TOP, 0.001)
	assert_almost_eq(target.x, 0.2, 0.001)
	assert_almost_eq(target.z, -0.3, 0.001)


func test_ray_above_the_table_looks_far_along_the_ray():
	var dir := Vector3(-0.3, 0.1, -1.0)
	var target: Vector3 = SeatGaze.cursor_look_target(SEAT_CAMERA, dir)
	assert_almost_eq(target.distance_to(SEAT_CAMERA), SeatGaze.CURSOR_LOOK_FAR, 0.001)
	assert_lt(target.x, SEAT_CAMERA.x, "光标偏左时视线目标也在左边")


func test_ray_hitting_the_floor_beyond_the_table_does_not_snap_to_the_table_plane():
	# 指向桌外地面:与桌面平面的交点在桌子半径外,不能当成"看桌面"
	var dir := (Vector3(2.5, SeatLayout.TABLE_TOP, 1.5) - SEAT_CAMERA)
	var target: Vector3 = SeatGaze.cursor_look_target(SEAT_CAMERA, dir)
	assert_almost_eq(target.distance_to(SEAT_CAMERA), SeatGaze.CURSOR_LOOK_FAR, 0.001)


func test_unnormalized_direction_is_handled():
	var target: Vector3 = SeatGaze.cursor_look_target(SEAT_CAMERA, Vector3(0, 0, -10))
	assert_almost_eq(target.distance_to(SEAT_CAMERA), SeatGaze.CURSOR_LOOK_FAR, 0.001)


func test_neck_input_grows_while_held_and_caps_at_reach():
	var input := Vector3.ZERO
	input = SeatGaze.next_neck_input(input, Vector3(0, 0, -1), 0.1)
	assert_almost_eq(input.z, -SeatGaze.NECK_SPEED * 0.1, 0.0001, "按住 W 朝桌心伸出")
	for i in 100:
		input = SeatGaze.next_neck_input(input, Vector3(0, 0, -1), 0.1)
	assert_almost_eq(input.length(), Patron.NECK_REACH, 0.0001, "伸到上限为止")


func test_neck_input_diagonal_is_not_faster():
	var input := SeatGaze.next_neck_input(Vector3.ZERO, Vector3(1, 0, -1), 0.1)
	assert_almost_eq(input.length(), SeatGaze.NECK_SPEED * 0.1, 0.0001)


func test_neck_input_stays_when_released():
	var input := SeatGaze.next_neck_input(Vector3.ZERO, Vector3(-1, 0, 0), 0.3)
	assert_eq(SeatGaze.next_neck_input(input, Vector3.ZERO, 0.016), input, "松开就停在原处,不弹回")


func test_neck_input_does_not_go_backward():
	# 头只能往前、往两侧探:往后(朝越肩镜头)会挡在镜头和自己的手牌之间(同 feature/liars-tavern-mvp 的 eadc745)
	var input := SeatGaze.next_neck_input(Vector3.ZERO, Vector3(0, 0, 1), 0.5)
	assert_eq(input, Vector3.ZERO, "在原位按 S 不往后探")
	input = SeatGaze.next_neck_input(input, Vector3(0, 0, -1), 0.1)
	assert_almost_eq(input.z, -SeatGaze.NECK_SPEED * 0.1, 0.0001, "随后按 W 立刻往前,不用先抵消攒下的后退量")


func test_neck_input_back_key_stops_at_rest():
	var input := SeatGaze.next_neck_input(Vector3.ZERO, Vector3(1, 0, -1), 0.4)
	input = SeatGaze.next_neck_input(input, Vector3(0, 0, 1), 2.0)
	assert_almost_eq(input.z, 0.0, 0.0001, "按 S 收回到原位就停")
	assert_gt(input.x, 0.0, "横向位置保留")


func test_neck_input_does_not_go_backward():
	var input := SeatGaze.next_neck_input(Vector3.ZERO, Vector3(0, 0, 1), 0.5)
	assert_eq(input, Vector3.ZERO, "在原位按 S 不往后探")
	input = SeatGaze.next_neck_input(input, Vector3(0, 0, -1), 0.1)
	assert_almost_eq(input.z, -SeatGaze.NECK_SPEED * 0.1, 0.0001, "随后按 W 立刻往前,不用先抵消攒下的后退量")


func test_neck_input_back_key_stops_at_rest():
	var input := SeatGaze.next_neck_input(Vector3.ZERO, Vector3(1, 0, -1), 0.4)
	input = SeatGaze.next_neck_input(input, Vector3(0, 0, 1), 2.0)
	assert_almost_eq(input.z, 0.0, 0.0001, "按 S 收回到原位就停")
	assert_gt(input.x, 0.0, "横向位置保留")


func test_opposite_key_brings_the_head_back():
	var input := SeatGaze.next_neck_input(Vector3.ZERO, Vector3(0, 0, -1), 0.5)
	input = SeatGaze.next_neck_input(input, Vector3(0, 0, 1), 0.5)
	assert_almost_eq(input.length(), 0.0, 0.0001, "按 S 同样时长,头回到原位")
