extends GutTest


func _make_lobby() -> LobbyModel:
	var lobby := LobbyModel.new()
	lobby.add_host("房主")
	return lobby


func test_host_is_present_and_ready():
	var lobby := _make_lobby()
	assert_eq(lobby.size(), 1)
	var view := lobby.view()
	assert_eq(view[0]["pid"], LobbyModel.HOST_ID)
	assert_true(view[0]["ready"])
	assert_true(view[0]["is_host"])


func _lobby_with(count: int) -> LobbyModel:
	# 房主 + (count - 1) 位客人
	var lobby := _make_lobby()
	for i in count - 1:
		lobby.add_member(10 + i, "客%d" % i)
	return lobby


func test_join_checks_version_game_state_and_capacity():
	var lobby := _make_lobby()
	assert_eq(lobby.check_join(Protocol.VERSION, false, GameMode.LIARS, false), "")
	assert_string_contains(lobby.check_join(Protocol.VERSION + 1, false, GameMode.LIARS, false), "版本")
	assert_string_contains(lobby.check_join(Protocol.VERSION, true, GameMode.LIARS, false), "已开始")
	for id in [10, 11, 12]:
		lobby.add_member(id, "客%d" % id)
	assert_string_contains(lobby.check_join(Protocol.VERSION, false, GameMode.LIARS, false), "已满")


func test_version_is_judged_before_anything_else():
	# 主菜单靠「版本」字样去问房主要更新:对局中、满员的房间也得先报版本不符
	var lobby := _lobby_with(GameMode.max_players(GameMode.HOLDEM))
	for mode in GameMode.ALL:
		for in_game in [false, true]:
			for accepting_late in [false, true]:
				var reason := lobby.check_join(Protocol.VERSION - 1, in_game, mode, accepting_late)
				assert_string_contains(reason, "版本", "%s in_game=%s late=%s" % [mode, in_game, accepting_late])


func test_running_poker_table_seats_late_joiners():
	for mode in [GameMode.HOLDEM, GameMode.SHORT_DECK]:
		assert_eq(_make_lobby().check_join(Protocol.VERSION, true, mode, true), "", mode)


func test_closed_match_reasons_differ_by_mode():
	# 德州散局中或已结算时不再收人,文案和骗子酒馆的「已开始」不同
	assert_eq(_make_lobby().check_join(Protocol.VERSION, true, GameMode.SHORT_DECK, false), "牌局正在散局,请稍后再来")
	assert_eq(_make_lobby().check_join(Protocol.VERSION, true, GameMode.LIARS, false), "游戏已开始,请等这一局结束")


func test_capacity_follows_the_mode():
	var four := _lobby_with(4)
	assert_eq(four.check_join(Protocol.VERSION, false, GameMode.LIARS, false), "房间已满(4/4)")
	assert_eq(four.check_join(Protocol.VERSION, false, GameMode.HOLDEM, false), "")
	var eight := _lobby_with(8)
	assert_eq(eight.check_join(Protocol.VERSION, false, GameMode.HOLDEM, false), "房间已满(8/8)")
	assert_eq(eight.check_join(Protocol.VERSION, true, GameMode.SHORT_DECK, true), "房间已满(8/8)", "对局中满员也不能入座")


func test_members_join_unready_with_sanitized_unique_names():
	var lobby := _make_lobby()
	lobby.add_member(10, "  阿杰 ")
	lobby.add_member(11, "阿杰")
	lobby.add_member(12, "")
	var names := lobby.names()
	assert_eq(names[10], "阿杰")
	assert_eq(names[11], "阿杰 2")
	assert_eq(names[12], "酒客 4")
	assert_false(lobby.view()[1]["ready"])


func test_seat_order_is_join_order():
	var lobby := _make_lobby()
	lobby.add_member(900, "乙")
	lobby.add_member(5, "丙")
	assert_eq(lobby.seat_order(), [1, 900, 5])


func test_can_start_needs_two_players_all_ready():
	var lobby := _make_lobby()
	assert_false(lobby.can_start())
	lobby.add_member(10, "乙")
	assert_false(lobby.can_start())
	assert_true(lobby.set_ready(10, true))
	assert_true(lobby.can_start())
	lobby.add_member(11, "丙")
	assert_false(lobby.can_start())


func test_set_ready_unknown_member_and_host_is_rejected():
	var lobby := _make_lobby()
	assert_false(lobby.set_ready(99, true))
	assert_false(lobby.set_ready(LobbyModel.HOST_ID, false))
	assert_true(lobby.view()[0]["ready"])


func test_remove_member_and_host_cannot_be_removed():
	var lobby := _make_lobby()
	lobby.add_member(10, "乙")
	assert_true(lobby.remove(10))
	assert_false(lobby.remove(10))
	assert_false(lobby.remove(LobbyModel.HOST_ID))
	assert_eq(lobby.seat_order(), [1])


func test_reset_ready_keeps_host_ready_only():
	var lobby := _make_lobby()
	lobby.add_member(10, "乙")
	lobby.set_ready(10, true)
	lobby.reset_ready()
	assert_false(lobby.view()[1]["ready"])
	assert_true(lobby.view()[0]["ready"])


func test_view_is_detached_copy():
	var lobby := _make_lobby()
	var view := lobby.view()
	view[0]["name"] = "篡改"
	assert_eq(lobby.names()[1], "房主")
