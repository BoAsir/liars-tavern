class_name PokerScreenState
extends RefCounted
# 德州牌桌的本地状态(纯逻辑,不依赖场景树):最新的公共 / 私有视图、演出进行到哪一步的「影子行」
# (各人的筹码、下注、状态——铭牌在演出期间按它显示,视图领先于演出)、自己保存的座位表(规格 §4.2:
# 演到 hand_started 时取它的 seats,对账时视图的 seats 不同就重排)、当前行动者与摊牌条。
# 事件只改影子行;演出结束后 refresh_from_view 用视图整体覆盖。视图与事件来自网络,字段类型不对的一律当作没有。


const ROW_INTS := ["stack", "bet", "committed", "buyins", "net"]
const DEFAULT_ROW := {"stack": 0, "bet": 0, "committed": 0, "status": PokerRules.STATUS_WAITING, "left": false,
	"buyins": 1, "net": 0, "shown": []}
const UNKNOWN_NAME := "?"

var pub := {}                 # 最新公共视图
var priv := {}                # 最新私有视图
var rows := {}                # pid -> 玩家行(视图字段的拷贝,事件期间由 apply_event 推进)
var order: Array = []         # rows 的顺序(视图 players 的顺序:座位表在前,还没登场的新人在后)
var seats: Array = []         # 当前桌上有酒客的 pid(座位顺序)
var names := {}               # pid -> 名字(含已离开者)
var board: Array = []
var pots: Array = []
var hand := 0
var mode := GameMode.HOLDEM
var positions := {"button": null, "sb": null, "bb": null}
var current_pid = null        # 演出进行到的行动者(事件驱动,不随视图跳)
var in_showdown := false      # reveal 到 hand_over 之间:底部显示摊牌条
var revealed := {}            # pid -> 两张牌(摊牌条的条目)
var ending := false


# —— 视图 ——

func set_seats(entries: Array) -> void:
	# 开局 / 迟到者进牌桌时的座位表(Net.seats:[{pid, name}])
	seats = []
	for entry in entries:
		if entry is Dictionary and entry.get("pid") is int:
			seats.append(entry["pid"])
			if entry.get("name") is String:
				names[entry["pid"]] = entry["name"]


func apply_public(state: Dictionary) -> void:
	# 只记下视图:影子行与座位表由调用方在演出结束后用 refresh_from_view 对账(它会报告座位表是否变了)
	pub = state


func apply_private(state: Dictionary) -> void:
	priv = state


func refresh_from_view() -> bool:
	# 用最新视图整体覆盖影子状态;返回座位表是否变了(调用方据此重排酒客)
	if pub.is_empty():
		return false
	rows = {}
	order = []
	for p in _array(pub.get("players")):
		if p is Dictionary and p.get("pid") is int:
			rows[p["pid"]] = _clean_row(p)
			order.append(p["pid"])
			if p.get("name") is String:
				names[p["pid"]] = p["name"]
	var new_seats: Array = _array(pub.get("seats")).filter(func(pid): return pid is int)
	var reseat := new_seats != seats
	seats = new_seats
	board = _cards(pub.get("board"))
	pots = _array(pub.get("pots")).filter(func(pot): return pot is Dictionary)
	hand = pub["hand"] if pub.get("hand") is int else hand
	mode = pub["mode"] if GameMode.is_valid(pub.get("mode")) else mode
	for key in positions:
		positions[key] = pub[key] if pub.get(key) is int else null
	ending = pub.get("ending") is bool and pub["ending"]
	return reseat


func sync_from_view() -> void:
	# 迟到者的第一帧(规格 §7):不靠事件,整张桌按视图摆好,行动者与已亮的牌也从视图取
	refresh_from_view()
	current_pid = pub["current_pid"] if pub.get("current_pid") is int else null
	revealed = {}
	for pid in order:
		var shown: Array = rows[pid]["shown"]
		if shown.size() == PokerRules.HOLE_CARDS and not has_left(pid):
			revealed[pid] = shown
	in_showdown = not revealed.is_empty() and pub.get("phase") == "betting"


# —— 事件(只改影子行)——

