extends "res://tests/poker_table_case.gd"
# 德州视图(规格 §4.6):公共视图永远不含没亮的手牌。不泄露按字段路径检查:视图的键集合固定,
# 带牌的键只有 board 与 players[].shown(牌值 8–59 会和筹码数、手数撞值,不能按数值搜)。


const NAMES := {1: "甲", 2: "乙", 3: "丙"}
const MODE := GameMode.SHORT_DECK
# 公共视图的全部键路径(含嵌套):多一个键就可能多一条泄露路径,少一个键界面会缺数据
const PUBLIC_PATHS := [
	"actions", "actions.call_amount", "actions.can_allin", "actions.can_check", "actions.can_raise",
	"actions.max_raise_to", "actions.min_raise_to", "actions.pid", "actions.to_call",
	"bb", "blinds", "board", "button", "current_bet", "current_pid", "ending", "hand", "mode", "phase",
	"players", "players[].bet", "players[].buyins", "players[].committed", "players[].left", "players[].name",
	"players[].net", "players[].pid", "players[].shown", "players[].stack", "players[].status",
	"pots", "pots[].amount", "pots[].eligible", "results", "sb", "seats", "street", "turn_time_left",
]
const CARD_PATHS := ["board", "players[].shown"]


func _rig(holes: Dictionary, board := "8c 6h 4d Jc 3s", stacks := {}) -> Dictionary:
	var hole_cards := {}
	for pid in holes:
		hole_cards[pid] = H.cards(holes[pid])
	return {"holes": hole_cards, "board": H.cards(board), "stacks": stacks}


func _public(t: PokerTable, time_left := 0.0) -> Dictionary:
	return PokerViews.public_view(t, NAMES, MODE, time_left)


func _paths(value: Variant, prefix: String, out: Dictionary) -> void:
	# 收集字典/数组里出现过的所有键路径:数组元素统一记作 []
	if value is Dictionary:
		for key in value:
			var path := str(key) if prefix == "" else "%s.%s" % [prefix, key]
			out[path] = true
			_paths(value[key], path, out)
	elif value is Array:
		for item in value:
			_paths(item, prefix + "[]", out)


func _public_paths(pub: Dictionary) -> Array:
	var out := {}
	_paths(pub, "", out)
	var paths := out.keys()
	paths.sort()
	return paths


func _to_flop(t: PokerTable) -> void:
	start_with_button(t, 1, _rig({1: "Ah Kh", 2: "Qs Qd", 3: "7c 8d"}))   # 小盲 2、大盲 3,1 先说话
	play_as(t, 1, R.CALL)
	play_as(t, 2, R.CALL)
	play_as(t, 3, R.CHECK)
	assert_eq(t.street(), R.FLOP)


# —— 不泄露 ——

func test_public_view_has_exactly_the_documented_keys():
	var t := make_table([1, 2, 3], true)
	_to_flop(t)
	play_as(t, 2, R.RAISE, 40)
	assert_eq(_public_paths(_public(t)), PUBLIC_PATHS)


func test_cards_only_appear_on_the_board_and_in_revealed_hands():
	var t := make_table([1, 2, 3], true)
	_to_flop(t)
	var pub := _public(t)
	assert_eq(pub["board"], H.cards("8c 6h 4d"), "只含已翻开的公共牌,没翻的不外露")
	for p in pub["players"]:
		assert_eq(p["shown"], [], "没亮过的人 shown 为空")
	for path in CARD_PATHS:
		assert_has(PUBLIC_PATHS, path)


func test_showdown_reveals_only_the_players_still_in_the_hand():
	var t := make_table([1, 2, 3], true)
	_to_flop(t)
	play_as(t, 2, R.FOLD)
	check_down(t)
	var shown := {}
	for p in _public(t)["players"]:
		shown[p["pid"]] = p["shown"]
	assert_eq(shown, {1: H.cards("Ah Kh"), 2: [], 3: H.cards("7c 8d")}, "弃牌的人不亮牌")


func test_uncontested_win_on_the_river_shows_nothing():
	var t := make_table([1, 2, 3], true)
	_to_flop(t)
	play_as(t, 2, R.CHECK)
	play_as(t, 3, R.CHECK)
	play_as(t, 1, R.CHECK)
	play_as(t, 2, R.CHECK)
	play_as(t, 3, R.CHECK)
	play_as(t, 1, R.CHECK)
	assert_eq(t.street(), R.RIVER)
	play_as(t, 2, R.RAISE, 200)
	var events := play_as(t, 3, R.FOLD)
	events.append_array(play_as(t, 1, R.FOLD))
	assert_no_card_leak(t, events, 2)
	var pub := _public(t)
	assert_eq(pub["board"].size(), 5)
	for p in pub["players"]:
		assert_eq(p["shown"], [], "没摊牌就赢:谁的牌都不亮")
	assert_eq(_public_paths(pub).filter(func(path: String) -> bool: return path.begins_with("results")), ["results"])


