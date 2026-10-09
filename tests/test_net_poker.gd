extends GutTest
# 德州的房主端接线(离线 NetworkManager,不是 Net 自动加载;经 _handle_join_request / _handle_poker_rpc /
# _on_hand_timer 等内部函数):开局计时、一手间隔排期、输光选择时间、旁人再领的预算、挂机离座、
# 中途加入的完整顺序、断线、散局与回等待厅。规格 §7 的「不卡住」在每批事件之后检查。


const H := preload("res://tests/poker_helpers.gd")
const R := preload("res://src/core/poker/poker_rules.gd")
const EPS := 0.05
const HOST := LobbyModel.HOST_ID
const GUESTS := [10, 11]


class StubNet:
	extends "res://src/net/network_manager.gd"
	# sent:经 _send_to 发出的 [id, 方法, 参数]
	var sent: Array = []

	func _send_to(id: int, method: StringName, args: Array = []) -> void:
		sent.append([id, String(method), args])


var net: StubNet
var _events: Array = []   # 房主自己收到的最近一批事件(game_events 信号)


func before_each():
	net = StubNet.new()
	add_child_autofree(net)  # _ready 里创建计时器
	net.game_events.connect(func(events: Array) -> void: _events = events)


func after_each():
	# leave() 把整棵树共用的 multiplayer_peer 置空:换回默认的离线 peer
	if multiplayer.multiplayer_peer == null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()


# —— 搭台 ——

func _start(mode := GameMode.HOLDEM) -> void:
	net.is_host = true
	net._session_active = true
	net.game_mode = mode
	var lobby := LobbyModel.new()
	lobby.add_host("房主")
	for id in GUESTS:
		lobby.add_member(id, "客%d" % id)
		lobby.set_ready(id, true)
	net._lobby = lobby
	net.start_game()
	net.sent = []


func _table() -> PokerTable:
	return net._session._table


func _current() -> int:
	return net.last_public["current_pid"]


func _act(pid: int, action: String, amount := 0) -> void:
	net._handle_poker_rpc(pid, action, amount)


func _fold_out() -> void:
	while net._session.has_turn():
		_act(_current(), R.FOLD)
	_assert_live()


func _next_hand() -> Dictionary:
	# 一手间隔到点:开下一手,返回 hand_started
	assert_false(net._hand_timer.is_stopped(), "下一手应该已排期")
	net.sent = []
	net._on_hand_timer()
	_assert_live()
	return H.find(_events, "hand_started")


func _bust_host() -> void:
	_bust(HOST)


func _bust(loser: int) -> void:
	# 下一手:按钮 loser(先说话)、只有 20 拿 72 全下,下家拿 AA 跟注,第三人弃牌 → loser 输光
	var order := [HOST, GUESTS[0], GUESTS[1]]
	var i := order.find(loser)
	var winner: int = order[(i + 1) % order.size()]
	var folder: int = order[(i + 2) % order.size()]
	_table().button_pid = folder   # 按钮下一手移到他的下家:loser
	_table().rigged = {"holes": {loser: H.cards("7c 2d"), winner: H.cards("Ah Ad")}, "board": H.cards("8c 6h 4d Jc 3s"), "stacks": {loser: 20}}
	_next_hand()
	for step in [[loser, R.ALLIN], [winner, R.CALL], [folder, R.FOLD]]:
		assert_eq(_current(), step[0])
		_act(step[0], step[1])
	assert_eq(_status(loser), R.STATUS_BUSTED)
	_assert_live()


func _sorted(values: Array) -> Array:
	var out := values.duplicate()
	out.sort()
	return out


func _status(pid: int) -> String:
	for p in net.last_public["players"]:
		if p["pid"] == pid:
			return p["status"]
	return ""


func _sent_to(id: int) -> Array:
	return net.sent.filter(func(entry: Array) -> bool: return entry[0] == id)


func _methods_sent_to(id: int) -> Array:
	return _sent_to(id).map(func(entry: Array) -> String: return entry[1])


