class_name HandEvaluator
# 德州牌型评估(规格 §2.2):从 5–7 张里取最好的 5 张。
# 按该玩法的牌型名次从大到小逐个找,第一个凑得出的就是最好的牌型(短牌只是同花与葫芦换了位置);
# 每种牌型的查找都直接取该牌型里最大的组合:成组的取最大点数,踢脚取剩下最大的牌。
# score = 名次 << 20 | 5 个 4 位比较点数,同一玩法里直接比大小,相等即平局。


const MIN_CARDS := 5
const MAX_CARDS := 7
const HAND_SIZE := 5
const RANK_BITS := 4                              # 点数 1–14 放得进 4 位(A 当最小牌时记 1)
const STRENGTH_SHIFT := RANK_BITS * HAND_SIZE
const SEPARATOR := " · "


static func evaluate(cards: Array, short_deck: bool) -> Dictionary:
	# 5–7 张 → {"category", "score", "cards": 最好的 5 张(展示顺序), "name", "detail"};张数不对返回 {}
	if cards.size() < MIN_CARDS or cards.size() > MAX_CARDS:
		return {}
	var info := _analyze(cards)
	var order := PokerRules.category_order(short_deck)
	for i in range(order.size() - 1, -1, -1):
		var category: int = order[i]
		var five := _find(category, info, short_deck)
		if not five.is_empty():
			return _result(category, five, short_deck)
	return {}


static func compare(a: Dictionary, b: Dictionary) -> int:
	# 1:a 大;0:一样大(平分);-1:b 大
	return signi(a["score"] - b["score"])


static func _analyze(cards: Array) -> Dictionary:
	# 点数降序(同点数按花色编号升序,只为展示稳定),再按点数、花色分组;分组都保持这个顺序
	var sorted := cards.duplicate()
	sorted.sort_custom(_higher_first)
	var by_rank := {}
	var by_suit := {}
	for card in sorted:
		var r := PokerCard.rank(card)
		var s := PokerCard.suit(card)
		if not by_rank.has(r):
			by_rank[r] = []
		if not by_suit.has(s):
			by_suit[s] = []
		by_rank[r].append(card)
		by_suit[s].append(card)
	return {"sorted": sorted, "by_rank": by_rank, "by_suit": by_suit}


static func _higher_first(a: int, b: int) -> bool:
	var ra := PokerCard.rank(a)
	var rb := PokerCard.rank(b)
	return ra > rb or (ra == rb and PokerCard.suit(a) < PokerCard.suit(b))


static func _find(category: int, info: Dictionary, short_deck: bool) -> Array:
	match category:
		PokerRules.Category.STRAIGHT_FLUSH:
			return _straight_flush(info, short_deck)
		PokerRules.Category.FOUR_OF_A_KIND:
			return _sets(info, [4])
		PokerRules.Category.FULL_HOUSE:
			return _sets(info, [3, 2])
		PokerRules.Category.FLUSH:
			return _flush(info)
		PokerRules.Category.STRAIGHT:
			return _straight(info["sorted"], short_deck)
		PokerRules.Category.THREE_OF_A_KIND:
			return _sets(info, [3])
		PokerRules.Category.TWO_PAIR:
			return _sets(info, [2, 2])
		PokerRules.Category.ONE_PAIR:
			return _sets(info, [2])
	return info["sorted"].slice(0, HAND_SIZE)


static func _sets(info: Dictionary, sizes: Array) -> Array:
	# 依次取张数够的最大点数凑成组(葫芦的「对子」可以拆自另一个三条),再用剩下最大的牌补踢脚
	var by_rank: Dictionary = info["by_rank"]
	var used := {}
	var five := []
	for size in sizes:
		var picked := -1
		for r in by_rank:
			if not used.has(r) and by_rank[r].size() >= size:
				picked = r
				break
		if picked < 0:
			return []
		used[picked] = true
		five.append_array(by_rank[picked].slice(0, size))
	for card in info["sorted"]:
		if five.size() == HAND_SIZE:
			break
		if not five.has(card):
			five.append(card)
	return five


