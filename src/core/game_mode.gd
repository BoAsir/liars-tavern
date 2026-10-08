class_name GameMode
# 玩法:开房时选择,开房后不能改(想换玩法就重开房间)。纯数据,网络层、界面与规则引擎共用。
# 玩法 id 会进局域网发现报文与等待厅 meta,来自不可信对端时先用 is_valid 校验。


const LIARS := "liars"
const HOLDEM := "holdem"            # 德州扑克·长牌(52 张)
const SHORT_DECK := "short_deck"    # 德州扑克·短牌(36 张,去掉 2–5)
const ALL := [LIARS, HOLDEM, SHORT_DECK]
const DEFAULT := LIARS

const MIN_PLAYERS := 2
const LIARS_MAX_PLAYERS := 4        # 20 张牌,每人 5 张
const POKER_MAX_PLAYERS := 8

const _LABELS := {LIARS: "骗子酒馆", HOLDEM: "德州扑克·长牌", SHORT_DECK: "德州扑克·短牌"}
const _SHORT_LABELS := {LIARS: "骗子酒馆", HOLDEM: "德州·长牌", SHORT_DECK: "德州·短牌"}
const UNKNOWN_LABEL := "未知玩法"


static func is_valid(mode: Variant) -> bool:
	return mode is String and ALL.has(mode)


static func is_poker(mode: String) -> bool:
	return mode == HOLDEM or mode == SHORT_DECK


static func is_short_deck(mode: String) -> bool:
	return mode == SHORT_DECK


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
	return POKER_MAX_PLAYERS if is_poker(mode) else LIARS_MAX_PLAYERS


static func allows_late_join(mode: String) -> bool:
	# 德州是现金局:开打后新玩家仍可加入,下一手开始发牌
	return is_poker(mode)
