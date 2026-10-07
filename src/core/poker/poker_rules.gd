class_name PokerRules
# 德州扑克(无限注现金局)的规则常量。说明书、界面与引擎里的数字一律取自这里。


const STARTING_STACK := 2000     # 入座与每次再领的筹码
const SMALL_BLIND := 10
const BIG_BLIND := 20
const CHIP_UNIT := 10            # 所有下注额都是它的倍数;分池按它分,零头按它给
const HOLE_CARDS := 2
const FLOP_CARDS := 3
const BOARD_CARDS := 5
const MIN_PLAYERS := 2
const MAX_SEATS := 8
const SHORT_DECK_MIN_RANK := 6   # 短牌去掉 2–5

# —— 动作(网络意图与事件共用的字符串)——
const FOLD := "fold"
const CHECK := "check"
const CALL := "call"
const BET := "bet"               # 只出现在事件里:本轮还没人下注时的 raise 记为 bet
const RAISE := "raise"           # 意图里的下注与加注都用它,amount 为「加注到」
const ALLIN := "allin"
const REBUY := "rebuy"
const SPECTATE := "spectate"
const BET_ACTIONS := [FOLD, CHECK, CALL, RAISE, ALLIN]
const SEAT_ACTIONS := [REBUY, SPECTATE]

# —— 玩家状态(公共视图 players[].status)——
const STATUS_ACTIVE := "active"          # 在本手中,还能行动
const STATUS_ALLIN := "allin"            # 在本手中,已全下
const STATUS_FOLDED := "folded"          # 本手已弃牌
const STATUS_WAITING := "waiting"        # 有筹码但不在本手中,下一手发牌
const STATUS_BUSTED := "busted"          # 筹码 0,还没选择再领或观战
const STATUS_SPECTATING := "spectating"  # 筹码 0,选择了观战
const STATUS_LEFT := "left"              # 已离开,下一手开始时移出座位

# —— 下注轮 ——
const PREFLOP := "preflop"
const FLOP := "flop"
const TURN := "turn"
const RIVER := "river"
const SHOWDOWN := "showdown"

# —— 牌型(规范编号,与大小无关;大小看 category_order)——
enum Category { HIGH_CARD, ONE_PAIR, TWO_PAIR, THREE_OF_A_KIND, STRAIGHT, FLUSH, FULL_HOUSE, FOUR_OF_A_KIND, STRAIGHT_FLUSH }

const CATEGORY_NAMES := {
	Category.HIGH_CARD: "高牌",
	Category.ONE_PAIR: "一对",
	Category.TWO_PAIR: "两对",
	Category.THREE_OF_A_KIND: "三条",
	Category.STRAIGHT: "顺子",
	Category.FLUSH: "同花",
	Category.FULL_HOUSE: "葫芦",
	Category.FOUR_OF_A_KIND: "四条",
	Category.STRAIGHT_FLUSH: "同花顺",
}
const ROYAL_FLUSH_NAME := "皇家同花顺"   # A 高的同花顺:只是名字,大小同同花顺

# 牌型从小到大。短牌只有一处不同:同花 > 葫芦(36 张牌里同花比葫芦难成)。
# 三条与顺子的先后各家曾不一致,这里取 Triton 2019 年起与多数平台的现行版本:顺子 > 三条,与长牌相同
const LONG_DECK_ORDER := [
	Category.HIGH_CARD, Category.ONE_PAIR, Category.TWO_PAIR, Category.THREE_OF_A_KIND, Category.STRAIGHT,
	Category.FLUSH, Category.FULL_HOUSE, Category.FOUR_OF_A_KIND, Category.STRAIGHT_FLUSH,
]
const SHORT_DECK_ORDER := [
	Category.HIGH_CARD, Category.ONE_PAIR, Category.TWO_PAIR, Category.THREE_OF_A_KIND, Category.STRAIGHT,
	Category.FULL_HOUSE, Category.FLUSH, Category.FOUR_OF_A_KIND, Category.STRAIGHT_FLUSH,
]


static func category_order(short_deck: bool) -> Array:
	return SHORT_DECK_ORDER if short_deck else LONG_DECK_ORDER


static func strength(category: int, short_deck: bool) -> int:
	# 牌型在该玩法里的大小名次(0 最小)
	return category_order(short_deck).find(category)


static func min_rank(short_deck: bool) -> int:
	return SHORT_DECK_MIN_RANK if short_deck else PokerCard.RANK_MIN


static func deck_size(short_deck: bool) -> int:
	return (PokerCard.RANK_MAX - min_rank(short_deck) + 1) * PokerCard.SUITS.size()
