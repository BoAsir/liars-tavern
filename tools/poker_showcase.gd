extends Node
# 截图与性能用的德州展台(tools/shot.gd --poker-showcase、tools/perf_probe.gd --showcase=poker):
# 德州桌坐满 8 位酒客,5 张公共牌、2 人亮牌、2 人弃牌、各家筹码与本轮下注、2 个底池、庄家按钮、自己的两张手牌。
# 用假视图数据走与德州牌桌相同的对账接口(PokerChips.sync / PokerCards.sync),机位取自 TableWorld。
# worst_case 为真时每摞筹码、每处下注都摆满(40 枚)、底池 7 个:约 900 枚筹码,性能对比用的最坏情况。


const ME := 1
const SEATS := 8
const BUTTON := 4
const SETTLE := 3.0   # 秒:登场动画与登场的烟(Fx.smoke_puff 2.8 秒)都散了再拍
const WORST_AMOUNT := 1000000   # 远超每摞显示上限(40 枚)
const WORST_POTS := 7           # 8 人全下额度各不相同时最多 7 个底池

var world: TableWorld
var chips: PokerChips
var cards: PokerCards
var worst_case := false


func build(tavern: Tavern) -> void:
	await CardFaces.build(self)
	Card3D.refresh_materials()
	world = TableWorld.new(tavern)
	tavern.table_root.add_child(world)
	# 同 main.apply_table_mode(德州):桌子放大,收起烛台与目标牌立牌(tools 里不能引用 main)
	world.configure_table(SeatLayout.POKER_TABLE_RADIUS)
	tavern.set_table_decor_visible(false)
	world.cards.set_stand_visible(false)
	world.arrange(range(1, SEATS + 1).map(func(pid): return {"pid": pid}), ME, true, false)
	chips = PokerChips.new(world)
	cards = PokerCards.new(world)
	world.poker_root.add_child(chips)
	world.poker_root.add_child(cards)
	var players := _players()
	chips.sync(players, _pots())
	chips.place_button(BUTTON)
	cards.sync(range(1, SEATS + 1), players, _board(), ME, [PokerCard.make(PokerCard.ACE, PokerCard.SPADES),
		PokerCard.make(PokerCard.KING, PokerCard.HEARTS)])
	await get_tree().create_timer(SETTLE).timeout
	_pose()


func _players() -> Array:
	# 两人亮牌(3 号、6 号全下)、两人弃牌(2 号、7 号),其余还在本手中;筹码多寡不一,各种面额都看得到
	var c := func(rank: int, suit: int) -> int: return PokerCard.make(rank, suit)
	var rows := [
		[1, 1840, 200, PokerRules.STATUS_ACTIVE, []],
		[2, 2650, 0, PokerRules.STATUS_FOLDED, []],
		[3, 0, 0, PokerRules.STATUS_ALLIN, [c.call(PokerCard.QUEEN, PokerCard.DIAMONDS), c.call(PokerCard.QUEEN, PokerCard.CLUBS)]],
		[4, 5370, 200, PokerRules.STATUS_ACTIVE, []],
		[5, 960, 200, PokerRules.STATUS_ACTIVE, []],
		[6, 0, 0, PokerRules.STATUS_ALLIN, [c.call(PokerCard.JACK, PokerCard.HEARTS), c.call(10, PokerCard.HEARTS)]],
		[7, 12480, 0, PokerRules.STATUS_FOLDED, []],
		[8, 3110, 80, PokerRules.STATUS_ACTIVE, []],
	]
	return rows.map(func(row: Array) -> Dictionary:
		return {"pid": row[0], "stack": WORST_AMOUNT if worst_case else row[1], "bet": WORST_AMOUNT if worst_case else row[2],
			"status": row[3], "shown": row[4], "left": false})


func _pots() -> Array:
	if worst_case:
		var all := range(1, SEATS + 1)
		return range(WORST_POTS).map(func(_i): return {"amount": WORST_AMOUNT, "eligible": all})
	return [{"amount": 2400, "eligible": [1, 3, 4, 5, 6, 8]}, {"amount": 860, "eligible": [1, 4, 5, 8]}]


func _board() -> Array:
	return [PokerCard.make(PokerCard.QUEEN, PokerCard.HEARTS), PokerCard.make(9, PokerCard.HEARTS),
		PokerCard.make(4, PokerCard.SPADES), PokerCard.make(PokerCard.KING, PokerCard.CLUBS),
		PokerCard.make(2, PokerCard.DIAMONDS)]


func _pose() -> void:
	# 演出里会出现的几种姿态:行动者前倾、亮牌的人一个得意一个发愁、弃牌的人发愁
	world.look_all_at(Vector3(0, SeatLayout.TABLE_TOP + 0.1, 0))
	world.patrons[8].set_active(true)
	world.patrons[3].set_expression("smug")
	world.patrons[6].set_expression("worried")
	world.patrons[2].set_expression("worried")
	cards.highlight([PokerCard.make(PokerCard.QUEEN, PokerCard.DIAMONDS), PokerCard.make(PokerCard.QUEEN, PokerCard.CLUBS),
		PokerCard.make(PokerCard.QUEEN, PokerCard.HEARTS)])
