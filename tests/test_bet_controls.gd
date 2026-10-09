extends GutTest
# 下注控件(规格 §6.2):预设公式、取整与夹取、按钮文案、按 can_raise / can_allin 禁用、
# 快捷键映射(F 在能免费过牌时不弃牌)、所有控件不抢键盘焦点、布局不超过 600×170。


const ME := 1

var controls: BetControls


func before_each():
	controls = BetControls.new()
	add_child_autofree(controls)


func _pub(actions: Dictionary, current_bet := 20, pots := [{"amount": 60, "eligible": [1, 2, 3]}],
		bets := [20, 20, 0], statuses := ["active", "active", "active"]) -> Dictionary:
	# 三人桌:底池 60,桌上本轮下注 20 + 20,当前最高 20
	var players := []
	for i in bets.size():
		players.append({"pid": i + 1, "name": "P%d" % (i + 1), "stack": 1000, "bet": bets[i], "status": statuses[i], "left": false})
	return {"actions": actions, "current_bet": current_bet, "pots": pots, "players": players, "seats": [1, 2, 3]}


func _legal(overrides := {}) -> Dictionary:
	var legal := {"pid": ME, "to_call": 20, "call_amount": 20, "can_check": false, "can_raise": true, "can_allin": true,
		"min_raise_to": 40, "max_raise_to": 1000}
	legal.merge(overrides, true)
	return legal


# —— 预设公式 ——

func test_presets_with_a_bet_on_the_table_follow_the_spec_example():
	# 底池 60 + 桌上下注 40、当前最高 20、要跟 20、最少加到 40、最多 1000:½ 池 = 80,1 池 = 140,全下 = 1000
	var s := BetControls.situation(_pub(_legal()), ME)
	assert_eq(s["pot"], 100)
	assert_eq(BetControls.preset_amounts(s), [40, 80, 110, 140, 1000])


func test_presets_without_a_bet_use_the_pot_times_fraction():
	# 翻牌后没人下注:底池 300,½ 池 = 150,1 池 = 300;最小下注 20
	var legal := _legal({"to_call": 0, "call_amount": 0, "can_check": true, "min_raise_to": 20, "max_raise_to": 980})
	var s := BetControls.situation(_pub(legal, 0, [{"amount": 300, "eligible": [1, 2, 3]}], [0, 0, 0]), ME)
	assert_eq(BetControls.preset_amounts(s), [20, 150, 230, 300, 980])


func test_presets_are_rounded_to_the_chip_unit_and_clamped():
	var legal := _legal({"min_raise_to": 60, "max_raise_to": 120})
	# ½ 池 = 20 + 120 × 0.5 = 80;1 池 = 140 → 夹到 120;最小 60
	var s := BetControls.situation(_pub(legal), ME)
	assert_eq(BetControls.preset_amounts(s), [60, 80, 110, 120, 120])
	assert_eq(BetControls.round_to_unit(84.9), 80)
	assert_eq(BetControls.round_to_unit(85.0), 90)
	assert_eq(BetControls.clamp_amount(5, legal), 60)
	assert_eq(BetControls.clamp_amount(5000, legal), 120)


func test_situation_ignores_actions_meant_for_someone_else_and_bad_data():
	var pub := _pub(_legal({"pid": 2}))
	assert_true(BetControls.situation(pub, ME)["legal"].is_empty(), "别人的回合:没有可用动作")
	var junk := {"actions": "x", "current_bet": "20", "pots": [{"amount": "9"}, 3], "players": [{"bet": "7"}, 4]}
	var s := BetControls.situation(junk, ME)
	assert_true(s["legal"].is_empty())
	assert_eq(s["pot"], 0)
	assert_eq(s["current_bet"], 0)


# —— 文案 ——

func test_button_labels():
	var with_bet := BetControls.labels(_legal(), 20, 80)
	assert_eq(with_bet["fold"], "弃牌")
	assert_eq(with_bet["check_call"], "跟注 20")
	assert_eq(with_bet["raise"], "加注到 80")
	assert_eq(with_bet["allin"], "全下 1,000")
	var no_bet := BetControls.labels(_legal({"to_call": 0, "call_amount": 0, "can_check": true}), 0, 40)
	assert_eq(no_bet["check_call"], "过牌")
	assert_eq(no_bet["raise"], "下注 40")


func test_short_call_is_labelled_as_an_all_in_call():
	# 筹码不够跟:跟注就是全下
	var labels := BetControls.labels(_legal({"to_call": 500, "call_amount": 300, "can_raise": false, "max_raise_to": 300}), 500, 0)
	assert_eq(labels["check_call"], "全下跟注 300")


func test_raise_block_reasons():
	assert_eq(BetControls.raise_block_reason(BetControls.situation(_pub(_legal()), ME)), "")
	# 筹码只够跟注:最多也只能加到当前最高
	var short := _legal({"can_raise": false, "max_raise_to": 20})
	assert_eq(BetControls.raise_block_reason(BetControls.situation(_pub(short), ME)), "筹码只够跟注")
	# 对手都已全下
	var all_in := _legal({"can_raise": false, "can_allin": false})
	var pub := _pub(all_in, 20, [{"amount": 60, "eligible": [1, 2, 3]}], [20, 20, 0], ["active", "allin", "folded"])
	assert_eq(BetControls.raise_block_reason(BetControls.situation(pub, ME)), "对手都已全下")
	# 还有对手能行动、自己也有钱,却不能加注:只能是不完整加注不重开
	var reopened := _pub(all_in)
	assert_eq(BetControls.raise_block_reason(BetControls.situation(reopened, ME)), "不完整加注不重开")


