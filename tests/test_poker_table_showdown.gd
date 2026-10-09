extends "res://tests/poker_table_case.gd"
# 底池与摊牌(规格 §2.5):河牌摊牌、平分零头、全下亮牌后发完、多层边池从最后一个分到主池、
# 只有一个有资格者的边池照常比牌、短牌同花胜葫芦、两手之间保留的状态(规格 §4.4)。


func _rig(holes: Dictionary, board_text: String, stacks := {}) -> Dictionary:
	var hole_cards := {}
	for pid in holes:
		hole_cards[pid] = H.cards(holes[pid])
	return {"holes": hole_cards, "board": H.cards(board_text), "stacks": stacks}


func test_river_showdown_reveals_everyone_after_the_button_and_pays_the_best_hand():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1, _rig({1: "Ah Kh", 2: "Qs Qd", 3: "7c 2d"}, "Qh Jh Th 3s 4c"))
	var events := check_down(t)
	var tail := events.slice(events.size() - 4)
	assert_eq(H.types(tail), ["reveal", "pot_won", "hand_over", "hand_record"])
	assert_eq(tail[0], {"type": "reveal", "reason": "showdown", "hands": [
		{"pid": 2, "cards": H.cards("Qs Qd")}, {"pid": 3, "cards": H.cards("7c 2d")}, {"pid": 1, "cards": H.cards("Ah Kh")},
	]})
	assert_eq(tail[1], {
		"type": "pot_won", "index": 0, "amount": 60, "winners": [1], "shares": {1: 60},
		"hand_name": "皇家同花顺", "best": {1: H.cards("Ah Kh Qh Jh Th")}, "uncontested": false,
	})
	assert_eq(tail[2], {"type": "hand_over", "hand": 1, "stacks": {1: 2040, 2: 1980, 3: 1980}, "busted": []})
	assert_eq(t.street(), R.SHOWDOWN)
	assert_eq(t.player(3)["shown"], H.cards("7c 2d"))


func test_tie_splits_by_chip_units_and_the_odd_unit_goes_to_the_first_winner_after_the_button():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1, _rig({1: "2h 3h", 2: "6c 7c", 3: "4d 5d"}, "As Ks Qd Jc Tc"))
	play_as(t, 1, R.CALL)
	play_as(t, 2, R.FOLD)     # 小盲的 10 是死钱:底池 50
	var events := check_down(t)
	var won := H.find(events, "pot_won")
	assert_eq([won["amount"], won["winners"], won["shares"], won["hand_name"]], [50, [3, 1], {3: 30, 1: 20}, "顺子"],
		"5 个单位两人分:按钮之后的第一位赢家 3 多拿一个")
	assert_eq(won["best"].keys().size(), 2)
	assert_eq(H.find(events, "reveal")["hands"].map(func(h): return h["pid"]), [3, 1], "弃牌的人不亮牌")


func test_preflop_all_in_reveals_first_then_runs_out_three_streets():
	var t := make_table([1, 2])
	start_with_button(t, 1, _rig({1: "As Ad", 2: "Kc Kd"}, "2h 7s 9c Jd 3h"))
	play_as(t, 1, R.ALLIN)
	var events := play_as(t, 2, R.CALL)
	assert_eq(H.types(events), ["action", "bets_collected", "reveal", "street", "street", "street", "pot_won", "hand_over", "hand_record"])
	var reveal := H.find(events, "reveal")
	assert_eq([reveal["reason"], reveal["hands"].map(func(h): return h["pid"])], ["allin", [2, 1]])
	var streets := H.find_all(events, "street")
	assert_eq(streets.map(func(s): return s["street"]), [R.FLOP, R.TURN, R.RIVER])
	assert_eq(streets[2]["board"], H.cards("2h 7s 9c Jd 3h"))
	var won := H.find(events, "pot_won")
	assert_eq([won["amount"], won["winners"], won["hand_name"], won["uncontested"]], [4000, [1], "一对", false])
	assert_eq(H.find(events, "hand_over")["busted"], [2])
	assert_eq(t.player(2)["status"], R.STATUS_BUSTED)


