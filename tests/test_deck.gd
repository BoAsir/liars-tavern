extends GutTest


func test_card_matches_target_or_joker():
	assert_true(Card.matches(Card.QUEEN, Card.QUEEN))
	assert_true(Card.matches(Card.JOKER, Card.QUEEN))
	assert_false(Card.matches(Card.KING, Card.QUEEN))


func test_deck_composition():
	var cards := Deck.build()
	assert_eq(cards.size(), 20)
	assert_eq(cards.count(Card.QUEEN), 6)
	assert_eq(cards.count(Card.KING), 6)
	assert_eq(cards.count(Card.ACE), 6)
	assert_eq(cards.count(Card.JOKER), 2)


func test_deal_gives_five_cards_each_and_uses_whole_deck_for_four():
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var hands := Deck.deal([1, 2, 3, 4], rng)
	assert_eq(hands.size(), 4)
	var all_cards := []
	for pid in hands:
		assert_eq(hands[pid].size(), 5)
		all_cards.append_array(hands[pid])
	all_cards.sort()
	var full := Array(Deck.build())
	full.sort()
	assert_eq(all_cards, full)


func test_pick_target_is_never_joker():
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for i in 50:
		var target := Deck.pick_target(rng)
		assert_true(target in [Card.QUEEN, Card.KING, Card.ACE])
