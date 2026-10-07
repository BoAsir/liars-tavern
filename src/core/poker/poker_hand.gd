class_name PokerHand
extends RefCounted
# 一手牌的流程(规格 §2.4、§2.5):下盲、轮流行动、收注与退回、发公共牌、全下后发完、摊牌分池、不战而胜。
# 只管这一手发到牌的人;座位、输光、离座、离开者的去留与散局归 PokerTable。
# 玩家记录与 PokerTable 共用同一份字典;一条街的下注细节在 BettingRound。
# 这一手结束后对象留着:两手之间的公共视图照样显示它的公共牌、按钮/盲注与结束时的街(规格 §4.4)。


const NEXT_STREET := {
	PokerRules.PREFLOP: PokerRules.FLOP, PokerRules.FLOP: PokerRules.TURN, PokerRules.TURN: PokerRules.RIVER,
}
const STREET_CARDS := {PokerRules.FLOP: PokerRules.FLOP_CARDS, PokerRules.TURN: 1, PokerRules.RIVER: 1}

var number: int             # 第几手
var button: int
var small_blind: int
var big_blind: int
var dealt: Array            # 发到牌的人,从小盲起
var seats: Array            # 本手的座位表(hand_started.seats)
var street := PokerRules.PREFLOP
var board := []
var pots := []              # 已收进底池的部分(不含本轮下注);这一手结束后为 []
var current: Variant = null # 轮到谁;没人在行动时为 null

var _players: Dictionary
var _short_deck: bool
var _pending_board: Array   # 这一手要发的 5 张公共牌,按街翻开;没翻的不外露
var _round: BettingRound
var _anchor: Variant = null # 找下一位行动者的起点:刚出手的人;翻牌前为大盲,新的一条街为按钮
var _over := false


func _init(p_number: int, players: Dictionary, short_deck: bool, positions: Dictionary, p_seats: Array, pending_board: Array) -> void:
	# positions:{"button", "sb", "bb", "dealt"}(由 PokerTable 定);发到牌的人的手牌已经发好
	number = p_number
	_players = players
	_short_deck = short_deck
	button = positions["button"]
	small_blind = positions["sb"]
	big_blind = positions["bb"]
	dealt = positions["dealt"]
	seats = p_seats
	_pending_board = pending_board


func start() -> Array:
	# 下盲(不算行动,大盲因此有选择权)→ 发手牌 → 轮到大盲之后第一位能行动的人(或直接发完)
	_round = BettingRound.new(_players, dealt, PokerRules.BIG_BLIND)
	var events := [
		_round.post_blind(small_blind, "sb", PokerRules.SMALL_BLIND),
		_round.post_blind(big_blind, "bb", PokerRules.BIG_BLIND),
		{"type": "hole_cards", "hand": number, "pids": dealt.duplicate()},
	]
	_anchor = big_blind
	_advance(events)
	return events


func act(pid: int, action: String, amount: int) -> Dictionary:
	# 当前行动者出手(调用方已核对轮到他)→ {"ok": true, "events"} 或 {"ok": false, "error"}
	var result := _round.apply(pid, action, amount)
	if not result["ok"]:
		return result
	var events := [result["event"]]
	_anchor = pid
	current = null
	_advance(events)
	return {"ok": true, "events": events}


func fold(pid: int) -> Array:
	# 离开的人立即弃牌(不一定轮到他):已下的注留在桌上;轮到的是别人时不打断他
	_players[pid]["status"] = PokerRules.STATUS_FOLDED
	if current == pid:
		_anchor = pid
		current = null
	var events := []
	_advance(events)
	return events


func is_over() -> bool:
	return _over


func legal(pid: int) -> Dictionary:
	return _round.legal(pid)


func to_call(pid: int) -> int:
	return _round.to_call(pid)


func current_bet() -> int:
	return 0 if _over else _round.current_bet


# —— 推进 ——

func _advance(events: Array) -> void:
	# 每次状态变化后推进:只剩一人 → 不亮牌赢下底池;没人还能下注 → 亮牌发完;一轮结束 → 下一条街;否则轮到下一位
	while true:
		if _round.live().size() == 1:
			_win_uncontested(events)
			return
		if _round.should_run_out():
			_run_out(events)
			return
		if not _round.is_complete():
			break
		_collect(events)
		if street == PokerRules.RIVER:
			_showdown(events)
			return
		_deal_street(events)
	_pass_turn(events)


