class_name GameState
# 骗子牌核心状态机:仅在房主端运行,不依赖节点/网络/UI。
# 动作方法返回 {"ok": bool, "error"?: String, "events"?: Array}。


enum Phase { PLAYING, MATCH_OVER }

var rng: RandomNumberGenerator
var seat_order: Array = []
var alive := {}
var hands := {}
var revolvers := {}
var target_card := -1
var phase := Phase.PLAYING
var current_pid = null
var last_play := {}
var winner_pid = null
var round_number := 0


func start_match(player_ids: Array, p_rng: RandomNumberGenerator) -> void:
	rng = p_rng
	seat_order = player_ids.duplicate()
	alive = {}
	revolvers = {}
	for pid in seat_order:
		alive[pid] = true
		revolvers[pid] = Revolver.new(rng)
	phase = Phase.PLAYING
	winner_pid = null
	round_number = 0
	_start_round(seat_order[rng.randi_range(0, seat_order.size() - 1)])


func play_cards(pid, indices: Array) -> Dictionary:
	if phase != Phase.PLAYING:
		return {"ok": false, "error": "match_over"}
	if pid != current_pid:
		return {"ok": false, "error": "not_your_turn"}
	var hand: Array = hands[pid]
	if not Rules.is_play_valid(hand.size(), indices):
		return {"ok": false, "error": "invalid_play"}
	var order := indices.duplicate()
	order.sort()
	order.reverse()
	var cards := []
	for i in order:
		cards.append(hand[i])
		hand.remove_at(i)
	last_play = {"pid": pid, "cards": cards, "count": cards.size()}
	var events := [{"type": "played", "pid": pid, "count": cards.size()}]
	if _others_all_empty(pid):
		# 强制验证:场上只剩该玩家有手牌,系统自动翻牌(challenger 为 null)
		events.append_array(_resolve_reveal(null))
	else:
		current_pid = _next_actor_after(pid)
		events.append({"type": "turn", "pid": current_pid})
	return {"ok": true, "events": events}


func challenge(pid) -> Dictionary:
	if phase != Phase.PLAYING:
		return {"ok": false, "error": "match_over"}
	if pid != current_pid:
		return {"ok": false, "error": "not_your_turn"}
	# 上一手是自己出的也不能质疑:其他人断线、手牌出完后回合会绕回出牌者
	if last_play.is_empty() or last_play["pid"] == pid:
		return {"ok": false, "error": "nothing_to_challenge"}
	return {"ok": true, "events": _resolve_reveal(pid)}


func eliminate_player(pid) -> Array:
	# 断线淘汰:任意时刻可发生,返回事件列表(可能为空)。
	if phase != Phase.PLAYING or not alive.get(pid, false):
		return []
	alive[pid] = false
	var events := [{"type": "eliminated", "pid": pid}]
	if not last_play.is_empty() and last_play["pid"] == pid:
		last_play = {}  # 断线者未被验证的出牌作废
	var alive_list := _alive_pids()
	if alive_list.size() == 1:
		return events + _finish_match(alive_list[0])
	if current_pid == pid:
		current_pid = _next_actor_after(pid)
		if current_pid == null:
			# 极端情况:其余存活者手牌都已空,直接重开小局
			_start_round(_next_alive_after(pid))
			events.append(round_started_event())
		else:
			events.append({"type": "turn", "pid": current_pid})
	return events


func round_started_event() -> Dictionary:
	return {
		"type": "round_started",
		"round": round_number,
		"target": target_card,
		"starter": current_pid,
	}


func _resolve_reveal(challenger_pid) -> Array:
	var played_pid = last_play["pid"]
	var cards: Array = last_play["cards"]
	var honest := Rules.is_honest(cards, target_card)
	var events := [{
		"type": "reveal",
		"pid": played_pid,
		"cards": cards,
		"target": target_card,
		"honest": honest,
		"challenger": challenger_pid,
	}]
	# 真话 → 质疑者开枪(强制验证时无人开枪);假话 → 出牌者开枪
	var shooter = challenger_pid if honest else played_pid
	var next_starter = played_pid
	if shooter != null:
		var revolver: Revolver = revolvers[shooter]
		var hit: bool = revolver.pull_trigger()
		events.append({
			"type": "gunshot",
			"pid": shooter,
			"hit": hit,
			"shots_fired": revolver.shots_fired(),
		})
		if hit:
			alive[shooter] = false
			events.append({"type": "eliminated", "pid": shooter})
		next_starter = shooter if alive[shooter] else _next_alive_after(shooter)
	var alive_list := _alive_pids()
	if alive_list.size() == 1:
		return events + _finish_match(alive_list[0])
	_start_round(next_starter)
	events.append(round_started_event())
	return events


func _finish_match(winner) -> Array:
	phase = Phase.MATCH_OVER
	winner_pid = winner
	current_pid = null
	return [{"type": "match_over", "winner": winner}]


func _start_round(starter_pid) -> void:
	round_number += 1
	target_card = Deck.pick_target(rng)
	hands = Deck.deal(_alive_pids(), rng)
	last_play = {}
	current_pid = starter_pid


func _alive_pids() -> Array:
	var out := []
	for pid in seat_order:
		if alive[pid]:
			out.append(pid)
	return out


func _others_all_empty(pid) -> bool:
	for other in _alive_pids():
		if other != pid and hands[other].size() > 0:
			return false
	return true


func _next_actor_after(pid):
	# 下一个「存活且有手牌」的玩家;找不到返回 null。
	var n := seat_order.size()
	var start := seat_order.find(pid)
	for step in range(1, n + 1):
		var cand = seat_order[(start + step) % n]
		if alive[cand] and hands.get(cand, []).size() > 0:
			return cand
	return null


func _next_alive_after(pid):
	var n := seat_order.size()
	var start := seat_order.find(pid)
	for step in range(1, n + 1):
		var cand = seat_order[(start + step) % n]
		if alive[cand]:
			return cand
	return null
