extends GutTest
# 德州 3D 层整体(无头):TableWorld + PokerChips + PokerCards 都挂在 poker_root 下。
# 用假视图对账,节点数符合预期;人数变少后多余的节点收走;演完一手的动画后拆台,
# TableWorld 下没有德州节点、酒客牌扇里没有德州的牌,骗子酒馆的东西不受影响。


const R := SeatLayout.POKER_TABLE_RADIUS
const ME := 1

var world: TableWorld
var chips: PokerChips
var cards: PokerCards


func before_each():
	world = TableWorld.new(null)
	add_child_autofree(world)
	world.configure_table(R)
	chips = PokerChips.new(world)
	cards = PokerCards.new(world)
	world.poker_root.add_child(chips)
	world.poker_root.add_child(cards)


func _seat(pids: Array) -> void:
	world.arrange(pids.map(func(pid): return {"pid": pid}), ME, true, false)


func _c(rank: int, suit: int) -> int:
	return PokerCard.make(rank, suit)


func _players(pids: Array, status := PokerRules.STATUS_ACTIVE) -> Array:
	return pids.map(func(pid): return {"pid": pid, "stack": 1980, "bet": 20, "status": status, "shown": [], "left": false})


func _sync(pids: Array, board: Array, pots: Array) -> void:
	var players := _players(pids)
	chips.sync(players, pots)
	cards.sync(pids, players, board, ME, [_c(14, 0), _c(14, 1)])


func _poker_nodes() -> Array:
	# poker_root 下的筹码与牌(牌架不算),加上各家牌扇里的牌
	var nodes := world.poker_root.find_children("*", "ChipStack3D", true, false)
	nodes.append_array(world.poker_root.find_children("*", "Card3D", true, false))
	for pid in world.patrons:
		nodes.append_array(world.patrons[pid].fan.get_children().filter(func(n): return n is Card3D))
	return nodes.filter(func(n: Node) -> bool: return not n.is_queued_for_deletion())


func test_full_table_from_a_view():
	var pids := [1, 2, 3, 4, 5, 6, 7, 8]
	_seat(pids)
	_sync(pids, [_c(2, 0), _c(9, 1), _c(12, 2)], [{"amount": 300, "eligible": pids}, {"amount": 90, "eligible": [1, 2]}])
	# 8 摞筹码 + 8 处下注 + 2 个底池;3 张公共牌 + 8 × 2 张手牌
	assert_eq(_poker_nodes().size(), 8 + 8 + 2 + 3 + 16)


func test_fewer_players_leave_no_extra_nodes():
	var pids := [1, 2, 3, 4, 5, 6, 7, 8]
	_seat(pids)
	_sync(pids, [_c(2, 0), _c(9, 1), _c(12, 2)], [{"amount": 300, "eligible": pids}])
	_seat([1, 2, 3])
	_sync([1, 2, 3], [], [])
	await wait_process_frames(1)
	assert_eq(_poker_nodes().size(), 3 + 3 + 3 * 2)


func test_a_hand_plays_through_and_the_table_tears_down():
	_seat([1, 2, 3])
	chips.sync([1, 2, 3].map(func(pid): return {"pid": pid, "stack": 2000, "bet": 0}), [])
	await chips.move_button(1)
	await chips.bet(2, 10, 1990)
	await chips.bet(3, 20, 1980)
	await cards.deal_hole([2, 3, 1], ME, [_c(14, 0), _c(14, 1)])
	await chips.bet(1, 20, 1980)
	await cards.fold(2)
	await chips.collect([{"amount": 50, "eligible": [1, 3]}], {})
	await cards.deal_board([_c(2, 0), _c(9, 1), _c(12, 2)], 0)
	await cards.reveal(3, [_c(9, 0), _c(9, 2)])
	await cards.reveal(ME, [_c(14, 0), _c(14, 1)])
	cards.highlight([_c(14, 0), _c(14, 1)])
	await chips.award(0, {1: 50}, {1: 2030})
	assert_eq(chips.stack_amount(1), 2030)
	assert_eq(chips.pot_amounts(), [])
	await cards.sweep()
	world.cards.sync({2: 2}, [])   # 骗子酒馆的牌(假设残留):拆德州台时不动
	world.clear_poker()
	await wait_process_frames(1)
	assert_eq(world.poker_root.get_child_count(), 0, "TableWorld 下没有德州节点")
	for pid in [1, 3]:
		assert_eq(world.patrons[pid].fan.get_child_count(), 0, "牌扇里没有德州的牌")
	assert_eq(world.patrons[2].fan.get_child_count(), 2, "CardTable 的牌还在")
	assert_eq(world.patrons.size(), 3, "酒客留着,回等待厅接着用")
