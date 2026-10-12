class_name PokerBotBrain
# 德州机器人的内置策略(没接 AI、或 AI 没按时回答时用)。只看玩家能看到的东西:公共视图 + 自己的私有视图,不偷看别人的牌。
# 胜率用蒙特卡洛估(对手手牌与没发的公共牌随机补齐),再按风格比较胜率与底池赔率:
# 胜率够高就下注 / 加注,够赔率就跟,否则过牌或弃牌;各风格偶尔诈唬。随机数从外面给,决策可以单测。


const SIMULATIONS := 100          # 每次决策模拟的局数:7 张评估约 26 µs,3 个对手约 10 ms(房主这一帧),胜率误差约 ±5%
const MAX_SIM_OPPONENTS := 3      # 对手再多也只模拟这么多个:多出来的几乎不改变结论,却要多花时间
const BIG_BET_FRACTION := 1.0     # 按底池比例下注的上下限
const SMALL_BET_FRACTION := 0.5
const PREFLOP_OPEN := 2.5         # 翻牌前加注到「当前最高注 × (这个 + 进攻性)」
const RAISE_MARGIN := 0.08        # 面对下注时,胜率比下注门槛再高这么多才反加
const BLUFF_RAISE_SHARE := 0.5    # 面对下注时的诈唬反加概率 = 风格诈唬率 × 这个
const STRONG_BASE := 0.42         # 下注门槛 = 平均胜率 + (1 − 平均胜率) × (这个 − 进攻性 × STRONG_AGGRESSION)
const STRONG_AGGRESSION := 0.12
const IN_HAND := [PokerRules.STATUS_ACTIVE, PokerRules.STATUS_ALLIN]

# 风格:aggression 越高越爱下注、下得越大;looseness 让跟注时少算一点赔率;bluff 是没牌时下注的概率。
# persona 是给 AI 的人设(接了 AI 时机器人照它的性格打)
const STYLES := [
	{"id": "steady", "label": "稳健", "aggression": 0.3, "looseness": 0.0, "bluff": 0.04,
		"persona": "稳健派:只玩好牌,很少诈唬,拿到大牌才会重注。"},
	{"id": "wild", "label": "凶狠", "aggression": 0.8, "looseness": 0.06, "bluff": 0.14,
		"persona": "凶狠派:喜欢主动下注和加注施压,敢于诈唬,但不会无脑全下。"},
	{"id": "sly", "label": "狡猾", "aggression": 0.55, "looseness": 0.03, "bluff": 0.2,
		"persona": "狡猾派:擅长读局面,会慢打大牌、也会在合适的牌面诈唬。"},
	{"id": "loose", "label": "爱跟", "aggression": 0.15, "looseness": 0.12, "bluff": 0.03,
		"persona": "爱跟派:好奇心重,喜欢跟注看牌,很少主动加注。"},
]


static func style(index: int) -> Dictionary:
	return STYLES[posmod(index, STYLES.size())]


# —— 局面 ——

static func situation(pub: Dictionary, priv: Dictionary, me: int) -> Dictionary:
	# 从公共视图与自己的私有视图提炼决策要用的东西;不轮到自己时 legal 为 {}
	var actions: Dictionary = pub.get("actions", {})
	var legal: Dictionary = actions.duplicate() if actions.get("pid") == me else {}
	legal.erase("pid")
	var pot := 0
	for p in pub.get("pots", []):
		pot += int(p.get("amount", 0))
	var opponents := 0
	var mine := {}
	for row in pub.get("players", []):
		pot += int(row.get("bet", 0))
		if row.get("pid") == me:
			mine = row
		elif IN_HAND.has(row.get("status")):
			opponents += 1
	return {
		"me": me,
		"hole": priv.get("hole", []),
		"board": pub.get("board", []),
		"short_deck": GameMode.is_short_deck(str(pub.get("mode", ""))),
		"street": pub.get("street", PokerRules.PREFLOP),
		"legal": legal,
		"pot": pot,
		"current_bet": int(pub.get("current_bet", 0)),
		"stack": int(mine.get("stack", 0)),
		"opponents": opponents,
	}


# —— 决策 ——

static func decide(sit: Dictionary, bot_style: Dictionary, rng: RandomNumberGenerator,
		sims := SIMULATIONS) -> Dictionary:
	# → {"action", "amount"};不轮到自己(legal 为空)时返回 {}
	var legal: Dictionary = sit["legal"]
	if legal.is_empty():
		return {}
	var opponents := maxi(int(sit["opponents"]), 1)
	var win := equity(sit["hole"], sit["board"], mini(opponents, MAX_SIM_OPPONENTS), sit["short_deck"], rng, sims)
	var aggression: float = bot_style["aggression"]
	var fair := 1.0 / (opponents + 1)
	var strong := fair + (1.0 - fair) * (STRONG_BASE - aggression * STRONG_AGGRESSION)
	var size := _size_for(win, strong, aggression)
	if legal.get("can_check", false):
		if win >= strong or rng.randf() < bot_style["bluff"]:
			return bet(sit, size)
		return pick(PokerRules.CHECK)
	var to_call: int = legal.get("to_call", 0)
	var odds := to_call / float(sit["pot"] + to_call)
	if win >= strong + RAISE_MARGIN:
		return bet(sit, size)
	if win + bot_style["looseness"] >= odds:
		return pick(PokerRules.CALL)
	if sit["street"] != PokerRules.PREFLOP and rng.randf() < bot_style["bluff"] * BLUFF_RAISE_SHARE:
		return bet(sit, SMALL_BET_FRACTION)
	return pick(PokerRules.FOLD)


