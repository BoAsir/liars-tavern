class_name BombCatState
# 炸弹猫规则引擎(规格 §1、§2):仅在房主端运行,不依赖节点/网络/UI。
# 每个改动局面的方法返回 {"ok": bool, "error"?: String, "events": Array};被拒时局面不变、events 为空。
# 公共事件广播给全员,**不含任何隐藏信息**(手牌内容、牌堆顺序、偷看结果、塞回位置、给出的是哪张);
# 私有信息只经 hand_of / last_drawn_of / peek_of / reinsert_info / give_info / transfer_of 给私有视图。
#
# —— 局面 ——
# 步骤 step:TURN 当前玩家自由行动(出牌或摸牌)· WINDOW 反应窗口(谁都能打「不行!」,当前玩家等着)·
#   REINSERT 当前玩家拆了弹、选炸弹塞回的位置 · GIVE 被「讨要」的人挑一张给出 · OVER 已分胜负。
# turns_left:当前玩家还要行动几个回合(含正在进行的这一回合,平时为 1)。摸牌、溜了各消耗 1 个;
#   用完轮到下一位存活者。甩锅:当前玩家剩余回合作废,下家行动 2 个回合;若当前玩家本身在「被甩」的回合里
#   (under_attack),下家行动 turns_left + 2 个回合。
# 牌堆 deck 下标 0 = 顶;塞回位置 pos ∈ 0..deck.size(),0 = 顶、deck.size() = 底。
# 弃牌堆 discard 末尾 = 最上面;出局者的手牌垫到最底下(discard_top 只记公开打出的牌)。
# 牌数守恒:deck + discard + 各手牌 + removed(炸飞移出的炸弹)+ held_bomb(塞回中拿在手上的 0/1 张)= total_cards。
#
# —— 公共事件(字段一览;cards / named 是牌 id,pid 是玩家 id)——
#   round_started  {seats: [pid], hands: [{pid, count}], deck_count, bombs, current, turns}
#                  开局:座次、每人手牌张数、牌堆张数、炸弹总数、先手与他的回合数(1)
#   played         {pid, cards: [牌 id], kind, target: pid|null, named: 牌 id|"", window: 秒}
#                  打出一张功能牌或一组零食并打开反应窗口。kind ∈ skip / pass_turns / peek / shuffle / beg / pair / triple;
#                  target 只有 beg / pair / triple 有;named 只有 triple 有
#   noped          {pid, depth, window: 秒}         有人打「不行!」:depth = 本窗口里第几张,窗口重新计时
#   window_resolved {pid, kind, effective, nopes, aborted}
#                  窗口结算:pid / kind 是原出牌;effective = 「不行!」张数为偶数;
#                  aborted = 出牌者中途断线、窗口作废(effective 为 false)
#   effect         原牌生效的公开结果,pid = 出牌者,按 kind:
#                    skip       {kind, pid}
#                    pass_turns {kind, pid, to, turns}            to = 被甩的下家,turns = 他要行动的回合数
#                    peek       {kind, pid, count}                看了几张(牌面只在出牌者的私有视图)
#                    shuffle    {kind, pid}
#                    beg        {kind, pid, from, to, got}        给牌结束(或落空):from 给 to 一张(不含是哪张)
#                    steal      {kind, pid, from, to, got}        两张零食:从 from 随机抽 1 张给 to
#                    request    {kind, pid, from, to, named, got} 三张零食点名 named,from 有就给 to(got)
#   give_requested {pid, to, timeout: 秒}           讨要生效:pid 要挑一张给 to,进入 GIVE 步骤
#   drew           {pid, deck_count, bomb}          摸了一张(不含是哪张);bomb 为真时紧跟 bomb_drawn
#   bomb_drawn     {pid}                            摸到炸弹(所有人吓一跳)
#   defused        {pid, deck_count, timeout: 秒}   自动打出拆弹,进入 REINSERT 步骤(deck_count 是可选位置的上限)
#   reinserted     {pid, deck_count}                炸弹塞回牌堆(不含位置)
#   exploded       {pid, discarded}                 没拆弹,炸飞出局:手牌 discarded 张弃掉,炸弹移出游戏
#   player_left    {pid, discarded}                 断线出局(没有爆炸)
#   turn_passed    {pid, turns}                     轮到 pid,他要行动 turns 个回合(同一人连走下一回合也发)
#   match_over     {winner, ranking: [pid]}         分出胜负;ranking 第 1 名起(= 胜者 + 出局顺序倒排)
# 所有事件都有 "type" 键。只有 played.cards 与 effect.named 会带牌 id,且都是本来就公开的牌。


