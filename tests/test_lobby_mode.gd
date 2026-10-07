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
