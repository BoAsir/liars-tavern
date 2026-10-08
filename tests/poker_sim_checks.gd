extends RefCounted
# 随机模拟每一步之后的不变量(规格 §7、§8;文件名不以 test_ 开头,GUT 不会单独跑它):
# 筹码守恒、金额非负且是 10 的倍数、BETTING 时一定有能行动的行动者、牌不重复、
# 事件里的金额与座位合理、没摊牌就赢的人不亮牌也没有牌型名。出错返回说明,没出错返回 ""。

const R := preload("res://src/core/poker/poker_rules.gd")


static func table(t: PokerTable) -> String:
	if t.chips_in_play() != t.total_bought_in():
		return "筹码不守恒:桌上与带走的 %d ≠ 累计领取 %d" % [t.chips_in_play(), t.total_bought_in()]
	for pid in t.seat_order():
		var p := t.player(pid)
		var error := _amounts([p["stack"], p["bet"], p["committed"]])
		if error != "":
			return "p%d:%s" % [pid, error]
		if p["bet"] > p["committed"]:
			return "p%d 本轮下注多于本手投入" % pid
	for pot in t.pots():
		if not _chips_ok(pot["amount"]) or pot["amount"] == 0 or pot["eligible"].is_empty():
			return "底池不对:%s" % pot
	return _turn_state(t)


static func events(t: PokerTable, batch: Array) -> String:
	for i in batch.size():
		var e: Dictionary = batch[i]
		var error := _event(t, e)
		if error == "" and e["type"] == "turn" and (i != batch.size() - 1 or e["pid"] != t.current_pid()):
			error = "turn 必须是这批的最后一个事件,且是当前行动者"
		if error != "":
			return "%s 事件:%s" % [e["type"], error]
	return ""


static func _turn_state(t: PokerTable) -> String:
	var current: Variant = t.current_pid()
	if t.phase() != PokerTable.Phase.BETTING:
		return "" if current == null else "不在下注中却有行动者 p%d" % current
	if current == null:
		return "BETTING 时没有行动者"
	if t.player(current).get("status") != R.STATUS_ACTIVE or t.legal_actions(current).is_empty():
		return "行动者 p%d 不能行动" % current
	var error := _legal_shape(t, current)
	return error if error != "" else _cards_unique(t)


static func _legal_shape(t: PokerTable, pid: int) -> String:
	# 可选动作自洽(规格 §2.4):最少加注不超过全下额、跟注额不超过筹码、能过牌当且仅当不欠跟注、能加注时加得上去
	var legal := t.legal_actions(pid)
	var p := t.player(pid)
	var error := _amounts([legal["to_call"], legal["call_amount"], legal["min_raise_to"], legal["max_raise_to"]])
	if error != "":
		return "可选动作里的" + error
	if legal["max_raise_to"] != p["bet"] + p["stack"] or legal["min_raise_to"] > legal["max_raise_to"]:
		return "加注范围不对:%s" % legal
	if legal["call_amount"] != mini(legal["to_call"], p["stack"]) or legal["can_check"] != (legal["to_call"] == 0):
		return "跟注/过牌不对:%s" % legal
	if legal["to_call"] > t.current_bet() - p["bet"]:
		return "欠的比当前最高下注还多:%s" % legal
	if legal["can_raise"] and legal["min_raise_to"] <= t.current_bet():
		return "能加注却加不过当前最高下注:%s" % legal
	return ""


static func _cards_unique(t: PokerTable) -> String:
	var cards := t.board()
	for pid in t.seat_order():
		cards.append_array(t.hole_cards(pid))
	var seen := {}
	for card in cards:
		if seen.has(card):
			return "牌发重了:%s" % PokerCard.label(card)
		seen[card] = true
	return ""


static func _event(t: PokerTable, e: Dictionary) -> String:
	match e["type"]:
		"blind", "action":
			return _amounts([e["amount"], e["bet"], e["stack"]])
		"bets_collected":
			var amounts: Array = e["pots"].map(func(pot): return pot["amount"])
			if not e["refund"].is_empty():
				amounts.append(e["refund"]["amount"])
			return _amounts(amounts)
		"pot_won":
			return _pot_won(t, e)
		"reveal":
			for hand in e["hands"]:
				if t.player(hand["pid"]).get("status") == R.STATUS_FOLDED:
					return "亮了弃牌者 p%d 的牌" % hand["pid"]
		"hand_over":
			return _amounts(e["stacks"].values())
		"rebuy":
			return "" if e["amount"] == R.STARTING_STACK else "再领额 %d" % e["amount"]
		"hand_started":
			return _hand_started(e)
	return ""


static func _pot_won(t: PokerTable, e: Dictionary) -> String:
	var total := 0
	for pid in e["shares"]:
		total += e["shares"][pid]
	if total != e["amount"]:
		return "份额之和 %d ≠ 底池 %d" % [total, e["amount"]]
	var error := _amounts([e["amount"]] + e["shares"].values())
	if error != "" or not e["uncontested"]:
		return error
	if e["hand_name"] != "" or not e["best"].is_empty():
		return "没摊牌就赢却给出了牌型"
	for pid in e["winners"]:
		if not t.player(pid).get("shown", []).is_empty():
			return "没摊牌就赢的 p%d 亮了牌" % pid
	return ""


static func _hand_started(e: Dictionary) -> String:
	var dealt: Array = e["dealt"]
	if dealt.size() < R.MIN_PLAYERS or dealt.size() > R.MAX_SEATS:
		return "发牌人数 %d" % dealt.size()
	for pid in [e["button"], e["sb"], e["bb"]]:
		if not dealt.has(pid):
			return "按钮或盲注 p%s 没被发牌" % pid
	if dealt[0] != e["sb"]:
		return "发牌没从小盲起"
	if dealt.size() == PokerTable.HEADS_UP and e["sb"] != e["button"]:
		return "单挑时按钮没下小盲"
	for pid in dealt:
		if not e["seats"].has(pid):
			return "发到牌的 p%d 不在座位表里" % pid
	return ""


static func _amounts(values: Array) -> String:
	for value in values:
		if not _chips_ok(value):
			return "金额 %s 不是非负的 %d 的倍数" % [value, R.CHIP_UNIT]
	return ""


static func _chips_ok(value: Variant) -> bool:
	return value is int and value >= 0 and value % R.CHIP_UNIT == 0
