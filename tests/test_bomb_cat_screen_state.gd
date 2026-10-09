extends GutTest
# BombCatScreenState(纯逻辑):视图与事件序列推进影子行、屏幕上的自己的手牌、出手规则(选牌、组合、目标、点名、
# 不行! 按钮、塞回范围、给牌)与结算名次;网络来的坏字段不报错。用真的 BombCatSession 产生视图与事件,和房主一致。


const H := preload("res://tests/bomb_cat_helpers.gd")
const C := preload("res://src/core/bomb_cat/bomb_cat_card.gd")
const ME := 1

var st: BombCatScreenState


func before_each():
	st = BombCatScreenState.new()
	st.my_pid = ME
	st.set_seats([{"pid": 1, "name": "我"}, {"pid": 2, "name": "乙"}, {"pid": 3, "name": "丙"}])


func _pub(overrides := {}) -> Dictionary:
	var pub := {"mode": GameMode.BOMB_CAT, "step": "turn", "current_pid": ME, "turns": 1, "deck_count": 20, "discard_count": 0,
		"discard_top": "", "bombs_left": 2, "bombs_total": 2, "window": {}, "give": {}, "reinsert": {},
		"players": [{"pid": 1, "name": "我", "alive": true, "hand_count": 5}, {"pid": 2, "name": "乙", "alive": true, "hand_count": 4},
			{"pid": 3, "name": "丙", "alive": true, "hand_count": 0}],
		"out_order": [], "winner": null, "ranking": [], "turn_time_left": 30.0, "paused_turn_left": 0.0}
	pub.merge(overrides, true)
	return pub


func _priv(hand: Array, overrides := {}) -> Dictionary:
	var priv := {"hand": hand, "alive": true, "last_drawn": "", "draw_seq": 0, "peek": [], "peek_seq": 0, "reinsert": {},
		"give": {}, "transfer": {}}
	priv.merge(overrides, true)
	return priv


# —— 事件推进影子行 ——

func test_round_started_sets_counts_deck_bombs_and_current():
	st.apply_event({"type": "round_started", "seats": [1, 2, 3], "hands": [{"pid": 1, "count": 8}, {"pid": 2, "count": 8},
		{"pid": 3, "count": 8}], "deck_count": 30, "bombs": 2, "current": 2, "turns": 1})
	assert_eq(st.counts, {1: 8, 2: 8, 3: 8})
	assert_eq(st.deck_count, 30)
	assert_eq([st.bombs_left, st.bombs_total], [2, 2])
	assert_eq(st.current_pid, 2)
	assert_eq(st.step, "turn")
	assert_true(st.started)


func test_a_whole_sequence_of_events_moves_the_shadow_row():
	st.counts = {1: 8, 2: 8, 3: 8}
	st.alive = {1: true, 2: true, 3: true}
	st.deck_count = 30
	st.bombs_left = 2
	st.apply_event({"type": "played", "pid": 2, "cards": [C.SNACK_FISH, C.SNACK_FISH], "kind": "pair", "target": 3, "named": "", "window": 3.0})
	assert_eq(st.counts[2], 6, "出了两张")
	assert_eq(st.step, "window")
	assert_eq(st.window["target"], 3)
	assert_eq(st.discard_recent, [C.SNACK_FISH, C.SNACK_FISH])
	st.apply_event({"type": "noped", "pid": 3, "depth": 1, "window": 3.0})
	assert_eq(st.counts[3], 7)
	assert_eq(st.window["nopes"], 1)
	assert_eq(st.discard_recent[-1], C.NOPE)
	st.apply_event({"type": "window_resolved", "pid": 2, "kind": "pair", "effective": false, "nopes": 1, "aborted": false})
	assert_eq(st.step, "turn")
	assert_eq(st.window, {})
	st.apply_event({"type": "effect", "kind": "steal", "pid": 2, "from": 3, "to": 2, "got": true})
	assert_eq([st.counts[2], st.counts[3]], [7, 6], "抽走一张")
	st.apply_event({"type": "drew", "pid": 2, "deck_count": 29, "bomb": false})
	assert_eq([st.counts[2], st.deck_count], [8, 29])
	st.apply_event({"type": "drew", "pid": 3, "deck_count": 28, "bomb": true})
	assert_eq(st.counts[3], 6, "摸到炸弹不进手牌")
	st.apply_event({"type": "bomb_drawn", "pid": 3})
	st.apply_event({"type": "defused", "pid": 3, "deck_count": 28, "timeout": 15.0})
	assert_eq(st.counts[3], 5, "拆弹打出")
	assert_eq(st.step, "reinsert")
	st.apply_event({"type": "reinserted", "pid": 3, "deck_count": 29})
	assert_eq([st.deck_count, st.step], [29, "turn"])
	st.apply_event({"type": "turn_passed", "pid": 1, "turns": 2})
	assert_eq([st.current_pid, st.turns], [1, 2])
	st.apply_event({"type": "drew", "pid": 1, "deck_count": 28, "bomb": true})
	st.apply_event({"type": "exploded", "pid": 1, "discarded": 8})
	assert_false(st.is_alive(1))
	assert_eq(st.counts[1], 0)
	assert_eq(st.bombs_left, 1, "炸飞一颗")
	assert_true(st.exploded.has(1))
	assert_eq(st.out_order, [1])
	st.apply_event({"type": "player_left", "pid": 3, "discarded": 5})
	assert_false(st.exploded.has(3), "断线不算炸飞")
	assert_eq(st.bombs_left, 1, "断线不移除炸弹")
	st.apply_event({"type": "match_over", "winner": 2, "ranking": [2, 3, 1]})
	assert_eq([st.step, st.winner, st.current_pid], ["over", 2, null])