static func _size_for(win: float, strong: float, aggression: float) -> float:
	# 胜率越超出门槛下得越大:半池到满池,进攻性再往上推一点
	var over := clampf((win - strong) / maxf(1.0 - strong, 0.01), 0.0, 1.0)
	return clampf(lerpf(SMALL_BET_FRACTION, BIG_BET_FRACTION, over) + aggression * 0.2,
		SMALL_BET_FRACTION, BIG_BET_FRACTION)


static func bet(sit: Dictionary, fraction: float) -> Dictionary:
	# 下注 / 加注到:翻牌前按最高注的倍数,翻牌后按底池比例(加注到 = 最高注 + 比例 × (底池 + 跟注额));
	# 取筹码单位的整数倍,夹在最小加注与全下之间,到顶就是全下;不能加注时退回跟注或过牌
	# (筹码不够跟注时「跟注」就是跟到全下)
	var legal: Dictionary = sit["legal"]
	if not legal.get("can_raise", false):
		return pick(PokerRules.CHECK if legal.get("can_check", false) else PokerRules.CALL)
	var current: int = sit["current_bet"]
	var target: float
	if sit["street"] == PokerRules.PREFLOP:
		target = maxf(current, PokerRules.BIG_BLIND) * (PREFLOP_OPEN + fraction)
	else:
		target = current + fraction * (sit["pot"] + int(legal.get("to_call", 0)))
	var amount := ceili(target / PokerRules.CHIP_UNIT) * PokerRules.CHIP_UNIT
	return clamp_raise(legal, amount)


static func clamp_raise(legal: Dictionary, amount: int) -> Dictionary:
	# 加注到 amount:取整、夹到合法范围;够到全下额就是全下(AI 的回答也走这里)
	var low: int = legal.get("min_raise_to", PokerRules.BIG_BLIND)
	var high: int = legal.get("max_raise_to", low)
	amount = clampi(ceili(amount / float(PokerRules.CHIP_UNIT)) * PokerRules.CHIP_UNIT, low, high)
	if amount >= high:
		return pick(PokerRules.ALLIN)
	return pick(PokerRules.RAISE, amount)


static func pick(action: String, amount := 0) -> Dictionary:
	return {"action": action, "amount": amount}


static func fallback(legal: Dictionary) -> Dictionary:
	# 兜底(AI 答非所问又来不及算的时候):能过牌就过牌,否则弃牌,和回合超时代打一样
	return pick(PokerRules.CHECK if legal.get("can_check", false) else PokerRules.FOLD)


# —— 胜率 ——

static func equity(hole: Array, board: Array, opponents: int, short_deck: bool, rng: RandomNumberGenerator,
		sims := SIMULATIONS) -> float:
	# 对 opponents 个随机手牌的胜率(平分按人数折算);手牌不全时为 0
	if hole.size() != PokerRules.HOLE_CARDS or sims <= 0:
		return 0.0
	var deck := remaining_deck(hole + board, short_deck)
	var missing := PokerRules.BOARD_CARDS - board.size()
	var need := missing + PokerRules.HOLE_CARDS * opponents
	if need > deck.size():
		return 0.0
	var total := 0.0
	for i in sims:
		_partial_shuffle(deck, need, rng)
		var full_board: Array = board + deck.slice(0, missing)
		var mine := HandEvaluator.evaluate(hole + full_board, short_deck)
		var ties := 0
		var lost := false
		for o in opponents:
			var at := missing + o * PokerRules.HOLE_CARDS
			var theirs := HandEvaluator.evaluate(deck.slice(at, at + PokerRules.HOLE_CARDS) + full_board, short_deck)
			var cmp := HandEvaluator.compare(mine, theirs)
			if cmp < 0:
				lost = true
				break
			if cmp == 0:
				ties += 1
		if not lost:
			total += 1.0 / (ties + 1)
	return total / sims


static func remaining_deck(known: Array, short_deck: bool) -> Array:
	var deck := []
	for r in range(PokerRules.min_rank(short_deck), PokerCard.RANK_MAX + 1):
		for s in PokerCard.SUITS:
			var card := PokerCard.make(r, s)
			if not known.has(card):
				deck.append(card)
	return deck


static func _partial_shuffle(deck: Array, count: int, rng: RandomNumberGenerator) -> void:
	# 只洗前 count 张(Fisher–Yates 的前半段):每局要的牌都从剩下的牌里等概率抽出
	for i in count:
		var j := rng.randi_range(i, deck.size() - 1)
		var tmp: Variant = deck[i]
		deck[i] = deck[j]
		deck[j] = tmp
