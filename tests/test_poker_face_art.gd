extends GutTest
# 德州牌面的几何与排版(PokerFaceArt,纯几何):超大角标约占牌高 38%、花色在点数下方、右下角标是左上的中心对称、
# 中央大花色居中、只有 J/Q/K 有冠饰、四色花色、全部画在金边以内;
# 缩到 30×42 像素仍认得出:角标与中央之间留出纸缝(不粘成一团)、「10」的两个数字分开、点数的笔画里没有被填实的洞;
# 每个多边形都能三角化(draw_colored_polygon 三角化失败会报引擎错误,那一块就画不出来)。


const ALL_RANKS := [2, 3, 4, 5, 6, 7, 8, 9, 10, PokerCard.JACK, PokerCard.QUEEN, PokerCard.KING, PokerCard.ACE]
const SMALLEST_WIDTH := 30.0          # 规格 §6.1 摊牌条小牌 ≥ 30×42
const RANK_SHARE := Vector2(0.36, 0.40)   # 规格 §5.2:点数约占牌高 38%
const SPEC_DIAMOND := Color(0.2, 0.45, 0.95)
const SPEC_CLUB := Color(0.15, 0.6, 0.25)
const COLOR_TOLERANCE := 0.06
const DISC_SEGMENTS := 24


func _cards() -> Array:
	var out := []
	for suit in PokerCard.SUITS:
		for rank in ALL_RANKS:
			out.append(PokerCard.make(rank, suit))
	return out


func _bounds(polys: Array) -> Rect2:
	var rect := Rect2(polys[0][0], Vector2.ZERO)
	for poly in polys:
		for p in poly:
			rect = rect.expand(p)
	return rect


func _keeps_clear(a: Array, b: Array, clearance: float) -> bool:
	# a 外扩 clearance(圆角)后与 b 不相交 ⇔ 两组多边形相距至少 clearance。外扩可能闭合出洞(顺时针),洞不算 a 的地盘
	for pa in a:
		for grown in Geometry2D.offset_polygon(pa, clearance, Geometry2D.JOIN_ROUND):
			if Geometry2D.is_polygon_clockwise(grown):
				continue
			for pb in b:
				if not Geometry2D.intersect_polygons(grown, pb).is_empty():
					return false
	return true


func _corner(card: int) -> Array:
	return PokerFaceArt.index_polygons(PokerCard.rank(card), PokerCard.suit(card))


func _turned(card: int) -> Array:
	return _corner(card).map(func(poly): return PokerFaceArt.half_turn(poly))


func _centre_group(card: int) -> Array:
	# 中央花色 + 冠饰 + 冠饰上的宝石(宝石是画家用圆画的,这里折成多边形)
	var art := PokerFaceArt.layout(card)
	var group: Array = art["center"].duplicate()
	if not art["crown"].is_empty():
		group.append(art["crown"])
	for jewel in art["jewels"]:
		group.append(_disc(jewel, PokerFaceArt.JEWEL_RADIUS))
	return group