func test_give_requested_and_beg_effect():
	st.counts = {1: 3, 2: 3, 3: 3}
	st.apply_event({"type": "give_requested", "pid": 1, "to": 2, "timeout": 15.0})
	assert_eq(st.step, "give")
	st.apply_event({"type": "effect", "kind": "beg", "pid": 2, "from": 1, "to": 2, "got": true})
	assert_eq(st.step, "turn")
	assert_eq([st.counts[1], st.counts[2]], [2, 4])


func test_bad_event_fields_do_not_crash():
	st.apply_event({"type": "played", "pid": "x", "cards": "nope", "kind": 3})
	st.apply_event({"type": "drew", "pid": null, "deck_count": "many"})
	st.apply_event({"type": "turn_passed", "pid": [1], "turns": {}})
	st.apply_event({"type": "exploded"})
	st.apply_event({})
	assert_eq(st.current_pid, null)
	assert_eq(st.deck_count, 0)


func test_sync_from_view_overwrites_the_shadow_row():
	st.counts = {1: 99}
	st.apply_public(_pub({"discard_top": C.SKIP, "discard_count": 4, "out_order": [3], "players": [
		{"pid": 1, "name": "我", "alive": true, "hand_count": 5}, {"pid": 2, "name": "乙", "alive": true, "hand_count": 4},
		{"pid": 3, "name": "丙", "alive": false, "hand_count": 0}]}))
	st.apply_private(_priv([C.SKIP, C.NOPE, C.DEFUSE, C.SNACK_FISH, C.SNACK_FISH]))
	st.sync_from_view()
	assert_eq(st.counts, {1: 5, 2: 4, 3: 0})
	assert_false(st.is_alive(3))
	assert_eq(st.discard_recent, [C.SKIP])
	assert_eq(st.shown_hand, [C.SKIP, C.NOPE, C.DEFUSE, C.SNACK_FISH, C.SNACK_FISH], "屏幕上的手牌以私有视图为准")


# —— 屏幕上的自己的手牌 ——

func test_take_from_shown_prefers_the_submitted_indices():
	st.shown_hand = [C.SNACK_FISH, C.SKIP, C.SNACK_FISH, C.SNACK_FISH]
	assert_eq(st.take_from_shown([C.SNACK_FISH, C.SNACK_FISH], [2, 3]), [2, 3])
	assert_eq(st.shown_hand, [C.SNACK_FISH, C.SKIP])


func test_take_from_shown_falls_back_to_matching_ids():
	st.shown_hand = [C.SKIP, C.PEEK]
	assert_eq(st.take_from_shown([C.PEEK], [0]), [1], "下标对不上就按牌型找")
	assert_eq(st.shown_hand, [C.SKIP])


