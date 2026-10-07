class_name BettingRound
extends RefCounted
# 一条街的下注(规格 §2.4):有效跟注额、最小加注、能否加注、动作结算、一轮结束与「发完公共牌」的判断。
# 玩家记录归 PokerTable 所有(同一份字典,改动直接生效)。这里只动 stack / bet / committed / status,
# 以及本轮的 acted(行动过)与 acted_bet(他上次行动后的当前最高下注,用来算之后累计被加注了多少)。


var current_bet: int        # 本轮当前最高下注:翻牌前从大盲起算(大盲短码也一样),翻牌后从 0 起
var last_full_raise: int    # 最近一次完整增量:每条街开始时为大盲
var _players: Dictionary    # pid → 玩家记录
var _order: Array           # 本手发到牌的人(座位顺序的一个轮转)


func _init(players: Dictionary, order: Array, opening_bet: int) -> void:
	_players = players
	_order = order
	current_bet = opening_bet
	last_full_raise = PokerRules.BIG_BLIND
	for pid in order:
		var p: Dictionary = players[pid]
		p["bet"] = 0
		p["acted"] = false
		p["acted_bet"] = 0


func post_blind(pid: int, kind: String, amount: int) -> Dictionary:
	# 下盲不算行动(所以大盲还有选择权);筹码不够就全下
	var p: Dictionary = _players[pid]
	var paid := mini(amount, p["stack"])
	_put(p, paid)
	return {
		"type": "blind", "pid": pid, "kind": kind, "amount": paid,
		"bet": p["bet"], "stack": p["stack"], "all_in": _is_all_in(p),
	}


func live() -> Array:
	# 还在本手中(没弃牌)的人:含已全下的与全下后离开的
	return _order.filter(func(pid): return _players[pid]["status"] != PokerRules.STATUS_FOLDED)


func to_call(pid: int) -> int:
	# 有效跟注额:已全下的对手只「够得着」他本轮下的,没全下的够得着当前最高下注
	var reach := 0
	for q in live():
		if q != pid:
			var other: Dictionary = _players[q]
			reach = maxi(reach, other["bet"] if _is_all_in(other) else current_bet)
	return maxi(0, mini(current_bet, reach) - int(_players[pid]["bet"]))


func can_raise(pid: int) -> bool:
	# TDA:①本轮还没行动过,或自上次行动以来累计被加注 ≥ 最近完整增量(不完整加注不重开,累计够了才重开);
	# ②筹码多于跟注额;③还有别的在本手中的人没全下(对手都全下了,加注没人能跟)
	var p: Dictionary = _players[pid]
	var reopened: bool = not p["acted"] or current_bet - int(p["acted_bet"]) >= last_full_raise
	return reopened and p["stack"] > to_call(pid) and _another_can_bet(pid)


func legal(pid: int) -> Dictionary:
	var p: Dictionary = _players[pid]
	var owe := to_call(pid)
	var raise_ok := can_raise(pid)
	var all_in_to: int = p["bet"] + p["stack"]
	return {
		"to_call": owe,
		"call_amount": mini(owe, p["stack"]),
		"can_check": owe == 0,
		"can_raise": raise_ok,
		"can_allin": raise_ok or p["stack"] <= owe,
		# 筹码不够最小加注时唯一的加注就是全下:最小值封顶为全下额,界面夹取与「加注到最小」都不会越界
		"min_raise_to": mini(current_bet + last_full_raise, all_in_to),
		"max_raise_to": all_in_to,
	}


