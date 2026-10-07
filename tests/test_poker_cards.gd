extends GutTest
# 德州牌层(PokerCards):
# - 发手牌到各家牌扇(自己的牌扇抬到德州位置、牌面朝越肩镜头)、公共牌飞到牌架上翻开、
#   弃牌推进弃牌堆、亮牌摊到座位前、赢家的牌发光、新一手全部收回;
# - 按公共 / 私有视图瞬时对账,中途对账或拆台时协程照常走完、牌不乱飞;
# - 桌上的牌按本机视角正立,时长在演出预算之内。


const R := SeatLayout.POKER_TABLE_RADIUS
const ME := 1
const SETTLE := 0.15
const EPS := Vector3.ONE * 0.0001
const TIMING_SLACK := 0.1   # 秒

var world: TableWorld
var cards: PokerCards
var sounds: Array = []


func before_each():
	world = TableWorld.new(null)
	add_child_autofree(world)
	world.configure_table(R)
	world.arrange([1, 2, 3, 4].map(func(pid): return {"pid": pid}), ME, true, false)
	cards = PokerCards.new(world)
	world.poker_root.add_child(cards)
	sounds = []
	cards.sfx.connect(func(name: String): sounds.append(name))


func _c(rank: int, suit: int) -> int:
	return PokerCard.make(rank, suit)


func _fan_cards(pid: int) -> Array:
	return world.patrons[pid].fan.get_children().filter(
		func(n: Node) -> bool: return n is Card3D and not n.is_queued_for_deletion())


func _live_cards() -> Array:
	var all := cards.find_children("*", "Card3D", true, false)
	for pid in world.patrons:
		all.append_array(_fan_cards(pid))
	return all.filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())


func _kinds(list: Array) -> Array:
	return list.map(func(card: Card3D) -> int: return card.kind)


func _glow(card: Card3D) -> float:
	return card.get_child(0).get_instance_shader_parameter("glow")


func _player(pid: int, status: String, shown := []) -> Dictionary:
	return {"pid": pid, "status": status, "shown": shown, "left": false}


func _deal_all() -> void:
	await cards.deal_hole([2, 3, 4, 1], ME, [_c(14, 0), _c(13, 0)])


func _assert_takes(seconds: float, action: Callable) -> void:
	# 用同一帧建的补间计时:与被测动画同一个时钟(测试刚开始那一帧可能很长,补间一步就跨过去,
	# 按物理帧数的 wait_seconds 会落后)。早于 seconds − TIMING_SLACK 没走完,晚于 seconds + TIMING_SLACK 已走完
	var done := [false]
	var run := func():
		await action.call()
		done[0] = true
	run.call()
	await _tween_wait(seconds - TIMING_SLACK)
	assert_false(done[0], "不早于 %.2f 秒走完" % seconds)
	await _tween_wait(TIMING_SLACK * 2.0)
	assert_true(done[0], "%.2f 秒内走完" % seconds)


func _tween_wait(seconds: float) -> void:
	var tween := create_tween()
	tween.tween_interval(seconds)
	await tween.finished


# —— 牌架与发牌 ——

func test_rack_sits_under_the_board_slots():
	var rack := cards.get_node("BoardRack") as Node3D
	assert_not_null(rack)
	assert_gt(rack.find_children("*", "MeshInstance3D", true, false).size(), 0)
	for i in PokerRules.BOARD_CARDS:
		var slot := PokerLayout.board_slot(i)
		assert_gt(slot.origin.y, SeatLayout.TABLE_TOP, "牌在牌架上")


func test_deal_hole_gives_every_dealt_player_two_cards():
	await _assert_takes(PokerCards.deal_duration(8), _deal_all)
	assert_eq(_kinds(_fan_cards(ME)), [_c(14, 0), _c(13, 0)], "自己的牌按私有视图")
	for pid in [2, 3, 4]:
		assert_eq(_kinds(_fan_cards(pid)), [CardFaces.BACK, CardFaces.BACK], "别人的是牌背")
	assert_eq(sounds.count("deal"), 8)


func test_dealt_cards_land_in_the_fan_slots():
	await _deal_all()
	for pid in [ME, 3]:
		var held := _fan_cards(pid)
		for i in held.size():
			assert_almost_eq(held[i].transform.origin, CardTable.fan_slot(i, 2, 0.0).origin, EPS)


func test_my_fan_is_raised_to_the_poker_spot_facing_the_camera():
	await _deal_all()
	var seat := world.seat_transform(world.seat_angles[ME])
	var expected := PokerLayout.fan_transform(seat, world.third_person_view(ME).origin)
	assert_true(world.patrons[ME].fan.transform.is_equal_approx(expected))


