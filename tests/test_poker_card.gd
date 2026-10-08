extends GutTest
# 扑克牌编码:往返、取值范围、与骗子酒馆牌型不重叠、文字。


func test_make_and_decode_roundtrip_for_every_card():
	var seen := {}
	for r in range(PokerCard.RANK_MIN, PokerCard.RANK_MAX + 1):
		for s in PokerCard.SUITS:
			var card := PokerCard.make(r, s)
			assert_eq(PokerCard.rank(card), r)
			assert_eq(PokerCard.suit(card), s)
			assert_false(seen.has(card), "编码不能重复")
			seen[card] = true
	assert_eq(seen.size(), 52)


func test_value_range():
	assert_eq(PokerCard.make(2, PokerCard.SPADES), PokerCard.MIN_VALUE)
	assert_eq(PokerCard.make(PokerCard.ACE, PokerCard.CLUBS), PokerCard.MAX_VALUE)


func test_values_do_not_collide_with_liars_card_kinds():
	# CardFaces 按取值分流:-1 牌背、0–3 骗子酒馆的 Q/K/A/鬼
	for kind in [CardFaces.BACK, Card.QUEEN, Card.KING, Card.ACE, Card.JOKER]:
		assert_false(PokerCard.is_card(kind), str(kind))


func test_is_card_rejects_untrusted_values():
	for value in [PokerCard.MIN_VALUE - 1, PokerCard.MAX_VALUE + 1, -5, 7.0 * 8, "8", null, [8]]:
		assert_false(PokerCard.is_card(value), str(value))
	assert_true(PokerCard.is_card(PokerCard.MIN_VALUE))
	assert_true(PokerCard.is_card(PokerCard.MAX_VALUE))


func test_labels():
	assert_eq(PokerCard.label(PokerCard.make(PokerCard.ACE, PokerCard.SPADES)), "A♠")
	assert_eq(PokerCard.label(PokerCard.make(10, PokerCard.HEARTS)), "10♥")
	assert_eq(PokerCard.label(PokerCard.make(PokerCard.QUEEN, PokerCard.DIAMONDS)), "Q♦")
	assert_eq(PokerCard.label(PokerCard.make(2, PokerCard.CLUBS)), "2♣")
	var hand := [PokerCard.make(PokerCard.KING, PokerCard.CLUBS), PokerCard.make(7, PokerCard.HEARTS)]
	assert_eq(PokerCard.labels(hand), "K♣ 7♥")
