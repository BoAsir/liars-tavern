extends GutTest
# 炸弹猫导演:每段演出的实际时长不超过 BombCatPacing 的预算(同 test_poker_director_pacing:把导演与 BombCatCards 的节奏常量
# 按每种事件的最坏情况加起来,每个 await 再算一帧余量),导演认得设计稿 §7.3 的每一种公共事件、每种都有预算;
# 另测几个纯函数(日志、气泡、效果文案)。


const FRAME := 1.0 / 30.0
const C := preload("res://src/core/bomb_cat/bomb_cat_card.gd")
const H := preload("res://tests/bomb_cat_helpers.gd")
const D := preload("res://src/ui/bomb_cat/bomb_cat_director.gd")


func _budget_ok(actual: float, awaits: int, budget: float, what: String) -> void:
	assert_lte(actual + FRAME * awaits, budget, "%s:实际 %.2f + %d 帧余量 > 预算 %.2f" % [what, actual, awaits, budget])


func test_director_handles_every_public_event_type():
	assert_eq(D.HANDLED_EVENTS.size(), H.EVENT_KEYS.size())
	for type in H.EVENT_KEYS:
		assert_has(D.HANDLED_EVENTS, type, "导演要演 %s" % type)
		assert_gt(BombCatPacing.estimate([{"type": type, "kind": C.SKIP}]), 0.0, "%s 有预算" % type)


func test_intro_and_round_start_fit():
	_budget_ok(D.INTRO_MOVE, 1, BombCatPacing.INTRO, "intro")
	for players in range(BombCatDeck.MIN_PLAYERS, BombCatDeck.MAX_PLAYERS + 1):
		var cards := players * (BombCatDeck.HAND_SIZE + 1)
		# 等私有手牌最多 DEAL_PRIVATE_WAIT(逐帧等,算两帧余量),发牌一个 await
		_budget_ok(D.DEAL_PRIVATE_WAIT + BombCatCards.deal_duration(cards), 3, BombCatPacing.ROUND_STARTED, "%d 人发牌" % players)


func test_play_nope_and_window_fit():
	# 三张零食:每张错开 0.04 秒出手
	_budget_ok(BombCatCards.PLAY_FLIGHT + 2 * 0.04 + D.PLAY_HOLD, 2, BombCatPacing.PLAYED, "played")
	_budget_ok(BombCatCards.NOPE_RISE + BombCatCards.NOPE_SLAM + D.NOPE_HOLD, 3, BombCatPacing.NOPED, "noped")
	_budget_ok(D.RESOLVE_PAUSE, 1, BombCatPacing.WINDOW_RESOLVED, "window_resolved")
	_budget_ok(D.GIVE_PAUSE, 1, BombCatPacing.GIVE_REQUESTED, "give_requested")


func test_effects_fit():
	_budget_ok(D.SKIP_PAUSE, 1, BombCatPacing.EFFECT_SKIP, "skip")
	_budget_ok(D.PASS_PAUSE, 1, BombCatPacing.EFFECT_PASS_TURNS, "pass_turns")
	_budget_ok(D.PEEK_PAUSE, 3, BombCatPacing.EFFECT_PEEK, "peek")
	_budget_ok(BombCatCards.SHUFFLE_TIME + D.SHUFFLE_TAIL, 2, BombCatPacing.EFFECT_SHUFFLE, "shuffle")
	_budget_ok(D.PRIVATE_WAIT + BombCatCards.TRANSFER_FLIGHT + D.TRANSFER_TAIL, 4, BombCatPacing.EFFECT_TRANSFER, "转手")
	_budget_ok(D.MISS_PAUSE, 1, BombCatPacing.EFFECT_MISS, "落空")


