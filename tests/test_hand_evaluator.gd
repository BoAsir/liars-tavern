extends GutTest
# 牌型评估(规格 §2.2):长短牌各牌型、短牌只换同花/葫芦、两种最小顺子、踢脚、平局、只用公共牌、7 选 5。

const H := preload("res://tests/poker_helpers.gd")
const C := PokerRules.Category


func _eval(text: String, short_deck := false) -> Dictionary:
	return HandEvaluator.evaluate(H.cards(text), short_deck)


func _cmp(a: String, b: String, short_deck := false) -> int:
	return HandEvaluator.compare(_eval(a, short_deck), _eval(b, short_deck))


# —— 长牌:各牌型与比较 ——

func test_royal_flush_beats_four_aces():
	var royal := _eval("Ah Kh Qh Jh Th 2c 3d")
	assert_eq(royal["category"], C.STRAIGHT_FLUSH)
	assert_eq(royal["name"], "皇家同花顺")
	assert_eq(royal["detail"], "皇家同花顺")
	assert_eq(royal["cards"], H.cards("Ah Kh Qh Jh Th"))
	assert_eq(_cmp("Ah Kh Qh Jh Th 2c 3d", "As Ad Ac Ah Kd 2c 3d"), 1)


func test_wheel_straight_flush_is_five_high_and_loses_to_six_high():
	var wheel := _eval("Ad 2d 3d 4d 5d Kc Qs")
	assert_eq(wheel["category"], C.STRAIGHT_FLUSH)
	assert_eq(wheel["name"], "同花顺")
	assert_eq(wheel["detail"], "同花顺 · 到 5")
	assert_eq(wheel["cards"], H.cards("5d 4d 3d 2d Ad"), "A-2-3-4-5 展示为 5 4 3 2 A")
	assert_eq(_cmp("Ad 2d 3d 4d 5d Kc Qs", "2h 3h 4h 5h 6h Ac Ad"), -1)


func test_wheel_straight_loses_to_six_high_straight_and_beats_trips():
	var wheel := _eval("As 2d 3c 4h 5s Kd 9c")
	assert_eq(wheel["category"], C.STRAIGHT)
	assert_eq(wheel["detail"], "顺子 · 到 5")
	assert_eq(wheel["cards"], H.cards("5s 4h 3c 2d As"))
	assert_eq(_cmp("As 2d 3c 4h 5s Kd 9c", "2s 3d 4c 5h 6s Kd 9c"), -1)
	assert_eq(_cmp("As 2d 3c 4h 5s Kd 9c", "Ks Kd Kc 2h 7s 9d Jc"), 1)


func test_four_of_a_kind_takes_the_biggest_kicker():
	var quads := _eval("9s 9h 9d 9c 2s Kd Qc")
	assert_eq(quads["category"], C.FOUR_OF_A_KIND)
	assert_eq(quads["cards"], H.cards("9s 9h 9d 9c Kd"))
	assert_eq(quads["detail"], "四条 · 9")
	assert_eq(_cmp("9s 9h 9d 9c 2s Kd Qc", "9s 9h 9d 9c 2s Qd Jc"), 1, "四条一样比踢脚")


func test_full_house_is_decided_by_the_trips_first():
	assert_eq(_cmp("Ks Kd Kc 2h 2d", "Qs Qd Qc Ah Ad"), 1, "KKK22 胜 QQQAA")
	assert_eq(_cmp("Ks Kd Kc 3h 3d", "Kh Ks Kc 2h 2d"), 1, "三条相同比对子")


func test_flush_compares_down_to_the_fifth_card():
	assert_eq(_cmp("Ah Jh 9h 6h 4h", "Ad Jd 9d 6d 3d"), 1)
	assert_eq(_cmp("Ah Jh 9h 6h 4h", "As Js 9s 6s 4s"), 0, "花色不分大小")


func test_two_pair_kicker_decides():
	assert_eq(_cmp("As Ad 8s 8d Kc", "Ah Ac 8h 8c Qc"), 1, "AA88K 胜 AA88Q")
	assert_eq(_cmp("As Ad 8s 8d Kc", "Ah Ac 9h 9c 2c"), -1, "第二对大的赢")


func test_quads_from_a_pocket_pair_and_the_board_with_king_kicker():
	var hole := H.cards("7h 7d")
	var board := H.cards("7c 7s Kh Kd 2c")
	var best := HandEvaluator.evaluate(hole + board, false)
	assert_eq(best["category"], C.FOUR_OF_A_KIND)
	assert_eq(H.ranks(best["cards"]), [7, 7, 7, 7, PokerCard.KING])
	assert_eq(best["detail"], "四条 · 7")


func test_three_pairs_use_the_top_two_and_the_best_kicker():
	var best := _eval("Ah Ad Kh Kd Qs Qc 2h")
	assert_eq(best["category"], C.TWO_PAIR)
	assert_eq(H.ranks(best["cards"]), [14, 14, 13, 13, 12], "第三对的 Q 当踢脚")
	assert_eq(best["detail"], "两对 · A 和 K")


