class_name PokerTable
extends RefCounted
# 德州状态机(规格 §2、§4.4、§4.5):只在房主端运行,不依赖节点/网络/UI。
# 动作方法返回 {"ok": bool, "error"?: String, "events"?: Array};座位变化直接返回事件数组。
# 一条街的下注细节在 BettingRound,边池/退回/分池在 PotBuilder,牌型在 HandEvaluator。
# 筹码守恒(规格 §7):在座者筹码 + 本手已投入 + 已离开者带走的 = 累计领取总额。


enum Phase { IDLE, BETTING, OVER }        # IDLE:两手之间/等人;OVER:已散局

const HEADS_UP := 2                       # 单挑:按钮下小盲,翻牌前按钮先说话
const NEXT_STREET := {
	PokerRules.PREFLOP: PokerRules.FLOP, PokerRules.FLOP: PokerRules.TURN, PokerRules.TURN: PokerRules.RIVER,
}
const STREET_CARDS := {PokerRules.FLOP: PokerRules.FLOP_CARDS, PokerRules.TURN: 1, PokerRules.RIVER: 1}
# 不在本手中的人:不发牌,按钮与盲注跳过
const SITTING_OUT := [PokerRules.STATUS_BUSTED, PokerRules.STATUS_SPECTATING, PokerRules.STATUS_AWAY]

# —— 测试钩子 ——
var button_pid: Variant = null   # 上一手的按钮:下一手按钮是他之后的下一位上桌者;为 null 时第一手随机
var rigged := {}                 # {"holes": {pid: [两张]}, "board": [≤5 张], "stacks": {pid: 筹码}}:下一手按它发,用后清空

var _short_deck: bool
var _rng: RandomNumberGenerator
var _players := {}          # pid → 玩家记录:在座的人,含要到这一手结束才移出的离开者
var _seat_order := []       # 座位顺序 = 行动顺序(俯视顺时针);新人排在末尾
var _hand_seats := []       # 本手 hand_started 的座位表(两手之间为上一手的);开局前为开局入座的人
var _departed := []         # 已移出座位的离开者 [{"pid", "stack", "buyins"}],筹码已定格
var _phase := Phase.IDLE
var _hand_number := 0
var _ending := false
var _street := ""
var _board := []
var _pending_board := []    # 本手要发的 5 张公共牌:没发出去的不外露
var _pots := []             # 已收进底池的部分(不含本轮下注)
var _dealt := []            # 本手发到牌的人,从小盲起
var _button: Variant = null
var _sb: Variant = null
var _bb: Variant = null
var _current: Variant = null
var _anchor: Variant = null    # 找下一位行动者的起点:刚出手的人;翻牌前为大盲,新的一条街为按钮
var _round: BettingRound = null


func _init(short_deck: bool, rng: RandomNumberGenerator) -> void:
	_short_deck = short_deck
	_rng = rng


# —— 座位 ——

func seat(pid: int) -> void:
	# 开局入座:筹码 2000、领取 1 次、等着发牌;开局入座的人一开始就有酒客
	if _players.has(pid):
		return
	_players[pid] = _new_player()
	_seat_order.append(pid)
	_hand_seats.append(pid)


func add_player(pid: int) -> Array:
	# 中途加入:领 2000,排在座位顺序末尾,本手旁观、下一手发牌;座位上限只数没离开的人
	if _phase == Phase.OVER or _players.has(pid) or _seated_count() >= PokerRules.MAX_SEATS:
		return []
	_players[pid] = _new_player()
	_seat_order.append(pid)
	return [{"type": "player_joined", "pid": pid}]


func remove_player(pid: int) -> Array:
	# 离开或断线(规格 §2.7):在本手中且没全下 → 立即弃牌;已全下 → 照常摊牌;
	# 不在本手中 → 空闲时立即移出,否则这一手结束时移出。他的筹码在这一手结束(退回与分池之后)才定格
	if _phase == Phase.OVER or not _is_seated(pid):
		return []
	var p: Dictionary = _players[pid]
	p["left"] = true
	if _phase == Phase.IDLE:
		_depart(pid)
		return [_left_event(pid, false)]
	var folds: bool = p["status"] == PokerRules.STATUS_ACTIVE
	var events := [_left_event(pid, folds)]
	if folds:
		p["status"] = PokerRules.STATUS_FOLDED
		if _current == pid:
			_anchor = pid
			_current = null
		_advance(events)
	return events


