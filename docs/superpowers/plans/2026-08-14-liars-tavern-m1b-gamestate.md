# M1b:GameState 核心状态机

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** TDD 实现整局生命周期状态机:发牌→轮转→出牌→质疑→开枪→小局重开→胜负,含断线淘汰。

**Architecture:** `GameState` 是纯 RefCounted,只在房主端存在。动作方法返回 `{"ok", "error"?, "events"?}`;`events` 数组是网络层广播和 UI 演出的唯一数据源。测试用白盒方式(直接改 `hands`/`target_card`/`revolvers` 内部状态)构造确定性场景。

**依赖:** M1a 完成(Card/Deck/Revolver/Rules 存在且单测全绿)。

事件类型一览(后续里程碑按此消费,不得改名):

| type | 载荷字段 | 含义 |
|---|---|---|
| `played` | pid, count | 有人出牌 |
| `turn` | pid | 轮到某人行动 |
| `reveal` | pid, cards, target, honest, challenger | 翻牌验证(challenger 为 null 表示系统强制验证;target 为被验证时的目标牌,供 UI 演出用,不依赖可能已被新小局覆盖的公共状态) |
| `gunshot` | pid, hit, shots_fired | 开枪结果 |
| `eliminated` | pid | 玩家出局(中弹或断线) |
| `round_started` | round, target, starter | 新小局开始 |
| `match_over` | winner | 整局结束 |

---

### Task 1: GameState 主体(TDD)

**Files:**
- Create: `src/core/game_state.gd`
- Test: `tests/test_game_state.gd`

- [ ] **Step 1: 写失败测试 `tests/test_game_state.gd`**