enum Step { TURN, WINDOW, REINSERT, GIVE, OVER }

const STEP_NAMES := {
	Step.TURN: "turn", Step.WINDOW: "window", Step.REINSERT: "reinsert", Step.GIVE: "give", Step.OVER: "over",
}

# —— 规则常量(秒数也是规则的一部分:事件里带给客户端画倒计时)——
const REACT_WINDOW := 3.0
const REINSERT_TIMEOUT := 15.0
const GIVE_TIMEOUT := 15.0
const PEEK_COUNT := 3
const PASS_TURNS_ADD := 2
const MAX_COMBO := 3            # 一次最多打出的牌数(三张零食)

# —— 出牌种类(played.kind / window_resolved.kind)——
const KIND_PAIR := "pair"
const KIND_TRIPLE := "triple"

# —— 拒绝错误码 ——
const ERR_MATCH_OVER := "match_over"
const ERR_NOT_SEATED := "not_seated"
const ERR_OUT := "out"
const ERR_NOT_YOUR_TURN := "not_your_turn"
const ERR_BUSY := "busy"                    # 当前玩家在窗口 / 塞回 / 给牌期间想出牌或摸牌
const ERR_INVALID_PLAY := "invalid_play"    # 下标不对或不是合法的牌组合
const ERR_INVALID_TARGET := "invalid_target"
const ERR_TARGET_EMPTY := "target_empty"
const ERR_INVALID_NAMED := "invalid_named"
const ERR_NO_WINDOW := "no_window"
const ERR_NO_NOPE := "no_nope"
const ERR_NOT_WAITING := "not_waiting"      # 现在不是等你塞回 / 给牌
const ERR_INVALID_POS := "invalid_pos"
const ERR_INVALID_INDEX := "invalid_index"
const ERR_INVALID_INTENT := "invalid_intent"   # 会话层:意图字典的 kind 或字段类型不对
const ERR_INVALID_PLAYERS := "invalid_players"

const ERROR_MESSAGES := {
	ERR_MATCH_OVER: "对局已结束",
	ERR_NOT_SEATED: "你不在这一局里",
	ERR_OUT: "你已经出局了",
	ERR_NOT_YOUR_TURN: "还没轮到你",
	ERR_BUSY: "先等这一步结束",
	ERR_INVALID_PLAY: "这几张牌不能这样出",
	ERR_INVALID_TARGET: "要选一位还在场的其他玩家",
	ERR_TARGET_EMPTY: "他手里没有牌了",
	ERR_INVALID_NAMED: "要点名一种牌",
	ERR_NO_WINDOW: "现在没有可以「不行!」的牌",
	ERR_NO_NOPE: "你手里没有「不行!」",
	ERR_NOT_WAITING: "现在不用你做这个",
	ERR_INVALID_POS: "位置超出牌堆范围",
	ERR_INVALID_INDEX: "没有这张牌",
	ERR_INVALID_INTENT: "操作不合法",
	ERR_INVALID_PLAYERS: "人数不对",
}