func test_players_without_patron_are_skipped():
	world.remove_patron(4)
	await cards.deal_hole([2, 3, 4, 1], ME, [_c(14, 0), _c(13, 0)])
	assert_eq(sounds.count("deal"), 6)


# —— 公共牌 ——

func test_board_cards_fly_to_the_rack_and_turn_face_up():
	await _assert_takes(PokerCards.board_duration(3), func(): await cards.deal_board([_c(2, 0), _c(9, 1), _c(12, 2)], 0))
	await cards.deal_board([_c(5, 3)], 3)
	var board := cards.board_cards()
	assert_eq(_kinds(board), [_c(2, 0), _c(9, 1), _c(12, 2), _c(5, 3)])
	for i in board.size():
		assert_true(board[i].transform.is_equal_approx(PokerLayout.board_slot(i)), "第 %d 张正面朝上摆在牌架上" % i)
	assert_eq(sounds.count("flip"), 4)


# —— 弃牌与亮牌 ——

func test_fold_pushes_the_cards_into_the_muck_face_down():
	await _deal_all()
	await cards.fold(3)
	assert_eq(_fan_cards(3).size(), 0)
	var muck := cards.muck_cards()
	assert_eq(muck.size(), 2)
	for i in muck.size():
		assert_true(muck[i].transform.is_equal_approx(PokerLayout.muck_slot(i)))
		assert_lt(muck[i].transform.basis.y.y, 0.0, "牌面朝下")
	assert_true(sounds.has("fold"))


func test_folding_empty_handed_still_fills_the_muck():
	# 导演容错:手里没牌的弃牌不报错,弃牌堆照样多两张
	await cards.fold(2)
	assert_eq(cards.muck_cards().size(), 2)


func test_reveal_lays_the_hand_face_up_in_front_of_the_seat():
	await _deal_all()
	var hand := [_c(10, 1), _c(10, 2)]
	await cards.reveal(2, hand)
	assert_eq(_fan_cards(2).size(), 0, "牌从牌扇里拿出来了")
	var shown := cards.shown_cards(2)
	assert_eq(_kinds(shown), hand)
	for i in shown.size():
		assert_true(shown[i].transform.is_equal_approx(PokerLayout.shown_card(world.seat_angles[2], R, i)))


func test_reveal_of_a_player_who_left_still_shows_the_cards():
	await _deal_all()
	world.remove_patron(4)
	await cards.reveal(4, [_c(3, 0), _c(3, 1)])
	assert_eq(_kinds(cards.shown_cards(4)), [_c(3, 0), _c(3, 1)])


func test_highlight_glows_only_the_winning_cards():
	await cards.deal_board([_c(2, 0), _c(9, 1), _c(12, 2), _c(5, 3), _c(7, 0)], 0)
	await _deal_all()
	await cards.reveal(2, [_c(9, 0), _c(9, 2)])
	cards.highlight([_c(9, 1), _c(9, 0), _c(9, 2), _c(12, 2), _c(7, 0)])
	await wait_seconds(PokerCards.HIGHLIGHT_TIME * 0.5)
	for card in cards.board_cards() + cards.shown_cards(2):
		var lit := [_c(9, 1), _c(9, 0), _c(9, 2), _c(12, 2), _c(7, 0)].has(card.kind)
		assert_eq(_glow(card) > 0.0, lit, PokerCard.label(card.kind))
	cards.highlight([])
	for card in cards.board_cards():
		assert_eq(_glow(card), 0.0, "换下一个底池时先熄掉")


# —— 收牌 ——

func test_sweep_gathers_every_card_and_frees_them():
	await _deal_all()
	await cards.deal_board([_c(2, 0), _c(9, 1), _c(12, 2)], 0)
	await cards.fold(3)
	await cards.reveal(2, [_c(10, 1), _c(10, 2)])
	await cards.sweep()
	await wait_process_frames(1)
	assert_eq(_live_cards().size(), 0)
	assert_true(sounds.has("sweep"))
	assert_eq(cards.board_cards(), [])


# —— 对账 ——

func _view_players() -> Array:
	return [_player(1, PokerRules.STATUS_ACTIVE), _player(2, PokerRules.STATUS_FOLDED),
		_player(3, PokerRules.STATUS_ALLIN, [_c(11, 0), _c(11, 1)]), _player(4, PokerRules.STATUS_ACTIVE),
		_player(9, PokerRules.STATUS_WAITING)]


