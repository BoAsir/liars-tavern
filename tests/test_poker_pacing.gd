extends GutTest
# 德州演出预算(纯函数):各事件计价、交出回合的批次、房主回合计时。
# 导演实际时长不超过预算的检查放在 PokerDirector 的测试里(读取导演的节奏常量)。


func test_empty_and_unknown_batches_are_free():
	assert_eq(PokerPacing.estimate([]), 0.0)
	assert_eq(PokerPacing.estimate([{"type": "mystery"}, {"type": "turn", "pid": 1}]), 0.0)


func test_hole_cards_scale_with_players():
	var two := PokerPacing.estimate([{"type": "hole_cards", "hand": 1, "pids": [1, 2]}])
	var eight := PokerPacing.estimate([{"type": "hole_cards", "hand": 1, "pids": [1, 2, 3, 4, 5, 6, 7, 8]}])
	assert_almost_eq(two, PokerPacing.HOLE_BASE + PokerPacing.HOLE_PER_CARD * 4, 0.001)
	assert_almost_eq(eight - two, PokerPacing.HOLE_PER_CARD * 12, 0.001)


func test_all_in_costs_more_than_a_plain_action():
	var plain := PokerPacing.estimate([{"type": "action", "pid": 1, "action": "call", "all_in": false}])
	var shove := PokerPacing.estimate([{"type": "action", "pid": 1, "action": "raise", "all_in": true}])
	assert_almost_eq(plain, PokerPacing.ACTION, 0.001)
	assert_almost_eq(shove, PokerPacing.ACTION_ALLIN, 0.001)


func test_flop_costs_more_than_turn():
	var flop := PokerPacing.estimate([{"type": "street", "street": "flop", "cards": [8, 9, 10]}])
	var turn := PokerPacing.estimate([{"type": "street", "street": "turn", "cards": [11]}])
	assert_almost_eq(flop - turn, PokerPacing.STREET_PER_CARD * 2, 0.001)


func test_full_hand_end_batch_sums_segments():
	var events := [
		{"type": "action", "pid": 2, "action": "call", "all_in": false},
		{"type": "bets_collected", "pots": [], "refund": {}},
		{"type": "reveal", "hands": [{"pid": 1, "cards": []}, {"pid": 2, "cards": []}], "reason": "showdown"},
		{"type": "pot_won", "index": 0},
		{"type": "hand_over", "hand": 3, "stacks": {}, "busted": []},
	]
	var expected := PokerPacing.ACTION + PokerPacing.BETS_COLLECTED + PokerPacing.REVEAL_BASE \
		+ PokerPacing.REVEAL_PER_HAND * 2 + PokerPacing.POT_WON + PokerPacing.HAND_OVER
	assert_almost_eq(PokerPacing.estimate(events), expected, 0.001)


func test_only_turn_events_hand_over_the_turn():
	assert_true(PokerPacing.starts_turn([{"type": "action", "pid": 1}, {"type": "turn", "pid": 2}]))
	assert_false(PokerPacing.starts_turn([{"type": "rebuy", "pid": 3}]))
	assert_false(PokerPacing.starts_turn([{"type": "hand_over", "hand": 1}]))


func test_turn_timer_restarts_full_after_a_turn_batch():
	var events := [{"type": "action", "pid": 1, "all_in": false}, {"type": "turn", "pid": 2}]
	assert_almost_eq(PokerPacing.turn_timer_after(events, 2.0, 11.0), 2.0 + Protocol.TURN_TIMEOUT, 0.001)


func test_bystander_batches_keep_the_running_turn_time():
	var events := [{"type": "rebuy", "pid": 4}]
	assert_almost_eq(PokerPacing.turn_timer_after(events, 0.6, 12.0), 12.0 + PokerPacing.REBUY, 0.001)


func test_bust_decision_gap_is_longer_than_the_plain_hand_gap():
	# 有人输光的那一手之后,下一手晚一点开,留时间给他选再领/观战(规格 §2.6);选完就恢复普通间隔
	assert_gt(PokerPacing.BUST_DECISION, PokerPacing.HAND_GAP)
	assert_almost_eq(PokerPacing.BUST_DECISION, 6.0, 0.001)


func test_seat_status_events_take_no_show_time():
	assert_eq(PokerPacing.estimate([{"type": "away", "pid": 1}, {"type": "sit_in", "pid": 1}, {"type": "spectate", "pid": 2}]), 0.0)