func test_add_and_remove_from_shown():
	st.shown_hand = [C.NOPE, C.SKIP]
	st.add_to_shown(C.BEG)
	st.add_to_shown("bogus")
	assert_eq(st.shown_hand, [C.NOPE, C.SKIP, C.BEG])
	assert_eq(st.remove_from_shown(C.NOPE), 0)
	assert_eq(st.shown_hand, [C.SKIP, C.BEG])


# —— 出手规则 ——

func test_selection_kind_and_multi_select_only_for_same_snacks():
	st.apply_private(_priv([C.SNACK_FISH, C.SNACK_FISH, C.SNACK_FISH, C.SKIP, C.SNACK_YARN, C.NOPE, C.DEFUSE]))
	assert_eq(st.selection_kind([3]), C.SKIP)
	assert_eq(st.selection_kind([0, 1]), "pair")
	assert_eq(st.selection_kind([0, 1, 2]), "triple")
	assert_eq(st.selection_kind([0]), "", "单张零食不能出")
	assert_eq(st.selection_kind([5]), "", "不行! 不能在自由行动时打")
	assert_eq(st.selection_kind([6]), "", "拆弹不能主动打")
	assert_eq(st.selection_kind([0, 4]), "", "不同零食不能组合")
	assert_eq(st.selection_kind([0, 0]), "", "重复下标")
	assert_eq(st.selection_kind([9]), "", "越界")
	assert_true(st.can_select_more([0], 1), "同种零食可以多选")
	assert_true(st.can_select_more([0, 1], 2))
	assert_false(st.can_select_more([0, 1, 2], 2), "最多三张")
	assert_false(st.can_select_more([0], 4), "不同零食")
	assert_false(st.can_select_more([3], 0), "功能牌只能单选")
	assert_false(st.can_select_more([0], 3), "零食里混功能牌")
	assert_true(st.can_select_more([], 3))


func test_selection_hints_explain_illegal_picks():
	st.apply_private(_priv([C.SNACK_FISH, C.NOPE, C.DEFUSE, C.BEG, C.SNACK_FISH]))
	assert_string_contains(st.selection_hint([0]), "两张一样")
	assert_string_contains(st.selection_hint([1]), "反应窗口")
	assert_string_contains(st.selection_hint([2]), "自动用掉")
	assert_string_contains(st.selection_hint([0, 4]), "随机抽")
	assert_eq(st.selection_hint([3]), C.description(C.BEG))
	assert_eq(st.selection_hint([]), "")


func test_target_candidates_are_alive_others_with_cards():
	st.apply_public(_pub({"players": [{"pid": 1, "name": "我", "alive": true, "hand_count": 5},
		{"pid": 2, "name": "乙", "alive": true, "hand_count": 4}, {"pid": 3, "name": "丙", "alive": true, "hand_count": 0},
		{"pid": 4, "name": "丁", "alive": false, "hand_count": 0}]}))
	assert_eq(st.target_candidates(), [2], "自己、空手的、出局的都不能选")
	assert_true(st.is_valid_target(2))
	assert_false(st.is_valid_target(1))
	assert_false(st.is_valid_target(3))
	assert_false(st.is_valid_target("2"))
	assert_true(BombCatScreenState.needs_target(C.BEG))
	assert_true(BombCatScreenState.needs_target("pair"))
	assert_false(BombCatScreenState.needs_target(C.SKIP))
	assert_true(BombCatScreenState.needs_named("triple"))
	assert_false(BombCatScreenState.nameable_cards().has(C.BOMB), "点名不能点炸弹")
	assert_eq(BombCatScreenState.nameable_cards().size(), C.ALL.size() - 1)


func test_nope_button_lights_only_in_a_window_when_alive_with_a_nope():
	st.apply_private(_priv([C.NOPE]))
	st.apply_public(_pub({"step": "turn"}))
	assert_false(st.can_nope(), "窗口外")
	st.apply_public(_pub({"step": "window", "window": {"pid": 2, "cards": [C.SKIP], "kind": C.SKIP, "target": null, "named": "", "nopes": 0}}))
	assert_true(st.can_nope())
	st.apply_private(_priv([C.SKIP]))
	assert_false(st.can_nope(), "手里没有不行!")
	st.apply_private(_priv([C.NOPE], {"alive": false}))
	assert_false(st.can_nope(), "出局了")


