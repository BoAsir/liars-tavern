extends GutTest
# 德州 HUD(规格 §6.1、§6.3、§6.4、§2.8):文案纯函数、底部区域按状态切换、输光提示带倒计时且不模态、
# 2D 小牌条(mipmap 过滤、牌面生成完刷新、坏数据丢掉)、铭牌文案与高亮、1280×720 下的布局预算。


const SCREEN := Vector2(1280, 720)
const ME := 1

var holder: Control
var hud: PokerHud


func before_each():
	holder = Control.new()
	holder.size = SCREEN
	add_child_autofree(holder)
	hud = PokerHud.new()
	holder.add_child(hud)


func _card(rank: int, suit: int) -> int:
	return PokerCard.make(rank, suit)


func _player(status: String, overrides := {}) -> Dictionary:
	var p := {"pid": ME, "name": "我", "stack": 1840, "bet": 200, "committed": 200, "status": status, "left": false,
		"buyins": 1, "net": 240, "shown": []}
	p.merge(overrides, true)
	return p


# —— 文案 ——

func test_header_and_pot_summary_text():
	assert_eq(PokerHud.title_text(GameMode.HOLDEM, [10, 20], 3), "德州·长牌 · 盲注 10/20 · 第 3 手")
	assert_eq(PokerHud.title_text(GameMode.SHORT_DECK, [10, 20], 0), "德州·短牌 · 盲注 10/20 · 等待开局")
	assert_eq(PokerHud.pot_summary([{"amount": 2400}, {"amount": 840}]), "底池 3,240 · 边池 ×1")
	assert_eq(PokerHud.pot_summary([{"amount": 60}]), "底池 60")
	assert_eq(PokerHud.pot_summary([]), "底池 0")
	assert_eq(PokerHud.pot_summary([{"amount": "x"}, 7]), "底池 0", "视图不可信:坏数据当 0")


func test_my_status_text():
	assert_eq(PokerHud.my_status_text(_player("active")), "筹码 1,840 · 盈亏 +240 · 领取 1 次")
	assert_eq(PokerHud.my_status_text(_player("busted", {"stack": 0, "net": -4000, "buyins": 2})), "筹码 0 · 盈亏 -4,000 · 领取 2 次")


func test_bottom_mode_follows_my_status_then_the_showdown():
	assert_eq(PokerHud.bottom_mode_for(_player("busted"), false), PokerHud.BOTTOM_BUST)
	assert_eq(PokerHud.bottom_mode_for(_player("spectating"), false), PokerHud.BOTTOM_SPECTATE)
	assert_eq(PokerHud.bottom_mode_for(_player("away"), false), PokerHud.BOTTOM_AWAY)
	assert_eq(PokerHud.bottom_mode_for(_player("waiting"), true), PokerHud.BOTTOM_WAITING, "等待下一手只看 status")
	assert_eq(PokerHud.bottom_mode_for(_player("active"), true), PokerHud.BOTTOM_SHOWDOWN)
	assert_eq(PokerHud.bottom_mode_for(_player("folded"), true), PokerHud.BOTTOM_SHOWDOWN)
	assert_eq(PokerHud.bottom_mode_for(_player("active"), false), PokerHud.BOTTOM_BET)
	assert_eq(PokerHud.bottom_mode_for(_player("folded"), false), PokerHud.BOTTOM_BET, "弃牌后仍看别人的回合横幅")
	assert_eq(PokerHud.bottom_mode_for({}, false), PokerHud.BOTTOM_NONE, "还没进座位表的迟到者")


# —— 底部区域 ——

func test_bust_prompt_is_not_modal_and_counts_down():
	hud.set_bottom_mode(PokerHud.BOTTOM_BUST)
	hud.set_bust_countdown(4.0, 6.0)
	assert_true(hud.prompts.visible)
	assert_true(hud.prompts._ring.visible)
	assert_almost_eq(hud.prompts._ring.remaining, 4.0, 0.001)
	assert_eq(hud.prompts.mouse_filter, Control.MOUSE_FILTER_IGNORE, "提示不挡住右上的「散局」")
	assert_true(hud.prompts._rebuy_button.visible)
	assert_true(hud.prompts._spectate_button.visible)
	for node in hud.prompts.find_children("*", "Button", true, false):
		assert_eq((node as Button).focus_mode, Control.FOCUS_NONE, "正在按的空格/回车不会误触")


