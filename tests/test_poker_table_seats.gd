extends "res://tests/poker_table_case.gd"
# 座位(规格 §2.6、§2.7、§2.9):输光与再领/观战的状态约束、中途加入、离开的三种情形、散局与结算。


func _rig(holes: Dictionary, stacks := {}) -> Dictionary:
	var hole_cards := {}
	for pid in holes:
		hole_cards[pid] = H.cards(holes[pid])
	return {"holes": hole_cards, "board": H.cards("8c 6h 4d Jc 3s"), "stacks": stacks}


func _bust_player_one(t: PokerTable) -> Array:
	# 三人局:1 只有 20、拿 72 全下,2 拿 AA 跟注,大盲 3 弃牌 → 1 输光
	start_with_button(t, 1, _rig({1: "7c 2d", 2: "Ah Ad"}, {1: 20}))
	play_as(t, 1, R.ALLIN)
	assert_eq(error_of(t.rebuy(1)), "cannot_rebuy", "手牌中全下的人筹码也是 0,但不能领")
	play_as(t, 2, R.CALL)
	return play_as(t, 3, R.FOLD)


func test_busted_player_can_spectate_or_rebuy_and_others_cannot():
	var t := make_table([1, 2, 3])
	var events := _bust_player_one(t)
	assert_eq(H.find(events, "hand_over")["busted"], [1])
	assert_eq([t.player(1)["status"], t.player(1)["stack"]], [R.STATUS_BUSTED, 0])
	assert_eq(error_of(t.rebuy(2)), "cannot_rebuy", "有筹码的人不能领")
	assert_eq(error_of(t.spectate(2)), "invalid_action", "只有输光的人能选观战")
	assert_eq(error_of(t.rebuy(99)), "not_seated")
	var result := t.spectate(1)
	assert_eq(result, {"ok": true, "events": [{"type": "spectate", "pid": 1}]})
	assert_eq(t.player(1)["status"], R.STATUS_SPECTATING)
	assert_eq(error_of(t.spectate(1)), "invalid_action")
	result = t.rebuy(1)
	assert_eq(result["events"], [{"type": "rebuy", "pid": 1, "amount": 2000, "buyins": 2, "stack": 2000}], "观战中随时可以领")
	assert_eq([t.player(1)["status"], t.player(1)["net"]], [R.STATUS_WAITING, -2000])
	assert_eq(error_of(t.rebuy(1)), "cannot_rebuy")
	assert_has(H.find(t.start_hand(), "hand_started")["dealt"], 1, "再领后下一手发牌")


func test_spectators_stay_seated_but_are_not_dealt():
	var t := make_table([1, 2, 3])
	_bust_player_one(t)
	t.spectate(1)
	var started := H.find(t.start_hand(), "hand_started")
	assert_eq(started["seats"], [1, 2, 3], "观战者留在座位表里")
	assert_does_not_have(started["dealt"], 1)
	assert_eq(t.hole_cards(1), [], "没被发牌的人没有手牌")
	assert_eq(t.player(1)["status"], R.STATUS_SPECTATING)


func test_late_joiner_watches_this_hand_and_is_dealt_the_next():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)
	assert_eq(t.add_player(4), [{"type": "player_joined", "pid": 4}])
	assert_eq(t.add_player(4), [], "已经在座")
	assert_eq([t.player(4)["status"], t.player(4)["stack"], t.player(4)["buyins"]], [R.STATUS_WAITING, 2000, 1])
	assert_eq(t.hole_cards(4), [])
	assert_eq(t.seats_with_patrons(), [1, 2, 3], "新人要等下一手才登场")
	assert_eq(t.chips_in_play(), t.total_bought_in())
	fold_out(t)
	assert_eq(t.seats_with_patrons(), [1, 2, 3])
	var started := H.find(t.start_hand(), "hand_started")
	assert_eq(started["seats"], [1, 2, 3, 4])
	assert_has(started["dealt"], 4)
	assert_eq(t.seats_with_patrons(), [1, 2, 3, 4])