var rng: RandomNumberGenerator
var seat_order: Array = []
var alive := {}                 # pid -> bool
var hands := {}                 # pid -> Array[牌 id]
var deck: Array = []            # 下标 0 = 顶
var discard: Array = []         # 末尾 = 最上面
var discard_top := ""           # 最近一张公开打出的牌(出牌、不行!、拆弹);没有为 ""
var removed: Array = []         # 炸飞后移出游戏的炸弹
var held_bomb := ""             # 塞回步骤里拿在手上的炸弹;没有为 ""
var step := Step.OVER
var current_pid = null
var turns_left := 0
var under_attack := false       # 当前玩家的回合是不是被甩来的
var window := {}                # {"pid", "cards", "kind", "target", "named", "nopes"};不在窗口里为 {}
var give_request := {}          # {"from": 给牌的人, "to": 讨要的人};不在给牌步骤为 {}
var winner_pid = null
var out_order: Array = []       # 出局顺序(爆炸与断线)
var bombs_total := 0
var total_cards := 0

# —— 私有信息(只进私有视图)——
var _last_drawn := {}           # pid -> {"card", "seq"}
var _peek := {}                 # pid -> {"cards", "seq"};牌堆一变(摸牌、洗牌、塞回)就作废
var _transfer := {}             # pid -> {"card", "from", "to", "seq"}:最近一次涉及他的转手(讨要、抽牌、点名)
var _seq := 0


# —— 开局 ——

func start(player_ids: Array, p_rng: RandomNumberGenerator) -> Dictionary:
	if not BombCatDeck.is_valid_count(player_ids.size()):
		return _fail(ERR_INVALID_PLAYERS)
	rng = p_rng
	seat_order = player_ids.duplicate()
	var dealt := BombCatDeck.deal(seat_order, rng)
	hands = dealt["hands"]
	deck = dealt["deck"]
	discard = []
	discard_top = ""
	removed = []
	held_bomb = ""
	alive = {}
	for pid in seat_order:
		alive[pid] = true
	out_order = []
	winner_pid = null
	window = {}
	give_request = {}
	_last_drawn = {}
	_peek = {}
	_transfer = {}
	bombs_total = BombCatDeck.bomb_count(seat_order.size())
	total_cards = BombCatDeck.total_cards(seat_order.size())
	current_pid = seat_order[rng.randi_range(0, seat_order.size() - 1)]
	turns_left = 1
	under_attack = false
	step = Step.TURN
	return _ok([round_started_event()])


func round_started_event() -> Dictionary:
	var counts := []
	for pid in seat_order:
		counts.append({"pid": pid, "count": hands[pid].size()})
	return {
		"type": "round_started",
		"seats": seat_order.duplicate(),
		"hands": counts,
		"deck_count": deck.size(),
		"bombs": bombs_total,
		"current": current_pid,
		"turns": turns_left,
	}


# —— 当前玩家的动作 ——

func play(pid, indices: Variant, target: Variant = null, named: Variant = "") -> Dictionary:
	# 打出一张功能牌(skip / pass_turns / peek / shuffle / beg)或一组 2–3 张同样的零食,打开反应窗口。
	# beg 与零食组合要 target(还在场、不是自己、手里有牌);三张零食还要 named(能点的牌 id)
	var error := _check_actor(pid)
	if error != "":
		return _fail(error)
	var hand: Array = hands[pid]
	if not _valid_indices(indices, hand.size()):
		return _fail(ERR_INVALID_PLAY)
	var cards := []
	for i in indices:
		cards.append(hand[i])
	var kind := combo_kind(cards)
	if kind == "":
		return _fail(ERR_INVALID_PLAY)
	var needs_target := kind == BombCatCard.BEG or kind == KIND_PAIR or kind == KIND_TRIPLE
	if needs_target:
		if not _is_other_alive(pid, target):
			return _fail(ERR_INVALID_TARGET)
		if hands[target].is_empty():
			return _fail(ERR_TARGET_EMPTY)
	if kind == KIND_TRIPLE and not BombCatCard.can_be_named(named):
		return _fail(ERR_INVALID_NAMED)
	var order: Array = indices.duplicate()
	order.sort()
	order.reverse()
	for i in order:
		hand.remove_at(i)
	for card in cards:
		discard.append(card)
	discard_top = cards[-1]
	window = {
		"pid": pid,
		"cards": cards,
		"kind": kind,
		"target": target if needs_target else null,
		"named": named if kind == KIND_TRIPLE else "",
		"nopes": 0,
	}
	step = Step.WINDOW
	return _ok([{
		"type": "played",
		"pid": pid,
		"cards": cards.duplicate(),
		"kind": kind,
		"target": window["target"],
		"named": window["named"],
		"window": REACT_WINDOW,
	}])


