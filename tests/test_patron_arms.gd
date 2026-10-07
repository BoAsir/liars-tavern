extends GutTest
# 酒客的手:拿着牌时双手也搭在桌面上,不去扶牌扇(扶牌会挡住牌面)。
# 走与牌桌界面相同的接线:第三人称举牌 → 挂上自己的牌扇 → 发牌对账。


const POSE_SETTLE := 0.5   # 秒:旧的扶牌补间为 0.3 秒,等它走完再量手的位置
const SIT_BAND := Vector2(0.03, 0.07)  # 米:掌心高出桌面的范围——低了是陷进桌里/贴在桌边,高了是悬空
const ON_TABLE := 0.02     # 米:手掌至少有这么多搭在桌面以内

var world: TableWorld


func before_each():
	world = TableWorld.new(null)
	add_child_autofree(world)
	world.arrange([{"pid": 1}, {"pid": 2}], 1, true, true)
	var me: Patron = world.patrons[1]
	me.present_hand_to(world.third_person_view(1).origin)
	world.cards.attach_hand(me.fan)


func test_paws_rest_on_the_table_while_holding_cards():
	world.cards.sync({1: 5, 2: 5}, [Card.QUEEN, Card.KING, Card.ACE, Card.JOKER, Card.QUEEN])
	await wait_seconds(POSE_SETTLE)
	assert_eq(world.cards.held.get(2, []).size(), 5, "对手确实拿着牌")
	assert_eq(world.cards.my_cards.size(), 5, "自己确实拿着牌")
	for pid in [1, 2]:
		_assert_paws_on_table(world.patrons[pid], "pid %d" % pid)


func test_paws_go_back_to_the_table_after_reaching_for_the_pile():
	world.cards.sync({1: 5, 2: 5}, [Card.QUEEN, Card.KING, Card.ACE, Card.JOKER, Card.QUEEN])
	var other: Patron = world.patrons[2]
	await other.reach_toward_center()
	await wait_seconds(POSE_SETTLE)
	_assert_paws_on_table(other, "出牌伸手之后")


func _assert_paws_on_table(patron: Patron, label: String) -> void:
	var left_hand: Node3D = patron.find_child("ArmL", true, false).get_node("Hand")
	for hand in [left_hand, patron.right_hand]:
		# 换算到座位局部坐标(不受登场缩放影响),再按未缩放的座位变换放回牌桌坐标
		var seat_local := patron.to_local(hand.global_position)
		var on_table := patron.transform.orthonormalized() * seat_local
		assert_between(on_table.y, SeatLayout.TABLE_TOP + SIT_BAND.x, SeatLayout.TABLE_TOP + SIT_BAND.y,
			"%s 的 %s 应贴着桌面" % [label, hand.get_parent().name])
		var inner_edge := Vector2(on_table.x, on_table.z).length() - Patron.PAW_RADIUS
		assert_lt(inner_edge, SeatLayout.TABLE_RADIUS - ON_TABLE,
			"%s 的 %s 应搭到桌面以内" % [label, hand.get_parent().name])
