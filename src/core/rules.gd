class_name Rules
# 出牌合法性与质疑诚实判定。


const MIN_PLAY := 1
const MAX_PLAY := 3


static func is_play_valid(hand_size: int, indices: Array) -> bool:
	if indices.size() < MIN_PLAY or indices.size() > MAX_PLAY:
		return false
	var seen := {}
	for i in indices:
		if typeof(i) != TYPE_INT or i < 0 or i >= hand_size:
			return false
		if seen.has(i):
			return false
		seen[i] = true
	return true


static func is_honest(cards: Array, target: int) -> bool:
	for card in cards:
		if not Card.matches(card, target):
			return false
	return true
