extends GutTest
# Discovery._broadcast_once 的健康判定:只有必定在本链路上的目标(全局广播、每块网卡最窄的子网推测)
# 发送成功才算"到了局域网";回环和经网关转发的宽前缀推测地址都不算。用桩替换 _send,不发真实报文。


const DiscoveryScript := preload("res://src/net/discovery.gd")


class StubDiscovery:
	extends "res://src/net/discovery.gd"
	# ok_targets:哪些目标地址"发送成功";其余返回失败
	var ok_targets: Array = []
	var sent: Array = []

	func _send(target: String, _port: int, _payload: PackedByteArray) -> Error:
		sent.append(target)
		return OK if ok_targets.has(target) else FAILED


var discovery: StubDiscovery


func before_each():
	discovery = StubDiscovery.new()
	add_child_autofree(discovery)
	discovery._sender = PacketPeerUDP.new()
	# 报文桩按 NetworkManager._room_announcement 的样子写(v4 字段 seated/cap/mode/playing,旧字段 max 压在 4 以内)
	discovery._announce = func(): return {"id": "t", "room": "测试", "host": "甲",
		"players": 1, "max": Protocol.LEGACY_MAX_PLAYERS,
		"seated": 1, "cap": GameMode.max_players(GameMode.LIARS), "mode": GameMode.LIARS, "playing": false,
		"version": Protocol.VERSION, "port": Protocol.GAME_PORT, "open": true}


func _tick(times: int) -> void:
	for i in times:
		discovery._broadcast_once()


func test_stub_announcement_is_a_packet_this_build_would_accept():
	# 桩不能和真报文脱节:本机 RoomList 得认它
	var decoded: Dictionary = RoomList.decode(RoomList.encode(discovery._announce.call()))
	assert_eq(decoded.get("mode"), GameMode.LIARS)
	assert_eq([decoded.get("seated"), decoded.get("cap")], [1, GameMode.max_players(GameMode.LIARS)])


func test_only_loopback_succeeding_turns_unhealthy():
	# macOS 未授权本地网络:只有 127.0.0.1 发得出去
	discovery.ok_targets = [Lan.LOOPBACK]
	_tick(DiscoveryScript.BROADCAST_FAIL_TICKS)
	assert_false(discovery.is_broadcast_healthy())
	assert_has(discovery.sent, Lan.LOOPBACK, "回环照常发送,同机实例还要靠它发现房间")


func test_router_forwarded_wide_guesses_do_not_count_as_healthy():
	# 宽前缀推测地址(如 192.168.255.255)会被当单播交给网关,"发送成功"不代表局域网收到
	var addresses := Array(IP.get_local_addresses())
	var wide := []
	for target in Lan.broadcast_targets(addresses):
		if target != Lan.LOOPBACK and not Lan.health_targets(addresses).has(target):
			wide.append(target)
	if wide.is_empty():
		pass_test("本机没有可供推测的私网地址,无宽前缀目标可测")
		return
	discovery.ok_targets = wide + [Lan.LOOPBACK]
	_tick(DiscoveryScript.BROADCAST_FAIL_TICKS)
	assert_false(discovery.is_broadcast_healthy())


func test_global_broadcast_success_keeps_healthy_and_recovers():
	discovery.ok_targets = [Lan.LOOPBACK]
	_tick(DiscoveryScript.BROADCAST_FAIL_TICKS)
	assert_false(discovery.is_broadcast_healthy())
	watch_signals(discovery)
	discovery.ok_targets = [Lan.GLOBAL_BROADCAST, Lan.LOOPBACK]
	_tick(1)
	assert_true(discovery.is_broadcast_healthy(), "一次成功立即恢复")
	assert_signal_emitted_with_parameters(discovery, "broadcast_health_changed", [true])
