extends GutTest
# 骗子酒馆会话(规格 §4.2):把 GameState / Views / Pacing 的用法从 NetworkManager 搬进来,行为零变化。
# 这里逐条对照 GameState 与 Views 的直接调用,确认会话只是转发。


const NAMES := {1: "甲", 2: "乙", 3: "丙"}

var session: LiarsSession


func before_each():
	session = LiarsSession.new()


func _start(seed_value := 99) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return session.start([1, 2, 3], NAMES, rng)


func _current() -> int:
	return session.public_view(0.0)["current_pid"]


func test_start_opens_the_first_round_and_hands_the_turn_to_the_starter():
	var events := _start()
	assert_eq(events.size(), 1)
	assert_eq(events[0]["type"], "round_started")
	assert_eq(events[0]["starter"], _current())
	assert_true(session.has_turn())
	assert_false(session.is_over())
	assert_false(session.is_ending())


func test_play_and_challenge_are_turn_actions():
	_start()
	var result := session.handle_intent(_current(), {"kind": "play", "indices": [0]})
	assert_true(result["ok"])
	assert_true(result["turn_action"], "出牌消耗回合:行动者那端的演出欠账清零")
	assert_eq(result["events"][0]["type"], "played")
	result = session.handle_intent(_current(), {"kind": "challenge"})
	assert_true(result["ok"])
	assert_true(result["turn_action"])
	assert_eq(result["events"][0]["type"], "reveal")


func test_rejections_keep_the_engine_error_codes():
	_start()
	var bystander: int = [1, 2, 3].filter(func(pid: int) -> bool: return pid != _current())[0]
	assert_eq(session.handle_intent(bystander, {"kind": "play", "indices": [0]}), {"ok": false, "error": "not_your_turn", "turn_action": false})
	assert_eq(session.handle_intent(_current(), {"kind": "challenge"})["error"], "nothing_to_challenge")
	assert_eq(session.handle_intent(_current(), {"kind": "play", "indices": [9]})["error"], "invalid_play")


func test_foreign_or_malformed_intents_are_invalid_plays():
	_start()
	for intent in [{"kind": "fold", "amount": 0}, {"kind": "rebuy"}, {}, {"kind": 3}, {"kind": "play", "indices": "0"}, {"kind": "play"}]:
		var result := session.handle_intent(_current(), intent)
		assert_eq([result["ok"], result["error"]], [false, "invalid_play"], str(intent))
	assert_true(session.has_turn(), "被拒绝的意图不改状态")


func test_timeout_plays_the_first_card_of_the_current_player():
	_start()
	var actor := _current()
	var result := session.on_turn_timeout()
	assert_true(result["ok"])
	assert_true(result["turn_action"], "超时代打按消耗回合处理")
	assert_eq([result["events"][0]["type"], result["events"][0]["pid"], result["events"][0]["count"]], ["played", actor, 1])


func test_disconnect_eliminates_members_and_ignores_strangers():
	_start()
	assert_eq(session.on_disconnect(42), [])
	var bystander: int = [1, 2, 3].filter(func(pid: int) -> bool: return pid != _current())[0]
	var events := session.on_disconnect(bystander)
	assert_eq(events, [{"type": "eliminated", "pid": bystander}])
	assert_eq(session.on_disconnect(bystander), [], "已出局的人再断线没有事件")
	assert_true(session.has_turn(), "旁人断线不换人")


func test_views_match_the_direct_view_builders():
	_start()
	var gs: GameState = session._gs
	assert_eq(session.public_view(12.5), Views.public_state(gs, NAMES, 12.5))
	for pid in [1, 2, 3]:
		assert_eq(session.private_view(pid), Views.private_state(gs, pid))
	assert_eq(session.viewers(), [1, 2, 3], "每个座位都收私有视图")


func test_match_over_stops_the_turn_and_refuses_late_joiners_always():
	_start()
	assert_false(session.accepts_late_join(), "骗子酒馆从不中途加入")
	assert_eq(session.add_player(9, "丁"), [])
	assert_false(session.next_hand_ready())
	assert_eq(session.start_next_hand(), [])
	assert_eq(session.request_end(), [])
	session.on_disconnect(1)
	var events := session.on_disconnect(2)
	assert_eq(events.back()["type"], "match_over")
	assert_true(session.is_over())
	assert_false(session.has_turn())
	assert_eq(session.public_view(9.0)["turn_time_left"], 0.0)
	assert_eq(session.handle_intent(3, {"kind": "challenge"})["error"], "match_over")


func test_pacing_is_the_liars_budget():
	var batch := [{"type": "played", "pid": 1, "count": 1}, {"type": "turn", "pid": 2}]
	assert_almost_eq(session.estimate(batch), Pacing.estimate(batch), 0.001)
	assert_almost_eq(session.turn_timer_after(batch, 2.0, 11.0), Pacing.turn_timer_after(batch, 2.0, 11.0), 0.001)
	assert_eq(session.seats_with_patrons(), [], "开局前没有座位")
	_start()
	assert_eq(session.seats_with_patrons(), [1, 2, 3])
	assert_eq(session.name_of(2), "乙")
