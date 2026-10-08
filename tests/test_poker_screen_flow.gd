extends GutTest
# 德州牌桌整体流程(无头,加速演出):真实的 PokerScreen + PokerDirector + PokerChips / PokerCards + HUD,
# 用假的 app 直接喂视图与事件,走完:开局发牌 → 自己行动 → 翻牌 → 全下亮牌 → 分池 → 输光 → 观战 → 再领 →
# 有人中途加入、有人离开 → 下一手重排座位 → 房主散局 → 结算 → 退场拆台。
# 每一步都断言 3D 与 HUD 的状态;引擎错误(缺前置状态的事件、空引用)会让 GUT 判失败(规格 §7 的容错)。


const PokerScreenScript := preload("res://src/ui/poker/poker_screen.gd")
const PLATE_KEY := PokerScreenScript.PLATE_KEY
const H := preload("res://tests/poker_helpers.gd")
const ME := 1
const SPEED := 12.0     # 演出加速:每批几秒的动画压到零点几秒
const MAX_WAIT := 20.0  # 真实秒


class StubTavern:
	extends Node
	var camera_rig: CameraRig


class StubApp:
	extends Node
	var world: TableWorld
	var labels: WorldLabels
	var tavern: StubTavern
	var toasts: Array = []
	var modes: Array = []

	func apply_table_mode(mode: String) -> void:
		modes.append(mode)
		world.configure_table(SeatLayout.table_radius_for(mode))

	func toast(text: String, _color := Color.WHITE) -> void:
		toasts.append(text)

	func show_rules() -> void:
		pass

	func is_rules_open() -> bool:
		return false

	func is_modal_open() -> bool:
		return false


var app: StubApp
var screen: Node
var saved := {}
var stacks := {}      # pid -> 筹码(假视图按它生成)
var statuses := {}    # pid -> status
var bets := {}
var shown := {}
var seats: Array = []
var names := {1: "我", 2: "乙", 3: "丙", 9: "迟到"}


func before_each():
	saved = {"seats": Net.seats, "pub": Net.last_public, "priv": Net.last_private, "mode": Net.game_mode, "scale": Engine.time_scale}
	# 前面的联机测试 leave() 后会把整棵树共用的 multiplayer_peer 置空,本屏幕 _ready 里要读 Net.my_pid()
	if multiplayer.multiplayer_peer == null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Engine.time_scale = SPEED
	PokerFaces.clear()
	app = StubApp.new()
	add_child_autofree(app)
	app.labels = WorldLabels.new(null)
	app.add_child(app.labels)
	app.tavern = StubTavern.new()
	app.tavern.camera_rig = CameraRig.new()
	app.tavern.add_child(app.tavern.camera_rig)
	app.add_child(app.tavern)
	app.world = TableWorld.new(null)
	app.add_child(app.world)
	Net.game_mode = GameMode.HOLDEM
	Net.last_public = {}
	Net.last_private = {}


func after_each():
	Net.seats = saved["seats"]
	Net.last_public = saved["pub"]
	Net.last_private = saved["priv"]
	Net.game_mode = saved["mode"]
	Engine.time_scale = saved["scale"]
	PokerFaces.clear()


# —— 假视图 ——

func _reset_table(pids: Array) -> void:
	seats = pids.duplicate()
	stacks = {}
	statuses = {}
	bets = {}
	shown = {}
	for pid in pids:
		stacks[pid] = PokerRules.STARTING_STACK
		statuses[pid] = PokerRules.STATUS_ACTIVE
		bets[pid] = 0
		shown[pid] = []


func _players() -> Array:
	return stacks.keys().map(func(pid): return {"pid": pid, "name": names[pid], "stack": stacks[pid], "bet": bets[pid],
		"committed": bets[pid], "status": statuses[pid], "left": false, "buyins": 1, "net": stacks[pid] - 2000, "shown": shown[pid]})


