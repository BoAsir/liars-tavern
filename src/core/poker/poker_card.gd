class_name PokerCard
# 扑克牌编码:card = rank * 4 + suit,便于 RPC 序列化。
# rank 2–14(J=11 Q=12 K=13 A=14),suit 0=♠ 1=♥ 2=♦ 3=♣,取值 8–59。
# 与骗子酒馆的牌型(-1 牌背、0–3)不重叠,CardFaces 据取值范围分流到德州牌面。


const SPADES := 0
const HEARTS := 1
const DIAMONDS := 2
const CLUBS := 3
const SUITS := [SPADES, HEARTS, DIAMONDS, CLUBS]

const RANK_MIN := 2
const RANK_MAX := 14
const JACK := 11
const QUEEN := 12
const KING := 13
const ACE := 14

const MIN_VALUE := RANK_MIN * 4
const MAX_VALUE := RANK_MAX * 4 + CLUBS

const SUIT_SYMBOLS := ["♠", "♥", "♦", "♣"]
const SUIT_NAMES := ["黑桃", "红心", "方块", "梅花"]
const FACE_LABELS := {JACK: "J", QUEEN: "Q", KING: "K", ACE: "A"}


static func make(r: int, s: int) -> int:
	assert(r >= RANK_MIN and r <= RANK_MAX, "rank out of range")
	assert(s >= SPADES and s <= CLUBS, "suit out of range")
	return r * 4 + s


static func rank(card: int) -> int:
	return card >> 2


static func suit(card: int) -> int:
	return card & 3


static func is_card(value: Variant) -> bool:
	# 网络与视图里的牌先过这一关:类型与取值都要对
	return value is int and value >= MIN_VALUE and value <= MAX_VALUE


static func rank_label(r: int) -> String:
	return FACE_LABELS.get(r, str(r))


static func label(card: int) -> String:
	return rank_label(rank(card)) + SUIT_SYMBOLS[suit(card)]


static func labels(cards: Array) -> String:
	return " ".join(cards.map(func(c): return label(c)))