func test_sync_lays_out_the_table_from_the_view():
	cards.sync(_view_players(), [_c(2, 0), _c(9, 1), _c(12, 2)], ME, [_c(14, 0), _c(13, 0)])
	assert_eq(_kinds(cards.board_cards()), [_c(2, 0), _c(9, 1), _c(12, 2)])
	assert_eq(_kinds(_fan_cards(ME)), [_c(14, 0), _c(13, 0)])
	assert_eq(_kinds(_fan_cards(4)), [CardFaces.BACK, CardFaces.BACK])
	assert_eq(_fan_cards(2).size(), 0, "弃了牌的手里没牌")
	assert_eq(_fan_cards(3).size(), 0, "亮了牌的手里没牌")
	assert_eq(_kinds(cards.shown_cards(3)), [_c(11, 0), _c(11, 1)])
	assert_eq(cards.muck_cards().size(), 2)
	for i in 3:
		assert_true(cards.board_cards()[i].transform.is_equal_approx(PokerLayout.board_slot(i)))


func test_sync_again_removes_what_is_gone():
	cards.sync(_view_players(), [_c(2, 0), _c(9, 1), _c(12, 2)], ME, [_c(14, 0), _c(13, 0)])
	var waiting := [1, 2, 3, 4].map(func(pid): return _player(pid, PokerRules.STATUS_WAITING))
	cards.sync(waiting, [], ME, [])
	await wait_process_frames(1)
	assert_eq(_live_cards().size(), 0)


func test_sync_is_idempotent():
	cards.sync(_view_players(), [_c(2, 0)], ME, [_c(14, 0), _c(13, 0)])
	var before := _live_cards()
	cards.sync(_view_players(), [_c(2, 0)], ME, [_c(14, 0), _c(13, 0)])
	await wait_process_frames(1)
	assert_eq(_live_cards(), before, "同样的视图不重建牌")


func test_sync_during_a_deal_settles_the_cards_and_the_deal_still_finishes():
	var done := [false]
	var run := func():
		await _deal_all()
		done[0] = true
	run.call()
	await wait_seconds(PokerCards.DEAL_STAGGER * 3.0)
	cards.sync(_view_players(), [], ME, [_c(14, 0), _c(13, 0)])
	await wait_seconds(PokerCards.deal_duration(8) + SETTLE)
	assert_true(done[0], "协程走完,没有卡住")
	assert_eq(_kinds(_fan_cards(4)), [CardFaces.BACK, CardFaces.BACK])
	assert_eq(_fan_cards(2).size(), 0, "对账后发到一半的牌不再落进弃了牌的人手里")
	for i in 2:
		assert_almost_eq(_fan_cards(4)[i].transform.origin, CardTable.fan_slot(i, 2, 0.0).origin, EPS, "没有接着飞")


func test_clear_frees_every_card_but_keeps_the_rack():
	cards.sync(_view_players(), [_c(2, 0)], ME, [_c(14, 0), _c(13, 0)])
	cards.clear()
	await wait_process_frames(1)
	assert_eq(_live_cards().size(), 0)
	assert_not_null(cards.get_node_or_null("BoardRack"))


func test_clear_poker_mid_deal_takes_the_hole_cards_without_errors():
	var run := func(): await _deal_all()
	run.call()
	await wait_seconds(PokerCards.deal_duration(8) * 0.6)
	world.clear_poker()
	await wait_seconds(PokerCards.deal_duration(8) + SETTLE)
	for pid in world.patrons:
		assert_eq(_fan_cards(pid).size(), 0)
	assert_false(is_instance_valid(cards))


# —— 朝向与预算 ——

func test_cards_on_the_table_read_upright_from_the_local_seat():
	cards.sync(_view_players(), [_c(2, 0), _c(9, 1), _c(12, 2), _c(5, 3), _c(7, 0)], ME, [])
	for card in cards.board_cards() + cards.shown_cards(3):
		var top: Vector3 = (card.global_basis * Vector3.FORWARD).normalized()
		assert_lt(top.z, 0.0, "牌顶朝 −Z")
		assert_gt(card.global_basis.y.y, 0.0, "牌面朝上")


func test_animations_fit_the_pacing_budget():
	for players in range(PokerRules.MIN_PLAYERS, PokerRules.MAX_SEATS + 1):
		var dealt := players * PokerRules.HOLE_CARDS
		assert_lte(PokerCards.deal_duration(dealt), PokerPacing.HOLE_BASE + PokerPacing.HOLE_PER_CARD * dealt)
	for count in [1, PokerRules.FLOP_CARDS, PokerRules.BOARD_CARDS]:
		assert_lte(PokerCards.board_duration(count), PokerPacing.STREET_BASE + PokerPacing.STREET_PER_CARD * count)
	assert_lte(PokerCards.FOLD_FLIGHT, PokerPacing.ACTION)
	assert_lte(PokerCards.REVEAL_FLIGHT, PokerPacing.REVEAL_PER_HAND)
	assert_lte(PokerCards.SWEEP_FLIGHT + PokerCards.SWEEP_JITTER, PokerPacing.HAND_STARTED)
	assert_lte(PokerCards.HIGHLIGHT_TIME, PokerPacing.POT_WON)
