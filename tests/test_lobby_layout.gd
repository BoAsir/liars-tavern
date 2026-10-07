extends GutTest
# 等待厅布局(德州 8 人也要在 1280×720 里放下,规格 §3.2):玩家列表最多露出 4 行、其余在列表里滚动;
# 3D 铭牌单行「名字 ✓」不超过 130×44(8 人围坐时两行的铭牌会互相压住)。


const LobbyScreen := preload("res://src/ui/lobby/lobby.gd")
const LONG_NAME := "小明明明明明明明明明明明"   # 昵称上限 12 字


func test_list_shows_every_row_up_to_the_limit():
	assert_eq(LobbyScreen.visible_list_height([44.0, 58.0, 58.0], 8.0, 4), 44.0 + 58.0 + 58.0 + 2 * 8.0)
	assert_eq(LobbyScreen.visible_list_height([], 8.0, 4), 0.0)


func test_list_beyond_the_limit_scrolls_instead_of_growing():
	var rows := [44.0, 58.0, 58.0, 58.0, 58.0, 58.0, 58.0, 58.0]
	assert_eq(LobbyScreen.visible_list_height(rows, 8.0, 4), 44.0 + 3 * 58.0 + 3 * 8.0)
	assert_eq(LobbyScreen.LIST_VISIBLE_ROWS, 4, "骗子酒馆满员 4 人时列表不滚动")


func _plate_texts(plate: Control) -> Array:
	return plate.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)


func test_nameplate_is_one_short_line():
	for pname in ["阿花", LONG_NAME]:
		for ready in [true, false]:
			var plate: Control = LobbyScreen.nameplate(pname, ready)
			add_child_autofree(plate)
			var size := plate.get_combined_minimum_size()
			assert_lte(size.x, LobbyScreen.PLATE_MAX.x, "%s ready=%s" % [pname, ready])
			assert_lte(size.y, LobbyScreen.PLATE_MAX.y, "%s ready=%s" % [pname, ready])
			assert_eq(plate.find_children("*", "Label", true, false).size(), 2 if ready else 1, "单行:名字(+ ✓)")


func test_nameplate_marks_ready_players():
	var ready: Control = autofree(LobbyScreen.nameplate("阿花", true))
	assert_eq(_plate_texts(ready), ["阿花", "✓"])
	var waiting: Control = autofree(LobbyScreen.nameplate("阿花", false))
	assert_eq(_plate_texts(waiting), ["阿花"])


func test_short_names_get_their_full_width():
	# 名字一栏按文字宽度给足(只有超长昵称才省略号截断):不能缩成只剩「…」
	var plate: Control = LobbyScreen.nameplate("阿花", true)
	add_child_autofree(plate)
	var name_label: Label = plate.find_children("*", "Label", true, false)[0]
	var text_width := name_label.get_theme_font("font").get_string_size("阿花", HORIZONTAL_ALIGNMENT_LEFT, -1,
		name_label.get_theme_font_size("font_size")).x
	assert_gt(text_width, 0.0)
	assert_gte(name_label.get_combined_minimum_size().x, text_width - 0.5)


func test_row_buttons_keep_rows_as_short_as_the_name():
	# 名单行里的「请出」用主题样式但收小内边距:有按钮的行和没按钮的行一样高,4 行露出的高度省下来
	var button: Button = autofree(LobbyScreen.row_button("请出"))
	for state in LobbyScreen.ROW_BUTTON_STATES:
		var box: StyleBox = button.get_theme_stylebox(state)
		assert_true(button.has_theme_stylebox_override(state), state)
		assert_eq([box.content_margin_left, box.content_margin_top], [LobbyScreen.ROW_BUTTON_PADDING.x,
			LobbyScreen.ROW_BUTTON_PADDING.y], state)
	assert_eq(button.focus_mode, Control.FOCUS_ALL, "仍能用键盘请出")
