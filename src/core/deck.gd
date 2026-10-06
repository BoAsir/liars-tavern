class_name Deck
# 牌堆:Q/K/A 各 6 张 + 鬼牌 2 张,共 20 张。


const HAND_SIZE := 5
const COMPOSITION := {Card.QUEEN: 6, Card.KING: 6, Card.ACE: 6, Card.JOKER: 2}
const TARGETS := [Card.QUEEN, Card.KING, Card.ACE]


static func build() -> Array[int]:
	var cards: Array[int] = []
	for card_type in COMPOSITION:
		for i in COMPOSITION[card_type]:
			cards.append(card_type)
	return cards


static func deal(player_ids: Array, rng: RandomNumberGenerator) -> Dictionary:
	# 返回 {player_id: Array 五张手牌},Fisher-Yates 洗牌。
	assert(not player_ids.is_empty(), "player_ids must not be empty")
	assert(player_ids.size() * HAND_SIZE <= build().size(), "not enough cards for this many players")
	var cards := build()
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
	var hands := {}
	var idx := 0
	for pid in player_ids:
		hands[pid] = Array(cards.slice(idx, idx + HAND_SIZE))
		idx += HAND_SIZE
	return hands


static func pick_target(rng: RandomNumberGenerator) -> int:
	return TARGETS[rng.randi_range(0, TARGETS.size() - 1)]
