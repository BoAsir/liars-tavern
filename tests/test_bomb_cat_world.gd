extends GutTest
# 炸弹猫的 3D 层(无头):牌面数组纹理的层数与层序、所有牌共用一份材质、牌扇按张数排开 / 超过 10 张压缩(不加网格)、
# 牌堆与弃牌堆的高度、BombCatCards 按视图对账(各家张数、自己的牌面、牌堆张数)与偷看浮牌、拆台。


const C := preload("res://src/core/bomb_cat/bomb_cat_card.gd")
const ME := 1

var world: TableWorld
var cards: BombCatCards


func before_each():
	BombCatFaces.clear()
	world = TableWorld.new(null)
	add_child_autofree(world)
	world.arrange([{"pid": 1}, {"pid": 2}, {"pid": 3}], ME, true, false)
	cards = BombCatCards.new(world)
	cards.my_pid = ME
	world.poker_root.add_child(cards)


func after_each():
	BombCatFaces.clear()


# —— 牌面 ——

func test_face_atlas_has_a_layer_for_the_back_and_every_card():
	assert_eq(BombCatFaces.layer_count(), C.ALL.size() + 1, "13 种牌 + 牌背")
	assert_eq(BombCatFaces.face_array().get_layers(), BombCatFaces.layer_count())
	assert_eq(BombCatFaces.foil_array().get_layers(), BombCatFaces.layer_count())
	assert_eq(BombCatFaces.layer(BombCatFaces.BACK), 0)
	var seen := {}
	for id in C.ALL:
		var layer := BombCatFaces.layer(id)
		assert_gt(layer, 0, id)
		assert_false(seen.has(layer), "每种牌一层")
		seen[layer] = true
	assert_eq(BombCatFaces.layer("bogus"), 0, "不认识的牌给牌背")


func test_headless_build_falls_back_and_signals():
	watch_signals(BombCatFaces.built_signal().get_object())
	await BombCatFaces.build(self)
	assert_true(BombCatFaces.is_built())
	for id in BombCatFaces.LAYERS:
		assert_not_null(BombCatFaces.texture(id))
	assert_signal_emitted(BombCatFaces.built_signal().get_object(), "built")


func test_every_card_shares_one_material():
	var a := BombCard3D.new(C.BOMB)
	var b := BombCard3D.new(C.SNACK_FISH)
	add_child_autofree(a)
	add_child_autofree(b)
	var mat_a: Material = (a.get_node("Slab") as MeshInstance3D).material_override
	var mat_b: Material = (b.get_node("Slab") as MeshInstance3D).material_override
	assert_same(mat_a, mat_b, "所有炸弹猫的牌共用一份材质")
	assert_same(mat_a, BombCatFaces.material())
	assert_eq((a.get_node("Slab") as MeshInstance3D).get_instance_shader_parameter("face"), BombCatFaces.layer(C.BOMB))
	b.set_card("nonsense")
	assert_true(b.is_back(), "坏 id 当牌背")


func test_clear_drops_the_cached_material():
	var first := BombCatFaces.material()
	BombCatFaces.clear()
	assert_ne(BombCatFaces.material(), first)


# —— 牌扇 ——

func test_fan_spacing_is_constant_up_to_ten_cards_then_compresses():
	for count in range(2, BombCatLayout.COMPRESS_FROM + 1):
		assert_almost_eq(BombCatLayout.spacing_for(count), BombCatLayout.SPACING, 0.0001, "%d 张" % count)
	var full := BombCatLayout.fan_width(BombCatLayout.COMPRESS_FROM)
	for count in [11, 14, 20, 30]:
		assert_almost_eq(BombCatLayout.fan_width(count), full, 0.0001, "%d 张压缩成 10 张的宽度" % count)
		assert_lt(BombCatLayout.spacing_for(count), BombCatLayout.SPACING)


func test_fan_rotation_and_drop_stay_bounded():
	for count in [1, 3, 8, 12, 25]:
		var slots := BombCatLayout.fan_slots(count)
		assert_eq(slots.size(), count)
		var first: Dictionary = slots[0]
		var last: Dictionary = slots[-1]
		assert_lte(absf(first["rot"] - last["rot"]), deg_to_rad(BombCatLayout.SPREAD_TOTAL_DEG) + 0.0001, "%d 张总转角" % count)
		assert_lte(absf(first["y"]), BombCatLayout.DROP_EDGE + 0.0001)
		assert_almost_eq(first["x"], -last["x"], 0.0001, "左右对称")
	assert_eq(BombCatLayout.fan_slots(0), [])