func _pub(actor: Variant, overrides := {}) -> Dictionary:
	var pub := {"mode": GameMode.HOLDEM, "hand": 1, "phase": "betting" if actor != null else "idle", "street": PokerRules.PREFLOP,
		"board": [], "pots": [], "button": 1, "sb": 2, "bb": 3, "current_pid": actor, "current_bet": 20, "actions": {},
		"blinds": [10, 20], "seats": seats.duplicate(), "players": _players(), "turn_time_left": 30.0, "ending": false, "results": []}
	if actor is int:
		var to_call: int = pub["current_bet"] - bets.get(actor, 0)
		pub["actions"] = {"pid": actor, "to_call": to_call, "call_amount": to_call, "can_check": to_call == 0, "can_raise": true,
			"can_allin": true, "min_raise_to": 40, "max_raise_to": bets.get(actor, 0) + stacks.get(actor, 0)}
	pub.merge(overrides, true)
	return pub


func _bet(pid: int, action: String, total: int, all_in := false) -> Dictionary:
	var added: int = total - bets[pid]
	stacks[pid] -= added
	bets[pid] = total
	if all_in:
		statuses[pid] = PokerRules.STATUS_ALLIN
	elif action == PokerRules.FOLD:
		statuses[pid] = PokerRules.STATUS_FOLDED
	return {"type": "action", "pid": pid, "action": action, "amount": added, "bet": total, "stack": stacks[pid], "all_in": all_in, "timeout": false}


func _blind(pid: int, kind: String, amount: int) -> Dictionary:
	stacks[pid] -= amount
	bets[pid] = amount
	return {"type": "blind", "pid": pid, "kind": kind, "amount": amount, "bet": amount, "stack": stacks[pid], "all_in": false}


func _collect() -> Dictionary:
	var total := 0
	for pid in bets:
		total += bets[pid]
		bets[pid] = 0
	return {"type": "bets_collected", "pots": [{"amount": total, "eligible": seats.duplicate()}], "refund": {}}


func _feed(events: Array, pub: Dictionary, priv := {}) -> void:
	# 同房主的顺序:先事件,再公共视图,再私有视图;然后等演出播完
	screen._on_events(events)
	screen._on_public(pub)
	if not priv.is_empty():
		screen._on_private(priv)
	await wait_until(func(): return not screen.animating and screen._intro_done, MAX_WAIT, "演出播完")


func _plate(pid: int) -> Control:
	return app.labels.get_node_for(PLATE_KEY % pid)


func _live_patrons() -> Array:
	return app.world.patrons.keys().filter(func(pid): return is_instance_valid(app.world.patrons[pid]))


func _open_table(pids: Array, late: bool) -> void:
	_reset_table(pids)
	Net.seats = pids.filter(func(pid): return not late or pid != ME).map(func(pid): return {"pid": pid, "name": names[pid]})
	screen = PokerScreenScript.new(app)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child_autofree(screen)


# —— 一整局 ——