func test_seat_cap_counts_only_players_who_have_not_left():
	var t := make_table([1, 2, 3, 4, 5, 6, 7, 8])
	assert_eq(t.add_player(9), [], "8 人满")
	start_with_button(t, 1)
	t.remove_player(5)
	assert_eq(t.add_player(9), [{"type": "player_joined", "pid": 9}], "离开的人不占座位上限")
	assert_eq(t.add_player(10), [])


func test_leaving_on_your_turn_folds_and_leaves_the_bet_on_the_table():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)
	play_as(t, 1, R.RAISE, 60)
	var events := t.remove_player(2)
	assert_eq(H.types(events), ["player_left", "turn"])
	assert_eq(events[0], {"type": "player_left", "pid": 2, "folded": true})
	assert_eq(events[1]["pid"], 3)
	assert_eq([t.player(2)["status"], t.player(2)["left"], t.player(2)["bet"]], [R.STATUS_FOLDED, true, 10], "已下的注留在桌上")
	assert_eq(t.seats_with_patrons(), [1, 3], "酒客立即离场")
	assert_eq(t.remove_player(2), [], "离开过的人再离开没有事件")
	events = play_as(t, 3, R.CALL)
	assert_eq(H.find(events, "bets_collected")["pots"], [{"amount": 130, "eligible": [1, 3]}])
	assert_eq(t.chips_in_play(), t.total_bought_in())
	fold_out(t)
	assert_eq(t.seat_order(), [1, 3], "这一手结束时移出座位")
	assert_eq(t.player(2), {})
	assert_eq(t.departed_stacks(), {2: 1990})
	assert_eq(t.chips_in_play(), t.total_bought_in())


func test_leaving_out_of_turn_folds_without_moving_the_turn():
	var t := make_table([1, 2, 3, 4])
	start_with_button(t, 1)    # 4 先说话
	var events := t.remove_player(1)
	assert_eq(events, [{"type": "player_left", "pid": 1, "folded": true}])
	assert_eq(t.current_pid(), 4)


func test_all_in_player_who_leaves_stays_in_the_hand_and_can_win():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1, _rig({1: "Ah Ad", 2: "Ks Kd", 3: "Qs Qd"}, {1: 100}))
	play_as(t, 1, R.ALLIN)
	play_as(t, 2, R.CALL)
	play_as(t, 3, R.CALL)
	assert_eq(t.remove_player(1), [{"type": "player_left", "pid": 1, "folded": false}])
	assert_eq([t.player(1)["status"], t.player(1)["left"]], [R.STATUS_ALLIN, true])
	var events := check_down(t)
	assert_has(H.find(events, "reveal")["hands"].map(func(h): return h["pid"]), 1, "照常摊牌")
	assert_eq(H.find(events, "pot_won")["winners"], [1])
	assert_eq(H.find(events, "hand_over")["stacks"][1], 300)
	assert_eq(H.find(events, "hand_over")["busted"], [])
	assert_eq(t.departed_stacks(), {1: 300}, "结算筹码在他离开的那一手结束才定格")
	assert_eq(t.seat_order(), [2, 3])


func test_sole_top_bettor_leaving_when_the_callers_are_all_in_gets_the_uncalled_part_back():
	var t := make_table([1, 2, 3])
	start_with_button(t, 3, {"stacks": {2: 220}})   # 小盲 1、大盲 2;翻牌后 1 先说话
	play_as(t, 3, R.CALL)
	play_as(t, 1, R.CALL)
	play_as(t, 2, R.CHECK)
	play_as(t, 1, R.RAISE, 200)
	play_as(t, 2, R.CALL)      # 只剩 200:全下跟注
	play_as(t, 3, R.RAISE, 500)
	var events := t.remove_player(3)
	assert_eq(H.types(events), [
		"player_left", "bets_collected", "reveal", "street", "street", "pot_won", "hand_over",
	], "1 不欠跟注、对手都全下:直接发完")
	assert_eq(events[0]["folded"], true)
	assert_eq(H.find(events, "bets_collected")["refund"], {"pid": 3, "amount": 300}, "离开的人照样退回没人跟的部分")
	assert_eq(H.find(events, "bets_collected")["pots"], [{"amount": 660, "eligible": [1, 2]}])
	assert_eq(t.departed_stacks(), {3: 1780}, "2000 − 20 − 500 + 退回 300")