func draw(pid) -> Dictionary:
	# 从牌堆顶摸 1 张结束一个回合;摸到炸弹:有拆弹自动拆、进入塞回步骤,没有就炸飞出局
	var error := _check_actor(pid)
	if error != "":
		return _fail(error)
	if deck.is_empty():
		# 不该发生(存活 ≥ 2 时牌堆里至少还有一张炸弹);兜底:不摸牌直接结束回合,局面不会卡住
		return _ok(_end_turn())
	var card: String = deck.pop_front()
	_peek = {}
	_seq += 1
	_last_drawn[pid] = {"card": card, "seq": _seq}
	var bomb := card == BombCatCard.BOMB
	var events := [{"type": "drew", "pid": pid, "deck_count": deck.size(), "bomb": bomb}]
	if not bomb:
		hands[pid].append(card)
		return _ok(events + _end_turn())
	events.append({"type": "bomb_drawn", "pid": pid})
	var defuse_at: int = hands[pid].find(BombCatCard.DEFUSE)
	if defuse_at < 0:
		removed.append(card)
		return _ok(events + _knock_out(pid, "exploded"))
	hands[pid].remove_at(defuse_at)
	discard.append(BombCatCard.DEFUSE)
	discard_top = BombCatCard.DEFUSE
	held_bomb = card
	step = Step.REINSERT
	events.append({"type": "defused", "pid": pid, "deck_count": deck.size(), "timeout": REINSERT_TIMEOUT})
	return _ok(events)


func reinsert(pid, pos: Variant) -> Dictionary:
	# 拆弹后把炸弹塞回牌堆:pos 0 = 顶 … deck.size() = 底;塞回后本回合结束
	if step == Step.OVER:
		return _fail(ERR_MATCH_OVER)
	if step != Step.REINSERT or pid != current_pid:
		return _fail(ERR_NOT_WAITING)
	if not pos is int or pos < 0 or pos > deck.size():
		return _fail(ERR_INVALID_POS)
	return _ok(_put_back_bomb(pos) + _end_turn())


# —— 反应窗口 ——

func nope(pid, card_index: Variant = -1) -> Dictionary:
	# 反应窗口里任何存活玩家(含出牌者自己)都能打;card_index = -1 时用手里第一张「不行!」。窗口重新计时
	if step == Step.OVER:
		return _fail(ERR_MATCH_OVER)
	if not alive.has(pid):
		return _fail(ERR_NOT_SEATED)
	if not alive[pid]:
		return _fail(ERR_OUT)
	if step != Step.WINDOW:
		return _fail(ERR_NO_WINDOW)
	var hand: Array = hands[pid]
	var index := -1
	if card_index is int and card_index == -1:
		index = hand.find(BombCatCard.NOPE)
		if index < 0:
			return _fail(ERR_NO_NOPE)
	elif card_index is int and card_index >= 0 and card_index < hand.size():
		if hand[card_index] != BombCatCard.NOPE:
			return _fail(ERR_NO_NOPE)
		index = card_index
	else:
		return _fail(ERR_INVALID_INDEX)
	hand.remove_at(index)
	discard.append(BombCatCard.NOPE)
	discard_top = BombCatCard.NOPE
	window["nopes"] += 1
	return _ok([{"type": "noped", "pid": pid, "depth": window["nopes"], "window": REACT_WINDOW}])