func test_prompt_buttons_only_emit_signals():
	watch_signals(hud)
	hud.set_bottom_mode(PokerHud.BOTTOM_BUST)
	hud.prompts._rebuy_button.pressed.emit()
	assert_signal_emitted(hud, "rebuy_pressed")
	hud.prompts._spectate_button.pressed.emit()
	assert_signal_emitted(hud, "spectate_pressed")
	hud.set_bottom_mode(PokerHud.BOTTOM_AWAY)
	hud.prompts._sit_in_button.pressed.emit()
	assert_signal_emitted(hud, "sit_in_pressed")


func test_escape_chooses_spectating_only_while_the_bust_prompt_is_up():
	watch_signals(hud)
	hud.set_bottom_mode(PokerHud.BOTTOM_BET)
	assert_false(hud.handle_cancel())
	hud.set_bottom_mode(PokerHud.BOTTOM_BUST)
	assert_true(hud.handle_cancel())
	assert_signal_emitted(hud, "spectate_pressed")


func test_each_bottom_mode_shows_one_thing():
	hud.set_bottom_mode(PokerHud.BOTTOM_BET)
	assert_true(hud.controls.visible)
	assert_false(hud.prompts.visible)
	assert_false(hud.showdown.visible)
	hud.set_bottom_mode(PokerHud.BOTTOM_SHOWDOWN)
	assert_true(hud.showdown.visible)
	assert_false(hud.controls.visible)
	for mode in [PokerHud.BOTTOM_SPECTATE, PokerHud.BOTTOM_WAITING, PokerHud.BOTTOM_AWAY]:
		hud.set_bottom_mode(mode)
		assert_true(hud.prompts.visible, mode)
		assert_false(hud.controls.visible, mode)
	assert_eq(hud.prompts._message.text, PokerPrompts.MESSAGES[PokerHud.BOTTOM_AWAY])
	assert_true(hud.prompts._sit_in_button.visible)
	assert_false(hud.prompts._rebuy_button.visible)
	hud.set_bottom_mode(PokerHud.BOTTOM_NONE)
	assert_false(hud.prompts.visible)
	assert_false(hud.controls.visible)


func test_spectator_prompt_offers_chips_regardless_of_stack():
	hud.set_bottom_mode(PokerHud.BOTTOM_SPECTATE)
	assert_eq(hud.prompts._rebuy_button.text, PokerPrompts.SEAT_TEXT)
	assert_true(hud.prompts._rebuy_button.visible)
	assert_false(hud.prompts._spectate_button.visible)
	assert_false(hud.prompts._ring.visible)


# —— 2D 小牌条 ——

func test_card_strip_uses_mipmapped_filtering_and_drops_junk():
	var strip := CardStrip.new(5, Vector2(36, 50))
	add_child_autofree(strip)
	strip.set_cards([_card(12, 1), "junk", _card(9, 1), 999, null])
	assert_eq(strip.cards(), [_card(12, 1), _card(9, 1)])
	var faces := strip.find_children("*", "TextureRect", true, false)
	assert_eq(faces.size(), 5, "固定 5 个槽位")
	for face in faces:
		assert_eq((face as TextureRect).texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS)
		assert_eq((face as TextureRect).custom_minimum_size, Vector2(36, 50))
	assert_true(faces[0].visible)
	assert_true(faces[1].visible)
	assert_false(faces[2].visible, "空槽位只画框")


func test_card_strip_without_fixed_slots_grows_with_the_cards():
	var strip := CardStrip.new(0, Vector2(30, 42))
	add_child_autofree(strip)
	strip.set_cards([_card(14, 0), _card(13, 1)])
	assert_eq(strip.find_children("*", "TextureRect", true, false).size(), 2)
	strip.set_cards([])
	assert_eq(strip.find_children("*", "TextureRect", true, false).size(), 0)


func test_card_strip_refreshes_textures_when_poker_faces_finish_building():
	PokerFaces.clear()
	var strip := CardStrip.new(0, Vector2(30, 42))
	add_child_autofree(strip)
	strip.set_cards([_card(14, 0)])
	var face: TextureRect = strip.find_children("*", "TextureRect", true, false)[0]
	var placeholder := face.texture
	await PokerFaces.build(strip)
	assert_true(PokerFaces.is_built())
	assert_ne(face.texture, placeholder, "生成完成后重新取纹理")
	assert_eq(face.texture, PokerFaces.texture(_card(14, 0)))
	PokerFaces.clear()


func test_card_strip_highlight_dims_the_other_cards():
	var strip := CardStrip.new(5, Vector2(36, 50))
	add_child_autofree(strip)
	strip.set_cards([_card(12, 1), _card(9, 1), _card(4, 0)])
	strip.highlight([_card(12, 1)])
	var faces := strip.find_children("*", "TextureRect", true, false)
	assert_eq((faces[0] as TextureRect).modulate, Color.WHITE)
	assert_lt((faces[1] as TextureRect).modulate.v, 1.0)
	strip.highlight([])
	assert_eq((faces[1] as TextureRect).modulate, Color.WHITE)


