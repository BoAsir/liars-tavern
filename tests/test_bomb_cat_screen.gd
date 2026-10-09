extends GutTest
# 炸弹猫牌桌控制器里不依赖场景的部分(屏幕不入树,只配一个 HUD,意图交给 intent_sink 记下来):
# 快捷键映射(不占 T / Q / V / WASD / Esc / F1;快捷语面板开着时数字键不选牌)、选牌规则、出牌要不要选目标 / 点名、
# 演出中与等回执时不能出手、「不行!」只在窗口里且不重复提交、塞回位置的范围、被讨要时点牌就是给牌。


const ScreenScript := preload("res://src/ui/bomb_cat/bomb_cat_screen.gd")
const C := preload("res://src/core/bomb_cat/bomb_cat_card.gd")
const ME := 1


class FakeBanterView:
	extends Node
	var open := false

	func is_panel_open() -> bool:
		return open


class StubApp:
	extends Node
	var toasts: Array = []
	var banter_view: FakeBanterView

	func toast(text: String, _color := Color.WHITE) -> void:
		toasts.append(text)

	func is_modal_open() -> bool:
		return false

	func is_rules_open() -> bool:
		return false


var app: StubApp
var screen: Node
var sent: Array = []


func before_each():
	app = StubApp.new()
	add_child_autofree(app)
	app.banter_view = FakeBanterView.new()
	app.add_child(app.banter_view)
	screen = autofree(ScreenScript.new(app))
	screen.my_pid = ME
	screen.state.my_pid = ME
	screen.state.set_seats([{"pid": 1, "name": "我"}, {"pid": 2, "name": "乙"}, {"pid": 3, "name": "丙"}])
	screen.hud = BombCatHud.new()
	add_child_autofree(screen.hud)
	screen.intent_sink = func(intent: Dictionary) -> void: sent.append(intent)
	sent = []


func after_each():
	BombCatFaces.clear()


func _view(hand: Array, overrides := {}, priv_overrides := {}) -> void:
	var pub := {"mode": GameMode.BOMB_CAT, "step": "turn", "current_pid": ME, "turns": 1, "deck_count": 20, "discard_count": 0,
		"discard_top": "", "bombs_left": 2, "bombs_total": 2, "window": {}, "give": {}, "reinsert": {},
		"players": [{"pid": 1, "name": "我", "alive": true, "hand_count": hand.size()}, {"pid": 2, "name": "乙", "alive": true, "hand_count": 4},
			{"pid": 3, "name": "丙", "alive": true, "hand_count": 0}],
		"out_order": [], "winner": null, "ranking": [], "turn_time_left": 30.0, "paused_turn_left": 0.0}
	pub.merge(overrides, true)
	var priv := {"hand": hand, "alive": true, "last_drawn": "", "draw_seq": 0, "peek": [], "peek_seq": 0, "reinsert": {}, "give": {},
		"transfer": {}}
	priv.merge(priv_overrides, true)
	screen.state.apply_public(pub)
	screen.state.apply_private(priv)
	screen.state.sync_from_view()
	screen.animating = false
	screen.refresh_actions()


# —— 快捷键 ——

func test_key_mapping():
	assert_eq(ScreenScript.key_action(KEY_ENTER), ScreenScript.ACTION_PLAY)
	assert_eq(ScreenScript.key_action(KEY_KP_ENTER), ScreenScript.ACTION_PLAY)
	assert_eq(ScreenScript.key_action(KEY_SPACE), ScreenScript.ACTION_DRAW)
	assert_eq(ScreenScript.key_action(KEY_N), ScreenScript.ACTION_NOPE)
	for taken in [KEY_T, KEY_G, KEY_Q, KEY_V, KEY_W, KEY_A, KEY_S, KEY_D, KEY_ESCAPE, KEY_F1]:
		assert_eq(ScreenScript.key_action(taken), "", "%s 已被占用,不能挪作炸弹猫的动作" % OS.get_keycode_string(taken))
		assert_eq(ScreenScript.card_key_index(taken), -1)
	for i in 9:
		assert_eq(ScreenScript.card_key_index(KEY_1 + i), i)
		assert_eq(ScreenScript.card_key_index(KEY_KP_1 + i), i)
	assert_eq(ScreenScript.card_key_index(KEY_0), -1)


