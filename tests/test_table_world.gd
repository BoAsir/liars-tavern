extends GutTest
# 角色层:物种按玩家稳定分配、复活时复位幸存者的姿势、清理出局时打飞的帽子;
# 德州:桌子放大后的座位与机位(规格 §5.5)、沿圆弧换座、离桌、铭牌挂点、拆台(§5.1)。


const FAST_CLOCK := 8.0   # 庆祝动画以秒计:加速时钟,测试不必真等
const CLOCK_SLACK := 0.4  # 游戏秒:物理帧计时与补间的处理帧之间至多差一个(加速后的)物理帧
const POKER_R := SeatLayout.POKER_TABLE_RADIUS
const SLIDE_SETTLE := 0.15   # 秒:换座补间结束后再等一会儿

var world: TableWorld


func before_each():
	world = TableWorld.new(null)
	add_child_autofree(world)


func after_each():
	Engine.time_scale = 1.0


func _arrange(pids: Array) -> void:
	world.arrange(pids.map(func(pid): return {"pid": pid}), pids[0], true, false)


func _species() -> Dictionary:
	var result := {}
	for pid in world.patrons:
		result[pid] = world.patrons[pid].species_index
	return result


func _debris() -> Array:
	return world.get_children().filter(func(node: Node) -> bool:
		return node.is_in_group(Patron.DEBRIS_GROUP) and not node.is_queued_for_deletion())


func _right_arm_points_at(patron: Patron, target: Vector3) -> bool:
	# 手臂从肩膀指向目标点(手在臂长末端),比较方向即可判断姿势
	var hand := patron.body.to_local(patron.right_hand.global_position) - Patron.SHOULDER
	return hand.normalized().distance_to((target - Patron.SHOULDER).normalized()) < 0.01


# —— 物种 ——

func test_new_patrons_take_distinct_species_in_seat_order():
	_arrange([1, 2, 3])
	assert_eq(_species(), {1: 0, 2: 1, 3: 2})


func test_newcomer_takes_the_species_a_leaver_freed_and_others_keep_theirs():
	_arrange([1, 2, 3])
	_arrange([1, 3])
	_arrange([1, 3, 4])
	assert_eq(_species(), {1: 0, 3: 2, 4: 1})


func test_revived_patron_keeps_its_species():
	_arrange([1, 2, 3])
	var old: Patron = world.patrons[2]
	old.die()
	world.revive_all()
	assert_ne(world.patrons[2], old, "倒下的酒客换成新实例")
	assert_true(world.patrons[2].alive)
	assert_eq(_species(), {1: 0, 2: 1, 3: 2})


func test_species_of_matches_the_patron_model():
	_arrange([1, 2, 3])
	_arrange([1, 3])
	assert_eq(world.species_of(3), PatronParts.species(2))
	assert_eq(world.species_of(99), {}, "没有角色的玩家")


# —— 复活时复位幸存者 ——

func test_revive_all_releases_the_winners_cheer_pose():
	_arrange([1, 2])
	var winner: Patron = world.patrons[1]
	winner.celebrate()
	world.revive_all()
	assert_eq(world.patrons[1], winner, "幸存者沿用原实例")
	winner.rest_arms(false)
	await wait_process_frames(3)
	assert_true(_right_arm_points_at(winner, winner.rest_target(1.0)), "复位后双手能搭回桌上")
	assert_almost_eq(winner.body.position.y, Patron.HIP.y, 0.0001, "庆祝的蹦跳已停止")


func test_celebrate_unlocks_the_arms_once_its_bounces_end():
	_arrange([1, 2])
	var winner: Patron = world.patrons[1]
	Engine.time_scale = FAST_CLOCK
	winner.celebrate()
	await wait_seconds(Patron.CHEER_BOUNCES * Patron.CHEER_BOUNCE_TIME * 2.0 + CLOCK_SLACK)
	assert_true(_right_arm_points_at(winner, Patron.HAND_CHEER), "跳完后双手仍举着")
	winner.rest_arms(false)
	await wait_process_frames(3)
	assert_true(_right_arm_points_at(winner, winner.rest_target(1.0)), "动作锁已解除")


