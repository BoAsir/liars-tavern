extends GutTest
# GazeSync:视线同步的纯逻辑 —— 座位坐标换算、发送节流与心跳、接收端的超时与释放、非法数据过滤。


const EPS := 0.001

var gaze: GazeSync


func before_each():
	gaze = GazeSync.new()


func _seat(angle: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, angle), Vector3(sin(angle), 0, cos(angle)) * 1.4)


func test_seat_local_round_trip_maps_to_same_relative_point():
	# 每台机器的座位整体转了不同角度:同一个相对落点在两边都落在"同一个人"相对的位置上
	var sender_here := _seat(0.0)
	var sender_there := _seat(2.1)
	var target := Vector3(-0.6, 1.2, 0.3)
	var local := GazeSync.to_seat_local(sender_here, target)
	var there := GazeSync.from_seat_local(sender_there, local)
	assert_almost_eq(there.distance_to(sender_there.origin), target.distance_to(sender_here.origin), EPS)
	assert_almost_eq(there.y, target.y, EPS)
	assert_true(GazeSync.from_seat_local(sender_here, local).is_equal_approx(target))


func test_first_active_frame_sends_immediately():
	var out := gaze.outgoing(0.016, Vector3(0, 1, 0), true)
	assert_eq(out.get("active"), true)
	assert_true(out["point"].is_equal_approx(Vector3(0, 1, 0)))


func test_throttles_within_send_interval():
	gaze.outgoing(0.016, Vector3.ZERO, true)
	assert_true(gaze.outgoing(GazeSync.SEND_INTERVAL * 0.5, Vector3(1, 0, 0), true).is_empty(), "间隔内不再发送")
	assert_false(gaze.outgoing(GazeSync.SEND_INTERVAL * 0.6, Vector3(1, 0, 0), true).is_empty(), "过了间隔、目标动了就发")


func test_still_target_only_sends_heartbeats():
	gaze.outgoing(0.016, Vector3.ZERO, true)
	assert_true(gaze.outgoing(GazeSync.SEND_INTERVAL * 1.5, Vector3(0.001, 0, 0), true).is_empty(), "几乎没动不发")
	assert_false(gaze.outgoing(GazeSync.HEARTBEAT, Vector3.ZERO, true).is_empty(), "到心跳时间补发一次,对端才不会判超时")


func test_going_inactive_sends_one_release_then_silence():
	gaze.outgoing(0.016, Vector3.ZERO, true)
	var out := gaze.outgoing(0.016, Vector3.ZERO, false)
	assert_eq(out.get("active"), false, "交还演出时立即通知,不等节流")
	assert_true(gaze.outgoing(GazeSync.HEARTBEAT * 2.0, Vector3.ZERO, false).is_empty())


func test_inactive_from_start_sends_nothing():
	assert_true(gaze.outgoing(0.016, Vector3.ZERO, false).is_empty())


func test_received_target_is_live_until_stale():
	gaze.receive(7, Vector3(1, 1, 1), true)
	assert_true(gaze.tick(GazeSync.STALE * 0.5).is_empty())
	assert_true(gaze.live_targets()[7].is_equal_approx(Vector3(1, 1, 1)))
	assert_eq(gaze.tick(GazeSync.STALE * 0.6), [7], "收不到心跳就释放,交还给演出")
	assert_false(gaze.live_targets().has(7))
	assert_true(gaze.tick(1.0).is_empty(), "只释放一次")


func test_release_message_frees_on_next_tick():
	gaze.receive(7, Vector3(1, 1, 1), true)
	gaze.receive(7, Vector3(1, 1, 1), false)
	assert_false(gaze.live_targets().has(7))
	assert_eq(gaze.tick(0.016), [7])


func test_release_without_prior_target_is_ignored():
	gaze.receive(7, Vector3.ZERO, false)
	assert_true(gaze.tick(0.016).is_empty())


func test_fresh_update_resets_staleness():
	gaze.receive(7, Vector3.ZERO, true)
	gaze.tick(GazeSync.STALE * 0.8)
	gaze.receive(7, Vector3(0, 1, 0), true)
	assert_true(gaze.tick(GazeSync.STALE * 0.8).is_empty())
	assert_true(gaze.live_targets().has(7))


func test_rejects_non_finite_or_far_points():
	assert_true(GazeSync.is_valid(Vector3(1, 2, -3)))
	assert_false(GazeSync.is_valid(Vector3(NAN, 0, 0)))
	assert_false(GazeSync.is_valid(Vector3(INF, 0, 0)))
	assert_false(GazeSync.is_valid(Vector3(0, GazeSync.MAX_RANGE + 1.0, 0)))


func test_forget_drops_player():
	gaze.receive(7, Vector3.ZERO, true)
	gaze.forget(7)
	assert_false(gaze.live_targets().has(7))
	assert_true(gaze.tick(0.016).is_empty())


func test_looking_at_a_player_lands_on_that_player_on_every_screen():
	# 四人桌:座位 0 的人看着座位 2 的人。座位 1、座位 3 的屏幕各自把"自己"摆在前排,
	# 换算回来的落点都要正好落在他们画面里座位 2 那个人身上
	var world := TableWorld.new(null)
	var count := 4
	var sender := 0
	var watched := 2
	var sender_view := func(i): return SeatLayout.seat_angle(i, sender, count)
	var local := GazeSync.to_seat_local(world.seat_transform(sender_view.call(sender)),
		SeatLayout.seat_position(sender_view.call(watched)))
	for viewer in [1, 3]:
		var seat_there := world.seat_transform(SeatLayout.seat_angle(sender, viewer, count))
		var expected := SeatLayout.seat_position(SeatLayout.seat_angle(watched, viewer, count))
		assert_true(GazeSync.from_seat_local(seat_there, local).is_equal_approx(expected), "座位 %d 的屏幕" % viewer)
	world.free()
