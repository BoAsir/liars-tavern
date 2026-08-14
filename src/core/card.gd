class_name Card
# 牌面常量:用 int 表示,便于 RPC 序列化。


const QUEEN := 0
const KING := 1
const ACE := 2
const JOKER := 3

const NAMES := {QUEEN: "Q", KING: "K", ACE: "A", JOKER: "鬼"}


static func matches(card: int, target: int) -> bool:
	return card == target or card == JOKER
