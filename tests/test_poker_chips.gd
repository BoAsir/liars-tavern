extends GutTest
# 德州筹码层(PokerChips):
# - 按公共视图瞬时对账:在座者的筹码堆、本轮下注、各底池,金额为 0 不建节点,人少了多余的收走;
# - 下注、收进底池(先退未跟注部分)、分池、再领都是协程,走完后金额与视图一致,时长在演出预算之内;
# - 中途对账或清空时动画协程照常走完、不卡住,也不把旧金额写回去;
# - 筹码堆与庄家按钮跟着沿圆弧换座的酒客走;金额标签挂点在筹码上方。


const R := SeatLayout.POKER_TABLE_RADIUS
const SETTLE := 0.15   # 秒:补间结束后再等一会儿
const FRAME_LAG := 0.08   # 米:换座滑动最快时一帧走过的距离(留足余量)
const MID_SLIDE := 0.15   # 米:滑到一半时离起点、终点都至少这么远

var world: TableWorld
var chips: PokerChips
var sounds: Array = []


func before_each():
	world = TableWorld.new(null)
	add_child_autofree(world)
	world.configure_table(R)
	world.arrange([1, 2, 3, 4].map(func(pid): return {"pid": pid}), 1, true, false)
	chips = PokerChips.new(world)
	world.poker_root.add_child(chips)
	sounds = []
	chips.sfx.connect(func(name: String): sounds.append(name))


func _player(pid: int, stack: int, bet := 0, left := false) -> Dictionary:
	return {"pid": pid, "stack": stack, "bet": bet, "left": left, "status": PokerRules.STATUS_ACTIVE}


func _table() -> Array:
	return [_player(1, 1980, 20), _player(2, 2000), _player(3, 1990, 10), _player(4, 0)]


func _stack_nodes() -> Array:
	return chips.find_children("*", "ChipStack3D", true, false).filter(
		func(n: Node) -> bool: return not n.is_queued_for_deletion())


func _angle(pid: int) -> float:
	return world.seat_angles[pid]


# —— 对账 ——

func test_sync_lays_out_stacks_bets_and_pots():
	chips.sync(_table(), [{"amount": 300, "eligible": [1, 2, 3]}, {"amount": 120, "eligible": [1, 3]}])
	assert_eq([chips.stack_amount(1), chips.stack_amount(2), chips.stack_amount(3), chips.stack_amount(4)],
		[1980, 2000, 1990, 0])
	assert_eq([chips.bet_amount(1), chips.bet_amount(2), chips.bet_amount(3)], [20, 0, 10])
	assert_eq(chips.pot_amounts(), [300, 120])
	assert_eq(_stack_nodes().size(), 3 + 2 + 2, "3 摞筹码 + 2 处下注 + 2 个底池;金额 0 不建节点")


func test_sync_places_items_by_the_layout():
	chips.sync(_table(), [{"amount": 300, "eligible": [1, 2]}, {"amount": 120, "eligible": [1]}])
	assert_almost_eq(chips.stack_node(2).position, PokerLayout.stack_position(_angle(2), R), Vector3.ONE * 0.0001)
	assert_almost_eq(chips.bet_node(3).position, PokerLayout.bet_position(_angle(3), R), Vector3.ONE * 0.0001)
	assert_almost_eq(chips.pot_node(1).position, PokerLayout.pot_position(1, 2), Vector3.ONE * 0.0001)
	var facing := -chips.stack_node(2).global_basis.z
	assert_almost_eq(facing, -SeatLayout.direction(_angle(2)), Vector3.ONE * 0.0001, "大面额那排朝桌心")


func test_sync_removes_what_is_no_longer_there():
	chips.sync(_table(), [{"amount": 300, "eligible": []}, {"amount": 120, "eligible": []}])
	chips.sync([_player(1, 2000), _player(2, 1990, 10)], [{"amount": 60, "eligible": []}])
	assert_eq(chips.stack_amount(3), 0)
	assert_eq(chips.bet_amount(1), 0)
	assert_eq(chips.pot_amounts(), [60])
	assert_eq(_stack_nodes().size(), 2 + 1 + 1)


func test_sync_keeps_a_leavers_bet_but_not_his_stack():
	# 规格 §2.7:离开者已下的注留在桌上(等收进底池),筹码跟他走
	chips.sync([_player(1, 1980, 20), _player(2, 1500, 500, true)], [])
	assert_eq(chips.stack_amount(2), 0)
	assert_eq(chips.bet_amount(2), 500)


