class_name Pacing
# 演出时长估算(秒)。房主把它加到回合计时上,保证玩家看完动画后仍有完整思考时间。
# 牌桌导演的各段演出时长必须不超过这里的预算。


const PLAYED := 1.2
const REVEAL_BASE := 2.6
const REVEAL_PER_CARD := 0.75
const GUNSHOT := 5.5
const ELIMINATED := 1.2
const ROUND_STARTED := 3.2


static func estimate(events: Array) -> float:
	var total := 0.0
	for ev in events:
		match ev.get("type", ""):
			"played":
				total += PLAYED
			"reveal":
				total += REVEAL_BASE + REVEAL_PER_CARD * ev.get("cards", []).size()
			"gunshot":
				total += GUNSHOT
			"eliminated":
				total += ELIMINATED
			"round_started":
				total += ROUND_STARTED
	return total
