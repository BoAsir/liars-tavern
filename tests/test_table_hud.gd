extends GutTest
# 牌桌 HUD:出牌/质疑按钮不抢键盘焦点;自己的气泡在出牌按钮上方居中;弹出动画的支点随布局更新。


var hud: TableHud


func before_each():
	hud = TableHud.new()
	add_child_autofree(hud)


func test_action_buttons_never_take_keyboard_focus():
	# 鼠标点过后焦点若留在按钮上,之后按回车/空格会在松开时再按一次它(误发质疑或出牌)
	assert_eq(hud._play_button.focus_mode, Control.FOCUS_NONE)
	assert_eq(hud._challenge_button.focus_mode, Control.FOCUS_NONE)


func test_my_bubble_replaces_the_previous_one_and_ignores_the_mouse():
	hud.my_bubble("2 张「Q」")
	hud.my_bubble("骗子!", UiTheme.BLOOD)
	var bubbles := hud._bubble_anchor.get_children()
	assert_eq(bubbles.size(), 1)
	assert_eq((bubbles[0] as Control).mouse_filter, Control.MOUSE_FILTER_IGNORE, "气泡不能挡住下面手牌的点击")
	await wait_process_frames(1)   # 被顶掉的旧气泡帧末才真正释放


func test_my_bubble_is_centred_above_the_action_row():
	hud.my_bubble("3 张「K」")
	await wait_process_frames(3)
	var anchor: Control = hud._bubble_anchor
	var bubble: Control = anchor.get_child(0)
	assert_gt(bubble.size.x, 40.0, "气泡应已完成布局")
	assert_almost_eq(bubble.position.x + bubble.size.x / 2.0, anchor.size.x / 2.0, 1.0)
	assert_true(bubble.position.y + bubble.size.y + SpeechBubble.TAIL_LENGTH <= anchor.size.y + 0.5,
		"气泡连同小三角都应在按钮行上方")


func test_announce_and_turn_banner_scale_around_their_centre():
	hud.announce("第 1 局", UiTheme.BRASS_BRIGHT, "目标牌 ·「Q」")
	hud.set_turn("轮到你了", true)
	await wait_process_frames(3)
	assert_eq(hud._announce_box.pivot_offset, hud._announce_box.size / 2.0)
	assert_eq(hud._turn_panel.pivot_offset, hud._turn_panel.size / 2.0)
	hud.set_turn("等待 一个名字很长的客人 行动…", false)
	await wait_process_frames(3)
	assert_eq(hud._turn_panel.pivot_offset, hud._turn_panel.size / 2.0)


func test_speech_bubble_pops_from_its_tail_after_layout():
	var holder := Control.new()
	add_child_autofree(holder)
	var bubble := SpeechBubble.new("2 张「Q」")
	holder.add_child(bubble)
	await wait_process_frames(2)
	assert_gt(bubble.size.x, 40.0)
	assert_eq(bubble.pivot_offset, Vector2(bubble.size.x / 2.0, bubble.size.y))
	assert_eq(bubble.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_eliminated_player_keeps_action_row_hidden_after_camera_returns():
	# 出局后镜头每次离开/回座都会切 set_away_from_seat,按钮行必须一直藏着
	hud.set_actions_visible(false)
	hud.set_away_from_seat(true)
	hud.set_away_from_seat(false)
	assert_false(hud._action_row.visible)
	assert_false(hud._hint.visible)


func test_alive_player_action_row_hides_while_camera_is_away_and_returns():
	hud.set_actions_visible(true)
	hud.set_away_from_seat(true)
	assert_false(hud._action_row.visible, "特写时收起按钮行,不挡角色")
	hud.set_away_from_seat(false)
	assert_true(hud._action_row.visible)
	assert_true(hud._hint.visible)


func test_clear_my_bubble_removes_pending_bubbles():
	hud.my_bubble("骗子!")
	hud.clear_my_bubble()
	assert_eq(hud._bubble_anchor.get_child_count(), 0)


func test_idle_hint_lists_both_chat_keys_and_the_tomato_on_g():
	# 九宫格快捷对话 T、丢番茄 G、动物叫声快捷语 Q 三个键都写在提示行里
	hud.set_actions(false, false, 0, false)
	assert_string_contains(hud._hint.text, "T 对话")
	assert_string_contains(hud._hint.text, "G 丢番茄")
	assert_string_contains(hud._hint.text, "Q 快捷语")
	assert_false(hud._hint.text.contains("T 丢番茄"))
