extends GutTest
# 结算庆祝(规格 2026-10-09-winner-celebration):
# - 胜者跳舞:开始、停下,reset_pose 把身体、腿、帽子、牌扇、手臂都复原;挑哪支舞按物种 + 种子确定,每支都能跳完不出错;
# - 旁人:活着的鼓掌(两只爪子真的碰上),出局的人不鼓掌、仍然倒着,只偶尔抽一下手;
# - 礼炮与彩纸:开演时摆两门礼炮,第一炮两门齐发,之后轮流;收起时全部释放;场上彩纸 + 彩带不超过上限;
# - 德州平局:并列第一的人都跳;
# - 骗子酒馆导演的 match_over 开演(德州 / 炸弹猫的接入在各自的整局流程测试里断言)。


const FAST := 8.0
const STEP := 1.0 / 30.0

var world: TableWorld


func before_each():
	world = TableWorld.new(null)
	add_child_autofree(world)


func after_each():
	Engine.time_scale = 1.0


func _seat(pids: Array) -> void:
	world.arrange(pids.map(func(pid): return {"pid": pid}), pids[0], true, false)


func _drive(dance: PatronDance, seconds: float) -> void:
	# 不等真实帧:手动推进舞步(Patron 自己的待机在真实帧里照常跑)
	var t := 0.0
	while t < seconds:
		dance._process(STEP)
		t += STEP


func _paw(patron: Patron, side: float) -> Vector3:
	var arm: Node3D = patron._arm_r if side > 0.0 else patron._arm_l
	return arm.get_node("Hand").global_position


# —— 舞步 ——

func test_dance_starts_and_reset_pose_restores_everything():
	_seat([1, 2])
	var p: Patron = world.patrons[2]
	await wait_seconds(0.2)
	var hat_rest := p._hat.transform
	var fan_visible := p.fan.visible
	p.dance(PatronDance.HAT, 3)
	assert_true(p.is_dancing())
	assert_eq(p.dance_routine(), PatronDance.HAT)
	assert_true(p._arms_locked and p._sitting_up, "跳舞时坐直、手臂被舞步占着")
	assert_false(p.fan.visible, "牌扇收起来,免得手穿过牌")
	_drive(p._dance, 1.8)   # 第 1–3 拍帽子在天上
	assert_false(p._hat.transform.is_equal_approx(hat_rest), "帽子飞起来了")
	p.reset_pose()
	assert_false(p.is_dancing())
	assert_null(p._dance)
	assert_true(p._hat.transform.is_equal_approx(hat_rest), "帽子回到头上")
	assert_eq(p.body.position, Patron.HIP)
	assert_almost_eq(p.body.rotation.y, 0.0, 0.0001)
	assert_almost_eq(p.body.rotation.z, 0.0, 0.0001)
	assert_true(p._legs.transform.is_equal_approx(Transform3D.IDENTITY), "腿回到座位上")
	assert_eq(p.fan.visible, fan_visible)
	assert_false(p._arms_locked)
	await wait_process_frames(2)
	assert_true(p._resting[p._arm_l] and p._resting[p._arm_r], "双手搭回桌上")
	assert_eq(p.find_children("Dance", "", false, false).size(), 0, "舞步节点收走")


func test_stop_dance_mid_spin_puts_the_legs_and_body_back():
	_seat([1, 2])
	var p: Patron = world.patrons[2]
	p.dance(PatronDance.SPIN)
	_drive(p._dance, 2.6)   # 第 5 拍左右正在空中转圈
	assert_gt(absf(p.body.rotation.y), 0.3, "身体在转")
	assert_false(p._legs.transform.basis.is_equal_approx(Basis.IDENTITY), "腿跟着转")
	p.stop_dance()
	assert_true(p._legs.transform.is_equal_approx(Transform3D.IDENTITY))
	assert_eq(p.body.position, Patron.HIP)
	assert_almost_eq(p.body.rotation.y, 0.0, 0.0001)


func test_dance_choice_is_deterministic_per_seed_and_varies():
	var seen := {}
	for species in Species.count():
		for seed_value in 12:
			var routine := PatronDance.pick(species, seed_value)
			assert_eq(routine, PatronDance.pick(species, seed_value), "同物种同种子挑同一支")
			assert_true(PatronDance.ROUTINES.has(routine))
			seen[routine] = true
	assert_eq(seen.size(), PatronDance.ROUTINES.size(), "每支舞都会被挑到")


