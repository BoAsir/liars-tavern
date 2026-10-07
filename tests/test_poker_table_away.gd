extends "res://tests/poker_table_case.gd"
# 挂机离座(规格 §2.8):连续 2 次超时 → 从下一手起 away(保留筹码、不发牌、按钮与盲注跳过他);
# sit_in 回到 waiting、下一手发牌;他自己的任何一次行动都把连续超时清零。


func _timeout_as(t: PokerTable, pid: int) -> Array:
	assert_eq(t.current_pid(), pid, "应该轮到 %d" % pid)
	var result := t.timeout_action()
	assert_true(result["ok"])
	return result["events"]


func _send_four_away(t: PokerTable) -> Array:
	# 四人局里 4 连续两手超时弃牌,返回第二手结束那批事件
	start_with_button(t, 1)              # 小盲 2、大盲 3,4 先说话
	_timeout_as(t, 4)
	var first := fold_out(t)
	assert_false(H.types(first).has("away"), "只超时一次不离座")
	var started := H.find(t.start_hand(), "hand_started")
	assert_eq([started["button"], started["sb"], started["bb"]], [2, 3, 4])
	play_as(t, 1, R.RAISE, 60)
	play_as(t, 2, R.FOLD)
	play_as(t, 3, R.FOLD)
	return _timeout_as(t, 4)


func test_two_timeouts_in_a_row_send_the_player_away_at_the_end_of_the_hand():
	var t := make_table([1, 2, 3, 4])
	var events := _send_four_away(t)
	assert_eq(H.types(events).slice(-2), ["hand_over", "away"])
	assert_eq(events.back(), {"type": "away", "pid": 4})
	assert_eq([t.player(4)["status"], t.player(4)["stack"]], [R.STATUS_AWAY, 1980], "保留筹码:只下过一次大盲")
	assert_eq(t.seats_with_patrons(), [1, 2, 3, 4], "离座的人留在座位上")


func test_away_player_is_not_dealt_and_the_button_and_blinds_skip_him():
	var t := make_table([1, 2, 3, 4])
	_send_four_away(t)
	var started := H.find(t.start_hand(), "hand_started")
	assert_eq(started["seats"], [1, 2, 3, 4])
	assert_eq([started["button"], started["sb"], started["bb"]], [3, 1, 2], "按钮 3 之后本该是 4 下小盲:跳过离座的人")
	assert_eq(started["dealt"], [1, 2, 3])
	assert_eq(t.hole_cards(4), [])
	assert_eq(t.player(4)["status"], R.STATUS_AWAY)
	assert_eq(error_of(t.rebuy(4)), "cannot_rebuy", "有筹码,不是输光")
	assert_eq(error_of(t.spectate(4)), "invalid_action")


func test_sit_in_returns_to_waiting_and_is_dealt_the_next_hand():
	var t := make_table([1, 2, 3, 4])
	_send_four_away(t)
	assert_eq(error_of(t.sit_in(1)), "invalid_action", "只有离座的人能回到牌桌")
	assert_eq(error_of(t.sit_in(99)), "not_seated")
	t.start_hand()
	assert_eq(t.sit_in(4), {"ok": true, "events": [{"type": "sit_in", "pid": 4}]}, "手牌进行中也能点,下一手才发牌")
	assert_eq(t.player(4)["status"], R.STATUS_WAITING)
	assert_eq(t.hole_cards(4), [])
	fold_out(t)
	assert_has(H.find(t.start_hand(), "hand_started")["dealt"], 4)


func test_acting_once_between_timeouts_resets_the_count():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)              # 小盲 2、大盲 3
	_timeout_as(t, 1)
	fold_out(t)
	t.start_hand()                       # 按钮 2、小盲 3、大盲 1
	play_as(t, 2, R.RAISE, 60)
	play_as(t, 3, R.FOLD)
	play_as(t, 1, R.FOLD)                # 自己行动一次:清零
	t.start_hand()                       # 按钮 3、小盲 1、大盲 2
	play_as(t, 3, R.RAISE, 60)
	var events := _timeout_as(t, 1)
	events.append_array(fold_out(t))
	assert_false(H.types(events).has("away"), "清零后只算一次超时")
	assert_eq(t.player(1)["status"], R.STATUS_FOLDED)


func test_two_timeouts_inside_one_hand_also_count():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)
	play_as(t, 1, R.CALL)
	play_as(t, 2, R.CALL)
	_timeout_as(t, 3)                    # 大盲不欠跟注:过牌
	assert_eq(t.street(), R.FLOP)
	play_as(t, 2, R.CHECK)
	_timeout_as(t, 3)                    # 又过牌
	play_as(t, 1, R.RAISE, 40)
	play_as(t, 2, R.FOLD)
	var events := _timeout_as(t, 3)      # 面对下注:弃牌
	assert_eq(events.back(), {"type": "away", "pid": 3})


func test_heads_up_with_one_player_away_waits_until_he_sits_in():
	var t := make_table([1, 2])
	start_with_button(t, 1)              # 单挑:按钮 1 下小盲先说话
	_timeout_as(t, 1)
	t.start_hand()                       # 按钮 2 先说话
	play_as(t, 2, R.RAISE, 60)
	var events := _timeout_as(t, 1)
	assert_eq(events.back(), {"type": "away", "pid": 1})
	assert_false(t.can_start_hand(), "只剩一个能上桌的人:牌桌等待")
	assert_eq(t.start_hand(), [])
	t.sit_in(1)
	assert_true(t.can_start_hand())


func test_no_one_is_sent_away_when_the_session_is_ending():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)
	_timeout_as(t, 1)
	fold_out(t)
	t.start_hand()                       # 按钮 2、小盲 3、大盲 1
	t.request_end()
	play_as(t, 2, R.RAISE, 60)
	play_as(t, 3, R.FOLD)
	var events := _timeout_as(t, 1)
	assert_eq(H.types(events).slice(-2), ["hand_over", "session_over"])
	assert_eq(t.results().size(), 3)