func test_a_whole_session_from_deal_to_settlement():
	_open_table([1, 2, 3], false)
	assert_eq(app.modes, [GameMode.HOLDEM], "进牌桌按玩法摆桌")
	assert_eq(_live_patrons().size(), 3)
	assert_true(screen.animating, "开场运镜中")
	# 第一手:下盲、发牌、轮到自己(按钮 1,小盲 2,大盲 3)
	var hole := H.cards("Ah Kd")
	await _feed([{"type": "hand_started", "hand": 1, "button": 1, "sb": 2, "bb": 3, "seats": [1, 2, 3], "dealt": [2, 3, 1]},
		_blind(2, "sb", 10), _blind(3, "bb", 20), {"type": "hole_cards", "hand": 1, "pids": [2, 3, 1]}, {"type": "turn", "pid": ME}],
		_pub(ME), {"hand": 1, "hole": hole, "best": {}})
	assert_true(screen.is_my_turn())
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_BET)
	assert_true(screen.hud.controls.is_my_turn())
	assert_eq(screen.chips.stack_amount(2), 1990)
	assert_eq(screen.chips.bet_amount(3), 20)
	assert_eq(screen.chips.button_pid(), 1)
	assert_eq(screen.hud.my_strip.cards(), hole)
	assert_eq(app.world.patrons[ME].fan.get_child_count(), 2, "自己的两张手牌举在手里")
	assert_not_null(_plate(2))
	assert_not_null(_plate(3))
	assert_null(_plate(ME), "自己没有铭牌")
	assert_eq(screen.director.camera_mode(), PokerDirector.MODE_SEAT)
	assert_true(screen.director.is_at_seat())
	# 自己跟注 → 小盲弃牌 → 大盲过牌 → 收注 → 翻牌 → 轮到大盲
	assert_true(screen.submit(PokerRules.CALL))
	assert_false(screen.is_my_turn(), "等回执")
	var flop := H.cards("Qc 7h 2s")
	await _feed([_bet(ME, PokerRules.CALL, 20), _bet(2, PokerRules.FOLD, 10), _bet(3, PokerRules.CHECK, 20), _collect(),
		{"type": "street", "street": PokerRules.FLOP, "cards": flop, "board": flop}, {"type": "turn", "pid": 3}],
		_pub(3, {"street": PokerRules.FLOP, "board": flop, "pots": [{"amount": 50, "eligible": [1, 3]}], "current_bet": 0}),
		{"hand": 1, "hole": hole, "best": {"detail": "高牌 · A", "cards": hole + flop}})
	assert_false(screen.is_my_turn())
	assert_eq(screen.cards.board_cards().size(), 3)
	assert_eq(screen.hud.board_strip.cards(), flop)
	assert_eq(screen.chips.pot_amounts(), [50])
	assert_eq(screen.cards.muck_cards().size(), 2, "弃的牌在弃牌堆")
	assert_eq(screen.hud._best_label.text, "高牌 · A")
	assert_eq(screen.state.row(3)["status"], PokerRules.STATUS_ACTIVE)
	# 大盲全下,自己跟注全下 → 亮牌 → 发完转牌河牌 → 分池 → 自己输光
	await _feed([_bet(3, PokerRules.RAISE, 1980, true), {"type": "turn", "pid": ME}], _pub(ME, {"street": PokerRules.FLOP, "board": flop,
		"pots": [{"amount": 50, "eligible": [1, 3]}], "current_bet": 1980}))
	assert_true(screen.is_my_turn())
	assert_eq(screen.state.row(3)["status"], PokerRules.STATUS_ALLIN)
	var turn := H.cards("Qd")
	var river := H.cards("9s")
	var board := flop + turn + river
	shown[3] = H.cards("Qh Qs")
	shown[ME] = hole
	var win := _bet(ME, PokerRules.CALL, 1980, true)
	stacks[3] = 4010
	stacks[2] = 1990
	stacks[ME] = 0
	statuses[ME] = PokerRules.STATUS_BUSTED
	await _feed([win, {"type": "bets_collected", "pots": [{"amount": 4010, "eligible": [1, 3]}], "refund": {}},
		{"type": "reveal", "hands": [{"pid": 3, "cards": shown[3]}, {"pid": ME, "cards": hole}], "reason": "allin"},
		{"type": "street", "street": PokerRules.TURN, "cards": turn, "board": flop + turn},
		{"type": "street", "street": PokerRules.RIVER, "cards": river, "board": board},
		{"type": "pot_won", "index": 0, "amount": 4010, "winners": [3], "shares": {3: 4010}, "hand_name": "四条 · Q",
			"best": {3: H.cards("Qc Qd Qh Qs 9s")}, "uncontested": false},
		{"type": "hand_over", "hand": 1, "stacks": {1: 0, 2: 1990, 3: 4010}, "busted": [1]}],
		_pub(null, {"street": PokerRules.SHOWDOWN, "board": board, "current_bet": 0}), {"hand": 1, "hole": hole, "best": {}})
	assert_eq(screen.my_status(), PokerRules.STATUS_BUSTED)
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_BUST, "输光提示")
	assert_gt(screen._bust_left, 0.0, "带倒计时")
	assert_eq(screen.chips.stack_amount(3), 4010)
	assert_eq(screen.chips.pot_amounts(), [])
	assert_eq(screen.cards.shown_cards(3).size(), 2, "亮出的牌摊在座位前")
	assert_false(screen.state.in_showdown, "hand_over 后摊牌条收起")
	assert_false(screen.is_my_turn())
	# 观战:酒客本机隐藏、镜头到观战机位;随后再领回座
	statuses[ME] = PokerRules.STATUS_SPECTATING
	await _feed([{"type": "spectate", "pid": ME}], _pub(null, {"street": PokerRules.SHOWDOWN, "board": board, "current_bet": 0}))
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_SPECTATE)
	assert_false(app.world.patrons[ME].visible)
	await wait_until(func(): return screen.director.is_camera_at_rest(), MAX_WAIT)
	assert_eq(screen.director.camera_mode(), PokerDirector.MODE_OVERVIEW)
	assert_false(screen.director.is_at_seat())
	statuses[ME] = PokerRules.STATUS_WAITING
	stacks[ME] = 2000
	stacks[9] = 2000
	statuses[9] = PokerRules.STATUS_WAITING
	bets[9] = 0
	shown[9] = []
	await _feed([{"type": "player_joined", "pid": 9, "name": "迟到"}, {"type": "rebuy", "pid": ME, "amount": 2000, "buyins": 2, "stack": 2000}],
		_pub(null, {"street": PokerRules.SHOWDOWN, "board": board, "current_bet": 0}))
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_WAITING)
	assert_true(app.world.patrons[ME].visible)
	assert_eq(screen.chips.stack_amount(ME), 2000)
	assert_false(_live_patrons().has(9), "新人下一手才登场")
	assert_eq(screen.name_of(9), "迟到")
	await wait_until(func(): return screen.director.is_camera_at_rest(), MAX_WAIT)
	assert_eq(screen.director.camera_mode(), PokerDirector.MODE_SEAT)
	# 乙离开(不在手牌中):酒客离场、铭牌收走;下一手按新座位表重排,新人登场
	stacks.erase(2)
	seats = [1, 3]
	await _feed([{"type": "player_left", "pid": 2, "folded": false}], _pub(null, {"street": PokerRules.SHOWDOWN, "board": board, "current_bet": 0}))
	await wait_process_frames(2)
	assert_false(_live_patrons().has(2))
	assert_null(_plate(2))
	seats = [1, 3, 9]
	for pid in seats:
		statuses[pid] = PokerRules.STATUS_ACTIVE
		shown[pid] = []
	var hole2 := H.cards("7c 7d")
	await _feed([{"type": "hand_started", "hand": 2, "button": 3, "sb": 9, "bb": 1, "seats": [1, 3, 9], "dealt": [9, 1, 3]},
		_blind(9, "sb", 10), _blind(ME, "bb", 20), {"type": "hole_cards", "hand": 2, "pids": [9, 1, 3]}, {"type": "turn", "pid": 3}],
		_pub(3, {"hand": 2, "button": 3, "sb": 9, "bb": 1}), {"hand": 2, "hole": hole2, "best": {}})
	assert_eq(_live_patrons().size(), 3)
	assert_true(_live_patrons().has(9))
	assert_not_null(_plate(9))
	assert_not_null(_plate(3))
	assert_eq(screen.chips.button_pid(), 3)
	assert_eq(screen.cards.board_cards().size(), 0, "上一手的公共牌收走")
	assert_eq(screen.cards.shown_cards(3).size(), 0)
	assert_eq(screen.hud.my_strip.cards(), hole2)
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_BET, "看别人的回合横幅")
	assert_false(screen.is_my_turn())
	# 房主散局:本手结束后结算;对手都弃牌,自己赢;结算面板
	await _feed([{"type": "ending"}], _pub(3, {"hand": 2, "button": 3, "sb": 9, "bb": 1, "ending": true}))
	assert_true(screen.hud.end_button.disabled)
	assert_eq(screen.hud.end_button.text, PokerHud.ENDING_TEXT)
	var results := [{"pid": 3, "name": "丙", "stack": 4010, "buyins": 1, "net": 2010, "left": false},
		{"pid": 1, "name": "我", "stack": 2030, "buyins": 2, "net": -1970, "left": false},
		{"pid": 9, "name": "迟到", "stack": 1990, "buyins": 1, "net": -10, "left": false},
		{"pid": 2, "name": "乙", "stack": 1990, "buyins": 1, "net": -10, "left": true}]
	var folds := [_bet(3, PokerRules.FOLD, 0), _bet(9, PokerRules.FOLD, 10)]
	stacks[ME] = 2030
	for pid in seats:
		bets[pid] = 0
	await _feed(folds + [{"type": "bets_collected", "pots": [{"amount": 30, "eligible": [1]}], "refund": {}},
		{"type": "pot_won", "index": 0, "amount": 30, "winners": [1], "shares": {1: 30}, "hand_name": "", "best": {}, "uncontested": true},
		{"type": "hand_over", "hand": 2, "stacks": {1: 2030, 3: 4010, 9: 1990}, "busted": []},
		{"type": "session_over", "results": results}],
		_pub(null, {"hand": 2, "phase": "over", "button": 3, "sb": 9, "bb": 1, "ending": true, "results": results, "current_bet": 0}))
	assert_not_null(screen._settlement, "结算面板")
	assert_eq(screen._settlement._ranking[0]["name"], "丙")
	assert_false(screen.is_my_turn())
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_NONE)
	assert_eq(screen.chips.stack_amount(ME), 2030)
	# 退场:拆台,铭牌收走,酒客留给等待厅(屏幕本身由 autofree 释放)
	remove_child(screen)
	await wait_process_frames(2)
	assert_eq(app.world.poker_root.get_child_count(), 0, "TableWorld 下没有德州节点")
	assert_eq(app.world.patrons[ME].fan.get_child_count(), 0, "牌扇里没有德州的牌")
	assert_null(_plate(3))
	assert_eq(_live_patrons().size(), 3)