func _events_sent_to(id: int) -> Array:
	var events := []
	for entry in _sent_to(id):
		if entry[1] == "rpc_game_events":
			events.append_array(entry[2][0])
	return events


func _assert_live() -> void:
	# 规格 §7:每批事件之后要么有人在计时行动,要么一手间隔计时器在走,要么牌桌在等人,要么已散局
	var s = net._session
	if s == null or s.is_over():
		assert_true(net._turn_timer.is_stopped() and net._hand_timer.is_stopped(), "散局后计时器都停")
	elif s.has_turn():
		assert_false(net._turn_timer.is_stopped(), "有人在行动就得在计时")
		assert_true(net._hand_timer.is_stopped())
	elif s.next_hand_ready():
		assert_false(net._hand_timer.is_stopped(), "两手之间就得排期")
		assert_true(net._turn_timer.is_stopped())
	else:
		assert_true(net._turn_timer.is_stopped() and net._hand_timer.is_stopped(), "等人时不计时")
	assert_almost_eq(net.last_public["turn_time_left"], net._turn_time_left(), EPS)


# —— 开局与一手间隔 ——

func test_poker_start_schedules_the_first_turn_after_the_intro():
	net.is_host = true
	net._session_active = true
	net.game_mode = GameMode.SHORT_DECK
	var lobby := LobbyModel.new()
	lobby.add_host("房主")
	for id in GUESTS:
		lobby.add_member(id, "客%d" % id)
		lobby.set_ready(id, true)
	net._lobby = lobby
	watch_signals(net)
	net.start_game()
	assert_eq(_methods_sent_to(10), ["rpc_game_started", "rpc_game_events", "rpc_state_public", "rpc_state_private"])
	assert_eq(_sent_to(10)[0][2][1], {"mode": GameMode.SHORT_DECK, "late": false})
	assert_eq(net.seats, [{"pid": 1, "name": "房主", "species": 0}, {"pid": 10, "name": "客10", "species": 1},
		{"pid": 11, "name": "客11", "species": 2}])
	var events := _events_sent_to(10)
	assert_eq(events[0]["type"], "hand_started")
	var expected := Protocol.TURN_TIMEOUT + PokerPacing.INTRO + PokerPacing.estimate(events)
	assert_almost_eq(net._turn_timer.time_left, expected, EPS, "第一回合 = 开场运镜 + 发牌演出 + 30 秒")
	assert_almost_eq(net.last_public["turn_time_left"], expected, EPS)
	assert_eq(net.last_public["mode"], GameMode.SHORT_DECK)
	assert_eq(net.last_private["hole"].size(), 2, "房主自己的私有视图")
	assert_true(net._hand_timer.is_stopped())
	assert_signal_emitted(net, "game_started")
	_assert_live()


func _confirm(pids: Array) -> void:
	# 这些人点「开始下一手」
	for pid in pids:
		_act(pid, R.NEXT)
		_assert_live()


func test_next_hand_waits_for_everyone_to_press_start_or_thirty_seconds():
	_start()
	_fold_out()
	assert_true(net._turn_timer.is_stopped())
	var deadline: float = net._hand_timer.time_left
	assert_almost_eq(deadline, net._anim_left + PokerPacing.NEXT_HAND_TIMEOUT, EPS, "演完后最多等 15 秒")
	assert_eq(net.last_public["phase"], "idle")
	_confirm([HOST, GUESTS[0]])
	assert_almost_eq(net._hand_timer.time_left, deadline, EPS, "还有人没点:照旧等")
	assert_true(_events.back()["type"] == "next_ready")
	_confirm([GUESTS[1]])
	assert_almost_eq(net._hand_timer.time_left, net._anim_left + PokerPacing.HAND_GAP, EPS, "都点了:演完稍停就开")
	var started := _next_hand()
	assert_eq(started["hand"], 2)
	assert_eq(net.last_public["hand"], 2)
	assert_true(net._hand_timer.is_stopped())
	assert_almost_eq(net._turn_timer.time_left, net._anim_left + Protocol.TURN_TIMEOUT, EPS)


