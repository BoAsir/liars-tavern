class_name PokerPacing
# 德州演出预算(秒)。房主把它加到回合计时与一手之间的间隔上,保证玩家看完动画后仍有完整思考时间。
# PokerDirector 每段演出的实际时长必须不超过这里的预算(测试读取导演的节奏常量来检查)。


const INTRO := Pacing.INTRO          # 开场运镜:客户端进入牌桌先播它
const HAND_STARTED := 1.4            # 收上一手的牌与筹码、按新座位表重排、移动庄家按钮
const BLIND := 0.5                   # 每个盲注
const HOLE_BASE := 0.45              # 发手牌:基础 + 每张
const HOLE_PER_CARD := 0.07
const ACTION := 0.7                  # 一次行动(弃牌/过牌/跟注/下注/加注)
const ACTION_ALLIN := 1.2            # 全下
const BETS_COLLECTED := 0.7          # 一轮结束把下注收进底池
const STREET_BASE := 0.5             # 发公共牌:基础 + 每张
const STREET_PER_CARD := 0.4
const REVEAL_BASE := 0.4             # 亮牌:基础 + 每人
const REVEAL_PER_HAND := 0.5
const POT_WON := 2.0                 # 每个底池的分配
const HAND_OVER := 0.6
const REBUY := 0.6
const PLAYER_LEFT := 0.8
const PLAYER_JOINED := 0.2
const SESSION_OVER := 3.0            # 结算面板之前的谢幕
const HAND_GAP := 1.5                # 一手之间的停顿:房主排期用,不对应事件
# 有人输光的那一手之后的停顿(规格 §2.6):留时间给他选再领/观战;输光者都选完就恢复 HAND_GAP。
# away / sit_in / spectate 事件不占演出时间
const BUST_DECISION := 6.0

# 这些事件会让客户端在演出结束时把回合交给某人(重新起算回合时间)
const TURN_EVENTS := ["turn"]


static func estimate(events: Array) -> float:
	var total := 0.0
	for ev in events:
		match ev.get("type", ""):
			"hand_started":
				total += HAND_STARTED
			"blind":
				total += BLIND
			"hole_cards":
				total += HOLE_BASE + HOLE_PER_CARD * PokerRules.HOLE_CARDS * ev.get("pids", []).size()
			"action":
				total += ACTION_ALLIN if ev.get("all_in", false) else ACTION
			"bets_collected":
				total += BETS_COLLECTED
			"street":
				total += STREET_BASE + STREET_PER_CARD * ev.get("cards", []).size()
			"reveal":
				total += REVEAL_BASE + REVEAL_PER_HAND * ev.get("hands", []).size()
			"pot_won":
				total += POT_WON
			"hand_over":
				total += HAND_OVER
			"rebuy":
				total += REBUY
			"player_left":
				total += PLAYER_LEFT
			"player_joined":
				total += PLAYER_JOINED
			"session_over":
				total += SESSION_OVER
	return total


static func starts_turn(events: Array) -> bool:
	for ev in events:
		if TURN_EVENTS.has(ev.get("type", "")):
			return true
	return false


static func turn_timer_after(events: Array, pending: float, time_left: float) -> float:
	# 同 Pacing.turn_timer_after:交出回合的批次在演完后给满回合时间;
	# 否则(如旁人离开、再领)保留剩余时间,只补上本批演出
	if starts_turn(events) or time_left <= 0.0:
		return pending + Protocol.TURN_TIMEOUT
	return time_left + estimate(events)
