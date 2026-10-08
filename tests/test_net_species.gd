extends GutTest
# 自选形象的网络接线(子项目② §3.4/§3.6,离线 NetworkManager,不是 Net 自动加载):
# 客人握手通过后才报形象;房主先到先得地分配,变了广播、被拒单独回一份名单;每个对端 0.25 秒冷却;
# 开局兜底分配,座位表带 species;德州中途入座者也拿到形象。


const HOST := LobbyModel.HOST_ID
const FOX := 0
const BEAR := 1
const PIG := 2
const CROC := 7


class StubNet:
	extends "res://src/net/network_manager.gd"
	# sent:经 _send_to 发出的 [id, 方法, 参数];late:德州会话是否正在接受中途入座
	var sent: Array = []
	var late := false

	func _send_to(id: int, method: StringName, args: Array = []) -> void:
		sent.append([id, String(method), args])

	func _accepting_late_join() -> bool:
		return late


var net: StubNet


func before_each():
	net = StubNet.new()
	add_child_autofree(net)  # _ready 里创建计时器


func after_each():
	if multiplayer.multiplayer_peer == null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


func _host(mode := GameMode.LIARS, host_species := CROC, guests := [10, 11]) -> void:
	net._open_room("房主", "房间", Protocol.GAME_PORT, mode, host_species)
	for id in guests:
		net._handle_join_request(id, "客%d" % id, Protocol.VERSION)
	net.sent = []


func _sent_to(id: int, method := "") -> Array:
	return net.sent.filter(func(entry: Array) -> bool: return entry[0] == id and (method == "" or entry[1] == method))


func _ask(id: int, index: int) -> void:
	# 每次请求之间跳过冷却(冷却本身另有用例)
	net._species_asked_at.erase(id)
	net._handle_species_request(id, index)


func _species() -> Dictionary:
	var out := {}
	for row in net._lobby.view():
		out[row["pid"]] = row["species"]
	return out


# —— 房主 ——

func test_host_takes_the_preferred_species_when_opening_the_room():
	_host(GameMode.LIARS, PIG, [])
	assert_eq(net._lobby.species_of(HOST), PIG)
	assert_eq(net.player_species, PIG)


func test_guests_are_unassigned_until_their_request_arrives():
	_host()
	assert_eq(_species(), {HOST: CROC, 10: Species.UNASSIGNED, 11: Species.UNASSIGNED})


func test_granted_request_is_broadcast_to_every_member():
	_host()
	_ask(10, CROC)   # 房主已经是鳄鱼:分第一个空着的
	_ask(11, CROC)
	assert_eq(_species(), {HOST: CROC, 10: FOX, 11: BEAR}, "按请求到达顺序拿到狐狸、熊")
	for id in [10, 11]:
		assert_eq(_sent_to(id, "rpc_lobby_state").size(), 2, "每次变化都广播")
	assert_eq(net.lobby_players.map(func(p): return p["species"]), [CROC, FOX, BEAR], "房主本机也刷新")


func test_rejected_request_gets_a_lobby_state_reply_only_to_the_requester():
	_host()
	_ask(10, PIG)
	net.sent = []
	_ask(11, PIG)   # 11 还没有形象:分第一个空着的(变了,广播)
	net.sent = []
	_ask(11, PIG)   # 11 已有狐狸,猪被 10 占着:不变
	assert_eq(_species()[11], FOX)
	assert_eq(_sent_to(11, "rpc_lobby_state").size(), 1, "被拒也回一份名单,请求者据此结算")
	assert_eq(_sent_to(10).size(), 0, "别人不收")


func test_requests_inside_the_cooldown_are_rejected():
	_host()
	net._handle_species_request(10, PIG)
	net.sent = []
	net._handle_species_request(10, BEAR)   # 0.25 秒内的第二次
	assert_eq(_species()[10], PIG, "冷却内按被拒处理")
	assert_eq(_sent_to(10, "rpc_lobby_state").size(), 1)
	assert_eq(_sent_to(11).size(), 0, "不广播")


func test_strangers_and_clients_cannot_change_species():
	_host()
	net._handle_species_request(99, PIG)
	assert_eq(net.sent, [], "不在名单里的连接不理")
	net.is_host = false
	net._handle_species_request(10, PIG)
	assert_eq(_species()[10], Species.UNASSIGNED, "只有房主处理")


func test_species_cannot_change_during_a_match():
	_host()
	_ask(10, PIG)
	_ask(11, BEAR)
	net._lobby.set_ready(10, true)
	net._lobby.set_ready(11, true)
	net.start_game()
	net.sent = []
	_ask(10, FOX)
	assert_eq(_species()[10], PIG)
	assert_eq(net.sent, [], "对局中没有挑选入口")


func test_leaving_frees_the_species_for_the_next_request():
	_host()
	_ask(10, PIG)
	net._on_peer_disconnected(10)
	_ask(11, PIG)
	assert_eq(_species(), {HOST: CROC, 11: PIG})


func test_host_request_applies_locally_and_refreshes_even_when_rejected():
	_host()
	_ask(10, PIG)
	watch_signals(net)
	net.request_species(BEAR)
	assert_eq(net.player_species, BEAR)
	assert_eq(_species()[HOST], BEAR)
	assert_eq(_sent_to(10, "rpc_lobby_state").size(), 2)
	net.request_species(PIG)   # 被 10 占着
	assert_eq(_species()[HOST], BEAR)
	assert_eq(net.player_species, BEAR, "被拒不改本机偏好")
	assert_signal_emit_count(net, "lobby_updated", 2, "被拒也在本机刷新一次,界面据此结算")


