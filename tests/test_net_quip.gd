extends GutTest
# 快捷对话的房主端(离线 NetworkManager,经 _handle_quip):对局中的成员才能说,编号先校验,
# 每人限速;通过的广播给所有成员(含说话人自己),房主本机发 quip_shown 信号。


const HOST := LobbyModel.HOST_ID
const GUESTS := [10, 11]


class StubNet:
	extends "res://src/net/network_manager.gd"
	var sent: Array = []

	func _send_to(id: int, method: StringName, args: Array = []) -> void:
		sent.append([id, String(method), args])


var net: StubNet
var shown: Array = []


func before_each():
	net = StubNet.new()
	add_child_autofree(net)
	net.quip_shown.connect(func(pid: int, index: int) -> void: shown.append([pid, index]))
	shown = []


func after_each():
	if multiplayer.multiplayer_peer == null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _start() -> void:
	net.is_host = true
	net._session_active = true
	net.game_mode = GameMode.LIARS
	var lobby := LobbyModel.new()
	lobby.add_host("房主")
	for id in GUESTS:
		lobby.add_member(id, "客%d" % id)
		lobby.set_ready(id, true)
	net._lobby = lobby
	net.start_game()
	net.sent = []


func _quips_sent() -> Array:
	return net.sent.filter(func(s: Array) -> bool: return s[1] == "rpc_quip_shown")


func test_a_member_quip_reaches_everyone():
	_start()
	net._handle_quip(10, 3)
	assert_eq(shown, [[10, 3]], "房主本机也看到")
	assert_eq(_quips_sent(), [[10, "rpc_quip_shown", [10, 3]], [11, "rpc_quip_shown", [10, 3]]], "含说话人自己")


func test_bad_indices_strangers_and_lobby_time_are_ignored():
	net._handle_quip(10, 1)
	assert_eq(shown, [], "不在对局中")
	_start()
	for bad in [9, -1, "1", 1.5, null, [1]]:
		net._handle_quip(10, bad)
	net._handle_quip(77, 1)
	assert_eq(shown, [])
	assert_eq(_quips_sent(), [])


func test_spam_is_dropped_on_the_host():
	_start()
	net._handle_quip(10, 0)
	net._handle_quip(10, 1)
	net._handle_quip(11, 2)
	assert_eq(shown, [[10, 0], [11, 2]], "同一人冷却中的第二条丢掉")


func test_host_speaks_through_the_same_path():
	_start()
	net.send_quip(4)
	assert_eq(shown, [[HOST, 4]])
	assert_eq(_quips_sent().size(), GUESTS.size())


func test_client_ignores_malformed_relays():
	net.in_game = true
	net.rpc_quip_shown(10, 99)
	net.rpc_quip_shown("x", 1)
	assert_eq(shown, [])
	net.rpc_quip_shown(10, 1)
	assert_eq(shown, [[10, 1]])