func rebuy(pid: int) -> Dictionary:
	# 再领(规格 §2.6):只有输光或观战的人可以(手牌中全下的人筹码也是 0,但不能领);下一手发牌
	var error := _seat_error(pid)
	if error == "" and not [PokerRules.STATUS_BUSTED, PokerRules.STATUS_SPECTATING].has(_players[pid]["status"]):
		error = "cannot_rebuy"
	if error != "":
		return _fail(error)
	var p: Dictionary = _players[pid]
	p["stack"] += PokerRules.STARTING_STACK
	p["buyins"] += 1
	p["status"] = PokerRules.STATUS_WAITING
	p["timeouts"] = 0
	return _ok([{
		"type": "rebuy", "pid": pid, "amount": PokerRules.STARTING_STACK, "buyins": p["buyins"], "stack": p["stack"],
	}])


func spectate(pid: int) -> Dictionary:
	# 观战:只有刚输光、还没选择的人可以
	return _switch_status(pid, PokerRules.STATUS_BUSTED, PokerRules.STATUS_SPECTATING, PokerRules.SPECTATE)


func sit_in(pid: int) -> Dictionary:
	# 挂机离座的人回到牌桌(规格 §2.8):回到 waiting,下一手发牌
	return _switch_status(pid, PokerRules.STATUS_AWAY, PokerRules.STATUS_WAITING, PokerRules.SIT_IN)


func request_end() -> Array:
	# 散局(规格 §2.9):有进行中的手牌就打完这一手再结算,否则立即结算
	if _phase == Phase.OVER or _ending:
		return []
	_ending = true
	if _phase == Phase.BETTING:
		return [{"type": "ending"}]
	_phase = Phase.OVER
	return [{"type": "session_over", "results": results()}]


# —— 一手 ——

func can_start_hand() -> bool:
	return _phase == Phase.IDLE and _ready_players().size() >= PokerRules.MIN_PLAYERS


func start_hand() -> Array:
	if not can_start_hand():
		return []
	var rig := rigged
	rigged = {}
	for pid in rig.get("stacks", {}):
		_players[pid]["stack"] = rig["stacks"][pid]
	_choose_positions(_ready_players())
	_hand_number += 1
	_hand_seats = _seat_order.duplicate()
	button_pid = _button
	_board = []
	_pots = []
	_street = PokerRules.PREFLOP
	_phase = Phase.BETTING
	_reset_seats_for_hand()
	_deal_cards(rig)
	var events := [{
		"type": "hand_started", "hand": _hand_number, "button": _button, "sb": _sb, "bb": _bb,
		"seats": _hand_seats.duplicate(), "dealt": _dealt.duplicate(),
	}]
	_round = BettingRound.new(_players, _dealt, PokerRules.BIG_BLIND)
	events.append(_round.post_blind(_sb, "sb", PokerRules.SMALL_BLIND))
	events.append(_round.post_blind(_bb, "bb", PokerRules.BIG_BLIND))
	events.append({"type": "hole_cards", "hand": _hand_number, "pids": _dealt.duplicate()})
	_anchor = _bb
	_current = null
	_advance(events)
	return events


func act(pid: int, action: String, amount := 0) -> Dictionary:
	var error := _seat_error(pid)
	if error == "" and not PokerRules.BET_ACTIONS.has(action):
		error = "invalid_action"
	if error == "" and _phase != Phase.BETTING:
		error = "no_hand"
	if error == "" and pid != _current:
		error = "not_your_turn"
	if error != "":
		return _fail(error)
	return _bet_action(pid, action, amount, false)


func timeout_action() -> Dictionary:
	# 回合超时代打:不欠跟注就过牌,否则弃牌;记一次连续超时
	if _phase == Phase.OVER:
		return _fail("session_over")
	if _phase != Phase.BETTING or _current == null:
		return _fail("no_hand")
	var pid: int = _current
	var action := PokerRules.CHECK if _round.to_call(pid) == 0 else PokerRules.FOLD
	return _bet_action(pid, action, 0, true)


func legal_actions(pid: int) -> Dictionary:
	# 不轮到他时为 {};否则 {"to_call", "call_amount", "can_check", "can_raise", "can_allin", "min_raise_to", "max_raise_to"}
	if _phase != Phase.BETTING or pid != _current:
		return {}
	return _round.legal(pid)


func results() -> Array:
	# 结算行(含已离开的):盈亏 = 筹码 − 领取次数 × 2000,按盈亏从高到低(同分按座位、离开的先后)
	var rows := []
	for pid in _seat_order:
		var p: Dictionary = _players[pid]
		rows.append(_result_row(pid, p["stack"], p["buyins"], p["left"]))
	for gone in _departed:
		rows.append(_result_row(gone["pid"], gone["stack"], gone["buyins"], true))
	var higher := func(a: int, b: int) -> bool:
		return rows[a]["net"] > rows[b]["net"] or (rows[a]["net"] == rows[b]["net"] and a < b)
	var order := range(rows.size())
	order.sort_custom(higher)
	return order.map(func(i: int) -> Dictionary: return rows[i])


