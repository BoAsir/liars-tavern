extends RefCounted
# 德州随机模拟器(给 test_poker_simulation.gd 用;文件名不以 test_ 开头,GUT 不会单独跑它)。
# 每一步随机做一件合法的事(行动、超时、再领、观战、回到牌桌、加入、离开),也穿插该被拒绝的意图;
# 每一步之后检查不变量(规格 §7、§8)。run() 出错时返回带种子、手号与最近若干步的说明,没出错返回 ""。

const R := preload("res://src/core/poker/poker_rules.gd")
const Checks := preload("res://tests/poker_sim_checks.gd")
const MAX_STEPS_PER_HAND := 600     # 正常一手几十步;超过它就是卡住了
const TRACE_SIZE := 14
const SEAT_EVENT_CHANCE := 0.04     # 每一步先插一次座位变化的概率
const BAD_INTENT_CHANCE := 0.03     # 每一步先试一个该被拒绝的意图的概率
const TIMEOUT_CHANCE := 0.04
const ALLIN_CHANCE := 0.05
const RAISE_CHANCE := 0.2
const FOLD_CHANCE := 0.2            # 不欠跟注时只有它的十分之一
const SMALL_RAISE_STEPS := 10       # 多数加注只比最小加注多几个单位,好让牌局走到后面的街

var _seed: int
var _rng := RandomNumberGenerator.new()
var _table: PokerTable
var _next_pid := 1
var _trace := []
var _steps_this_hand := 0
var _results := []
var stats := {}                     # 走到过的情形 → 次数(测试据此确认模拟覆盖了各条路径)


func _init(seed_value: int, index: int) -> void:
	# 第 index 个种子:开局人数在 2–8 人之间轮换,长短牌交替(规格 §8:2–8 人、长短牌各半)
	_seed = seed_value
	_rng.seed = seed_value
	var table_rng := RandomNumberGenerator.new()
	table_rng.seed = seed_value * 7919 + 1
	_table = PokerTable.new(index % 2 == 1, table_rng)
	for i in R.MIN_PLAYERS + index % (R.MAX_SEATS - R.MIN_PLAYERS + 1):
		_table.seat(_take_pid())


func run(hands: int) -> String:
	var error := ""
	while error == "" and _table.hand_number() < hands:
		error = _step()
	if error == "":
		error = _finish()
	if error == "":
		return ""
	return "种子 %d · 第 %d 手:%s\n最近的步骤:\n  %s" % [_seed, _table.hand_number(), error, "\n  ".join(_trace)]


# —— 一步 ——

func _step() -> String:
	if _rng.randf() < SEAT_EVENT_CHANCE:
		var error := _random_seat_event()
		if error != "":
			return error
	if _rng.randf() < BAD_INTENT_CHANCE:
		var error := _bad_intent()
		if error != "":
			return error
	match _table.phase():
		PokerTable.Phase.IDLE:
			return _idle_step()
		PokerTable.Phase.BETTING:
			return _betting_step()
	return "模拟中途散局了"


func _idle_step() -> String:
	if _table.can_start_hand():
		_steps_this_hand = 0
		return _apply("开第 %d 手" % (_table.hand_number() + 1), _table.start_hand())
	# 凑不够两个上桌者:让输光/离座的人回来,或者来个新人
	var options := _sitting_out()
	if options.is_empty() or (_seated() < R.MAX_SEATS and _rng.randf() < 0.3):
		return _join()
	return _bring_back(options[_rng.randi_range(0, options.size() - 1)])


func _betting_step() -> String:
	_steps_this_hand += 1
	if _steps_this_hand > MAX_STEPS_PER_HAND:
		return "一手超过 %d 步还没结束" % MAX_STEPS_PER_HAND
	var pid: int = _table.current_pid()
	if _rng.randf() < TIMEOUT_CHANCE:
		return _apply_result("p%d 超时" % pid, _table.timeout_action())
	var choice := _choose(_table.legal_actions(pid))
	return _apply_result("p%d %s %d" % [pid, choice[0], choice[1]], _table.act(pid, choice[0], choice[1]))


func _choose(legal: Dictionary) -> Array:
	var roll := _rng.randf()
	if roll < ALLIN_CHANCE and legal["can_allin"]:
		return [R.ALLIN, 0]
	if roll < ALLIN_CHANCE + RAISE_CHANCE and legal["can_raise"]:
		return [R.RAISE, _raise_amount(legal)]
	var fold_chance := FOLD_CHANCE / 10.0 if legal["can_check"] else FOLD_CHANCE
	if _rng.randf() < fold_chance:
		return [R.FOLD, 0]
	return [R.CHECK if legal["can_check"] else R.CALL, 0]


func _raise_amount(legal: Dictionary) -> int:
	@warning_ignore("integer_division")
	var steps: int = (legal["max_raise_to"] - legal["min_raise_to"]) / R.CHIP_UNIT
	var limit := steps if _rng.randf() < 0.3 else mini(steps, SMALL_RAISE_STEPS)
	return legal["min_raise_to"] + _rng.randi_range(0, limit) * R.CHIP_UNIT


# —— 座位变化 ——

func _random_seat_event() -> String:
	var roll := _rng.randf()
	if roll < 0.3:
		return _join()
	if roll < 0.55:
		var seated := _table.seat_order().filter(func(pid): return not _table.player(pid)["left"])
		if seated.is_empty():
			return ""
		var pid: int = seated[_rng.randi_range(0, seated.size() - 1)]
		return _apply("p%d 离开" % pid, _table.remove_player(pid))
	var sitting_out := _sitting_out()
	if sitting_out.is_empty():
		return ""
	return _bring_back(sitting_out[_rng.randi_range(0, sitting_out.size() - 1)])


