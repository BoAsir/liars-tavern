class_name PokerSession
extends GameSession
# 德州会话(规格 §4.2):持有 PokerTable 与名字表,把网络意图分派给引擎,给事件补名字,
# 决定一手之间的间隔与谁收私有视图。视图由 PokerViews 构建。


const MAX_AMOUNT := 1_000_000   # 意图里的金额上限(规格 §3.3):超过它一定不是正常客户端发的

var _mode: String
var _table: PokerTable = null
var _names := {}                # 含已离开者:结算行要用


func _init(mode: String) -> void:
	_mode = mode


func start(seat_order: Array, names: Dictionary, rng: RandomNumberGenerator) -> Array:
	_names = names.duplicate()
	_table = PokerTable.new(GameMode.is_short_deck(_mode), rng)
	for pid in seat_order:
		_table.seat(pid)
	return _named(_table.start_hand())


static func check_intent(action: Variant, amount: Variant) -> String:
	# RPC 参数不加类型,在这里校验(规格 §3.3):action 是本玩法的动作,amount 是 0–MAX_AMOUNT 的整数
	if not action is String or not (PokerRules.BET_ACTIONS.has(action) or PokerRules.SEAT_ACTIONS.has(action)):
		return "invalid_action"
	if not amount is int or amount < 0 or amount > MAX_AMOUNT:
		return "invalid_amount"
	return ""


func handle_intent(pid: int, intent: Dictionary) -> Dictionary:
	# 5 个下注动作走 act(消耗回合);rebuy / spectate / sit_in 各自的方法(不消耗回合)
	var action: Variant = intent.get("kind")
	var amount: Variant = intent.get("amount", 0)
	var error := check_intent(action, amount)
	if error != "":
		return rejected(error)
	var result: Dictionary
	match action:
		PokerRules.REBUY:
			result = _table.rebuy(pid)
		PokerRules.SPECTATE:
			result = _table.spectate(pid)
		PokerRules.SIT_IN:
			result = _table.sit_in(pid)
		_:
			result = _table.act(pid, action, amount)
	if not result["ok"]:
		return rejected(result["error"])
	return accepted(_named(result["events"]), PokerRules.BET_ACTIONS.has(action))


func on_disconnect(pid: int) -> Array:
	return _named(_table.remove_player(pid))


func on_turn_timeout() -> Dictionary:
	var result := _table.timeout_action()
	if not result["ok"]:
		return rejected(result["error"])
	return accepted(_named(result["events"]), true)


func public_view(turn_time_left: float) -> Dictionary:
	if _table == null:
		return {"mode": _mode}
	return PokerViews.public_view(_table, _names, _mode, turn_time_left)


func private_view(pid: int) -> Dictionary:
	return PokerViews.private_view(_table, pid)


func viewers() -> Array:
	# 所有没离开的成员:含观战、输光、等待、迟到者;本手里离开(已弃牌或全下)的人不再收
	return _table.seat_order().filter(func(pid: int) -> bool: return not _table.player(pid)["left"])


func is_over() -> bool:
	return _table.phase() == PokerTable.Phase.OVER


func is_ending() -> bool:
	return _table.is_ending()


func has_turn() -> bool:
	return _table.phase() == PokerTable.Phase.BETTING and _table.current_pid() != null


func estimate(events: Array) -> float:
	return PokerPacing.estimate(events)


func turn_timer_after(events: Array, pending: float, time_left: float) -> float:
	return PokerPacing.turn_timer_after(events, pending, time_left)


func accepts_late_join() -> bool:
	# 现金局:没散局、没结算就收人(规格 §2.7)
	return not is_over() and not is_ending()


func add_player(pid: int, name: String) -> Array:
	var events := _table.add_player(pid)
	if not events.is_empty():
		_names[pid] = name
	return _named(events)


func next_hand_ready() -> bool:
	return _table.can_start_hand()


func hand_gap() -> float:
	# 有输光者还没选再领/观战(且没离开)时留出选择时间(规格 §2.6)
	for pid in _table.seat_order():
		var p := _table.player(pid)
		if p["status"] == PokerRules.STATUS_BUSTED and not p["left"]:
			return PokerPacing.BUST_DECISION
	return PokerPacing.HAND_GAP


func start_next_hand() -> Array:
	return _named(_table.start_hand())


func request_end() -> Array:
	return _named(_table.request_end())


func seats_with_patrons() -> Array:
	return _table.seats_with_patrons() if _table != null else []


func name_of(pid: int) -> String:
	return _names.get(pid, str(pid))


func _named(events: Array) -> Array:
	# player_joined 与 session_over 里的名字由会话补(引擎不知道名字)
	for ev in events:
		match ev.get("type", ""):
			"player_joined":
				ev["name"] = name_of(ev["pid"])
			"session_over":
				for row in ev["results"]:
					row["name"] = name_of(row["pid"])
	return events
