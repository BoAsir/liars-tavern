extends "res://tests/poker_table_case.gd"
# 下注(规格 §2.4):错误码、最小加注、不完整加注不重开与累计重开、对手都全下、大盲选择权、
# 一轮结束、全员弃牌给大盲(退回且不泄露牌)、超时代打。


func _action(events: Array) -> Dictionary:
	return H.find(events, "action")


func test_error_codes_and_rejected_intents_change_nothing():
	var t := make_table([1, 2, 3])
	assert_eq(error_of(t.act(1, R.CHECK)), "no_hand", "还没开始发牌")
	start_with_button(t, 1)    # 小盲 2、大盲 3,按钮 1 先说话
	assert_eq(error_of(t.act(2, R.CALL)), "not_your_turn")
	assert_eq(error_of(t.act(9, R.FOLD)), "not_seated")
	assert_eq(error_of(t.act(1, "dance")), "invalid_action")
	assert_eq(error_of(t.act(1, R.REBUY)), "invalid_action", "座位意图不走 act")
	assert_eq(error_of(t.act(1, R.CHECK)), "invalid_action", "欠 20 不能过牌")
	assert_eq(error_of(t.act(1, R.RAISE, 30)), "invalid_amount", "最少加注到 40")
	assert_eq(error_of(t.act(1, R.RAISE, 45)), "invalid_amount", "不是 10 的倍数")
	assert_eq(error_of(t.act(1, R.RAISE, 2010)), "invalid_amount", "超过本轮已下 + 筹码")
	assert_eq([t.current_pid(), t.player(1)["stack"], t.player(1)["bet"]], [1, 2000, 0], "被拒绝的意图不改状态")
	play_as(t, 1, R.CALL)
	play_as(t, 2, R.CALL)
	assert_eq(error_of(t.act(3, R.CALL)), "invalid_action", "不欠跟注时不能跟注")


func test_preflop_minimum_raise_follows_the_last_full_increment():
	var t := make_table([1, 2, 3, 4])
	start_with_button(t, 1)    # 小盲 2、大盲 3,4 先说话
	assert_eq(t.legal_actions(4)["min_raise_to"], 40, "翻牌前最近完整增量 = 大盲 20")
	var raise := _action(play_as(t, 4, R.RAISE, 60))
	assert_eq([raise["action"], raise["amount"], raise["bet"], raise["stack"], raise["all_in"]], [R.RAISE, 60, 60, 1940, false])
	assert_eq(t.legal_actions(1)["min_raise_to"], 100, "增量 40")
	play_as(t, 1, R.RAISE, 100)
	assert_eq(t.legal_actions(2)["min_raise_to"], 140)
	raise = _action(play_as(t, 2, R.RAISE, 340))
	assert_eq([raise["amount"], raise["bet"]], [330, 340], "小盲已下 10,这次再放 330")
	assert_eq(t.current_bet(), 340)
	var legal := t.legal_actions(3)
	assert_eq([legal["to_call"], legal["min_raise_to"], legal["max_raise_to"]], [320, 580, 2000])
	assert_eq(error_of(t.act(3, R.RAISE, 570)), "invalid_amount")


func test_postflop_short_all_in_bet_needs_a_raise_to_thirty_and_checkers_can_only_call():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1, {"stacks": {3: 30}})    # 小盲 2、大盲 3(只有 30)
	play_as(t, 1, R.CALL)
	play_as(t, 2, R.CALL)
	play_as(t, 3, R.CHECK)
	assert_eq(t.street(), R.FLOP)
	assert_eq(t.legal_actions(2)["min_raise_to"], 20, "当前最高为 0 时最少下注 20")
	play_as(t, 2, R.CHECK)
	var bet := _action(play_as(t, 3, R.ALLIN))
	assert_eq([bet["action"], bet["amount"], bet["all_in"]], [R.BET, 10, true], "本轮第一注记为 bet")
	var legal := t.legal_actions(1)
	assert_eq([legal["to_call"], legal["min_raise_to"], legal["can_raise"]], [10, 30, true], "全下 10 不够完整增量:最少加注到 30")
	play_as(t, 1, R.CALL)
	legal = t.legal_actions(2)
	assert_eq([legal["to_call"], legal["can_check"], legal["can_raise"], legal["can_allin"]], [10, false, false, false],
		"已过牌的人面对不完整加注只能跟注或弃牌")
	assert_eq(error_of(t.act(2, R.RAISE, 30)), "invalid_action")
	assert_eq(error_of(t.act(2, R.ALLIN)), "invalid_action")
	play_as(t, 2, R.CALL)
	assert_eq(t.street(), R.TURN)


