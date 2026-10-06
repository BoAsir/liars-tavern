class_name Views
# 视图构建:决定每个客户端能看到什么。手牌牌面与弹膛位置永不进入公共视图。


static func public_state(gs: GameState, names: Dictionary) -> Dictionary:
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
	}


static func private_state(gs: GameState, pid) -> Dictionary:
	# 小局号让客户端判断手牌是否已属于新小局(发牌动画要等新手牌到达)
	return {"hand": gs.hands.get(pid, []).duplicate(), "round": gs.round_number}
