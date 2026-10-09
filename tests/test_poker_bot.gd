extends GutTest
# PokerBot.choose:德州 bot 按公共视图的合法动作挑动作(规格 §8.1 的概率表),不能加注/全下时退回跟注或过牌。

const PRESETS := [40, 80, 100, 140, 1000]   # 最小、½ 池、¾ 池、1 池、全下


func _legal(can_check: bool, can_raise := true, can_allin := true) -> Dictionary:
	return {"to_call": 0 if can_check else 20, "call_amount": 0 if can_check else 20, "can_check": can_check,
		"can_raise": can_raise, "can_allin": can_allin, "min_raise_to": 40, "max_raise_to": 1000}


func test_no_legal_actions_gives_nothing():
	assert_eq_deep(PokerBot.choose({}, PRESETS, 0.5, 0.5), {})


func test_free_check_mostly_checks():
	assert_eq_deep(PokerBot.choose(_legal(true), PRESETS, 0.0, 0.0), {"action": PokerRules.CHECK, "amount": 0})
	assert_eq_deep(PokerBot.choose(_legal(true), PRESETS, 0.54, 0.0), {"action": PokerRules.CHECK, "amount": 0})


func test_free_check_bets_min_or_half_pot():
	assert_eq_deep(PokerBot.choose(_legal(true), PRESETS, 0.56, 0.2), {"action": PokerRules.RAISE, "amount": 40})
	assert_eq_deep(PokerBot.choose(_legal(true), PRESETS, 0.89, 0.8), {"action": PokerRules.RAISE, "amount": 80})


func test_free_check_sometimes_shoves():
	assert_eq_deep(PokerBot.choose(_legal(true), PRESETS, 0.95, 0.0), {"action": PokerRules.ALLIN, "amount": 0})


func test_facing_a_bet_folds_calls_raises_or_shoves():
	var legal := _legal(false)
	assert_eq(PokerBot.choose(legal, PRESETS, 0.10, 0.0)["action"], PokerRules.FOLD)
	assert_eq(PokerBot.choose(legal, PRESETS, 0.16, 0.0)["action"], PokerRules.CALL)
	assert_eq(PokerBot.choose(legal, PRESETS, 0.74, 0.0)["action"], PokerRules.CALL)
	assert_eq_deep(PokerBot.choose(legal, PRESETS, 0.80, 0.0), {"action": PokerRules.RAISE, "amount": 40})
	assert_eq_deep(PokerBot.choose(legal, PRESETS, 0.80, 0.99), {"action": PokerRules.RAISE, "amount": 140})
	assert_eq(PokerBot.choose(legal, PRESETS, 0.95, 0.0)["action"], PokerRules.ALLIN)


func test_falls_back_to_check_or_call_when_raising_is_closed():
	assert_eq(PokerBot.choose(_legal(true, false, false), PRESETS, 0.7, 0.0)["action"], PokerRules.CHECK)
	assert_eq(PokerBot.choose(_legal(true, false, false), PRESETS, 0.95, 0.0)["action"], PokerRules.CHECK)
	assert_eq(PokerBot.choose(_legal(false, false, false), PRESETS, 0.8, 0.0)["action"], PokerRules.CALL)
	assert_eq(PokerBot.choose(_legal(false, false, false), PRESETS, 0.95, 0.0)["action"], PokerRules.CALL)


func test_short_stack_can_still_shove_without_raise_rights():
	# 筹码 ≤ 要跟的数:不能加注但能全下(记为跟注)
	assert_eq(PokerBot.choose(_legal(false, false, true), PRESETS, 0.95, 0.0)["action"], PokerRules.ALLIN)


func test_missing_presets_raise_to_the_minimum():
	assert_eq_deep(PokerBot.choose(_legal(true), [], 0.6, 0.9), {"action": PokerRules.RAISE, "amount": 40})


func test_every_choice_is_a_bet_action():
	for i in 200:
		var choice := PokerBot.choose(_legal(i % 2 == 0, i % 3 != 0, i % 5 != 0), PRESETS, randf(), randf())
		assert_true(PokerRules.BET_ACTIONS.has(choice["action"]), str(choice))