```gdscript
extends GutTest


func _make_gs(player_ids := [1, 2, 3], seed_value := 99) -> GameState:
	var gs := GameState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	gs.start_match(player_ids, rng)
	return gs


func _types(events: Array) -> Array:
	return events.map(func(e): return e["type"])


func _find(events: Array, type: String) -> Dictionary:
	for e in events:
		if e["type"] == type:
			return e
	return {}


func _seat_after(gs: GameState, pid) -> Variant:
	var idx := gs.seat_order.find(pid)
	return gs.seat_order[(idx + 1) % gs.seat_order.size()]


# —— 开局 ——

func test_start_match_deals_five_cards_and_sets_state():
	var gs := _make_gs()
	assert_eq(gs.phase, GameState.Phase.PLAYING)
	assert_eq(gs.round_number, 1)
	assert_true(gs.target_card in [Card.QUEEN, Card.KING, Card.ACE])
	assert_true(gs.current_pid in [1, 2, 3])
	assert_true(gs.last_play.is_empty())
	for pid in [1, 2, 3]:
		assert_true(gs.alive[pid])
		assert_eq(gs.hands[pid].size(), 5)


# —— 出牌 ——

func test_play_removes_cards_records_claim_and_advances_turn():
	var gs := _make_gs()
	var pid = gs.current_pid
	var result := gs.play_cards(pid, [0, 2])
	assert_true(result["ok"])
	assert_eq(gs.hands[pid].size(), 3)
	assert_eq(gs.last_play["pid"], pid)
	assert_eq(gs.last_play["count"], 2)
	assert_ne(gs.current_pid, pid)
	var types := _types(result["events"])
	assert_has(types, "played")
	assert_has(types, "turn")


func test_play_rejected_when_not_your_turn():
	var gs := _make_gs()
	var other = _seat_after(gs, gs.current_pid)
	var result := gs.play_cards(other, [0])
	assert_false(result["ok"])
	assert_eq(result["error"], "not_your_turn")


func test_play_rejected_with_invalid_indices():
	var gs := _make_gs()
	var pid = gs.current_pid
	assert_false(gs.play_cards(pid, [])["ok"])
	assert_false(gs.play_cards(pid, [0, 1, 2, 3])["ok"])
	assert_false(gs.play_cards(pid, [9])["ok"])
	assert_false(gs.play_cards(pid, [1, 1])["ok"])
	assert_eq(gs.hands[pid].size(), 5)


func test_turn_skips_empty_handed_players():
	var gs := _make_gs()
	var a = gs.current_pid
	var b = _seat_after(gs, a)
	var c = _seat_after(gs, b)
	gs.hands[b] = []
	gs.play_cards(a, [0])
	assert_eq(gs.current_pid, c)


# —— 质疑 ——

func test_first_actor_cannot_challenge():
	var gs := _make_gs()
	var result := gs.challenge(gs.current_pid)
	assert_false(result["ok"])
	assert_eq(result["error"], "nothing_to_challenge")


func test_challenge_honest_play_shoots_challenger_and_restarts_round():
	var gs := _make_gs()
	gs.target_card = Card.QUEEN
	var pid = gs.current_pid
	gs.hands[pid] = [Card.QUEEN, Card.JOKER, Card.KING, Card.KING, Card.ACE]
	gs.play_cards(pid, [0, 1])
	var challenger = gs.current_pid
	gs.revolvers[challenger].bullet_chamber = 6
	gs.revolvers[challenger].next_chamber = 1
	var result := gs.challenge(challenger)
	assert_true(result["ok"])
	var reveal := _find(result["events"], "reveal")
	assert_true(reveal["honest"])
	assert_eq(reveal["challenger"], challenger)
	assert_eq(reveal["target"], Card.QUEEN)
	var gunshot := _find(result["events"], "gunshot")
	assert_eq(gunshot["pid"], challenger)
	assert_false(gunshot["hit"])
	assert_has(_types(result["events"]), "round_started")
	assert_eq(gs.round_number, 2)
	assert_eq(gs.current_pid, challenger)
	for p in gs._alive_pids():
		assert_eq(gs.hands[p].size(), 5)


func test_challenge_lie_shoots_liar():
	var gs := _make_gs()
	gs.target_card = Card.QUEEN
	var pid = gs.current_pid
	gs.hands[pid] = [Card.KING, Card.QUEEN, Card.QUEEN, Card.ACE, Card.ACE]
	gs.play_cards(pid, [0])
	var challenger = gs.current_pid
	gs.revolvers[pid].bullet_chamber = 6
	gs.revolvers[pid].next_chamber = 1
	var result := gs.challenge(challenger)
	var gunshot := _find(result["events"], "gunshot")
	assert_eq(gunshot["pid"], pid)
	assert_eq(gs.current_pid, pid)


func test_fatal_shot_eliminates_and_ends_match():
	var gs := _make_gs([1, 2], 5)
	gs.target_card = Card.ACE
	var pid = gs.current_pid
	gs.hands[pid] = [Card.KING, Card.ACE, Card.ACE, Card.ACE, Card.ACE]
	gs.play_cards(pid, [0])
	var challenger = gs.current_pid
	gs.revolvers[pid].bullet_chamber = 1
	gs.revolvers[pid].next_chamber = 1
	var result := gs.challenge(challenger)
	var types := _types(result["events"])
	assert_has(types, "eliminated")
	assert_has(types, "match_over")
	assert_eq(gs.phase, GameState.Phase.MATCH_OVER)
	assert_eq(gs.winner_pid, challenger)
	assert_eq(gs.current_pid, null)
	assert_false(gs.play_cards(challenger, [0])["ok"])
	assert_false(gs.challenge(challenger)["ok"])


# —— 强制验证(仅剩一人有手牌)——

func test_last_player_with_cards_honest_play_auto_reveals_no_shot():
	var gs := _make_gs()
	gs.target_card = Card.QUEEN
	var pid = gs.current_pid
	for other in gs.seat_order:
		if other != pid:
			gs.hands[other] = []
	gs.hands[pid] = [Card.QUEEN, Card.JOKER]
	var result := gs.play_cards(pid, [0, 1])
	var types := _types(result["events"])
	assert_has(types, "reveal")
	assert_does_not_have(types, "gunshot")
	assert_has(types, "round_started")
	assert_eq(_find(result["events"], "reveal")["challenger"], null)
	assert_eq(gs.current_pid, pid)


func test_last_player_with_cards_lie_gets_shot():
	var gs := _make_gs()
	gs.target_card = Card.QUEEN
	var pid = gs.current_pid
	for other in gs.seat_order:
		if other != pid:
			gs.hands[other] = []
	gs.hands[pid] = [Card.KING]
	gs.revolvers[pid].bullet_chamber = 6
	gs.revolvers[pid].next_chamber = 1
	var result := gs.play_cards(pid, [0])
	var gunshot := _find(result["events"], "gunshot")
	assert_eq(gunshot["pid"], pid)
	assert_has(_types(result["events"]), "round_started")
```