func _disc(center: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in DISC_SEGMENTS:
		out.append(center + Vector2.from_angle(TAU * i / DISC_SEGMENTS) * radius)
	return out


func _components(polys: Array) -> Array:
	# 互相接触的多边形归成一组(并查集的朴素版):用来数一个点数由几块分开的字形组成
	var groups := []
	for poly in polys:
		var merged := [poly]
		var rest := []
		for group in groups:
			if _keeps_clear(group, [poly], 0.5):
				rest.append(group)
			else:
				merged.append_array(group)
		rest.append(merged)
		groups = rest
	return groups


func test_card_size_is_shared_with_poker_faces():
	assert_eq(PokerFaceArt.SIZE, Vector2i(256, 372))
	assert_eq(PokerFaces.SIZE, PokerFaceArt.SIZE)


func test_four_colour_suits_follow_the_spec():
	var colors: Array = PokerFaceArt.SUIT_COLORS
	assert_eq(colors.size(), 4)
	# 动森式柔化后:♠ 是带靛色的深墨(仍远暗于纸)、♥ 是柔一点的红(红通道明显压过另两个)
	assert_lt(colors[PokerCard.SPADES].get_luminance(), 0.25, "♠ 深墨")
	var heart: Color = colors[PokerCard.HEARTS]
	assert_true(heart.r > 0.75 and heart.r - maxf(heart.g, heart.b) > 0.45, "♥ 红 %s" % heart)
	for pair in [[PokerCard.DIAMONDS, SPEC_DIAMOND], [PokerCard.CLUBS, SPEC_CLUB]]:
		var c: Color = colors[pair[0]]
		var want: Color = pair[1]
		assert_almost_eq(Vector3(c.r, c.g, c.b), Vector3(want.r, want.g, want.b), Vector3.ONE * COLOR_TOLERANCE,
			PokerCard.SUIT_NAMES[pair[0]])
	for i in 4:
		for j in range(i + 1, 4):
			var a: Color = colors[i]
			var b: Color = colors[j]
			assert_gt(Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length(), 0.4, "花色 %d 与 %d 要一眼分清" % [i, j])


func test_rank_is_a_jumbo_index_in_the_top_left():
	for rank in ALL_RANKS:
		var bounds := _bounds(PokerFaceArt.rank_polygons(rank, PokerFaceArt.rank_box(rank)))
		var share := bounds.size.y / PokerFaceArt.SIZE.y
		assert_between(share, RANK_SHARE.x, RANK_SHARE.y, "%s 占牌高 %.3f" % [PokerCard.rank_label(rank), share])
		assert_lt(bounds.get_center().x, PokerFaceArt.SIZE.x / 2.0, PokerCard.rank_label(rank))
		assert_lt(bounds.position.y, PokerFaceArt.SIZE.y * 0.1, PokerCard.rank_label(rank))


func test_index_suit_sits_under_the_rank():
	for card in _cards():
		var rank := PokerCard.rank(card)
		var rank_count := PokerFaceArt.rank_polygons(rank, PokerFaceArt.rank_box(rank)).size()
		var corner := _corner(card)
		var glyph := _bounds(corner.slice(0, rank_count))
		var pip := _bounds(corner.slice(rank_count))
		assert_gt(pip.position.y, glyph.end.y, PokerCard.label(card))
		assert_between(pip.get_center().x, glyph.position.x, glyph.end.x, PokerCard.label(card))


func test_bottom_right_index_is_the_top_left_turned_half_way():
	assert_eq(PokerFaceArt.half_turn(PackedVector2Array([Vector2.ZERO])), PackedVector2Array([Vector2(PokerFaceArt.SIZE)]))
	for card in _cards():
		var corner := _corner(card)
		var index: Array = PokerFaceArt.layout(card)["index"]
		assert_eq(index.size(), corner.size() * 2, PokerCard.label(card))
		for i in corner.size():
			assert_eq(index[i], corner[i])
			assert_eq(index[corner.size() + i], PokerFaceArt.half_turn(corner[i]))


func test_centre_suit_and_crown_are_centred_on_the_card():
	var middle := Vector2(PokerFaceArt.SIZE) / 2.0
	for card in _cards():
		var center := _bounds(_centre_group(card)).get_center()
		assert_almost_eq(center.x, middle.x, 1.0, PokerCard.label(card))
		assert_almost_eq(center.y, middle.y, 1.0, PokerCard.label(card))


func test_only_jack_queen_and_king_wear_a_crown():
	for card in _cards():
		var rank := PokerCard.rank(card)
		var art := PokerFaceArt.layout(card)
		var crowned := rank in [PokerCard.JACK, PokerCard.QUEEN, PokerCard.KING]
		assert_eq(not art["crown"].is_empty(), crowned, PokerCard.label(card))
		assert_eq(art["jewels"].size(), PokerFaceArt.CROWN_POINTS.get(rank, 0), PokerCard.label(card))


func test_everything_is_drawn_inside_the_gold_frame():
	# 金边内沿:画家的金边内缩 + 线宽
	var inset := PokerFacePainter.FRAME_INSET + PokerFacePainter.FRAME_WIDTH
	var interior := Rect2(Vector2.ONE * inset, Vector2(PokerFaceArt.SIZE) - Vector2.ONE * inset * 2.0)
	for card in _cards():
		var bounds := _bounds(_corner(card) + _turned(card) + _centre_group(card))
		assert_true(interior.encloses(bounds), "%s %s" % [PokerCard.label(card), bounds])


func test_corners_and_centre_keep_paper_between_them_at_the_smallest_size():
	# 至少留 MIN_CLEARANCE 宽的纸,缩到 30 像素宽时还有一个多像素的缝:否则角标、中央花色与冠饰粘成一团
	assert_gte(PokerFaceArt.MIN_CLEARANCE, PokerFaceArt.SIZE.x / SMALLEST_WIDTH)
	for card in _cards():
		var label := PokerCard.label(card)
		assert_true(_keeps_clear(_corner(card), _centre_group(card), PokerFaceArt.MIN_CLEARANCE), "左上角标贴着中央 " + label)
		assert_true(_keeps_clear(_turned(card), _centre_group(card), PokerFaceArt.MIN_CLEARANCE), "右下角标贴着中央 " + label)
		assert_true(_keeps_clear(_corner(card), _turned(card), PokerFaceArt.MIN_CLEARANCE), "两个角标相碰 " + label)


func test_ten_is_two_separate_digits():
	var polys := PokerFaceArt.rank_polygons(10, PokerFaceArt.rank_box(10))
	var digits := _components(polys)
	assert_eq(digits.size(), 2, "「1」和「0」不能连成一块")
	if digits.size() == 2:
		assert_true(_keeps_clear(digits[0], digits[1], PokerFaceArt.MIN_CLEARANCE), "两个数字之间要有缝")


func test_rank_strokes_leave_no_filled_holes():
	# offset_polyline 把闭合的笔画加粗时会多出一个顺时针的「洞」;画家把每个多边形都填色,洞就被填实了(4 的三角形空心)
	for rank in ALL_RANKS:
		for poly in PokerFaceArt.rank_polygons(rank, PokerFaceArt.rank_box(rank)):
			assert_false(Geometry2D.is_polygon_clockwise(poly), PokerCard.rank_label(rank))


func test_every_polygon_can_be_triangulated():
	for card in _cards():
		var art := PokerFaceArt.layout(card)
		var polys: Array = art["index"] + art["center"]
		if not art["crown"].is_empty():
			polys.append(art["crown"])
		for poly in polys:
			assert_false(Geometry2D.triangulate_polygon(poly).is_empty(), PokerCard.label(card))
