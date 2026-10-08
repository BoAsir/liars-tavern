class_name BombCatDirector
extends Node
# 炸弹猫演出导演(规格 §3.1):把阶段一的公共事件(设计稿 §7.3)翻译成镜头、酒客动作、牌的动画(BombCatCards)、
# 特效、音效、宣告与日志。每段演出的实际时长不超过 BombCatPacing 的预算(房主据此延长计时),
# 由 test_bomb_cat_director 读这里与 BombCatCards 的节奏常量来保证。
# 常驻机位两种:自己座位(越肩 / 第一人称,V 切换,共用 SeatCamera)与出局后的观战俯视;
# 摸到炸弹时推近到摸牌人的特写,拆完 / 塞回 / 爆炸后回到常驻机位;胜利时环绕胜者。
# 只有当事人看得到的东西(自己摸到的牌、偷看的三张、转手的那张)从私有视图取,别人看到的是牌背。


signal event_started(ev: Dictionary)   # 每段演出开始时发出(调试截图与 bot 日志按它取景)

const INTRO_MOVE := BombCatPacing.INTRO - 0.1
const CAMERA_MOVE := 0.8              # 常驻机位之间的运镜(出局后转观战不等它走完)
const DEAL_PRIVATE_WAIT := 0.4        # 发牌前最多再等私有手牌这么久(通常同一帧就到了)
const PLAY_HOLD := 0.1                # 出牌:牌落到弃牌堆后再停一下
const NOPE_HOLD := 0.2
const RESOLVE_PAUSE := 0.22
const SKIP_PAUSE := 0.22
const PASS_PAUSE := 0.45
const PEEK_PAUSE := 0.95
const SHUFFLE_TAIL := 0.05
const TRANSFER_TAIL := 0.05
const MISS_PAUSE := 0.38
const GIVE_PAUSE := 0.3
const DRAW_TAIL := 0.0
const PRIVATE_WAIT := 0.1             # 自己摸牌 / 转手 / 偷看时最多等私有视图这么久(通常同一帧就到了;算在各段预算里)
const BOMB_PUSH := 0.5                # 摸到炸弹:镜头推近
const BOMB_HOLD := 1.15               # 推近之后:火花、心跳
const SNIP_TIME := Patron.SNIP_TIME   # 拆弹:手忙脚乱剪线
const DEFUSE_RELIEF := 0.4            # 「咔嚓」之后松一口气
const REINSERT_TAIL := 0.05
const EXPLODE_HOLD := 2.2             # 轰!之后:黑脸冒烟、蚊香眼转成 ×
const SMOKE_AGAIN := 0.7              # 第二缕头顶黑烟
const CAMERA_BACK := 0.6              # 特写之后回到常驻机位
const LEFT_PAUSE := 0.7
const MATCH_HOLD := 2.2
const TABLE_FOCUS := BombCatLayout.TABLE_FOCUS   # 酒客平时看向桌心的两摞牌
const BUBBLE_KEY := "bubble:%d"
const BUBBLE_ABOVE_PLATE := -66.0
const MODE_SEAT := "seat"
const MODE_OVERVIEW := "overview"
const MODE_CLOSE := "close"
const MODE_ORBIT := "orbit"
const EXPLOSION_FLASH := Color(1.0, 0.82, 0.55, 0.8)
# 导演认得的公共事件(设计稿 §7.3 全部 14 种;测试核对与 BombCatPacing 一一对应)
const HANDLED_EVENTS := ["round_started", "played", "noped", "window_resolved", "effect", "give_requested", "drew",
	"bomb_drawn", "defused", "reinserted", "exploded", "player_left", "turn_passed", "match_over"]
const SHOUTS := {
	BombCatCard.SKIP: "溜了~", BombCatCard.PASS_TURNS: "甩锅!", BombCatCard.PEEK: "偷看一下…",
	BombCatCard.SHUFFLE: "洗洗更健康", BombCatCard.BEG: "给我一张嘛",
}