func test_nobody_pressing_start_still_deals_after_the_timeout():
	_start()
	_fold_out()
	var started := _next_hand()
	assert_eq(started["hand"], 2, "15 秒到了自动开(等于替大家点了开始)")
	assert_eq(_sorted(started["dealt"]), _sorted([HOST] + GUESTS))


func test_start_is_rejected_during_a_hand():
	_start()
	net.sent = []
	_act(GUESTS[0], R.NEXT)
	assert_eq(_methods_sent_to(GUESTS[0]), ["rpc_intent_rejected"])


func test_hand_timer_does_nothing_without_a_table_to_deal():
	net._on_hand_timer()
	assert_eq(net.sent, [])
	_start()
	net.sent = []
	net._on_hand_timer()
	assert_eq(net.sent, [], "手牌进行中不会再开一手")


# —— 输光的选择时间 ——

func test_a_bust_player_rebuying_counts_as_pressing_start():
	_start()
	_fold_out()
	_bust_host()
	var before: float = net._hand_timer.time_left
	assert_almost_eq(before, net._anim_left + PokerPacing.NEXT_HAND_TIMEOUT, EPS)
	_confirm(GUESTS)
	assert_almost_eq(net._hand_timer.time_left, before, EPS, "还在等输光的人选")
	net.request_rebuy()
	assert_eq(_status(HOST), R.STATUS_WAITING)
	assert_almost_eq(net._hand_timer.time_left, net._anim_left + PokerPacing.HAND_GAP, EPS, "再领就是开始")
	assert_has(_next_hand()["dealt"], HOST, "再领后下一手发牌")


func test_undecided_bust_does_not_block_the_next_hand():
	_start()
	_fold_out()
	_bust_host()
	var started := _next_hand()
	assert_eq(_sorted(started["dealt"]), GUESTS)
	assert_eq(_status(HOST), R.STATUS_BUSTED, "没选就不发牌,牌局照常")


func test_choosing_to_spectate_means_nobody_waits_for_you():
	_start()
	_fold_out()
	_bust_host()
	_confirm(GUESTS)
	var before: float = net._hand_timer.time_left
	net.request_spectate()
	assert_eq(_status(HOST), R.STATUS_SPECTATING)
	assert_lte(net._hand_timer.time_left, before, "只会提前")
	assert_almost_eq(net._hand_timer.time_left, net._anim_left + PokerPacing.HAND_GAP, EPS)
	assert_eq(_sorted(_next_hand()["dealt"]), GUESTS)


func test_pressing_start_late_keeps_the_shorter_remaining_wait():
	_start()
	_fold_out()
	var before: float = net._hand_timer.time_left
	net._process(3.0)
	_confirm([HOST] + GUESTS)
	assert_lt(net._hand_timer.time_left, before - 3.0, "剩下的等待比原计划短")
	assert_almost_eq(net._hand_timer.time_left, net._anim_left + PokerPacing.HAND_GAP, EPS)


func test_a_player_leaving_while_others_wait_brings_the_hand_forward():
	_start()
	_fold_out()
	_bust(10)
	_confirm([HOST, 11])
	assert_almost_eq(net._hand_timer.time_left, net._anim_left + PokerPacing.NEXT_HAND_TIMEOUT, EPS)
	net._on_peer_disconnected(10)
	assert_false(net._lobby.has(10))
	assert_eq(_events.back()["type"], "player_left")
	assert_almost_eq(net._hand_timer.time_left, net._anim_left + PokerPacing.HAND_GAP, EPS, "没确认的人走了就不用再等")
	_assert_live()
	assert_eq(_sorted(_next_hand()["dealt"]), [HOST, 11])


# —— 旁人再领 ——