static func _flush(info: Dictionary) -> Array:
	# 7 张里最多只有一种花色够 5 张
	for s in info["by_suit"]:
		var suited: Array = info["by_suit"][s]
		if suited.size() >= HAND_SIZE:
			return suited.slice(0, HAND_SIZE)
	return []


static func _straight_flush(info: Dictionary, short_deck: bool) -> Array:
	for s in info["by_suit"]:
		var suited: Array = info["by_suit"][s]
		if suited.size() >= HAND_SIZE:
			return _straight(suited, short_deck)
	return []


static func _straight(cards_desc: Array, short_deck: bool) -> Array:
	# A 可以当最小牌接顺子:长牌 A-2-3-4-5(按 5 高),短牌 A-6-7-8-9(按 9 高)。展示顺序从大到小,A 在最后
	var by_rank := {}
	for card in cards_desc:
		if not by_rank.has(PokerCard.rank(card)):
			by_rank[PokerCard.rank(card)] = card
	var low_ace := _low_ace_rank(short_deck)
	if by_rank.has(PokerCard.ACE):
		by_rank[low_ace] = by_rank[PokerCard.ACE]
	for high in range(PokerCard.ACE, low_ace + HAND_SIZE - 2, -1):
		var run := []
		for r in range(high, high - HAND_SIZE, -1):
			if not by_rank.has(r):
				break
			run.append(by_rank[r])
		if run.size() == HAND_SIZE:
			return run
	return []


static func _low_ace_rank(short_deck: bool) -> int:
	return PokerRules.min_rank(short_deck) - 1


static func _result(category: int, five: Array, short_deck: bool) -> Dictionary:
	var ranks := _compare_ranks(category, five)
	var score := PokerRules.strength(category, short_deck) << STRENGTH_SHIFT
	for i in HAND_SIZE:
		score |= int(ranks[i]) << (RANK_BITS * (HAND_SIZE - 1 - i))
	return {
		"category": category,
		"score": score,
		"cards": five,
		"name": _name(category, five),
		"detail": _detail(category, five),
	}


static func _compare_ranks(category: int, five: Array) -> Array:
	# 顺子只看最高张;A 当最小牌排在展示的最后,按「最高张往下数」记比较点数(A-2-3-4-5 记 5 4 3 2 1)
	if category == PokerRules.Category.STRAIGHT or category == PokerRules.Category.STRAIGHT_FLUSH:
		var high := PokerCard.rank(five[0])
		return range(high, high - HAND_SIZE, -1)
	return five.map(func(c): return PokerCard.rank(c))


static func _is_royal(category: int, five: Array) -> bool:
	return category == PokerRules.Category.STRAIGHT_FLUSH and PokerCard.rank(five[0]) == PokerCard.ACE


static func _name(category: int, five: Array) -> String:
	if _is_royal(category, five):
		return PokerRules.ROYAL_FLUSH_NAME
	return PokerRules.CATEGORY_NAMES[category]


static func _detail(category: int, five: Array) -> String:
	# 只写牌型名与点数(界面字体里没有花色符号,规格 §6.1)
	var name := _name(category, five)
	var top := _label(five[0])
	match category:
		PokerRules.Category.TWO_PAIR:
			return name + SEPARATOR + top + " 和 " + _label(five[2])
		PokerRules.Category.STRAIGHT:
			return name + SEPARATOR + "到 " + top
		PokerRules.Category.FLUSH:
			return name + SEPARATOR + top + " 高"
		PokerRules.Category.FULL_HOUSE:
			return name + SEPARATOR + top + " 带 " + _label(five[3])
		PokerRules.Category.STRAIGHT_FLUSH:
			return name if _is_royal(category, five) else name + SEPARATOR + "到 " + top
	return name + SEPARATOR + top


static func _label(card: int) -> String:
	return PokerCard.rank_label(PokerCard.rank(card))
