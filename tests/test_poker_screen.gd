extends GutTest
# 德州牌桌控制器里不依赖场景的部分(屏幕不入树,HUD 与导演为空,用假视图):
# 演出中不是自己的回合;视图说轮到自己、演出也到了自己才算;提交后等回执期间不能重复提交,被拒绝后恢复;
# 再领 / 观战 / 回座只在对应状态下发、等回执期间不重复;不在座位表里时用观战机位;退场只收自己的铭牌并拆台。


const PokerScreenScript := preload("res://src/ui/poker/poker_screen.gd")
const ME := 1
const H := preload("res://tests/poker_helpers.gd")


class StubTavern:
	extends Node
	var camera_rig: CameraRig


class StubApp:
	extends Node
	var labels: WorldLabels
	var world: TableWorld
	var tavern: StubTavern
	var toasts: Array = []

	func toast(text: String, _color := Color.WHITE) -> void:
		toasts.append(text)


var app: StubApp
var screen: Node


func before_each():
	app = StubApp.new()
	add_child_autofree(app)
	app.labels = WorldLabels.new(null)
	app.add_child(app.labels)
	app.world = TableWorld.new(null)
	app.add_child(app.world)
	app.tavern = StubTavern.new()
	app.tavern.camera_rig = CameraRig.new()
	app.tavern.add_child(app.tavern.camera_rig)
	app.add_child(app.tavern)
	# 不入树:_ready 不会运行,只测状态逻辑
	screen = autofree(PokerScreenScript.new(app))
	screen.my_pid = ME
	screen.world = app.world


func _player(pid: int, status := PokerRules.STATUS_ACTIVE, overrides := {}) -> Dictionary:
	var p := {"pid": pid, "name": "P%d" % pid, "stack": 2000, "bet": 0, "committed": 0, "status": status, "left": false,
		"buyins": 1, "net": 0, "shown": []}
	p.merge(overrides, true)
	return p


func _pub(pids: Array, actor: Variant, overrides := {}) -> Dictionary:
	var pub := {"mode": GameMode.HOLDEM, "hand": 2, "phase": "betting", "street": PokerRules.PREFLOP, "board": [],
		"pots": [], "button": pids[0], "sb": null, "bb": null, "current_pid": actor, "current_bet": 20, "actions": {},
		"blinds": [10, 20], "seats": pids.duplicate(), "players": pids.map(func(pid): return _player(pid)),
		"turn_time_left": 30.0, "ending": false, "results": []}
	if actor is int:
		pub["actions"] = {"pid": actor, "to_call": 20, "call_amount": 20, "can_check": false, "can_raise": true,
			"can_allin": true, "min_raise_to": 40, "max_raise_to": 2000}
	pub.merge(overrides, true)
	return pub


func _my_turn_view() -> void:
	screen._on_public(_pub([1, 2, 3], ME))
	screen.animating = false
	screen.set_current(ME)


# —— 回合 ——

func test_not_my_turn_while_the_show_is_still_playing():
	screen._on_public(_pub([1, 2, 3], ME))
	screen.set_current(ME)
	assert_true(screen.animating, "进牌桌时先播开场运镜")
	assert_false(screen.is_my_turn())
	screen.animating = false
	assert_true(screen.is_my_turn())
	assert_eq(screen.legal()["min_raise_to"], 40)


func test_my_turn_needs_both_the_view_and_the_show_to_agree():
	screen._on_public(_pub([1, 2, 3], 2))
	screen.animating = false
	screen.set_current(ME)
	assert_false(screen.is_my_turn(), "演出到了自己,但视图说轮到别人(视图领先)")
	assert_eq(screen.legal(), {})
	screen._on_public(_pub([1, 2, 3], ME))
	screen.set_current(2)
	assert_false(screen.is_my_turn(), "视图说轮到自己,但演出还没到")


func test_submitting_waits_for_the_hosts_reply_and_a_rejection_restores_the_turn():
	_my_turn_view()
	assert_true(screen.submit(PokerRules.CALL))
	assert_false(screen.is_my_turn(), "等回执期间不能重复提交")
	assert_false(screen.submit(PokerRules.FOLD))
	screen._on_rejected("not_your_turn")
	assert_true(screen.is_my_turn())
	assert_eq(app.toasts, [PokerScreenScript.ERROR_MESSAGES["not_your_turn"]])
	screen._on_rejected("mystery_code")
	assert_eq(app.toasts.back(), "mystery_code", "没有文案的错误码原样显示")


func test_the_next_turn_event_clears_the_pending_submission():
	_my_turn_view()
	screen.submit(PokerRules.RAISE, 60)
	screen._on_public(_pub([1, 2, 3], 2))
	screen.set_current(2)
	assert_false(screen._awaiting_intent)
	assert_false(screen.is_my_turn())


func test_only_betting_actions_can_be_submitted():
	_my_turn_view()
	assert_false(screen.submit(PokerRules.REBUY))
	assert_false(screen.submit("explode"))
	assert_true(screen.is_my_turn())


func test_no_turn_once_the_settlement_is_up():
	_my_turn_view()
	screen._settlement = autofree(PokerSettlement.new([], false))
	assert_false(screen.is_my_turn())


# —— 座位请求 ——