func test_number_keys_select_cards_and_enter_plays():
	_view([C.SNACK_FISH, C.SKIP, C.SNACK_FISH])
	assert_true(screen.handle_key(KEY_2))
	assert_eq(screen.selected_indices(), [1])
	assert_true(screen.handle_key(KEY_ENTER))
	assert_eq(sent, [{"kind": "play", "cards": [1]}])


func test_number_keys_go_to_the_quick_chat_panel_when_it_is_open():
	_view([C.SKIP, C.NOPE])
	app.banter_view.open = true
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	screen._unhandled_input(key)
	assert_eq(screen.selected_indices(), [], "面板开着:1 不选牌")
	key.keycode = KEY_9
	screen._unhandled_input(key)
	assert_eq(screen.selected_indices(), [], "面板没用掉的 9 也不选牌")


func test_space_draws_and_waits_for_the_receipt():
	_view([C.SKIP])
	assert_true(screen.handle_key(KEY_SPACE))
	assert_eq(sent, [{"kind": "draw"}])
	assert_false(screen.is_my_turn(), "等回执")
	assert_false(screen.submit_draw(), "不重复提交")
	screen._on_rejected(BombCatState.ERR_BUSY)
	assert_has(app.toasts, BombCatState.ERROR_MESSAGES[BombCatState.ERR_BUSY], "被拒时 toast 中文")
	assert_true(screen.is_my_turn())


# —— 选牌与出牌 ——

func test_selecting_replaces_unless_it_is_a_matching_snack():
	_view([C.SNACK_FISH, C.SNACK_FISH, C.SKIP, C.SNACK_FISH, C.SNACK_YARN])
	screen.toggle_card(0)
	screen.toggle_card(1)
	assert_eq(screen.selected_indices(), [0, 1], "同种零食可以多选")
	screen.toggle_card(3)
	assert_eq(screen.selected_indices(), [0, 1, 3])
	screen.toggle_card(4)
	assert_eq(screen.selected_indices(), [4], "别的牌换成单选")
	screen.toggle_card(2)
	assert_eq(screen.selected_indices(), [2])
	screen.toggle_card(2)
	assert_eq(screen.selected_indices(), [], "再点一下取消")
	screen.toggle_card(9)
	assert_eq(screen.selected_indices(), [], "越界不选")


func test_illegal_selection_is_not_sent():
	_view([C.SNACK_FISH, C.DEFUSE])
	screen.toggle_card(0)
	assert_true(screen.hud.play_button.disabled, "单张零食:出牌按钮不亮")
	assert_false(screen.submit_play())
	assert_eq(sent, [])
	assert_string_contains(app.toasts[-1], "两张一样")


func test_beg_asks_for_a_valid_target_first():
	_view([C.BEG])
	screen.toggle_card(0)
	assert_true(screen.submit_play())
	assert_eq(sent, [], "先选目标")
	assert_eq(screen.hud.prompt_kind, BombCatHud.PROMPT_TARGET)
	assert_false(screen.choose_target(3), "丙手里没牌")
	assert_false(screen.choose_target(ME), "不能选自己")
	assert_eq(sent, [])
	assert_true(screen.choose_target(2))
	assert_eq(sent, [{"kind": "play", "cards": [0], "target": 2}])
	assert_eq(screen.hud.prompt_kind, BombCatHud.PROMPT_NONE)


func test_triple_asks_for_a_target_then_a_card_name():
	_view([C.SNACK_CARROT, C.SNACK_CARROT, C.SNACK_CARROT])
	for i in 3:
		screen.toggle_card(i)
	assert_true(screen.submit_play())
	assert_true(screen.choose_target(2))
	assert_eq(screen.hud.prompt_kind, BombCatHud.PROMPT_NAMED)
	assert_false(screen.choose_named(C.BOMB), "不能点名炸弹")
	assert_true(screen.choose_named(C.DEFUSE))
	assert_eq(sent, [{"kind": "play", "cards": [0, 1, 2], "target": 2, "named": C.DEFUSE}])