func test_sync_skips_players_without_a_seat():
	# 迟到者还没登场:公共视图里有他,桌上没有他的座位
	chips.sync([_player(1, 2000), _player(9, 2000)], [])
	assert_eq(chips.stack_amount(9), 0)
	assert_eq(_stack_nodes().size(), 1)


func test_clear_leaves_nothing():
	chips.sync(_table(), [{"amount": 300, "eligible": []}])
	chips.place_button(1)
	chips.clear()
	await wait_process_frames(1)
	assert_eq(_stack_nodes().size(), 0)
	assert_eq(chips.pot_amounts(), [])
	assert_false(chips.button_node().visible)


func test_every_chip_mesh_skips_shadows():
	chips.sync(_table(), [{"amount": 300, "eligible": []}])
	for mm in chips.find_children("*", "MultiMeshInstance3D", true, false):
		assert_eq(mm.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)


# —— 动画 ——

func test_bet_slides_new_chips_from_the_stack_to_the_bet():
	chips.sync([_player(1, 2000), _player(2, 2000)], [])
	var started := Time.get_ticks_msec()
	await chips.bet(1, 60, 1940)
	assert_almost_eq((Time.get_ticks_msec() - started) / 1000.0, PokerChips.BET_SLIDE, 0.1)
	assert_eq([chips.bet_amount(1), chips.stack_amount(1)], [60, 1940])
	assert_eq(sounds, ["chips"])
	assert_eq(_stack_nodes().size(), 3, "飞行的临时筹码已收走")


func test_all_in_pushes_the_whole_stack():
	chips.sync([_player(1, 300, 20), _player(2, 2000)], [])
	await chips.bet(1, 320, 0)
	assert_eq([chips.bet_amount(1), chips.stack_amount(1)], [320, 0])
	assert_eq(sounds, ["chips_push"])


func test_collect_refunds_first_then_gathers_bets_into_the_pots():
	chips.sync([_player(1, 1700, 300), _player(2, 0, 100), _player(3, 1100, 900)], [])
	await chips.collect([{"amount": 300, "eligible": [1, 2, 3]}, {"amount": 400, "eligible": [1, 3]}],
		{"pid": 3, "amount": 600})
	assert_eq(chips.stack_amount(3), 1700, "退回的 600 回到筹码堆")
	for pid in [1, 2, 3]:
		assert_eq(chips.bet_amount(pid), 0)
	assert_eq(chips.pot_amounts(), [300, 400])
	assert_eq(_stack_nodes().size(), 2 + 2, "两摞筹码 + 两个底池")


func test_collect_without_refund():
	chips.sync([_player(1, 1980, 20), _player(2, 1980, 20)], [])
	await chips.collect([{"amount": 40, "eligible": [1, 2]}], {})
	assert_eq(chips.pot_amounts(), [40])
	assert_eq(chips.bet_amount(1), 0)


func test_award_slides_shares_to_the_winners():
	chips.sync([_player(1, 1000), _player(2, 1000), _player(3, 0)], [{"amount": 300, "eligible": []},
		{"amount": 70, "eligible": []}])
	await chips.award(1, {2: 40, 3: 30}, {2: 1040})
	assert_eq(chips.stack_amount(2), 1040)
	assert_eq(chips.stack_amount(3), 30, "视图没给就加上份额")
	assert_eq(chips.pot_amounts(), [300], "分掉的底池收走")
	await chips.award(0, {1: 300}, {1: 1300})
	assert_eq(chips.stack_amount(1), 1300)
	assert_eq(chips.pot_amounts(), [])


func test_rebuy_drops_a_fresh_stack():
	chips.sync([_player(1, 2000), _player(2, 0)], [])
	await chips.rebuy(2, PokerRules.STARTING_STACK)
	assert_eq(chips.stack_amount(2), PokerRules.STARTING_STACK)
	assert_almost_eq(chips.stack_node(2).position, PokerLayout.stack_position(_angle(2), R), Vector3.ONE * 0.0001)


func test_remove_seat_takes_the_stack_and_leaves_the_bet():
	chips.sync([_player(1, 1980, 20), _player(2, 1500, 500)], [])
	chips.remove_seat(2)
	assert_eq(chips.stack_amount(2), 0)
	assert_eq(chips.bet_amount(2), 500)


func test_animations_fit_the_pacing_budget():
	assert_lte(PokerChips.BET_SLIDE, PokerPacing.BLIND)
	assert_lte(PokerChips.REFUND_SLIDE + PokerChips.COLLECT_SLIDE, PokerPacing.BETS_COLLECTED)
	assert_lte(PokerChips.AWARD_SLIDE, PokerPacing.POT_WON)
	assert_lte(PokerChips.REBUY_DROP, PokerPacing.REBUY)
	assert_lte(maxf(PokerChips.BUTTON_MOVE, TableWorld.SEAT_MOVE), PokerPacing.HAND_STARTED)