func _join() -> String:
	var pid := _take_pid()
	var events := _table.add_player(pid)
	if _seated() > R.MAX_SEATS or (events.is_empty() and _seated() < R.MAX_SEATS):
		return "加入 p%d 的结果不对:%s" % [pid, events]
	return _apply("p%d 加入" % pid, events)


func _bring_back(pid: int) -> String:
	# 输光的人随机先观战;观战/输光的再领;离座的回到牌桌。都必须成功
	var status: String = _table.player(pid)["status"]
	if status == R.STATUS_AWAY:
		return _apply_result("p%d 回到牌桌" % pid, _table.sit_in(pid))
	if status == R.STATUS_BUSTED and _rng.randf() < 0.3:
		return _apply_result("p%d 观战" % pid, _table.spectate(pid))
	return _apply_result("p%d 再领" % pid, _table.rebuy(pid))


# —— 该被拒绝的意图:必须失败且不改任何状态 ——

func _bad_intent() -> String:
	var before := _snapshot()
	var label := ""
	var result := {}
	var current: Variant = _table.current_pid()
	var others := _table.seat_order().filter(func(pid): return pid != current)
	var legal := _table.legal_actions(current) if current != null else {}
	if not legal.is_empty() and legal["to_call"] > 0 and _rng.randf() < 0.5:
		label = "p%d 欠 %d 还想过牌" % [current, legal["to_call"]]
		result = _table.act(current, R.CHECK)
	elif not legal.is_empty() and legal["can_raise"] and _rng.randf() < 0.5:
		label = "p%d 加注到不合法的额" % current
		result = _table.act(current, R.RAISE, legal["min_raise_to"] - R.CHIP_UNIT)
	elif not others.is_empty():
		var pid: int = others[_rng.randi_range(0, others.size() - 1)]
		label = "p%d 不该行动" % pid
		result = _table.act(pid, R.CALL)
	else:
		label = "不在座的人行动"
		result = _table.act(-1, R.FOLD)
	stats["rejected"] = stats.get("rejected", 0) + 1
	if result["ok"]:
		return "该被拒绝的意图通过了:" + label
	if _snapshot() != before:
		return "被拒绝的意图改了状态:" + label
	return ""


func _snapshot() -> Array:
	var seats := []
	for pid in _table.seat_order():
		seats.append([pid, _table.player(pid), _table.hole_cards(pid)])
	return [
		_table.phase(), _table.hand_number(), _table.street(), _table.current_pid(), _table.current_bet(),
		_table.board(), _table.pots(), _table.chips_in_play(), _table.total_bought_in(), seats,
	]


# —— 收尾:散局并核对结算 ——

func _finish() -> String:
	var error := _apply("散局", _table.request_end())
	var guard := 0
	while error == "" and _table.phase() == PokerTable.Phase.BETTING and guard < MAX_STEPS_PER_HAND:
		guard += 1
		var pid: int = _table.current_pid()
		var choice := _choose(_table.legal_actions(pid))
		error = _apply_result("p%d %s %d" % [pid, choice[0], choice[1]], _table.act(pid, choice[0], choice[1]))
	if error != "":
		return error
	if _table.phase() != PokerTable.Phase.OVER:
		return "散局请求后没有结算"
	return _check_results(_results)


func _check_results(rows: Array) -> String:
	var total := 0
	for i in rows.size():
		var row: Dictionary = rows[i]
		total += row["net"]
		if row["net"] != row["stack"] - row["buyins"] * R.STARTING_STACK:
			return "结算行的盈亏算错:%s" % row
		if i > 0 and rows[i - 1]["net"] < row["net"]:
			return "结算没按盈亏降序"
	return "" if total == 0 else "盈亏之和 %d ≠ 0" % total


# —— 记录与检查 ——

func _apply_result(label: String, result: Dictionary) -> String:
	if not result["ok"]:
		return "合法的意图被拒绝(%s):%s" % [label, result.get("error", "")]
	return _apply(label, result["events"])


func _apply(label: String, events: Array) -> String:
	_trace.append("h%d %s → %s" % [_table.hand_number(), label, ",".join(events.map(func(e): return e["type"]))])
	if _trace.size() > TRACE_SIZE:
		_trace.pop_front()
	for e in events:
		_count(e)
		if e["type"] == "session_over":
			_results = e["results"]
	var error := Checks.events(_table, events)
	return error if error != "" else Checks.table(_table)


func _count(e: Dictionary) -> void:
	var keys: Array = [e["type"]]
	match e["type"]:
		"action":
			if e["timeout"]:
				keys.append("timeout")
		"bets_collected":
			if e["pots"].size() > 1:
				keys.append("side_pots")
			if not e["refund"].is_empty():
				keys.append("refund")
		"reveal":
			keys.append("reveal_" + e["reason"])
		"pot_won":
			if e["uncontested"]:
				keys.append("uncontested")
			if e["winners"].size() > 1:
				keys.append("split")
	for key in keys:
		stats[key] = stats.get(key, 0) + 1


func _take_pid() -> int:
	_next_pid += 1
	return _next_pid - 1


func _seated() -> int:
	return _table.seat_order().filter(func(pid): return not _table.player(pid)["left"]).size()


func _sitting_out() -> Array:
	# 没离开、但下一手不会被发牌的人:输光、观战、离座
	return _table.seat_order().filter(_is_sitting_out)


func _is_sitting_out(pid: int) -> bool:
	var p := _table.player(pid)
	return not p["left"] and [R.STATUS_BUSTED, R.STATUS_SPECTATING, R.STATUS_AWAY].has(p["status"])