var screen: Node        # BombCatScreen
var app: Node
var world: TableWorld
var cards: BombCatCards
var rig: CameraRig
var fx: PostFx
var hud: BombCatHud
var seat_camera: SeatCamera
var spectator := false
var _mode := ""
var _settled := false
var _camera_serial := 0


func _init(p_screen: Node, p_app: Node, p_hud: BombCatHud) -> void:
	screen = p_screen
	app = p_app
	hud = p_hud
	world = p_screen.world
	cards = p_screen.cards
	rig = app.tavern.camera_rig
	fx = app.get("post_fx")
	var path = app.get("settings_path")
	seat_camera = SeatCamera.new(rig, world, screen.my_pid, path if path is String else Settings.PATH)
	add_child(seat_camera)


# —— 纯逻辑 ——

static func played_text(ev: Dictionary, names: Callable) -> String:
	# 日志里的一次出牌:「阿狸 打出「讨要」→ 小熊」「阿狸 打出两张鱼干 → 小熊」「阿狸 打出三张鱼干,点名「拆弹」→ 小熊」
	var who: String = names.call(ev.get("pid"))
	var cards_played: Array = ev["cards"] if ev.get("cards") is Array else []
	var first: String = str(cards_played[0]) if not cards_played.is_empty() else ""
	var text := ""
	match str(ev.get("kind", "")):
		BombCatState.KIND_PAIR:
			text = "%s 打出两张%s" % [who, BombCatCard.display_name(first)]
		BombCatState.KIND_TRIPLE:
			text = "%s 打出三张%s,点名「%s」" % [who, BombCatCard.display_name(first), BombCatCard.display_name(str(ev.get("named", "")))]
		var kind:
			text = "%s 打出「%s」" % [who, BombCatCard.display_name(kind)]
	if ev.get("target") is int:
		text += " → %s" % names.call(ev["target"])
	return text


static func shout_for(ev: Dictionary) -> String:
	# 出牌人头顶的气泡
	var kind := str(ev.get("kind", ""))
	if SHOUTS.has(kind):
		return SHOUTS[kind]
	if kind == BombCatState.KIND_PAIR:
		return "两张%s!" % BombCatCard.display_name(str(ev["cards"][0])) if ev.get("cards") is Array and not ev["cards"].is_empty() else "抽一张!"
	if kind == BombCatState.KIND_TRIPLE:
		return "我要「%s」!" % BombCatCard.display_name(str(ev.get("named", "")))
	return BombCatCard.display_name(kind)


static func effect_text(ev: Dictionary, names: Callable) -> String:
	var pid: Variant = ev.get("pid")
	var got: bool = ev.get("got") is bool and ev["got"]
	match str(ev.get("kind", "")):
		BombCatCard.SKIP:
			return "%s 溜了,这回合不摸牌" % names.call(pid)
		BombCatCard.PASS_TURNS:
			return "%s 把锅甩给 %s:要连走 %d 回合" % [names.call(pid), names.call(ev.get("to")), int(ev.get("turns", 2))]
		BombCatCard.PEEK:
			return "%s 偷看了牌堆顶 %d 张" % [names.call(pid), int(ev.get("count", 0))]
		BombCatCard.SHUFFLE:
			return "%s 把牌堆洗乱了" % names.call(pid)
		BombCatCard.BEG:
			return "%s 给了 %s 一张牌" % [names.call(ev.get("from")), names.call(ev.get("to"))] if got \
				else "%s 没要到牌" % names.call(ev.get("to"))
		"steal":
			return "%s 从 %s 手里抽走一张" % [names.call(ev.get("to")), names.call(ev.get("from"))] if got \
				else "%s 没抽到牌" % names.call(ev.get("to"))
		"request":
			var named := BombCatCard.display_name(str(ev.get("named", "")))
			return "%s 交出了「%s」" % [names.call(ev.get("from")), named] if got \
				else "%s 手里没有「%s」" % [names.call(ev.get("from")), named]
	return ""


# —— 入口 ——

func intro() -> void:
	Sfx.play("whoosh")
	await settle_camera(INTRO_MOVE)


