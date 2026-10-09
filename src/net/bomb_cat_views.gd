class_name BombCatViews
# 炸弹猫视图构建:决定每个客户端能看到什么。只用 BombCatState 的只读访问。
# 公共视图所有人一样,不含手牌内容、牌堆顺序、偷看结果与塞回位置(带牌 id 的只有 discard_top、
# window.cards / window.named,都是公开打出的牌);私有视图只有自己的那份。字段说明见设计稿「实施记录(阶段一)」。


static func public_view(s: BombCatState, names: Dictionary, turn_time_left := 0.0, paused_turn_left := 0.0) -> Dictionary:
	# turn_time_left:房主计时器剩余秒数(当前步骤的:回合 / 窗口 / 塞回 / 给牌;含客户端要先播完的演出);
	# paused_turn_left:窗口或给牌期间暂停保存的回合剩余,步骤回到 turn 时恢复;其他时候为 0
	var over := s.step == BombCatState.Step.OVER
	return {
		"mode": GameMode.BOMB_CAT,
		"step": s.step_name(),
		"current_pid": s.current_pid,
		"turns": s.turns_left,
		"deck_count": s.deck.size(),
		"discard_count": s.discard.size(),
		"discard_top": s.discard_top,
		"bombs_left": s.bombs_left(),
		"bombs_total": s.bombs_total,
		"window": _window(s),
		"give": s.give_request.duplicate(),
		"reinsert": {"pid": s.current_pid} if s.step == BombCatState.Step.REINSERT else {},
		"players": players(s, names),
		"out_order": s.out_order.duplicate(),
		"winner": s.winner_pid,
		"ranking": ranking(s, names) if over else [],
		"turn_time_left": 0.0 if over else maxf(turn_time_left, 0.0),
		"paused_turn_left": maxf(paused_turn_left, 0.0) if _paused(s) else 0.0,
	}


static func private_view(s: BombCatState, pid: int) -> Dictionary:
	var drawn := s.last_drawn_of(pid)
	var peek := s.peek_of(pid)
	return {
		"hand": s.hand_of(pid),
		"alive": s.is_alive(pid),
		"last_drawn": drawn.get("card", ""),
		"draw_seq": drawn.get("seq", 0),
		"peek": peek.get("cards", []),
		"peek_seq": peek.get("seq", 0),
		"reinsert": s.reinsert_info(pid),
		"give": s.give_info(pid),
		"transfer": s.transfer_of(pid),
	}


static func players(s: BombCatState, names: Dictionary) -> Array:
	# 按座位顺序
	var rows := []
	for pid in s.seat_order:
		rows.append({
			"pid": pid,
			"name": names.get(pid, str(pid)),
			"alive": s.is_alive(pid),
			"hand_count": s.hands[pid].size(),
		})
	return rows


static func ranking(s: BombCatState, names: Dictionary) -> Array:
	# 结算名次:第 1 名是胜者,其后按出局顺序倒排
	var rows := []
	var order := [s.winner_pid]
	for i in range(s.out_order.size() - 1, -1, -1):
		order.append(s.out_order[i])
	for i in order.size():
		rows.append({"pid": order[i], "name": names.get(order[i], str(order[i])), "place": i + 1})
	return rows


static func _window(s: BombCatState) -> Dictionary:
	if s.window.is_empty():
		return {}
	var w := s.window
	return {"pid": w["pid"], "cards": w["cards"].duplicate(), "kind": w["kind"], "target": w["target"],
		"named": w["named"], "nopes": w["nopes"]}


static func _paused(s: BombCatState) -> bool:
	return s.step == BombCatState.Step.WINDOW or s.step == BombCatState.Step.GIVE
