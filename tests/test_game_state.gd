extends GutTest


func _make_gs(player_ids := [1, 2, 3], seed_value := 99) -> GameState:
	var gs := GameState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	gs.start_match(player_ids, rng)
	return gs


func _types(events: Array) -> Array:
	return events.map(func(e): return e["type"])


func _find(events: Array, type: String) -> Dictionary:
	for e in events:
		if e["type"] == type:
			return e
	return {}


func _seat_after(gs: GameState, pid) -> Variant:
	var idx := gs.seat_order.find(pid)
	return gs.seat_order[(idx + 1) % gs.seat_order.size()]


# —— 开局 ——

func test_start_match_deals_five_cards_and_sets_state():
	var gs := _make_gs()
	assert_eq(gs.phase, GameState.Phase.PLAYING)
	assert_eq(gs.round_number, 1)
	assert_true(gs.target_card in [Card.QUEEN, Card.KING, Card.ACE])
	assert_true(gs.current_pid in [1, 2, 3])
	assert_true(gs.last_play.is_empty())
	for pid in [1, 2, 3]:
		assert_true(gs.alive[pid])
		assert_eq(gs.hands[pid].size(), 5)


# —— 出牌 ——

func test_play_removes_cards_records_claim_and_advances_turn():
	var gs := _make_gs()
	var pid = gs.current_pid
	var result := gs.play_cards(pid, [0, 2])
	assert_true(result["ok"])
	assert_eq(gs.hands[pid].size(), 3)
	assert_eq(gs.last_play["pid"], pid)
	assert_eq(gs.last_play["count"], 2)
	assert_ne(gs.current_pid, pid)
	var types := _types(result["events"])
	assert_has(types, "played")
	assert_has(types, "turn")


func test_play_rejected_when_not_your_turn():
	var gs := _make_gs()
	var other = _seat_after(gs, gs.current_pid)
	var result := gs.play_cards(other, [0])
	assert_false(result["ok"])
	assert_eq(result["error"], "not_your_turn")


func test_play_rejected_with_invalid_indices():
	var gs := _make_gs()
	var pid = gs.current_pid
	assert_false(gs.play_cards(pid, [])["ok"])
	assert_false(gs.play_cards(pid, [0, 1, 2, 3])["ok"])
	assert_false(gs.play_cards(pid, [9])["ok"])
	assert_false(gs.play_cards(pid, [1, 1])["ok"])
	assert_eq(gs.hands[pid].size(), 5)


func test_turn_skips_empty_handed_players():
	var gs := _make_gs()
	var a = gs.current_pid
	var b = _seat_after(gs, a)
	var c = _seat_after(gs, b)
	gs.hands[b] = []
	gs.play_cards(a, [0])
	assert_eq(gs.current_pid, c)


# —— 质疑 ——

func test_first_actor_cannot_challenge():
	var gs := _make_gs()
	var result := gs.challenge(gs.current_pid)
	assert_false(result["ok"])
	assert_eq(result["error"], "nothing_to_challenge")


func test_challenge_honest_play_shoots_challenger_and_restarts_round():
	var gs := _make_gs()
	gs.target_card = Card.QUEEN
	var pid = gs.current_pid
	gs.hands[pid] = [Card.QUEEN, Card.JOKER, Card.KING, Card.KING, Card.ACE]
	gs.play_cards(pid, [0, 1])
	var challenger = gs.current_pid
	gs.revolvers[challenger].bullet_chamber = Revolver.CHAMBERS
	gs.revolvers[challenger].next_chamber = 1
	var result := gs.challenge(challenger)
	assert_true(result["ok"])
	var reveal := _find(result["events"], "reveal")
	assert_true(reveal["honest"])
	assert_eq(reveal["challenger"], challenger)
	assert_eq(reveal["target"], Card.QUEEN)
	var gunshot := _find(result["events"], "gunshot")
	assert_eq(gunshot["pid"], challenger)
	assert_false(gunshot["hit"])
	assert_has(_types(result["events"]), "round_started")
	assert_eq(gs.round_number, 2)
	assert_eq(gs.current_pid, challenger)
	for p in gs._alive_pids():
		assert_eq(gs.hands[p].size(), 5)


func test_challenge_lie_shoots_liar():
	var gs := _make_gs()
	gs.target_card = Card.QUEEN
	var pid = gs.current_pid
	gs.hands[pid] = [Card.KING, Card.QUEEN, Card.QUEEN, Card.ACE, Card.ACE]
	gs.play_cards(pid, [0])
	var challenger = gs.current_pid
	gs.revolvers[pid].bullet_chamber = Revolver.CHAMBERS
	gs.revolvers[pid].next_chamber = 1
	var result := gs.challenge(challenger)
	var gunshot := _find(result["events"], "gunshot")
	assert_eq(gunshot["pid"], pid)
	assert_eq(gs.current_pid, pid)


