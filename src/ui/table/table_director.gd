class_name TableDirector
extends Node
# 演出导演:把网络事件翻译成镜头、角色动作、卡牌动画、音效与 HUD 宣告。
# 每段演出时长须不超过 Pacing 中的预算(房主据此延长回合计时)。


const BUBBLE_KEY := "bubble:%d"   # WorldLabels 里他人对话气泡的键
const INTRO_MOVE := 1.7           # 开局运镜到越肩机位的时长

var screen: Node        # TableScreen
var app: Node
var world: TableWorld
var cards: CardTable
var rig: CameraRig
var fx: PostFx
var hud: TableHud
var spectator := false
var _at_seat := false


func _init(p_screen: Node, p_app: Node, p_hud: TableHud) -> void:
	screen = p_screen
	app = p_app
	hud = p_hud
	world = app.world
	cards = world.cards
	rig = app.tavern.camera_rig
	fx = app.post_fx


func intro() -> void:
	rig.parallax_enabled = false
	Sfx.play("whoosh")
	rig.set_fill(TableWorld.SEAT_FILL_LIGHT, INTRO_MOVE)
	await rig.move_to(world.third_person_view(screen.my_pid), INTRO_MOVE, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT).finished
	rig.parallax_enabled = true
	_at_seat = true


func play(ev: Dictionary) -> void:
	match ev["type"]:
		"round_started":
			await _round_started(ev)
		"played":
			await _played(ev)
		"turn":
			screen.set_current(ev["pid"])
		"reveal":
			await _reveal(ev)
		"gunshot":
			await _gunshot(ev)
		"eliminated":
			await _eliminated(ev)
		"match_over":
			await _match_over(ev)


# —— 新一局 ——

func _round_started(ev: Dictionary) -> void:
	screen.set_current(null)
	screen.begin_round()
	if not _at_seat:
		# 强制验证为真话时没有开枪段,镜头还停在翻牌机位
		await back_to_seat(0.45)
	hud.set_target(ev["target"], ev["round"])
	await cards.sweep()
	hud.announce("第 %d 局" % ev["round"], UiTheme.BRASS_BRIGHT, "目标牌 ·「%s」" % Card.NAMES[ev["target"]], 0.9)
	hud.log_event("—— 第 %d 局 · 目标「%s」——" % [ev["round"], Card.NAMES[ev["target"]]], UiTheme.BRASS)
	await cards.set_target(ev["target"])
	var order: Array = screen.alive_order()
	var counts := {}
	for pid in order:
		counts[pid] = Deck.HAND_SIZE
	var my_hand: Array = []
	if order.has(screen.my_pid):
		my_hand = await screen.initial_hand(ev["round"])
	world.look_all_at(cards.stand_position())
	await cards.deal(order, counts, my_hand)
	screen.set_current(ev["starter"])


# —— 出牌 ——

func _played(ev: Dictionary) -> void:
	var pid: int = ev["pid"]
	var claim := "%d 张「%s」" % [ev["count"], Card.NAMES.get(cards.target_kind, "?")]
	if world.patrons.has(pid):
		world.patrons[pid].reach_toward_center()
	_bubble(pid, claim)
	hud.log_event("%s 打出 %s" % [screen.name_of(pid), claim])
	world.look_all_at(cards.stand_position())
	await cards.play(pid, ev["count"], screen.take_submitted() if pid == screen.my_pid else [])


# —— 质疑翻牌 ——

