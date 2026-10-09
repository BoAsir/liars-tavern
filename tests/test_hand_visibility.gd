extends GutTest
# 越肩镜头下自己的手牌不被自己的头(含帽子、耳朵)挡住:坐着、轮到自己前倾时都一样,
# 头往前、往两侧探到最远也一样。从镜头向每张牌上的采样点打射线,和头部每个网格的包围盒求交
# (包围盒比实际形状大,所以只要求被挡的采样点极少,且每张牌的中心都看得见)。


const SETTLE := 1.2          # 秒:登场缩放与前倾插值走完
const NECK_SETTLE := 1.2     # 秒:脖子弹簧追到目标(最远 2.55 米)
const MAX_BLOCKED := 0.05    # 允许被包围盒挡住的采样点比例(包围盒的角比实际形状大)
const R := Patron.NECK_REACH
const NECK_OFFSETS := [Vector3.ZERO, Vector3(0.4, 0, 0), Vector3(0.85, 0, 0), Vector3(0.6, 0, -0.6),
	Vector3(0, 0, -0.85), Vector3(-0.85, 0, 0), Vector3(0.6, 0, 0.6),
	# 伸到最远(三倍之后):正前、两侧、斜前,以及中途扫过牌扇的位置
	Vector3(R, 0, 0), Vector3(-R, 0, 0), Vector3(0, 0, -R), Vector3(R * 0.7, 0, -R * 0.7), Vector3(-R * 0.7, 0, -R * 0.7),
	Vector3(1.5, 0, 0), Vector3(1.5, 0, -0.5)]

var world: TableWorld
var me: Patron


func before_each():
	world = TableWorld.new(null)
	add_child_autofree(world)
	world.arrange([{"pid": 1}, {"pid": 2}], 1, true, false)
	me = world.patrons[1]
	me.present_hand_to(_eye())
	world.cards.attach_hand(me.fan)
	world.cards.sync({1: 5, 2: 5}, [Card.QUEEN, Card.KING, Card.ACE, Card.JOKER, Card.QUEEN])


func test_head_never_hides_the_hand_while_seated():
	await wait_seconds(SETTLE)
	await _assert_hand_visible_for_all_offsets("坐着")


func test_head_never_hides_the_hand_on_own_turn():
	me.set_active(true)
	await wait_seconds(SETTLE)
	await _assert_hand_visible_for_all_offsets("轮到自己前倾")


func _assert_hand_visible_for_all_offsets(posture: String) -> void:
	for offset in NECK_OFFSETS:
		me.set_neck_target(offset)
		await wait_seconds(NECK_SETTLE)
		var label := "%s,头探到 %s" % [posture, offset]
		var total := 0
		var blocked := 0
		for card in world.cards.my_cards:
			assert_false(_blocked(card.global_transform.origin), label + ":牌的中心被头挡住")
			for point in _card_points(card):
				total += 1
				if _blocked(point):
					blocked += 1
		assert_lte(float(blocked) / total, MAX_BLOCKED, label + ":被挡住 %d/%d 个采样点" % [blocked, total])


func _eye() -> Vector3:
	return world.third_person_view(1).origin


func _card_points(card: Card3D) -> Array:
	var points := []
	for i in 5:
		for j in 5:
			var local := Vector3((i / 4.0 - 0.5) * Card3D.WIDTH * 0.9, 0.0, (j / 4.0 - 0.5) * Card3D.HEIGHT * 0.9)
			points.append(card.global_transform * local)
	return points


func _blocked(point: Vector3) -> bool:
	for node in me.head.find_children("*", "VisualInstance3D", true, false):
		var mesh := node as VisualInstance3D
		if mesh.is_visible_in_tree() and (mesh.global_transform * mesh.get_aabb()).intersects_segment(_eye(), point) != null:
			return true
	return false
