class_name BombCatScreenState
extends RefCounted
# 炸弹猫牌桌的本地状态(纯逻辑,不碰场景;牌桌、HUD、导演、机器人都读它):
# - pub / priv:最近一份公共 / 私有视图(房主权威,领先于演出);
# - 影子行:按事件流推进的手牌张数、存活、牌堆张数、剩余炸弹、当前玩家与回合数、步骤、窗口(演出播到哪儿就显示到哪儿),
#   演出结束后 sync_from_view() 用视图兜底对齐;
# - shown_hand:屏幕上自己的手牌(按事件推进:出牌按提交的下标拿走、摸牌 / 抢来的牌等私有视图到了再追加),演完以私有视图为准;
# - 出手规则:能不能出这几张、要不要选目标 / 点名、能不能摸牌 / 不行!、塞回滑块的范围、给牌提示——都按视图判断。
# 视图与事件来自网络:字段类型不对的当缺省值,不报错。


const TARGET_KINDS := [BombCatCard.BEG, BombCatState.KIND_PAIR, BombCatState.KIND_TRIPLE]
const STEP_TURN := "turn"
const STEP_WINDOW := "window"
const STEP_REINSERT := "reinsert"
const STEP_GIVE := "give"
const STEP_OVER := "over"

var my_pid := 0
var seats: Array = []          # 座位顺序的 pid
var names := {}                # pid -> 名字
var pub := {}
var priv := {}
# —— 影子行(按事件推进)——
var counts := {}               # pid -> 手牌张数
var alive := {}                # pid -> bool
var deck_count := 0
var discard_count := 0
var discard_recent: Array = [] # 最近公开进弃牌堆的牌 id(最上面在最后,最多 BombCatLayout.DISCARD_SHOWN 张)
var bombs_total := 0
var bombs_left := 0
var current_pid: Variant = null
var turns := 0
var step := STEP_OVER
var window := {}
var out_order: Array = []
var exploded := {}             # pid -> true:炸飞的(断线出局的不在这里)
var winner: Variant = null
var shown_hand: Array = []     # 屏幕上自己的手牌(牌 id)
var started := false           # 收到过 round_started(或视图)


func set_seats(entries: Array) -> void:
	# Net.seats:[{pid, name, species}]
	seats = []
	for entry in entries:
		if entry is Dictionary and entry.get("pid") is int:
			seats.append(entry["pid"])
			names[entry["pid"]] = str(entry.get("name", entry["pid"]))
			if not counts.has(entry["pid"]):
				counts[entry["pid"]] = 0
				alive[entry["pid"]] = true


func name_of(pid: Variant) -> String:
	return names.get(pid, "?") if pid is int else "?"


# —— 视图 ——

func apply_public(view: Dictionary) -> void:
	pub = view
	for row in _players():
		if row.get("pid") is int and row.has("name"):
			names[row["pid"]] = str(row["name"])


func apply_private(view: Dictionary) -> void:
	priv = view


func sync_from_view() -> void:
	# 演出结束:影子行与屏幕上的手牌全部按视图对齐
	if pub.is_empty():
		return
	started = true
	for row in _players():
		var pid: Variant = row.get("pid")
		if not pid is int:
			continue
		counts[pid] = _int(row, "hand_count")
		alive[pid] = row.get("alive") is bool and row["alive"]
	deck_count = _int(pub, "deck_count")
	discard_count = _int(pub, "discard_count")
	var top: Variant = pub.get("discard_top", "")
	if BombCatCard.is_valid(top) and (discard_recent.is_empty() or discard_recent[-1] != top):
		discard_recent = [top]
	if not BombCatCard.is_valid(top):
		discard_recent = []
	bombs_total = _int(pub, "bombs_total")
	bombs_left = _int(pub, "bombs_left")
	current_pid = pub.get("current_pid") if pub.get("current_pid") is int else null
	turns = _int(pub, "turns")
	step = str(pub.get("step", STEP_OVER))
	window = pub["window"].duplicate() if pub.get("window") is Dictionary else {}
	out_order = pub["out_order"].duplicate() if pub.get("out_order") is Array else []
	winner = pub.get("winner") if pub.get("winner") is int else null
	shown_hand = private_hand()