func apply_event(ev: Dictionary) -> void:
	var pid: Variant = ev.get("pid")
	match ev.get("type", ""):
		"hand_started":
			_hand_started(ev)
		"blind", "action":
			_bet_made(pid, ev)
		"turn":
			current_pid = pid if pid is int else null
		"bets_collected":
			_bets_collected(ev)
		"street":
			board = _cards(ev.get("board"))
		"reveal":
			_reveal(ev)
		"pot_won":
			var shares: Dictionary = ev["shares"] if ev.get("shares") is Dictionary else {}
			for winner in shares:
				if rows.has(winner) and shares[winner] is int:
					rows[winner]["stack"] += shares[winner]
		"hand_over":
			_hand_over(ev)
		"rebuy":
			_set_fields(pid, {"stack": ev.get("stack"), "buyins": ev.get("buyins"), "status": PokerRules.STATUS_WAITING})
		"spectate":
			_set_fields(pid, {"status": PokerRules.STATUS_SPECTATING})
		"away":
			_set_fields(pid, {"status": PokerRules.STATUS_AWAY})
		"sit_in":
			_set_fields(pid, {"status": PokerRules.STATUS_WAITING})
		"player_joined":
			_player_joined(pid, ev.get("name"))
		"player_left":
			_player_left(pid, ev.get("folded"))
		"ending":
			ending = true


func _hand_started(ev: Dictionary) -> void:
	hand = ev["hand"] if ev.get("hand") is int else hand
	for key in positions:
		positions[key] = ev[key] if ev.get(key) is int else null
	seats = _array(ev.get("seats")).filter(func(pid): return pid is int)
	for pid in seats:
		_ensure_row(pid)
	for pid in rows:
		rows[pid]["bet"] = 0
		rows[pid]["committed"] = 0
		rows[pid]["shown"] = []
	for pid in _array(ev.get("dealt")):
		_set_fields(pid, {"status": PokerRules.STATUS_ACTIVE})
	board = []
	pots = []
	current_pid = null
	in_showdown = false
	revealed = {}


func _bet_made(pid: Variant, ev: Dictionary) -> void:
	var fields := {"stack": ev.get("stack"), "bet": ev.get("bet")}
	if ev.get("action") == PokerRules.FOLD:
		fields["status"] = PokerRules.STATUS_FOLDED
	elif ev.get("all_in") is bool and ev["all_in"]:
		fields["status"] = PokerRules.STATUS_ALLIN
	_set_fields(pid, fields)


func _bets_collected(ev: Dictionary) -> void:
	pots = _array(ev.get("pots")).filter(func(pot): return pot is Dictionary)
	for pid in rows:
		rows[pid]["bet"] = 0
	var refund: Dictionary = ev["refund"] if ev.get("refund") is Dictionary else {}
	if rows.has(refund.get("pid")) and refund.get("amount") is int:
		rows[refund["pid"]]["stack"] += refund["amount"]


func _reveal(ev: Dictionary) -> void:
	in_showdown = true
	for entry in _array(ev.get("hands")):
		if entry is Dictionary and rows.has(entry.get("pid")):
			var cards := _cards(entry.get("cards"))
			revealed[entry["pid"]] = cards
			rows[entry["pid"]]["shown"] = cards


func _hand_over(ev: Dictionary) -> void:
	var stacks: Dictionary = ev["stacks"] if ev.get("stacks") is Dictionary else {}
	for pid in stacks:
		_set_fields(pid, {"stack": stacks[pid]})
	for pid in rows:
		rows[pid]["bet"] = 0
		rows[pid]["committed"] = 0
	for pid in _array(ev.get("busted")):
		_set_fields(pid, {"status": PokerRules.STATUS_BUSTED})
	current_pid = null
	in_showdown = false
	revealed = {}


func _player_joined(pid: Variant, name: Variant) -> void:
	if not pid is int:
		return
	if name is String:
		names[pid] = name
	_ensure_row(pid)
	if not order.has(pid):
		order.append(pid)


func _player_left(pid: Variant, folded: Variant) -> void:
	var fields := {"left": true}
	if folded is bool and folded:
		fields["status"] = PokerRules.STATUS_FOLDED
	_set_fields(pid, fields)


# —— 查询 ——

func row(pid: Variant) -> Dictionary:
	return rows.get(pid, {})


func status_of(pid: Variant) -> String:
	var status: Variant = row(pid).get("status", "")
	return status if status is String else ""