func _reveal(ev: Dictionary) -> void:
	screen.set_current(null)
	var liar: int = ev["pid"]
	var challenger = ev["challenger"]
	var kinds: Array = ev["cards"]
	if challenger == null:
		Sfx.play("bell")
		hud.announce("强制验证", UiTheme.BRASS_BRIGHT, "只剩 %s 有手牌,系统直接翻牌" % screen.name_of(liar), 0.8)
		hud.log_event("只剩 %s 有手牌,强制翻牌" % screen.name_of(liar), UiTheme.BRASS)
		await _wait(0.5)
	else:
		hud.log_event("%s 质疑 %s!" % [screen.name_of(challenger), screen.name_of(liar)], UiTheme.LIE)
		_bubble(challenger, "骗子!", UiTheme.BLOOD)
		world.look_all_at(world.head_position(challenger))
		if world.patrons.has(challenger):
			await world.patrons[challenger].slam_table()
		Sfx.play("slam")
		rig.shake(0.45)
		app.tavern.kick_lamp(0.07)
	_leave_seat()
	rig.move_to(world.reveal_view(), 0.55)
	await cards.gather_for_reveal(kinds.size())
	world.look_all_at(Vector3(0, SeatLayout.TABLE_TOP, CardTable.REVEAL_Z))
	for i in kinds.size():
		var matches := Card.matches(kinds[i], ev["target"])
		await cards.flip_revealed(i, kinds[i], matches)
		await _wait(0.4)
	if ev["honest"]:
		Sfx.play("sting_truth")
		hud.announce("没说谎!", UiTheme.TRUTH, "%s 句句属实" % screen.name_of(liar), 0.7)
	else:
		Sfx.play("sting_lie")
		hud.announce("骗子!", UiTheme.LIE, "%s 在撒谎" % screen.name_of(liar), 0.7)
		if world.patrons.has(liar):
			world.patrons[liar].set_expression("worried")
	await _wait(0.6)


# —— 开枪 ——

func _gunshot(ev: Dictionary) -> void:
	var shooter: int = ev["pid"]
	hud.log_event("%s 对自己扣下扳机(第 %d 枪)" % [screen.name_of(shooter), ev["shots_fired"]], UiTheme.PARCHMENT_DIM)
	fx.set_tension(0.55, 0.8)
	await _third_person_shot(shooter, ev["hit"])
	if shooter == screen.my_pid and ev["hit"]:
		# 自己中弹:画面短暂染红,之后以俯视镜头观战
		spectator = true
		await fx.fade_to(Color(0.25, 0.0, 0.0, 0.6), 0.45)
		fx.flash(Color(0.25, 0.0, 0.0, 0.6), 1.0)
	fx.set_tension(0.0, 0.7)
	screen.on_gunshot_resolved(shooter, ev["shots_fired"], ev["hit"])
	await back_to_seat(0.55)


func _third_person_shot(shooter: int, hit: bool) -> void:
	# 所有人(包括自己)都用同一套演出:镜头转到开枪者正面,角色拿枪抵住太阳穴
	_leave_seat()
	rig.move_to(world.focus_view(shooter), 0.7)
	world.look_all_at(world.head_position(shooter))
	var patron: Patron = world.patrons.get(shooter)
	var gun: Revolver3D = world.revolvers.get(shooter)
	if patron == null or gun == null:
		await _wait(1.5)
		_announce_shot(shooter, hit)
		return
	await patron.pick_up(gun, 0.28)
	Sfx.play("cock")
	gun.cock_hammer()
	await patron.raise_gun_to_head(gun, 0.42)
	await _suspense(gun)
	gun.release_hammer()
	if hit:
		_bang(gun.muzzle_transform())
		gun.recoil()
		patron.die(gun, world)
		_announce_shot(shooter, true)
		await _wait(1.0)
	else:
		Sfx.play("click")
		rig.shake(0.12)
		_announce_shot(shooter, false)
		patron.relief()
		await _wait(0.35)
		await patron.lower_gun(gun, world.revolver_rest(shooter), world, 0.3)


func _suspense(gun: Revolver3D) -> void:
	# 转轮 + 心跳 + 暗角收紧:整段约 1.4 秒
	Sfx.play("spin")
	gun.spin_drum(0.85, 2.0 + randf())
	fx.set_tension(1.0, 1.0)
	Sfx.play("heartbeat", 0.0)
	await _wait(0.72)
	Sfx.play("heartbeat", 0.0)
	fx.pulse_aberration(1.6, 0.4)
	await _wait(0.68)