# —— 控件状态 ——

func test_controls_follow_can_raise_and_can_allin():
	controls.update(_pub(_legal({"can_raise": false, "can_allin": true, "max_raise_to": 20})), ME)
	assert_true(controls._raise_button.disabled)
	assert_true(controls._slider.editable == false)
	assert_false(controls._allin_button.disabled)
	assert_eq(controls._raise_button.tooltip_text, "筹码只够跟注")
	for preset in controls._preset_buttons:
		assert_true((preset as Button).disabled)
	controls.update(_pub(_legal()), ME)
	assert_false(controls._raise_button.disabled)
	assert_true(controls._slider.editable)
	assert_false(controls._allin_button.disabled)
	assert_eq(controls._raise_button.tooltip_text, "")


func test_only_all_in_possible_pins_the_amount_to_the_maximum():
	# min_raise_to == max_raise_to:筹码不够一个完整加注,唯一的加注就是全下
	controls.update(_pub(_legal({"min_raise_to": 300, "max_raise_to": 300})), ME)
	assert_eq(controls.amount(), 300)
	assert_false(controls._slider.editable)
	assert_false(controls._raise_button.disabled)
	assert_eq(controls._raise_button.text, "加注到 300")


func test_update_keeps_a_legal_amount_and_resets_to_the_minimum_each_turn():
	controls.update(_pub(_legal()), ME)
	assert_eq(controls.amount(), 40, "新回合从最小加注开始")
	controls.set_amount(85)
	assert_eq(controls.amount(), 90, "按 10 取整")
	controls.set_amount(99999)
	assert_eq(controls.amount(), 1000)
	assert_eq(controls._raise_button.text, "加注到 1,000")


func test_no_controls_take_keyboard_focus():
	for node in controls.find_children("*", "Control", true, false):
		assert_eq((node as Control).focus_mode, Control.FOCUS_NONE, str(node))


func test_layout_fits_the_bottom_centre_budget():
	controls.update(_pub(_legal()), ME)
	controls.set_turn("轮到你了", true)
	controls.set_countdown(30.0, 30.0)
	await wait_process_frames(3)
	assert_true(controls.size.x <= BetControls.MAX_SIZE.x, "宽 %s" % controls.size)
	assert_true(controls.size.y <= BetControls.MAX_SIZE.y, "高 %s" % controls.size)
	assert_true(controls._slider.custom_minimum_size.x >= BetControls.SLIDER_WIDTH)


func test_slider_track_is_visible_on_the_dark_panel():
	# 游戏主题下滑条的轨道要有高度、要在深色面板上看得见(默认主题的轨道是深灰,看不见范围与当前位置)
	controls.theme = UiTheme.theme()
	controls.update(_pub(_legal()), ME)
	var track: StyleBoxFlat = controls._slider.get_theme_stylebox("slider")
	var fill: StyleBoxFlat = controls._slider.get_theme_stylebox("grabber_area")
	assert_true(track.get_minimum_size().y >= 4.0, "轨道高度 %s" % track.get_minimum_size())
	assert_true(track.bg_color.a >= 0.2 and track.bg_color.v >= 0.5, "轨道颜色 %s" % track.bg_color)
	assert_true(fill.bg_color.v >= 0.7, "已选部分颜色 %s" % fill.bg_color)


func test_a_new_street_with_the_same_legal_set_still_resets_the_amount():
	# 新回合的判定不能只靠合法动作集合变了:翻牌圈大家都过牌,转牌圈又轮到我先手,合法动作一模一样,金额仍要回到最小
	var legal := _legal({"to_call": 0, "call_amount": 0, "can_check": true, "min_raise_to": 20, "max_raise_to": 980})
	var pub := _pub(legal, 0, [{"amount": 300, "eligible": [1, 2, 3]}], [0, 0, 0])
	pub.merge({"hand": 3, "street": "flop", "current_pid": ME}, true)
	assert_eq(BetControls.situation(pub, ME)["turn"], [3, "flop", ME])
	controls.update(pub, ME)
	controls.set_amount(300)
	controls.update(pub, ME)
	assert_eq(controls.amount(), 300, "同一回合的刷新(倒计时)保留调好的金额")
	var next := pub.duplicate(true)
	next["street"] = "turn"
	controls.update(next, ME)
	assert_eq(controls.amount(), 20, "新一条街:合法动作一样也回到最小")
	var junk := {"actions": legal, "hand": "x", "street": 7, "current_pid": "me"}
	assert_eq(BetControls.situation(junk, ME)["turn"], [null, null, null], "视图不可信:类型不对当空")


# —— 快捷键 ——

