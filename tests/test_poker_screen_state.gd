extends GutTest
# 德州牌桌的本地状态(纯逻辑,规格 §4.2「PokerScreen 自己保存座位表」、§5.5 机位规则、§6.1 底部区域、§7 对账):
# 视图整体覆盖、事件只改影子行(演出期间铭牌按它显示)、座位表只在 hand_started 与对账时换、
# 摊牌条的牌型名在公共牌不足 3 张时为空、迟到者按「座位表 + 自己」排座。


const ME := 1
const H := preload("res://tests/poker_helpers.gd")

var state: PokerScreenState


func before_each():
	state = PokerScreenState.new()


func _player(pid: int, status := PokerRules.STATUS_ACTIVE, overrides := {}) -> Dictionary:
	var p := {"pid": pid, "name": "P%d" % pid, "stack": 2000, "bet": 0, "committed": 0, "status": status, "left": false,
		"buyins": 1, "net": 0, "shown": []}
	p.merge(overrides, true)
	return p


func _pub(pids: Array, overrides := {}) -> Dictionary:
	var pub := {"mode": GameMode.HOLDEM, "hand": 3, "phase": "betting", "street": PokerRules.PREFLOP, "board": [],
		"pots": [], "button": pids[0], "sb": pids[1 % pids.size()], "bb": pids[2 % pids.size()], "current_pid": null,
		"current_bet": 20, "actions": {}, "blinds": [10, 20], "seats": pids.duplicate(),
		"players": pids.map(func(pid): return _player(pid)), "turn_time_left": 0.0, "ending": false, "results": []}
	pub.merge(overrides, true)
	return pub


# —— 视图 ——

func test_view_refresh_fills_rows_seats_and_table_info():
	state.apply_public(_pub([1, 2, 3], {"board": H.cards("Ah Kd 2c"), "pots": [{"amount": 60, "eligible": [1, 2, 3]}]}), false)
	assert_eq(state.seats, [1, 2, 3])
	assert_eq(state.order, [1, 2, 3])
	assert_eq(state.row(2)["stack"], 2000)
	assert_eq(state.board, H.cards("Ah Kd 2c"))
	assert_eq(state.pots, [{"amount": 60, "eligible": [1, 2, 3]}])
	assert_eq(state.hand, 3)
	assert_eq(state.positions, {"button": 1, "sb": 2, "bb": 3})
	assert_eq(state.name_of(3), "P3")
	assert_eq(state.name_of(9), "?")


func test_view_during_animation_is_kept_but_rows_are_not_overwritten():
	state.apply_public(_pub([1, 2]), false)
	state.apply_public(_pub([1, 2], {"players": [_player(1, "active", {"stack": 500}), _player(2)]}), true)
	assert_eq(state.row(1)["stack"], 2000, "演出中影子行不动")
	assert_eq(state.pub["players"][0]["stack"], 500, "但最新视图记下了")
	assert_true(state.refresh_from_view() == false, "座位表没变")
	assert_eq(state.row(1)["stack"], 500)


func test_refresh_reports_a_seat_change_for_reseating():
	state.apply_public(_pub([1, 2]), false)
	state.apply_public(_pub([1, 2, 3]), true)
	assert_true(state.refresh_from_view())
	assert_eq(state.seats, [1, 2, 3])


func test_bad_view_rows_are_dropped():
	var pub := _pub([1, 2])
	pub["players"] = [_player(1), "junk", {"pid": "x"}, _player(2)]
	pub["seats"] = [1, "junk", 2]
	state.apply_public(pub, false)
	assert_eq(state.order, [1, 2])
	assert_eq(state.seats, [1, 2])