func resolve_window() -> Dictionary:
	# 窗口到点:「不行!」张数为偶数则原牌生效。牌已经进了弃牌堆,作废也不退回
	if step == Step.OVER:
		return _fail(ERR_MATCH_OVER)
	if step != Step.WINDOW:
		return _fail(ERR_NO_WINDOW)
	var w := window
	window = {}
	step = Step.TURN
	var effective: bool = w["nopes"] % 2 == 0
	var events := [{
		"type": "window_resolved",
		"pid": w["pid"],
		"kind": w["kind"],
		"effective": effective,
		"nopes": w["nopes"],
		"aborted": false,
	}]
	if effective:
		events.append_array(_apply(w))
	return _ok(events)


# —— 讨要:被点名的人给牌 ——

func give(pid, card_index: Variant) -> Dictionary:
	if step == Step.OVER:
		return _fail(ERR_MATCH_OVER)
	if step != Step.GIVE or pid != give_request["from"]:
		return _fail(ERR_NOT_WAITING)
	if not card_index is int or card_index < 0 or card_index >= hands[pid].size():
		return _fail(ERR_INVALID_INDEX)
	var asker = give_request["to"]
	give_request = {}
	step = Step.TURN
	_transfer_card(pid, asker, card_index)
	return _ok([_effect(BombCatCard.BEG, asker, {"from": pid, "to": asker, "got": true})])


# —— 超时代打与断线 ——

func timeout() -> Dictionary:
	# 当前步骤到点:窗口 → 结算;塞回 → 随机位置;给牌 → 随机给一张;自由行动 → 直接摸牌
	match step:
		Step.WINDOW:
			return resolve_window()
		Step.REINSERT:
			return reinsert(current_pid, rng.randi_range(0, deck.size()))
		Step.GIVE:
			var giver = give_request["from"]
			if hands[giver].is_empty():
				# 不该发生(给牌步骤里他没法出牌);兜底:讨要落空,回到讨要者的回合
				var asker = give_request["to"]
				give_request = {}
				step = Step.TURN
				return _ok([_effect(BombCatCard.BEG, asker, {"from": giver, "to": asker, "got": false})])
			return give(giver, rng.randi_range(0, hands[giver].size() - 1))
		Step.TURN:
			return draw(current_pid)
	return _fail(ERR_MATCH_OVER)


func eliminate(pid) -> Dictionary:
	# 断线 = 出局(手牌弃掉,没有爆炸)。不在局里或已出局的人返回空事件。
	# 他正卡着的步骤先收尾:自己的窗口作废、塞回中的炸弹随机塞回、讨要落空
	if step == Step.OVER or not alive.get(pid, false):
		return _ok([])
	var events := []
	match step:
		Step.WINDOW:
			if window["pid"] == pid:
				events.append({
					"type": "window_resolved", "pid": pid, "kind": window["kind"],
					"effective": false, "nopes": window["nopes"], "aborted": true,
				})
				window = {}
				step = Step.TURN
		Step.REINSERT:
			if current_pid == pid:
				events.append_array(_put_back_bomb(rng.randi_range(0, deck.size())))
		Step.GIVE:
			if give_request["from"] == pid or give_request["to"] == pid:
				var asker = give_request["to"]
				events.append(_effect(BombCatCard.BEG, asker, {"from": give_request["from"], "to": asker, "got": false}))
				give_request = {}
				step = Step.TURN
	return _ok(events + _knock_out(pid, "player_left"))


# —— 只读访问(视图与测试用)——

func is_member(pid) -> bool:
	return alive.has(pid)


func is_alive(pid) -> bool:
	return alive.get(pid, false)


func alive_pids() -> Array:
	return seat_order.filter(func(pid) -> bool: return alive[pid])


func step_name() -> String:
	return STEP_NAMES[step]


func bombs_left() -> int:
	# 场上还剩几张炸弹(公开信息:开局炸弹数 − 已炸飞的)
	return bombs_total - removed.size()