func test_incomplete_all_in_raise_does_not_reopen_the_betting():
	var t := make_table([1, 2, 3])
	start_with_button(t, 3, {"stacks": {2: 170}})   # 小盲 1、大盲 2;翻牌后 1 先说话
	check_to_flop(t)
	play_as(t, 1, R.RAISE, 100)
	var shove := _action(play_as(t, 2, R.ALLIN))
	assert_eq([shove["action"], shove["bet"], shove["all_in"]], [R.RAISE, 150, true])
	assert_eq(t.legal_actions(3)["min_raise_to"], 250, "不完整加注不改最近完整增量 100")
	play_as(t, 3, R.CALL)
	var legal := t.legal_actions(1)
	assert_eq([legal["to_call"], legal["can_raise"], legal["can_allin"]], [50, false, false], "只被加了 50 < 100:不重开")
	assert_eq(error_of(t.act(1, R.RAISE, 250)), "invalid_action")
	play_as(t, 1, R.CALL)
	assert_eq(t.street(), R.TURN)


func test_short_all_ins_that_add_up_to_a_full_raise_reopen_the_betting():
	var t := make_table([1, 2, 3, 4])
	start_with_button(t, 4, {"stacks": {2: 170, 3: 220}})   # 小盲 1、大盲 2;翻牌后 1 先说话
	check_to_flop(t)
	play_as(t, 1, R.RAISE, 100)
	play_as(t, 2, R.ALLIN)    # 150:增量 50
	play_as(t, 3, R.ALLIN)    # 200:又 50,累计 100
	play_as(t, 4, R.CALL)
	var legal := t.legal_actions(1)
	assert_eq([legal["to_call"], legal["can_raise"], legal["min_raise_to"]], [100, true, 300], "累计被加注 100 ≥ 完整增量:重开")
	play_as(t, 1, R.RAISE, 300)
	assert_true(t.legal_actions(4)["can_raise"], "完整加注让已跟注的人也能再加")


func test_raise_below_the_minimum_is_only_possible_as_all_in():
	var t := make_table([1, 2, 3])
	start_with_button(t, 3, {"stacks": {2: 170}})   # 翻牌后 2 只剩 150
	check_to_flop(t)
	play_as(t, 1, R.RAISE, 100)
	var legal := t.legal_actions(2)
	assert_eq([legal["to_call"], legal["can_raise"], legal["min_raise_to"], legal["max_raise_to"]], [100, true, 150, 150],
		"筹码不够最小加注 200:最少加注封顶为全下额")
	assert_eq(error_of(t.act(2, R.RAISE, 160)), "invalid_amount")
	var shove := _action(play_as(t, 2, R.RAISE, 150))
	assert_eq([shove["bet"], shove["stack"], shove["all_in"]], [150, 0, true], "加注到全部筹码 = 全下")
	assert_eq(t.player(2)["status"], R.STATUS_ALLIN)


