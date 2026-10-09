extends GutTest
# 德州规则常量:筹码单位、牌堆大小、长短牌的牌型大小顺序。


func test_money_constants_are_whole_chip_units():
	for amount in [PokerRules.STARTING_STACK, PokerRules.SMALL_BLIND, PokerRules.BIG_BLIND]:
		assert_eq(amount % PokerRules.CHIP_UNIT, 0, str(amount))
	assert_eq(PokerRules.BIG_BLIND, PokerRules.SMALL_BLIND * 2)
	assert_eq(PokerRules.STARTING_STACK / PokerRules.BIG_BLIND, 100, "起始 100 个大盲")


func test_deck_sizes():
	assert_eq(PokerRules.deck_size(false), 52)
	assert_eq(PokerRules.deck_size(true), 36)
	assert_eq(PokerRules.min_rank(true), 6)


func test_every_category_has_a_name_and_a_place_in_both_orders():
	for category in PokerRules.Category.values():
		assert_true(PokerRules.CATEGORY_NAMES.has(category))
		assert_gte(PokerRules.strength(category, false), 0)
		assert_gte(PokerRules.strength(category, true), 0)
	assert_eq(PokerRules.LONG_DECK_ORDER.size(), PokerRules.Category.size())
	assert_eq(PokerRules.SHORT_DECK_ORDER.size(), PokerRules.Category.size())


func test_long_deck_order():
	var C := PokerRules.Category
	assert_gt(PokerRules.strength(C.FULL_HOUSE, false), PokerRules.strength(C.FLUSH, false))
	assert_gt(PokerRules.strength(C.STRAIGHT, false), PokerRules.strength(C.THREE_OF_A_KIND, false))
	assert_eq(PokerRules.strength(C.STRAIGHT_FLUSH, false), PokerRules.Category.size() - 1)


func test_short_deck_only_swaps_flush_and_full_house():
	var C := PokerRules.Category
	assert_gt(PokerRules.strength(C.FLUSH, true), PokerRules.strength(C.FULL_HOUSE, true))
	assert_gt(PokerRules.strength(C.STRAIGHT, true), PokerRules.strength(C.THREE_OF_A_KIND, true), "顺子 > 三条,同长牌")
	assert_gt(PokerRules.strength(C.FOUR_OF_A_KIND, true), PokerRules.strength(C.FLUSH, true))
	var differences := 0
	for category in PokerRules.Category.values():
		if PokerRules.strength(category, true) != PokerRules.strength(category, false):
			differences += 1
	assert_eq(differences, 2, "只有同花与葫芦两个牌型互换了位置")


func test_action_sets():
	for action in PokerRules.BET_ACTIONS + PokerRules.SEAT_ACTIONS:
		assert_true(action is String and action != "")
	assert_false(PokerRules.BET_ACTIONS.has(PokerRules.BET), "bet 只出现在事件里,意图统一用 raise")


func test_seat_intents_include_sitting_back_in():
	# 网络层按 BET_ACTIONS + SEAT_ACTIONS 校验意图(规格 §3.3),这几个字符串是协议的一部分
	assert_eq(PokerRules.SEAT_ACTIONS, ["rebuy", "spectate", "sit_in", "next"])
	for action in PokerRules.SEAT_ACTIONS:
		assert_false(PokerRules.BET_ACTIONS.has(action))
	assert_eq(PokerRules.STATUS_AWAY, "away")
	assert_eq(PokerRules.AWAY_AFTER_TIMEOUTS, 2, "连续 2 次超时离座(规格 §2.8)")