func hand_of(pid) -> Array:
	return hands.get(pid, []).duplicate()


func last_drawn_of(pid) -> Dictionary:
	# {"card", "seq"};没摸过为 {}
	return _last_drawn.get(pid, {}).duplicate()


func peek_of(pid) -> Dictionary:
	# {"cards": [顶 → 下], "seq"};没偷看或牌堆已变为 {}
	if not _peek.has(pid):
		return {}
	return {"cards": _peek[pid]["cards"].duplicate(), "seq": _peek[pid]["seq"]}


func reinsert_info(pid) -> Dictionary:
	# 轮到他塞回炸弹时 {"deck_count"}(可选位置 0..deck_count),否则 {}
	if step == Step.REINSERT and pid == current_pid:
		return {"deck_count": deck.size()}
	return {}


func give_info(pid) -> Dictionary:
	# 他被讨要、要挑一张给出时 {"to": 讨要的人},否则 {}
	if step == Step.GIVE and give_request["from"] == pid:
		return {"to": give_request["to"]}
	return {}


func transfer_of(pid) -> Dictionary:
	return _transfer.get(pid, {}).duplicate()


func card_count() -> int:
	# 守恒检查用:应恒等于 total_cards
	var total := deck.size() + discard.size() + removed.size() + (1 if held_bomb != "" else 0)
	for pid in hands:
		total += hands[pid].size()
	return total


static func combo_kind(cards: Array) -> String:
	# 牌组合的种类:单张可主动打出的功能牌 → 它的 id;2 / 3 张同样的零食 → pair / triple;否则 ""
	if cards.size() == 1:
		return cards[0] if BombCatCard.is_playable(cards[0]) else ""
	if cards.size() < 2 or cards.size() > MAX_COMBO or not BombCatCard.is_snack(cards[0]):
		return ""
	for card in cards:
		if card != cards[0]:
			return ""
	return KIND_PAIR if cards.size() == 2 else KIND_TRIPLE


# —— 内部 ——

func _apply(w: Dictionary) -> Array:
	var pid = w["pid"]
	var target = w["target"]
	match w["kind"]:
		BombCatCard.SKIP:
			return [_effect(BombCatCard.SKIP, pid, {})] + _end_turn()
		BombCatCard.PASS_TURNS:
			var turns: int = (turns_left + PASS_TURNS_ADD) if under_attack else PASS_TURNS_ADD
			current_pid = _next_alive_after(pid)
			turns_left = turns
			under_attack = true
			return [
				_effect(BombCatCard.PASS_TURNS, pid, {"to": current_pid, "turns": turns}),
				{"type": "turn_passed", "pid": current_pid, "turns": turns},
			]
		BombCatCard.PEEK:
			var cards := deck.slice(0, PEEK_COUNT)
			_seq += 1
			_peek[pid] = {"cards": cards, "seq": _seq}
			return [_effect(BombCatCard.PEEK, pid, {"count": cards.size()})]
		BombCatCard.SHUFFLE:
			BombCatDeck.shuffle(deck, rng)
			_peek = {}
			return [_effect(BombCatCard.SHUFFLE, pid, {})]
		BombCatCard.BEG:
			# 窗口期间目标可能断线出局或把牌打光:落空
			if not is_alive(target) or hands[target].is_empty():
				return [_effect(BombCatCard.BEG, pid, {"from": target, "to": pid, "got": false})]
			give_request = {"from": target, "to": pid}
			step = Step.GIVE
			return [{"type": "give_requested", "pid": target, "to": pid, "timeout": GIVE_TIMEOUT}]
		KIND_PAIR:
			var got: bool = is_alive(target) and not hands[target].is_empty()
			if got:
				_transfer_card(target, pid, rng.randi_range(0, hands[target].size() - 1))
			return [_effect("steal", pid, {"from": target, "to": pid, "got": got})]
		KIND_TRIPLE:
			var named: String = w["named"]
			var at: int = hands[target].find(named) if is_alive(target) else -1
			if at >= 0:
				_transfer_card(target, pid, at)
			return [_effect("request", pid, {"from": target, "to": pid, "named": named, "got": at >= 0})]
	return []


