extends RefCounted
# 德州测试共用的小工具(文件名不以 test_ 开头,GUT 不会把它当测试跑)。
# 牌用短字符串写:"Ah Kd Tc 9s"(T = 10;s ♠、h ♥、d ♦、c ♣)。

const RANKS := {
	"2": 2, "3": 3, "4": 4, "5": 5, "6": 6, "7": 7, "8": 8, "9": 9,
	"T": 10, "J": PokerCard.JACK, "Q": PokerCard.QUEEN, "K": PokerCard.KING, "A": PokerCard.ACE,
}
const SUITS := {"s": PokerCard.SPADES, "h": PokerCard.HEARTS, "d": PokerCard.DIAMONDS, "c": PokerCard.CLUBS}


static func cards(text: String) -> Array:
	var out := []
	for token in text.split(" ", false):
		out.append(PokerCard.make(RANKS[token[0]], SUITS[token[1]]))
	return out


static func card(text: String) -> int:
	return cards(text)[0]


static func ranks(hand: Array) -> Array:
	return hand.map(func(c): return PokerCard.rank(c))


static func types(events: Array) -> Array:
	return events.map(func(e): return e["type"])


static func find(events: Array, type: String) -> Dictionary:
	for e in events:
		if e["type"] == type:
			return e
	return {}


static func find_all(events: Array, type: String) -> Array:
	return events.filter(func(e): return e["type"] == type)