func test_cannot_raise_when_every_opponent_is_all_in():
	var t := make_table([1, 2])
	start_with_button(t, 1, {"stacks": {2: 500}})   # 单挑:按钮 1 下小盲
	play_as(t, 1, R.RAISE, 100)
	play_as(t, 2, R.ALLIN)
	var legal := t.legal_actions(1)
	assert_eq([legal["to_call"], legal["call_amount"], legal["can_raise"], legal["can_allin"]], [400, 400, false, false])
	assert_eq(error_of(t.act(1, R.RAISE, 1000)), "invalid_action")
	assert_eq(error_of(t.act(1, R.ALLIN)), "invalid_action", "全下只在 can_allin 时合法")
	var events := play_as(t, 1, R.CALL)
	assert_eq(H.find(events, "reveal")["reason"], "allin")
	assert_eq(t.phase(), PokerTable.Phase.IDLE)


func test_all_in_for_less_than_the_call_counts_as_a_call():
	var t := make_table([1, 2])
	start_with_button(t, 1, {"stacks": {1: 300}})
	play_as(t, 1, R.CALL)
	play_as(t, 2, R.RAISE, 500)
	var legal := t.legal_actions(1)
	assert_eq([legal["to_call"], legal["call_amount"], legal["can_raise"], legal["can_allin"]], [480, 280, false, true])
	var events := play_as(t, 1, R.ALLIN)
	var call := _action(events)
	assert_eq([call["action"], call["amount"], call["bet"], call["all_in"]], [R.CALL, 280, 300, true])
	assert_eq(H.find(events, "bets_collected")["refund"], {"pid": 2, "amount": 200}, "没人跟的 200 退回")


func test_uncalled_part_goes_back_down_to_the_second_highest_bet_even_if_that_player_folded():
	# 规格 §2.4 的例子:X 下注 300、Y 全下跟 100、Z 加注到 900、X 弃牌 → Z 退回 600(不是 800)
	var t := make_table([1, 2, 3])
	start_with_button(t, 3, {"stacks": {2: 120}})   # 小盲 1、大盲 2;翻牌后 1 先说话
	check_to_flop(t)
	play_as(t, 1, R.RAISE, 300)
	var call := _action(play_as(t, 2, R.CALL))
	assert_eq([call["amount"], call["all_in"]], [100, true], "筹码不够跟:全下跟注")
	play_as(t, 3, R.RAISE, 900)
	var events := play_as(t, 1, R.FOLD)
	assert_eq(H.find(events, "bets_collected")["refund"], {"pid": 3, "amount": 600})
	assert_eq(H.find(events, "reveal")["reason"], "allin", "Z 不欠跟注、Y 已全下:直接发完")


func test_first_actor_after_the_flop_skips_all_in_and_folded_players():
	var t := make_table([1, 2, 3, 4])
	start_with_button(t, 4, {"stacks": {1: 100}})   # 小盲 1、大盲 2,3 先说话
	play_as(t, 3, R.CALL)
	play_as(t, 4, R.CALL)
	play_as(t, 1, R.ALLIN)
	play_as(t, 2, R.FOLD)
	play_as(t, 3, R.CALL)
	var events := play_as(t, 4, R.CALL)
	assert_eq(H.find(events, "street")["street"], R.FLOP)
	assert_eq(H.find(events, "turn")["pid"], 3, "按钮之后的 1 已全下、2 已弃牌")


func test_big_blind_has_the_option_to_raise_when_everyone_limps():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)
	play_as(t, 1, R.CALL)
	play_as(t, 2, R.CALL)
	assert_eq(t.current_pid(), 3, "下盲不算行动:大盲还要说话")
	var legal := t.legal_actions(3)
	assert_eq([legal["to_call"], legal["can_check"], legal["can_raise"], legal["min_raise_to"]], [0, true, true, 40])
	play_as(t, 3, R.RAISE, 60)
	assert_eq(t.street(), R.PREFLOP)
	assert_eq(t.current_pid(), 1, "完整加注后跟过的人要重新表态")
	assert_eq(t.legal_actions(1)["to_call"], 40)


