extends GutTest
# 牌局记录与「开始下一手」的界面部分:记录的清洗与去重、记录面板翻页、两手之间的底部提示与进度。


const H := preload("res://tests/poker_helpers.gd")
const ME := 1


func _record(hand: int, deltas := {1: 30, 2: -10, 3: -20}) -> Dictionary:
	var players := []
	for pid in deltas:
		players.append({"pid": pid, "name": "P%d" % pid, "cards": H.cards("Kc Kd") if pid == 1 else H.cards("7s 2h"),
			"hand_name": "一对 · K" if pid == 1 else "", "folded": pid == 2, "left": false, "delta": deltas[pid]})
	return {"type": "hand_record", "hand": hand, "board": H.cards("8c 6h 4d Jc 3s"), "players": players}


func test_state_keeps_each_hand_once_and_drops_bad_fields():
	var state := PokerScreenState.new()
	state.apply_event(_record(1))
	state.apply_event(_record(1))
	assert_eq(state.history.size(), 1, "同一手只记一次")
	state.apply_event({"type": "hand_record", "hand": "x"})
	state.apply_event({"type": "hand_record", "hand": 2, "board": "junk", "players": ["junk", {"pid": 5, "cards": [1, 99],
		"delta": "big", "folded": 1}]})
	assert_eq(state.history.size(), 2)
	var bad: Dictionary = state.history[1]
	assert_eq(bad["board"], [])
	assert_eq(bad["players"].size(), 1)
	assert_eq(bad["players"][0], {"pid": 5, "name": "?", "cards": [], "hand_name": "", "folded": false, "left": false, "delta": 0})


func test_state_history_is_capped():
	var state := PokerScreenState.new()
	for i in PokerScreenState.HISTORY_MAX + 5:
		state.apply_event(_record(i + 1))
	assert_eq(state.history.size(), PokerScreenState.HISTORY_MAX)
	assert_eq(state.history[0]["hand"], 6, "最旧的先丢")


func test_between_hands_and_confirm_progress():
	var state := PokerScreenState.new()
	state.apply_public({"hand": 1, "phase": "betting", "seats": [1, 2, 3], "players": [
		{"pid": 1, "status": "active"}, {"pid": 2, "status": "active"}, {"pid": 3, "status": "spectating"}]})
	state.refresh_from_view()
	state.apply_event({"type": "hand_over", "hand": 1, "stacks": {}, "busted": []})
	assert_true(state.between_hands)
	assert_eq(state.bottom_mode(ME), PokerHud.BOTTOM_NEXT)
	assert_eq(state.confirm_progress(), [0, 2], "观战的人不用点")
	state.apply_event({"type": "next_ready", "pid": ME})
	assert_eq(state.bottom_mode(ME), PokerHud.BOTTOM_NEXT_WAIT)
	assert_eq(state.confirm_progress(), [1, 2])
	assert_eq(PokerNameplate.status_text(state.row(ME)), PokerNameplate.CONFIRMED_TEXT, "铭牌显示已准备")
	state.apply_event({"type": "hand_started", "hand": 2, "seats": [1, 2, 3], "dealt": [1, 2]})
	assert_false(state.between_hands)
	assert_false(state.row(ME)["confirmed"])


func test_late_first_frame_between_hands_shows_the_start_button():
	var state := PokerScreenState.new()
	state.apply_public({"hand": 3, "phase": "idle", "seats": [1, 2], "players": [{"pid": 1, "status": "waiting"},
		{"pid": 2, "status": "folded"}]})
	state.sync_from_view()
	assert_true(state.between_hands)
	assert_eq(state.bottom_mode(ME), PokerHud.BOTTOM_NEXT)


func test_history_panel_pages_and_shows_every_dealt_hand():
	assert_eq(HandHistoryPanel.result_text(1240), "+1,240")
	assert_eq(HandHistoryPanel.result_text(-20), "-20")
	assert_eq(HandHistoryPanel.result_text(0), "0")
	var panel := HandHistoryPanel.new()
	panel.set_records([])
	add_child_autofree(panel)
	assert_eq(panel.index(), -1)
	assert_eq(panel.row_count(), 0, "还没有记录")
	var state := PokerScreenState.new()
	state.apply_event(_record(1))
	state.apply_event(_record(2, {1: -40, 2: 40}))
	panel.set_records(state.history)
	assert_eq(panel.index(), 1, "默认翻到最近一手")
	assert_eq(panel.row_count(), 2)
	panel.page(-1)
	assert_eq(panel.index(), 0)
	assert_eq(panel.row_count(), 3, "弃牌的人也列出来")
	panel.page(-1)
	assert_eq(panel.index(), 0, "翻到头就停")
	state.apply_event(_record(3))
	panel.set_records(state.history, false)
	assert_eq(panel.index(), 0, "有新记录时停在当前页")


func test_history_panel_fits_eight_players_on_screen():
	var holder := Control.new()
	holder.size = Vector2(1280, 720)
	add_child_autofree(holder)
	var deltas := {}
	for pid in range(1, 9):
		deltas[pid] = 0
	var state := PokerScreenState.new()
	state.apply_event(_record(1, deltas))
	var panel := HandHistoryPanel.new()
	panel.set_records(state.history)
	holder.add_child(panel)
	await wait_process_frames(3)
	assert_true(panel.position.y >= 0.0 and panel.position.y + panel.size.y <= 720.0, "上下 %s %s" % [panel.position, panel.size])
	assert_true(panel.position.x >= 0.0 and panel.position.x + panel.size.x <= 1280.0)


func test_hud_bottom_modes_between_hands():
	var p := func(status: String, confirmed := false) -> Dictionary: return {"status": status, "confirmed": confirmed}
	assert_eq(PokerHud.bottom_mode_for(p.call("folded"), true), PokerHud.BOTTOM_NEXT)
	assert_eq(PokerHud.bottom_mode_for(p.call("active", true), true), PokerHud.BOTTOM_NEXT_WAIT)
	assert_eq(PokerHud.bottom_mode_for(p.call("waiting"), true), PokerHud.BOTTOM_NEXT, "中途加入等发牌的也要点")
	assert_eq(PokerHud.bottom_mode_for(p.call("busted"), true), PokerHud.BOTTOM_BUST, "输光的人先选再领 / 观战")
	assert_eq(PokerHud.bottom_mode_for(p.call("spectating"), true), PokerHud.BOTTOM_SPECTATE)
	assert_eq(PokerHud.bottom_mode_for(p.call("away"), true), PokerHud.BOTTOM_AWAY)
	assert_eq(PokerHud.bottom_mode_for(p.call("waiting"), false), PokerHud.BOTTOM_WAITING, "手牌进行中")