func test_fan_slot_lift_moves_toward_the_card_top():
	var flat := BombCatLayout.fan_slot(0, 1)
	var lifted := BombCatLayout.fan_slot(0, 1, 0.03)
	assert_almost_eq(lifted.origin.z, flat.origin.z - 0.03, 0.0001)
	assert_eq(BombCatLayout.fan_slot(5, 3), Transform3D(), "越界给单位变换")


func test_pile_heights_grow_with_counts_and_cap():
	assert_eq(BombCatLayout.stack_height(0), 0.0)
	assert_almost_eq(BombCatLayout.stack_height(10), 10 * BombCatLayout.CARD_STEP, 0.00001)
	assert_eq(BombCatLayout.stack_height(10000), BombCatLayout.MAX_STACK_HEIGHT)
	assert_gt(BombCatLayout.deck_top(20).origin.y, BombCatLayout.deck_top(5).origin.y)
	assert_eq(BombCatLayout.discard_slot(7), BombCatLayout.discard_slot(7), "弃牌的落点各端一致")
	assert_gt(BombCatLayout.discard_slot(8).origin.y, BombCatLayout.discard_slot(7).origin.y)


func test_bomb_show_faces_the_table_centre():
	var xform := BombCatLayout.bomb_show(0.0, SeatLayout.SEAT_RADIUS)
	var normal := xform.basis.y.normalized()
	assert_almost_eq(normal.dot(Vector3(0, 0, -1)), 1.0, 0.01, "牌面朝桌心")
	assert_gt(xform.origin.y, SeatLayout.TABLE_TOP)


# —— 牌层对账 ——

func test_sync_lays_out_every_hand_and_the_piles():
	cards.sync({1: 3, 2: 5, 3: 12}, [C.SKIP, C.NOPE, C.DEFUSE], 21, 9, [C.SNACK_FISH, C.SNACK_FISH, C.PEEK])
	assert_eq(cards.held_count(2), 5)
	assert_eq(cards.held_count(3), 12, "超过 10 张照样每张一张牌(压缩扇面,不加网格)")
	assert_eq(cards.my_ids(), [C.SKIP, C.NOPE, C.DEFUSE])
	assert_eq(cards.held_cards(2)[0].card_id, BombCatFaces.BACK, "别人的是牌背")
	assert_eq(cards.deck_count, 21)
	assert_eq(cards.discard_ids(), [C.SNACK_FISH, C.SNACK_FISH, C.PEEK])
	assert_eq(cards.held_cards(3)[0].get_parent(), world.patrons[3].fan, "牌在酒客的牌扇里")


func test_sync_reuses_matching_cards_and_drops_gone_players():
	cards.sync({1: 2, 2: 2}, [C.SKIP, C.NOPE], 10, 0, [])
	var keep: Node = cards.held_cards(2)[0]
	cards.sync({1: 2, 2: 2}, [C.SKIP, C.NOPE], 9, 1, [C.SKIP])
	assert_same(cards.held_cards(2)[0], keep, "张数没变就不重建")
	cards.sync({1: 2}, [C.SKIP, C.NOPE], 9, 1, [C.SKIP])
	assert_eq(cards.held_count(2), 0)


func test_peek_cards_float_under_the_camera_and_clear():
	var camera := Camera3D.new()
	add_child_autofree(camera)
	cards.show_peek([C.BOMB, C.SKIP, "bogus", C.NOPE], camera)
	assert_eq(cards.peek_nodes().size(), 3, "坏 id 丢掉")
	assert_eq(cards.peek_nodes()[0].get_parent(), camera)
	cards.clear_peek()
	assert_eq(cards.peek_nodes().size(), 0)


func test_pick_hits_my_fan_cards():
	cards.sync({1: 3}, [C.SKIP, C.NOPE, C.DEFUSE], 10, 0, [])
	var card: BombCard3D = cards.held_cards(ME)[1]
	# 牌扇里后一张压住前一张的右边:点它露出来的左边
	var normal := card.global_basis.y.normalized()
	var target := card.global_position - card.global_basis.x * 0.04 + normal * 0.0005
	assert_eq(cards.pick(target + normal * 0.5, -normal), 1)
	assert_eq(cards.pick(target + Vector3(0, 5, 0), Vector3.UP), -1)


func test_clear_poker_tears_the_bomb_cat_layer_down():
	cards.sync({1: 2, 2: 3}, [C.SKIP, C.NOPE], 10, 0, [])
	world.clear_poker()
	await get_tree().process_frame
	assert_eq(world.poker_root.get_child_count(), 0)
	for pid in world.patrons:
		assert_eq(world.patrons[pid].fan.get_children().filter(func(c): return c is BombCard3D).size(), 0, "牌扇里的炸弹猫牌一并收走")