func test_fatal_shot_eliminates_and_ends_match():
	var gs := _make_gs([1, 2], 5)
	gs.target_card = Card.ACE
	var pid = gs.current_pid
	gs.hands[pid] = [Card.KING, Card.ACE, Card.ACE, Card.ACE, Card.ACE]
	gs.play_cards(pid, [0])
	var challenger = gs.current_pid
	gs.revolvers[pid].bullet_chamber = 1
	gs.revolvers[pid].next_chamber = 1
	var result := gs.challenge(challenger)
	var types := _types(result["events"])
	assert_has(types, "eliminated")
	assert_has(types, "match_over")
	assert_eq(gs.phase, GameState.Phase.MATCH_OVER)
	assert_eq(gs.winner_pid, challenger)
	assert_eq(gs.current_pid, null)
	assert_false(gs.play_cards(challenger, [0])["ok"])
	assert_false(gs.challenge(challenger)["ok"])


# —— 强制验证(仅剩一人有手牌)——

func test_last_player_with_cards_honest_play_auto_reveals_no_shot():
	var gs := _make_gs()
	gs.target_card = Card.QUEEN
	var pid = gs.current_pid
	for other in gs.seat_order:
		if other != pid:
			gs.hands[other] = []
	gs.hands[pid] = [Card.QUEEN, Card.JOKER]
	var result := gs.play_cards(pid, [0, 1])
	var types := _types(result["events"])
	assert_has(types, "reveal")
	assert_does_not_have(types, "gunshot")
	assert_has(types, "round_started")
	assert_eq(_find(result["events"], "reveal")["challenger"], null)
	assert_eq(gs.current_pid, pid)


func test_last_player_with_cards_lie_gets_shot():
	var gs := _make_gs()
	gs.target_card = Card.QUEEN
	var pid = gs.current_pid
	for other in gs.seat_order:
		if other != pid:
			gs.hands[other] = []
	gs.hands[pid] = [Card.KING]
	gs.revolvers[pid].bullet_chamber = Revolver.CHAMBERS
	gs.revolvers[pid].next_chamber = 1
	var result := gs.play_cards(pid, [0])
	var gunshot := _find(result["events"], "gunshot")
	assert_eq(gunshot["pid"], pid)
	assert_has(_types(result["events"]), "round_started")


# —— 断线淘汰 ——

func test_eliminate_player_advances_turn_and_voids_their_play():
	var gs := _make_gs()
	var a = gs.current_pid
	gs.play_cards(a, [0])
	var b = gs.current_pid
	var events := gs.eliminate_player(a)
	assert_has(_types(events), "eliminated")
	assert_true(gs.last_play.is_empty())
	assert_eq(gs.current_pid, b)
	assert_false(gs.alive[a])


func test_eliminate_current_player_passes_turn():
	var gs := _make_gs()
	var a = gs.current_pid
	var events := gs.eliminate_player(a)
	assert_has(_types(events), "turn")
	assert_ne(gs.current_pid, a)


func test_turn_back_to_last_player_after_disconnect_cannot_challenge_own_play():
	# A 出牌后,当前行动者 B 断线,C 已没有手牌 → 回合绕回 A;A 不能质疑自己那手牌
	var gs := _make_gs()
	var a = gs.current_pid
	var b = _seat_after(gs, a)
	var c = _seat_after(gs, b)
	gs.hands[c] = []
	gs.play_cards(a, [0])
	assert_eq(gs.current_pid, b)
	assert_eq(_types(gs.eliminate_player(b)), ["eliminated", "turn"])
	assert_eq(gs.current_pid, a)
	var result := gs.challenge(a)
	assert_false(result["ok"])
	assert_eq(result["error"], "nothing_to_challenge")
	assert_eq(gs.last_play["pid"], a)
	assert_eq(gs.revolvers[a].shots_fired(), 0)
	# A 只能继续出牌,场上只剩他有手牌 → 强制验证(无质疑者)
	var forced := gs.play_cards(a, [0])
	assert_true(forced["ok"])
	assert_eq(_find(forced["events"], "reveal")["challenger"], null)


func test_eliminate_down_to_one_wins_match():
	var gs := _make_gs([1, 2], 8)
	var loser = gs.current_pid
	var winner = _seat_after(gs, loser)
	var events := gs.eliminate_player(loser)
	assert_has(_types(events), "match_over")
	assert_eq(gs.winner_pid, winner)


func test_eliminate_dead_or_after_match_over_is_noop():
	var gs := _make_gs([1, 2], 8)
	gs.eliminate_player(gs.current_pid)
	assert_eq(gs.eliminate_player(gs.winner_pid).size(), 0)