func _pass_turn(events: Array) -> void:
	# 旁人的变化(离开)不打断当前行动者;否则从起点往后找下一位还要行动的人
	if current != null and _round.needs_action(current):
		return
	current = _round.next_actor(_anchor)
	events.append({"type": "turn", "pid": current})


func _collect(events: Array) -> void:
	# 一轮结束:先退未跟注部分,再把下注收进底池;本轮没人下注(都过牌)就没有收注演出
	var result := _round.collect()
	var committed := {}
	var folded := {}
	for pid in dealt:
		committed[pid] = _players[pid]["committed"]
		if _players[pid]["status"] == PokerRules.STATUS_FOLDED:
			folded[pid] = true
	pots = PotBuilder.build(committed, folded, seats)
	if result["had_bets"]:
		events.append({"type": "bets_collected", "pots": pots.duplicate(true), "refund": result["refund"]})


func _deal_street(events: Array) -> void:
	street = NEXT_STREET[street]
	var cards := _pending_board.slice(board.size(), board.size() + STREET_CARDS[street])
	board.append_array(cards)
	_round = BettingRound.new(_players, dealt, 0)
	_anchor = button
	current = null
	events.append({"type": "street", "street": street, "cards": cards, "board": board.duplicate()})


func _run_out(events: Array) -> void:
	# 没人还能下注:先亮出所有没弃牌者的手牌,再把剩下的公共牌依次发完,然后摊牌
	_collect(events)
	_reveal(events, PokerRules.ALLIN if board.size() < PokerRules.BOARD_CARDS else PokerRules.SHOWDOWN)
	while board.size() < PokerRules.BOARD_CARDS:
		_deal_street(events)
	_showdown(events)


func _showdown(events: Array) -> void:
	# 没弃牌的人自动亮牌(全下时已亮过的不重复);从最后一个边池到主池依次分配
	street = PokerRules.SHOWDOWN
	_reveal(events, PokerRules.SHOWDOWN)
	for i in range(pots.size() - 1, -1, -1):
		events.append(_award_showdown(i))
	_finish()


func _award_showdown(index: int) -> Dictionary:
	# 有资格者中牌最大的赢(只有一个有资格者也照常比牌,不算没摊牌就赢)
	var hands := {}
	var winners := []
	for pid in pots[index]["eligible"]:
		hands[pid] = HandEvaluator.evaluate(_players[pid]["hole"] + board, _short_deck)
		var cmp := 1 if winners.is_empty() else HandEvaluator.compare(hands[pid], hands[winners[0]])
		if cmp > 0:
			winners = [pid]
		elif cmp == 0:
			winners.append(pid)
	winners = _after_button(winners)
	var best := {}
	for pid in winners:
		best[pid] = hands[pid]["cards"].duplicate()
	return _pot_won(index, winners, hands[winners[0]]["name"], best, false)


func _win_uncontested(events: Array) -> void:
	# 只剩一人没弃牌:退回未跟注部分、收注后他直接赢下全部底池,不亮牌(事件里没有他的牌与牌型名)
	_collect(events)
	var winner: int = _round.live()[0]
	for i in range(pots.size() - 1, -1, -1):
		events.append(_pot_won(i, [winner], "", {}, true))
	_finish()


func _pot_won(index: int, winners: Array, hand_name: String, best: Dictionary, uncontested: bool) -> Dictionary:
	# 平分按 10 为单位,零头从按钮之后顺时针第一位赢家开始依次多给(winners 已按这个顺序排好)
	var amount: int = pots[index]["amount"]
	var shares := PotBuilder.split(amount, winners, PokerRules.CHIP_UNIT)
	for pid in shares:
		_players[pid]["stack"] += shares[pid]
	return {
		"type": "pot_won", "index": index, "amount": amount, "winners": winners, "shares": shares,
		"hand_name": hand_name, "best": best, "uncontested": uncontested,
	}


func _reveal(events: Array, reason: String) -> void:
	var hands := []
	for pid in _after_button(_round.live()):
		var p: Dictionary = _players[pid]
		if p["shown"].is_empty():
			p["shown"] = p["hole"].duplicate()
			hands.append({"pid": pid, "cards": p["hole"].duplicate()})
	if not hands.is_empty():
		events.append({"type": "reveal", "hands": hands, "reason": reason})


func _finish() -> void:
	_over = true
	current = null
	pots = []


func _after_button(pids: Array) -> Array:
	# 按座位从按钮之后顺时针排(按钮本人排在最后)
	var start := seats.find(button)
	var out := []
	for i in range(1, seats.size() + 1):
		var pid: int = seats[(start + i) % seats.size()]
		if pids.has(pid):
			out.append(pid)
	return out
