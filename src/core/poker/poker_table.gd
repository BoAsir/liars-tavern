class_name PokerTable
extends RefCounted
# 德州状态机(规格 §2、§4.4、§4.5):只在房主端运行,不依赖节点/网络/UI。
# 动作方法返回 {"ok": bool, "error"?: String, "events"?: Array};座位变化直接返回事件数组。
# 这里管座位与整场:入座/加入/离开、按钮与盲注位置、发牌、输光/再领/观战/离座、一手结束的收尾、散局与结算。
# 一手牌的流程在 PokerHand,一条街的下注在 BettingRound,边池/退回/分池在 PotBuilder,牌型在 HandEvaluator。
# 筹码守恒(规格 §7):在座者筹码 + 本手已投入 + 已离开者带走的 = 累计领取总额。


enum Phase { IDLE, BETTING, OVER }        # IDLE:两手之间/等人;OVER:已散局

const HEADS_UP := 2                       # 单挑:按钮下小盲,翻牌前按钮先说话
# 不在本手中的人:不发牌,按钮与盲注跳过
const SITTING_OUT := [PokerRules.STATUS_BUSTED, PokerRules.STATUS_SPECTATING, PokerRules.STATUS_AWAY]

# —— 测试钩子 ——
var button_pid: Variant = null   # 上一手的按钮:下一手按钮是他之后的下一位上桌者;为 null 时第一手随机
var rigged := {}                 # {"holes": {pid: [两张]}, "board": [≤5 张], "stacks": {pid: 筹码}}:下一手按它发,用后清空

var _short_deck: bool
var _rng: RandomNumberGenerator
var _players := {}          # pid → 玩家记录:在座的人,含要到这一手结束才移出的离开者
var _seat_order := []       # 座位顺序 = 行动顺序(俯视顺时针);新人排在末尾
var _opening_seats := []    # 开局入座的人:第一手之前他们就有酒客
var _departed := []         # 已移出座位的离开者 [{"pid", "stack", "buyins"}],筹码已定格
var _phase := Phase.IDLE
var _hand_number := 0
var _ending := false
var _hand: PokerHand = null # 进行中的一手;两手之间是刚结束的那一手(公共视图还显示它)


func _init(short_deck: bool, rng: RandomNumberGenerator) -> void:
	_short_deck = short_deck
	_rng = rng


# —— 座位 ——

func seat(pid: int) -> void:
	# 开局入座:筹码 2000、领取 1 次、等着发牌
	if _players.has(pid):
		return
	_players[pid] = _new_player()
	_seat_order.append(pid)
	_opening_seats.append(pid)


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
		events.append_array(_hand.fold(pid))
		_settle_if_over(events)
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
	var positions := _positions(_ready_players())
	_hand_number += 1
	button_pid = positions["button"]
	_reset_seats_for_hand(positions["dealt"])
	var board := _deal(rig, positions["dealt"])
	_hand = PokerHand.new(_hand_number, _players, _short_deck, positions, _seat_order.duplicate(), board)
	_phase = Phase.BETTING
	var events := [{
		"type": "hand_started", "hand": _hand_number, "button": positions["button"], "sb": positions["sb"],
		"bb": positions["bb"], "seats": _seat_order.duplicate(), "dealt": positions["dealt"].duplicate(),
	}]
	events.append_array(_hand.start())
	_settle_if_over(events)
	return events


func act(pid: int, action: String, amount := 0) -> Dictionary:
	var error := _seat_error(pid)
	if error == "" and not PokerRules.BET_ACTIONS.has(action):
		error = "invalid_action"
	if error == "" and _phase != Phase.BETTING:
		error = "no_hand"
	if error == "" and pid != _hand.current:
		error = "not_your_turn"
	if error != "":
		return _fail(error)
	return _bet_action(pid, action, amount, false)


func timeout_action() -> Dictionary:
	# 回合超时代打:不欠跟注就过牌,否则弃牌;记一次连续超时
	if _phase == Phase.OVER:
		return _fail("session_over")
	if _phase != Phase.BETTING or _hand.current == null:
		return _fail("no_hand")
	var pid: int = _hand.current
	return _bet_action(pid, PokerRules.CHECK if _hand.to_call(pid) == 0 else PokerRules.FOLD, 0, true)


func legal_actions(pid: int) -> Dictionary:
	# 不轮到他时为 {};否则 {"to_call", "call_amount", "can_check", "can_raise", "can_allin", "min_raise_to", "max_raise_to"}
	if _phase != Phase.BETTING or pid != _hand.current:
		return {}
	return _hand.legal(pid)


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
	var cards := board()
	if not _players.has(pid) or _players[pid]["hole"].is_empty() or cards.size() < PokerRules.FLOP_CARDS:
		return {}
	var hand := HandEvaluator.evaluate(_players[pid]["hole"] + cards, _short_deck)
	return {"category": hand["category"], "name": hand["name"], "detail": hand["detail"], "cards": hand["cards"]}


func board() -> Array:
	return _hand.board.duplicate() if _hand != null else []


func pots() -> Array:
	return _hand.pots.duplicate(true) if _hand != null else []


func hand_number() -> int:
	return _hand_number


func street() -> String:
	return _hand.street if _hand != null else ""


func phase() -> Phase:
	return _phase


func current_pid() -> Variant:
	return _hand.current if _hand != null else null


func current_bet() -> int:
	return _hand.current_bet() if _hand != null else 0


func button() -> Variant:
	return _hand.button if _hand != null else null


func small_blind() -> Variant:
	return _hand.small_blind if _hand != null else null