func play(ev: Dictionary) -> void:
	event_started.emit(ev)
	match ev.get("type", ""):
		"round_started":
			await _round_started(ev)
		"played":
			await _played(ev)
		"noped":
			await _noped(ev)
		"window_resolved":
			await _window_resolved(ev)
		"effect":
			await _effect(ev)
		"give_requested":
			await _give_requested(ev)
		"drew":
			await _drew(ev)
		"bomb_drawn":
			await _bomb_drawn(ev)
		"defused":
			await _defused(ev)
		"reinserted":
			await _reinserted(ev)
		"exploded":
			await _exploded(ev)
		"player_left":
			await _player_left(ev)
		"turn_passed":
			screen.note_event(ev)
			screen.set_current(ev.get("pid"), _int(ev, "turns"))
		"match_over":
			await _match_over(ev)


# —— 开局 ——

func _round_started(ev: Dictionary) -> void:
	screen.set_current(null)
	screen.note_event(ev)
	var order: Array = screen.state.seats.duplicate()
	var counts := {}
	var total := 0
	for row in (ev["hands"] if ev.get("hands") is Array else []):
		if row is Dictionary and row.get("pid") is int:
			counts[row["pid"]] = _int(row, "count")
			total += _int(row, "count")
	cards.sync({}, [], _int(ev, "deck_count") + total, 0, [])
	world.look_all_at(TABLE_FOCUS)
	var mine: Array = await screen.wait_private_hand(DEAL_PRIVATE_WAIT)
	hud.log_event("—— 炸弹猫开局 · 牌堆里藏着 %d 颗炸弹 ——" % _int(ev, "bombs"), UiTheme.BRASS)
	hud.announce("炸弹猫", UiTheme.BRASS_BRIGHT, "牌堆里藏着 %d 颗炸弹,摸到就炸飞!" % _int(ev, "bombs"), 1.0)
	await cards.deal(order, counts, mine)
	screen.sync_table()
	screen.set_current(ev.get("current"), _int(ev, "turns"))


# —— 出牌与反应窗口 ——

func _played(ev: Dictionary) -> void:
	var pid: Variant = ev.get("pid")
	var played: Array = ev["cards"].filter(BombCatCard.is_valid) if ev.get("cards") is Array else []
	var indices: Array = screen.take_submitted() if pid == screen.my_pid else []
	if pid == screen.my_pid:
		indices = screen.state.take_from_shown(played, indices)
		screen.refresh_my_hand()
	screen.note_event(ev)
	_reach(pid)
	_bubble(pid, shout_for(ev))
	hud.log_event(played_text(ev, screen.name_of))
	if ev.get("target") is int:
		_look_all(world.head_position(ev["target"]))
		if ev["target"] == screen.my_pid:
			hud.announce("冲你来的!", UiTheme.LIE, played_text(ev, screen.name_of), 0.6)
	else:
		_look_all(TABLE_FOCUS)
	if pid is int:
		await cards.play(pid, played, indices)
	await _wait(PLAY_HOLD)


func _noped(ev: Dictionary) -> void:
	var pid: Variant = ev.get("pid")
	if pid == screen.my_pid:
		screen.state.remove_from_shown(BombCatCard.NOPE)
		screen.refresh_my_hand()
	screen.note_event(ev)
	var depth := _int(ev, "depth")
	var text := "不行!" if depth % 2 == 1 else "不行不行!"
	_bubble(pid, text, UiTheme.BLOOD)
	hud.log_event("%s 打出「不行!」(第 %d 张)" % [screen.name_of(pid), depth], UiTheme.LIE)
	hud.announce(text, UiTheme.LIE, "%s 拍桌" % ("你" if pid == screen.my_pid else screen.name_of(pid)), 0.45)
	if pid is int and world.patrons.has(pid):
		world.patrons[pid].slam_table()
		_look_all(world.head_position(pid))
	rig.shake(0.3)
	_startle_all(pid)
	if pid is int:
		await cards.nope_slam(pid)
	app.tavern.kick_lamp(0.05)
	await _wait(NOPE_HOLD)