func test_game_start_assigns_the_unassigned_and_seats_carry_species():
	_host(GameMode.LIARS, BEAR)
	_ask(11, BEAR)   # 撞车:狐狸
	net._lobby.set_ready(10, true)
	net._lobby.set_ready(11, true)
	net.start_game()
	assert_eq(net.seats, [{"pid": HOST, "name": "房主", "species": BEAR}, {"pid": 10, "name": "客10", "species": PIG},
		{"pid": 11, "name": "客11", "species": FOX}], "10 的请求没到:开局兜底分第一个空着的")
	var started: Array = _sent_to(10, "rpc_game_started")
	assert_eq(started[0][2][0], net.seats)


func test_poker_late_joiner_gets_a_species_before_his_first_hand():
	_host(GameMode.HOLDEM, CROC, [10])
	_ask(10, FOX)
	net._lobby.set_ready(10, true)
	net.start_game()
	net.late = true
	net.sent = []
	net._handle_join_request(50, "迟到", Protocol.VERSION)
	var started: Array = _sent_to(50, "rpc_game_started")
	assert_eq(started[0][2][0], [{"pid": HOST, "name": "房主", "species": CROC}, {"pid": 10, "name": "客10", "species": FOX}],
		"中途入座的座位表同样带 species")
	_ask(50, FOX)   # 他报上来的首选被占:分第一个空着的
	assert_eq(_species()[50], BEAR, "对局中入座者的第一次请求照样处理")
	_ask(50, PIG)
	assert_eq(_species()[50], BEAR, "已有形象:对局中不能再换")


func test_hand_timer_assigns_late_joiners_whose_request_never_came():
	# 中途入座者等下一手才登场:形象请求一直没到(异常客户端)时,开下一手之前兜底分好并下发名单
	_host(GameMode.HOLDEM, CROC, [10])
	_ask(10, FOX)
	net._lobby.set_ready(10, true)
	net.start_game()
	net.late = true
	net._handle_join_request(50, "迟到", Protocol.VERSION)
	assert_eq(net._lobby.species_of(50), Species.UNASSIGNED)
	while net._session.has_turn():
		net._handle_poker_rpc(net.last_public["current_pid"], PokerRules.FOLD, 0)
	net.sent = []
	net._on_hand_timer()
	assert_eq(net._lobby.species_of(50), BEAR)
	assert_eq(_sent_to(10, "rpc_lobby_state").size(), 1, "名单随之下发:各端据此给他建酒客")


# —— 客人 ——

func _begin_joining(species := PIG) -> void:
	net.player_name = "客"
	net.player_species = species
	net._session_active = true
	net._joining = true
	net._join_timer.start(Protocol.JOIN_TIMEOUT)


func test_client_reports_its_species_right_after_acceptance_before_entering_the_lobby():
	_begin_joining(CROC)
	var sent_before_lobby := []
	net.joined_lobby.connect(func(): sent_before_lobby.append(net.sent.duplicate()))
	net.rpc_join_accepted({"in_game": false, "mode": GameMode.LIARS})
	assert_eq(sent_before_lobby, [[[HOST, "rpc_lobby_species", [CROC]]]])


func test_late_joiner_reports_its_species_too():
	_begin_joining(FOX)
	net.rpc_join_accepted({"in_game": true, "mode": GameMode.HOLDEM})
	assert_eq(net.sent, [[HOST, "rpc_lobby_species", [FOX]]])


func test_client_request_goes_to_the_host_and_a_grant_updates_the_preference():
	_begin_joining(PIG)
	net.rpc_join_accepted({"in_game": false, "mode": GameMode.LIARS})
	net.sent = []
	net.request_species(CROC)
	assert_eq(net.sent, [[HOST, "rpc_lobby_species", [CROC]]])
	var me := net.my_pid()
	net.rpc_lobby_state([{"pid": HOST, "name": "房主", "ready": true, "is_host": true, "species": FOX},
		{"pid": me, "name": "客", "ready": false, "is_host": false, "species": PIG}], {})
	assert_eq(net.player_species, PIG, "无关的名单不算批准")
	net.rpc_lobby_state([{"pid": HOST, "name": "房主", "ready": true, "is_host": true, "species": FOX},
		{"pid": me, "name": "客", "ready": false, "is_host": false, "species": CROC}], {})
	assert_eq(net.player_species, CROC, "房主批下后成为之后加入时报的形象")


func test_species_lookup_prefers_seats_then_the_lobby_and_rejects_junk():
	net.seats = [{"pid": 1, "name": "房主", "species": CROC}, {"pid": 5, "name": "乙", "species": "fox"}]
	net.lobby_players = [{"pid": 5, "species": 99}, {"pid": 9, "species": PIG}]
	assert_eq(net.species_of(1), CROC)
	assert_eq(net.species_of(5), Species.UNASSIGNED, "非法值都当没有")
	assert_eq(net.species_of(9), PIG, "对局中入座者的形象来自名单")
	assert_eq(net.species_of(42), Species.UNASSIGNED)
	assert_eq(net.patron_entries([9, 1]), [{"pid": 9, "species": PIG}, {"pid": 1, "species": CROC}])
