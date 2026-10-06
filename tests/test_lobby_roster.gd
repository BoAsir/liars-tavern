extends GutTest
# 等待厅名单对比:首份名单只当基准(已在房里的人和自己都不播「走进了酒馆」)。


const LobbyScreen := preload("res://src/ui/lobby/lobby.gd")


func _player(pid: int, pname: String) -> Dictionary:
	return {"pid": pid, "name": pname, "ready": false, "is_host": pid == 1}


func test_first_roster_is_only_a_baseline():
	var players := [_player(1, "房主"), _player(5, "老王"), _player(9, "小明")]
	var changes: Dictionary = LobbyScreen.roster_changes({}, players, 9)
	assert_eq(changes["joined"], [])
	assert_eq(changes["left"], [])
	assert_eq_deep(changes["now"], {1: "房主", 5: "老王", 9: "小明"})


func test_empty_roster_keeps_waiting_for_a_baseline():
	var changes: Dictionary = LobbyScreen.roster_changes({}, [], 1)
	assert_eq(changes["joined"], [])
	assert_true(changes["now"].is_empty())


func test_arrivals_and_departures_after_the_baseline():
	var changes: Dictionary = LobbyScreen.roster_changes({1: "房主", 5: "老王"}, [_player(1, "房主"), _player(7, "阿花")], 1)
	assert_eq(changes["joined"], [7])
	assert_eq(changes["left"], [5])


func test_never_announces_yourself():
	var changes: Dictionary = LobbyScreen.roster_changes({1: "房主"}, [_player(1, "房主"), _player(3, "我")], 3)
	assert_eq(changes["joined"], [])


func test_unchanged_roster_announces_nothing():
	var players := [_player(1, "房主"), _player(5, "老王")]
	var changes: Dictionary = LobbyScreen.roster_changes({1: "房主", 5: "老王"}, players, 5)
	assert_eq(changes["joined"], [])
	assert_eq(changes["left"], [])