func _window_resolved(ev: Dictionary) -> void:
	screen.note_event(ev)
	if ev.get("aborted") is bool and ev["aborted"]:
		hud.log_event("出牌的人走了,这张牌作废", UiTheme.MUTED)
		await _wait(RESOLVE_PAUSE)
		return
	if ev.get("effective") is bool and ev["effective"]:
		cards.pulse_top(Color(1.0, 0.82, 0.4), 1.6, 0.4)
		if _int(ev, "nopes") > 0:
			hud.log_event("「不行!」被不行掉了,原牌照样生效", UiTheme.BRASS)
	else:
		cards.pulse_top(Color(1.0, 0.25, 0.15), 2.0, 0.4)
		hud.log_event("%s 的「%s」作废了" % [screen.name_of(ev.get("pid")), _kind_name(str(ev.get("kind", "")))], UiTheme.LIE)
		_express(ev.get("pid"), "angry")
	await _wait(RESOLVE_PAUSE)


func _effect(ev: Dictionary) -> void:
	var kind := str(ev.get("kind", ""))
	var text := effect_text(ev, screen.name_of)
	var got: bool = ev.get("got") is bool and ev["got"]
	match kind:
		BombCatCard.SKIP:
			screen.note_event(ev)
			hud.log_event(text, UiTheme.PARCHMENT_DIM)
			await _wait(SKIP_PAUSE)
		BombCatCard.PASS_TURNS:
			screen.note_event(ev)
			hud.log_event(text, UiTheme.BRASS)
			var to: Variant = ev.get("to")
			_bubble(to, "啊?!", UiTheme.LIE)
			_startle(to)
			_express(to, "worried")
			_look_all(world.head_position(to) if to is int else TABLE_FOCUS)
			if to == screen.my_pid:
				hud.announce("锅甩到你头上了!", UiTheme.LIE, "要连走 %d 回合" % _int(ev, "turns"), 0.5)
			await _wait(PASS_PAUSE)
		BombCatCard.PEEK:
			screen.note_event(ev)
			hud.log_event(text, UiTheme.PARCHMENT_DIM)
			var pid: Variant = ev.get("pid")
			if pid is int and world.patrons.has(pid):
				world.patrons[pid].cover_mouth()
			if pid == screen.my_pid:
				await screen.wait_peek(PRIVATE_WAIT)
				screen.show_peek()
				await _wait(maxf(PEEK_PAUSE - PRIVATE_WAIT, 0.0))
			else:
				await _wait(PEEK_PAUSE)
		BombCatCard.SHUFFLE:
			screen.note_event(ev)
			screen.clear_peek()
			hud.log_event(text, UiTheme.PARCHMENT_DIM)
			_look_all(TABLE_FOCUS)
			await cards.shuffle()
			await _wait(SHUFFLE_TAIL)
		BombCatCard.BEG, "steal", "request":
			var from: Variant = ev.get("from")
			var to: Variant = ev.get("to")
			hud.log_event(text, UiTheme.BRASS if got else UiTheme.MUTED)
			if not got:
				screen.note_event(ev)
				_bubble(to, "切~")
				_express(to, "angry")
				await _wait(MISS_PAUSE)
				return
			var id := ""
			if from == screen.my_pid or to == screen.my_pid:
				var record: Dictionary = await screen.wait_transfer(PRIVATE_WAIT)
				id = str(record.get("card", ""))
				if from == screen.my_pid:
					screen.state.remove_from_shown(id)
				else:
					screen.state.add_to_shown(id)
				if to == screen.my_pid:
					hud.announce("拿到「%s」" % BombCatCard.display_name(id), UiTheme.BRASS_BRIGHT, "从 %s 手里" % screen.name_of(from), 0.5)
				else:
					hud.announce("被拿走「%s」" % BombCatCard.display_name(id), UiTheme.LIE, "给了 %s" % screen.name_of(to), 0.5)
			screen.note_event(ev)
			if kind == "request":
				_bubble(from, "给你给你…")
			_look_all(world.head_position(to) if to is int else TABLE_FOCUS)
			if from is int and to is int:
				await cards.transfer(from, to, id)
			screen.refresh_my_hand(to == screen.my_pid)
			await _wait(TRANSFER_TAIL)
		_:
			screen.note_event(ev)