# —— 只读访问(视图层只用这些)——

func seat_order() -> Array:
	return _seat_order.duplicate()


func player(pid: int) -> Dictionary:
	# 玩家公开信息的拷贝;已移出座位或不认识的 pid 返回 {}
	if not _players.has(pid):
		return {}
	var p: Dictionary = _players[pid]
	return {
		"stack": p["stack"], "bet": p["bet"], "committed": p["committed"], "status": p["status"],
		"left": p["left"], "buyins": p["buyins"], "net": _net(p["stack"], p["buyins"]), "shown": p["shown"].duplicate(),
	}


func hole_cards(pid: int) -> Array:
	return _players[pid]["hole"].duplicate() if _players.has(pid) else []


func best_hand(pid: int) -> Dictionary:
	# 公共牌 ≥ 3 张时的当前最大牌型 {"category", "name", "detail", "cards"};没发到牌或还没翻牌为 {}
	if not _players.has(pid) or _players[pid]["hole"].is_empty() or _board.size() < PokerRules.FLOP_CARDS:
		return {}
	var hand := HandEvaluator.evaluate(_players[pid]["hole"] + _board, _short_deck)
	return {"category": hand["category"], "name": hand["name"], "detail": hand["detail"], "cards": hand["cards"]}


func board() -> Array:
	return _board.duplicate()


func pots() -> Array:
	return _pots.duplicate(true)


func hand_number() -> int:
	return _hand_number


func street() -> String:
	return _street


func phase() -> Phase:
	return _phase


func current_pid() -> Variant:
	return _current


func current_bet() -> int:
	return _round.current_bet if _phase == Phase.BETTING else 0


func button() -> Variant:
	return _button


func small_blind() -> Variant:
	return _sb


func big_blind() -> Variant:
	return _bb


func is_ending() -> bool:
	return _ending


func seats_with_patrons() -> Array:
	# 桌上有酒客的人(规格 §4.6 的 seats):本手(空闲时为上一手)的座位表去掉已离开的;新人要等下一手才登场
	return _hand_seats.filter(func(pid): return _is_seated(pid))


func chips_in_play() -> int:
	var total := 0
	for p in _players.values():
		total += p["stack"] + p["committed"]
	for gone in _departed:
		total += gone["stack"]
	return total


func total_bought_in() -> int:
	var buyins := 0
	for p in _players.values():
		buyins += p["buyins"]
	for gone in _departed:
		buyins += gone["buyins"]
	return buyins * PokerRules.STARTING_STACK


func departed_stacks() -> Dictionary:
	# 已移出座位的离开者带走的筹码 {pid: 筹码}
	var stacks := {}
	for gone in _departed:
		stacks[gone["pid"]] = stacks.get(gone["pid"], 0) + gone["stack"]
	return stacks


# —— 开一手 ——

func _ready_players() -> Array:
	# 下一手的上桌者,按座位顺序
	return _seat_order.filter(_is_ready)


func _is_ready(pid: int) -> bool:
	# 没离开、有筹码、不在输光/观战/离座(上一手的 active/allin/folded 到发牌时都算 waiting)
	var p: Dictionary = _players[pid]
	return not p["left"] and p["stack"] > 0 and not SITTING_OUT.has(p["status"])


func _choose_positions(dealt: Array) -> void:
	# 按钮、小盲(按钮之后的下一位上桌者)、大盲(再下一位);单挑时按钮下小盲。发牌从小盲起
	_button = _next_button(dealt)
	var i := dealt.find(_button)
	if dealt.size() == HEADS_UP:
		_sb = _button
		_bb = dealt[(i + 1) % dealt.size()]
	else:
		_sb = dealt[(i + 1) % dealt.size()]
		_bb = dealt[(i + 2) % dealt.size()]
	var s := dealt.find(_sb)
	_dealt = dealt.slice(s) + dealt.slice(0, s)


func _next_button(dealt: Array) -> Variant:
	# 第一手随机;之后在上一手的座位表里,从上一手按钮顺时针往后找第一位本手上桌者(按钮本人离开或输光也一样),
	# 所以排在末尾的新人不会抢按钮
	if button_pid == null:
		return dealt[_rng.randi_range(0, dealt.size() - 1)]
	if dealt.size() == HEADS_UP and _dealt.size() > HEADS_UP and dealt.has(_bb):
		return _bb   # 从 ≥3 人变成单挑:上一手的大盲拿按钮改下小盲,免得连下两次大盲(TDA)
	var ring := _hand_seats if _hand_seats.has(button_pid) else _seat_order
	var start := ring.find(button_pid)
	for i in range(1, ring.size() + 1):
		var pid: int = ring[(start + i) % ring.size()]
		if dealt.has(pid):
			return pid
	return dealt[0]


