extends GutTest
# 德州牌堆:长牌 52 张、短牌 36 张(去掉 2–5),按种子 Fisher-Yates 洗牌。


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _assert_unique_cards(cards: Array, expected_size: int, lowest_rank: int) -> void:
	assert_eq(cards.size(), expected_size)
	var seen := {}
	for card in cards:
		assert_true(PokerCard.is_card(card), str(card))
		assert_false(seen.has(card), "牌不能重复:%d" % card)
		seen[card] = true
		assert_gte(PokerCard.rank(card), lowest_rank)
	assert_eq(seen.size(), expected_size)


func test_long_deck_has_52_distinct_cards_from_two():
	var deck := PokerDeck.build(false)
	_assert_unique_cards(deck, 52, PokerCard.RANK_MIN)
	assert_eq(PokerCard.rank(deck[0]), PokerCard.RANK_MIN, "按点数升序,最小是 2")
	assert_eq(PokerCard.rank(deck[-1]), PokerCard.ACE)


func test_short_deck_has_36_distinct_cards_from_six():
	var deck := PokerDeck.build(true)
	_assert_unique_cards(deck, 36, PokerRules.SHORT_DECK_MIN_RANK)
	assert_eq(PokerCard.rank(deck[0]), PokerRules.SHORT_DECK_MIN_RANK)
	assert_eq(deck.size(), PokerRules.deck_size(true))


func test_build_is_sorted_by_rank_then_suit():
	var deck := PokerDeck.build(false)
	var sorted := deck.duplicate()
	sorted.sort()
	assert_eq(deck, sorted)
	assert_eq(deck[0], PokerCard.make(2, PokerCard.SPADES))
	assert_eq(deck[1], PokerCard.make(2, PokerCard.HEARTS))


func test_shuffled_is_a_permutation_of_the_deck():
	for short_deck in [false, true]:
		var shuffled := PokerDeck.shuffled(short_deck, _rng(7))
		var sorted := shuffled.duplicate()
		sorted.sort()
		assert_eq(sorted, PokerDeck.build(short_deck))
		assert_ne(shuffled, PokerDeck.build(short_deck), "洗过的牌不应还是原序")


func test_same_seed_same_order_different_seed_different_order():
	assert_eq(PokerDeck.shuffled(false, _rng(42)), PokerDeck.shuffled(false, _rng(42)))
	assert_ne(PokerDeck.shuffled(false, _rng(42)), PokerDeck.shuffled(false, _rng(43)))
	assert_eq(PokerDeck.shuffled(true, _rng(5)), PokerDeck.shuffled(true, _rng(5)))
	assert_ne(PokerDeck.shuffled(true, _rng(5)), PokerDeck.shuffled(true, _rng(6)))
