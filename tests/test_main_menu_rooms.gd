extends GutTest
# 主菜单房间行:局域网报文里的人数/上限不可信,画座位前夹到合法范围。


const MainMenuScreen := preload("res://src/ui/main_menu/main_menu.gd")


func test_normal_counts_pass_through():
	assert_eq(MainMenuScreen.clamp_seats(2, 4), Vector2i(2, 4))
	assert_eq(MainMenuScreen.seat_dots(Vector2i(2, 4)), "●●○○")


func test_huge_counts_are_capped_at_max_players():
	assert_eq(MainMenuScreen.clamp_seats(2000000000, 99999999), Vector2i(Protocol.MAX_PLAYERS, Protocol.MAX_PLAYERS))


func test_negative_counts_become_empty_seats():
	assert_eq(MainMenuScreen.clamp_seats(-3, 99999999), Vector2i(0, Protocol.MAX_PLAYERS))
	assert_eq(MainMenuScreen.clamp_seats(0, -5), Vector2i(0, 0))


func test_capacity_never_below_players():
	assert_eq(MainMenuScreen.clamp_seats(3, 1), Vector2i(3, 3))
	assert_eq(MainMenuScreen.seat_dots(MainMenuScreen.clamp_seats(3, 1)), "●●●")
