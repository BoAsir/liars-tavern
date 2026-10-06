extends Control
# 牌桌控制器:接收 Net 的视图与事件 → 事件队列交给导演逐个演出(演出期间锁输入)→
# 演出结束后按最新状态对账。负责手牌拾取、快捷键、意图提交、倒计时与铭牌。


var app: Node
var my_pid := 0
var hud: TableHud
var director: TableDirector
var world: TableWorld
var cards: CardTable

var pub := {}
var names := {}
var animating := true
var current_pid = null
var turn_deadline := 0.0

var _queue: Array = []
var _intro_done := false
var _initial_hands := {}    # round -> 该局初始手牌(发牌动画使用)
var _my_hand: Array = []
var _selected := {}
var _hovered := -1
var _submitted: Array = []
var _awaiting_intent := false
var _dead := {}
var _shots := {}
var _elimination_order: Array = []
var _settlement: Settlement = null


func _init(p_app: Node) -> void:
	app = p_app


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	my_pid = Net.my_pid()
	world = app.world
	cards = world.cards
	for seat in Net.seats:
		names[seat["pid"]] = seat["name"]
		_shots[seat["pid"]] = 0
	world.revive_all()
	cards.clear_all()
	app.labels.clear()
	world.arrange(Net.seats, my_pid, false, true)
	cards.attach_hand(app.tavern.camera_rig.camera)
	hud = TableHud.new()
	add_child(hud)
	hud.play_pressed.connect(_submit_play)
	hud.challenge_pressed.connect(_submit_challenge)
	hud.set_my_status(names.get(my_pid, ""), 0, true)
	director = TableDirector.new(self, app, hud)
	add_child(director)
	_build_nameplates()
	Net.state_public_updated.connect(_on_public)
	Net.state_private_updated.connect(_on_private)
	Net.game_events.connect(_on_events)
	Net.intent_rejected.connect(_on_rejected)
	if not Net.last_public.is_empty():
		_on_public(Net.last_public)
	if not Net.last_private.is_empty():
		_on_private(Net.last_private)
	_refresh_actions()
	await director.intro()
	_intro_done = true
	_drain()


func _exit_tree() -> void:
	app.labels.clear()


func _process(_delta: float) -> void:
	var show_ring: bool = current_pid != null and not animating and not pub.is_empty()
	hud.set_countdown(turn_deadline - _now(), Protocol.TURN_TIMEOUT, show_ring)


# —— 网络输入 ——

func _on_public(state: Dictionary) -> void:
	pub = state
	if not animating:
		_reconcile()


func _on_private(state: Dictionary) -> void:
	_my_hand = state.get("hand", [])
	var round_number: int = state.get("round", 0)
	if not _initial_hands.has(round_number):
		_initial_hands[round_number] = _my_hand.duplicate()
	if not animating:
		_reconcile()


func _on_events(events: Array) -> void:
	_queue.append_array(events)
	if _intro_done and not animating:
		_drain()


func _on_rejected(code: String) -> void:
	_awaiting_intent = false
	_submitted = []
	app.toast(Protocol.ERROR_MESSAGES.get(code, code), UiTheme.LIE)
	_refresh_actions()


func _drain() -> void:
	animating = true
	_refresh_actions()
	while not _queue.is_empty():
		var ev: Dictionary = _queue.pop_front()
		await director.play(ev)
	animating = false
	_reconcile()
	_refresh_actions()


func _reconcile() -> void:
	# 演出结束后用最新状态兜底对齐(正常流程下视觉已与状态一致)
	if pub.is_empty():
		return
	var counts := {}
	for p in pub["players"]:
		counts[p["pid"]] = p["hand_count"] if p["alive"] else 0
	if not _dead.has(my_pid) and _settlement == null:
		cards.sync(counts, _my_hand)
		if _selected.keys().any(func(i): return i >= _my_hand.size()):
			_selected = {}
		cards.set_selection(_selected, _hovered)
	_update_nameplates()


# —— 导演回调 ——

func name_of(pid) -> String:
	return names.get(pid, "?")


func alive_order() -> Array:
	var order := []
	for seat in Net.seats:
		if not _dead.has(seat["pid"]):
			order.append(seat["pid"])
	return order


func initial_hand(round_number: int) -> Array:
	# 新一局的私有手牌通常紧随事件到达;最多等 3 秒
	var waited := 0.0
	while not _initial_hands.has(round_number) and waited < 3.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	return _initial_hands.get(round_number, _my_hand)


func take_submitted() -> Array:
	var indices := _submitted
	_submitted = []
	_awaiting_intent = false
	_selected = {}
	_hovered = -1
	return indices


func set_current(pid) -> void:
	current_pid = pid
	turn_deadline = _now() + Protocol.TURN_TIMEOUT
	_awaiting_intent = false
	# 所有人盯着当前行动者(轮到自己时盯着镜头),行动者自己看桌心
	var focus := cards.stand_position()
	if pid == my_pid:
		focus = app.tavern.camera_rig.camera.global_position
	elif pid != null:
		focus = world.head_position(pid)
	for patron_pid in world.patrons:
		var patron: Patron = world.patrons[patron_pid]
		patron.set_active(patron_pid == pid)
		patron.look_at_point(cards.stand_position() if patron_pid == pid else focus)
	if pid == null:
		hud.set_turn("", false)
	elif pid == my_pid:
		hud.set_turn("轮到你了", true)
		Sfx.play("join")
	else:
		hud.set_turn("等待 %s 行动…" % name_of(pid), false)
	_update_nameplates()
	_refresh_actions()