func _effect(kind: String, pid, fields: Dictionary) -> Dictionary:
	return {"type": "effect", "kind": kind, "pid": pid}.merged(fields)


func _transfer_card(from, to, index: int) -> void:
	var card: String = hands[from][index]
	hands[from].remove_at(index)
	hands[to].append(card)
	_seq += 1
	var record := {"card": card, "from": from, "to": to, "seq": _seq}
	_transfer[from] = record
	_transfer[to] = record.duplicate()


func _put_back_bomb(pos: int) -> Array:
	deck.insert(pos, held_bomb)
	held_bomb = ""
	step = Step.TURN
	_peek = {}
	return [{"type": "reinserted", "pid": current_pid, "deck_count": deck.size()}]


func _end_turn() -> Array:
	# 消耗当前玩家的一个回合:还有就继续由他行动,没了轮到下一位存活者
	turns_left -= 1
	if turns_left > 0:
		return [{"type": "turn_passed", "pid": current_pid, "turns": turns_left}]
	return _advance_from(current_pid)


func _advance_from(pid) -> Array:
	current_pid = _next_alive_after(pid)
	turns_left = 1
	under_attack = false
	return [{"type": "turn_passed", "pid": current_pid, "turns": 1}]


func _knock_out(pid, event_type: String) -> Array:
	# 出局:手牌垫到弃牌堆最底下(不改 discard_top),记出局顺序;只剩一人就结束,轮到他时交给下一位
	alive[pid] = false
	var dropped: Array = hands[pid]
	hands[pid] = []
	discard = dropped + discard
	out_order.append(pid)
	var events := [{"type": event_type, "pid": pid, "discarded": dropped.size()}]
	var left := alive_pids()
	if left.size() == 1:
		return events + _finish(left[0])
	if current_pid == pid:
		events.append_array(_advance_from(pid))
	return events


func _finish(winner) -> Array:
	step = Step.OVER
	winner_pid = winner
	current_pid = null
	turns_left = 0
	window = {}
	give_request = {}
	var ranking := [winner]
	for i in range(out_order.size() - 1, -1, -1):
		ranking.append(out_order[i])
	return [{"type": "match_over", "winner": winner, "ranking": ranking}]


func _check_actor(pid) -> String:
	# 出牌 / 摸牌的共同前提:对局没结束、轮到他、当前是自由行动步骤
	if step == Step.OVER:
		return ERR_MATCH_OVER
	if not alive.has(pid):
		return ERR_NOT_SEATED
	if not alive[pid]:
		return ERR_OUT
	if pid != current_pid:
		return ERR_NOT_YOUR_TURN
	if step != Step.TURN:
		return ERR_BUSY
	return ""


func _is_other_alive(pid, target: Variant) -> bool:
	return target is int and target != pid and is_alive(target)


static func _valid_indices(indices: Variant, hand_size: int) -> bool:
	# 1–3 个互不相同、在手牌范围内的整数下标(来自不可信对端:先判类型与长度)
	if not indices is Array or indices.is_empty() or indices.size() > MAX_COMBO:
		return false
	var seen := {}
	for i in indices:
		if not i is int or i < 0 or i >= hand_size or seen.has(i):
			return false
		seen[i] = true
	return true


func _next_alive_after(pid):
	var n := seat_order.size()
	var start := seat_order.find(pid)
	for offset in range(1, n + 1):
		var cand = seat_order[(start + offset) % n]
		if alive[cand]:
			return cand
	return null


func _ok(events: Array) -> Dictionary:
	return {"ok": true, "events": events}


func _fail(error: String) -> Dictionary:
	return {"ok": false, "error": error, "events": []}