func test_my_turn_in_view_needs_turn_step_and_current():
	st.apply_private(_priv([C.SKIP]))
	st.apply_public(_pub({"step": "turn", "current_pid": ME}))
	assert_true(st.my_turn_in_view())
	st.apply_public(_pub({"step": "window", "current_pid": ME}))
	assert_false(st.my_turn_in_view(), "窗口里不能再出牌摸牌")
	st.apply_public(_pub({"step": "turn", "current_pid": 2}))
	assert_false(st.my_turn_in_view())


func test_reinsert_range_and_give_target_come_from_the_private_view():
	st.apply_private(_priv([], {"reinsert": {"deck_count": 17}}))
	assert_eq(st.reinsert_max(), 17, "可选位置 0..17")
	st.apply_private(_priv([], {"reinsert": {}}))
	assert_eq(st.reinsert_max(), -1)
	st.apply_private(_priv([], {"reinsert": {"deck_count": "x"}}))
	assert_eq(st.reinsert_max(), -1, "坏字段当没有")
	st.apply_private(_priv([C.SKIP], {"give": {"to": 2}}))
	assert_eq(st.give_to(), 2)
	st.apply_private(_priv([C.SKIP]))
	assert_eq(st.give_to(), null)


# —— 结算 ——

func test_ranking_rows_use_the_view_and_mark_fates():
	st.exploded = {3: true}
	st.apply_public(_pub({"step": "over", "ranking": [{"pid": 2, "name": "乙", "place": 1}, {"pid": 3, "name": "丙", "place": 2},
		{"pid": 1, "name": "我", "place": 3}]}))
	var rows := st.ranking_rows()
	assert_eq(rows.map(func(r): return r["pid"]), [2, 3, 1])
	assert_eq(rows.map(func(r): return r["fate"]), ["winner", "exploded", "left"])


func test_ranking_rows_fall_back_to_winner_plus_reversed_out_order():
	st.winner = 2
	st.out_order = [1, 3]
	st.apply_public(_pub())
	assert_eq(st.ranking_rows().map(func(r): return r["pid"]), [2, 3, 1])
	assert_eq(st.ranking_rows().map(func(r): return r["place"]), [1, 2, 3])


# —— 与真实会话一致 ——

func test_shadow_row_matches_the_session_after_every_batch():
	# 真实会话随机打一局:每批事件推进影子行后,张数、牌堆、炸弹、当前玩家都和视图一致
	var session := BombCatSession.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var names := {1: "我", 2: "乙", 3: "丙", 4: "丁"}
	st.set_seats([{"pid": 1, "name": "我"}, {"pid": 2, "name": "乙"}, {"pid": 3, "name": "丙"}, {"pid": 4, "name": "丁"}])
	var events := session.start([1, 2, 3, 4], names, rng)
	var steps := 0
	while steps < 400:
		for ev in events:
			st.apply_event(ev)
		var pub := session.public_view(5.0)
		for row in pub["players"]:
			assert_eq(st.counts.get(row["pid"], 0), row["hand_count"] if row["alive"] else 0, "步 %d P%d 张数" % [steps, row["pid"]])
			assert_eq(st.is_alive(row["pid"]), row["alive"])
		assert_eq(st.deck_count, pub["deck_count"], "步 %d 牌堆" % steps)
		assert_eq(st.bombs_left, pub["bombs_left"])
		assert_eq(st.step, pub["step"], "步 %d 步骤" % steps)
		if session.is_over():
			break
		var s := session.state()
		var result: Dictionary
		match s.step:
			BombCatState.Step.TURN:
				var hand: Array = s.hands[s.current_pid]
				var simple := BombCatBot.legal_plays(hand).filter(func(cards: Array) -> bool:
					return BombCatState.combo_kind(cards.map(func(i: int): return hand[i])) in [C.SKIP, C.SHUFFLE, C.PEEK, C.PASS_TURNS])
				if not simple.is_empty() and rng.randf() < 0.4:
					result = session.handle_intent(s.current_pid, {"kind": "play", "cards": simple[0]})
				else:
					result = session.handle_intent(s.current_pid, {"kind": "draw"})
			_:
				result = session.on_turn_timeout()
		events = result.get("events", [])
		steps += 1
	assert_true(session.is_over(), "随机打的一局要能打完")