# —— 散落物 ——

func test_revive_all_removes_every_knocked_off_hat():
	_arrange([1, 2, 3, 4])
	for pid in [2, 3, 4]:
		world.patrons[pid].die()
	assert_eq(_debris().size(), 3, "三顶帽子都落到了桌边")
	world.revive_all()
	assert_eq(_debris().size(), 0)


func test_clear_removes_knocked_off_hats():
	_arrange([1, 2])
	world.patrons[2].die()
	world.clear()
	assert_eq(_debris().size(), 0)




# —— 德州:桌子放大与机位 ——

func _assert_view(view: Transform3D, pos: Vector3, target: Vector3, label: String) -> void:
	assert_almost_eq(view.origin, pos, Vector3.ONE * 0.0001, label + " 机位")
	assert_almost_eq(-view.basis.z, (target - pos).normalized(), Vector3.ONE * 0.0001, label + " 朝向")


func _flat_radius(node: Node3D) -> float:
	return Vector2(node.position.x, node.position.z).length()


func test_poker_table_seats_patrons_further_out():
	world.configure_table(POKER_R)
	_arrange([1, 2, 3, 4, 5, 6, 7, 8])
	for pid in world.patrons:
		assert_almost_eq(_flat_radius(world.patrons[pid]), 1.75, 0.0001)


func test_growing_the_table_slides_seated_patrons_outwards():
	_arrange([1, 2, 3])
	world.configure_table(POKER_R)
	await wait_seconds(TableWorld.SEAT_MOVE + SLIDE_SETTLE)
	for pid in world.patrons:
		assert_almost_eq(_flat_radius(world.patrons[pid]), world.seat_radius, 0.0001)
		assert_almost_eq(world.patrons[pid].position, world.seat_transform(world.seat_angles[pid]).origin,
			Vector3.ONE * 0.0001, "角度不变,只往外挪")


func test_liars_table_keeps_its_camera_views():
	_arrange([1, 2, 3])
	world.configure_table(POKER_R)
	world.configure_table(SeatLayout.TABLE_RADIUS)
	_assert_view(world.third_person_view(1), Vector3(0.55, 1.92, 2.1), Vector3(0, 0.78, -0.12), "越肩")
	_assert_view(world.overview_view(), Vector3(0, 2.3, 2.7), Vector3(0, 0.78, -0.25), "观战")
	_assert_view(world.lobby_view(), Vector3(0.95, 2.6, 2.5), Vector3(0.95, 0.75, -0.1), "等待厅")
	var orbit := world.table_orbit()
	assert_eq([orbit["center"], orbit["radius"], orbit["height"]], [Vector3(0, 0.95, 0), 2.4, 0.9], "结算环绕不变")


func test_poker_table_uses_the_spec_camera_views():
	world.configure_table(POKER_R)
	_arrange([1, 2])
	_assert_view(world.third_person_view(1), Vector3(0.55, 1.92, 2.6), Vector3(0, 0.78, -0.12), "越肩")
	_assert_view(world.third_person_view(2), Vector3(-0.55, 1.92, -2.6), Vector3(0, 0.78, 0.12), "对面座位的越肩")
	_assert_view(world.overview_view(), Vector3(0, 2.0, 2.6), Vector3(0, 0.78, 0.0), "观战")
	_assert_view(world.lobby_view(), Vector3(1.65, 2.75, 3.35), Vector3(1.35, 0.75, 0.1), "等待厅")


func test_poker_closing_orbit_clears_the_chair_backs():
	# 规格 §5.5:散局环绕半径 ≥ 3.0、镜头高约 2.0(2.4 米的环绕会擦过 2.11 米处的椅背)
	world.configure_table(POKER_R)
	var orbit := world.table_orbit()
	assert_gte(orbit["radius"], 3.0)
	assert_almost_eq(orbit["center"].y + orbit["height"], 2.0, 0.05, "镜头高约 2 米")
	assert_gt(orbit["speed"], 0.0)


