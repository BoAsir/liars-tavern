extends GutTest
# 德州会话(规格 §4.2):意图分派与校验、turn_action 标记、名字补齐、视图接收者、一手间隔、中途加入与散局。
# 引擎规则在 PokerTable 的测试里;这里只看会话这一层。


const H := preload("res://tests/poker_helpers.gd")
const R := preload("res://src/core/poker/poker_rules.gd")
const NAMES := {1: "甲", 2: "乙", 3: "丙"}

var session: PokerSession


func before_each():
	session = PokerSession.new(GameMode.HOLDEM)


func _start(pids := [1, 2, 3], seed_value := 7) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return session.start(pids, NAMES, rng)


func _current() -> int:
	return session.public_view(0.0)["current_pid"]


func _intent(pid: int, action: String, amount := 0) -> Dictionary:
	return session.handle_intent(pid, {"kind": action, "amount": amount})


func _fold_out() -> Array:
	var events := []
	while session.has_turn():
		events.append_array(_intent(_current(), R.FOLD)["events"])
	return events


func _bust_one() -> Array:
	# 三人局:1 只有 20、全下,2 拿 AA 跟注,3 弃牌 → 1 输光
	var table: PokerTable = session._table
	table.rigged = {"holes": {1: H.cards("7c 2d"), 2: H.cards("Ah Ad")}, "board": H.cards("8c 6h 4d Jc 3s"), "stacks": {1: 20}}
	var events := session.start_next_hand()
	assert_true(session.has_turn())
	for step in [[R.ALLIN, 1], [R.CALL, 2], [R.FOLD, 3]]:
		assert_eq(_current(), step[1])
		events.append_array(_intent(step[1], step[0])["events"])
	assert_eq(H.find(events, "hand_over").get("busted"), [1])
	return events


# —— 开局与意图 ——

func test_start_seats_everyone_and_deals_the_first_hand():
	var events := _start()
	assert_eq(events[0]["type"], "hand_started")
	assert_eq(events[0]["seats"], [1, 2, 3])
	assert_eq(events.back()["type"], "turn")
	assert_true(session.has_turn())
	assert_false(session.is_over())
	assert_false(session.is_ending())
	assert_true(session.accepts_late_join())
	assert_eq(session.seats_with_patrons(), [1, 2, 3])
	assert_eq(session.name_of(3), "丙")
	assert_eq(session.public_view(0.0)["mode"], GameMode.HOLDEM)
	var short_deck := PokerSession.new(GameMode.SHORT_DECK)
	short_deck.start([1, 2, 3], NAMES, RandomNumberGenerator.new())
	assert_eq(short_deck.public_view(0.0)["mode"], GameMode.SHORT_DECK)


func test_naming_events_leaves_the_engine_dictionaries_untouched():
	# 引擎的事件字典不就地改:补了名字的是新字典(编码规范:不变性)
	_start()
	var joined := {"type": "player_joined", "pid": 4}
	var over := {"type": "session_over", "results": [{"pid": 1, "net": 0}]}
	var named: Array = session._named([joined, over])
	assert_eq(named[0], {"type": "player_joined", "pid": 4, "name": "4"})
	assert_eq(named[1]["results"][0], {"pid": 1, "net": 0, "name": "甲"})
	assert_false(joined.has("name"), "原事件没被改")
	assert_false(over["results"][0].has("name"), "原结算行没被改")


func test_bet_actions_consume_the_turn_and_seat_actions_do_not():
	_start()
	var result := _intent(_current(), R.FOLD)
	assert_true(result["ok"])
	assert_true(result["turn_action"])
	assert_eq(result["events"][0]["type"], "action")
	_fold_out()
	var busted_events := _bust_one()
	assert_false(busted_events.is_empty())
	result = _intent(1, R.REBUY)
	assert_true(result["ok"])
	assert_false(result["turn_action"], "再领不消耗回合")
	assert_eq(result["events"], [{"type": "rebuy", "pid": 1, "amount": 2000, "buyins": 2, "stack": 2000}])