func test_two_trips_make_a_full_house():
	var best := _eval("9h 9d 9c 7h 7d 7c Ks")
	assert_eq(best["category"], C.FULL_HOUSE)
	assert_eq(H.ranks(best["cards"]), [9, 9, 9, 7, 7])
	assert_eq(best["detail"], "葫芦 · 9 带 7")


func test_six_suited_cards_pick_the_top_five():
	var best := _eval("Ah Kh 9h 7h 4h 2h Qd")
	assert_eq(best["category"], C.FLUSH)
	assert_eq(best["cards"], H.cards("Ah Kh 9h 7h 4h"))
	assert_eq(best["detail"], "同花 · A 高")


func test_board_straight_is_a_split():
	var board := "5c 6d 7h 8s 9c"
	assert_eq(_cmp("2h 3d " + board, "Ks Qd " + board), 0, "两人都只用公共牌")
	assert_eq(_eval("2h 3d " + board)["cards"], H.cards("9c 8s 7h 6d 5c"))


func test_straight_uses_the_highest_run_in_seven_cards():
	var best := _eval("4c 5d 6h 7s 8c 9d Td")
	assert_eq(best["category"], C.STRAIGHT)
	assert_eq(best["detail"], "顺子 · 到 10")


func test_groups_come_first_then_kickers_by_rank():
	assert_eq(H.ranks(_eval("2c Kd 8h Ks 5d 9c 3h")["cards"]), [13, 13, 9, 8, 5])
	assert_eq(H.ranks(_eval("Js 4d Jh 9c 4c 2s 7h")["cards"]), [11, 11, 4, 4, 9])
	assert_eq(H.ranks(_eval("6s 6d 6h Ac 2c 9s 3d")["cards"]), [6, 6, 6, 14, 9])


func test_detail_text_for_every_category():
	var cases := {
		"Ah Jd 8c 6s 3h 2d 9c": ["高牌", "高牌 · A"],
		"Kh Kd 8c 6s 3h 2d 9c": ["一对", "一对 · K"],
		"Ah Ad 8c 8s 3h 2d Jc": ["两对", "两对 · A 和 8"],
		"9h 9d 9c 6s 3h 2d Jc": ["三条", "三条 · 9"],
		"7h 8d 9c Ts Jh 2d 2c": ["顺子", "顺子 · 到 J"],
		"Ah Jh 8h 6h 3h 2d 9c": ["同花", "同花 · A 高"],
		"Qh Qd Qc 7s 7h 2d 3c": ["葫芦", "葫芦 · Q 带 7"],
		"9h 9d 9c 9s 3h 2d Jc": ["四条", "四条 · 9"],
		"5h 6h 7h 8h 9h 2d Jc": ["同花顺", "同花顺 · 到 9"],
		"Th Jh Qh Kh Ah 2d 3c": ["皇家同花顺", "皇家同花顺"],
	}
	for text in cases:
		var best := _eval(text)
		assert_eq(best["name"], cases[text][0], text)
		assert_eq(best["detail"], cases[text][1], text)
		for symbol in PokerCard.SUIT_SYMBOLS:
			assert_false(best["detail"].contains(symbol), "文案里不出现花色符号")


func test_result_shape_and_score_ordering():
	var best := _eval("Ah Jd 8c 6s 3h 2d 9c")
	for key in ["category", "score", "cards", "name", "detail"]:
		assert_true(best.has(key), key)
	assert_eq(best["cards"].size(), 5)
	var pair := _eval("Kh Kd 8c 6s 3h 2d 9c")
	assert_gt(pair["score"], best["score"])
	assert_eq(HandEvaluator.compare(best, pair), -1)
	assert_eq(HandEvaluator.compare(pair, best), 1)


func test_wrong_card_counts_give_empty_result():
	assert_eq(_eval("Ah Kh Qh Jh"), {})
	assert_eq(_eval("Ah Kh Qh Jh Th 9h 8h 7h"), {})


# —— 短牌 ——

func test_short_deck_wheel_is_nine_high_and_loses_to_six_to_ten():
	var wheel := _eval("As 6d 7c 8h 9s Kd Jc", true)
	assert_eq(wheel["category"], C.STRAIGHT)
	assert_eq(wheel["detail"], "顺子 · 到 9")
	assert_eq(wheel["cards"], H.cards("9s 8h 7c 6d As"), "A-6-7-8-9 展示为 9 8 7 6 A")
	assert_eq(_cmp("As 6d 7c 8h 9s Kd Jc", "6s 7d 8c 9h Ts", true), -1)


func test_long_deck_has_no_ace_six_straight():
	assert_eq(_eval("As 6d 7c 8h 9s Kd Jc")["category"], C.HIGH_CARD)