func test_three_all_ins_pay_the_side_pot_first_and_the_main_pot_last():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1, _rig({1: "As Ad", 2: "Ks Kd", 3: "Qs Qd"}, "2c 7h 9d Jc 3h", {1: 300, 2: 600}))
	play_as(t, 1, R.ALLIN)
	play_as(t, 2, R.ALLIN)
	assert_false(t.legal_actions(3)["can_allin"], "对手都全下:只能跟或弃")
	var events := play_as(t, 3, R.CALL)
	assert_eq(H.find(events, "bets_collected")["pots"], [
		{"amount": 900, "eligible": [1, 2, 3]}, {"amount": 600, "eligible": [2, 3]},
	])
	var won := H.find_all(events, "pot_won")
	assert_eq(won.map(func(w): return [w["index"], w["amount"], w["winners"]]), [[1, 600, [2]], [0, 900, [1]]],
		"从最后一个边池到主池依次分配")
	assert_eq(H.find(events, "hand_over")["stacks"], {1: 900, 2: 600, 3: 1400})


func test_side_pot_with_a_single_eligible_player_is_still_a_showdown_win():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1, _rig({1: "As Ad", 2: "Ks Kd", 3: "Qs Qd"}, "2c 7h 9d Jc 3h", {1: 100}))
	play_as(t, 1, R.ALLIN)
	play_as(t, 2, R.CALL)
	play_as(t, 3, R.CALL)
	play_as(t, 2, R.RAISE, 200)
	play_as(t, 3, R.CALL)
	play_as(t, 2, R.RAISE, 300)
	var events := play_as(t, 3, R.FOLD)
	assert_eq(H.find(events, "bets_collected")["refund"], {"pid": 2, "amount": 300})
	assert_eq(H.find(events, "bets_collected")["pots"], [{"amount": 300, "eligible": [1, 2]}, {"amount": 400, "eligible": [2]}])
	var side: Dictionary = H.find_all(events, "pot_won")[0]
	assert_eq([side["index"], side["winners"], side["uncontested"], side["hand_name"]], [1, [2], false, "一对"])
	assert_eq(side["best"], {2: H.cards("Ks Kd Jc 9d 7h")}, "摊牌赢的边池照常给出牌型与亮过的牌")
	var main: Dictionary = H.find_all(events, "pot_won")[1]
	assert_eq([main["index"], main["winners"], main["amount"]], [0, [1], 300])


func test_short_deck_flush_beats_full_house_but_long_deck_does_not():
	var rig := _rig({1: "Ah 9h", 2: "Ks Kd"}, "Kh 7h 6h 7c Td")
	for short_deck in [false, true]:
		var t := make_table([1, 2], short_deck)
		start_with_button(t, 1, rig.duplicate(true))
		var won := H.find(check_down(t), "pot_won")
		if short_deck:
			assert_eq([won["winners"], won["hand_name"]], [[1], "同花"], "短牌:同花 > 葫芦")
		else:
			assert_eq([won["winners"], won["hand_name"]], [[2], "葫芦"], "长牌:葫芦 > 同花")


func test_between_hands_the_table_keeps_the_last_hand_on_display():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1, _rig({1: "Ah Kh", 2: "Qs Qd", 3: "7c 2d"}, "Qh Jh Th 3s 4c"))
	play_as(t, 1, R.CALL)
	play_as(t, 2, R.CALL)
	play_as(t, 3, R.CHECK)
	assert_eq(t.best_hand(2), {
		"category": PokerRules.Category.THREE_OF_A_KIND, "name": "三条", "detail": "三条 · Q",
		"cards": H.cards("Qs Qh Qd Jh Th"),
	}, "翻牌后私有视图有当前最大牌型")
	play_as(t, 2, R.CHECK)
	play_as(t, 3, R.FOLD)
	check_down(t)
	assert_eq(t.phase(), PokerTable.Phase.IDLE)
	assert_eq([t.street(), t.board(), t.pots()], [R.SHOWDOWN, H.cards("Qh Jh Th 3s 4c"), []])
	assert_eq([t.button(), t.small_blind(), t.big_blind(), t.current_pid(), t.current_bet()], [1, 2, 3, null, 0])
	assert_eq([t.player(1)["status"], t.player(2)["status"], t.player(3)["status"]],
		[R.STATUS_ACTIVE, R.STATUS_ACTIVE, R.STATUS_FOLDED], "保留各人这一手的最终 status")
	assert_eq([t.player(1)["shown"], t.player(3)["shown"]], [H.cards("Ah Kh"), []])
	assert_eq([t.player(1)["bet"], t.player(1)["committed"]], [0, 0])
	assert_eq(t.legal_actions(1), {})
	assert_eq(t.hand_number(), 1)
	t.start_hand()
	assert_eq([t.player(1)["shown"], t.player(3)["status"]], [[], R.STATUS_ACTIVE], "下一手开始才清掉")
	assert_eq(t.board(), [])
	assert_eq(t.best_hand(1), {}, "还没翻牌")
