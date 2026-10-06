class_name Pacing
# 演出时长估算(秒)。房主把它加到回合计时上,保证玩家看完动画后仍有完整思考时间。
# 牌桌导演的各段演出时长必须不超过这里的预算。


const PLAYED := 1.2
const REVEAL_BASE := 2.6
const REVEAL_PER_CARD := 0.75
const GUNSHOT := 5.5
const ELIMINATED := 1.2
# 最坏情况:强制验证为真话(无开枪段)后先回座 0.45 + 收牌 0.52 + 翻目标牌 1.22 + 满员发牌 1.47 ≈ 3.66,
# 再留几帧余量(每个 await 可能晚一帧)
const ROUND_STARTED := 3.8
# 开局运镜(TableDirector.intro):客户端进入牌桌先播它,第一批事件排在它后面
const INTRO := 1.8

# 这些事件会让客户端在演出结束时把回合交给某人(重新起算回合时间)
const TURN_EVENTS := ["turn", "round_started"]


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


# —— 房主回合计时(纯函数,网络管理器调用)——

static func starts_turn(events: Array) -> bool:
	for ev in events:
		if TURN_EVENTS.has(ev.get("type", "")):
			return true
	return false


static func pending_after(anim_left: float, events: Array) -> float:
	# 客户端按顺序排队演出:新一批要等前面还没播完的(按预算估)演完才开始
	return maxf(anim_left, 0.0) + estimate(events)


static func turn_timer_after(events: Array, pending: float, time_left: float) -> float:
	# pending = 含本批在内客户端还要演多久;time_left = 计时器当前剩余(没在跑时为 0)。
	# 交出回合的批次:演完后重新给满回合时间;否则(如非当前玩家断线)保留剩余时间,只补上本批演出
	if starts_turn(events) or time_left <= 0.0:
		return pending + Protocol.TURN_TIMEOUT
	return time_left + estimate(events)