func apply_event(ev: Dictionary) -> void:
	# 演出每段开始前推进影子行(铭牌、左上信息跟着演出走,不抢先跳到视图)
	match ev.get("type", ""):
		"round_started":
			started = true
			if ev.get("seats") is Array:
				seats = ev["seats"].filter(func(p): return p is int)
			for row in (ev["hands"] if ev.get("hands") is Array else []):
				if row is Dictionary and row.get("pid") is int:
					counts[row["pid"]] = _int(row, "count")
					alive[row["pid"]] = true
			deck_count = _int(ev, "deck_count")
			bombs_total = _int(ev, "bombs")
			bombs_left = bombs_total
			current_pid = ev.get("current") if ev.get("current") is int else null
			turns = _int(ev, "turns")
			step = STEP_TURN
			discard_count = 0
			discard_recent = []
			out_order = []
		"played":
			var cards: Array = ev["cards"].filter(BombCatCard.is_valid) if ev.get("cards") is Array else []
			_add_count(ev.get("pid"), -cards.size())
			_discard(cards)
			step = STEP_WINDOW
			window = {"pid": ev.get("pid"), "cards": cards, "kind": str(ev.get("kind", "")), "target": ev.get("target"),
				"named": str(ev.get("named", "")), "nopes": 0}
		"noped":
			_add_count(ev.get("pid"), -1)
			_discard([BombCatCard.NOPE])
			window["nopes"] = _int(ev, "depth")
		"window_resolved":
			step = STEP_TURN
			window = {}
		"effect":
			if ev.get("got") is bool and ev["got"]:
				_add_count(ev.get("from"), -1)
				_add_count(ev.get("to"), 1)
			if step == STEP_GIVE:
				step = STEP_TURN
		"give_requested":
			step = STEP_GIVE
		"drew":
			deck_count = _int(ev, "deck_count")
			if not (ev.get("bomb") is bool and ev["bomb"]):
				_add_count(ev.get("pid"), 1)
		"defused":
			_add_count(ev.get("pid"), -1)
			_discard([BombCatCard.DEFUSE])
			deck_count = _int(ev, "deck_count")
			step = STEP_REINSERT
		"reinserted":
			deck_count = _int(ev, "deck_count")
			step = STEP_TURN
		"exploded", "player_left":
			var pid: Variant = ev.get("pid")
			if pid is int:
				alive[pid] = false
				discard_count += counts.get(pid, 0)
				counts[pid] = 0
				if not out_order.has(pid):
					out_order.append(pid)
				if ev["type"] == "exploded":
					exploded[pid] = true
					bombs_left = maxi(bombs_left - 1, 0)
		"turn_passed":
			current_pid = ev.get("pid") if ev.get("pid") is int else null
			turns = _int(ev, "turns")
			step = STEP_TURN
		"match_over":
			step = STEP_OVER
			winner = ev.get("winner") if ev.get("winner") is int else null
			current_pid = null


func _add_count(pid: Variant, delta: int) -> void:
	if pid is int:
		counts[pid] = maxi(counts.get(pid, 0) + delta, 0)


func _discard(cards: Array) -> void:
	discard_count += cards.size()
	discard_recent.append_array(cards)
	while discard_recent.size() > BombCatLayout.DISCARD_SHOWN:
		discard_recent.pop_front()


# —— 屏幕上的自己的手牌 ——

func private_hand() -> Array:
	return priv["hand"].filter(BombCatCard.is_valid) if priv.get("hand") is Array else []


func take_from_shown(ids: Array, indices: Array) -> Array:
	# 自己出牌 / 不行! / 拆弹时屏幕上拿走的那几张的下标(按提交的下标,对不上就按牌型找);返回实际拿走的下标(升序)
	var picked := []
	var by_index := indices.size() == ids.size()
	for k in indices.size():
		var i: Variant = indices[k]
		if not (i is int and i >= 0 and i < shown_hand.size() and shown_hand[i] == ids[k]):
			by_index = false
	if by_index:
		picked = indices.duplicate()
	else:
		for id in ids:
			for i in shown_hand.size():
				if shown_hand[i] == id and not picked.has(i):
					picked.append(i)
					break
	picked.sort()
	for k in range(picked.size() - 1, -1, -1):
		shown_hand.remove_at(picked[k])
	return picked


func add_to_shown(id: String) -> void:
	if BombCatCard.is_valid(id):
		shown_hand.append(id)


func remove_from_shown(id: String) -> int:
	var at := shown_hand.find(id)
	if at >= 0:
		shown_hand.remove_at(at)
	elif not shown_hand.is_empty():
		at = shown_hand.size() - 1
		shown_hand.remove_at(at)
	return at


# —— 视图里的事实 ——

func pub_step() -> String:
	return str(pub.get("step", STEP_OVER))


func pub_current() -> Variant:
	return pub.get("current_pid") if pub.get("current_pid") is int else null


func am_alive() -> bool:
	if priv.has("alive"):
		return priv["alive"] is bool and priv["alive"]
	return alive.get(my_pid, false)


func is_alive(pid: Variant) -> bool:
	return pid is int and alive.get(pid, false)


func players_rows() -> Array:
	return _players()


func last_drawn() -> Dictionary:
	# {"card", "seq"}
	return {"card": str(priv.get("last_drawn", "")), "seq": _int(priv, "draw_seq")}


func peek_cards() -> Array:
	return priv["peek"].filter(BombCatCard.is_valid) if priv.get("peek") is Array else []


func peek_seq() -> int:
	return _int(priv, "peek_seq")


func transfer() -> Dictionary:
	return priv["transfer"] if priv.get("transfer") is Dictionary else {}


func reinsert_max() -> int:
	# 塞回炸弹:可选位置 0..deck_count;不是自己塞回时 -1
	var info: Variant = priv.get("reinsert")
	if not info is Dictionary or not info.get("deck_count") is int:
		return -1
	return maxi(info["deck_count"], 0)