func test_poker_camera_rule_sends_late_joiners_and_spectators_to_the_overview():
	# 规格 §5.5「用哪个机位」:在座位表里且没在观战 → 越肩(输光还没选、刚再领、离座都留在越肩)
	for status in [PokerRules.STATUS_ACTIVE, PokerRules.STATUS_ALLIN, PokerRules.STATUS_FOLDED,
			PokerRules.STATUS_WAITING, PokerRules.STATUS_BUSTED, "away"]:
		assert_false(TableWorld.uses_overview(true, status), status)
	assert_true(TableWorld.uses_overview(true, PokerRules.STATUS_SPECTATING), "观战")
	assert_true(TableWorld.uses_overview(false, PokerRules.STATUS_WAITING), "迟到者还不在座位表里")


func test_rest_view_follows_the_camera_rule():
	world.configure_table(POKER_R)
	_arrange([1, 2, 3])
	assert_eq(world.rest_view(1, true, PokerRules.STATUS_BUSTED), world.third_person_view(1))
	assert_eq(world.rest_view(1, true, PokerRules.STATUS_SPECTATING), world.overview_view())
	assert_eq(world.rest_view(1, false, PokerRules.STATUS_WAITING), world.overview_view())


func test_spectator_hides_only_the_local_patron_without_rebuilding_it():
	# 观战机位从本机座位后上方看过去:自己的酒客只在本机藏起来,不重建(重建可能换成别的动物)
	_arrange([1, 2, 3])
	var me: Patron = world.patrons[1]
	world.set_patron_visible(1, false)
	assert_false(me.visible)
	_arrange([1, 2, 3])
	assert_eq(world.patrons[1], me, "重排不重建")
	assert_false(me.visible, "重排后仍然藏着")
	world.set_patron_visible(1, true)
	assert_true(me.visible)
	world.set_patron_visible(99, false)
	assert_eq(world.patrons.size(), 3, "没有酒客的人:什么也不做")


# —— 德州:沿圆弧换座、离桌、铭牌挂点 ——