func test_private_views_hold_only_your_own_cards():
	var t := make_table([1, 2, 3], true)
	_to_flop(t)
	for pid in [1, 2, 3]:
		var priv := PokerViews.private_view(t, pid)
		assert_eq(priv.keys(), ["hand", "hole", "best"])
		assert_eq(priv["hand"], 1)
		assert_eq(priv["hole"], t.hole_cards(pid))
		assert_eq(priv["best"], t.best_hand(pid), "公共牌 ≥ 3 张时房主算好当前最大牌型")
		assert_eq(priv["best"]["cards"].size(), 5)


# —— 可选动作 ——

func test_actions_match_legal_actions_for_the_current_player():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)
	var pub := _public(t)
	assert_eq(pub["current_pid"], 1)
	assert_eq(pub["actions"], {"pid": 1}.merged(t.legal_actions(1)))
	assert_eq(pub["actions"]["to_call"], 20)
	assert_eq(pub["current_bet"], 20)
	assert_eq(pub["blinds"], [R.SMALL_BLIND, R.BIG_BLIND])
	assert_almost_eq(_public(t, 12.5)["turn_time_left"], 12.5, 0.001)
	assert_eq(_public(t, -3.0)["turn_time_left"], 0.0)


# —— 两手之间 ——

func test_between_hands_keeps_the_last_hand_on_the_table():
	var t := make_table([1, 2, 3], true)
	_to_flop(t)
	play_as(t, 2, R.FOLD)
	check_down(t)
	var pub := _public(t, 9.0)
	assert_eq(pub["phase"], "idle")
	assert_eq(pub["hand"], 1)
	assert_eq(pub["street"], R.SHOWDOWN)
	assert_eq(pub["board"].size(), 5, "上一手的公共牌留在桌上")
	assert_eq(pub["pots"], [])
	assert_eq([pub["button"], pub["sb"], pub["bb"]], [1, 2, 3])
	assert_eq(pub["current_pid"], null)
	assert_eq(pub["actions"], {})
	assert_eq(pub["turn_time_left"], 0.0, "没人在计时")
	assert_false(pub["ending"])
	assert_eq(pub["results"], [])
	var statuses: Array = pub["players"].map(func(p: Dictionary) -> String: return p["status"])
	assert_eq(statuses, [R.STATUS_ACTIVE, R.STATUS_FOLDED, R.STATUS_ACTIVE], "各人保留一手结束时的状态")


func test_before_the_first_hand_the_view_is_empty_but_well_formed():
	var t := make_table([1, 2])
	var pub := _public(t)
	assert_eq([pub["phase"], pub["hand"], pub["street"], pub["board"], pub["pots"]], ["idle", 0, "", [], []])
	assert_eq([pub["button"], pub["sb"], pub["bb"], pub["current_pid"], pub["current_bet"]], [null, null, null, null, 0])
	assert_eq(pub["seats"], [1, 2], "开局入座的人第一手之前就有酒客")
	assert_eq(pub["mode"], MODE)


# —— seats 与 players ——

func test_seats_are_the_patrons_on_the_table_and_newcomers_come_last():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)
	t.add_player(4)
	var pub := _public(t)
	assert_eq(pub["seats"], [1, 2, 3], "新人要等下一手才登场")
	var pids: Array = pub["players"].map(func(p: Dictionary) -> int: return p["pid"])
	assert_eq(pids, [1, 2, 3, 4], "players 按 seats 顺序,还没登场的新人排在最后")
	var newcomer: Dictionary = pub["players"][3]
	assert_eq([newcomer["status"], newcomer["stack"], newcomer["buyins"], newcomer["net"], newcomer["name"]],
		[R.STATUS_WAITING, 2000, 1, 0, "4"])
	assert_eq(PokerViews.private_view(t, 4), {"hand": 1, "hole": [], "best": {}}, "没被发牌的人没有手牌")
	t.remove_player(2)
	pub = _public(t)
	assert_eq(pub["seats"], [1, 3], "离场者的酒客立即离场")
	var left: Dictionary = pub["players"][1]
	assert_eq([left["pid"], left["left"], left["status"]], [2, true, R.STATUS_FOLDED], "本手里他仍在 players 里,标 left")


func test_player_rows_copy_the_engine_record_with_names():
	var t := make_table([1, 2, 3])
	start_with_button(t, 1)
	play_as(t, 1, R.RAISE, 60)
	var row: Dictionary = _public(t)["players"][0]
	var expected := t.player(1)
	expected["pid"] = 1
	expected["name"] = "甲"
	assert_eq(row, expected)
	assert_eq([row["bet"], row["committed"], row["stack"], row["net"]], [60, 60, 1940, -60])


func test_results_carry_names_once_the_session_is_over():
	var t := make_table([1, 2, 3])
	t.remove_player(3)
	t.request_end()
	var pub := _public(t, 5.0)
	assert_eq(pub["phase"], "over")
	assert_eq(pub["turn_time_left"], 0.0)
	assert_eq(pub["results"].size(), 3)
	for row in pub["results"]:
		assert_eq(row["name"], NAMES[row["pid"]])
	assert_eq(pub["results"].filter(func(r: Dictionary) -> bool: return r["left"]).size(), 1)