func test_every_routine_runs_for_a_full_cycle_on_every_species():
	# 16 拍(小鸡舞一整轮)≈ 7.7 秒:姿势始终有限、手臂四元数是单位长;停下后帽子回原位
	var players := []
	for i in Species.count():
		players.append({"pid": i + 1, "species": i})
	world.arrange(players, 1, true, true)
	for routine in PatronDance.ROUTINES:
		for pid in world.patrons:
			var p: Patron = world.patrons[pid]
			var hat_rest := p._hat.transform
			p.dance(routine)
			_drive(p._dance, 16.0 * 60.0 / PatronDance.BPM)
			for arm: Node3D in [p._arm_l, p._arm_r]:
				assert_almost_eq(arm.quaternion.length(), 1.0, 0.001, "%s 物种 %d 手臂" % [PatronDance.NAMES[routine], p.species_index])
			assert_true(p.body.position.is_finite() and p.body.rotation.is_finite())
			assert_lt(absf(p.body.position.y - Patron.HIP.y), 0.3, "屁股离座不超过 30 cm")
			p.stop_dance()
			assert_true(p._hat.transform.is_equal_approx(hat_rest), "%s:帽子复原" % PatronDance.NAMES[routine])


func test_dancer_gets_floating_notes_only_while_dancing():
	_seat([1, 2])
	var p: Patron = world.patrons[2]
	p.dance(PatronDance.WAVE)
	var notes := p.find_children("Notes", "MultiMeshInstance3D", true, false)
	assert_eq(notes.size(), 1)
	assert_eq(notes[0].cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	p.stop_dance()
	await wait_process_frames(2)
	assert_eq(p.find_children("Notes", "MultiMeshInstance3D", true, false).size(), 0)


func test_dead_patron_does_not_dance():
	_seat([1, 2])
	var p: Patron = world.patrons[2]
	p.die()
	p.dance(PatronDance.WAVE)
	assert_false(p.is_dancing())
	p.clap()
	assert_eq(p.dance_routine(), -1)


# —— 旁人 ——

func test_others_clap_and_the_dead_only_twitch():
	_seat([1, 2, 3, 4])
	await wait_seconds(0.1)
	world.patrons[4].die()
	var dead_body: Vector3 = world.patrons[4].body.rotation
	world.celebrate([2], 5)
	assert_true(world.patrons[2].is_dancing(), "胜者跳舞")
	for pid in [1, 3]:
		assert_eq(world.patrons[pid].dance_routine(), PatronDance.CLAP, "活着的 %d 鼓掌" % pid)
		assert_false(world.patrons[pid].is_dancing())
	assert_eq(world.patrons[4].dance_routine(), PatronDance.TWITCH, "出局的不鼓掌,只抽手")
	assert_false(world.patrons[4].alive)
	_drive(world.patrons[4]._dance, 6.0)
	assert_true(world.patrons[4].body.rotation.is_equal_approx(dead_body), "仍然倒着")


func test_clapping_paws_actually_meet():
	_seat([1, 2, 3])
	await wait_seconds(0.7)   # 登场缩放走完(从 0.01 倍放大)
	var p: Patron = world.patrons[3]
	p.clap(1)
	var dance := p._dance
	dance._clap_left = 50
	var closest := INF
	var widest := 0.0
	var t := 0.0
	while t < 1.5:
		dance._process(1.0 / 120.0)
		var gap := _paw(p, 1.0).distance_to(_paw(p, -1.0))
		closest = minf(closest, gap)
		widest = maxf(widest, gap)
		t += 1.0 / 120.0
	assert_lt(closest, Patron.PAW_RADIUS * 2.6, "两只爪子拍到一起")
	assert_gt(widest, 0.25, "拍手之间分得开")


func test_clapper_stops_and_rests_paws_on_the_table():
	_seat([1, 2])
	var p: Patron = world.patrons[1]
	p.clap()
	_drive(p._dance, 1.0)
	p.stop_dance()
	assert_false(p._arms_locked)
	assert_eq(p._antics.head_add, Vector3.ZERO)
	await wait_process_frames(2)
	assert_true(p._resting[p._arm_l] and p._resting[p._arm_r], "双手搭回桌上")


# —— 礼炮与彩纸 ——

func test_cannons_and_confetti_appear_and_are_freed_on_stop():
	_seat([1, 2, 3])
	var cel := world.celebrate([2])
	assert_true(world.is_celebrating())
	assert_eq(cel.cannons().size(), 2, "胜者两侧各一门礼炮")
	for cannon in cel.cannons():
		var mesh: MeshInstance3D = cannon.get_node("CannonMesh")
		assert_eq(mesh.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "特效件不投影")
		var to_winner: Vector3 = world.patrons[2].global_position - cannon.global_position
		assert_lt(Vector2(to_winner.x, to_winner.z).length(), 1.2, "礼炮在胜者面前的桌沿")
		assert_almost_eq(cannon.global_position.y, SeatLayout.FELT_TOP, 0.01, "摆在桌面上")
	cel._process(Celebration.FIRST_BURST + 0.01)
	assert_eq(cel.bursts(), 1)
	var confetti := cel.get_children().filter(func(n): return n is GPUParticles3D and n.is_in_group(&"confetti"))
	assert_eq(confetti.size(), 4, "第一炮两门齐发:每门彩纸 + 彩带")
	for node: GPUParticles3D in confetti:
		assert_eq(node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		assert_false(node.local_coords, "彩纸飘在世界里,不跟着礼炮走")
	assert_eq(cel.alive_confetti(), 2 * (Celebration.FIRST_CONFETTI + Celebration.FIRST_STREAMERS))
	var cannon0 := cel.cannons()[0]
	world.stop_celebration()
	assert_false(world.is_celebrating())
	assert_false(world.patrons[2].is_dancing(), "收起时舞步也停下")
	await wait_process_frames(2)
	assert_false(is_instance_valid(cel))
	assert_false(is_instance_valid(cannon0))
	for node in confetti:
		assert_false(is_instance_valid(node), "彩纸立刻收走")


func test_bursts_alternate_and_the_first_is_biggest():
	_seat([1, 2])
	var cel := world.celebrate([2])
	cel._process(Celebration.FIRST_BURST + 0.01)
	var first := cel.alive_confetti()
	var before := cel.get_child_count()
	cel._process(Celebration.BURST_EVERY)
	assert_eq(cel.bursts(), 2)
	var second := cel.get_children().slice(before).filter(func(n): return n is GPUParticles3D and n.is_in_group(&"confetti"))
	assert_eq(second.size(), 2, "之后每次只有一门开炮")
	var amount := 0
	for node in second:
		amount += node.amount
	assert_lt(amount, first / 2, "第一炮最大")


func test_confetti_budget_never_exceeds_the_cap():
	# 账面:按每股的寿命记账,任何时刻在场的彩纸 + 彩带不超过上限(时间跳着走,不等粒子真的结束)
	_seat([1, 2])
	var cel := world.celebrate([2])
	for i in 40:
		cel._process(0.5)
		var on_stage := 0
		for entry in cel._ledger:
			on_stage += entry[0]
		assert_lte(on_stage, Celebration.MAX_CONFETTI)
	assert_gt(cel.bursts(), 5)


func test_confetti_nodes_alive_stay_under_the_cap_in_real_time():
	# 真实帧(加速时钟)下数场上的粒子节点:结束的会自己释放,数量始终不超过上限
	_seat([1, 2])
	Engine.time_scale = FAST
	var cel := world.celebrate([2])
	var peak := 0
	var frames := 0
	while cel._t < 14.0 and frames < 2000:
		await get_tree().process_frame
		peak = maxi(peak, cel.alive_confetti())
		frames += 1
	assert_gt(cel.bursts(), 3)
	assert_gt(peak, 0)
	assert_lte(peak, Celebration.MAX_CONFETTI)


func test_revive_all_and_clear_stop_the_celebration():
	_seat([1, 2])
	world.celebrate([2])
	world.revive_all()
	assert_false(world.is_celebrating())
	assert_false(world.patrons[2].is_dancing())
	world.celebrate([2])
	world.clear()
	assert_false(world.is_celebrating())


func test_celebrating_again_replaces_the_previous_one():
	_seat([1, 2, 3])
	var first := world.celebrate([2])
	var second := world.celebrate([3])
	assert_ne(first, second)
	assert_false(world.patrons[2].is_dancing())
	assert_true(world.patrons[3].is_dancing())
	await wait_process_frames(2)
	assert_false(is_instance_valid(first))


func test_no_winner_patron_still_fires_from_the_table():
	_seat([1, 2])
	var cel := world.celebrate([99])
	assert_eq(cel.cannons().size(), 2)
	assert_eq(cel.dancers(), [])
	assert_eq(world.patrons[1].dance_routine(), PatronDance.CLAP)


func test_celebration_sounds_go_through_the_world_signal():
	_seat([1, 2])
	var heard := []
	world.sfx.connect(func(sound: String): heard.append(sound))
	var cel := world.celebrate([2])
	assert_has(heard, "fanfare")
	assert_has(heard, "applause")
	cel._process(Celebration.FIRST_BURST + 0.01)
	assert_has(heard, "cannon_pop")
	for sound in heard:
		assert_true(preload("res://src/ui/sfx.gd").VOLUMES.has(sound), "%s 有音量表项" % sound)


# —— 德州平局 ——

func test_poker_top_ranked_includes_everyone_tied_for_first():
	var rows := [{"pid": 3, "net": 1200}, {"pid": 5, "net": 1200}, {"pid": 1, "net": -400}, {"pid": 2, "net": -2000}]
	assert_eq(PokerDirector.top_ranked(rows), [3, 5])
	assert_eq(PokerDirector.top_ranked([{"pid": 4, "net": 10}, {"pid": 1, "net": 0}]), [4])
	assert_eq(PokerDirector.top_ranked([]), [])
	assert_eq(PokerDirector.top_ranked([{"pid": "x", "net": 9}, "bad", {"pid": 2}, {"pid": 6, "net": -5}]), [6], "坏行跳过")


func test_everyone_tied_dances():
	_seat([1, 3, 5, 7])
	world.celebrate(PokerDirector.top_ranked([{"pid": 3, "net": 800}, {"pid": 5, "net": 800}, {"pid": 1, "net": -1600}]))
	assert_true(world.patrons[3].is_dancing())
	assert_true(world.patrons[5].is_dancing())
	assert_eq(world.patrons[1].dance_routine(), PatronDance.CLAP)
	assert_eq(world.patrons[7].dance_routine(), PatronDance.CLAP)


# —— 骗子酒馆导演 ——

class StubApp:
	extends Node
	var world: TableWorld
	var tavern: Node
	var post_fx: PostFx = null
	var settings_path := "user://test_celebration_settings.cfg"

	func toast(_text: String, _color := Color.WHITE) -> void:
		pass


class StubTavern:
	extends Node
	var camera_rig: CameraRig


class StubScreen:
	extends Node
	var my_pid := 1
	var shown = null
	var _round_now := 3

	func set_current(_pid) -> void:
		pass

	func name_of(pid) -> String:
		return "P%s" % pid

	func show_settlement(winner) -> void:
		shown = winner


func test_liars_match_over_starts_the_celebration_and_keeps_the_settlement():
	_seat([1, 2, 3])
	world.patrons[3].die()
	var app := StubApp.new()
	add_child_autofree(app)
	app.world = world
	app.post_fx = PostFx.new()
	app.add_child(app.post_fx)
	var tavern := StubTavern.new()
	app.add_child(tavern)
	tavern.camera_rig = CameraRig.new()
	tavern.add_child(tavern.camera_rig)
	app.tavern = tavern
	var screen := StubScreen.new()
	add_child_autofree(screen)
	var hud := TableHud.new()
	add_child_autofree(hud)
	var director := TableDirector.new(screen, app, hud)
	add_child_autofree(director)
	Engine.time_scale = FAST
	director.play({"type": "match_over", "winner": 2})
	await get_tree().process_frame
	assert_true(world.is_celebrating(), "match_over 开演")
	assert_true(world.patrons[2].is_dancing(), "胜者跳舞")
	assert_eq(world.patrons[1].dance_routine(), PatronDance.CLAP, "自己没赢就鼓掌")
	assert_eq(world.patrons[3].dance_routine(), PatronDance.TWITCH)
	await wait_until(func(): return screen.shown != null, 3.0, "结算面板照常弹出")
	assert_eq(screen.shown, 2)
	assert_true(world.is_celebrating(), "结算面板出来后庆祝继续")
	assert_almost_eq(director.rig._orbit_frame, TableWorld.SETTLEMENT_FRAME, 0.0001, "环绕时胜者让到画面左边")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(app.settings_path))


# —— 结算面板停在右边、胜者让到画面左边 ——

static func _ndc_x(view: Transform3D, point: Vector3, aspect: float) -> float:
	var local := view.affine_inverse() * point
	return (local.x / -local.z) / (tan(deg_to_rad(CameraRig.DEFAULT_FOV) * 0.5) * aspect)


func test_framed_orbit_puts_the_center_where_asked():
	var view := Transform3D(Basis.looking_at(Vector3(0, 0, -1)), Vector3(0, 0, 2))
	for aspect in [16.0 / 9.0, 4.0 / 3.0]:
		var framed := CameraRig.framed(view, TableWorld.SETTLEMENT_FRAME, CameraRig.DEFAULT_FOV, aspect)
		assert_almost_eq(_ndc_x(framed, Vector3.ZERO, aspect), TableWorld.SETTLEMENT_FRAME, 0.001, "宽高比 %.2f" % aspect)
	assert_eq(CameraRig.framed(view, 0.0, CameraRig.DEFAULT_FOV, 1.5), view, "不偏就原样")


func test_celebration_orbit_frames_one_winner_a_close_pair_or_the_whole_table():
	world.configure_table(SeatLayout.POKER_TABLE_RADIUS)
	_seat([1, 2, 3, 4, 5, 6, 7, 8])
	await wait_seconds(0.7)
	var one := world.celebration_orbit([3])
	assert_almost_eq(one["center"].distance_to(world.head_position(3)), 0.25, 0.01, "绕着胜者的头")
	assert_eq(one["frame"], TableWorld.SETTLEMENT_FRAME)
	var pair := world.celebration_orbit([3, 4])
	var mid: Vector3 = (world.head_position(3) + world.head_position(4)) / 2.0
	assert_lt(Vector2(pair["center"].x - mid.x, pair["center"].z - mid.z).length(), 0.01, "挨着的两人绕他们的中点转")
	assert_gt(pair["radius"], one["radius"], "两人时拉远一点")
	var all := world.celebration_orbit([1, 2, 3, 4, 5, 6, 7, 8])
	assert_eq(all["radius"], world.table_orbit()["radius"], "全员平局:整桌环绕")
	assert_eq(all["frame"], TableWorld.SETTLEMENT_FRAME, "整桌环绕也让到左边")
	assert_eq(world.celebration_orbit([99])["radius"], world.table_orbit()["radius"], "胜者不在桌上:整桌环绕")


func test_winner_stays_left_of_the_docked_panel_while_orbiting():
	# 环绕到任意角度,胜者的头都落在画面左侧,不进右侧结算面板的停靠区(16:9 与 4:3)
	_seat([1, 2, 3])
	await wait_seconds(0.7)
	var orbit := world.celebration_orbit([2])
	for aspect in [16.0 / 9.0, 4.0 / 3.0]:
		for k in 12:
			orbit["start"] = TAU * k / 12.0
			var x := _ndc_x(TableWorld.orbit_start(orbit, aspect), world.head_position(2), aspect)
			assert_lt(x, UiTheme.SETTLEMENT_DOCK * 2.0 - 1.0 - 0.25, "头离面板停靠区还有余地")
			assert_gt(x, -0.9, "头没出左边")


func test_settlement_panels_dock_right_and_leave_the_left_undimmed():
	var root := Control.new()
	add_child_autofree(root)
	var stats := {1: {"name": "我", "shots": 1, "rounds": 2}, 2: {"name": "阿狸", "shots": 2, "rounds": 2}}
	var panels: Array[ColorRect] = [
		Settlement.new("阿狸", Settlement.build_ranking(2, [1], stats), false),
		PokerSettlement.new([{"pid": 1, "name": "我", "stack": 3000, "buyins": 1, "net": 1000},
			{"pid": 2, "name": "阿狸", "stack": 1000, "buyins": 1, "net": -1000}], true),
		BombCatSettlement.new("阿狸", [{"pid": 2, "name": "阿狸", "place": 1, "fate": "winner"},
			{"pid": 1, "name": "我", "place": 2, "fate": "exploded"}], false),
	]
	for panel in panels:
		root.add_child(panel)
	for size in [Vector2(1280, 720), Vector2(1280, 960)]:
		for panel in panels:
			panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
			panel.position = Vector2.ZERO
			panel.size = size
		await wait_process_frames(3)
		for panel in panels:
			var box: Control = panel.get_node("Dock").get_child(0)
			var rect := box.get_global_rect()
			assert_gte(rect.position.x, size.x * 0.5, "%s 停在右边" % panel.get_script().get_global_name())
			assert_lte(rect.end.x, size.x + 1.0, "不出右边")
			assert_almost_eq(rect.get_center().y, size.y / 2.0, 2.0, "竖直居中")
			var image: Image = (panel.get_node("Scrim") as TextureRect).texture.get_image()
			assert_lt(image.get_pixel(int(image.get_width() * 0.25), 1).a, 0.01, "左边不压暗")
			assert_gt(image.get_pixel(image.get_width() - 1, 1).a, 0.5, "面板后面压暗")
			assert_eq(panel.color.a, 0.0, "整屏不再压暗")