func big_blind() -> Variant:
	return _hand.big_blind if _hand != null else null


func is_ending() -> bool:
	return _ending


func seats_with_patrons() -> Array:
	# 桌上有酒客的人(规格 §4.6 的 seats):本手(空闲时为上一手)的座位表去掉已离开的;新人要等下一手才登场
	return _hand_seats().filter(_is_seated)


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


# —— 开一手:位置与发牌 ——

func _ready_players() -> Array:
	# 下一手的上桌者,按座位顺序
	return _seat_order.filter(_is_ready)


func _is_ready(pid: int) -> bool:
	# 没离开、有筹码、不在输光/观战/离座(上一手的 active/allin/folded 到发牌时都算 waiting)
	var p: Dictionary = _players[pid]
	return not p["left"] and p["stack"] > 0 and not SITTING_OUT.has(p["status"])


func _positions(ready: Array) -> Dictionary:
	# 按钮;小盲 = 按钮之后的下一位上桌者(单挑时就是按钮),大盲 = 再下一位;发牌从小盲起
	var button_at := ready.find(_next_button(ready))
	var sb_at := button_at if ready.size() == HEADS_UP else (button_at + 1) % ready.size()
	return {
		"button": ready[button_at], "sb": ready[sb_at], "bb": ready[(sb_at + 1) % ready.size()],
		"dealt": ready.slice(sb_at) + ready.slice(0, sb_at),
	}


func _next_button(ready: Array) -> int:
	# 第一手随机;之后在上一手的座位表里,从上一手按钮顺时针往后找第一位本手上桌者(按钮本人离开或输光也一样),
	# 所以排在末尾的新人不会抢按钮
	if button_pid == null:
		return ready[_rng.randi_range(0, ready.size() - 1)]
	if _hand != null and ready.size() == HEADS_UP and _hand.dealt.size() > HEADS_UP and ready.has(_hand.big_blind):
		return _hand.big_blind   # 从 ≥3 人变成单挑:上一手的大盲拿按钮改下小盲,免得连下两次大盲(TDA)
	var ring := _hand_seats() if _hand_seats().has(button_pid) else _seat_order
	var start := ring.find(button_pid)
	for i in range(1, ring.size() + 1):
		var pid: int = ring[(start + i) % ring.size()]
		if ready.has(pid):
			return pid
	return ready[0]


func _reset_seats_for_hand(dealt: Array) -> void:
	# 上一手的手牌、亮牌、投入清零;上桌者改为 active,其余人保持 waiting/busted/spectating/away
	for pid in _seat_order:
		var p: Dictionary = _players[pid]
		p["shown"] = []
		p["hole"] = []
		p["bet"] = 0
		p["committed"] = 0
		if dealt.has(pid):
			p["status"] = PokerRules.STATUS_ACTIVE


func _deal(rig: Dictionary, dealt: Array) -> Array:
	# 发手牌并定好这一手的 5 张公共牌(按街翻开)。测试钩子指定的牌先从牌堆里拿走,其余从洗好的牌堆发
	var holes: Dictionary = rig.get("holes", {})
	var fixed_board: Array = rig.get("board", [])
	var used := {}
	for cards in holes.values() + [fixed_board]:
		for card in cards:
			used[card] = true
	var deck := Array(PokerDeck.shuffled(_short_deck, _rng)).filter(func(card): return not used.has(card))
	for pid in dealt:
		_players[pid]["hole"] = holes[pid].duplicate() if holes.has(pid) else _draw(deck, PokerRules.HOLE_CARDS)
	return fixed_board.duplicate() + _draw(deck, PokerRules.BOARD_CARDS - fixed_board.size())


static func _draw(deck: Array, count: int) -> Array:
	var cards := []
	for i in count:
		cards.append(deck.pop_back())
	return cards


# —— 行动与一手结束 ——

func _bet_action(pid: int, action: String, amount: int, timed_out: bool) -> Dictionary:
	var result := _hand.act(pid, action, amount)
	if not result["ok"]:
		return result
	var p: Dictionary = _players[pid]
	p["timeouts"] = p["timeouts"] + 1 if timed_out else 0   # 自己的任何一次行动都清零连续超时
	var events: Array = result["events"]
	events[0]["timeout"] = timed_out
	_settle_if_over(events)
	return _ok(events)


func _settle_if_over(events: Array) -> void:
	if _hand.is_over():
		_end_hand(events)


func _end_hand(events: Array) -> void:
	# 一手结束:投入清零;发到牌而筹码为 0 的人输光;连续超时的人离座;离开者筹码定格并移出座位;散局中就结算
	_phase = Phase.IDLE
	var stacks := {}
	var busted := []
	for pid in _seat_order:
		var p: Dictionary = _players[pid]
		p["bet"] = 0
		p["committed"] = 0
		stacks[pid] = p["stack"]
		if _hand.dealt.has(pid) and p["stack"] == 0:
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
	for pid in _hand.dealt:
		var p: Dictionary = _players[pid]
		if p["timeouts"] >= PokerRules.AWAY_AFTER_TIMEOUTS and p["stack"] > 0 and not p["left"]:
			p["status"] = PokerRules.STATUS_AWAY
			p["timeouts"] = 0
			events.append({"type": "away", "pid": pid})


# —— 小工具 ——

func _hand_seats() -> Array:
	# 本手(两手之间为上一手)的座位表;第一手之前为开局入座的人
	return _hand.seats if _hand != null else _opening_seats


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
	return _seat_order.filter(_is_seated).size()


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