func test_rejections_keep_the_engine_error_codes_and_change_nothing():
	_start()
	var actor := _current()
	var bystander: int = [1, 2, 3].filter(func(pid: int) -> bool: return pid != actor)[0]
	assert_eq(_intent(bystander, R.FOLD), {"ok": false, "error": "not_your_turn", "turn_action": false})
	assert_eq(_intent(actor, R.RAISE, 25)["error"], "invalid_amount")
	assert_eq(_intent(actor, R.REBUY)["error"], "cannot_rebuy")
	assert_eq(_intent(actor, R.SPECTATE)["error"], "invalid_action")
	assert_eq(_intent(actor, R.SIT_IN)["error"], "invalid_action")
	assert_eq(_intent(99, R.FOLD)["error"], "not_seated")
	assert_eq(_current(), actor)


func test_foreign_or_malformed_intents_are_rejected_before_the_engine():
	_start()
	var actor := _current()
	var bad_actions := [{"kind": "play", "indices": [0]}, {"kind": "challenge"}, {}, {"kind": 3}, {"kind": "steal"}]
	for intent in bad_actions:
		assert_eq(session.handle_intent(actor, intent)["error"], "invalid_action", str(intent))
	var bad_amounts := [{"kind": R.RAISE}, {"kind": R.RAISE, "amount": "60"}, {"kind": R.RAISE, "amount": 60.0},
		{"kind": R.RAISE, "amount": -10}, {"kind": R.RAISE, "amount": PokerSession.MAX_AMOUNT + 1}]
	for intent in bad_amounts:
		assert_eq(session.handle_intent(actor, intent)["error"], "invalid_amount", str(intent))
	assert_eq(_current(), actor)


func test_check_intent_validates_the_raw_rpc_arguments():
	assert_eq(PokerSession.check_intent(R.FOLD, 0), "")
	assert_eq(PokerSession.check_intent(R.SIT_IN, 0), "")
	assert_eq(PokerSession.check_intent(R.RAISE, PokerSession.MAX_AMOUNT), "")
	assert_eq(PokerSession.check_intent("play", 0), "invalid_action")
	assert_eq(PokerSession.check_intent(5, 0), "invalid_action")
	assert_eq(PokerSession.check_intent(null, 0), "invalid_action")
	assert_eq(PokerSession.check_intent(R.RAISE, 1.0), "invalid_amount")
	assert_eq(PokerSession.check_intent(R.RAISE, -1), "invalid_amount")
	assert_eq(PokerSession.check_intent(R.RAISE, null), "invalid_amount")
	assert_eq(PokerSession.check_intent(R.RAISE, PokerSession.MAX_AMOUNT + 1), "invalid_amount")


func test_timeout_acts_for_the_current_player_as_a_turn_action():
	_start()
	var actor := _current()
	var result := session.on_turn_timeout()
	assert_true(result["ok"])
	assert_true(result["turn_action"])
	assert_eq([result["events"][0]["pid"], result["events"][0]["timeout"]], [actor, true])
	_fold_out()
	assert_false(session.has_turn())
	assert_eq(session.on_turn_timeout()["error"], "no_hand", "两手之间没有回合可超时")


# —— 离开、加入、名字 ——

func test_disconnect_folds_members_and_ignores_strangers():
	_start()
	assert_eq(session.on_disconnect(42), [])
	var actor := _current()
	var events := session.on_disconnect(actor)
	assert_eq(events[0], {"type": "player_left", "pid": actor, "folded": true})
	assert_eq(session.on_disconnect(actor), [], "离开过的人再断线没有事件")
	assert_true(session.has_turn(), "行动继续")
	assert_ne(_current(), actor)


func test_late_joiner_gets_a_name_and_is_dealt_the_next_hand():
	_start()
	var events := session.add_player(4, "丁")
	assert_eq(events, [{"type": "player_joined", "pid": 4, "name": "丁"}])
	assert_eq(session.name_of(4), "丁")
	assert_eq(session.seats_with_patrons(), [1, 2, 3], "本手旁观")
	assert_has(session.viewers(), 4, "迟到者也收私有视图")
	assert_eq(session.public_view(0.0)["players"][3]["name"], "丁")
	_fold_out()
	assert_true(session.next_hand_ready())
	var started := H.find(session.start_next_hand(), "hand_started")
	assert_has(started["dealt"], 4)
	assert_eq(session.seats_with_patrons(), [1, 2, 3, 4])


