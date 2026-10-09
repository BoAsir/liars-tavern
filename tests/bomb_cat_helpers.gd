extends RefCounted
# 炸弹猫测试共用:摆局面、找事件、检查公共事件 / 公共视图不漏隐藏信息。


const C := preload("res://src/core/bomb_cat/bomb_cat_card.gd")

# 每种公共事件允许出现的键(多出任何键都算可疑:可能夹带了隐藏信息)
const EVENT_KEYS := {
	"round_started": ["type", "seats", "hands", "deck_count", "bombs", "current", "turns"],
	"played": ["type", "pid", "cards", "kind", "target", "named", "window"],
	"noped": ["type", "pid", "depth", "window"],
	"window_resolved": ["type", "pid", "kind", "effective", "nopes", "aborted"],
	"effect": ["type", "kind", "pid", "to", "turns", "count", "from", "got", "named"],
	"give_requested": ["type", "pid", "to", "timeout"],
	"drew": ["type", "pid", "deck_count", "bomb"],
	"bomb_drawn": ["type", "pid"],
	"defused": ["type", "pid", "deck_count", "timeout"],
	"reinserted": ["type", "pid", "deck_count"],
	"exploded": ["type", "pid", "discarded"],
	"player_left": ["type", "pid", "discarded"],
	"turn_passed": ["type", "pid", "turns"],
	"match_over": ["type", "winner", "ranking"],
}
# 只有这些键的值可以是牌 id:打出的牌(公开)、出牌种类、三张零食点名的牌
const CARD_KEYS := ["cards", "kind", "named"]
const PUBLIC_VIEW_KEYS := ["mode", "step", "current_pid", "turns", "deck_count", "discard_count", "discard_top",
	"bombs_left", "bombs_total", "window", "give", "reinsert", "players", "out_order", "winner", "ranking",
	"turn_time_left", "paused_turn_left"]
const PLAYER_ROW_KEYS := ["pid", "name", "alive", "hand_count"]


static func new_state(pids: Array, seed_value := 7) -> BombCatState:
	var s := BombCatState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	s.start(pids, rng)
	return s


static func rig(s: BombCatState, hands: Dictionary, deck: Array, current, turns := 1) -> void:
	# 换成指定的手牌与牌堆(没列出的人手牌清空),从 current 的自由行动开始;守恒总数按新局面重算
	for pid in s.seat_order:
		s.hands[pid] = hands.get(pid, []).duplicate()
	s.deck = deck.duplicate()
	s.discard = []
	s.discard_top = ""
	s.current_pid = current
	s.turns_left = turns
	s.under_attack = false
	s.window = {}
	s.give_request = {}
	s.step = BombCatState.Step.TURN
	s.total_cards = s.card_count()


static func find(events: Array, type: String) -> Dictionary:
	for ev in events:
		if ev.get("type") == type:
			return ev
	return {}


static func types(events: Array) -> Array:
	return events.map(func(ev: Dictionary) -> String: return ev["type"])


static func event_leak(ev: Dictionary) -> String:
	# 返回问题描述,没问题为 ""
	var type: Variant = ev.get("type")
	if not EVENT_KEYS.has(type):
		return "未知事件 %s" % str(type)
	for key in ev:
		if not EVENT_KEYS[type].has(key):
			return "%s 多出键 %s" % [type, key]
		if not CARD_KEYS.has(key) and _has_card_id(ev[key]):
			return "%s.%s 带了牌 id" % [type, key]
	return ""


static func view_leak(view: Dictionary) -> String:
	for key in view:
		if not PUBLIC_VIEW_KEYS.has(key):
			return "公共视图多出键 %s" % key
	for row in view["players"]:
		for key in row:
			if not PLAYER_ROW_KEYS.has(key):
				return "players[] 多出键 %s" % key
	for key in ["players", "give", "reinsert", "out_order", "ranking"]:
		if _has_card_id(view[key]):
			return "公共视图 %s 带了牌 id" % key
	return ""


static func _has_card_id(value: Variant) -> bool:
	if value is String:
		return C.is_valid(value)
	if value is Array:
		for item in value:
			if _has_card_id(item):
				return true
	if value is Dictionary:
		for key in value:
			if _has_card_id(value[key]):
				return true
	return false
