extends "res://tests/poker_screen_harness.gd"
# 德州牌桌整体流程(无头,加速演出):真实的 PokerScreen + PokerDirector + PokerChips / PokerCards + HUD,
# 用假的 app 直接喂视图与事件,走完:开局发牌 → 自己行动 → 翻牌 → 全下亮牌 → 分池 → 输光 → 观战 → 再领 →
# 有人中途加入、有人离开 → 下一手重排座位 → 房主散局 → 结算 → 退场拆台。
# 每一步都断言 3D 与 HUD 的状态;引擎错误(缺前置状态的事件、空引用)会让 GUT 判失败(规格 §7 的容错)。


# —— 一整局 ——

func test_a_whole_session_from_deal_to_settlement():
	_open_table([1, 2, 3], false)
	assert_eq(app.modes, [GameMode.HOLDEM], "进牌桌按玩法摆桌")
	assert_eq(_live_patrons().size(), 3)
	assert_true(screen.animating, "开场运镜中")
	# 第一手:下盲、发牌、轮到自己(按钮 1,小盲 2,大盲 3)
	var hole := H.cards("Ah Kd")
	await _feed([{"type": "hand_started", "hand": 1, "button": 1, "sb": 2, "bb": 3, "seats": [1, 2, 3], "dealt": [2, 3, 1]},
		_blind(2, "sb", 10), _blind(3, "bb", 20), {"type": "hole_cards", "hand": 1, "pids": [2, 3, 1]}, {"type": "turn", "pid": ME}],
		_pub(ME), {"hand": 1, "hole": hole, "best": {}})
	assert_true(screen.is_my_turn())
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_BET)
	assert_true(screen.hud.controls.is_my_turn())
	assert_eq(screen.chips.stack_amount(2), 1990)
	assert_eq(screen.chips.bet_amount(3), 20)
	assert_eq(screen.chips.button_pid(), 1)
	assert_eq(screen.hud.my_strip.cards(), hole)
	assert_eq(app.world.patrons[ME].fan.get_child_count(), 2, "自己的两张手牌举在手里")
	assert_not_null(_plate(2))
	assert_not_null(_plate(3))
	assert_null(_plate(ME), "自己没有铭牌")
	assert_eq(screen.director.camera_mode(), PokerDirector.MODE_SEAT)
	assert_true(screen.director.is_at_seat())
	# 自己跟注 → 小盲弃牌 → 大盲过牌 → 收注 → 翻牌 → 轮到大盲
	assert_true(screen.submit(PokerRules.CALL))
	assert_false(screen.is_my_turn(), "等回执")
	var flop := H.cards("Qc 7h 2s")
	await _feed([_bet(ME, PokerRules.CALL, 20), _bet(2, PokerRules.FOLD, 10), _bet(3, PokerRules.CHECK, 20), _collect(),
		{"type": "street", "street": PokerRules.FLOP, "cards": flop, "board": flop}, {"type": "turn", "pid": 3}],
		_pub(3, {"street": PokerRules.FLOP, "board": flop, "pots": [{"amount": 50, "eligible": [1, 3]}], "current_bet": 0}),
		{"hand": 1, "hole": hole, "best": {"detail": "高牌 · A", "cards": hole + flop}})
	assert_false(screen.is_my_turn())
	assert_eq(screen.cards.board_cards().size(), 3)
	assert_eq(screen.hud.board_strip.cards(), flop)
	assert_eq(screen.chips.pot_amounts(), [50])
	assert_eq(screen.cards.muck_cards().size(), 2, "弃的牌在弃牌堆")
	assert_eq(screen.hud._best_label.text, "高牌 · A")
	assert_eq(screen.state.row(3)["status"], PokerRules.STATUS_ACTIVE)
	# 大盲全下,自己跟注全下 → 亮牌 → 发完转牌河牌 → 分池 → 自己输光
	await _feed([_bet(3, PokerRules.RAISE, 1980, true), {"type": "turn", "pid": ME}], _pub(ME, {"street": PokerRules.FLOP, "board": flop,
		"pots": [{"amount": 50, "eligible": [1, 3]}], "current_bet": 1980}))
	assert_true(screen.is_my_turn())
	assert_eq(screen.state.row(3)["status"], PokerRules.STATUS_ALLIN)
	var turn := H.cards("Qd")
	var river := H.cards("9s")
	var board := flop + turn + river
	shown[3] = H.cards("Qh Qs")
	shown[ME] = hole
	var win := _bet(ME, PokerRules.CALL, 1980, true)
	stacks[3] = 4010
	stacks[2] = 1990
	stacks[ME] = 0
	statuses[ME] = PokerRules.STATUS_BUSTED
	await _feed([win, {"type": "bets_collected", "pots": [{"amount": 4010, "eligible": [1, 3]}], "refund": {}},
		{"type": "reveal", "hands": [{"pid": 3, "cards": shown[3]}, {"pid": ME, "cards": hole}], "reason": "allin"},
		{"type": "street", "street": PokerRules.TURN, "cards": turn, "board": flop + turn},
		{"type": "street", "street": PokerRules.RIVER, "cards": river, "board": board},
		{"type": "pot_won", "index": 0, "amount": 4010, "winners": [3], "shares": {3: 4010}, "hand_name": "四条 · Q",
			"best": {3: H.cards("Qc Qd Qh Qs 9s")}, "uncontested": false},
		{"type": "hand_over", "hand": 1, "stacks": {1: 0, 2: 1990, 3: 4010}, "busted": [1]}],
		_pub(null, {"street": PokerRules.SHOWDOWN, "board": board, "current_bet": 0}), {"hand": 1, "hole": hole, "best": {}})
	assert_eq(screen.my_status(), PokerRules.STATUS_BUSTED)
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_BUST, "输光提示")
	assert_gt(screen._bust_left, 0.0, "带倒计时")
	assert_eq(screen.chips.stack_amount(3), 4010)
	assert_eq(screen.chips.pot_amounts(), [])
	assert_eq(screen.cards.shown_cards(3).size(), 2, "亮出的牌摊在座位前")
	assert_true(screen.hud.showdown.visible, "一手结束后摊牌面板还在,到下一手开始才收")
	assert_eq(screen.hud.showdown.row_count(), 2, "两人亮了牌")
	assert_eq(screen.state.showdown_entries(false)[0]["won"], 4010, "赢家排第一、带赢到的数")
	assert_false(screen.is_my_turn())
	# 观战:酒客本机隐藏、镜头到观战机位;随后再领回座
	statuses[ME] = PokerRules.STATUS_SPECTATING
	await _feed([{"type": "spectate", "pid": ME}], _pub(null, {"street": PokerRules.SHOWDOWN, "board": board, "current_bet": 0}))
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_SPECTATE)
	assert_false(app.world.patrons[ME].visible)
	await wait_until(func(): return screen.director.is_camera_at_rest(), MAX_WAIT)
	assert_eq(screen.director.camera_mode(), PokerDirector.MODE_OVERVIEW)
	assert_false(screen.director.is_at_seat())
	statuses[ME] = PokerRules.STATUS_WAITING
	stacks[ME] = 2000
	stacks[9] = 2000
	statuses[9] = PokerRules.STATUS_WAITING
	bets[9] = 0
	shown[9] = []
	await _feed([{"type": "player_joined", "pid": 9, "name": "迟到"}, {"type": "rebuy", "pid": ME, "amount": 2000, "buyins": 2, "stack": 2000}],
		_pub(null, {"street": PokerRules.SHOWDOWN, "board": board, "current_bet": 0}))
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_WAITING)
	assert_true(app.world.patrons[ME].visible)
	assert_eq(screen.chips.stack_amount(ME), 2000)
	assert_false(_live_patrons().has(9), "新人下一手才登场")
	assert_eq(screen.name_of(9), "迟到")
	await wait_until(func(): return screen.director.is_camera_at_rest(), MAX_WAIT)
	assert_eq(screen.director.camera_mode(), PokerDirector.MODE_SEAT)
	# 乙离开(不在手牌中):酒客离场、铭牌收走;下一手按新座位表重排,新人登场
	stacks.erase(2)
	seats = [1, 3]
	await _feed([{"type": "player_left", "pid": 2, "folded": false}], _pub(null, {"street": PokerRules.SHOWDOWN, "board": board, "current_bet": 0}))
	await wait_process_frames(2)
	assert_false(_live_patrons().has(2))
	assert_null(_plate(2))
	seats = [1, 3, 9]
	for pid in seats:
		statuses[pid] = PokerRules.STATUS_ACTIVE
		shown[pid] = []
	var hole2 := H.cards("7c 7d")
	await _feed([{"type": "hand_started", "hand": 2, "button": 3, "sb": 9, "bb": 1, "seats": [1, 3, 9], "dealt": [9, 1, 3]},
		_blind(9, "sb", 10), _blind(ME, "bb", 20), {"type": "hole_cards", "hand": 2, "pids": [9, 1, 3]}, {"type": "turn", "pid": 3}],
		_pub(3, {"hand": 2, "button": 3, "sb": 9, "bb": 1}), {"hand": 2, "hole": hole2, "best": {}})
	assert_eq(_live_patrons().size(), 3)
	assert_true(_live_patrons().has(9))
	assert_not_null(_plate(9))
	assert_not_null(_plate(3))
	assert_eq(screen.chips.button_pid(), 3)
	assert_eq(screen.cards.board_cards().size(), 0, "上一手的公共牌收走")
	assert_false(screen.hud.showdown.visible, "新一手开始收起摊牌面板")
	assert_eq(screen.cards.shown_cards(3).size(), 0)
	assert_eq(screen.hud.my_strip.cards(), hole2)
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_BET, "看别人的回合横幅")
	assert_false(screen.is_my_turn())
	# 房主散局:本手结束后结算;对手都弃牌,自己赢;结算面板
	await _feed([{"type": "ending"}], _pub(3, {"hand": 2, "button": 3, "sb": 9, "bb": 1, "ending": true}))
	assert_true(screen.hud.end_button.disabled)
	assert_eq(screen.hud.end_button.text, PokerHud.ENDING_TEXT)
	var results := [{"pid": 3, "name": "丙", "stack": 4010, "buyins": 1, "net": 2010, "left": false},
		{"pid": 1, "name": "我", "stack": 2030, "buyins": 2, "net": -1970, "left": false},
		{"pid": 9, "name": "迟到", "stack": 1990, "buyins": 1, "net": -10, "left": false},
		{"pid": 2, "name": "乙", "stack": 1990, "buyins": 1, "net": -10, "left": true}]
	var folds := [_bet(3, PokerRules.FOLD, 0), _bet(9, PokerRules.FOLD, 10)]
	stacks[ME] = 2030
	for pid in seats:
		bets[pid] = 0
	await _feed(folds + [{"type": "bets_collected", "pots": [{"amount": 30, "eligible": [1]}], "refund": {}},
		{"type": "pot_won", "index": 0, "amount": 30, "winners": [1], "shares": {1: 30}, "hand_name": "", "best": {}, "uncontested": true},
		{"type": "hand_over", "hand": 2, "stacks": {1: 2030, 3: 4010, 9: 1990}, "busted": []},
		{"type": "session_over", "results": results}],
		_pub(null, {"hand": 2, "phase": "over", "button": 3, "sb": 9, "bb": 1, "ending": true, "results": results, "current_bet": 0}))
	assert_not_null(screen._settlement, "结算面板")
	assert_eq(screen._settlement._ranking[0]["name"], "丙")
	assert_false(screen.is_my_turn())
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_NONE)
	assert_eq(screen.chips.stack_amount(ME), 2030)
	# 退场:拆台,铭牌收走,酒客留给等待厅(屏幕本身由 autofree 释放)
	remove_child(screen)
	await wait_process_frames(2)
	assert_eq(app.world.poker_root.get_child_count(), 0, "TableWorld 下没有德州节点")
	assert_eq(app.world.patrons[ME].fan.get_child_count(), 0, "牌扇里没有德州的牌")
	assert_null(_plate(3))
	assert_eq(_live_patrons().size(), 3)