func test_short_deck_flush_beats_full_house_but_straight_still_beats_trips():
	assert_eq(_cmp("Ah Jh 9h 7h 6h", "Ks Kd Kc Qh Qd", true), 1, "短牌:同花 > 葫芦")
	assert_eq(_cmp("Ah Jh 9h 7h 6h", "Ks Kd Kc Qh Qd", false), -1, "长牌:葫芦 > 同花")
	assert_eq(_cmp("6s 7d 8c 9h Ts", "As Ad Ac Kh Qd", true), 1, "短牌:顺子 > 三条,同长牌")


func test_short_deck_ace_six_suited_run_is_a_straight_flush():
	var best := _eval("Ah 6h 7h 8h 9h", true)
	assert_eq(best["category"], C.STRAIGHT_FLUSH)
	assert_eq(best["detail"], "同花顺 · 到 9")
	assert_eq(_eval("Ah 6h 7h 8h 9h")["category"], C.FLUSH, "长牌里只是同花")


func test_same_seven_cards_flip_full_house_versus_flush_between_decks():
	# 同一副公共牌:甲凑成葫芦,乙凑成同花。长牌甲赢,短牌乙赢
	var board := H.cards("9h 9s 6h 7h Kc")
	var full_house := H.cards("9d Kd") + board
	var flush := H.cards("Ah Jh") + board
	for short_deck in [false, true]:
		var a := HandEvaluator.evaluate(full_house, short_deck)
		var b := HandEvaluator.evaluate(flush, short_deck)
		assert_eq(a["category"], C.FULL_HOUSE)
		assert_eq(b["category"], C.FLUSH)
		assert_eq(HandEvaluator.compare(a, b), -1 if short_deck else 1, "short_deck=%s" % short_deck)


# —— 随机对拍:7 张的结果必须等于 21 种 5 张组合里(用独立的朴素算法打分)最大的那个 ——

const RANDOM_HANDS := 400


func test_matches_brute_force_on_random_seven_card_hands():
	for short_deck in [false, true]:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2026 + int(short_deck)
		for n in RANDOM_HANDS:
			var seven := PokerDeck.shuffled(short_deck, rng).slice(0, 7)
			var best := HandEvaluator.evaluate(seven, short_deck)
			var expected := _brute_best(seven, short_deck)
			if best["score"] != expected:
				fail_test("short=%s %s:评估 %d,朴素 %d" % [short_deck, PokerCard.labels(seven), best["score"], expected])
				return
			for card in best["cards"]:
				assert_true(seven.has(card))
			assert_eq(HandEvaluator.evaluate(best["cards"], short_deck)["score"], expected, "选出的 5 张自己也是这个分")


func _brute_best(seven: Array, short_deck: bool) -> int:
	var best := -1
	for skip_a in 7:
		for skip_b in range(skip_a + 1, 7):
			var five := []
			for i in 7:
				if i != skip_a and i != skip_b:
					five.append(seven[i])
			best = maxi(best, _naive_score(five, short_deck))
	return best


func _naive_score(five: Array, short_deck: bool) -> int:
	var counts := {}
	var suits := {}
	for c in five:
		counts[PokerCard.rank(c)] = counts.get(PokerCard.rank(c), 0) + 1
		suits[PokerCard.suit(c)] = true
	# 成组:按(张数、点数)降序
	var groups := []
	for r in counts:
		groups.append([counts[r], r])
	groups.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]))
	var flush := suits.size() == 1
	var high := _naive_straight_high(counts.keys(), short_deck)
	var category := C.HIGH_CARD
	if high > 0 and flush:
		category = C.STRAIGHT_FLUSH
	elif groups[0][0] == 4:
		category = C.FOUR_OF_A_KIND
	elif groups[0][0] == 3 and groups[1][0] == 2:
		category = C.FULL_HOUSE
	elif flush:
		category = C.FLUSH
	elif high > 0:
		category = C.STRAIGHT
	elif groups[0][0] == 3:
		category = C.THREE_OF_A_KIND
	elif groups[0][0] == 2 and groups[1][0] == 2:
		category = C.TWO_PAIR
	elif groups[0][0] == 2:
		category = C.ONE_PAIR
	var ranks := []
	if high > 0:
		ranks = [high, high - 1, high - 2, high - 3, high - 4]
	else:
		for g in groups:
			for i in g[0]:
				ranks.append(g[1])
	var score := PokerRules.strength(category, short_deck) << 20
	for i in 5:
		score |= ranks[i] << (4 * (4 - i))
	return score


func _naive_straight_high(distinct: Array, short_deck: bool) -> int:
	if distinct.size() != 5:
		return -1
	var sorted := distinct.duplicate()
	sorted.sort()
	if sorted[4] - sorted[0] == 4:
		return sorted[4]
	var lowest := PokerRules.min_rank(short_deck)
	if sorted == [lowest, lowest + 1, lowest + 2, lowest + 3, PokerCard.ACE]:
		return lowest + 3
	return -1