func test_draw_and_bomb_fit():
	_budget_ok(D.PRIVATE_WAIT + BombCatCards.DRAW_FLIGHT + D.DRAW_TAIL, 3, BombCatPacing.DREW, "drew")
	_budget_ok(D.BOMB_PUSH + 0.1 + D.BOMB_HOLD, 2, BombCatPacing.BOMB_DRAWN, "bomb_drawn")
	_budget_ok(D.SNIP_TIME + D.DEFUSE_RELIEF, 2, BombCatPacing.DEFUSED, "defused")
	_budget_ok(BombCatCards.REINSERT_FLIGHT + D.REINSERT_TAIL, 2, BombCatPacing.REINSERTED, "reinserted")
	_budget_ok(D.EXPLODE_HOLD + D.CAMERA_BACK, 3, BombCatPacing.EXPLODED, "exploded")
	_budget_ok(D.LEFT_PAUSE, 1, BombCatPacing.PLAYER_LEFT, "player_left")
	_budget_ok(D.MATCH_HOLD, 1, BombCatPacing.MATCH_OVER, "match_over")
	assert_lte(BombCatCards.BOMB_FLIGHT, D.BOMB_PUSH + D.BOMB_HOLD, "炸弹牌在推近期间翻起来")
	assert_lte(BombCatCards.DROP_FLIGHT + 0.08, D.EXPLODE_HOLD, "出局者的手牌在爆炸那段里散完")


# —— 纯函数 ——

func test_played_text():
	var names := func(pid): return {1: "我", 2: "乙", 3: "丙"}.get(pid, "?")
	assert_eq(D.played_text({"pid": 2, "cards": [C.BEG], "kind": C.BEG, "target": 3}, names), "乙 打出「讨要」 → 丙")
	assert_eq(D.played_text({"pid": 2, "cards": [C.SKIP], "kind": C.SKIP, "target": null}, names), "乙 打出「溜了」")
	assert_eq(D.played_text({"pid": 1, "cards": [C.SNACK_FISH, C.SNACK_FISH], "kind": "pair", "target": 2}, names), "我 打出两张鱼干 → 乙")
	assert_eq(D.played_text({"pid": 1, "cards": [C.SNACK_YARN, C.SNACK_YARN, C.SNACK_YARN], "kind": "triple", "named": C.DEFUSE, "target": 3},
		names), "我 打出三张毛线球,点名「拆弹」 → 丙")
	assert_eq(D.played_text({"pid": "x", "cards": "bad"}, names), "? 打出「?」", "坏字段不崩")


func test_shouts_and_effect_texts():
	assert_eq(D.shout_for({"kind": C.PASS_TURNS}), "甩锅!")
	assert_eq(D.shout_for({"kind": "pair", "cards": [C.SNACK_CACTUS, C.SNACK_CACTUS]}), "两张仙人掌!")
	assert_eq(D.shout_for({"kind": "triple", "named": C.NOPE}), "我要「不行!」!")
	var names := func(pid): return {1: "我", 2: "乙", 3: "丙"}.get(pid, "?")
	assert_eq(D.effect_text({"kind": C.PASS_TURNS, "pid": 1, "to": 2, "turns": 4}, names), "我 把锅甩给 乙:要连走 4 回合")
	assert_eq(D.effect_text({"kind": "steal", "pid": 1, "from": 2, "to": 1, "got": true}, names), "我 从 乙 手里抽走一张")
	assert_eq(D.effect_text({"kind": "request", "pid": 1, "from": 3, "to": 1, "named": C.DEFUSE, "got": false}, names), "丙 手里没有「拆弹」")
	assert_eq(D.effect_text({"kind": C.BEG, "pid": 1, "from": 3, "to": 1, "got": true}, names), "丙 给了 我 一张牌")
	assert_eq(D.effect_text({"kind": "???"}, names), "")
	for ev in [{"kind": C.PEEK, "pid": 1, "count": 3}, {"kind": C.SHUFFLE, "pid": 1}, {"kind": C.SKIP, "pid": 2}]:
		assert_eq(H.event_leak({"type": "effect"}.merged(ev)), "", "文案的输入都是公共事件")
