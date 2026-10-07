extends GutTest
# 客户端回合倒计时:以房主发来的剩余时间为准,本地按(随 time_scale 缩放的)帧时长扣减。


func test_local_fallback_starts_a_full_turn_on_each_turn_change():
	# 旧版房主不发剩余时间:与原行为一致,每次轮转从整 30 秒开始
	var clock := TurnClock.new()
	clock.restart_turn()
	assert_eq(clock.remaining(), Protocol.TURN_TIMEOUT)
	clock.tick(12.0)
	assert_almost_eq(clock.remaining(), Protocol.TURN_TIMEOUT - 12.0, 0.001)
	clock.restart_turn()
	assert_eq(clock.remaining(), Protocol.TURN_TIMEOUT)


func test_host_time_survives_turn_changes():
	# 演出里播到 turn 事件时不能把房主的剩余时间重置成 30 秒
	var clock := TurnClock.new()
	clock.sync_from_host(20.0)
	clock.restart_turn()
	assert_true(clock.has_host_time())
	assert_almost_eq(clock.remaining(), 20.0, 0.001)


func test_display_never_freezes_while_grace_remains():
	# 演出预算略宽于实际动画时,轮到行动者时剩余可能略多于 30 秒:照实显示并持续走动,不能停在 30
	var clock := TurnClock.new()
	clock.sync_from_host(Protocol.TURN_TIMEOUT + 1.5)
	var before := clock.remaining()
	clock.tick(0.5)
	assert_almost_eq(clock.remaining(), before - 0.5, 0.001)
	clock.tick(1.0)
	assert_almost_eq(clock.remaining(), Protocol.TURN_TIMEOUT, 0.001)


func test_newer_host_value_replaces_the_running_countdown():
	# 断线批次:房主改了截止时间,圆环跟着改,不再停在 0 或提前归零
	var clock := TurnClock.new()
	clock.sync_from_host(8.0)
	clock.tick(8.0)
	assert_eq(clock.remaining(), 0.0)
	clock.sync_from_host(Protocol.TURN_TIMEOUT + 1.2)
	assert_almost_eq(clock.remaining(), Protocol.TURN_TIMEOUT + 1.2, 0.001)


func test_never_counts_below_zero():
	var clock := TurnClock.new()
	clock.sync_from_host(3.0)
	clock.tick(5.0)
	assert_eq(clock.remaining(), 0.0)
	clock.tick(1.0)
	assert_eq(clock.remaining(), 0.0)


func test_accepts_integer_seconds():
	var clock := TurnClock.new()
	clock.sync_from_host(25)
	assert_true(clock.has_host_time())
	assert_almost_eq(clock.remaining(), 25.0, 0.001)


func test_ignores_missing_or_malformed_host_values():
	for bad in [-1.0, -0.5, "12", null, NAN, INF, -INF, [3.0]]:
		var clock := TurnClock.new()
		clock.sync_from_host(bad)
		assert_false(clock.has_host_time(), "应忽略 %s" % str(bad))
		clock.restart_turn()
		assert_eq(clock.remaining(), Protocol.TURN_TIMEOUT, "应退回本地计时:%s" % str(bad))


func test_bad_value_after_a_good_one_keeps_the_host_countdown():
	var clock := TurnClock.new()
	clock.sync_from_host(17.0)
	clock.sync_from_host("garbage")
	clock.restart_turn()
	assert_almost_eq(clock.remaining(), 17.0, 0.001)