func test_late_joiner_first_frame_comes_from_the_view_and_queued_events_are_dropped():
	# 翻牌后加入:开场运镜期间到达的 player_joined / action / street 事件丢掉,按视图把桌子瞬时摆好(规格 §7)
	_open_table([2, 3], true)
	assert_true(screen.late)
	stacks[ME] = 2000
	statuses[ME] = PokerRules.STATUS_WAITING
	bets[ME] = 0
	shown[ME] = []
	var flop := H.cards("Qc 7h 2s")
	bets[2] = 40
	stacks[2] = 1960
	stacks[3] = 1980
	shown[3] = []
	screen._on_events([{"type": "player_joined", "pid": ME, "name": "我"}])
	screen._on_events([_bet(2, PokerRules.RAISE, 40), {"type": "turn", "pid": 3}])
	await _feed([{"type": "street", "street": PokerRules.FLOP, "cards": flop, "board": flop}],
		_pub(3, {"street": PokerRules.FLOP, "board": flop, "pots": [{"amount": 40, "eligible": [2, 3]}], "current_bet": 40, "button": 2, "sb": 2, "bb": 3}),
		{"hand": 1, "hole": [], "best": {}})
	assert_eq(_live_patrons().size(), 2, "迟到者不建自己的酒客")
	assert_false(app.world.patrons.has(ME))
	assert_eq(app.world.seat_angles.size(), 3, "按「座位表 + 自己」排座:自己的座位空着")
	assert_eq(screen.cards.board_cards().size(), 3, "按视图摆好公共牌")
	assert_eq(screen.chips.bet_amount(2), 40)
	assert_eq(screen.chips.pot_amounts(), [40])
	assert_eq(screen.state.current_pid, 3)
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_WAITING)
	assert_eq(screen.hud.my_strip.cards(), [])
	assert_eq(screen.director.camera_mode(), PokerDirector.MODE_OVERVIEW)
	assert_null(_plate(ME))
	assert_not_null(_plate(2))
	# 下一手入座:自己的酒客登场,镜头回座位(运镜算在 hand_started 里)
	seats = [2, 3, 1]
	bets[2] = 0
	bets[3] = 0
	for pid in seats:
		statuses[pid] = PokerRules.STATUS_ACTIVE
	var hole := H.cards("Ah Kd")
	await _feed([{"type": "hand_started", "hand": 2, "button": 3, "sb": 1, "bb": 2, "seats": [2, 3, 1], "dealt": [1, 2, 3]},
		_blind(ME, "sb", 10), _blind(2, "bb", 20), {"type": "hole_cards", "hand": 2, "pids": [1, 2, 3]}, {"type": "turn", "pid": 3}],
		_pub(3, {"hand": 2, "button": 3, "sb": 1, "bb": 2}), {"hand": 2, "hole": hole, "best": {}})
	assert_true(app.world.patrons.has(ME))
	assert_eq(_live_patrons().size(), 3)
	assert_eq(screen.chips.bet_amount(ME), 10)
	assert_eq(screen.hud.my_strip.cards(), hole)
	assert_eq(screen.director.camera_mode(), PokerDirector.MODE_SEAT)
	assert_eq(screen.hud.bottom_mode(), PokerHud.BOTTOM_BET)


