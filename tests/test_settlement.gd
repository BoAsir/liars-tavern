extends GutTest
# 结算:名次(胜者第 1,其余按出局先后倒序)、各自存活局数(规格 2.6)、键盘默认焦点。


const STATS := {
	1: {"name": "甲", "shots": 2, "rounds": 7},
	2: {"name": "乙", "shots": 1, "rounds": 2},
	3: {"name": "丙", "shots": 3, "rounds": 6},
}


func _field(ranking: Array, key: String) -> Array:
	return ranking.map(func(entry): return entry[key])


func test_ranking_puts_winner_first_then_the_last_to_fall():
	var ranking := Settlement.build_ranking(1, [2, 3], STATS)
	assert_eq(_field(ranking, "name"), ["甲", "丙", "乙"])
	assert_eq(_field(ranking, "place"), [1, 2, 3])


func test_ranking_carries_survived_rounds_and_shots():
	var ranking := Settlement.build_ranking(1, [2, 3], STATS)
	assert_eq(_field(ranking, "rounds"), [7, 6, 2])
	assert_eq(_field(ranking, "shots"), [2, 3, 1])


func test_ranking_does_not_modify_the_stats():
	Settlement.build_ranking(1, [2, 3], STATS)
	assert_false(STATS[1].has("place"))


func test_ranking_lists_the_winner_once_and_tolerates_unknown_players():
	var ranking := Settlement.build_ranking(9, [2, 9], STATS)
	assert_eq(_field(ranking, "name"), ["?", "乙"])
	assert_eq(_field(ranking, "place"), [1, 2])
	assert_eq(ranking[0]["shots"], 0)


func test_rows_show_each_players_survived_rounds():
	var panel: Settlement = add_child_autofree(Settlement.new("甲", Settlement.build_ranking(1, [2, 3], STATS), false))
	for text in ["存活 7 局", "存活 6 局", "存活 2 局"]:
		assert_not_null(_find_label(panel, text), text)


func test_guest_gets_default_focus_on_leave_button():
	# 非房主没有「再来一局」:默认焦点落在「离开房间」,纯键盘也能离开
	get_viewport().gui_release_focus()
	add_child_autofree(Settlement.new("甲", Settlement.build_ranking(1, [2], STATS), false))
	await wait_process_frames(2)
	var focused := get_viewport().gui_get_focus_owner()
	assert_true(focused is Button)
	if focused is Button:
		assert_eq((focused as Button).text, "离开房间")


func test_does_not_steal_focus_from_a_dialog_on_top():
	# 说明书/确认框正拿着焦点:结算若抢走焦点,回车会在它们背后按下结算按钮
	var edit := LineEdit.new()
	add_child_autofree(edit)
	edit.grab_focus()
	add_child_autofree(Settlement.new("甲", Settlement.build_ranking(1, [2], STATS), false))
	await wait_process_frames(2)
	assert_true(edit.has_focus())


func test_first_navigation_key_restores_focus_after_it_was_lost():
	# 说明书合上后焦点可能落空:第一下 Tab/方向键/回车把焦点交回默认按钮
	add_child_autofree(Settlement.new("甲", Settlement.build_ranking(1, [2], STATS), false))
	await wait_process_frames(2)
	get_viewport().gui_release_focus()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.pressed = true
	get_viewport().push_input(tab)
	var focused := get_viewport().gui_get_focus_owner()
	assert_true(focused is Button)
	if focused is Button:
		assert_eq((focused as Button).text, "离开房间")


func _find_label(root: Node, text: String) -> Label:
	for node in root.find_children("*", "Label", true, false):
		if (node as Label).text == text:
			return node
	return null