func _reset_seats_for_hand() -> void:
	# 上一手的手牌、亮牌、投入清零;上桌者改为 active,其余人保持 waiting/busted/spectating/away
	for pid in _seat_order:
		var p: Dictionary = _players[pid]
		p["shown"] = []
		p["hole"] = []
		p["bet"] = 0
		p["committed"] = 0
		if _dealt.has(pid):
			p["status"] = PokerRules.STATUS_ACTIVE


func _deal_cards(rig: Dictionary) -> void:
	# 测试钩子指定的牌先从牌堆里拿走,其余从洗好的牌堆发;5 张公共牌一开始就定好,按街翻开
	var holes: Dictionary = rig.get("holes", {})
	var fixed_board: Array = rig.get("board", [])
	var used := {}
	for cards in holes.values() + [fixed_board]:
		for card in cards:
			used[card] = true
	var deck := Array(PokerDeck.shuffled(_short_deck, _rng)).filter(func(card): return not used.has(card))
	for pid in _dealt:
		_players[pid]["hole"] = holes[pid].duplicate() if holes.has(pid) else _draw(deck, PokerRules.HOLE_CARDS)
	_pending_board = fixed_board.duplicate() + _draw(deck, PokerRules.BOARD_CARDS - fixed_board.size())


static func _draw(deck: Array, count: int) -> Array:
	var cards := []
	for i in count:
		cards.append(deck.pop_back())
	return cards


# —— 推进 ——

func _bet_action(pid: int, action: String, amount: int, timed_out: bool) -> Dictionary:
	var result := _round.apply(pid, action, amount)
	if not result["ok"]:
		return result
	var p: Dictionary = _players[pid]
	p["timeouts"] = p["timeouts"] + 1 if timed_out else 0   # 自己的任何一次行动都清零连续超时
	var event: Dictionary = result["event"]
	event["timeout"] = timed_out
	var events := [event]
	_anchor = pid
	_current = null
	_advance(events)
	return _ok(events)


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
		if _street == PokerRules.RIVER:
			_showdown(events)
			return
		_deal_street(events)
	_pass_turn(events)


func _pass_turn(events: Array) -> void:
	# 旁人的变化(离开)不打断当前行动者;否则从起点往后找下一位还要行动的人
	if _current != null and _round.needs_action(_current):
		return
	_current = _round.next_actor(_anchor)
	events.append({"type": "turn", "pid": _current})


func _collect(events: Array) -> void:
	# 一轮结束:先退未跟注部分,再把下注收进底池;本轮没人下注(都过牌)就没有收注演出
	var result := _round.collect()
	var committed := {}
	var folded := {}
	for pid in _dealt:
		committed[pid] = _players[pid]["committed"]
		if _players[pid]["status"] == PokerRules.STATUS_FOLDED:
			folded[pid] = true
	_pots = PotBuilder.build(committed, folded, _hand_seats)
	if result["had_bets"]:
		events.append({"type": "bets_collected", "pots": _pots.duplicate(true), "refund": result["refund"]})


func _deal_street(events: Array) -> void:
	_street = NEXT_STREET[_street]
	var cards := _pending_board.slice(_board.size(), _board.size() + STREET_CARDS[_street])
	_board.append_array(cards)
	_round = BettingRound.new(_players, _dealt, 0)
	_anchor = _button
	_current = null
	events.append({"type": "street", "street": _street, "cards": cards, "board": _board.duplicate()})


func _run_out(events: Array) -> void:
	# 没人还能下注:先亮出所有没弃牌者的手牌,再把剩下的公共牌依次发完,然后摊牌
	_collect(events)
	_reveal(events, PokerRules.ALLIN if _board.size() < PokerRules.BOARD_CARDS else PokerRules.SHOWDOWN)
	while _board.size() < PokerRules.BOARD_CARDS:
		_deal_street(events)
	_showdown(events)


func _showdown(events: Array) -> void:
	# 没弃牌的人自动亮牌(全下时已亮过的不重复);从最后一个边池到主池依次分配
	_street = PokerRules.SHOWDOWN
	_reveal(events, PokerRules.SHOWDOWN)
	for i in range(_pots.size() - 1, -1, -1):
		events.append(_award_showdown(i))
	_end_hand(events)


