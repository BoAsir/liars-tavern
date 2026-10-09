extends GutTest
# 炸弹猫随机自对弈(设计稿 §5):几百局固定种子,随机合法意图 + 随机超时 + 偶尔断线 + 夹杂的垃圾意图,经会话驱动。
# 每一步检查不变量:牌数守恒、公共事件与公共视图不漏隐藏信息、私有视图与引擎一致、偷看结果属实、
# 自由行动时牌堆不空、计时器时长为正;每局必须在步数上限内结束,且恰好一个胜者。


const H := preload("res://tests/bomb_cat_helpers.gd")
const C := preload("res://src/core/bomb_cat/bomb_cat_card.gd")
const S := BombCatState.Step
const GAMES := 300
const MAX_STEPS := 4000

var _failures := 0   # 只把第一处失败的细节报出来,免得一处 bug 刷出成千上万条
var _seen := {}      # 事件类型(effect 记成 effect:kind)-> 出现次数:确认自对弈真的走到了每条路径


func test_random_self_play_keeps_every_invariant():
	var steps_total := 0
	for game in GAMES:
		steps_total += _play_one(game)
		if _failures > 0:
			break
	assert_eq(_failures, 0, "自对弈全部不变量成立")
	gut.p("炸弹猫自对弈:%d 局,共 %d 步;%s" % [GAMES, steps_total, str(_seen)])
	for type in H.EVENT_KEYS:
		if type != "effect":   # effect 按 kind 分开记
			assert_gt(_seen.get(type, 0), 0, "走到过 %s" % type)
	for kind in ["skip", "pass_turns", "peek", "shuffle", "beg", "steal", "request"]:
		assert_gt(_seen.get("effect:" + kind, 0), 0, "走到过 effect:%s" % kind)
	assert_gt(_seen.get("noped_twice", 0), 0, "走到过不行掉不行")


func _check(cond: bool, what: String) -> bool:
	if not cond and _failures == 0:
		fail_test(what)
	if not cond:
		_failures += 1
	return cond


