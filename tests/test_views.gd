extends GutTest


func _make_gs() -> GameState:
	var gs := GameState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	gs.start_match([1, 2, 3], rng)
	return gs


func test_public_state_shape_and_no_secrets():
	var gs := _make_gs()
	gs.play_cards(gs.current_pid, [0, 1])
	var pub := Views.public_state(gs, {1: "甲", 2: "乙", 3: "丙"})
	assert_eq(pub["target"], gs.target_card)
	assert_eq(pub["current_pid"], gs.current_pid)
	assert_eq(pub["round"], 1)
	assert_eq(pub["winner"], null)
	assert_eq(pub["phase"], GameState.Phase.PLAYING)
	# 防作弊:上家出的具体牌面绝不进入公共视图
	assert_eq(pub["last_play"]["count"], 2)
	assert_false(pub["last_play"].has("cards"))
	assert_eq(pub["players"].size(), 3)
	for p in pub["players"]:
		assert_false(p.has("hand"))
		assert_true(p.has("hand_count"))
		assert_true(p.has("shots_fired"))
		assert_true(p.has("alive"))
	assert_false(str(pub).contains("bullet"))


func test_public_state_players_follow_seat_order_with_names():
	var gs := _make_gs()
	var pub := Views.public_state(gs, {1: "甲", 2: "乙"})
	var pids := []
	for p in pub["players"]:
		pids.append(p["pid"])
	assert_eq(pids, gs.seat_order)
	assert_eq(pub["players"][0]["name"], "甲")
	# 缺失昵称时回退为 pid 字符串,不崩溃
	assert_eq(pub["players"][2]["name"], "3")


func test_public_state_last_play_empty_at_round_start():
	var gs := _make_gs()
	var pub := Views.public_state(gs, {})
	assert_true(pub["last_play"].is_empty())


func test_private_state_contains_only_own_hand_and_round():
	var gs := _make_gs()
	var pid = gs.current_pid
	var priv := Views.private_state(gs, pid)
	assert_eq(priv.keys(), ["hand", "round"])
	assert_eq(priv["hand"], gs.hands[pid])
	assert_eq(priv["round"], 1)


func test_private_state_is_a_copy():
	var gs := _make_gs()
	var priv := Views.private_state(gs, 1)
	priv["hand"].clear()
	assert_eq(gs.hands[1].size(), 5)


func test_private_state_for_unknown_player_is_empty_hand():
	var gs := _make_gs()
	assert_eq(Views.private_state(gs, 42)["hand"], [])
