extends GutTest
# 玩法接入的网络部分(离线 NetworkManager,不是 Net 自动加载;不开端口、不发广播):
# 发现报文的玩法与人数字段、旧版本能否看到房间、加入准入、等待厅 meta 里的玩法。


const RoomListTest := preload("res://tests/test_room_list.gd")


class StubNet:
	extends "res://src/net/network_manager.gd"
	# late:德州会话是否正在接受中途入座(真实值由网络会话给出);sent:经 _send_to 发出的 [id, 方法, 参数]
	var late := false
	var sent: Array = []

	func _accepting_late_join() -> bool:
		return late

	func _send_to(id: int, method: StringName, args: Array = []) -> void:
		sent.append([id, String(method), args])


var net: StubNet


func before_each():
	net = StubNet.new()
	add_child_autofree(net)  # _ready 里创建计时器


func after_each():
	# leave() 把整棵树共用的 multiplayer_peer 置空:换回默认的离线 peer,
	# 否则后面的测试里 Net.my_pid() 之类的调用会报引擎错误
	if multiplayer.multiplayer_peer == null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _host(mode: String, players := 1) -> void:
	# 搭一个房主:等待厅里有 players 人(含房主)
	net.is_host = true
	net._session_active = true
	net.game_mode = mode
	var lobby := LobbyModel.new()
	lobby.add_host("房主")
	for i in players - 1:
		lobby.add_member(10 + i, "客%d" % i)
	net._lobby = lobby


func test_poker_announcement_keeps_legacy_fields_in_v3_range():
	_host(GameMode.SHORT_DECK, 6)
	var info: Dictionary = net._room_announcement()
	assert_eq(info["mode"], GameMode.SHORT_DECK)
	assert_eq(info["cap"], 8)
	assert_eq(info["seated"], 6)
	assert_eq(info["max"], Protocol.LEGACY_MAX_PLAYERS)
	assert_eq(info["players"], Protocol.LEGACY_MAX_PLAYERS)
	assert_true(info["open"])
	assert_false(info["playing"])


func test_liars_announcement_reports_its_own_cap():
	_host(GameMode.LIARS, 3)
	var info: Dictionary = net._room_announcement()
	assert_eq(info["mode"], GameMode.LIARS)
	assert_eq([info["seated"], info["cap"], info["players"], info["max"]], [3, 4, 3, 4])
	assert_true(info["open"])


func test_announcements_pass_the_released_v3_rules_and_decode_to_the_real_counts():
	for mode in GameMode.ALL:
		for players in range(1, GameMode.max_players(mode) + 1):
			_host(mode, players)
			var bytes := RoomList.encode(net._room_announcement())
			assert_true(RoomListTest.v3_accepts(bytes), "%s %d 人" % [mode, players])
			var decoded := RoomList.decode(bytes)
			assert_eq([decoded.get("seated"), decoded.get("cap")], [players, GameMode.max_players(mode)])
			assert_true(decoded.get("compatible"), mode)


func test_full_room_is_not_open():
	_host(GameMode.HOLDEM, 8)
	assert_false(net._room_announcement()["open"])
	_host(GameMode.LIARS, 4)
	assert_false(net._room_announcement()["open"])


func test_match_in_progress_is_open_only_while_seating_late_joiners():
	_host(GameMode.HOLDEM, 3)
	net.in_game = true
	net.late = true
	var seating: Dictionary = net._room_announcement()
	assert_true(seating["playing"])
	assert_true(seating["open"], "德州对局中还有空位:列表里显示「入座」")
	net.late = false
	assert_false(net._room_announcement()["open"], "散局中或已结算")
	_host(GameMode.LIARS, 2)
	net.in_game = true
	assert_false(net._room_announcement()["open"])
	assert_true(net._room_announcement()["playing"])


# —— 开房 ——

func test_open_room_takes_the_chosen_mode():
	net._open_room("房主", "老王的牌局", Protocol.GAME_PORT, GameMode.HOLDEM)
	assert_eq(net.game_mode, GameMode.HOLDEM)
	assert_eq(net.max_players(), GameMode.max_players(GameMode.HOLDEM))
	var info: Dictionary = net._room_announcement()
	assert_eq([info["mode"], info["seated"], info["cap"], info["room"]], [GameMode.HOLDEM, 1, 8, "老王的牌局"])


func test_host_game_refuses_an_unknown_mode():
	assert_eq(net.host_game("房主", "房间", 0, "mahjong"), ERR_INVALID_PARAMETER)
	assert_push_error("mahjong")
	assert_false(net.is_host)
	assert_eq(net.game_mode, GameMode.DEFAULT)