func test_late_joiner_first_frame_comes_from_the_view_and_queued_events_are_dropped():
	# 翻牌后加入:开场运镜期间到达的 player_joined / action / street 事件丢掉,按视图把桌子瞬时摆好(规格 §7)
	_open_table([2, 3], true)
	assert_true(screen.late)
	stacks[ME] = 2000
	statuses[ME] = PokerRules.STATUS_WAITING
	bets[ME] = 0
	shown[ME] = []
	var flop := H.cards("Qc 7h 2s")
	bets[2] = 40
	stacks[2] = 1960
	stacks[3] = 1980
	shown[3] = []
	screen._on_events([{"type": "player_joined", "pid": ME, "name": "我"}])
	screen._on_events([_bet(2, PokerRules.RAISE, 40), {"type": "turn", "pid": 3}])
	await _feed([{"type": "street", "street": PokerRules.FLOP, "cards": flop, "board": flop}],
		_pub(3, {"street": PokerRules.FLOP, "board": flop, "pots": [{"amount": 40, "eligible": [2, 3]}], "current_bet": 40, "button": 2, "sb": 2, "bb": 3}),
		{"hand": 1, "hole": [], "best": {}})
	assert_eq(_live_patrons().size(), 2, "迟到者不建自己的酒客")
	assert_false(app.world.patrons.has(ME))
	assert_eq(app.world.seat_angles.size(), 3, "按「座位表 + 自己」排座:自己的座位空着")
	assert_eq(screen.cards.board_cards().size(), 3, "按视图摆好公共牌")
	assert_eq(screen.chips.bet_amount(2), 40)
	assert_eq(screen.chips.pot_amounts(), [40])
	assert_eq(screen.state.current_pid, 3)
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_WAITING)
	assert_eq(screen.hud.my_strip.cards(), [])
	assert_eq(screen.director.camera_mode(), PokerDirector.MODE_OVERVIEW)
	assert_null(_plate(ME))
	assert_not_null(_plate(2))
	# 下一手入座:自己的酒客登场,镜头回座位(运镜算在 hand_started 里)
	seats = [2, 3, 1]
	bets[2] = 0
	bets[3] = 0
	for pid in seats:
		statuses[pid] = PokerRules.STATUS_ACTIVE
	var hole := H.cards("Ah Kd")
	await _feed([{"type": "hand_started", "hand": 2, "button": 3, "sb": 1, "bb": 2, "seats": [2, 3, 1], "dealt": [1, 2, 3]},
		_blind(ME, "sb", 10), _blind(2, "bb", 20), {"type": "hole_cards", "hand": 2, "pids": [1, 2, 3]}, {"type": "turn", "pid": 3}],
		_pub(3, {"hand": 2, "button": 3, "sb": 1, "bb": 2}), {"hand": 2, "hole": hole, "best": {}})
	assert_true(app.world.patrons.has(ME))
	assert_eq(_live_patrons().size(), 3)
	assert_eq(screen.chips.bet_amount(ME), 10)
	assert_eq(screen.hud.my_strip.cards(), hole)
	assert_eq(screen.director.camera_mode(), PokerDirector.MODE_SEAT)
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_BET)


