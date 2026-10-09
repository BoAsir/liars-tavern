extends "res://tests/poker_table_case.gd"
# 庄家、座位与盲注(规格 §2.3):按钮移动、单挑、3→2 人、新人与离开者、大盲只剩 10 的三种情形。


func test_three_handed_button_blinds_dealing_order_and_first_actor():
	var t := make_table([1, 2, 3])
	var events := start_with_button(t, 1)
	assert_eq(H.types(events), ["hand_started", "blind", "blind", "hole_cards", "turn"])
	var started := H.find(events, "hand_started")
	assert_eq([started["hand"], started["button"], started["sb"], started["bb"]], [1, 1, 2, 3])
	assert_eq(started["seats"], [1, 2, 3])
	assert_eq(started["dealt"], [2, 3, 1], "发牌从小盲起")
	var blinds := H.find_all(events, "blind")
	assert_eq(blinds[0], {"type": "blind", "pid": 2, "kind": "sb", "amount": 10, "bet": 10, "stack": 1990, "all_in": false})
	assert_eq(blinds[1], {"type": "blind", "pid": 3, "kind": "bb", "amount": 20, "bet": 20, "stack": 1980, "all_in": false})
	assert_eq(H.find(events, "hole_cards"), {"type": "hole_cards", "hand": 1, "pids": [2, 3, 1]})
	assert_eq(H.find(events, "turn")["pid"], 1, "三人时翻牌前按钮先说话")
	assert_eq([t.current_pid(), t.current_bet(), t.street()], [1, 20, R.PREFLOP])
	assert_eq([t.button(), t.small_blind(), t.big_blind()], [1, 2, 3])
	var seen := {}
	for pid in [1, 2, 3]:
		assert_eq(t.hole_cards(pid).size(), 2)
		assert_eq(t.player(pid)["status"], R.STATUS_ACTIVE)
		for c in t.hole_cards(pid):
			seen[c] = true
	assert_eq(seen.size(), 6, "手牌各不相同")


func test_four_handed_first_actor_sits_after_the_big_blind():
	var t := make_table([1, 2, 3, 4])
	var started := H.find(start_with_button(t, 2), "hand_started")
	assert_eq([started["button"], started["sb"], started["bb"]], [2, 3, 4])
	assert_eq(started["dealt"], [3, 4, 1, 2])
	assert_eq(t.current_pid(), 1)


func test_heads_up_button_posts_small_blind_acts_first_preflop_and_last_after():
	var t := make_table([1, 2])
	var started := H.find(start_with_button(t, 1), "hand_started")
	assert_eq([started["button"], started["sb"], started["bb"]], [1, 1, 2])
	assert_eq(started["dealt"], [1, 2])
	assert_eq(t.current_pid(), 1, "单挑翻牌前按钮(小盲)先说话")
	play_as(t, 1, R.CALL)
	assert_eq(t.current_pid(), 2, "大盲还有选择权")
	play_as(t, 2, R.CHECK)
	assert_eq(t.street(), R.FLOP)
	assert_eq(t.current_pid(), 2, "翻牌后大盲先说话")


func test_button_and_blinds_move_one_seat_each_hand():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)
	fold_out(t)
	var started := H.find(t.start_hand(), "hand_started")
	assert_eq([started["hand"], started["button"], started["sb"], started["bb"]], [2, 2, 3, 1])
	fold_out(t)
	started = H.find(t.start_hand(), "hand_started")
	assert_eq([started["button"], started["sb"], started["bb"]], [3, 1, 2])


func test_first_button_is_random_when_not_set():
	var buttons := {}
	for s in 20:
		var t := make_table([1, 2, 3, 4], false, s)
		t.start_hand()
		assert_has([1, 2, 3, 4], t.button())
		buttons[t.button()] = true
	assert_gt(buttons.size(), 1)


func test_three_to_heads_up_gives_the_button_to_the_last_big_blind():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)    # 小盲 2、大盲 3
	fold_out(t)
	t.remove_player(1)
	var started := H.find(t.start_hand(), "hand_started")
	assert_eq(started["dealt"].size(), 2)
	assert_eq([started["button"], started["sb"], started["bb"]], [3, 3, 2], "上一手的大盲改下小盲,不连下两次大盲")


func test_new_player_between_button_and_small_blind_does_not_take_the_button():
	var t := make_table([1, 2, 3])
	start_with_button(t, 3)    # 小盲 1、大盲 2
	assert_eq(t.add_player(4), [{"type": "player_joined", "pid": 4}])
	assert_eq(t.seat_order(), [1, 2, 3, 4], "新人排在座位顺序末尾:按钮 3 与小盲 1 之间")
	fold_out(t)
	var started := H.find(t.start_hand(), "hand_started")
	assert_eq(started["seats"], [1, 2, 3, 4])
	assert_eq([started["button"], started["sb"], started["bb"]], [1, 2, 3], "按钮在上一手的座位表里往后走,新人不抢按钮")
	assert_eq(started["dealt"], [2, 3, 4, 1])
	assert_eq(t.current_pid(), 4, "新人坐在大盲之后,第一个说话")