func test_private_view_gives_my_hole_and_best_only_for_the_hand_it_belongs_to():
	state.apply_public(_pub([1, 2]), false)
	state.apply_private({"hand": 3, "hole": H.cards("Ah Kd"), "best": {"detail": "一对 · A", "cards": H.cards("Ah Ad Kd 9c 2c")}})
	assert_eq(state.hole(), H.cards("Ah Kd"))
	assert_eq(state.best_detail(), "一对 · A")
	assert_eq(state.hole_for_hand(3), H.cards("Ah Kd"))
	assert_null(state.hole_for_hand(4), "下一手的牌还没到")
	state.apply_private({"hand": 3, "hole": ["x", 7]})
	assert_eq(state.hole(), [], "坏牌值丢掉")


# —— 事件改影子行 ——

func test_blinds_actions_and_collection_move_the_shadow_rows():
	state.apply_public(_pub([1, 2, 3]), false)
	state.apply_event({"type": "blind", "pid": 2, "kind": "sb", "amount": 10, "bet": 10, "stack": 1990, "all_in": false})
	state.apply_event({"type": "action", "pid": 3, "action": "fold", "amount": 0, "bet": 0, "stack": 2000, "all_in": false, "timeout": false})
	state.apply_event({"type": "action", "pid": 1, "action": "raise", "amount": 2000, "bet": 2000, "stack": 0, "all_in": true, "timeout": false})
	assert_eq(state.row(2)["bet"], 10)
	assert_eq(state.row(2)["stack"], 1990)
	assert_eq(state.row(3)["status"], PokerRules.STATUS_FOLDED)
	assert_eq(state.row(1)["status"], PokerRules.STATUS_ALLIN)
	assert_eq(state.row(1)["stack"], 0)
	state.apply_event({"type": "bets_collected", "pots": [{"amount": 30, "eligible": [1, 2]}], "refund": {"pid": 1, "amount": 1980}})
	assert_eq(state.row(1)["bet"], 0)
	assert_eq(state.row(2)["bet"], 0)
	assert_eq(state.row(1)["stack"], 1980, "未跟注部分退回")
	assert_eq(state.pots, [{"amount": 30, "eligible": [1, 2]}])


func test_street_reveal_pot_and_hand_over():
	state.apply_public(_pub([1, 2]), false)
	state.apply_event({"type": "street", "street": "flop", "cards": H.cards("Ah Kd 2c"), "board": H.cards("Ah Kd 2c")})
	assert_eq(state.board, H.cards("Ah Kd 2c"))
	state.apply_event({"type": "reveal", "hands": [{"pid": 2, "cards": H.cards("Ac Ad")}], "reason": "allin"})
	assert_true(state.in_showdown)
	assert_eq(state.row(2)["shown"], H.cards("Ac Ad"))
	state.apply_event({"type": "pot_won", "index": 0, "amount": 100, "winners": [2], "shares": {2: 100}, "hand_name": "三条",
		"best": {2: H.cards("Ac Ad Ah Kd 2c")}, "uncontested": false})
	assert_eq(state.row(2)["stack"], 2100)
	state.apply_event({"type": "hand_over", "hand": 3, "stacks": {1: 0, 2: 4000}, "busted": [1]})
	assert_false(state.in_showdown)
	assert_eq(state.row(1)["stack"], 0)
	assert_eq(state.row(1)["status"], PokerRules.STATUS_BUSTED)
	assert_eq(state.row(2)["stack"], 4000)
	assert_null(state.current_pid)


func test_seat_events_change_status_and_membership():
	state.apply_public(_pub([1, 2]), false)
	state.apply_event({"type": "turn", "pid": 2})
	assert_eq(state.current_pid, 2)
	state.apply_event({"type": "rebuy", "pid": 1, "amount": 2000, "buyins": 2, "stack": 2000})
	assert_eq(state.row(1)["status"], PokerRules.STATUS_WAITING)
	assert_eq(state.row(1)["buyins"], 2)
	state.apply_event({"type": "spectate", "pid": 1})
	assert_eq(state.row(1)["status"], PokerRules.STATUS_SPECTATING)
	state.apply_event({"type": "away", "pid": 2})
	assert_eq(state.row(2)["status"], PokerRules.STATUS_AWAY)
	state.apply_event({"type": "sit_in", "pid": 2})
	assert_eq(state.row(2)["status"], PokerRules.STATUS_WAITING)
	state.apply_event({"type": "player_joined", "pid": 7, "name": "迟到"})
	assert_eq(state.name_of(7), "迟到")
	assert_eq(state.order, [1, 2, 7])
	assert_false(state.seats.has(7), "本手旁观,下一手才入座")
	assert_eq(state.row(7)["status"], PokerRules.STATUS_WAITING)
	state.apply_event({"type": "player_left", "pid": 2, "folded": true})
	assert_true(state.has_left(2))
	assert_eq(state.row(2)["status"], PokerRules.STATUS_FOLDED)
	state.apply_event({"type": "ending"})
	assert_true(state.ending)