func test_rebuy_during_someone_elses_turn_only_adds_the_rebuy_budget():
	_start()
	_fold_out()
	_bust_host()
	_next_hand()
	var before: float = net._turn_timer.time_left
	net.request_rebuy()
	assert_almost_eq(net._turn_timer.time_left, before + PokerPacing.REBUY, EPS, "行动者的时间只补上再领演出")
	assert_true(net._hand_timer.is_stopped())
	assert_eq(_events_sent_to(10).back()["type"], "rebuy")
	_assert_live()


func test_rebuy_during_the_hand_gap_never_shortens_the_gap():
	_start()
	_fold_out()
	_bust_host()
	net.request_spectate()
	_next_hand()
	_fold_out()
	var before: float = net._hand_timer.time_left
	net.request_rebuy()
	assert_almost_eq(net._hand_timer.time_left, before, EPS, "间隔里再领:下一手既不提前也不推迟")
	assert_has(_next_hand()["dealt"], HOST)


# —— 挂机离座 ——

func test_two_timeouts_in_a_row_send_the_player_away_and_sit_in_brings_him_back():
	_start()
	_fold_out()
	_table().button_pid = GUESTS[1]    # 下一手:按钮房主、小盲 10、大盲 11,房主先说话
	_next_hand()
	assert_eq(_current(), HOST)
	net._on_turn_timeout()
	assert_almost_eq(net._anim_left, PokerPacing.ACTION, EPS, "超时代打按消耗回合处理:演出欠账清零")
	assert_almost_eq(net._turn_timer.time_left, PokerPacing.ACTION + Protocol.TURN_TIMEOUT, EPS)
	_fold_out()
	_next_hand()                       # 按钮 10、小盲 11、大盲房主:10 先说话
	_act(10, R.RAISE, 60)
	_act(11, R.FOLD)
	assert_eq(_current(), HOST)
	net.sent = []
	net._on_turn_timeout()
	assert_eq(_events_sent_to(10).back(), {"type": "away", "pid": HOST})
	assert_eq(_status(HOST), R.STATUS_AWAY)
	_assert_live()
	assert_eq(_sorted(_next_hand()["dealt"]), GUESTS, "离座的人不发牌")
	var before: float = net._turn_timer.time_left
	net.request_sit_in()
	assert_eq(_status(HOST), R.STATUS_WAITING)
	assert_almost_eq(net._turn_timer.time_left, before, EPS, "回座不占演出时间")
	_fold_out()
	assert_has(_next_hand()["dealt"], HOST)


func test_acting_once_resets_the_timeout_streak():
	_start()
	_fold_out()
	_table().button_pid = GUESTS[1]
	_next_hand()
	net._on_turn_timeout()             # 房主超时一次
	_fold_out()
	_next_hand()                       # 按钮 10:10 先说话,大盲房主
	_act(10, R.CALL)
	_act(11, R.CALL)
	_act(HOST, R.CHECK)                # 自己行动一次:清零
	_fold_out()
	_next_hand()                       # 按钮 11、小盲房主、大盲 10:11 先说话
	_act(11, R.RAISE, 60)
	net.sent = []
	net._on_turn_timeout()             # 房主又超时一次
	assert_false(H.types(_events_sent_to(10)).has("away"), "清零后只算一次超时")


# —— 中途加入 ——