# —— 铭牌 ——

func test_nameplate_status_text():
	assert_eq(PokerNameplate.status_text(_player("active", {"bet": 40})), "下注 40")
	assert_eq(PokerNameplate.status_text(_player("active", {"bet": 0})), "")
	assert_eq(PokerNameplate.status_text(_player("folded")), "弃牌")
	assert_eq(PokerNameplate.status_text(_player("allin")), "全下")
	assert_eq(PokerNameplate.status_text(_player("spectating")), "观战")
	assert_eq(PokerNameplate.status_text(_player("waiting")), "等待下一手")
	assert_eq(PokerNameplate.status_text(_player("busted")), "输光")
	assert_eq(PokerNameplate.status_text(_player("away")), "离座")
	assert_eq(PokerNameplate.status_text(_player("allin", {"left": true})), "已离开")
	assert_eq(PokerNameplate.status_text({"status": 7}), "")


func test_nameplate_badges():
	var pub := {"button": 4, "sb": 5, "bb": 6}
	assert_eq(PokerNameplate.badge_for(4, pub), "D")
	assert_eq(PokerNameplate.badge_for(5, pub), "小盲")
	assert_eq(PokerNameplate.badge_for(6, pub), "大盲")
	assert_eq(PokerNameplate.badge_for(7, pub), "")
	assert_eq(PokerNameplate.badge_for(4, {"button": 4, "sb": 4, "bb": 6}), "D·小盲", "单挑:按钮下小盲")
	assert_eq(PokerNameplate.badge_for(4, {}), "")


func test_nameplate_highlights_the_actor_and_dims_folded_or_spectating():
	var plate := PokerNameplate.new("一个名字非常非常长的客人")
	add_child_autofree(plate)
	plate.set_info(_player("active", {"bet": 40}), "D", true)
	assert_eq(plate._style.border_color, UiTheme.BRASS_BRIGHT)
	assert_eq(plate.modulate, Color.WHITE)
	plate.set_info(_player("folded"), "", false)
	assert_lt(plate.modulate.v, 1.0)
	assert_true(PokerNameplate.is_dimmed(_player("spectating")))
	assert_true(PokerNameplate.is_dimmed(_player("active", {"left": true})))
	assert_false(PokerNameplate.is_dimmed(_player("waiting")))
	await wait_process_frames(2)
	assert_true(plate.size.x <= PokerNameplate.MAX_SIZE.x, "超长名字省略:%s" % plate.size)
	assert_true(plate.size.y <= PokerNameplate.MAX_SIZE.y, "两行:%s" % plate.size)


# —— 布局预算(1280×720)——

func _fill() -> void:
	hud.set_header(GameMode.SHORT_DECK, [10, 20], 12)
	hud.set_pots([{"amount": 2400}, {"amount": 860}])
	hud.set_board([_card(12, 1), _card(9, 1), _card(4, 0), _card(13, 3), _card(2, 2)])
	hud.set_host(true)
	hud.set_my_status("一个名字非常非常长的客人", _player("active"))
	hud.set_my_hole([_card(14, 0), _card(13, 1)])
	hud.set_my_best("两对 · K 和 Q")
	for i in 6:
		hud.log_event("第 %d 条很长很长的日志:某某 加注到 1,240,某某 跟注" % i)


func test_top_left_panel_fits_its_budget():
	_fill()
	await wait_process_frames(3)
	var panel := hud.header_panel
	assert_true(panel.size.x <= PokerHud.TOP_LEFT_MAX.x, "宽 %s" % panel.size)
	assert_true(panel.size.y <= PokerHud.TOP_LEFT_MAX.y, "高 %s" % panel.size)
	assert_true(panel.position.y + panel.size.y <= PokerHud.TOP_LEFT_BOTTOM, "底边 %s" % (panel.position.y + panel.size.y))
	for face in hud.board_strip.find_children("*", "TextureRect", true, false):
		assert_true((face as TextureRect).size.x >= 36.0 and (face as TextureRect).size.y >= 50.0, "公共牌 ≥ 36×50")


