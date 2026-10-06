extends GutTest
# Discovery:广播健康度(连续几轮发不出去才报警,恢复立即报告)与按 owner 的监听开关。
# 不调用 start_broadcast:那会向真实局域网发房间报文。


const DiscoveryScript := preload("res://src/net/discovery.gd")

var discovery: Node


func before_each():
	discovery = DiscoveryScript.new()
	add_child_autofree(discovery)


func _fail_ticks(count: int) -> void:
	for i in count:
		discovery._record_tick(false)


func test_broadcast_starts_healthy():
	assert_true(discovery.is_broadcast_healthy())


func test_unhealthy_only_after_consecutive_failed_ticks():
	watch_signals(discovery)
	_fail_ticks(DiscoveryScript.BROADCAST_FAIL_TICKS - 1)
	assert_true(discovery.is_broadcast_healthy())
	assert_signal_not_emitted(discovery, "broadcast_health_changed")
	_fail_ticks(1)
	assert_false(discovery.is_broadcast_healthy())
	assert_signal_emitted_with_parameters(discovery, "broadcast_health_changed", [false])


func test_failure_is_reported_once():
	watch_signals(discovery)
	_fail_ticks(DiscoveryScript.BROADCAST_FAIL_TICKS + 4)
	assert_signal_emit_count(discovery, "broadcast_health_changed", 1)


func test_one_successful_tick_recovers():
	_fail_ticks(DiscoveryScript.BROADCAST_FAIL_TICKS)
	watch_signals(discovery)
	discovery._record_tick(true)
	assert_true(discovery.is_broadcast_healthy())
	assert_signal_emitted_with_parameters(discovery, "broadcast_health_changed", [true])


func test_a_success_resets_the_failure_streak():
	_fail_ticks(DiscoveryScript.BROADCAST_FAIL_TICKS - 1)
	discovery._record_tick(true)
	_fail_ticks(DiscoveryScript.BROADCAST_FAIL_TICKS - 1)
	assert_true(discovery.is_broadcast_healthy())


func test_stopping_the_broadcast_resets_health():
	_fail_ticks(DiscoveryScript.BROADCAST_FAIL_TICKS)
	discovery.stop_broadcast()
	assert_true(discovery.is_broadcast_healthy())


func test_stop_from_a_stale_owner_is_ignored():
	var old_menu: Node = autofree(Node.new())
	var new_menu: Node = autofree(Node.new())
	var listening: bool = discovery.start_listening(new_menu)
	discovery.stop_listening(old_menu)
	assert_eq(discovery.is_listening(), listening, "旧菜单迟到的 stop 不能关掉新菜单的监听")
	discovery.stop_listening(new_menu)
	assert_false(discovery.is_listening())


func test_stop_without_owner_always_stops():
	var menu: Node = autofree(Node.new())
	discovery.start_listening(menu)
	discovery.stop_listening()
	assert_false(discovery.is_listening())