func test_leaving_while_not_in_the_hand():
	var t := make_table([1, 2, 3])
	assert_eq(t.remove_player(3), [{"type": "player_left", "pid": 3, "folded": false}])
	assert_eq(t.seat_order(), [1, 2], "牌桌空闲:立即移出")
	assert_eq(t.departed_stacks(), {3: 2000})
	start_with_button(t, 1)
	t.add_player(4)
	assert_eq(t.remove_player(4), [{"type": "player_left", "pid": 4, "folded": false}])
	assert_eq(t.seat_order(), [1, 2, 4], "手牌进行中:这一手结束时才移出")
	assert_eq(t.current_pid(), 1)
	fold_out(t)
	assert_eq(t.seat_order(), [1, 2])
	assert_eq(t.remove_player(77), [], "不在座位上")


func test_request_end_while_idle_settles_at_once():
	var t := make_table([1, 2])
	var events := t.request_end()
	assert_eq(H.types(events), ["session_over"])
	assert_eq(t.phase(), PokerTable.Phase.OVER)
	assert_eq(events[0]["results"].size(), 2)
	assert_eq(error_of(t.act(1, R.FOLD)), "session_over")
	assert_eq(error_of(t.rebuy(1)), "session_over")
	assert_eq(error_of(t.spectate(1)), "session_over")
	assert_eq(error_of(t.sit_in(1)), "session_over")
	assert_eq(error_of(t.timeout_action()), "session_over")
	assert_eq(t.add_player(3), [], "散局后不能加入")
	assert_eq(t.remove_player(1), [])
	assert_false(t.can_start_hand())
	assert_eq(t.start_hand(), [])
	assert_eq(t.request_end(), [])


func test_request_end_during_a_hand_finishes_the_hand_first():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)
	assert_eq(t.request_end(), [{"type": "ending"}])
	assert_true(t.is_ending())
	assert_eq(t.request_end(), [], "重复请求没有事件")
	assert_eq(t.phase(), PokerTable.Phase.BETTING)
	var events := fold_out(t)
	assert_eq(H.types(events).slice(-2), ["hand_over", "session_over"])
	assert_eq(t.phase(), PokerTable.Phase.OVER)
	assert_false(t.can_start_hand())


func test_results_rank_by_net_and_sum_to_zero_including_players_who_left():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1, _rig({1: "Ks Kd", 2: "Ah Ad"}))
	play_as(t, 1, R.ALLIN)
	play_as(t, 2, R.CALL)
	play_as(t, 3, R.FOLD)
	t.rebuy(1)
	t.remove_player(3)
	var events := t.request_end()
	var results: Array = events[0]["results"]
	assert_eq(results, [
		{"pid": 2, "stack": 4020, "buyins": 1, "net": 2020, "left": false},
		{"pid": 3, "stack": 1980, "buyins": 1, "net": -20, "left": true},
		{"pid": 1, "stack": 2000, "buyins": 2, "net": -2000, "left": false},
	])
	var total := 0
	for row in results:
		total += row["net"]
	assert_eq(total, 0, "所有人盈亏之和恒为 0")
	assert_eq(t.results(), results)


func test_results_mid_hand_count_chips_committed_this_hand_so_net_still_sums_to_zero():
	# results() 是公开接口,后续任务可能在一手进行中拿来预览:已押进本手的筹码也得算进盈亏
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)
	play(t, R.RAISE, 400)
	assert_eq(t.phase(), PokerTable.Phase.BETTING)
	var total := 0
	for row in t.results():
		total += row["net"]
	assert_eq(total, 0, "一手进行中盈亏之和也恒为 0")
	assert_eq(t.results()[0]["stack"], 2000, "没押筹码的人仍是 2000;押了的人按筹码 + 本手已投入计")
