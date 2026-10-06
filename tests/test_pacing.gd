extends GutTest


func test_empty_batch_has_no_grace():
	assert_eq(Pacing.estimate([]), 0.0)


func test_turn_only_is_free():
	assert_eq(Pacing.estimate([{"type": "turn", "pid": 1}]), 0.0)


func test_play_costs_play_time():
	var events := [{"type": "played", "pid": 1, "count": 2}, {"type": "turn", "pid": 2}]
	assert_almost_eq(Pacing.estimate(events), Pacing.PLAYED, 0.001)


func test_reveal_scales_with_card_count():
	var one := Pacing.estimate([{"type": "reveal", "cards": [0]}])
	var three := Pacing.estimate([{"type": "reveal", "cards": [0, 1, 2]}])
	assert_almost_eq(three - one, Pacing.REVEAL_PER_CARD * 2, 0.001)


func test_challenge_batch_sums_all_segments():
	var events := [
		{"type": "reveal", "cards": [0, 1]},
		{"type": "gunshot", "pid": 2, "hit": false, "shots_fired": 1},
		{"type": "round_started", "round": 2, "target": 0, "starter": 2},
	]
	var expected := Pacing.REVEAL_BASE + Pacing.REVEAL_PER_CARD * 2 + Pacing.GUNSHOT + Pacing.ROUND_STARTED
	assert_almost_eq(Pacing.estimate(events), expected, 0.001)


func test_unknown_event_types_are_ignored():
	assert_eq(Pacing.estimate([{"type": "mystery"}]), 0.0)
