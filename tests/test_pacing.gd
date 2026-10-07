extends GutTest

# 导演 _round_started 各段的时长直接读代码里的常量:导演或牌桌改了节奏,这里的预算检查会跟着变
const TableDirectorScript := preload("res://src/ui/table/table_director.gd")
const SEAT_RETURN := TableDirectorScript.SEAT_RETURN
const SPECTATOR_SEAT_FACTOR := TableDirectorScript.SPECTATOR_SEAT_FACTOR
const SWEEP_JITTER := CardTable.SWEEP_JITTER
const TARGET_FLIP := CardTable.TARGET_FLIP_HALF * 2 + CardTable.TARGET_GLOW
const DEAL_TAIL := CardTable.DEAL_TAIL
const FRAME_SLACK := 4.0 / 30.0           # 4 个 await 各可能晚一帧(按 30 fps 估)

const CHALLENGE_BATCH := [
	{"type": "reveal", "cards": [0, 1]},
	{"type": "gunshot", "pid": 2, "hit": false, "shots_fired": 1},
	{"type": "round_started", "round": 2, "target": 0, "starter": 2},
]
const ELIMINATED_BATCH := [{"type": "eliminated", "pid": 4}]


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


func _round_started_worst(alive: int, spectator: bool) -> float:
	var seat := SEAT_RETURN * (SPECTATOR_SEAT_FACTOR if spectator else 1.0)
	var deal := alive * Deck.HAND_SIZE * CardTable.DEAL_STAGGER + CardTable.DEAL_FLIGHT + DEAL_TAIL
	return seat + CardTable.SWEEP_FLIGHT + SWEEP_JITTER + TARGET_FLIP + deal


func test_round_started_budget_covers_director_worst_case():
	# 最坏情况:强制验证为真话(无开枪段)后先回座,再收牌、翻目标牌、给满员发牌;
	# 或者自己已出局(观战机位更慢),给剩下的人发牌
	var worst := maxf(_round_started_worst(Protocol.MAX_PLAYERS, false),
		_round_started_worst(Protocol.MAX_PLAYERS - 1, true))
	assert_lte(worst + FRAME_SLACK, Pacing.ROUND_STARTED)


# —— 房主回合计时 ——

func test_starts_turn_only_for_batches_that_hand_over_the_turn():
	assert_true(Pacing.starts_turn([{"type": "played", "pid": 1, "count": 1}, {"type": "turn", "pid": 2}]))
	assert_true(Pacing.starts_turn(CHALLENGE_BATCH))
	assert_false(Pacing.starts_turn(ELIMINATED_BATCH))
	assert_false(Pacing.starts_turn([{"type": "eliminated", "pid": 3}, {"type": "match_over", "winner": 1}]))


func test_pending_animation_queues_after_unplayed_budget():
	assert_almost_eq(Pacing.pending_after(2.0, ELIMINATED_BATCH), 2.0 + Pacing.ELIMINATED, 0.001)
	# 上一批早已播完(剩余为负)时从零起算
	assert_almost_eq(Pacing.pending_after(-5.0, ELIMINATED_BATCH), Pacing.ELIMINATED, 0.001)


func test_new_turn_gets_full_timeout_after_all_pending_animation():
	var batch := [{"type": "played", "pid": 1, "count": 1}, {"type": "turn", "pid": 2}]
	var pending := Pacing.pending_after(0.7, batch)
	assert_almost_eq(Pacing.turn_timer_after(batch, pending, 12.0),
		Protocol.TURN_TIMEOUT + 0.7 + Pacing.PLAYED, 0.001)


func test_disconnect_mid_animation_extends_instead_of_restarting():
	# 质疑批次刚开始演出 1 秒,非当前玩家断线:计时不能缩回 30+1.2 秒
	var pending := Pacing.pending_after(0.0, CHALLENGE_BATCH)
	var timer := Pacing.turn_timer_after(CHALLENGE_BATCH, pending, 0.0)
	var elapsed := 1.0
	var pending_after_drop := Pacing.pending_after(pending - elapsed, ELIMINATED_BATCH)
	var extended := Pacing.turn_timer_after(ELIMINATED_BATCH, pending_after_drop, timer - elapsed)
	assert_almost_eq(extended, pending_after_drop + Protocol.TURN_TIMEOUT, 0.001)
	assert_gt(extended, timer - elapsed)


func test_disconnect_while_player_thinks_keeps_remaining_time_plus_animation():
	var pending := Pacing.pending_after(0.0, ELIMINATED_BATCH)
	assert_almost_eq(Pacing.turn_timer_after(ELIMINATED_BATCH, pending, 12.0), 12.0 + Pacing.ELIMINATED, 0.001)


func test_stopped_timer_is_treated_as_a_new_turn():
	var pending := Pacing.pending_after(0.0, ELIMINATED_BATCH)
	assert_almost_eq(Pacing.turn_timer_after(ELIMINATED_BATCH, pending, 0.0),
		pending + Protocol.TURN_TIMEOUT, 0.001)


func test_first_turn_budget_includes_intro():
	# 开局:客户端先播开场运镜再播发牌,首个行动者看完动画后仍有完整的回合时间
	var batch := [{"type": "round_started", "round": 1, "target": 0, "starter": 1}]
	var pending := Pacing.pending_after(Pacing.INTRO, batch)
	assert_almost_eq(Pacing.turn_timer_after(batch, pending, 0.0),
		Protocol.TURN_TIMEOUT + Pacing.INTRO + Pacing.ROUND_STARTED, 0.001)


func test_fatal_shot_elimination_is_not_budgeted_twice():
	# 中弹出局的 eliminated 事件没有单独演出(导演直接跳过);断线出局才有
	var fatal := [
		{"type": "gunshot", "pid": 2, "hit": true, "shots_fired": 3},
		{"type": "eliminated", "pid": 2},
	]
	assert_almost_eq(Pacing.estimate(fatal), Pacing.GUNSHOT, 0.001)
	var disconnect := [{"type": "eliminated", "pid": 3}]
	assert_almost_eq(Pacing.estimate(disconnect), Pacing.ELIMINATED, 0.001)


func test_play_budget_covers_card_flight_but_stays_tight():
	# 预算超出动画多少,倒计时刚出现时就多出多少秒:要盖住飞牌,又不能宽到明显
	assert_gte(Pacing.PLAYED, CardTable.PLAY_FLIGHT + FRAME_SLACK)
	assert_lte(Pacing.PLAYED - CardTable.PLAY_FLIGHT, 0.3)