func test_hand_started_takes_the_new_seat_table_and_marks_the_dealt():
	state.apply_public(_pub([1, 2]), false)
	state.apply_event({"type": "player_joined", "pid": 7, "name": "迟到"})
	state.apply_event({"type": "reveal", "hands": [{"pid": 2, "cards": H.cards("Ac Ad")}], "reason": "showdown"})
	state.apply_event({"type": "hand_started", "hand": 4, "button": 2, "sb": 7, "bb": 1, "seats": [1, 2, 7], "dealt": [7, 1, 2]})
	assert_eq(state.seats, [1, 2, 7])
	assert_eq(state.hand, 4)
	assert_eq(state.positions, {"button": 2, "sb": 7, "bb": 1})
	assert_eq(state.row(7)["status"], PokerRules.STATUS_ACTIVE)
	assert_eq(state.row(7)["shown"], [])
	assert_eq(state.row(2)["shown"], [], "上一手亮的牌收走")
	assert_false(state.in_showdown)
	assert_true(state.revealed.is_empty())


func test_unknown_pids_in_events_do_not_crash():
	state.apply_public(_pub([1, 2]), false)
	state.apply_event({"type": "action", "pid": 99, "action": "call", "amount": 20, "bet": 20, "stack": 1980, "all_in": false})
	state.apply_event({"type": "rebuy", "pid": 98, "stack": 2000, "buyins": 1, "amount": 2000})
	state.apply_event({"type": "pot_won", "index": 0, "amount": 10, "winners": [97], "shares": {97: 10}, "hand_name": "", "best": {}, "uncontested": true})
	state.apply_event({"type": "hand_over", "hand": 3, "stacks": {96: 5}, "busted": [95]})
	state.apply_event({"type": "mystery"})
	assert_eq(state.order, [1, 2])


# —— 推导 ——

func test_bottom_mode_shows_bet_controls_only_while_someone_is_acting():
	state.apply_public(_pub([1, 2]), false)
	assert_eq(state.bottom_mode(ME), PokerHud.BOTTOM_NONE, "两手之间没人行动")
	state.apply_event({"type": "turn", "pid": 2})
	assert_eq(state.bottom_mode(ME), PokerHud.BOTTOM_BET, "看别人的回合横幅")
	state.apply_event({"type": "reveal", "hands": [{"pid": 2, "cards": H.cards("Ac Ad")}], "reason": "showdown"})
	assert_eq(state.bottom_mode(ME), PokerHud.BOTTOM_SHOWDOWN)
	state.apply_event({"type": "hand_over", "hand": 3, "stacks": {1: 0, 2: 4000}, "busted": [1]})
	assert_eq(state.bottom_mode(ME), PokerHud.BOTTOM_BUST)
	state.apply_event({"type": "spectate", "pid": ME})
	assert_eq(state.bottom_mode(ME), PokerHud.BOTTOM_SPECTATE)
	state.apply_event({"type": "rebuy", "pid": ME, "amount": 2000, "buyins": 2, "stack": 2000})
	assert_eq(state.bottom_mode(ME), PokerHud.BOTTOM_WAITING)
	assert_eq(PokerScreenState.new().bottom_mode(ME), PokerHud.BOTTOM_NONE, "还没有视图")