# —— 中途对账、清空 ——

func test_sync_during_a_bet_wins_and_the_bet_still_finishes():
	chips.sync([_player(1, 2000), _player(2, 2000)], [])
	var done := [false]
	var run := func():
		await chips.bet(1, 60, 1940)
		done[0] = true
	run.call()
	chips.sync([_player(1, 1500, 500), _player(2, 2000)], [])
	await wait_seconds(PokerChips.BET_SLIDE + SETTLE)
	assert_true(done[0], "协程走完,没有卡住")
	assert_eq([chips.bet_amount(1), chips.stack_amount(1)], [500, 1500], "不把旧金额写回去")
	assert_eq(_stack_nodes().size(), 3, "两摞筹码 + 一处下注,飞行的临时筹码已收走")


func test_clear_during_a_collect_does_not_hang():
	chips.sync([_player(1, 1980, 20), _player(2, 1980, 20)], [])
	var done := [false]
	var run := func():
		await chips.collect([{"amount": 40, "eligible": [1, 2]}], {})
		done[0] = true
	run.call()
	chips.clear()
	await wait_seconds(PokerChips.COLLECT_SLIDE + SETTLE)
	assert_true(done[0])
	assert_eq(_stack_nodes().size(), 0)


# —— 跟着座位走 ——

func test_stacks_follow_patrons_sliding_to_new_seats():
	chips.sync([_player(1, 2000), _player(2, 2000), _player(3, 2000), _player(4, 2000)], [])
	world.arrange([1, 3, 4].map(func(pid): return {"pid": pid}), 1, true, false)
	chips.remove_seat(2)
	var start := PokerLayout.stack_position(deg_to_rad(180.0), R)
	var end := PokerLayout.stack_position(_angle(3), R)
	await wait_seconds(TableWorld.SEAT_MOVE / 2.0)
	# 补间在各节点的 _process 之后才走:筹码堆最多落后酒客一帧
	var mid := PokerLayout.stack_position(world.seat_angle_now(3), R)
	assert_almost_eq(chips.stack_node(3).position, mid, Vector3.ONE * FRAME_LAG, "途中跟着酒客")
	assert_gt(chips.stack_node(3).position.distance_to(start), MID_SLIDE, "已经离开旧座位")
	assert_gt(chips.stack_node(3).position.distance_to(end), MID_SLIDE, "还没到新座位")
	await wait_seconds(TableWorld.SEAT_MOVE / 2.0 + SETTLE)
	assert_almost_eq(chips.stack_node(3).position, PokerLayout.stack_position(_angle(3), R), Vector3.ONE * 0.0001)


func test_button_moves_round_the_table_to_the_new_seat():
	chips.place_button(1)
	assert_true(chips.button_node().visible)
	assert_almost_eq(chips.button_node().position, PokerLayout.button_position(_angle(1), R), Vector3.ONE * 0.0001)
	await chips.move_button(3)
	assert_eq(chips.button_pid(), 3)
	assert_almost_eq(chips.button_node().position, PokerLayout.button_position(_angle(3), R), Vector3.ONE * 0.0001)
	chips.place_button(null)
	assert_false(chips.button_node().visible, "第一手之前没有按钮")


func test_first_button_appears_in_place():
	var started := Time.get_ticks_msec()
	await chips.move_button(2)
	assert_lt((Time.get_ticks_msec() - started) / 1000.0, 0.1, "第一次出现直接落位")
	assert_almost_eq(chips.button_node().position, PokerLayout.button_position(_angle(2), R), Vector3.ONE * 0.0001)


# —— 金额标签挂点 ——

func test_label_anchors_sit_above_the_chips():
	chips.sync([_player(1, 1980, 20)], [{"amount": 300, "eligible": []}])
	var stack := chips.stack_node(1)
	assert_almost_eq(chips.stack_anchor(1), stack.global_position + Vector3.UP * (stack.top_height() + PokerChips.LABEL_LIFT),
		Vector3.ONE * 0.0001)
	assert_gt(chips.bet_anchor(1).y, SeatLayout.TABLE_TOP)
	assert_gt(chips.pot_anchor(0).y, SeatLayout.TABLE_TOP)
	var empty := PokerLayout.stack_position(_angle(2), R) + Vector3.UP * PokerChips.LABEL_LIFT
	assert_almost_eq(chips.stack_anchor(2), empty, Vector3.ONE * 0.0001, "没有筹码时挂在筹码堆的位置")
