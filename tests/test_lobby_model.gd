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


func test_join_checks_version_game_state_and_capacity():
	var lobby := _make_lobby()
	assert_eq(lobby.check_join(Protocol.VERSION, false), "")
	assert_string_contains(lobby.check_join(Protocol.VERSION + 1, false), "版本")
	assert_string_contains(lobby.check_join(Protocol.VERSION, true), "已开始")
	for id in [10, 11, 12]:
		lobby.add_member(id, "客%d" % id)
	assert_string_contains(lobby.check_join(Protocol.VERSION, false), "已满")


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