func test_camera_rule_follows_seats_and_spectating():
	state.apply_public(_pub([2, 3]), false)
	assert_true(state.uses_overview(ME), "不在座位表里(迟到者)")
	state.apply_public(_pub([1, 2, 3]), false)
	assert_false(state.uses_overview(ME))
	for status in [PokerRules.STATUS_BUSTED, PokerRules.STATUS_WAITING, PokerRules.STATUS_AWAY]:
		state.apply_event({"type": "hand_over", "hand": 3, "stacks": {}, "busted": []})
		state.rows[ME]["status"] = status
		assert_false(state.uses_overview(ME), "%s 留在越肩" % status)
	state.apply_event({"type": "spectate", "pid": ME})
	assert_true(state.uses_overview(ME))


func test_gaze_excludes_spectators_and_the_departed():
	state.apply_public(_pub([1, 2, 3]), false)
	assert_false(state.is_excluded(2))
	state.apply_event({"type": "spectate", "pid": 2})
	assert_true(state.is_excluded(2))
	state.apply_event({"type": "player_left", "pid": 3, "folded": false})
	assert_true(state.is_excluded(3))
	assert_true(state.is_excluded(42), "不认识的人也不跟随")


func test_seat_entries_add_me_at_the_end_when_i_am_a_late_joiner():
	state.apply_public(_pub([2, 3]), false)
	state.names[ME] = "我"
	assert_eq(state.seat_entries(ME), [{"pid": 2, "name": "P2"}, {"pid": 3, "name": "P3"}, {"pid": ME, "name": "我"}])
	state.apply_public(_pub([1, 2, 3]), false)
	assert_eq(state.seat_entries(ME).map(func(e): return e["pid"]), [1, 2, 3])


func test_showdown_entries_name_the_hand_only_with_three_or_more_board_cards():
	state.apply_public(_pub([1, 2]), false)
	state.apply_event({"type": "reveal", "hands": [{"pid": 2, "cards": H.cards("Ac Ad")}, {"pid": 1, "cards": H.cards("7s 2h")}], "reason": "allin"})
	var entries := state.showdown_entries(false)
	assert_eq(entries.size(), 2)
	assert_eq(entries[0]["name"], "P1", "按视图顺序")
	assert_eq(entries[0]["hand_name"], "", "翻牌前亮牌:还没有牌型")
	state.apply_event({"type": "street", "street": "flop", "cards": H.cards("Ah Kd 2c"), "board": H.cards("Ah Kd 2c")})
	entries = state.showdown_entries(false)
	assert_eq(entries[1]["hand_name"], "三条 · A")
	assert_eq(entries[1]["cards"], H.cards("Ac Ad"))


func test_my_status_and_legal_actions_come_from_the_view():
	assert_eq(state.status_of(ME), "")
	var pub := _pub([1, 2], {"current_pid": ME, "actions": {"pid": ME, "to_call": 20, "call_amount": 20, "can_check": false,
		"can_raise": true, "can_allin": true, "min_raise_to": 40, "max_raise_to": 2000}})
	state.apply_public(pub, false)
	assert_eq(state.status_of(ME), PokerRules.STATUS_ACTIVE)
	assert_eq(state.legal(ME)["min_raise_to"], 40)
	assert_eq(state.legal(2), {}, "不是他的回合")


func test_sync_from_view_takes_the_actor_and_shown_cards_for_a_late_first_frame():
	var pub := _pub([1, 2], {"current_pid": 2, "street": PokerRules.RIVER, "board": H.cards("Ah Kd 2c 9s 9d"),
		"players": [_player(1), _player(2, "allin", {"shown": H.cards("Ac Ad")})]})
	state.apply_public(pub, true)
	state.sync_from_view()
	assert_eq(state.current_pid, 2)
	assert_eq(state.seats, [1, 2])
	assert_eq(state.revealed, {2: H.cards("Ac Ad")})
	assert_true(state.in_showdown)