func _award_showdown(index: int) -> Dictionary:
	# 有资格者中牌最大的赢(只有一个有资格者也照常比牌,不算没摊牌就赢)
	var pot: Dictionary = _pots[index]
	var hands := {}
	var winners := []
	for pid in pot["eligible"]:
		hands[pid] = HandEvaluator.evaluate(_players[pid]["hole"] + _board, _short_deck)
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
	for i in range(_pots.size() - 1, -1, -1):
		events.append(_pot_won(i, [winner], "", {}, true))
	_end_hand(events)


func _pot_won(index: int, winners: Array, hand_name: String, best: Dictionary, uncontested: bool) -> Dictionary:
	# 平分按 10 为单位,零头从按钮之后顺时针第一位赢家开始依次多给(winners 已按这个顺序排好)
	var amount: int = _pots[index]["amount"]
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


func _end_hand(events: Array) -> void:
	# 一手结束:投入清零;发到牌而筹码为 0 的人输光;连续超时的人离座;离开者筹码定格并移出座位;散局中就结算
	_phase = Phase.IDLE
	_current = null
	_pots = []
	var stacks := {}
	var busted := []
	for pid in _seat_order:
		var p: Dictionary = _players[pid]
		p["bet"] = 0
		p["committed"] = 0
		stacks[pid] = p["stack"]
		if _dealt.has(pid) and p["stack"] == 0:
			p["status"] = PokerRules.STATUS_BUSTED
			if not p["left"]:
				busted.append(pid)
	events.append({"type": "hand_over", "hand": _hand_number, "stacks": stacks, "busted": busted})
	if not _ending:
		_send_away(events)
	for pid in _seat_order.filter(func(q): return _players[q]["left"]):
		_depart(pid)
	if _ending:
		_phase = Phase.OVER
		events.append({"type": "session_over", "results": results()})


func _send_away(events: Array) -> void:
	# 挂机离座(规格 §2.8):连续超时够次数的人从下一手起离座,保留筹码、不发牌
	for pid in _dealt:
		var p: Dictionary = _players[pid]
		if p["timeouts"] >= PokerRules.AWAY_AFTER_TIMEOUTS and p["stack"] > 0 and not p["left"]:
			p["status"] = PokerRules.STATUS_AWAY
			p["timeouts"] = 0
			events.append({"type": "away", "pid": pid})


func _after_button(pids: Array) -> Array:
	# 按座位从按钮之后顺时针排(按钮本人排在最后)
	var start := _hand_seats.find(_button)
	var out := []
	for i in range(1, _hand_seats.size() + 1):
		var pid: int = _hand_seats[(start + i) % _hand_seats.size()]
		if pids.has(pid):
			out.append(pid)
	return out


# —— 小工具 ——

func _new_player() -> Dictionary:
	return {
		"stack": PokerRules.STARTING_STACK, "bet": 0, "committed": 0, "status": PokerRules.STATUS_WAITING,
		"left": false, "buyins": 1, "shown": [], "hole": [], "acted": false, "acted_bet": 0, "timeouts": 0,
	}


func _switch_status(pid: int, from: String, to: String, event_type: String) -> Dictionary:
	var error := _seat_error(pid)
	if error == "" and _players[pid]["status"] != from:
		error = "invalid_action"
	if error != "":
		return _fail(error)
	_players[pid]["status"] = to
	_players[pid]["timeouts"] = 0
	return _ok([{"type": event_type, "pid": pid}])


func _seat_error(pid: int) -> String:
	if _phase == Phase.OVER:
		return "session_over"
	if not _is_seated(pid):
		return "not_seated"
	return ""


func _is_seated(pid: Variant) -> bool:
	return _players.has(pid) and not _players[pid]["left"]


func _seated_count() -> int:
	return _seat_order.filter(func(pid): return not _players[pid]["left"]).size()


func _depart(pid: int) -> void:
	var p: Dictionary = _players[pid]
	_departed.append({"pid": pid, "stack": p["stack"], "buyins": p["buyins"]})
	_players.erase(pid)
	_seat_order.erase(pid)


func _left_event(pid: int, folded: bool) -> Dictionary:
	return {"type": "player_left", "pid": pid, "folded": folded}


func _result_row(pid: int, stack: int, buyins: int, left: bool) -> Dictionary:
	return {"pid": pid, "stack": stack, "buyins": buyins, "net": _net(stack, buyins), "left": left}


static func _net(stack: int, buyins: int) -> int:
	return stack - buyins * PokerRules.STARTING_STACK


static func _ok(events: Array) -> Dictionary:
	return {"ok": true, "events": events}


static func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error}