func test_late_joiner_is_seated_in_the_documented_order_and_dealt_next_hand():
	_start()
	assert_true(net._room_announcement()["open"], "对局中德州房间可入座")
	var before: float = net._turn_timer.time_left
	net._handle_join_request(50, "迟到", Protocol.VERSION)
	assert_eq(_methods_sent_to(50), ["rpc_join_accepted", "rpc_game_started", "rpc_game_events",
		"rpc_state_public", "rpc_state_private", "rpc_lobby_state"])
	assert_eq(_sent_to(50)[0][2], [{"in_game": true, "mode": GameMode.HOLDEM}])
	assert_eq(_sent_to(50)[1][2], [[{"pid": 1, "name": "房主", "species": 0}, {"pid": 10, "name": "客10", "species": 1},
		{"pid": 11, "name": "客11", "species": 2}],
		{"mode": GameMode.HOLDEM, "late": true}], "座位表是当前桌上有酒客的人,不含他自己")
	assert_eq(_events_sent_to(50), [{"type": "player_joined", "pid": 50, "name": "迟到"}])
	assert_eq(_events_sent_to(10), _events_sent_to(50), "全员都收到加入事件")
	assert_eq(net.last_public["players"].back()["name"], "迟到")
	assert_does_not_have(net.last_public["seats"], 50, "本手旁观")
	assert_true(net._lobby.has(50))
	assert_almost_eq(net._turn_timer.time_left, before + PokerPacing.PLAYER_JOINED, EPS, "旁人加入只补演出")
	_assert_live()
	_fold_out()
	var started := _next_hand()
	assert_has(started["dealt"], 50)
	assert_eq(started["seats"], [1, 10, 11, 50], "新人排在座位顺序末尾")
	net.sent = []
	net._relay_gaze(HOST, Vector3.ZERO, Vector3.ZERO, true)
	assert_eq(net.sent.map(func(entry: Array) -> int: return entry[0]), [10, 11, 50], "视线转发对象里有他,不含房主自己")


func test_late_joiner_the_session_refuses_is_denied_and_never_told_the_game_started():
	# 名单放行、会话拒收(同一 peer id 本手里刚离开,引擎要等这一手结束才移出他):
	# 不能发 rpc_game_started 让他以为入了座,要按拒绝处理并撤掉名单项
	_start()
	net._on_peer_disconnected(10)
	assert_false(net._lobby.has(10))
	assert_true(net._session.has_turn(), "牌局照常")
	net.sent = []
	net._handle_join_request(10, "回来", Protocol.VERSION)
	assert_eq(_methods_sent_to(10), ["rpc_join_denied"])
	assert_false(net._lobby.has(10), "会话拒收就不留在名单里")
	assert_eq(net._session.viewers().count(10), 0)
	assert_eq(_table().seat_order().count(10), 1, "本手里离开的他还在桌上定格,没被重复入座")
	_assert_live()


func test_late_joiners_are_refused_while_the_session_is_ending():
	_start()
	net.end_poker_session()
	assert_true(net.last_public["ending"])
	assert_false(net._accepting_late_join())
	assert_false(net._room_announcement()["open"])
	net.sent = []
	net._handle_join_request(50, "迟到", Protocol.VERSION)
	assert_false(net._lobby.has(50))
	assert_eq(_methods_sent_to(50), ["rpc_join_denied"])
	assert_string_contains(_sent_to(50)[0][2][0], "散局")


# —— 断线 ——

func test_actor_disconnect_folds_and_hands_the_turn_on():
	_start()
	var actor := _current()
	var guest: int = actor if actor != HOST else GUESTS[0]
	if guest != actor:
		_act(actor, R.CALL)
		guest = _current()
		if guest == HOST:
			_act(HOST, R.CALL)
			guest = _current()
	net.sent = []
	net._on_peer_disconnected(guest)
	var types := H.types(_events_sent_to(GUESTS.filter(func(id: int) -> bool: return id != guest)[0]))
	assert_eq(types[0], "player_left")
	assert_has(types, "turn", "行动继续")
	assert_ne(_current(), guest)
	assert_false(net._lobby.has(guest))
	assert_false(net._turn_timer.is_stopped())
	_assert_live()


func test_disconnects_down_to_one_player_leave_the_table_waiting():
	_start()
	net._on_peer_disconnected(10)
	net._on_peer_disconnected(11)
	assert_eq(net.last_public["phase"], "idle", "只剩一人:这一手结束")
	assert_false(net._session.next_hand_ready())
	assert_true(net._hand_timer.is_stopped(), "凑不够人不排期")
	assert_true(net._turn_timer.is_stopped())
	_assert_live()
	net._handle_join_request(50, "迟到", Protocol.VERSION)
	assert_false(net._hand_timer.is_stopped(), "来了新人就排下一手")
	assert_eq(_next_hand()["dealt"], [1, 50])


