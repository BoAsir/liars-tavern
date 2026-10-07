extends GutTest
# 光标 → 视线目标:射线落在桌面上看桌面那一点,否则看射线上远处一点。


const TableScreenScript := preload("res://src/ui/table/table_screen.gd")
const SEAT_CAMERA := Vector3(0.55, 1.92, 2.1)


func test_ray_onto_the_table_looks_at_the_tabletop_point():
	var dir := (Vector3(0.2, SeatLayout.TABLE_TOP, -0.3) - SEAT_CAMERA)
	var target: Vector3 = TableScreenScript.cursor_look_target(SEAT_CAMERA, dir)
	assert_almost_eq(target.y, SeatLayout.TABLE_TOP, 0.001)
	assert_almost_eq(target.x, 0.2, 0.001)
	assert_almost_eq(target.z, -0.3, 0.001)


func test_ray_above_the_table_looks_far_along_the_ray():
	var dir := Vector3(-0.3, 0.1, -1.0)
	var target: Vector3 = TableScreenScript.cursor_look_target(SEAT_CAMERA, dir)
	assert_almost_eq(target.distance_to(SEAT_CAMERA), TableScreenScript.CURSOR_LOOK_FAR, 0.001)
	assert_lt(target.x, SEAT_CAMERA.x, "光标偏左时视线目标也在左边")


func test_ray_hitting_the_floor_beyond_the_table_does_not_snap_to_the_table_plane():
	# 指向桌外地面:与桌面平面的交点在桌子半径外,不能当成"看桌面"
	var dir := (Vector3(2.5, SeatLayout.TABLE_TOP, 1.5) - SEAT_CAMERA)
	var target: Vector3 = TableScreenScript.cursor_look_target(SEAT_CAMERA, dir)
	assert_almost_eq(target.distance_to(SEAT_CAMERA), TableScreenScript.CURSOR_LOOK_FAR, 0.001)


func test_unnormalized_direction_is_handled():
	var target: Vector3 = TableScreenScript.cursor_look_target(SEAT_CAMERA, Vector3(0, 0, -10))
	assert_almost_eq(target.distance_to(SEAT_CAMERA), TableScreenScript.CURSOR_LOOK_FAR, 0.001)