func apply(pid: int, action: String, amount: int) -> Dictionary:
	# 当前行动者出手 → {"ok": true, "event"} 或 {"ok": false, "error"}。amount 只对 raise 有意义(加注到)
	var rules := legal(pid)
	match action:
		PokerRules.FOLD:
			_players[pid]["status"] = PokerRules.STATUS_FOLDED
			return _acted(pid, PokerRules.FOLD, 0)
		PokerRules.CHECK:
			if rules["can_check"]:
				return _acted(pid, PokerRules.CHECK, 0)
		PokerRules.CALL:
			if rules["to_call"] > 0:
				return _acted(pid, PokerRules.CALL, rules["call_amount"])
		PokerRules.RAISE:
			if rules["can_raise"]:
				if amount % PokerRules.CHIP_UNIT != 0 or amount < rules["min_raise_to"] or amount > rules["max_raise_to"]:
					return {"ok": false, "error": "invalid_amount"}
				return _raise_to(pid, amount)
		PokerRules.ALLIN:
			if rules["can_raise"]:
				return _raise_to(pid, rules["max_raise_to"])
			if rules["can_allin"]:
				# 筹码不超过跟注额:全下记为跟注
				return _acted(pid, PokerRules.CALL, _players[pid]["stack"])
	return {"ok": false, "error": "invalid_action"}


func needs_action(pid: int) -> bool:
	var p: Dictionary = _players[pid]
	return p["status"] == PokerRules.STATUS_ACTIVE and (not p["acted"] or to_call(pid) > 0)


func is_complete() -> bool:
	# 一轮结束:在本手中且没全下的人都行动过,且都不欠跟注
	for pid in _order:
		if needs_action(pid):
			return false
	return true


func should_run_out() -> bool:
	# 没弃牌的 ≥ 2 人里没全下的 ≤ 1 人且他不欠跟注:没人还能下注,亮牌后把公共牌发完
	var alive := live()
	if alive.size() <= 1:
		return false
	var free := alive.filter(func(pid): return _players[pid]["status"] == PokerRules.STATUS_ACTIVE)
	return free.is_empty() or (free.size() == 1 and to_call(free[0]) == 0)


func next_actor(after: Variant) -> Variant:
	# 从 after 之后顺时针找第一位还要行动的人(after 本人排在最后);没有返回 null
	var start := _order.find(after)
	for i in range(1, _order.size() + 1):
		var pid: int = _order[(start + i) % _order.size()]
		if needs_action(pid):
			return pid
	return null


func collect() -> Dictionary:
	# 一轮结束:下注最高者超出第二高(含已弃牌、已离开者)的部分退回给他,其余留在底池(投入早已记进 committed)
	# → {"refund": {"pid", "amount"} 或 {}, "had_bets": 本轮有没有人下过注}
	var bets := {}
	var had_bets := false
	for pid in _order:
		bets[pid] = _players[pid]["bet"]
		had_bets = had_bets or bets[pid] > 0
	var refund := PotBuilder.uncalled(bets)
	if not refund.is_empty():
		var top: Dictionary = _players[refund["pid"]]
		top["stack"] += refund["amount"]
		top["committed"] -= refund["amount"]
	for pid in _order:
		_players[pid]["bet"] = 0
	return {"refund": refund, "had_bets": had_bets}


func _raise_to(pid: int, target: int) -> Dictionary:
	# 加注到 target:增量够最近完整增量才算完整加注并更新增量;不够的只可能是全下,不重开已行动者的加注权
	var label := PokerRules.BET if current_bet == 0 else PokerRules.RAISE
	var increment := target - current_bet
	if increment >= last_full_raise:
		last_full_raise = increment
	current_bet = target
	return _acted(pid, label, target - int(_players[pid]["bet"]))


func _acted(pid: int, label: String, chips: int) -> Dictionary:
	var p: Dictionary = _players[pid]
	_put(p, chips)
	p["acted"] = true
	p["acted_bet"] = current_bet
	var event := {
		"type": "action", "pid": pid, "action": label, "amount": chips,
		"bet": p["bet"], "stack": p["stack"], "all_in": _is_all_in(p),
	}
	return {"ok": true, "event": event}


func _put(p: Dictionary, chips: int) -> void:
	p["stack"] -= chips
	p["bet"] += chips
	p["committed"] += chips
	if p["stack"] == 0 and p["status"] == PokerRules.STATUS_ACTIVE:
		p["status"] = PokerRules.STATUS_ALLIN


func _another_can_bet(pid: int) -> bool:
	for q in live():
		if q != pid and _players[q]["status"] == PokerRules.STATUS_ACTIVE:
			return true
	return false


func _is_all_in(p: Dictionary) -> bool:
	return p["status"] == PokerRules.STATUS_ALLIN