func test_events_missing_their_preconditions_do_not_break_the_show():
	# 规格 §7 的导演容错:没有下注堆的收注、手里没牌的弃牌与亮牌、前面槽位空着的河牌、没酒客的人的动作
	_open_table([1, 2], false)
	var river := H.cards("9s")
	shown[2] = H.cards("Qh Qs")
	await _feed([{"type": "bets_collected", "pots": [{"amount": 0, "eligible": []}], "refund": {"pid": 7, "amount": 50}},
		{"type": "action", "pid": 42, "action": PokerRules.FOLD, "amount": 0, "bet": 0, "stack": 0, "all_in": false},
		{"type": "reveal", "hands": [{"pid": 2, "cards": shown[2]}, {"pid": 42, "cards": []}], "reason": "showdown"},
		{"type": "street", "street": PokerRules.RIVER, "cards": river, "board": river},
		{"type": "action", "pid": 42, "action": PokerRules.CALL, "amount": 20, "bet": 20, "stack": 0, "all_in": true},
		{"type": "pot_won", "index": 3, "amount": 10, "winners": [42], "shares": {42: 10}, "hand_name": "", "best": {}, "uncontested": true},
		{"type": "rebuy", "pid": 42, "amount": 2000, "buyins": 1, "stack": 2000}, {"type": "player_left", "pid": 42, "folded": true},
		{"type": "away", "pid": 2}, {"type": "sit_in", "pid": 2}, {"type": "hand_over", "hand": 1, "stacks": {}, "busted": []},
		{"type": "mystery"}],
		_pub(null, {"current_bet": 0}))
	assert_false(screen.animating)
	assert_eq(_live_patrons().size(), 2)
	assert_eq(screen.cards.shown_cards(2).size(), 2, "手里没牌也在座位前现出亮牌")
	assert_eq(screen.cards.board_cards().size(), 0, "对账后按视图:没有公共牌")