func test_leave_resets_the_mode():
	net._open_room("房主", "房间", Protocol.GAME_PORT, GameMode.SHORT_DECK)
	net.leave()
	assert_eq(net.game_mode, GameMode.DEFAULT)


# —— 等待厅 meta 里的玩法 ——

func test_lobby_meta_carries_the_mode():
	net._open_room("房主", "房间", Protocol.GAME_PORT, GameMode.SHORT_DECK)
	net._broadcast_lobby()
	assert_eq(net.lobby_meta.get("mode"), GameMode.SHORT_DECK)


func test_client_takes_a_valid_mode_from_the_lobby_meta_and_ignores_junk():
	var players := [{"pid": 1, "name": "房主", "ready": true, "is_host": true}]
	net.rpc_lobby_state(players, {"room": "房间", "mode": GameMode.HOLDEM})
	assert_eq(net.game_mode, GameMode.HOLDEM)
	for junk in [{"mode": "mahjong"}, {"mode": 7}, {"mode": null}, {}]:
		net.rpc_lobby_state(players, junk)
		assert_eq(net.game_mode, GameMode.HOLDEM, str(junk))


# —— 加入准入(房主) ——

func _sent_to(id: int) -> Array:
	return net.sent.filter(func(entry: Array) -> bool: return entry[0] == id)


func _methods_sent_to(id: int) -> Array:
	return _sent_to(id).map(func(entry: Array) -> String: return entry[1])


func test_join_request_is_accepted_into_the_lobby():
	_host(GameMode.LIARS)
	net._handle_join_request(20, "新人", Protocol.VERSION)
	assert_true(net._lobby.has(20))
	assert_eq(_methods_sent_to(20), ["rpc_join_accepted", "rpc_lobby_state"], "先告诉他获准,再发名单")
	assert_eq(_sent_to(20)[0][2], [{"in_game": false, "mode": GameMode.LIARS}])
	assert_eq(net.lobby_players.size(), 2, "名单广播出去了")


func test_acceptance_tells_the_client_the_mode():
	# 等待厅一进来就要按玩法摆桌,名单(带 meta)比获准晚到
	for mode in GameMode.ALL:
		_host(mode)
		net.sent = []
		net._handle_join_request(21, "新人", Protocol.VERSION)
		assert_eq(_sent_to(21)[0][2] if not _sent_to(21).is_empty() else [], [{"in_game": false, "mode": mode}], mode)


func test_join_request_denials_keep_the_lobby_unchanged():
	var cases := [
		[GameMode.LIARS, 1, false, Protocol.VERSION - 1, "版本"],
		[GameMode.HOLDEM, 8, false, Protocol.VERSION, "已满"],
		[GameMode.LIARS, 2, true, Protocol.VERSION, "已开始"],
		[GameMode.SHORT_DECK, 2, true, Protocol.VERSION, "散局"],
	]
	for c in cases:
		_host(c[0], c[1])
		net.in_game = c[2]
		net.sent = []
		net._handle_join_request(40, "来客", c[3])
		assert_false(net._lobby.has(40), str(c))
		var replies := _sent_to(40)
		assert_eq(replies.size(), 1, str(c))
		assert_eq(replies[0][1] if not replies.is_empty() else "", "rpc_join_denied", str(c))
		assert_string_contains(replies[0][2][0] if not replies.is_empty() else "", c[4], str(c))
	net.in_game = false


func test_running_poker_table_accepts_and_flags_the_late_joiner():
	_host(GameMode.HOLDEM, 3)
	net.in_game = true
	net.late = true
	net._handle_join_request(50, "迟到", Protocol.VERSION)
	assert_true(net._lobby.has(50))
	assert_eq(_methods_sent_to(50).front(), "rpc_join_accepted")
	assert_eq(_sent_to(50)[0][2], [{"in_game": true, "mode": GameMode.HOLDEM}], "客户端据此保持「加入中」,等牌局信息")
	net.in_game = false


func test_repeated_or_misdirected_requests_are_ignored():
	_host(GameMode.LIARS, 2)
	net._handle_join_request(10, "客0", Protocol.VERSION)
	assert_eq(net.sent, [], "已在名单里的人再发一次请求")
	net.is_host = false
	net._handle_join_request(60, "某人", Protocol.VERSION)
	assert_eq(net.sent, [], "不是房主")


