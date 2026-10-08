class_name PokerDeck
# 德州牌堆(规格 §2.1):长牌 52 张,短牌去掉 2–5 共 36 张。
# 每手由房主 RNG 用 Fisher-Yates 重新洗牌,不烧牌。


static func build(short_deck: bool) -> Array[int]:
	# 按点数、花色升序(牌值 rank * 4 + suit 本身就是这个顺序)
	var cards: Array[int] = []
	for r in range(PokerRules.min_rank(short_deck), PokerCard.RANK_MAX + 1):
		for s in PokerCard.SUITS:
			cards.append(PokerCard.make(r, s))
	return cards


static func shuffled(short_deck: bool, rng: RandomNumberGenerator) -> Array[int]:
	var cards := build(short_deck)
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
	return cards