func has_left(pid: Variant) -> bool:
	return PokerNameplate.has_left(row(pid))


func name_of(pid: Variant) -> String:
	return names.get(pid, UNKNOWN_NAME)


func hole() -> Array:
	return _cards(priv.get("hole"))


func hole_for_hand(number: int) -> Variant:
	# 这一手的私有手牌到了才返回,否则 null(导演最多等几秒)
	return hole() if priv.get("hand") == number else null


func best_detail() -> String:
	var best: Variant = priv.get("best")
	if best is Dictionary and best.get("detail") is String:
		return best["detail"]
	return ""


func legal(my_pid: int) -> Dictionary:
	# 视图里给自己的可选动作;不是自己的回合为 {}
	return BetControls.situation(pub, my_pid)["legal"]


func badge(pid: Variant) -> String:
	return PokerNameplate.badge_for(pid, positions)


func is_short_deck() -> bool:
	return GameMode.is_short_deck(mode)


func uses_overview(my_pid: int) -> bool:
	# 机位规则(规格 §5.5):不在座位表里(迟到者)或在观战 → 观战机位
	return TableWorld.uses_overview(seats.has(my_pid), status_of(my_pid))


func is_excluded(pid: Variant) -> bool:
	# 视线不跟随的人:观战、已离开、不认识的
	return not rows.has(pid) or has_left(pid) or status_of(pid) == PokerRules.STATUS_SPECTATING


func bottom_mode(my_pid: int) -> String:
	# 底部中间放什么(规格 §6.1):座位状态优先,其次摊牌条;下注控件(含旁人回合横幅)只在有人行动时
	var bottom := PokerHud.bottom_mode_for(row(my_pid), in_showdown)
	if bottom == PokerHud.BOTTOM_BET and current_pid == null:
		return PokerHud.BOTTOM_NONE
	return bottom


func seat_entries(my_pid: int) -> Array:
	# 给 TableWorld.arrange 的座位表;迟到者(不在座位表里)按「座位表 + 自己」排在末尾(规格 §5.5)
	var pids := seats.duplicate()
	if not pids.has(my_pid):
		pids.append(my_pid)
	return pids.map(func(pid: int) -> Dictionary: return {"pid": pid, "name": name_of(pid)})


func showdown_entries(short_deck: bool) -> Array:
	# 摊牌条:按视图顺序列出亮了牌的人;公共牌不足 3 张(翻牌前全下)时还没有牌型名
	var entries := []
	for pid in order:
		if not revealed.has(pid):
			continue
		var hand_name := ""
		if board.size() >= PokerRules.FLOP_CARDS:
			hand_name = HandEvaluator.evaluate(revealed[pid] + board, short_deck).get("detail", "")
		entries.append({"name": name_of(pid), "cards": revealed[pid], "hand_name": hand_name})
	return entries


# —— 工具 ——

func _ensure_row(pid: Variant) -> void:
	if not pid is int or rows.has(pid):
		return
	for p in _array(pub.get("players")):
		if p is Dictionary and p.get("pid") == pid:
			rows[pid] = _clean_row(p)
			return
	rows[pid] = DEFAULT_ROW.duplicate(true)
	rows[pid]["pid"] = pid


func _set_fields(pid: Variant, fields: Dictionary) -> void:
	# 影子行只收类型对的值;不认识的 pid 忽略(事件可能先于视图)
	if not rows.has(pid):
		return
	for key in fields:
		var value: Variant = fields[key]
		if (key in ROW_INTS and value is int) or (key == "status" and value is String) or (key == "left" and value is bool):
			rows[pid][key] = value


static func _clean_row(p: Dictionary) -> Dictionary:
	var out := DEFAULT_ROW.duplicate(true)
	out["pid"] = p["pid"]
	for key in ROW_INTS:
		if p.get(key) is int:
			out[key] = p[key]
	if p.get("status") is String:
		out["status"] = p["status"]
	out["left"] = p.get("left") is bool and p["left"]
	out["shown"] = _cards(p.get("shown"))
	if p.get("name") is String:
		out["name"] = p["name"]
	return out


static func _array(value: Variant) -> Array:
	return value if value is Array else []


static func _cards(value: Variant) -> Array:
	return _array(value).filter(PokerCard.is_card)