func test_real_send_to_skips_unknown_peers_without_engine_errors():
	# 不用桩:离线时 _is_connected 全为 false,准入与拒绝都走完且不对未知 peer 调 rpc_id
	var real: Node = autofree(preload("res://src/net/network_manager.gd").new())
	add_child(real)
	real.is_host = true
	real._session_active = true
	real._lobby = LobbyModel.new()
	real._lobby.add_host("房主")
	real._handle_join_request(70, "新人", Protocol.VERSION)
	real._handle_join_request(71, "旧版", Protocol.VERSION - 1)
	assert_true(real._lobby.has(70))
	assert_false(real._lobby.has(71))
	assert_engine_error_count(0)


# —— 加入握手(客户端) ——

func _begin_joining() -> void:
	net._joining = true
	net._join_timer.start(Protocol.JOIN_TIMEOUT)
	watch_signals(net)


func test_lobby_join_finishes_on_acceptance():
	_begin_joining()
	net.rpc_join_accepted({"in_game": false, "mode": GameMode.LIARS})
	assert_false(net._joining)
	assert_true(net._join_timer.is_stopped())
	assert_signal_emitted(net, "joined_lobby")


func test_client_knows_the_mode_when_it_enters_the_lobby():
	# 等待厅在 joined_lobby 里建起来、立刻按玩法摆桌:玩法必须在发信号之前写好
	_begin_joining()
	var seen := []
	net.joined_lobby.connect(func(): seen.append(net.game_mode))
	net.rpc_join_accepted({"in_game": false, "mode": GameMode.SHORT_DECK})
	assert_eq(seen, [GameMode.SHORT_DECK])


func test_unknown_mode_in_the_acceptance_is_ignored():
	for junk in [{"mode": "mahjong"}, {"mode": 7}, {"mode": null}, {}]:
		net.game_mode = GameMode.DEFAULT
		_begin_joining()
		net.rpc_join_accepted({"in_game": false}.merged(junk))
		assert_false(net._joining, str(junk))
		assert_eq(net.game_mode, GameMode.DEFAULT, "不认识的玩法不写入:等名单的 meta 再定 %s" % str(junk))


func test_late_joiner_stays_joining_until_the_table_arrives():
	_begin_joining()
	net.rpc_join_accepted({"in_game": true, "mode": GameMode.HOLDEM})
	assert_eq(net.game_mode, GameMode.HOLDEM)
	assert_true(net._joining, "对局中入座:还不算加入完成")
	assert_false(net._join_timer.is_stopped(), "加入计时照走")
	assert_signal_not_emitted(net, "joined_lobby")
	var seats := [{"pid": 1, "name": "房主"}, {"pid": 7, "name": "老王"}]
	net.rpc_game_started(seats, {"mode": GameMode.SHORT_DECK, "late": true})
	assert_false(net._joining)
	assert_true(net._join_timer.is_stopped())
	assert_eq(net.game_mode, GameMode.SHORT_DECK, "发出 game_started 之前玩法已设好")
	assert_true(net.in_game)
	assert_signal_emitted_with_parameters(net, "game_started", [seats])
	assert_signal_not_emitted(net, "joined_lobby", "迟到者直接进牌桌,不经过等待厅")


func test_table_info_before_acceptance_is_ignored():
	# 房主总是先发获准再发牌局信息(可靠有序);没获准就到的牌局信息不能把人带上牌桌
	_begin_joining()
	net.rpc_game_started([{"pid": 1, "name": "房主"}], {"mode": GameMode.HOLDEM, "late": true})
	assert_true(net._joining)
	assert_false(net.in_game)
	assert_signal_not_emitted(net, "game_started")


func test_late_joiner_times_out_when_the_table_never_arrives():
	_begin_joining()
	net.rpc_join_accepted({"in_game": true, "mode": GameMode.HOLDEM})
	net._on_join_timeout()
	assert_false(net._joining)
	assert_signal_emitted_with_parameters(net, "join_failed", ["房主没有发来牌局信息"])


func test_plain_join_timeout_keeps_its_message():
	_begin_joining()
	net._on_join_timeout()
	assert_signal_emitted_with_parameters(net, "join_failed",
		["连接超时:%d 秒内没有收到房主响应" % int(Protocol.JOIN_TIMEOUT)])


func test_malformed_acceptance_is_a_plain_lobby_join():
	_begin_joining()
	net.rpc_join_accepted({"in_game": "yes"})
	assert_false(net._joining)
	assert_signal_emitted(net, "joined_lobby")


func test_game_start_tells_clients_the_mode():
	_host(GameMode.LIARS, 2)
	net._lobby.set_ready(10, true)
	net.start_game()
	var started := _sent_to(10).filter(func(entry: Array) -> bool: return entry[1] == "rpc_game_started")
	assert_eq(started.size(), 1)
	assert_eq(started[0][2][1] if not started.is_empty() else {}, {"mode": GameMode.LIARS, "late": false})
	net.leave()
