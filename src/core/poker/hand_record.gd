class_name HandRecord
# 一手结束后的牌局记录(hand_record 事件):公共牌、每个被发到牌的人的两张手牌(含弃牌的)、牌型与这一手的输赢。
# 只在这一手结束(退回与分池之后)才生成并发给所有人,所以不会在手牌进行中泄露谁拿着什么。


static func build(hand: int, board: Array, dealt: Array, players: Dictionary, start_stacks: Dictionary,
		short_deck: bool) -> Dictionary:
	var rows := []
	for pid in dealt:
		if not players.has(pid):
			continue
		var p: Dictionary = players[pid]
		var hole: Array = p["hole"]
		var hand_name := ""
		if board.size() >= PokerRules.FLOP_CARDS and hole.size() == PokerRules.HOLE_CARDS:
			hand_name = HandEvaluator.evaluate(hole + board, short_deck).get("detail", "")
		rows.append({
			"pid": pid, "cards": hole.duplicate(), "hand_name": hand_name,
			"folded": p["status"] == PokerRules.STATUS_FOLDED, "left": p["left"],
			"delta": p["stack"] - start_stacks.get(pid, p["stack"]),   # 这一手的输赢(含盲注)
		})
	return {"type": "hand_record", "hand": hand, "board": board.duplicate(), "players": rows}
