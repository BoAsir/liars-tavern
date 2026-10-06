class_name Views
# 视图构建:决定每个客户端能看到什么。手牌牌面与弹膛位置永不进入公共视图。


static func public_state(gs: GameState, names: Dictionary, turn_time_left := 0.0) -> Dictionary:
	# turn_time_left:发送时房主回合计时器的剩余秒数(含客户端要先播完的演出),客户端据此画倒计时
	var players := []
	for pid in gs.seat_order:
		players.append({
			"pid": pid,
			"name": names.get(pid, str(pid)),
			"alive": gs.alive[pid],
			"hand_count": gs.hands.get(pid, []).size(),
			"shots_fired": gs.revolvers[pid].shots_fired(),
		})
	var last_play := {}
	if not gs.last_play.is_empty():
		last_play = {"pid": gs.last_play["pid"], "count": gs.last_play["count"]}
	return {
		"phase": gs.phase,
		"round": gs.round_number,
		"target": gs.target_card,
		"current_pid": gs.current_pid,
		"last_play": last_play,
		"players": players,
		"winner": gs.winner_pid,
		"turn_time_left": maxf(turn_time_left, 0.0) if gs.phase == GameState.Phase.PLAYING else 0.0,
	}


static func private_state(gs: GameState, pid) -> Dictionary:
	# 小局号让客户端判断手牌是否已属于新小局(发牌动画要等新手牌到达)
	return {"hand": gs.hands.get(pid, []).duplicate(), "round": gs.round_number}