func test_cancelling_a_target_prompt_keeps_the_turn():
	_view([C.SNACK_FISH, C.SNACK_FISH])
	screen.toggle_card(0)
	screen.toggle_card(1)
	screen.submit_play()
	screen.cancel_prompt()
	assert_eq(screen.hud.prompt_kind, BombCatHud.PROMPT_NONE)
	assert_true(screen.submit_draw(), "取消之后照样能摸牌")


func test_no_play_or_draw_while_animating_or_in_a_window():
	_view([C.SKIP])
	screen.animating = true
	screen.toggle_card(0)
	assert_false(screen.submit_play(), "演出中")
	assert_false(screen.submit_draw())
	_view([C.SKIP], {"step": "window", "window": {"pid": ME, "cards": [C.PEEK], "kind": C.PEEK, "target": null, "named": "", "nopes": 0}})
	assert_false(screen.submit_draw(), "窗口里要等")
	_view([C.SKIP], {"current_pid": 2})
	assert_false(screen.submit_draw(), "不是自己的回合")


# —— 不行! ——

func test_nope_only_in_a_window_and_only_once_until_the_receipt():
	_view([C.NOPE, C.NOPE])
	assert_false(screen.submit_nope(), "窗口外")
	_view([C.NOPE, C.NOPE], {"step": "window", "current_pid": 2,
		"window": {"pid": 2, "cards": [C.BEG], "kind": C.BEG, "target": ME, "named": "", "nopes": 0}})
	screen.animating = true
	assert_true(screen.can_nope(), "不行! 不等演出")
	assert_true(screen.handle_key(KEY_N))
	assert_eq(sent, [{"kind": "nope"}])
	assert_false(screen.submit_nope(), "回执前不重复")
	screen._on_events([{"type": "noped", "pid": ME, "depth": 1, "window": 3.0}])
	assert_true(screen.submit_nope(), "回执到了还能再打一张")
	_view([C.SKIP], {"step": "window", "window": {"pid": 2, "cards": [C.BEG], "kind": C.BEG, "target": ME, "named": "", "nopes": 0}})
	assert_false(screen.can_nope(), "手里没有不行!")


# —— 塞回与给牌 ——

func test_reinsert_positions_are_bounded_by_the_private_view():
	_view([C.SKIP], {"step": "reinsert", "reinsert": {"pid": ME}}, {"reinsert": {"deck_count": 9}})
	assert_eq(screen.hud.prompt_kind, BombCatHud.PROMPT_REINSERT, "塞回滑块")
	assert_eq(screen.hud.reinsert_slider.max_value, 9.0)
	assert_false(screen.submit_reinsert(10), "超出牌堆")
	assert_false(screen.submit_reinsert(-1))
	assert_true(screen.submit_reinsert(9))
	assert_eq(sent, [{"kind": "reinsert", "pos": 9}])


func test_enter_confirms_the_reinsert_slider():
	_view([C.SKIP], {"step": "reinsert", "reinsert": {"pid": ME}}, {"reinsert": {"deck_count": 5}})
	screen.handle_key(KEY_RIGHT)
	screen.handle_key(KEY_RIGHT)
	screen.handle_key(KEY_ENTER)
	assert_eq(sent, [{"kind": "reinsert", "pos": 2}])


func test_when_begged_clicking_a_card_gives_it():
	_view([C.SKIP, C.NOPE, C.DEFUSE], {"step": "give", "current_pid": 2, "give": {"from": ME, "to": 2}}, {"give": {"to": 2}})
	assert_eq(screen.hud.prompt_kind, BombCatHud.PROMPT_GIVE)
	screen._on_card_clicked(2)
	assert_eq(sent, [{"kind": "give", "index": 2}])
	sent = []
	screen._on_events([])   # 回执到了
	_view([C.SKIP, C.NOPE, C.DEFUSE], {"step": "give", "current_pid": 2, "give": {"from": ME, "to": 2}}, {"give": {"to": 2}})
	screen.handle_key(KEY_1)
	assert_eq(sent, [{"kind": "give", "index": 0}], "数字键也能给")


func test_spectator_cannot_act():
	_view([], {"current_pid": ME}, {"alive": false})
	assert_false(screen.submit_draw())
	assert_false(screen.submit_nope())
	screen.toggle_card(0)
	assert_eq(screen.selected_indices(), [])