func test_reseated_patrons_follow_the_arc_not_the_chord():
	world.configure_table(POKER_R)
	_arrange([1, 2, 3, 4])
	var mover: Patron = world.patrons[3]
	_arrange([1, 3, 4])   # 3 号从 180° 挪到 120°:走弦线时离桌心最近只有 1.52 米
	var closest := INF
	var deadline := Time.get_ticks_msec() + int((TableWorld.SEAT_MOVE + SLIDE_SETTLE) * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await wait_process_frames(1)
		closest = minf(closest, _flat_radius(mover))
	assert_almost_eq(closest, world.seat_radius, 0.001, "一路都在座位圆上")
	assert_almost_eq(mover.position, world.seat_transform(world.seat_angles[3]).origin, Vector3.ONE * 0.0001)


func test_seat_angle_now_tracks_the_sliding_patron():
	world.configure_table(POKER_R)
	_arrange([1, 2, 3, 4])
	_arrange([1, 3, 4])
	await wait_seconds(TableWorld.SEAT_MOVE / 2.0)
	var now := world.seat_angle_now(3)
	assert_almost_eq(now, TableWorld.angle_of(world.patrons[3].position), 0.0001)
	assert_between(now, deg_to_rad(120.0) + 0.01, PI - 0.01, "途中在旧座位与新座位之间")
	await wait_seconds(TableWorld.SEAT_MOVE / 2.0 + SLIDE_SETTLE)
	assert_almost_eq(world.seat_angle_now(3), world.seat_angles[3], 0.0001)


func test_seat_angle_now_of_a_seat_without_patron_is_the_seat_angle():
	# 迟到者:按「座位表 + 自己」排座、不建自己的酒客,本机座位(角度 0)空着
	world.configure_table(POKER_R)
	world.arrange([{"pid": 2}, {"pid": 3}, {"pid": 1}], 1, false, false)
	assert_false(world.patrons.has(1))
	assert_almost_eq(world.seat_angle_now(1), 0.0, 0.0001)


func test_remove_patron_vanishes_but_keeps_the_seat_angle():
	world.configure_table(POKER_R)
	_arrange([1, 2, 3])
	var leaver: Patron = world.patrons[2]
	var angle: float = world.seat_angles[2]
	world.remove_patron(2)
	assert_false(world.patrons.has(2))
	assert_eq(world.seat_angles[2], angle, "座位角度留到下一次重排")
	assert_almost_eq(world.seat_angle_now(2), angle, 0.0001)
	await wait_seconds(0.5)
	assert_false(is_instance_valid(leaver), "离场动画后释放")
	_arrange([1, 3])
	assert_false(world.seat_angles.has(2))


func test_remove_patron_of_an_unknown_player_is_harmless():
	_arrange([1, 2])
	world.remove_patron(99)
	assert_eq(world.patrons.size(), 2)


func test_nameplate_anchor_sits_above_the_seat_origin():
	world.configure_table(POKER_R)
	_arrange([1, 2, 3, 4, 5, 6, 7, 8])
	assert_eq(TableWorld.NAMEPLATE_HEIGHT, 1.62)
	for pid in world.patrons:
		var seat := world.seat_transform(world.seat_angles[pid]).origin
		assert_almost_eq(world.nameplate_anchor(pid), seat + Vector3(0, 1.62, 0), Vector3.ONE * 0.0001)
	world.remove_patron(5)
	var empty_seat := world.seat_transform(world.seat_angles[5]).origin
	assert_almost_eq(world.nameplate_anchor(5), empty_seat + Vector3(0, 1.62, 0), Vector3.ONE * 0.0001, "离桌后仍按座位算")


func test_angle_of_inverts_the_seat_direction():
	for deg in [0.0, 45.0, 90.0, 180.0, 300.0]:
		var angle := deg_to_rad(deg)
		assert_almost_eq(TableWorld.angle_of(SeatLayout.seat_position(angle, 1.75)), angle, 0.0001)


# —— 德州:拆台(规格 §5.1)——

func test_clear_poker_frees_the_poker_nodes_and_hole_cards_only():
	world.configure_table(POKER_R)
	_arrange([1, 2, 3])
	var stack := ChipStack3D.new()
	world.poker_root.add_child(stack)
	var my_hole := Card3D.new()
	world.patrons[1].fan.add_child(my_hole)
	var their_hole := Card3D.new()
	world.patrons[3].fan.add_child(their_hole)
	world.cards.sync({2: 3}, [])   # 骗子酒馆的牌归 CardTable 管,拆德州台时不动
	var liars: Array = world.cards.held[2].duplicate()
	world.clear_poker()
	assert_eq(world.poker_root.get_child_count(), 0, "容器立即清空")
	for node in [stack, my_hole, their_hole]:
		assert_true(node.is_queued_for_deletion())
		assert_false(node.is_inside_tree(), "立即摘下,同一帧里也看不到")
	for card in liars:
		assert_false(card.is_queued_for_deletion(), "CardTable 的牌不动")
	await wait_process_frames(1)
	for node in [stack, my_hole, their_hole]:
		assert_false(is_instance_valid(node))
	assert_eq(world.patrons[2].fan.get_child_count(), liars.size())


func test_clear_poker_is_idempotent():
	world.configure_table(POKER_R)
	_arrange([1, 2])
	world.poker_root.add_child(Node3D.new())
	world.clear_poker()
	world.clear_poker()
	await wait_process_frames(1)
	assert_eq(world.poker_root.get_child_count(), 0)
	assert_true(is_instance_valid(world.poker_root), "容器本身留着,下一桌德州接着用")