func test_hotkey_map():
	assert_eq(BetControls.hotkey(KEY_F), {"kind": "fold"})
	assert_eq(BetControls.hotkey(KEY_C), {"kind": "check_call"})
	assert_eq(BetControls.hotkey(KEY_SPACE), {"kind": "check_call"})
	assert_eq(BetControls.hotkey(KEY_R), {"kind": "raise"})
	assert_eq(BetControls.hotkey(KEY_ENTER), {"kind": "check_call"}, "回车是默认动作:过牌 / 跟注")
	assert_eq(BetControls.hotkey(KEY_KP_ENTER), {"kind": "check_call"})
	assert_eq(BetControls.hotkey(KEY_UP), {"kind": "step", "delta": 1})
	assert_eq(BetControls.hotkey(KEY_DOWN), {"kind": "step", "delta": -1})
	assert_eq(BetControls.hotkey(KEY_1), {"kind": "preset", "index": 0})
	assert_eq(BetControls.hotkey(KEY_5), {"kind": "preset", "index": 4})
	assert_eq(BetControls.hotkey(KEY_W), {}, "WASD 仍是探头")
	assert_eq(BetControls.hotkey(KEY_ESCAPE), {})


func test_f_does_not_fold_when_checking_is_free():
	controls.update(_pub(_legal({"to_call": 0, "call_amount": 0, "can_check": true})), ME)
	watch_signals(controls)
	assert_true(controls.handle_key(KEY_F), "按键被消费(提示),不往下传")
	assert_signal_not_emitted(controls, "action_chosen")
	assert_signal_emitted(controls, "free_check_hinted")
	assert_eq(controls._hint.text, "可以免费过牌")


func test_f_folds_when_there_is_something_to_call():
	controls.update(_pub(_legal()), ME)
	watch_signals(controls)
	controls.handle_key(KEY_F)
	assert_signal_emitted_with_parameters(controls, "action_chosen", ["fold", 0])


func test_fold_button_asks_for_confirmation_only_when_checking_is_free():
	controls.update(_pub(_legal({"to_call": 0, "call_amount": 0, "can_check": true})), ME)
	watch_signals(controls)
	controls._fold_button.pressed.emit()
	assert_signal_emitted(controls, "fold_confirm_requested")
	assert_signal_not_emitted(controls, "action_chosen")
	controls.update(_pub(_legal()), ME)
	controls._fold_button.pressed.emit()
	assert_signal_emitted_with_parameters(controls, "action_chosen", ["fold", 0])


func test_check_call_raise_and_all_in_keys_emit_the_matching_action():
	controls.update(_pub(_legal()), ME)
	watch_signals(controls)
	controls.handle_key(KEY_SPACE)
	assert_signal_emitted_with_parameters(controls, "action_chosen", ["call", 0])
	controls.handle_key(KEY_3)
	assert_eq(controls.amount(), 110, "3 = ¾ 池")
	controls.handle_key(KEY_UP)
	assert_eq(controls.amount(), 130, "↑ 加一个大盲")
	controls.handle_key(KEY_DOWN)
	controls.handle_key(KEY_DOWN)
	assert_eq(controls.amount(), 90)
	controls.handle_key(KEY_R)
	assert_signal_emitted_with_parameters(controls, "action_chosen", ["raise", 90])
	controls._allin_button.pressed.emit()
	assert_signal_emitted_with_parameters(controls, "action_chosen", ["allin", 0])


func test_check_key_checks_when_free_and_disabled_actions_do_nothing():
	controls.update(_pub(_legal({"to_call": 0, "call_amount": 0, "can_check": true, "can_raise": false, "can_allin": false})), ME)
	watch_signals(controls)
	controls.handle_key(KEY_C)
	assert_signal_emitted_with_parameters(controls, "action_chosen", ["check", 0])
	assert_false(controls.handle_key(KEY_R), "不能加注:R 不消费")
	assert_eq(get_signal_emit_count(controls, "action_chosen"), 1)
	assert_false(controls.handle_key(KEY_UP))


func test_keys_are_ignored_when_it_is_not_my_turn():
	controls.update(_pub(_legal({"pid": 2})), ME)
	watch_signals(controls)
	assert_false(controls.handle_key(KEY_F))
	assert_false(controls.handle_key(KEY_SPACE))
	assert_signal_not_emitted(controls, "action_chosen")


func test_check_or_call_is_the_highlighted_default_button():
	# 用户要求:默认选过牌(高亮的主按钮是「过牌 / 跟注」,不是「加注到」)
	var controls := BetControls.new()
	add_child_autofree(controls)
	var primary := UiTheme.button("x", true)
	var plain := UiTheme.button("x", false)
	add_child_autofree(primary)
	add_child_autofree(plain)
	var bg := func(b: Button) -> Color: return (b.get_theme_stylebox("normal") as StyleBoxFlat).bg_color
	assert_eq(bg.call(controls._check_call_button), bg.call(primary), "过牌 / 跟注 高亮")
	assert_eq(bg.call(controls._raise_button), bg.call(plain), "加注不再高亮")
	assert_string_contains(BetControls.HOTKEY_HINT, "C/空格/回车 过牌或跟注")

