extends "res://tests/poker_screen_harness.gd"
# 德州牌桌的边角情形(任务 7b 审查发现的问题各一条回归):迟到者开场运镜期间开了新的一手、
# 手牌中途有人全下后离开、旁人的事件不重置已调好的加注额、结算面板下不再露出输光提示也不拉回机位、
# 再领只等自己的回执、旧的弃牌确认在换了行动者后作废。


func _hand1() -> void:
	await _feed([{"type": "hand_started", "hand": 1, "button": 1, "sb": 2, "bb": 3, "seats": [1, 2, 3], "dealt": [2, 3, 1]},
		_blind(2, "sb", 10), _blind(3, "bb", 20), {"type": "hole_cards", "hand": 1, "pids": [2, 3, 1]}, {"type": "turn", "pid": ME}],
		_pub(ME), {"hand": 1, "hole": H.cards("Ah Kd"), "best": {}})


func _join_as_waiting(pid: int) -> void:
	stacks[pid] = PokerRules.STARTING_STACK
	statuses[pid] = PokerRules.STATUS_WAITING
	bets[pid] = 0
	shown[pid] = []


func test_late_joiner_dealt_in_during_the_intro_gets_a_seat_and_a_patron():
	# 两手之间加入:房主 1.5 秒后开下一手,迟到者的开场运镜 1.7 秒,hand_started 在运镜期间到达并被第一帧丢掉
	_open_table([2, 3], true)
	_join_as_waiting(ME)
	screen._on_events([{"type": "player_joined", "pid": ME, "name": "我"}])
	screen._on_public(_pub(null))
	seats = [2, 3, 1]
	for pid in seats:
		statuses[pid] = PokerRules.STATUS_ACTIVE
	await _feed([{"type": "hand_started", "hand": 2, "button": 3, "sb": 1, "bb": 2, "seats": [2, 3, 1], "dealt": [1, 2, 3]},
		_blind(ME, "sb", 10), _blind(2, "bb", 20), {"type": "hole_cards", "hand": 2, "pids": [1, 2, 3]}, {"type": "turn", "pid": 3}],
		_pub(3, {"hand": 2, "button": 3, "sb": 1, "bb": 2}), {"hand": 2, "hole": H.cards("Ah Kd"), "best": {}})
	assert_eq(screen.state.seats, [2, 3, 1])
	assert_true(app.world.patrons.has(ME), "第一帧按视图重排:自己的酒客登场")
	assert_eq(app.world.patrons[ME].fan.get_child_count(), 2, "自己的两张手牌在牌扇里")
	assert_eq(screen.director.camera_mode(), PokerDirector.MODE_SEAT)
	assert_eq(screen.state.current_pid, 3, "行动者从视图取")


func test_a_departed_all_in_player_keeps_his_seat_for_the_reveal():
	_open_table([1, 2, 3], false)
	await _hand1()
	await _feed([_bet(ME, PokerRules.CALL, 20), _bet(2, PokerRules.CALL, 20), _bet(3, PokerRules.RAISE, 2000, true),
		{"type": "turn", "pid": ME}], _pub(ME, {"current_bet": 2000}))
	seats = [1, 2]
	var pub := _pub(ME, {"current_bet": 2000})
	for p in pub["players"]:
		if p["pid"] == 3:
			p["left"] = true
	await _feed([{"type": "player_left", "pid": 3, "folded": false}], pub)
	assert_true(app.world.seat_angles.has(3), "同一手里不重排:离场者的座位留到下一手")
	assert_false(_live_patrons().has(3), "但他的酒客已经离场")
	assert_gt(screen.chips.bet_amount(3), 0, "他留在桌上的注还在")
	await screen.director.play({"type": "reveal", "hands": [{"pid": 3, "cards": H.cards("Qh Qs")}], "reason": "showdown"})
	var card: Node3D = screen.cards.shown_cards(3)[0]
	var mine := PokerLayout.shown_card(0.0, app.world.table_radius, 0).origin
	assert_gt(card.position.distance_to(mine), 0.2, "他亮的牌摆在他的座位前,不在本机座位前")


func test_unrelated_events_keep_my_chosen_raise_amount():
	_open_table([1, 2, 3], false)
	await _hand1()
	assert_true(screen.is_my_turn())
	screen.hud.controls.set_amount(200)
	_join_as_waiting(9)
	await _feed([{"type": "player_joined", "pid": 9, "name": "迟到"}], _pub(ME))
	assert_true(screen.is_my_turn())
	assert_eq(screen.hud.controls.amount(), 200, "同一回合:旁人的事件不把金额打回最小加注")


func test_settlement_keeps_the_orbit_and_hides_the_bust_prompt():
	_open_table([1, 2, 3], false)
	await _hand1()
	stacks[ME] = 0
	statuses[ME] = PokerRules.STATUS_BUSTED
	var results := [{"pid": 1, "name": "我", "stack": 0, "buyins": 1, "net": -2000, "left": false}]
	await _feed([{"type": "hand_over", "hand": 1, "stacks": {1: 0}, "busted": [1]}, {"type": "session_over", "results": results}],
		_pub(null, {"phase": "over", "results": results}))
	screen._on_public(_pub(null, {"phase": "over", "results": results}))
	assert_not_null(screen._settlement)
	assert_eq(screen.director.camera_mode(), PokerDirector.MODE_ORBIT, "结算时留在散局环绕镜头")
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_NONE, "结算面板下不露出输光提示")
	assert_lt(screen._bust_left, 0.0, "输光倒计时停了")
	assert_false(screen.choose_rebuy(), "散局后不能再领")


func test_seat_requests_wait_for_their_own_receipt():
	_open_table([1, 2, 3], false)
	await _hand1()
	statuses[ME] = PokerRules.STATUS_BUSTED
	stacks[ME] = 0
	await _feed([{"type": "hand_over", "hand": 1, "stacks": {1: 0}, "busted": [1]}], _pub(null))
	assert_true(screen.choose_rebuy())
	_join_as_waiting(9)
	await _feed([{"type": "player_joined", "pid": 9, "name": "迟到"}], _pub(null))
	assert_false(screen.choose_rebuy(), "别人的事件不算回执:不重复发")
	assert_false(screen.choose_spectate())
	statuses[ME] = PokerRules.STATUS_WAITING
	stacks[ME] = PokerRules.STARTING_STACK
	await _feed([{"type": "rebuy", "pid": ME, "amount": 2000, "buyins": 2, "stack": 2000}], _pub(null))
	assert_false(screen._seat_request_pending, "自己的回执到了")


func test_a_stale_fold_confirm_is_dropped_when_the_turn_moves_on():
	_open_table([1, 2, 3], false)
	await _hand1()
	screen._confirm_fold()
	var overlay: ConfirmOverlay = screen._fold_confirm
	assert_true(is_instance_valid(overlay))
	await _feed([_bet(ME, PokerRules.CALL, 20), {"type": "turn", "pid": 2}], _pub(2))
	await wait_process_frames(2)
	assert_false(is_instance_valid(overlay), "换了行动者,旧的弃牌确认作废")