func test_button_leaving_passes_the_button_to_the_next_dealt_player():
	var t := make_table([1, 2, 3, 4])
	start_with_button(t, 1)    # 小盲 2、大盲 3,4 先说话
	t.remove_player(1)
	fold_out(t)
	var started := H.find(t.start_hand(), "hand_started")
	assert_eq(started["seats"], [2, 3, 4])
	assert_eq([started["button"], started["sb"], started["bb"]], [2, 3, 4])


func test_busted_button_passes_the_button_on_and_stays_seated():
	var t := make_table([1, 2, 3, 4])
	var rig := {"stacks": {1: 20}, "holes": {1: H.cards("7c 2d"), 3: H.cards("Ah Ad")}, "board": H.cards("Ks 9h 5c 4d Jd")}
	start_with_button(t, 1, rig)
	play_as(t, 4, R.FOLD)
	play_as(t, 1, R.ALLIN)    # 只有 20:全下即跟注
	play_as(t, 2, R.FOLD)     # 大盲已经下了 20,不用再行动,直接发完
	assert_eq(t.phase(), PokerTable.Phase.IDLE)
	assert_eq(t.player(1)["status"], R.STATUS_BUSTED)
	var started := H.find(t.start_hand(), "hand_started")
	assert_eq(started["seats"], [1, 2, 3, 4], "输光的人还在座位表里,只是不发牌")
	assert_eq([started["button"], started["sb"], started["bb"]], [2, 3, 4])
	assert_eq(started["dealt"], [3, 4, 2])


func test_heads_up_big_blind_with_ten_chips_runs_out_the_board_at_once():
	var t := make_table([1, 2])
	var events := start_with_button(t, 1, {"stacks": {2: 10}})
	var bb: Dictionary = H.find_all(events, "blind")[1]
	assert_eq([bb["amount"], bb["bet"], bb["stack"], bb["all_in"]], [10, 10, 0, true])
	assert_eq(H.types(events), [
		"hand_started", "blind", "blind", "hole_cards", "bets_collected", "reveal",
		"street", "street", "street", "pot_won", "hand_over",
	], "小盲 to_call 为 0、对手已全下:不用行动,直接发完")
	assert_eq(H.find(events, "bets_collected")["pots"], [{"amount": 20, "eligible": [1, 2]}])
	assert_eq(H.find(events, "reveal")["reason"], "allin")
	assert_eq(t.phase(), PokerTable.Phase.IDLE)


func test_short_big_blind_still_makes_the_button_call_twenty():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1, {"stacks": {3: 10}})
	assert_eq(t.current_bet(), 20, "大盲只下得起 10,当前最高下注仍按 20")
	var legal := t.legal_actions(1)
	assert_eq([legal["to_call"], legal["call_amount"], legal["min_raise_to"]], [20, 20, 40])
	play_as(t, 1, R.CALL)
	assert_eq(t.legal_actions(2)["to_call"], 10)


func test_short_big_blind_small_blind_need_not_act_after_the_button_folds():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1, {"stacks": {3: 10}})
	var events := play_as(t, 1, R.FOLD)
	assert_eq(H.types(events), ["action", "bets_collected", "reveal", "street", "street", "street", "pot_won", "hand_over"])
	assert_eq(H.find(events, "reveal")["hands"].map(func(h): return h["pid"]), [2, 3])


func test_heads_up_small_blind_all_in_for_ten_returns_the_big_blinds_extra_ten():
	var t := make_table([1, 2])
	var events := start_with_button(t, 1, {"stacks": {1: 10}})
	var sb: Dictionary = H.find_all(events, "blind")[0]
	assert_eq([sb["amount"], sb["all_in"]], [10, true])
	assert_false(H.types(events).has("turn"), "大盲不欠跟注、对手已全下:不用行动")
	assert_eq(H.find(events, "bets_collected")["refund"], {"pid": 2, "amount": 10}, "大盲多下的 10 没人跟,退回")
	assert_eq(H.find(events, "bets_collected")["pots"], [{"amount": 20, "eligible": [1, 2]}])
	var stacks: Dictionary = H.find(events, "hand_over")["stacks"]
	assert_eq(stacks[1] + stacks[2], 2010)


func test_newcomer_is_not_exempt_from_the_blinds_on_his_first_hand():
	var t := make_table([1, 2, 3])
	start_with_button(t, 2)    # 小盲 3、大盲 1
	t.add_player(4)
	fold_out(t)
	var started := H.find(t.start_hand(), "hand_started")
	assert_eq([started["button"], started["sb"], started["bb"]], [3, 4, 1], "新人排在按钮之后:第一手就下小盲,不补也不免")
	assert_eq(started["dealt"], [4, 1, 2, 3])


func test_heads_up_button_alternates_every_hand():
	var t := make_table([1, 2])
	start_with_button(t, 1)
	fold_out(t)
	var started := H.find(t.start_hand(), "hand_started")
	assert_eq([started["button"], started["sb"], started["bb"]], [2, 2, 1])
	fold_out(t)
	started = H.find(t.start_hand(), "hand_started")
	assert_eq([started["button"], started["sb"], started["bb"]], [1, 1, 2])


func test_hand_needs_two_players_with_chips():
	var t := make_table([1])
	assert_false(t.can_start_hand())
	assert_eq(t.start_hand(), [])
	assert_eq(t.hand_number(), 0)
	assert_eq(t.phase(), PokerTable.Phase.IDLE)
	t.add_player(2)
	assert_true(t.can_start_hand())
