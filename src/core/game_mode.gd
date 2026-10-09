class_name GameMode
# 玩法:开房时选择,开房后不能改(想换玩法就重开房间)。纯数据,网络层、界面与规则引擎共用。
# 玩法 id 会进局域网发现报文与等待厅 meta,来自不可信对端时先用 is_valid 校验。


const LIARS := "liars"
const HOLDEM := "holdem"            # 德州扑克·长牌(52 张)
const SHORT_DECK := "short_deck"    # 德州扑克·短牌(36 张,去掉 2–5)
const BOMB_CAT := "bomb_cat"        # 炸弹猫:摸到炸弹没拆弹就出局
# 顺序决定主菜单玩法切换的按钮顺序:两种德州挨着放最后
const ALL := [LIARS, BOMB_CAT, HOLDEM, SHORT_DECK]
const DEFAULT := LIARS
# 主菜单开房能不能选炸弹猫。只管菜单:id 照样合法(认得别人开的炸弹猫房间、网络与测试照常),
# 万一发版时牌桌界面没就绪,改成 false 就从开房菜单里藏起来
const BOMB_CAT_ENABLED := true

const MIN_PLAYERS := 2
const LIARS_MAX_PLAYERS := 4        # 20 张牌,每人 5 张
const POKER_MAX_PLAYERS := 8
const BOMB_CAT_MAX_PLAYERS := 6     # 与 BombCatDeck.MAX_PLAYERS 一致(配牌表只到 6 人)

const _LABELS := {LIARS: "骗子酒馆", HOLDEM: "德州扑克·长牌", SHORT_DECK: "德州扑克·短牌", BOMB_CAT: "炸弹猫"}
const _SHORT_LABELS := {LIARS: "骗子酒馆", HOLDEM: "德州·长牌", SHORT_DECK: "德州·短牌", BOMB_CAT: "炸弹猫"}
const UNKNOWN_LABEL := "未知玩法"


static func is_valid(mode: Variant) -> bool:
	return mode is String and ALL.has(mode)


static func is_poker(mode: String) -> bool:
	return mode == HOLDEM or mode == SHORT_DECK


static func is_short_deck(mode: String) -> bool:
	return mode == SHORT_DECK


static func is_bomb_cat(mode: String) -> bool:
	return mode == BOMB_CAT


static func menu_modes() -> Array:
	# 主菜单开房可选的玩法(按 ALL 的顺序)
	return ALL.filter(func(mode: String) -> bool: return mode != BOMB_CAT or BOMB_CAT_ENABLED)


static func label(mode: String) -> String:
	return _LABELS.get(mode, UNKNOWN_LABEL)


static func short_label(mode: String) -> String:
	return _SHORT_LABELS.get(mode, UNKNOWN_LABEL)


static func summary(mode: String) -> String:
	# 玩法全名与人数范围,如「德州扑克·短牌 · 2–8 人」:等待厅标题下一行、主菜单玩法按钮的提示
	return "%s · %d–%d 人" % [label(mode), min_players(mode), max_players(mode)]


static func min_players(_mode: String) -> int:
	return MIN_PLAYERS


static func max_players(mode: String) -> int:
	if is_poker(mode):
		return POKER_MAX_PLAYERS
	return BOMB_CAT_MAX_PLAYERS if is_bomb_cat(mode) else LIARS_MAX_PLAYERS


static func allows_late_join(mode: String) -> bool:
	# 德州是现金局:开打后新玩家仍可加入,下一手开始发牌;骗子酒馆与炸弹猫一局打到底,不收中途加入
	return is_poker(mode)
