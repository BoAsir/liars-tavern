class_name PokerViews
# 德州视图构建(规格 §4.6):决定每个客户端能看到什么。只用 PokerTable 的只读访问。
# 公共视图所有人一样,永远不含没亮的手牌(带牌的键只有 board 与 players[].shown);
# 私有视图只有自己的手牌与房主算好的当前最大牌型。


const PHASE_NAMES := {
	PokerTable.Phase.IDLE: "idle", PokerTable.Phase.BETTING: "betting", PokerTable.Phase.OVER: "over",
}


static func public_view(t: PokerTable, names: Dictionary, mode: String, turn_time_left := 0.0) -> Dictionary:
	# turn_time_left:房主回合计时器的剩余秒数(含客户端要先播完的演出);没人在行动时为 0
	var current: Variant = t.current_pid()
	return {
		"mode": mode,
		"hand": t.hand_number(),
		"phase": PHASE_NAMES[t.phase()],
		"street": t.street(),
		"board": t.board(),
		"pots": t.pots(),                      # 已收进底池的部分,不含本轮下注
		"button": t.button(),
		"sb": t.small_blind(),
		"bb": t.big_blind(),
		"current_pid": current,
		"current_bet": t.current_bet(),
		"actions": actions(t),
		"blinds": [PokerRules.SMALL_BLIND, PokerRules.BIG_BLIND],
		"seats": t.seats_with_patrons(),      # 当前桌上有酒客的人
		"players": players(t, names),
		"turn_time_left": maxf(turn_time_left, 0.0) if current != null else 0.0,
		"ending": t.is_ending(),
		"results": results(t, names) if t.phase() == PokerTable.Phase.OVER else [],
	}


static func private_view(t: PokerTable, pid: int) -> Dictionary:
	# 没被发牌的人 hole 为空;公共牌 ≥ 3 张时 best 由房主算好(没发到牌或还没翻牌为 {})
	return {"hand": t.hand_number(), "hole": t.hole_cards(pid), "best": t.best_hand(pid)}


static func actions(t: PokerTable) -> Dictionary:
	# 当前行动者的可选动作(与 legal_actions 一致,多一个 pid);没人在行动时为 {}
	var current: Variant = t.current_pid()
	if current == null:
		return {}
	var legal := t.legal_actions(current)
	return {} if legal.is_empty() else {"pid": current}.merged(legal)


static func players(t: PokerTable, names: Dictionary) -> Array:
	# 按座位顺序:本手座位表里的人(含本手里离开的)在前,还没登场的新人排在最后(引擎的座位顺序就是这样)
	var rows := []
	for pid in t.seat_order():
		var row := t.player(pid)
		row["pid"] = pid
		row["name"] = names.get(pid, str(pid))
		rows.append(row)
	return rows


static func results(t: PokerTable, names: Dictionary) -> Array:
	# 结算行补上名字(引擎不知道名字);已离开者的名字也在 names 里(会话保留)
	var rows := []
	for row in t.results():
		var named: Dictionary = row.duplicate()
		named["name"] = names.get(row["pid"], str(row["pid"]))
		rows.append(named)
	return rows