func test_round_end_collects_bets_deals_the_flop_and_starts_after_the_button():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)
	play_as(t, 1, R.CALL)
	play_as(t, 2, R.CALL)
	var events := play_as(t, 3, R.CHECK)
	assert_eq(H.types(events), ["action", "bets_collected", "street", "turn"])
	assert_eq(H.find(events, "bets_collected"), {"type": "bets_collected", "pots": [{"amount": 60, "eligible": [1, 2, 3]}], "refund": {}})
	var flop := H.find(events, "street")
	assert_eq([flop["street"], flop["cards"].size(), flop["board"]], [R.FLOP, 3, flop["cards"]])
	assert_eq(H.find(events, "turn")["pid"], 2, "翻牌后从按钮之后第一位开始")
	assert_eq([t.board(), t.pots(), t.current_bet()], [flop["cards"], [{"amount": 60, "eligible": [1, 2, 3]}], 0])
	for pid in [1, 2, 3]:
		assert_eq([t.player(pid)["bet"], t.player(pid)["committed"]], [0, 20])
	play_as(t, 2, R.CHECK)
	play_as(t, 3, R.CHECK)
	events = play_as(t, 1, R.CHECK)
	assert_eq(H.types(events), ["action", "street", "turn"], "都过牌:没有收注")
	assert_eq(H.find(events, "street")["board"].size(), 4)


func test_everyone_folds_to_the_big_blind_who_gets_the_extra_ten_back_without_showing():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)
	play_as(t, 1, R.FOLD)
	var events := play_as(t, 2, R.FOLD)
	assert_eq(H.types(events), ["action", "bets_collected", "pot_won", "hand_over", "hand_record"])
	assert_eq(H.find(events, "bets_collected")["refund"], {"pid": 3, "amount": 10})
	assert_eq(H.find(events, "pot_won"), {
		"type": "pot_won", "index": 0, "amount": 20, "winners": [3], "shares": {3: 20},
		"hand_name": "", "best": {}, "uncontested": true,
	})
	assert_eq(H.find(events, "hand_over")["stacks"], {1: 2000, 2: 1990, 3: 2010})
	assert_no_card_leak(t, events, 3)
	assert_eq(t.phase(), PokerTable.Phase.IDLE)


func test_winning_without_a_showdown_after_the_flop_leaks_no_cards_or_hand_name():
	var t := make_table([1, 2, 3])
	var all_events := start_with_button(t, 1)
	all_events.append_array(check_to_flop(t))
	all_events.append_array(play_as(t, 2, R.RAISE, 40))
	all_events.append_array(play_as(t, 3, R.FOLD))
	var last := play_as(t, 1, R.FOLD)
	all_events.append_array(last)
	assert_eq(H.find(last, "bets_collected")["refund"], {"pid": 2, "amount": 40})
	assert_eq(H.find(last, "pot_won")["amount"], 60)
	assert_eq(t.board().size(), 3)
	assert_eq(t.street(), R.FLOP, "两手之间 street 停在结束时的街")
	assert_no_card_leak(t, all_events, 2)


func test_timeout_checks_when_free_and_folds_when_facing_a_bet():
	var t := make_table([1, 2, 3])
	assert_eq(error_of(t.timeout_action()), "no_hand")
	start_with_button(t, 1)
	var result := t.timeout_action()
	assert_true(result["ok"])
	var fold := _action(result["events"])
	assert_eq([fold["pid"], fold["action"], fold["timeout"]], [1, R.FOLD, true])
	var call := _action(play_as(t, 2, R.CALL))
	assert_false(call["timeout"])
	var check := _action(t.timeout_action()["events"])
	assert_eq([check["pid"], check["action"], check["timeout"]], [3, R.CHECK, true])
	assert_eq(t.street(), R.FLOP)


# —— 小工具 ——

func check_to_flop(t: PokerTable) -> Array:
	# 翻牌前大家跟到大盲、大盲过牌
	var events := []
	while t.street() == R.PREFLOP:
		var legal := t.legal_actions(t.current_pid())
		events.append_array(play(t, R.CHECK if legal["can_check"] else R.CALL))
	return events