func test_rebuy_spectate_and_sit_in_follow_my_status():
	screen.animating = false
	screen._on_public(_pub([1, 2], null, {"players": [_player(ME, PokerRules.STATUS_BUSTED, {"stack": 0}), _player(2)]}))
	assert_eq(screen.my_status(), PokerRules.STATUS_BUSTED)
	assert_false(screen.choose_sit_in(), "没离座")
	assert_true(screen.choose_spectate())
	assert_false(screen.choose_rebuy(), "等回执期间不重复发")
	screen._on_events([{"type": "spectate", "pid": ME}])   # 回执到了(事件由导演演出时才改状态)
	assert_false(screen._seat_request_pending)
	screen.state.apply_event({"type": "spectate", "pid": ME})
	assert_eq(screen.my_status(), PokerRules.STATUS_SPECTATING)
	assert_false(screen.choose_spectate(), "观战中不能再选观战")
	assert_true(screen.choose_rebuy(), "观战中随时可以领筹码")
	screen._on_rejected("cannot_rebuy")
	assert_true(screen.choose_rebuy(), "被拒绝后可以再试")


func test_away_player_can_only_sit_in():
	screen.animating = false
	screen._on_public(_pub([1, 2], null, {"players": [_player(ME, PokerRules.STATUS_AWAY), _player(2)]}))
	assert_false(screen.choose_rebuy())
	assert_false(screen.choose_spectate())
	assert_true(screen.choose_sit_in())


func test_waiting_player_has_nothing_to_request():
	screen.animating = false
	screen._on_public(_pub([1, 2], null, {"players": [_player(ME, PokerRules.STATUS_WAITING), _player(2)]}))
	for request in [screen.choose_rebuy, screen.choose_spectate, screen.choose_sit_in]:
		assert_false(request.call())


# —— 视图与机位 ——

func test_views_during_the_show_are_reconciled_only_when_it_ends():
	screen._on_public(_pub([2, 3], null))
	assert_true(screen.late == false, "late 由 _ready 按 Net.seats 判定,这里不入树")
	assert_true(screen.state.seats.is_empty(), "演出中不换座位表")
	screen.animating = false
	screen._on_public(_pub([2, 3], null))
	assert_eq(screen.state.seats, [2, 3])


func test_late_joiner_uses_the_overview_camera_until_seated():
	screen.chips = PokerChips.new(app.world)
	screen.cards = PokerCards.new(app.world)
	app.world.poker_root.add_child(screen.chips)
	app.world.poker_root.add_child(screen.cards)
	var director := PokerDirector.new(screen, app, null)
	app.add_child(director)   # 运镜的计时要在树内
	screen.director = director
	screen._on_public(_pub([2, 3], 2))
	screen.animating = false
	assert_eq(director.wanted_mode(), PokerDirector.MODE_OVERVIEW, "不在座位表里:观战机位")
	screen._on_public(_pub([1, 2, 3], 2))
	assert_eq(director.wanted_mode(), PokerDirector.MODE_SEAT)
	screen._on_public(_pub([1, 2, 3], 2, {"players": [_player(ME, PokerRules.STATUS_SPECTATING, {"stack": 0}), _player(2), _player(3)]}))
	assert_eq(director.wanted_mode(), PokerDirector.MODE_OVERVIEW, "观战中")
	assert_false(app.world.patrons[ME].visible, "本机观战者的酒客藏起来")
	screen._on_public(_pub([1, 2, 3], 2, {"players": [_player(ME, PokerRules.STATUS_WAITING), _player(2), _player(3)]}))
	assert_eq(director.wanted_mode(), PokerDirector.MODE_SEAT, "再领后等下一手:留在越肩")
	assert_true(app.world.patrons[ME].visible)


func test_hole_cards_for_the_hand_come_from_the_private_view():
	screen._on_private({"hand": 2, "hole": H.cards("Ah Kd"), "best": {}})
	assert_eq(await screen.hole_for_hand(2), H.cards("Ah Kd"))
	assert_eq(await screen.hole_for_hand(3), [], "不在树内不等:下一手的牌还没到就当没有")


# —— 退场 ——

func test_exit_tree_untracks_only_poker_plates_and_tears_the_table_down():
	app.world.arrange([{"pid": 1, "name": "我"}, {"pid": 2, "name": "乙"}], ME, true, false)
	app.world.set_patron_visible(ME, false)
	app.world.poker_root.add_child(ChipStack3D.new())
	screen.state.names = {1: "我", 2: "乙"}
	app.labels.track("lobby:1", Label.new(), func(): return Vector3.ZERO)
	app.labels.track(PokerScreenScript.PLATE_KEY % 2, Label.new(), func(): return Vector3.ZERO)
	screen._exit_tree()
	assert_not_null(app.labels.get_node_for("lobby:1"), "等待厅的铭牌不能被牌桌退场清掉")
	assert_null(app.labels.get_node_for(PokerScreenScript.PLATE_KEY % 2))
	assert_true(app.world.patrons[ME].visible, "本机藏起来的酒客还原")
	assert_eq(app.world.poker_root.get_children().filter(func(n: Node): return not n.is_queued_for_deletion()).size(), 0)
	await wait_process_frames(1)   # 让 queue_free 的节点释放掉,不留孤儿
