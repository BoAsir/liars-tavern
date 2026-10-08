extends GutTest
# 散局结算(规格 §6.5):按盈亏排名、正负号与千分位、已离开标灰、超过 8 行能滚动、只发信号。


func _results() -> Array:
	return [
		{"pid": 2, "name": "乙", "stack": 2360, "buyins": 1, "net": 360, "left": false},
		{"pid": 1, "name": "甲", "stack": 5240, "buyins": 2, "net": 1240, "left": false},
		{"pid": 3, "name": "丙", "stack": 0, "buyins": 1, "net": -2000, "left": true},
		{"pid": 4, "name": "丁", "stack": 2400, "buyins": 1, "net": 400, "left": false},
	]


func _column(ranking: Array, key: String) -> Array:
	return ranking.map(func(row): return row[key])


func test_ranking_sorts_by_net_and_numbers_the_places():
	var ranking := PokerSettlement.rank(_results())
	assert_eq(_column(ranking, "name"), ["甲", "丁", "乙", "丙"])
	assert_eq(_column(ranking, "place"), [1, 2, 3, 4])
	assert_eq(_column(ranking, "net"), [1240, 400, 360, -2000])


func test_ranking_is_stable_for_equal_nets_and_does_not_modify_the_input():
	var results := [{"name": "A", "net": 0}, {"name": "B", "net": 0}, {"name": "C", "net": 0}]
	assert_eq(_column(PokerSettlement.rank(results), "name"), ["A", "B", "C"])
	assert_false(results[0].has("place"))


func test_ranking_tolerates_junk_from_the_network():
	var ranking := PokerSettlement.rank([{"name": 5, "net": "x", "stack": null, "buyins": 1.5, "left": "yes"}, "junk", 3])
	assert_eq(ranking.size(), 1)
	assert_eq(ranking[0]["name"], "?")
	assert_eq(ranking[0]["net"], 0)
	assert_eq(ranking[0]["stack"], 0)
	assert_eq(ranking[0]["buyins"], 0)
	assert_eq(ranking[0]["left"], false)


func test_signed_amounts_have_a_sign_and_thousands_separators():
	assert_eq(ChipText.signed(1240), "+1,240")
	assert_eq(ChipText.signed(-360), "-360")
	assert_eq(ChipText.signed(0), "0")
	assert_eq(ChipText.signed(-1234567), "-1,234,567")
	assert_eq(ChipText.format(1000), "1,000")
	assert_eq(ChipText.format(999), "999")


func test_rows_show_net_with_colour_and_mark_players_who_left():
	var panel: PokerSettlement = add_child_autofree(PokerSettlement.new(_results(), false))
	var win := _find_label(panel, "+1,240")
	var loss := _find_label(panel, "-2,000")
	assert_not_null(win)
	assert_not_null(loss)
	assert_eq(win.get_theme_color("font_color"), UiTheme.TRUTH)
	assert_eq(loss.get_theme_color("font_color"), UiTheme.LIE)
	assert_not_null(_find_label(panel, PokerSettlement.LEFT_TEXT))
	assert_not_null(_find_label(panel, "第 1 名"))
	assert_not_null(_find_label(panel, "5,240"))
	assert_not_null(_find_label(panel, "2 次"))


func test_visible_rows_are_capped_at_eight_so_longer_lists_scroll():
	assert_eq(PokerSettlement.visible_rows(3), 3)
	assert_eq(PokerSettlement.visible_rows(8), 8)
	assert_eq(PokerSettlement.visible_rows(12), 8)
	var many := []
	for i in 12:
		many.append({"pid": i, "name": "P%d" % i, "stack": 2000, "buyins": 1, "net": 0, "left": i % 2 == 0})
	var panel: PokerSettlement = add_child_autofree(PokerSettlement.new(many, true))
	await wait_process_frames(3)
	assert_eq(panel._rows.get_child_count(), 12)
	assert_true(panel._scroll.size.y < panel._rows.size.y, "12 行放不下:内容比滚动区高,能滚动")
	assert_true(panel._scroll.size.y <= PokerSettlement.MAX_VISIBLE_ROWS * PokerSettlement.ROW_HEIGHT + 1.0)


func test_buttons_depend_on_being_host_and_only_emit_signals():
	var host: PokerSettlement = add_child_autofree(PokerSettlement.new(_results(), true))
	watch_signals(host)
	assert_eq(host._primary.text, PokerSettlement.HOST_TEXT)
	host._primary.pressed.emit()
	assert_signal_emitted(host, "lobby_pressed")
	var guest: PokerSettlement = add_child_autofree(PokerSettlement.new(_results(), false))
	watch_signals(guest)
	assert_eq(guest._primary.text, PokerSettlement.GUEST_TEXT)
	guest._primary.pressed.emit()
	assert_signal_emitted(guest, "leave_pressed")


func _find_label(root: Node, text: String) -> Label:
	for node in root.find_children("*", "Label", true, false):
		if (node as Label).text == text:
			return node
	return null