func test_bottom_centre_fits_its_budget_in_every_mode():
	_fill()
	var pub := {"actions": {"pid": ME, "to_call": 20, "call_amount": 20, "can_check": false, "can_raise": true, "can_allin": true,
		"min_raise_to": 40, "max_raise_to": 1000}, "current_bet": 20, "pots": [{"amount": 60}], "players": [_player("active")]}
	hud.controls.update(pub, ME)
	hud.set_turn("轮到你了", true)
	hud.set_countdown(30.0, 30.0, true)
	var entries := []
	for i in 8:
		entries.append({"name": "第 %d 位名字很长的客人" % i, "cards": [_card(14, 0), _card(13, 1)], "hand_name": "两对 · K 和 Q"})
	hud.set_showdown(entries)
	for mode in [PokerHud.BOTTOM_BET, PokerHud.BOTTOM_SHOWDOWN, PokerHud.BOTTOM_BUST, PokerHud.BOTTOM_SPECTATE,
			PokerHud.BOTTOM_WAITING, PokerHud.BOTTOM_AWAY]:
		hud.set_bottom_mode(mode)
		await wait_process_frames(3)
		var box := hud.bottom_box
		assert_true(box.size.x <= PokerHud.BOTTOM_MAX.x, "%s 宽 %s" % [mode, box.size])
		assert_true(box.size.y <= PokerHud.BOTTOM_MAX.y, "%s 高 %s" % [mode, box.size])
		assert_true(box.position.x >= PokerHud.BOTTOM_LEFT and box.position.x + box.size.x <= PokerHud.BOTTOM_RIGHT,
			"%s 横向 %s" % [mode, box.position])
		assert_true(box.position.y >= PokerHud.BOTTOM_TOP_MIN, "%s 顶边 %s" % [mode, box.position.y])
		assert_true(box.position.y + box.size.y <= SCREEN.y, "%s 底边" % mode)


func test_showdown_strip_shows_at_most_two_rows_of_four():
	var entries := []
	for i in 9:
		entries.append({"name": "P%d" % i, "cards": [_card(14, 0), _card(13, 1)], "hand_name": "高牌 · A"})
	hud.set_showdown(entries)
	assert_eq(hud.showdown._grid.get_child_count(), 8)
	assert_eq(hud.showdown._grid.columns, 4)
	hud.set_showdown([{"name": "P", "cards": "junk", "hand_name": 3}, "junk"])
	assert_eq(hud.showdown._grid.get_child_count(), 1, "坏条目丢掉,坏字段当空")
	for face in hud.showdown.find_children("*", "TextureRect", true, false):
		assert_true((face as TextureRect).custom_minimum_size.x >= 30.0 and (face as TextureRect).custom_minimum_size.y >= 42.0)


func test_left_column_and_log_stay_in_their_lanes():
	_fill()
	await wait_process_frames(3)
	var left := hud.my_panel
	assert_true(left.position.x >= PokerHud.MARGIN.x - 0.5, "左下从 x 24 起")
	assert_true(left.position.x + left.size.x <= PokerHud.LEFT_RIGHT_EDGE, "左下 ≤ 300 宽:%s" % (left.position.x + left.size.x))
	var log := hud.log_box
	assert_true(log.position.x >= PokerHud.LOG_LEFT_EDGE - 0.5, "日志从 x 956 起:%s" % log.position.x)
	assert_true(log.position.x + log.size.x <= SCREEN.x - PokerHud.MARGIN.x + 0.5)
	assert_eq(log.get_child_count(), PokerHud.LOG_LINES)


func test_end_button_is_only_for_the_host_and_greys_out_once_requested():
	assert_false(hud.end_button.visible)
	hud.set_host(true)
	assert_true(hud.end_button.visible)
	assert_eq(hud.end_button.focus_mode, Control.FOCUS_NONE)
	watch_signals(hud)
	hud.end_button.pressed.emit()
	assert_signal_emitted(hud, "end_pressed")
	hud.set_ending(true)
	assert_true(hud.end_button.disabled)
	assert_eq(hud.end_button.text, PokerHud.ENDING_TEXT)
	assert_eq(hud.rules_button.focus_mode, Control.FOCUS_NONE)


func test_my_hole_cards_are_big_and_the_best_hand_is_shown():
	hud.set_my_hole([_card(14, 0), _card(13, 1)])
	hud.set_my_best("两对 · K 和 Q")
	assert_eq(hud.my_strip.cards(), [_card(14, 0), _card(13, 1)])
	assert_eq(hud._best_label.text, "两对 · K 和 Q")
	hud.set_my_hole([])
	assert_eq(hud.my_strip.cards(), [])
	for face in hud.my_strip.find_children("*", "TextureRect", true, false):
		assert_true((face as TextureRect).custom_minimum_size.y >= 70.0)
