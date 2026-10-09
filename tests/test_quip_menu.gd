extends GutTest
# 快捷对话的九宫格与控制器:9 个按钮按审定文案排、数字键映射、冷却中按钮变灰、选了就收起并进入冷却。


func test_menu_has_the_nine_lines_in_order():
	var menu := QuipMenu.new()
	add_child_autofree(menu)
	assert_eq(menu.button_count(), Quips.LINES.size())
	for i in Quips.LINES.size():
		assert_eq(menu.button_text(i), Quips.LINES[i])
	assert_false(menu.is_open(), "默认收起")


func test_menu_fits_the_screen_and_stays_under_the_top_buttons():
	var holder := Control.new()
	holder.size = Vector2(1280, 720)
	add_child_autofree(holder)
	var menu := QuipMenu.new()
	holder.add_child(menu)
	menu.open()
	await wait_process_frames(3)
	assert_true(menu.position.x >= 0.0, "左缘 %s" % menu.position.x)
	assert_true(menu.position.x + menu.size.x <= 1280.0 - QuipMenu.RIGHT_MARGIN + 0.5)
	assert_true(menu.position.y >= QuipMenu.TOP - 0.5)
	assert_true(menu.position.y + menu.size.y <= 720.0 / 2.0, "只占上半屏:%s" % (menu.position.y + menu.size.y))
	for button in menu._buttons:
		var needed := button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			button.get_theme_font_size("font_size")).x
		assert_true(button.size.x >= needed, "整句显示:%s" % button.text)


func test_cooldown_greys_the_buttons_and_says_how_long():
	assert_eq(QuipMenu.hint_text(0.0), QuipMenu.HINT)
	assert_eq(QuipMenu.hint_text(2.2), "3 秒后可以再说")
	var menu := QuipMenu.new()
	add_child_autofree(menu)
	menu.set_cooldown(1.0)
	assert_true(menu._buttons.all(func(b: Button) -> bool: return b.disabled))
	menu.set_cooldown(0.0)
	assert_true(menu._buttons.all(func(b: Button) -> bool: return not b.disabled))


func test_digit_keys_map_to_lines():
	assert_eq(QuipController.digit_index(KEY_1), 0)
	assert_eq(QuipController.digit_index(KEY_9), 8)
	assert_eq(QuipController.digit_index(KEY_KP_5), 4)
	assert_eq(QuipController.digit_index(KEY_0), -1)
	assert_eq(QuipController.digit_index(KEY_T), -1)


func test_choosing_closes_the_menu_and_starts_the_cooldown():
	var quip := QuipController.new(null, 1)
	add_child_autofree(quip)
	quip.menu.open()
	assert_true(quip.choose(2))
	assert_false(quip.menu.is_open())
	assert_gt(quip.cooldown_left(), Quips.COOLDOWN - 0.5)
	assert_false(quip.choose(3), "冷却中不能再说")
	assert_false(quip.choose(42), "编号不合法")