func _give_requested(ev: Dictionary) -> void:
	screen.note_event(ev)
	var giver: Variant = ev.get("pid")
	var asker: Variant = ev.get("to")
	_bubble(asker, "给我一张嘛~")
	_look_all(world.head_position(giver) if giver is int else TABLE_FOCUS)
	hud.log_event("%s 要 %s 挑一张牌给他" % [screen.name_of(asker), screen.name_of(giver)], UiTheme.PARCHMENT_DIM)
	if giver == screen.my_pid:
		hud.announce("%s 向你讨要一张牌" % screen.name_of(asker), UiTheme.BRASS_BRIGHT, "点一张手牌给他", 0.5)
	await _wait(GIVE_PAUSE)


# —— 摸牌与炸弹 ——

func _drew(ev: Dictionary) -> void:
	var pid: Variant = ev.get("pid")
	var bomb: bool = ev.get("bomb") is bool and ev["bomb"]
	screen.clear_peek()
	if bomb:
		screen.note_event(ev)
		return   # 紧跟着 bomb_drawn:炸弹牌由那一段翻起来
	var id := ""
	if pid == screen.my_pid:
		var drawn: Dictionary = await screen.wait_drawn(PRIVATE_WAIT)
		id = str(drawn.get("card", ""))
		screen.state.add_to_shown(id)
	screen.note_event(ev)
	hud.log_event("%s 摸了一张" % screen.name_of(pid), UiTheme.PARCHMENT_DIM)
	if pid is int:
		await cards.draw(pid, id, _int(ev, "deck_count"))
	if pid == screen.my_pid:
		screen.refresh_my_hand(true)
	await _wait(DRAW_TAIL)


func _bomb_drawn(ev: Dictionary) -> void:
	var pid: Variant = ev.get("pid")
	screen.note_event(ev)
	screen.set_current(null)
	hud.log_event("%s 摸到了炸弹!" % screen.name_of(pid), UiTheme.BLOOD)
	_startle_all(null)
	Sfx.play("fuse")
	if pid is int:
		_leave_rest(MODE_CLOSE)
		rig.move_to(BombCatLayout.bomb_view(world, pid), BOMB_PUSH)
		_look_all(world.head_position(pid))
		_express(pid, "worried")
		cards.reveal_bomb(pid, screen.state.deck_count)
	if fx != null:
		fx.set_tension(0.8, BOMB_PUSH)
	hud.announce("炸弹!", UiTheme.BLOOD, "你摸到了炸弹……" if pid == screen.my_pid else "%s 摸到了炸弹" % screen.name_of(pid), 0.9,
		BombCatHud.ANNOUNCE_Y_LOW)
	Sfx.play("heartbeat", 0.0)
	await _wait(BOMB_PUSH + 0.1)
	if fx != null:
		fx.pulse_aberration(1.4, 0.4)
	Sfx.play("heartbeat", 0.0)
	await _wait(BOMB_HOLD)


func _defused(ev: Dictionary) -> void:
	var pid: Variant = ev.get("pid")
	if pid == screen.my_pid:
		screen.state.remove_from_shown(BombCatCard.DEFUSE)
		screen.refresh_my_hand()
	screen.note_event(ev)
	hud.log_event("%s 用「拆弹」剪断了导火索" % screen.name_of(pid), UiTheme.TRUTH)
	if pid is int and world.patrons.has(pid):
		world.patrons[pid].snip_wires(SNIP_TIME)
		cards.play(pid, [BombCatCard.DEFUSE], [])
	await _wait(SNIP_TIME)
	Sfx.play("snip")
	cards.stop_sparks()
	if fx != null:
		fx.set_tension(0.0, 0.6)
	hud.announce("咔嚓!", UiTheme.TRUTH, "拆掉了,接着把炸弹偷偷塞回牌堆" if pid == screen.my_pid else "%s 拆掉了炸弹" % screen.name_of(pid), 0.6,
		BombCatHud.ANNOUNCE_Y_LOW)
	if pid is int and world.patrons.has(pid):
		world.patrons[pid].relief()
	await _wait(DEFUSE_RELIEF)


