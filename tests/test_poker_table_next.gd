extends "res://tests/poker_table_case.gd"
# 一手结束后的「开始下一手」确认与牌局记录:
# - 要确认的人 = 没离开、不在观战 / 离座的人(含输光还没选的、中途加入等发牌的);再领算确认,选观战就不用确认。
# - 确认只在两手之间有效;新的一手开始时清空。
# - 每手结束发 hand_record:公共牌、每个被发到牌的人的两张手牌(含弃牌的)、牌型、这一手的输赢。


func _next(t: PokerTable, pid: int) -> Dictionary:
	return t.confirm_next(pid)


func test_confirm_only_between_hands():
	var t := make_table([1, 2, 3])
	assert_eq(error_of(_next(t, 1)), "invalid_action", "还没打过一手")
	start_with_button(t, 1)
	assert_eq(error_of(_next(t, 1)), "invalid_action", "手牌进行中")
	fold_out(t)
	var result := _next(t, 1)
	assert_true(result["ok"])
	assert_eq(result["events"], [{"type": "next_ready", "pid": 1}])
	assert_true(t.is_confirmed(1))
	assert_true(t.player(1)["confirmed"])
	assert_eq(_next(t, 1)["events"], [], "重复确认没有事件")
	assert_eq(error_of(_next(t, 77)), "not_seated")


func test_everyone_who_will_play_must_confirm():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)
	fold_out(t)
	assert_false(t.all_confirmed())
	_next(t, 1)
	_next(t, 2)
	assert_false(t.all_confirmed())
	_next(t, 3)
	assert_true(t.all_confirmed())
	t.start_hand()
	assert_false(t.is_confirmed(1), "新的一手清空")
	assert_false(t.player(1)["confirmed"])


func _bust_one(t: PokerTable) -> void:
	# 三人局:1 只有 20、全下,2 拿 AA 跟注,3 弃牌 → 1 输光
	start_with_button(t, 1, {"holes": {1: H.cards("7c 2d"), 2: H.cards("Ah Ad")}, "board": H.cards("8c 6h 4d Jc 3s"),
		"stacks": {1: 20}})
	play_as(t, 1, R.ALLIN)
	play_as(t, 2, R.CALL)
	play_as(t, 3, R.FOLD)
	assert_eq(t.player(1)["status"], R.STATUS_BUSTED)


func test_spectators_and_leavers_are_not_waited_for():
	var t := make_table([1, 2, 3])
	_bust_one(t)
	assert_true(t.needs_confirm(1), "输光还没选的人也要等(他可能要再领)")
	_next(t, 2)
	_next(t, 3)
	assert_false(t.all_confirmed())
	assert_true(t.spectate(1)["ok"])
	assert_false(t.needs_confirm(1), "选了观战就不用等他")
	assert_true(t.all_confirmed())
	assert_eq(error_of(_next(t, 1)), "invalid_action", "观战的人不用确认")
	t.remove_player(2)
	assert_false(t.needs_confirm(2), "离开的人不等")


func test_rebuy_counts_as_confirming():
	var t := make_table([1, 2, 3])
	_bust_one(t)
	assert_true(t.rebuy(1)["ok"])
	assert_true(t.is_confirmed(1), "再领就是要接着打")


func test_hand_record_shows_every_dealt_hand_after_the_hand():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1, {"holes": {1: H.cards("Kc Kd"), 2: H.cards("Ah Ad"), 3: H.cards("7s 2h")},
		"board": H.cards("8c 6h 4d Jc 3s")})
	var events := []
	events += play(t, R.CALL)    # 1 按钮跟 20
	events += play(t, R.FOLD)    # 2 小盲弃牌
	events += check_down(t)      # 1、3 过牌到底摊牌
	var record := H.find(events, "hand_record")
	assert_false(record.is_empty(), "一手结束发记录")
	assert_eq(record["hand"], 1)
	assert_eq(record["board"], H.cards("8c 6h 4d Jc 3s"))
	var by_pid := {}
	for row in record["players"]:
		by_pid[row["pid"]] = row
	assert_eq(by_pid.keys().size(), 3, "被发到牌的人都在")
	assert_eq(by_pid[2]["cards"], H.cards("Ah Ad"), "弃牌的人的手牌也记下")
	assert_true(by_pid[2]["folded"])
	assert_eq(by_pid[2]["delta"], -10, "小盲弃牌输 10")
	assert_eq(by_pid[1]["hand_name"], "一对 · K")
	assert_eq(by_pid[1]["delta"], 30, "赢回 20 + 10 + 自己的 20 → 净赢 30")
	assert_eq(by_pid[3]["delta"], -20)
	var total := 0
	for row in record["players"]:
		total += row["delta"]
	assert_eq(total, 0, "这一手输赢之和为 0")
	assert_lt(H.types(events).find("hand_over"), H.types(events).find("hand_record"), "记录跟在 hand_over 后面")


func test_hand_record_before_the_flop_has_no_hand_names():
	var t := make_table([1, 2])
	start_with_button(t, 1)
	var events := fold_out(t)
	var record := H.find(events, "hand_record")
	for row in record["players"]:
		assert_eq(row["hand_name"], "", "没翻牌没有牌型")
		assert_eq(row["cards"].size(), 2)