func test_session_over_rows_carry_names_including_players_who_left():
	_start()
	session.on_disconnect(3)
	_fold_out()
	var events := session.request_end()
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "session_over")
	var names: Array = events[0]["results"].map(func(row: Dictionary) -> String: return row["name"])
	assert_eq(names.size(), 3)
	for name in NAMES.values():
		assert_has(names, name)
	assert_true(session.is_over())
	assert_false(session.accepts_late_join())
	assert_false(session.next_hand_ready())
	assert_eq(session.add_player(5, "戊"), [], "结算后不收人")
	assert_eq(session.public_view(0.0)["results"].size(), 3)
	assert_eq(_intent(1, R.FOLD)["error"], "session_over")


func test_viewers_are_everyone_who_has_not_left():
	_start()
	_fold_out()
	_bust_one()
	_intent(1, R.SPECTATE)
	session.add_player(4, "丁")
	session.on_disconnect(2)
	assert_eq(session.viewers(), [1, 3, 4], "观战者、迟到者都收;离开的人不收")
	session.start_next_hand()
	session.on_disconnect(3)
	assert_eq(session.viewers(), [1, 4], "本手里离开(已弃牌)的人也不再收")


# —— 一手间隔与散局 ——

func test_hand_gap_waits_for_bust_decisions():
	_start()
	assert_almost_eq(session.hand_gap(), PokerPacing.HAND_GAP, 0.001)
	_fold_out()
	assert_true(session.next_hand_ready())
	_bust_one()
	assert_almost_eq(session.hand_gap(), PokerPacing.BUST_DECISION, 0.001, "有输光者没做选择")
	assert_true(session.next_hand_ready(), "两人仍能开下一手,只是晚一点")
	_intent(1, R.SPECTATE)
	assert_almost_eq(session.hand_gap(), PokerPacing.HAND_GAP, 0.001, "选完就恢复")


func test_busted_player_who_left_does_not_hold_the_next_hand():
	_start()
	_fold_out()
	_bust_one()
	session.on_disconnect(1)
	assert_almost_eq(session.hand_gap(), PokerPacing.HAND_GAP, 0.001)


func test_bust_wait_only_follows_the_hand_where_someone_busted():
	# 规格 §2.6:「有人输光的那一手之后」才留 6 秒;一直不选的输光者不拖慢之后每一手
	_start()
	_fold_out()
	_bust_one()
	assert_almost_eq(session.hand_gap(), PokerPacing.BUST_DECISION, 0.001)
	session.start_next_hand()
	_fold_out()
	assert_eq(session.public_view(0.0)["players"][0]["status"], R.STATUS_BUSTED, "他还是没选")
	assert_almost_eq(session.hand_gap(), PokerPacing.HAND_GAP, 0.001, "之后的手恢复 1.5 秒")


func test_a_newcomer_who_leaves_mid_hand_is_gone_at_once_and_costs_no_show_time():
	# 还没登场(本手座位表里没有他)的人在手牌中离开:立即移出,加入与离开都不占演出时间,
	# 否则反复「加入→断开」能无限续当前行动者的回合、把视图撑大
	_start()
	var actor := _current()
	for i in 20:
		var pid := 100 + i
		var joined := session.add_player(pid, "过客")
		var left := session.on_disconnect(pid)
		assert_almost_eq(session.estimate(joined + left), 0.0, 0.001, "没有酒客,什么也不用演")
		assert_true(left[0].get("offstage", false))
	assert_eq(session.public_view(0.0)["players"].size(), 3, "视图不留过客")
	assert_eq(_current(), actor)
	var seated_leave := session.on_disconnect(actor)
	assert_false(seated_leave[0].get("offstage", false))
	assert_gt(session.estimate(seated_leave), 0.0, "桌上的人离开照常演")


func test_request_end_during_a_hand_marks_ending_and_settles_after_it():
	_start()
	assert_eq(session.request_end(), [{"type": "ending"}])
	assert_true(session.is_ending())
	assert_false(session.accepts_late_join(), "散局中不收人")
	assert_true(session.public_view(0.0)["ending"])
	var events := _fold_out()
	assert_eq(events.back()["type"], "session_over")
	assert_true(session.is_over())
	assert_eq(session.request_end(), [])


func test_pacing_is_the_poker_budget():
	var batch := [{"type": "action", "pid": 1, "all_in": false}, {"type": "turn", "pid": 2}]
	assert_almost_eq(session.estimate(batch), PokerPacing.estimate(batch), 0.001)
	assert_almost_eq(session.turn_timer_after(batch, 2.0, 11.0), PokerPacing.turn_timer_after(batch, 2.0, 11.0), 0.001)
