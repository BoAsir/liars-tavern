extends GutTest
# 炸弹猫 HUD(无头):按钮的亮灭、反应窗口条与「不行!」按钮、选目标 / 点名 / 塞回 / 给牌面板、偷看浮层、观战与特写时收起、
# 手牌条(快捷键数字、压缩、点选信号)、铭牌文案与结算面板的名次行;几个纯函数的文案。


const C := preload("res://src/core/bomb_cat/bomb_cat_card.gd")

var hud: BombCatHud


func before_each():
	hud = BombCatHud.new()
	add_child_autofree(hud)


func after_each():
	BombCatFaces.clear()


func test_play_and_draw_buttons_follow_set_actions():
	hud.set_actions(true, true, 2, true)
	assert_false(hud.play_button.disabled)
	assert_false(hud.draw_button.disabled)
	assert_eq(hud.play_button.text, "出牌 ×2")
	hud.set_actions(false, true, 1, true)
	assert_true(hud.play_button.disabled)
	assert_eq(hud.play_button.text, "出牌")
	hud.set_actions(false, false, 0, false)
	assert_true(hud.draw_button.disabled)


func test_window_panel_shows_the_bar_and_the_nope_button():
	hud.set_window("乙 打出「甩锅」", 0.5, true, true)
	assert_true(hud.window_panel.visible)
	assert_true(hud.nope_button.visible)
	assert_false(hud.nope_button.disabled)
	hud.set_window("乙 打出「甩锅」", 0.5, false, true)
	assert_true(hud.nope_button.disabled, "手里没有不行! 就按不动")
	hud.set_window("乙 打出「甩锅」", 0.5, false, false)
	assert_false(hud.nope_button.visible, "出局了不显示按钮")
	hud.set_window("", 0.0, false, false)
	assert_false(hud.window_panel.visible)


func test_window_hides_while_the_camera_is_away():
	hud.set_away_from_seat(true)
	hud.set_window("乙 打出「溜了」", 0.5, true, true)
	assert_false(hud.window_panel.visible)


func test_target_prompt_lists_candidates_and_emits_the_pid():
	watch_signals(hud)
	hud.show_targets([{"pid": 2, "name": "乙", "count": 3}, {"pid": 4, "name": "丁", "count": 1}], "讨要谁的牌?")
	assert_eq(hud.prompt_kind, BombCatHud.PROMPT_TARGET)
	var buttons := hud.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text.begins_with("丁"))
	assert_eq(buttons.size(), 1)
	buttons[0].pressed.emit()
	assert_signal_emitted_with_parameters(hud, "target_chosen", [4])
	hud.hide_prompt()
	assert_eq(hud.prompt_kind, BombCatHud.PROMPT_NONE)


func test_named_prompt_offers_every_card_but_the_bomb():
	watch_signals(hud)
	hud.show_named()
	var names: Array = hud.find_children("*", "Button", true, false).map(func(b: Button) -> String: return b.text)
	for id in BombCatScreenState.nameable_cards():
		assert_has(names, C.display_name(id))
	assert_does_not_have(names, C.display_name(C.BOMB))
	var fish: Button = hud.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "鱼干")[0]
	fish.pressed.emit()
	assert_signal_emitted_with_parameters(hud, "named_chosen", [C.SNACK_FISH])


func test_reinsert_slider_range_and_text():
	watch_signals(hud)
	hud.show_reinsert(12)
	assert_eq(hud.prompt_kind, BombCatHud.PROMPT_REINSERT)
	assert_eq(hud.reinsert_slider.min_value, 0.0)
	assert_eq(hud.reinsert_slider.max_value, 12.0, "0 = 顶 … 牌堆张数 = 底")
	assert_eq(hud.reinsert_value(), 0)
	hud.nudge_reinsert(1)
	assert_eq(hud.reinsert_value(), 1)
	hud.nudge_reinsert(-5)
	assert_eq(hud.reinsert_value(), 0, "不会小于 0")
	hud.reinsert_slider.value = 99
	assert_eq(hud.reinsert_value(), 12, "不会超过底")
	var ok: Button = hud.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "就放这儿")[0]
	ok.pressed.emit()
	assert_signal_emitted_with_parameters(hud, "reinsert_confirmed", [12])
	assert_true(hud.play_button.modulate.a < 0.01, "塞回时出牌按钮让开")


func test_reinsert_text():
	assert_string_contains(BombCatHud.reinsert_text(0, 10), "第 1 张")
	assert_string_contains(BombCatHud.reinsert_text(0, 10), "最上面")
	assert_string_contains(BombCatHud.reinsert_text(4, 10), "第 5 张")
	assert_string_contains(BombCatHud.reinsert_text(10, 10), "最底下")
	assert_string_contains(BombCatHud.reinsert_text(0, 0), "空")