func on_gunshot_resolved(pid: int, shots_fired: int, hit: bool) -> void:
	_shots[pid] = shots_fired
	if hit:
		mark_eliminated(pid)
	_update_nameplates()
	if pid == my_pid:
		hud.set_my_status(name_of(my_pid), shots_fired, not hit)


func mark_eliminated(pid: int) -> void:
	if _dead.has(pid):
		return
	_dead[pid] = true
	_elimination_order.append(pid)
	if pid == my_pid:
		hud.set_my_status(name_of(my_pid), _shots.get(pid, 0), false)
		hud.set_actions_visible(false)


func is_marked_dead(pid: int) -> bool:
	return _dead.has(pid)


func show_settlement(winner) -> void:
	var ranking := [{"name": name_of(winner), "shots": _shots.get(winner, 0), "place": 1}]
	var place := 2
	for i in range(_elimination_order.size() - 1, -1, -1):
		var pid = _elimination_order[i]
		ranking.append({"name": name_of(pid), "shots": _shots.get(pid, 0), "place": place})
		place += 1
	hud.set_actions_visible(false)
	_settlement = Settlement.new(name_of(winner), ranking, winner == my_pid)
	add_child(_settlement)


# —— 铭牌 ——

func _build_nameplates() -> void:
	for seat in Net.seats:
		var pid: int = seat["pid"]
		if pid == my_pid or not world.patrons.has(pid):
			continue
		var patron: Patron = world.patrons[pid]
		app.labels.track("plate:%d" % pid, Nameplate.new(seat["name"]), patron.nameplate_anchor)
	_update_nameplates()


func _update_nameplates() -> void:
	var counts := {}
	if not pub.is_empty():
		for p in pub["players"]:
			counts[p["pid"]] = p["hand_count"]
	for seat in Net.seats:
		var pid: int = seat["pid"]
		var plate: Nameplate = app.labels.get_node_for("plate:%d" % pid)
		if plate == null:
			continue
		var held: int = cards.held.get(pid, []).size() if animating else counts.get(pid, 0)
		plate.set_info(held, _shots.get(pid, 0), not _dead.has(pid), pid == current_pid)


# —— 输入 ——

func _unhandled_input(event: InputEvent) -> void:
	if _settlement != null:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_confirm_leave()
		return
	if _dead.has(my_pid):
		return
	if event is InputEventMouseMotion:
		var index := _pick(event.position)
		if index != _hovered:
			_hovered = index
			if index >= 0:
				Sfx.play("ui_hover")
			cards.set_selection(_selected, _hovered)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var index := _pick(event.position)
		if index >= 0:
			get_viewport().set_input_as_handled()
			_toggle(index)
	elif event is InputEventKey and event.pressed and not event.echo:
		_handle_key(event)


func _handle_key(event: InputEventKey) -> void:
	var key := event.keycode
	if key >= KEY_1 and key <= KEY_5:
		_toggle(key - KEY_1)
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		_submit_play()
	elif key == KEY_C or key == KEY_SPACE:
		_submit_challenge()


func _pick(screen_pos: Vector2) -> int:
	if animating or cards.my_cards.is_empty():
		return -1
	var camera: Camera3D = app.tavern.camera_rig.camera
	return cards.pick(camera.project_ray_origin(screen_pos), camera.project_ray_normal(screen_pos))


func _toggle(index: int) -> void:
	if animating or _awaiting_intent or index >= cards.my_cards.size():
		return
	if _selected.has(index):
		_selected.erase(index)
	elif _selected.size() < Rules.MAX_PLAY:
		_selected[index] = true
	else:
		app.toast("一次最多出 %d 张" % Rules.MAX_PLAY, UiTheme.MUTED)
		return
	Sfx.play("ui_click")
	cards.set_selection(_selected, _hovered)
	_refresh_actions()


func _my_turn() -> bool:
	return current_pid == my_pid and not animating and not _awaiting_intent and _settlement == null


func _refresh_actions() -> void:
	if hud == null:
		return
	var mine := _my_turn()
	var can_play := mine and _selected.size() >= Rules.MIN_PLAY and _selected.size() <= Rules.MAX_PLAY
	var can_challenge: bool = mine and not pub.get("last_play", {}).is_empty()
	hud.set_actions(can_play, can_challenge, _selected.size(), mine)


func _submit_play() -> void:
	if not _my_turn() or _selected.is_empty():
		return
	var indices := _selected.keys()
	indices.sort()
	_submitted = indices
	_awaiting_intent = true
	Sfx.play("ui_click")
	Net.submit_play(indices)
	_refresh_actions()


func _submit_challenge() -> void:
	if not _my_turn() or pub.get("last_play", {}).is_empty():
		return
	_awaiting_intent = true
	Sfx.play("ui_click")
	Net.submit_challenge()
	_refresh_actions()


func _confirm_leave() -> void:
	var overlay: ConfirmOverlay = app.confirm("离开牌桌会被判出局,确定吗?" if not Net.is_host else "你是房主,离开会解散整桌,确定吗?", "离开")
	overlay.confirmed.connect(func():
		Net.leave()
		Net.left_lobby.emit(""))


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
