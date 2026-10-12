extends GutTest
# 德州机器人的内置策略:蒙特卡洛胜率、从视图提炼局面、按胜率与赔率选动作、下注额取整与夹取。
# 随机数都用固定种子,结论稳定。


const H := preload("res://tests/poker_helpers.gd")
const R := preload("res://src/core/poker/poker_rules.gd")
const SIMS := 400


func _rng(seed_value := 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _calm() -> Dictionary:
	# 不诈唬的稳健风格:结论只取决于胜率
	return PokerBotBrain.style(0).merged({"bluff": 0.0}, true)


func _sit(hole: String, board: String, legal: Dictionary, pot := 30, current_bet := 20, street := R.PREFLOP,
		opponents := 1) -> Dictionary:
	return {
		"me": 5, "hole": H.cards(hole), "board": H.cards(board), "short_deck": false, "street": street,
		"legal": legal, "pot": pot, "current_bet": current_bet, "stack": 2000, "opponents": opponents,
	}


func _owe(to_call: int, min_to: int, max_to := 2000) -> Dictionary:
	return {"to_call": to_call, "call_amount": to_call, "can_check": to_call == 0, "can_raise": true,
		"can_allin": true, "min_raise_to": min_to, "max_raise_to": max_to}


# —— 胜率 ——

func test_aces_win_most_heads_up_and_seven_deuce_rarely():
	var aces := PokerBotBrain.equity(H.cards("As Ah"), [], 1, false, _rng(), SIMS)
	var junk := PokerBotBrain.equity(H.cards("7c 2d"), [], 1, false, _rng(), SIMS)
	assert_almost_eq(aces, 0.85, 0.07, "AA 单挑约 85%")
	assert_almost_eq(junk, 0.34, 0.07, "72 杂色单挑约 34%")


func test_more_opponents_lower_the_equity():
	var one := PokerBotBrain.equity(H.cards("Kh Qh"), [], 1, false, _rng(), SIMS)
	var four := PokerBotBrain.equity(H.cards("Kh Qh"), [], 4, false, _rng(), SIMS)
	assert_gt(one, four + 0.2)


func test_the_nuts_on_the_river_always_wins():
	var win := PokerBotBrain.equity(H.cards("Ah Kh"), H.cards("Qh Jh Th 2c 3d"), 3, false, _rng(), 50)
	assert_eq(win, 1.0, "皇家同花顺")


func test_a_board_that_plays_splits_the_pot():
	# 公共牌是 A 高同花顺:谁都一样大,胜率 = 平分
	var win := PokerBotBrain.equity(H.cards("2c 3c"), H.cards("Ts Js Qs Ks As"), 1, false, _rng(), 50)
	assert_almost_eq(win, 0.5, 0.001)


func test_remaining_deck_skips_known_cards_and_follows_the_deck():
	assert_eq(PokerBotBrain.remaining_deck(H.cards("As Ah"), false).size(), 50)
	var short := PokerBotBrain.remaining_deck(H.cards("As Ah Kd"), true)
	assert_eq(short.size(), 33)
	assert_false(short.has(H.card("As")))
	assert_true(short.all(func(c: int) -> bool: return PokerCard.rank(c) >= 6), "短牌没有 2–5")


func test_equity_needs_two_hole_cards():
	assert_eq(PokerBotBrain.equity([], [], 1, false, _rng()), 0.0)


# —— 局面 ——

func test_situation_reads_the_views_of_a_real_table():
	var table := PokerTable.new(false, _rng())
	for pid in [1, -1, -2]:
		table.seat(pid)
	table.start_hand()
	var names := {1: "房主", -1: "机器人·阿福", -2: "机器人·豆豆"}
	var pub := PokerViews.public_view(table, names, GameMode.HOLDEM, 30.0)
	var me: int = pub["current_pid"]
	var sit := PokerBotBrain.situation(pub, PokerViews.private_view(table, me), me)
	assert_eq(sit["hole"].size(), 2)
	assert_eq(sit["pot"], R.SMALL_BLIND + R.BIG_BLIND, "盲注算进底池")
	assert_eq(sit["opponents"], 2)
	assert_eq(sit["legal"]["to_call"], table.legal_actions(me)["to_call"])
	assert_false(sit["legal"].has("pid"))
	var other: int = [1, -1, -2].filter(func(p: int) -> bool: return p != me)[0]
	assert_true(PokerBotBrain.situation(pub, {}, other)["legal"].is_empty(), "不轮到他时没有可选动作")


# —— 决策 ——

func test_monster_bets_when_checked_to():
	var sit := _sit("As Ah", "Ad Ac 7h", _owe(0, 20), 200, 0, R.FLOP)
	var choice := PokerBotBrain.decide(sit, _calm(), _rng(), 100)
	assert_true([R.RAISE, R.ALLIN].has(choice["action"]), "四条要下注:%s" % choice)


func test_air_checks_when_it_can():
	var sit := _sit("7c 2d", "Ah Kh Qs", _owe(0, 20), 200, 0, R.FLOP, 2)
	assert_eq(PokerBotBrain.decide(sit, _calm(), _rng(), 100)["action"], R.CHECK)


func test_air_folds_to_a_big_bet():
	var sit := _sit("7c 2d", "Ah Kh Qs", _owe(400, 800), 600, 400, R.FLOP)
	assert_eq(PokerBotBrain.decide(sit, _calm(), _rng(), 100)["action"], R.FOLD)


func test_a_cheap_call_with_a_decent_hand_is_not_folded():
	var sit := _sit("9h 9d", "", _owe(20, 40), 30, 20)
	assert_ne(PokerBotBrain.decide(sit, _calm(), _rng(), 200)["action"], R.FOLD)


func test_no_legal_actions_means_no_choice():
	assert_eq(PokerBotBrain.decide(_sit("As Ah", "", {}), _calm(), _rng()), {})


# —— 下注额 ——

func test_preflop_open_is_a_multiple_of_the_big_blind():
	var choice := PokerBotBrain.bet(_sit("As Ah", "", _owe(20, 40), 30, 20), 0.5)
	assert_eq(choice["action"], R.RAISE)
	assert_eq(choice["amount"] % R.CHIP_UNIT, 0)
	assert_between(choice["amount"], 40, 120)


func test_postflop_bet_follows_the_pot_and_is_rounded():
	var choice := PokerBotBrain.bet(_sit("As Ah", "2c 7d 9h", _owe(0, 20), 155, 0, R.FLOP), 0.5)
	assert_eq(choice, {"action": R.RAISE, "amount": 80}, "半池 77.5 向上取到 80")


func test_clamp_raise_stays_in_range_and_tops_out_as_all_in():
	var legal := _owe(100, 200, 1000)
	assert_eq(PokerBotBrain.clamp_raise(legal, 15), {"action": R.RAISE, "amount": 200}, "太小 → 最小加注")
	assert_eq(PokerBotBrain.clamp_raise(legal, 333), {"action": R.RAISE, "amount": 340}, "取整到 10")
	assert_eq(PokerBotBrain.clamp_raise(legal, 5000)["action"], R.ALLIN, "到顶就是全下")


func test_bet_without_raise_rights_falls_back_to_call_or_check():
	var legal := _owe(100, 200).merged({"can_raise": false}, true)
	assert_eq(PokerBotBrain.bet(_sit("As Ah", "", legal), 1.0)["action"], R.CALL)
	legal = _owe(0, 20).merged({"can_raise": false}, true)
	assert_eq(PokerBotBrain.bet(_sit("As Ah", "", legal), 1.0)["action"], R.CHECK)


func test_fallback_checks_or_folds():
	assert_eq(PokerBotBrain.fallback(_owe(0, 20))["action"], R.CHECK)
	assert_eq(PokerBotBrain.fallback(_owe(50, 100))["action"], R.FOLD)


func test_styles_cycle_by_index():
	assert_eq(PokerBotBrain.style(0)["id"], PokerBotBrain.style(PokerBotBrain.STYLES.size())["id"])
	assert_eq(PokerBotBrain.style(-1)["id"], PokerBotBrain.STYLES.back()["id"])
