extends GutTest
# 牌桌控制器里不依赖场景的部分:能否质疑、局界处作废预选、记录出局局号。


const TableScreen := preload("res://src/ui/table/table_screen.gd")


func _bare_screen() -> Node:
	# 不入树:_ready 不会运行,HUD/导演为空,只测状态逻辑
	return autofree(TableScreen.new(null))


func test_cannot_challenge_when_nothing_was_played():
	assert_false(TableScreen.is_challengeable({}, 1))


func test_can_challenge_someone_elses_play():
	assert_true(TableScreen.is_challengeable({"pid": 2, "count": 1}, 1))


func test_cannot_challenge_own_play_when_the_turn_comes_back():
	# 出牌者之后的人都断线或打空手牌时,轮转可能回到出牌者本人
	assert_false(TableScreen.is_challengeable({"pid": 1, "count": 2}, 1))


func test_new_round_drops_the_preselection():
	# 新一局发的是新手牌:旧下标会落到别的牌上
	var screen := _bare_screen()
	screen._selected = {0: true, 2: true}
	screen._hovered = 1
	screen.begin_round(3)
	assert_true(screen._selected.is_empty())
	assert_eq(screen._hovered, -1)


func test_elimination_remembers_the_round_it_happened_in():
	var screen := _bare_screen()
	screen.my_pid = 1
	screen.begin_round(2)
	screen.mark_eliminated(3)
	screen.begin_round(5)
	screen.mark_eliminated(2)
	assert_eq(screen._out_round, {3: 2, 2: 5})
	assert_eq(screen._elimination_order, [3, 2])


func test_survived_rounds_count_to_the_final_round_for_the_winner():
	var screen := _bare_screen()
	screen.names = {1: "甲", 2: "乙"}
	screen.begin_round(1)
	screen.mark_eliminated(2)
	screen.begin_round(4)
	var stats: Dictionary = screen.player_stats()
	assert_eq(stats[1]["rounds"], 4)
	assert_eq(stats[2]["rounds"], 1)
	assert_eq(stats[2]["name"], "乙")
