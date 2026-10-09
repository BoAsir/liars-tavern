extends GutTest
# 德州牌桌测试的共用基类(文件名不以 test_ 开头,GUT 不会单独跑它):建桌、指定按钮、按当前行动者出手。

const H := preload("res://tests/poker_helpers.gd")
const R := preload("res://src/core/poker/poker_rules.gd")


func make_table(pids: Array, short_deck := false, seed_value := 1) -> PokerTable:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var t := PokerTable.new(short_deck, rng)
	for pid in pids:
		t.seat(pid)
	return t


func start_with_button(t: PokerTable, button: int, rig := {}) -> Array:
	# 测试钩子 button_pid 是「上一手的按钮」:下一手按钮是他之后的下一位上桌者,所以填按钮的上家
	var order := t.seat_order()
	t.button_pid = order[(order.find(button) - 1 + order.size()) % order.size()]
	t.rigged = rig
	return t.start_hand()


func play(t: PokerTable, action: String, amount := 0) -> Array:
	# 当前行动者出手并断言成功
	var pid: Variant = t.current_pid()
	var result := t.act(pid, action, amount)
	assert_true(result["ok"], "%s %s %d → %s" % [pid, action, amount, result.get("error", "")])
	return result.get("events", [])


func play_as(t: PokerTable, pid: int, action: String, amount := 0) -> Array:
	assert_eq(t.current_pid(), pid, "应该轮到 %d" % pid)
	return play(t, action, amount)


func fold_out(t: PokerTable) -> Array:
	# 一直弃牌直到这一手结束(最后一人不战而胜)
	var events := []
	while t.phase() == PokerTable.Phase.BETTING:
		events.append_array(play(t, R.FOLD))
	return events


func check_down(t: PokerTable) -> Array:
	# 能过牌就过、要跟就跟,直到这一手结束
	var events := []
	while t.phase() == PokerTable.Phase.BETTING:
		var legal := t.legal_actions(t.current_pid())
		events.append_array(play(t, R.CHECK if legal["can_check"] else R.CALL))
	return events


func error_of(result: Dictionary) -> String:
	assert_false(result["ok"])
	return result.get("error", "")


func assert_no_card_leak(t: PokerTable, events: Array, pid: int) -> void:
	# 没摊牌就赢的人:事件里不能有他的牌与牌型名(按字段查,牌值会和筹码数撞,不能按数值搜)
	for e in events:
		if e["type"] == "reveal":
			for hand in e["hands"]:
				assert_ne(hand["pid"], pid, "不该亮他的牌")
		if e["type"] == "pot_won":
			assert_eq(e["hand_name"], "")
			assert_eq(e["best"], {})
			assert_true(e["uncontested"])
	assert_eq(t.player(pid)["shown"], [])