func _play_one(game: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1000 + game
	var n := rng.randi_range(2, 6)
	var pids := []
	var names := {}
	for i in n:
		pids.append(100 + i * 7)
		names[100 + i * 7] = "玩家%d" % i
	var session := BombCatSession.new()
	var engine_rng := RandomNumberGenerator.new()
	engine_rng.seed = 5000 + game
	var events := session.start(pids, names, engine_rng)
	var s := session.state()
	var tag := "第 %d 局(%d 人)" % [game, n]
	_check_batch(session, events, tag, rng)
	var match_overs := 0
	var steps := 0
	while not session.is_over() and steps < MAX_STEPS and _failures == 0:
		steps += 1
		var result := _random_step(session, s, rng, tag)
		if result.is_empty() or not result["ok"]:
			continue
		_check_batch(session, result["events"], tag, rng)
		match_overs += result["events"].filter(func(ev: Dictionary) -> bool: return ev["type"] == "match_over").size()
	if _failures > 0:
		return steps
	_check(session.is_over(), "%s 在 %d 步内没有结束" % [tag, MAX_STEPS])
	_check(match_overs == 1, "%s match_over 出现 %d 次" % [tag, match_overs])
	var alive := s.alive_pids()
	_check(alive.size() == 1 and alive[0] == s.winner_pid, "%s 恰好一个活着的胜者:%s / %s" % [tag, str(alive), str(s.winner_pid)])
	var ranking: Array = session.public_view(0.0)["ranking"].map(func(row: Dictionary): return row["pid"])
	var sorted_ranking := ranking.duplicate()
	sorted_ranking.sort()
	_check(sorted_ranking == pids, "%s 名次包含每人一次:%s" % [tag, str(ranking)])
	_check(ranking[0] == s.winner_pid, "%s 第 1 名是胜者" % tag)
	return steps


func _random_step(session: BombCatSession, s: BombCatState, rng: RandomNumberGenerator, tag: String) -> Dictionary:
	var roll := rng.randf()
	if roll < 0.004:
		var alive := s.alive_pids()
		var events := session.on_disconnect(alive[rng.randi_range(0, alive.size() - 1)])
		return {"ok": true, "events": events} if not events.is_empty() else {}
	if roll < 0.05:
		_garbage(session, s, rng, tag)
		return {}
	if roll < 0.12:
		return session.on_turn_timeout()
	match s.step:
		S.TURN:
			var cur: int = s.current_pid
			_check(not s.deck.is_empty(), "%s 自由行动时牌堆空了" % tag)
			if rng.randf() < 0.55:
				var play := _random_play(s, cur, rng)
				if not play.is_empty():
					return _accepted(session, cur, play, tag)
			return _accepted(session, cur, {"kind": "draw"}, tag)
		S.WINDOW:
			var noper := _random_noper(s, rng)
			if noper != -1 and rng.randf() < 0.35:
				return _accepted(session, noper, {"kind": "nope"}, tag)
			return session.on_turn_timeout()
		S.REINSERT:
			return _accepted(session, s.current_pid, {"kind": "reinsert", "pos": rng.randi_range(0, s.deck.size())}, tag)
		S.GIVE:
			var giver: int = s.give_request["from"]
			return _accepted(session, giver, {"kind": "give", "index": rng.randi_range(0, s.hands[giver].size() - 1)}, tag)
	return {}


func _accepted(session: BombCatSession, pid: int, intent: Dictionary, tag: String) -> Dictionary:
	# 按引擎局面挑出来的都是合法意图:必须被接受
	var result := session.handle_intent(pid, intent)
	_check(result["ok"], "%s 合法意图被拒:%s %s → %s" % [tag, pid, str(intent), str(result.get("error"))])
	return result


func _random_play(s: BombCatState, pid: int, rng: RandomNumberGenerator) -> Dictionary:
	var hand: Array = s.hands[pid]
	var options := []
	var by_snack := {}
	for i in hand.size():
		if C.is_playable(hand[i]):
			options.append([i])
		elif C.is_snack(hand[i]):
			by_snack[hand[i]] = by_snack.get(hand[i], []) + [i]
	for snack in by_snack:
		var at: Array = by_snack[snack]
		if at.size() >= 2:
			options.append(at.slice(0, 2))
		if at.size() >= 3:
			options.append(at.slice(0, 3))
	if options.is_empty():
		return {}
	var cards: Array = options[rng.randi_range(0, options.size() - 1)]
	var intent := {"kind": "play", "cards": cards}
	var kind := BombCatState.combo_kind(cards.map(func(i: int): return hand[i]))
	if kind == C.BEG or kind == BombCatState.KIND_PAIR or kind == BombCatState.KIND_TRIPLE:
		var targets := s.alive_pids().filter(func(t: int) -> bool: return t != pid and not s.hands[t].is_empty())
		if targets.is_empty():
			return {}
		intent["target"] = targets[rng.randi_range(0, targets.size() - 1)]
	if kind == BombCatState.KIND_TRIPLE:
		var nameable := C.ALL.filter(func(id: String) -> bool: return C.can_be_named(id))
		intent["named"] = nameable[rng.randi_range(0, nameable.size() - 1)]
	return intent


func _random_noper(s: BombCatState, rng: RandomNumberGenerator) -> int:
	var nopers := s.alive_pids().filter(func(pid: int) -> bool: return s.hands[pid].has(C.NOPE))
	return -1 if nopers.is_empty() else nopers[rng.randi_range(0, nopers.size() - 1)]


func _garbage(session: BombCatSession, s: BombCatState, rng: RandomNumberGenerator, tag: String) -> void:
	# 夹杂的非法意图:必须被拒,且局面一点不变
	var before := [s.step, s.current_pid, s.turns_left, s.deck.duplicate(), s.hands.duplicate(true), s.window.duplicate(true)]
	var pid: int = s.seat_order[rng.randi_range(0, s.seat_order.size() - 1)]
	var junk := [
		{"kind": "play", "cards": [999]},
		{"kind": "play", "cards": ["x"]},
		{"kind": "play", "cards": [0, 0]},
		{"kind": "reinsert", "pos": -5},
		{"kind": "give", "index": 999},
		{"kind": "nope", "extra": [1, 2]} if s.step != S.WINDOW else {"kind": "teleport"},
		{"kind": "draw"} if pid != s.current_pid else {"kind": "give", "index": "0"},
		{"kind": 12},
		{},
	]
	var intent: Dictionary = junk[rng.randi_range(0, junk.size() - 1)]
	var result := session.handle_intent(pid, intent)
	_check(not result["ok"], "%s 垃圾意图被接受:%s %s" % [tag, pid, str(intent)])
	var after := [s.step, s.current_pid, s.turns_left, s.deck.duplicate(), s.hands.duplicate(true), s.window.duplicate(true)]
	_check(before == after, "%s 被拒的意图改了局面:%s" % [tag, str(intent)])


func _check_batch(session: BombCatSession, events: Array, tag: String, rng: RandomNumberGenerator) -> void:
	var s := session.state()
	_check(s.card_count() == s.total_cards, "%s 牌数不守恒:%d / %d" % [tag, s.card_count(), s.total_cards])
	for ev in events:
		var key: String = ev["type"] if ev["type"] != "effect" else "effect:" + str(ev["kind"])
		_seen[key] = _seen.get(key, 0) + 1
		if ev["type"] == "noped" and ev["depth"] >= 2:
			_seen["noped_twice"] = _seen.get("noped_twice", 0) + 1
		var leak := H.event_leak(ev)
		if not _check(leak == "", "%s 公共事件漏信息:%s %s" % [tag, leak, str(ev)]):
			return
		if ev["type"] == "effect" and ev["kind"] == C.PEEK:
			var peek := s.peek_of(ev["pid"])
			_check(peek.get("cards") == s.deck.slice(0, BombCatState.PEEK_COUNT), "%s 偷看结果不是牌堆顶" % tag)
			_check(peek["cards"].size() == ev["count"], "%s 偷看张数不符" % tag)
	var view := session.public_view(rng.randf_range(0.0, 30.0))
	_check(H.view_leak(view) == "", "%s 公共视图漏信息:%s" % [tag, H.view_leak(view)])
	for pid in session.viewers():
		var priv := session.private_view(pid)
		_check(priv["hand"] == s.hands[pid], "%s 私有视图手牌不符" % tag)
		if not s.is_alive(pid):
			_check(priv["hand"].is_empty() and not priv["alive"], "%s 出局者还有手牌" % tag)
	var bombs_in_play := s.deck.count(C.BOMB) + (1 if s.held_bomb != "" else 0)
	_check(bombs_in_play == s.bombs_left(), "%s 场上炸弹数不符" % tag)
	if not session.is_over():
		_check(bombs_in_play >= s.alive_pids().size() - 1, "%s 炸弹比存活人数 − 1 还少" % tag)
		var duration := session.turn_timer_after(events, rng.randf_range(0.0, 5.0), rng.randf_range(0.0, 30.0))
		_check(duration > 0.0 and duration <= Protocol.TURN_TIMEOUT + 60.0, "%s 计时时长不合理:%f" % [tag, duration])
		_check(s.current_pid != null and s.is_alive(s.current_pid), "%s 当前玩家不在场" % tag)
		_check(s.turns_left >= 1, "%s 当前玩家回合数 < 1" % tag)