- [ ] **Step 2: 跑测试验证失败**

Run: `$GODOT --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit`
Expected: FAIL(`GameState` 未定义)。

- [ ] **Step 3: 实现 `src/core/game_state.gd`**

```gdscript
class_name GameState
# 骗子牌核心状态机:仅在房主端运行,不依赖节点/网络/UI。
# 动作方法返回 {"ok": bool, "error"?: String, "events"?: Array}。


enum Phase { PLAYING, MATCH_OVER }

var rng: RandomNumberGenerator
var seat_order: Array = []
var alive := {}
var hands := {}
var revolvers := {}
var target_card := -1
var phase := Phase.PLAYING
var current_pid = null
var last_play := {}
var winner_pid = null
var round_number := 0


func start_match(player_ids: Array, p_rng: RandomNumberGenerator) -> void:
	rng = p_rng
	seat_order = player_ids.duplicate()
	alive = {}
	revolvers = {}
	for pid in seat_order:
		alive[pid] = true
		revolvers[pid] = Revolver.new(rng)
	phase = Phase.PLAYING
	winner_pid = null
	round_number = 0
	_start_round(seat_order[rng.randi_range(0, seat_order.size() - 1)])


func play_cards(pid, indices: Array) -> Dictionary:
	if phase != Phase.PLAYING:
		return {"ok": false, "error": "match_over"}
	if pid != current_pid:
		return {"ok": false, "error": "not_your_turn"}
	var hand: Array = hands[pid]
	if not Rules.is_play_valid(hand.size(), indices):
		return {"ok": false, "error": "invalid_play"}
	var order := indices.duplicate()
	order.sort()
	order.reverse()
	var cards := []
	for i in order:
		cards.append(hand[i])
		hand.remove_at(i)
	last_play = {"pid": pid, "cards": cards, "count": cards.size()}
	var events := [{"type": "played", "pid": pid, "count": cards.size()}]
	if _others_all_empty(pid):
		# 强制验证:场上只剩该玩家有手牌,系统自动翻牌(challenger 为 null)
		events.append_array(_resolve_reveal(null))
	else:
		current_pid = _next_actor_after(pid)
		events.append({"type": "turn", "pid": current_pid})
	return {"ok": true, "events": events}


func challenge(pid) -> Dictionary:
	if phase != Phase.PLAYING:
		return {"ok": false, "error": "match_over"}
	if pid != current_pid:
		return {"ok": false, "error": "not_your_turn"}
	if last_play.is_empty():
		return {"ok": false, "error": "nothing_to_challenge"}
	return {"ok": true, "events": _resolve_reveal(pid)}


func eliminate_player(pid) -> Array:
	# 断线淘汰:任意时刻可发生,返回事件列表(可能为空)。
	if phase != Phase.PLAYING or not alive.get(pid, false):
		return []
	alive[pid] = false
	var events := [{"type": "eliminated", "pid": pid}]
	if not last_play.is_empty() and last_play["pid"] == pid:
		last_play = {}  # 断线者未被验证的出牌作废
	var alive_list := _alive_pids()
	if alive_list.size() == 1:
		return events + _finish_match(alive_list[0])
	if current_pid == pid:
		current_pid = _next_actor_after(pid)
		if current_pid == null:
			# 极端情况:其余存活者手牌都已空,直接重开小局
			_start_round(_next_alive_after(pid))
			events.append(round_started_event())
		else:
			events.append({"type": "turn", "pid": current_pid})
	return events


func round_started_event() -> Dictionary:
	return {
		"type": "round_started",
		"round": round_number,
		"target": target_card,
		"starter": current_pid,
	}


func _resolve_reveal(challenger_pid) -> Array:
	var played_pid = last_play["pid"]
	var cards: Array = last_play["cards"]
	var honest := Rules.is_honest(cards, target_card)
	var events := [{
		"type": "reveal",
		"pid": played_pid,
		"cards": cards,
		"target": target_card,
		"honest": honest,
		"challenger": challenger_pid,
	}]
	# 真话 → 质疑者开枪(强制验证时无人开枪);假话 → 出牌者开枪
	var shooter = challenger_pid if honest else played_pid
	var next_starter = played_pid
	if shooter != null:
		var revolver: Revolver = revolvers[shooter]
		var hit: bool = revolver.pull_trigger()
		events.append({
			"type": "gunshot",
			"pid": shooter,
			"hit": hit,
			"shots_fired": revolver.shots_fired(),
		})
		if hit:
			alive[shooter] = false
			events.append({"type": "eliminated", "pid": shooter})
		next_starter = shooter if alive[shooter] else _next_alive_after(shooter)
	var alive_list := _alive_pids()
	if alive_list.size() == 1:
		return events + _finish_match(alive_list[0])
	_start_round(next_starter)
	events.append(round_started_event())
	return events


func _finish_match(winner) -> Array:
	phase = Phase.MATCH_OVER
	winner_pid = winner
	current_pid = null
	return [{"type": "match_over", "winner": winner}]


func _start_round(starter_pid) -> void:
	round_number += 1
	target_card = Deck.pick_target(rng)
	hands = Deck.deal(_alive_pids(), rng)
	last_play = {}
	current_pid = starter_pid


func _alive_pids() -> Array:
	var out := []
	for pid in seat_order:
		if alive[pid]:
			out.append(pid)
	return out


func _others_all_empty(pid) -> bool:
	for other in _alive_pids():
		if other != pid and hands[other].size() > 0:
			return false
	return true


func _next_actor_after(pid):
	# 下一个「存活且有手牌」的玩家;找不到返回 null。
	var n := seat_order.size()
	var start := seat_order.find(pid)
	for step in range(1, n + 1):
		var cand = seat_order[(start + step) % n]
		if alive[cand] and hands.get(cand, []).size() > 0:
			return cand
	return null


func _next_alive_after(pid):
	var n := seat_order.size()
	var start := seat_order.find(pid)
	for step in range(1, n + 1):
		var cand = seat_order[(start + step) % n]
		if alive[cand]:
			return cand
	return null
```