func test_give_prompt_and_peek_overlay():
	hud.show_give("乙")
	assert_eq(hud.prompt_kind, BombCatHud.PROMPT_GIVE)
	var texts: Array = hud.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_has(texts, "乙 向你讨要一张牌")
	watch_signals(hud)
	hud.show_peek([C.SKIP, C.BOMB, C.NOPE])
	assert_true(hud.is_peek_open())
	var ok: Button = hud.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == "知道了")[0]
	ok.pressed.emit()
	assert_signal_emitted(hud, "peek_dismissed")
	hud.hide_peek()
	assert_false(hud.is_peek_open())


func test_spectating_swaps_the_hand_for_a_banner():
	hud.set_spectating(true)
	assert_false(hud.strip.is_visible_in_tree())
	assert_false(hud.play_button.is_visible_in_tree())
	hud.set_spectating(false)
	assert_true(hud.strip.is_visible_in_tree())


func test_info_and_turn_texts():
	hud.set_info(17, 2, 3, "轮到 乙", "你:手牌 5 张")
	var texts: Array = hud.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	assert_has(texts, "牌堆 17 张")
	assert_has(texts, "炸弹还剩 2 / 3")
	assert_eq(BombCatHud.turn_info_text("乙", false, 3, "turn"), "轮到 乙 · 还要走 3 回合")
	assert_eq(BombCatHud.turn_info_text("我", true, 1, "turn"), "轮到 你")
	assert_string_contains(BombCatHud.turn_info_text("乙", false, 1, "reinsert"), "塞回")
	assert_eq(BombCatHud.turn_info_text("", false, 1, "turn"), "")


func test_window_text():
	var names := func(pid): return {1: "我", 2: "乙", 3: "丙"}.get(pid, "?")
	assert_eq(BombCatHud.window_text({"pid": 2, "kind": C.BEG, "target": 3, "nopes": 0}, names), "乙 打出「讨要」 → 丙")
	assert_string_contains(BombCatHud.window_text({"pid": 2, "kind": "pair", "target": 1, "nopes": 1}, names), "作废")
	assert_string_contains(BombCatHud.window_text({"pid": 2, "kind": "triple", "named": C.DEFUSE, "target": 1, "nopes": 2}, names), "又生效")
	assert_string_contains(BombCatHud.window_text({"pid": 2, "kind": "triple", "named": C.DEFUSE, "target": 1, "nopes": 0}, names), "拆弹")
	assert_eq(BombCatHud.window_text({}, names), "")


func test_hand_strip_numbers_cards_and_emits_clicks():
	watch_signals(hud)
	hud.set_hand([C.SKIP, C.NOPE, C.SNACK_FISH], {1: true}, true)
	assert_eq(hud.strip.card_count(), 3)
	assert_eq(hud.strip.ids(), [C.SKIP, C.NOPE, C.SNACK_FISH])
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	hud.strip.get_child(2).gui_input.emit(click)
	assert_signal_emitted_with_parameters(hud, "card_clicked", [2])


func test_hand_strip_compresses_long_hands():
	assert_eq(BombCatHandStrip.layout_step(5), BombCatHandStrip.CARD_SIZE.x + BombCatHandStrip.GAP)
	for count in [9, 14, 20]:
		assert_lte(BombCatHandStrip.strip_width(count), BombCatHandStrip.MAX_WIDTH + 0.01, "%d 张不超宽" % count)
	assert_lt(BombCatHandStrip.layout_step(20), BombCatHandStrip.CARD_SIZE.x, "很多张时互相压住")


func test_nameplate_texts():
	assert_eq(BombCatNameplate.info_text(5, true, false, false, 1), "手牌 5")
	assert_eq(BombCatNameplate.info_text(5, true, false, true, 3), "手牌 5 · 还要走 3 回合")
	assert_eq(BombCatNameplate.info_text(0, false, true, false, 1), "炸飞了")
	assert_eq(BombCatNameplate.info_text(0, false, false, false, 1), "离开了")


func test_settlement_rows_and_buttons():
	var rows := [{"pid": 2, "name": "乙", "place": 1, "fate": "winner"}, {"pid": 1, "name": "我", "place": 2, "fate": "exploded"},
		{"pid": 3, "name": "丙", "place": 3, "fate": "left"}]
	var panel := BombCatSettlement.new("乙", rows, false, true)
	add_child_autofree(panel)
	var texts: Array = panel.find_children("*", "Label", true, false).map(func(l: Label) -> String: return l.text)
	for want in ["乙", "第 1 名", "活到最后", "被炸飞", "断线离开"]:
		assert_has(texts, want)
	watch_signals(panel)
	assert_eq(panel.default_button().text, "再来一局", "房主默认焦点在「再来一局」")
	panel.default_button().pressed.emit()
	assert_signal_emitted(panel, "lobby_pressed")
	var guest := BombCatSettlement.new("乙", rows, true, false)
	add_child_autofree(guest)
	assert_eq(guest.default_button().text, "离开房间")