func give_to() -> Variant:
	# 被讨要:要给谁;不用给时 null
	var info: Variant = priv.get("give")
	if info is Dictionary and info.get("to") is int:
		return info["to"]
	return null


# —— 出手规则 ——

func my_turn_in_view() -> bool:
	# 视图说现在是自己的自由行动(演出与回执另由牌桌判断)
	return am_alive() and pub_current() == my_pid and pub_step() == STEP_TURN


func can_nope() -> bool:
	# 不行! 按钮亮起:视图在反应窗口里、自己活着、手里有不行!
	return pub_step() == STEP_WINDOW and am_alive() and private_hand().has(BombCatCard.NOPE)


func selection_kind(indices: Array) -> String:
	# 选中的这几张(私有手牌下标)能组成什么:单张功能牌的 id、pair、triple;不合法 ""
	var hand := private_hand()
	var cards := []
	var seen := {}
	for i in indices:
		if not i is int or i < 0 or i >= hand.size() or seen.has(i):
			return ""
		seen[i] = true
		cards.append(hand[i])
	if cards.is_empty():
		return ""
	return BombCatState.combo_kind(cards)


static func needs_target(kind: String) -> bool:
	return TARGET_KINDS.has(kind)


static func needs_named(kind: String) -> bool:
	return kind == BombCatState.KIND_TRIPLE


func target_candidates() -> Array:
	# 讨要 / 零食组合能点的人:还在场、不是自己、手里有牌(按座位顺序,用视图的张数)
	var out := []
	for row in _players():
		var pid: Variant = row.get("pid")
		if pid is int and pid != my_pid and row.get("alive") is bool and row["alive"] and _int(row, "hand_count") > 0:
			out.append(pid)
	return out


func is_valid_target(pid: Variant) -> bool:
	return target_candidates().has(pid)


static func nameable_cards() -> Array:
	# 三张零食点名:除炸弹外的所有牌
	return BombCatCard.ALL.filter(func(id: String) -> bool: return BombCatCard.can_be_named(id))


func can_select_more(selected: Array, index: int) -> bool:
	# 多选只给零食组合:已选的都是同一种零食、加上这张还是同一种、不超过三张;单张功能牌只能单选
	var hand := private_hand()
	if index < 0 or index >= hand.size():
		return false
	if selected.is_empty():
		return true
	if selected.size() >= BombCatState.MAX_COMBO:
		return false
	var id: String = hand[index]
	if not BombCatCard.is_snack(id):
		return false
	for i in selected:
		if not i is int or i < 0 or i >= hand.size() or hand[i] != id:
			return false
	return true


func selection_hint(indices: Array) -> String:
	# 手牌条上方的提示:选中的牌能不能出、出了要干嘛
	if indices.is_empty():
		return ""
	var kind := selection_kind(indices)
	var hand := private_hand()
	if kind == "":
		var first: Variant = hand[indices[0]] if indices[0] is int and indices[0] < hand.size() else ""
		if indices.size() == 1 and BombCatCard.is_snack(first):
			return "零食要两张一样的才能出"
		if indices.size() == 1 and first == BombCatCard.NOPE:
			return "「不行!」在别人出牌后的反应窗口里打"
		if indices.size() == 1 and (first == BombCatCard.DEFUSE or first == BombCatCard.BOMB):
			return "拆弹会在摸到炸弹时自动用掉"
		return "这几张不能一起出"
	match kind:
		BombCatState.KIND_PAIR:
			return "两张一样的零食:出牌后选一个人,随机抽他一张"
		BombCatState.KIND_TRIPLE:
			return "三张一样的零食:出牌后选一个人、点名一种牌"
	return BombCatCard.description(kind)


# —— 结算 ——

func ranking_rows() -> Array:
	# [{"pid", "name", "place", "fate"}]:fate ∈ winner / exploded / left。优先用视图的 ranking(只在 over 时有)
	var rows := []
	var source: Array = pub["ranking"] if pub.get("ranking") is Array and not pub["ranking"].is_empty() else []
	if source.is_empty():
		var order: Array = [winner] if winner is int else []
		for i in range(out_order.size() - 1, -1, -1):
			if out_order[i] != winner:
				order.append(out_order[i])
		for i in order.size():
			source.append({"pid": order[i], "name": name_of(order[i]), "place": i + 1})
	for row in source:
		if not row is Dictionary or not row.get("pid") is int:
			continue
		var pid: int = row["pid"]
		var fate := "winner" if _int(row, "place") == 1 else ("exploded" if exploded.has(pid) else "left")
		rows.append({"pid": pid, "name": str(row.get("name", name_of(pid))), "place": _int(row, "place"), "fate": fate})
	return rows


# —— 工具 ——

func _players() -> Array:
	return pub["players"].filter(func(r): return r is Dictionary) if pub.get("players") is Array else []


static func _int(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key, 0)
	if v is int:
		return v
	if v is float and is_finite(v):
		return int(v)
	return 0