- [ ] **Step 4: 跑测试验证通过**

Expected: test_game_state 全部用例 PASS,此前测试仍 PASS。

- [ ] **Step 5: Commit**

```bash
git add src/core/game_state.gd tests/test_game_state.gd
git commit -m "feat: GameState 状态机(出牌/质疑/开枪/强制验证/胜负)"
```

### Task 2: 断线淘汰路径补测(TDD)

**Files:**
- Modify: `tests/test_game_state.gd`(文件末尾追加)

- [ ] **Step 1: 追加失败测试到 `tests/test_game_state.gd` 末尾**

```gdscript
# —— 断线淘汰 ——

func test_eliminate_player_advances_turn_and_voids_their_play():
	var gs := _make_gs()
	var a = gs.current_pid
	gs.play_cards(a, [0])
	var b = gs.current_pid
	var events := gs.eliminate_player(a)
	assert_has(_types(events), "eliminated")
	assert_true(gs.last_play.is_empty())
	assert_eq(gs.current_pid, b)
	assert_false(gs.alive[a])


func test_eliminate_current_player_passes_turn():
	var gs := _make_gs()
	var a = gs.current_pid
	var events := gs.eliminate_player(a)
	assert_has(_types(events), "turn")
	assert_ne(gs.current_pid, a)


func test_eliminate_down_to_one_wins_match():
	var gs := _make_gs([1, 2], 8)
	var loser = gs.current_pid
	var winner = _seat_after(gs, loser)
	var events := gs.eliminate_player(loser)
	assert_has(_types(events), "match_over")
	assert_eq(gs.winner_pid, winner)


func test_eliminate_dead_or_after_match_over_is_noop():
	var gs := _make_gs([1, 2], 8)
	gs.eliminate_player(gs.current_pid)
	assert_eq(gs.eliminate_player(gs.winner_pid).size(), 0)
```

- [ ] **Step 2: 跑测试**

Expected: 4 个新用例直接 PASS(实现已含 eliminate_player;若 FAIL 则按断言修实现,不改测试)。

- [ ] **Step 3: Commit**

```bash
git add tests/test_game_state.gd
git commit -m "test: 断线淘汰路径覆盖"
```