func test_leave_stops_the_hand_timer_and_drops_the_session():
	_start()
	_fold_out()
	assert_false(net._hand_timer.is_stopped())
	net.leave()
	assert_true(net._hand_timer.is_stopped())
	assert_true(net._turn_timer.is_stopped())
	assert_eq(net._session, null)
	assert_eq(net.game_mode, GameMode.DEFAULT)


# —— 散局与回等待厅 ——

func test_ending_between_hands_settles_at_once_and_returns_to_the_lobby():
	_start()
	_fold_out()
	watch_signals(net)
	net.end_poker_session()
	var over: Dictionary = _events_sent_to(10).back()
	assert_eq(over["type"], "session_over")
	assert_eq(over["results"].size(), 3)
	assert_eq(over["results"][0].keys(), ["pid", "stack", "buyins", "net", "left", "name"])
	assert_eq(net.last_public["phase"], "over")
	assert_true(net._session.is_over())
	_assert_live()
	net.sent = []
	net.end_poker_session()
	assert_eq(net.sent, [], "已结算:再散局没有事件")
	net.request_rematch_lobby()
	assert_false(net.in_game)
	assert_eq(net._session, null)
	assert_true(net._hand_timer.is_stopped())
	assert_has(_methods_sent_to(10), "rpc_returned_to_lobby")
	assert_signal_emitted(net, "returned_to_lobby")


func test_ending_mid_hand_finishes_the_hand_first():
	_start()
	net.end_poker_session()
	assert_eq(_events_sent_to(10), [{"type": "ending"}])
	assert_true(net._session.is_ending())
	_assert_live()
	net.sent = []
	_fold_out()
	assert_eq(H.types(_events_sent_to(10)).slice(-3), ["hand_over", "hand_record", "session_over"])
	assert_true(net._hand_timer.is_stopped())
	assert_true(net._turn_timer.is_stopped())


func test_only_the_host_in_a_running_game_can_end_the_session():
	net.end_poker_session()
	assert_eq(net.sent, [], "没开局")
	_start()
	net.is_host = false
	net.end_poker_session()
	assert_eq(net.sent, [], "不是房主")
	net.is_host = true


# —— 德州意图的 RPC 校验 ——

func test_poker_rpc_rejects_bad_arguments_and_strangers():
	_start()
	var cases := [[10, "steal", 0, "invalid_action"], [10, R.RAISE, "60", "invalid_amount"],
		[10, R.RAISE, PokerSession.MAX_AMOUNT + 1, "invalid_amount"], [77, R.FOLD, 0, "not_seated"]]
	for c in cases:
		net.sent = []
		net._handle_poker_rpc(c[0], c[1], c[2])
		assert_eq(_sent_to(c[0]), [[c[0], "rpc_intent_rejected", [c[3]]]], str(c))
	watch_signals(net)
	net.submit_poker_action("steal")
	assert_signal_emitted_with_parameters(net, "intent_rejected", ["invalid_action"])
	var bystander: int = GUESTS.filter(func(id: int) -> bool: return id != _current())[0]
	net.sent = []
	_act(bystander, R.FOLD)
	assert_eq(_sent_to(bystander), [[bystander, "rpc_intent_rejected", ["not_your_turn"]]])


func test_poker_intents_in_a_liars_game_are_invalid_plays():
	_start(GameMode.LIARS)
	net._handle_poker_rpc(10, R.FOLD, 0)
	assert_eq(_sent_to(10), [[10, "rpc_intent_rejected", ["invalid_play"]]])
	assert_false(net._accepting_late_join(), "骗子酒馆从不中途加入")


func test_poker_intents_are_ignored_outside_a_game():
	net.submit_poker_action(R.FOLD)
	net._handle_poker_rpc(10, R.FOLD, 0)
	assert_eq(net.sent, [])
	assert_true(net._turn_timer.is_stopped())