func _reinserted(ev: Dictionary) -> void:
	screen.note_event(ev)
	screen.clear_peek()
	hud.log_event("%s 把炸弹塞回了牌堆(不知道塞在哪)" % screen.name_of(ev.get("pid")), UiTheme.PARCHMENT_DIM)
	settle_camera(CAMERA_BACK)
	await cards.reinsert(_int(ev, "deck_count"))
	await _wait(REINSERT_TAIL)


func _exploded(ev: Dictionary) -> void:
	var pid: Variant = ev.get("pid")
	var mine: bool = pid == screen.my_pid
	screen.note_event(ev)
	hud.log_event("轰!%s 被炸飞了" % screen.name_of(pid), UiTheme.BLOOD)
	var where := cards.bomb_position()
	Sfx.play("boom", 0.02)
	Fx.explosion(world, where)
	cards.blow_bomb()
	rig.shake(1.0)
	app.tavern.kick_lamp(0.18)
	if fx != null:
		fx.flash(EXPLOSION_FLASH, 0.5)
		fx.set_tension(0.0, 1.2)
	_startle_all(pid)
	hud.announce("轰!", UiTheme.BLOOD, "你被炸飞了……" if mine else "%s 被炸飞了" % screen.name_of(pid), 1.4, BombCatHud.ANNOUNCE_Y_LOW)
	if mine:
		screen.state.shown_hand = []
		screen.refresh_my_hand()
	if pid is int:
		screen.mark_out(pid)
		cards.discard_hand(pid)
		if world.patrons.has(pid):
			var patron: Patron = world.patrons[pid]
			patron.die()
			patron.set_soot(1.0, 0.25)
			Fx.head_smoke(world, patron.head_position() + Vector3(0, 0.25, 0))
	await _wait(SMOKE_AGAIN)
	if pid is int and world.patrons.has(pid):
		Fx.head_smoke(world, world.patrons[pid].head_position() + Vector3(0, 0.25, 0))
	await _wait(EXPLODE_HOLD - SMOKE_AGAIN)
	if mine:
		spectator = true
	await settle_camera(CAMERA_BACK)


func _player_left(ev: Dictionary) -> void:
	var pid: Variant = ev.get("pid")
	screen.note_event(ev)
	hud.log_event("%s 离开了牌桌(断线出局)" % screen.name_of(pid), UiTheme.LIE)
	_bubble(pid, "……")
	if pid is int:
		screen.mark_out(pid)
		cards.discard_hand(pid)
		if world.patrons.has(pid):
			world.patrons[pid].die()
	if pid == screen.my_pid:
		spectator = true
		settle_camera(CAMERA_MOVE)
	Sfx.play("thud")
	await _wait(LEFT_PAUSE)


func _match_over(ev: Dictionary) -> void:
	screen.note_event(ev)
	screen.set_current(null)
	var winner: Variant = ev.get("winner")
	if fx != null:
		fx.set_tension(0.0, 0.6)
	_leave_rest(MODE_ORBIT)
	var title := "你赢了!" if winner == screen.my_pid else "%s 赢了" % screen.name_of(winner)
	hud.announce(title, UiTheme.BRASS_BRIGHT, "最后一个没被炸飞的", 1.8, BombCatHud.ANNOUNCE_Y_LOW)
	# 结算庆祝(规格 2026-10-09):胜者跳舞、活着的人鼓掌、炸飞的人倒着抽手、礼炮彩纸;开场小号与掌声由庆祝发出
	world.celebrate([winner] if winner is int else [], hash(["bomb_cat", winner, ev.get("ranking")]))
	if winner is int and world.patrons.has(winner):
		var focus := world.winner_orbit(winner)
		rig.set_fill(TableWorld.SEAT_FILL_LIGHT * 0.6, 1.0)
		rig.orbit(focus["center"], focus["radius"], focus["height"], focus["speed"], 1.4, focus["start"])
		_look_all(world.head_position(winner))
	else:
		var orbit := world.table_orbit()
		rig.orbit(orbit["center"], orbit["radius"], orbit["height"], orbit["speed"], 1.4)
	hud.log_event("胜者:%s" % screen.name_of(winner), UiTheme.BRASS_BRIGHT)
	await _wait(MATCH_HOLD)
	screen.show_settlement()