func _bang(muzzle: Transform3D) -> void:
	Sfx.play("bang", 0.02)
	Fx.muzzle_flash(world, muzzle)
	Fx.smoke_puff(world, muzzle.origin, 22)
	fx.flash(Color(1.0, 0.85, 0.7, 0.75), 0.3)
	rig.shake(0.95)
	app.tavern.kick_lamp(0.14)


func _announce_shot(pid: int, hit: bool) -> void:
	var mine: bool = pid == screen.my_pid
	if hit:
		hud.announce("砰!", UiTheme.BLOOD, "你中弹了……" if mine else "%s 倒下了" % screen.name_of(pid), 1.0)
		hud.log_event("砰!%s 出局" % screen.name_of(pid), UiTheme.BLOOD)
	else:
		hud.announce("咔哒……", UiTheme.PARCHMENT, "空枪!你活下来了" if mine else "空枪!%s 逃过一劫" % screen.name_of(pid), 0.8)
		hud.log_event("咔哒,%s 是空枪" % screen.name_of(pid), UiTheme.PARCHMENT_DIM)


# —— 出局 / 结束 ——

func _eliminated(ev: Dictionary) -> void:
	var pid: int = ev["pid"]
	if screen.is_marked_dead(pid):
		return
	screen.mark_eliminated(pid)
	hud.log_event("%s 离开了牌桌(断线出局)" % screen.name_of(pid), UiTheme.LIE)
	_bubble(pid, "……")
	cards.drop_held(pid)
	if world.patrons.has(pid):
		world.patrons[pid].die()
	Sfx.play("thud")
	await _wait(0.8)


func _match_over(ev: Dictionary) -> void:
	screen.set_current(null)
	var winner = ev["winner"]
	fx.set_tension(0.0, 0.6)
	_leave_seat()
	Sfx.play("win")
	if winner == screen.my_pid:
		hud.announce("你赢了!", UiTheme.BRASS_BRIGHT, "活到了最后", 1.8)
	else:
		hud.announce("%s 赢了" % screen.name_of(winner), UiTheme.BRASS_BRIGHT, "活到了最后", 1.8)
	if world.patrons.has(winner):
		world.patrons[winner].celebrate()
		rig.orbit(world.head_position(winner) + Vector3(0, -0.2, 0), 1.3, 0.35, 0.25, 1.4)
	else:
		rig.orbit(Vector3(0, 0.95, 0), 2.4, 0.9, 0.18, 1.4)
	hud.log_event("胜者:%s" % screen.name_of(winner), UiTheme.BRASS_BRIGHT)
	await _wait(2.2)
	screen.show_settlement(winner)


# —— 工具 ——

func back_to_seat(duration: float) -> void:
	_at_seat = true
	if spectator:
		await rig.move_to(world.overview_view(), duration * 1.6).finished
		return
	rig.set_fill(TableWorld.SEAT_FILL_LIGHT, duration)
	await rig.move_to(world.third_person_view(screen.my_pid), duration).finished
	rig.parallax_enabled = true


func _leave_seat() -> void:
	_at_seat = false
	rig.parallax_enabled = false
	rig.set_fill(0.0, 0.5)


func _bubble(pid: int, text: String, color := UiTheme.INK) -> void:
	if pid == screen.my_pid:
		# 越肩镜头在自己头顶正上方,挂在自己头顶的气泡永远出画:改由 HUD 在出牌按钮上方显示
		hud.my_bubble(text, color)
		return
	if not world.patrons.has(pid):
		return
	var patron: Patron = world.patrons[pid]
	app.labels.track(BUBBLE_KEY % pid, SpeechBubble.new(text, color),
		func(): return patron.nameplate_anchor() + Vector3(0, 0.24, 0) if is_instance_valid(patron) else Vector3.ZERO)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