func test_events_missing_their_preconditions_do_not_break_the_show():
	# 规格 §7 的导演容错:没有下注堆的收注、手里没牌的弃牌与亮牌、前面槽位空着的河牌、没酒客的人的动作
	_open_table([1, 2], false)
	var river := H.cards("9s")
	shown[2] = H.cards("Qh Qs")
	await _feed([{"type": "bets_collected", "pots": [{"amount": 0, "eligible": []}], "refund": {"pid": 7, "amount": 50}},
		{"type": "action", "pid": 42, "action": PokerRules.FOLD, "amount": 0, "bet": 0, "stack": 0, "all_in": false},
		{"type": "reveal", "hands": [{"pid": 2, "cards": shown[2]}, {"pid": 42, "cards": []}], "reason": "showdown"},
		{"type": "street", "street": PokerRules.RIVER, "cards": river, "board": river},
		{"type": "action", "pid": 42, "action": PokerRules.CALL, "amount": 20, "bet": 20, "stack": 0, "all_in": true},
		{"type": "pot_won", "index": 3, "amount": 10, "winners": [42], "shares": {42: 10}, "hand_name": "", "best": {}, "uncontested": true},
		{"type": "rebuy", "pid": 42, "amount": 2000, "buyins": 1, "stack": 2000}, {"type": "player_left", "pid": 42, "folded": true},
		{"type": "away", "pid": 2}, {"type": "sit_in", "pid": 2}, {"type": "hand_over", "hand": 1, "stacks": {}, "busted": []},
		{"type": "mystery"}],
		_pub(null, {"current_bet": 0}))
	assert_false(screen.animating)
	assert_eq(_live_patrons().size(), 2)
	assert_eq(screen.cards.shown_cards(2).size(), 2, "手里没牌也在座位前现出亮牌")
	assert_eq(screen.cards.board_cards().size(), 0, "对账后按视图:没有公共牌")