# —— 机位 ——

func is_at_seat() -> bool:
	return _settled and _mode == MODE_SEAT


func is_camera_at_rest() -> bool:
	return _settled and (_mode == MODE_SEAT or _mode == MODE_OVERVIEW)


func camera_mode() -> String:
	return _mode


func wanted_mode() -> String:
	return MODE_OVERVIEW if spectator else MODE_SEAT


func settle_camera(duration := CAMERA_MOVE) -> void:
	# 回到常驻机位(座位或观战),已在那里就不动;协程,调用方可以等也可以不等
	var wanted := wanted_mode()
	if wanted == _mode and _settled:
		return
	_leave_rest(wanted)
	var serial := _camera_serial
	if wanted == MODE_SEAT:
		seat_camera.enter(duration)
	else:
		rig.set_fill(0.0, duration)
		rig.move_to(world.overview_view(), duration)
	await _wait(duration)
	if serial == _camera_serial:
		_settled = true
		rig.parallax_enabled = wanted == MODE_SEAT
		hud.set_away_from_seat(false)


func _leave_rest(mode: String) -> void:
	_mode = mode
	_settled = false
	_camera_serial += 1
	rig.parallax_enabled = false
	seat_camera.leave()
	if mode == MODE_CLOSE or mode == MODE_ORBIT:
		hud.clear_my_bubble()
		hud.set_away_from_seat(true)


func toggle_camera_mode() -> void:
	var on := seat_camera.toggle()
	cards.present_my_fan()
	app.toast(SeatCamera.toast_text(on, seat_camera.is_seated()), UiTheme.PARCHMENT)


# —— 酒客与工具 ——

func _reach(pid: Variant) -> void:
	if pid is int and world.patrons.has(pid):
		world.patrons[pid].reach_toward_center()


func _express(pid: Variant, kind: String) -> void:
	if pid is int and world.patrons.has(pid) and world.patrons[pid].alive:
		world.patrons[pid].set_expression(kind)


func _startle(pid: Variant) -> void:
	if pid is int and world.patrons.has(pid):
		world.patrons[pid].startle()


func _startle_all(except_pid: Variant) -> void:
	for pid in world.patrons:
		if pid != except_pid and is_instance_valid(world.patrons[pid]):
			world.patrons[pid].startle()


func _look_all(point: Vector3) -> void:
	world.look_all_at(point)


func _bubble(pid: Variant, text: String, color := UiTheme.INK) -> void:
	if not pid is int:
		return
	if pid == screen.my_pid:
		hud.my_bubble(text, color)
		return
	if not world.patrons.has(pid):
		return
	var patron: Patron = world.patrons[pid]
	app.labels.track(BUBBLE_KEY % pid, SpeechBubble.new(text, color),
		func(): return patron.nameplate_anchor() if is_instance_valid(patron) else Vector3.ZERO,
		Vector2(0, BUBBLE_ABOVE_PLATE))


static func _kind_name(kind: String) -> String:
	match kind:
		BombCatState.KIND_PAIR:
			return "两张零食"
		BombCatState.KIND_TRIPLE:
			return "三张零食"
	return BombCatCard.display_name(kind)


static func _int(ev: Dictionary, key: String) -> int:
	var v: Variant = ev.get(key, 0)
	return v if v is int else 0


func _wait(seconds: float) -> void:
	if seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout
