class_name PokerFaceArt
# 德州牌面的矢量图形与排版(纯几何,单测覆盖)。坐标是牌面像素,y 向下。
# 「超大角标」:点数约占牌高 38%,左上一个,右下一个(绕牌心转 180°),花色在点数下方;
# 中央一个大花色,J/Q/K 在花色上方加冠饰。
# 点数是粗笔画、花色是多边形与圆拼成的,都不依赖字体:界面字体里没有花色字形,
# 系统字体各平台也不一样,自己画才能保证每台机器上缩到 30×42 像素都认得出。


const SIZE := Vector2i(256, 372)

# 四色牌:暖光与牌面着色器(会压暗)下也要一眼分清,下标即 PokerCard 的花色
const SUIT_COLORS := [
	Color(0.07, 0.06, 0.06),   # ♠ 墨黑
	Color(0.80, 0.07, 0.09),   # ♥ 红
	Color(0.20, 0.45, 0.95),   # ♦ 亮蓝
	Color(0.15, 0.60, 0.25),   # ♣ 亮绿
]

# —— 角标 ——
# 两个角标各占一侧,中央花色夹在中间:点数框右下角(2 的底横、A 与 K 的右腿、Q 的尾巴)和「10」的「0」
# 离中央花色最近,宽度与中央花色的大小一起定,保证留得出 MIN_CLEARANCE 的纸缝
const RANK_HEIGHT := 140.0                # 约占牌高 38%:缩到 30×42 像素时仍有约 16 像素高
const RANK_WIDTH := 74.0                  # 窄体
const TEN_WIDTH := 88.0                   # 「10」两个字并排,比单字宽
const STROKE := 21.0                      # 笔画粗细:缩到 30×42 时仍有两个多像素
const TEN_STROKE := 18.0                  # 「10」挤在一格里:笔画稍细,两字之间与「0」的空心才留得出来
const TEN_ONE_X := 0.13                   # 「1」的竖笔位置(单位框):左边留给短旗
const TEN_ZERO_HALF_WIDTH := 0.23         # 「0」的半宽(单位框)
const INDEX_ORIGIN := Vector2(12, 12)     # 左上角标点数框的左上角
const INDEX_SUIT_HEIGHT := 46.0
const INDEX_SUIT_GAP := 11.0              # 点数与下方花色的间距:角标花色正好与中央花色在同一条水平线上
# —— 中央 ——
const CENTER_SUIT_HEIGHT := 76.0
const FACE_SUIT_HEIGHT := 64.0            # J/Q/K 的花色缩小,让出冠饰的位置
const CROWN_SIZE := Vector2(56, 30)
const CROWN_GAP := 6.0
const CROWN_POINTS := {PokerCard.JACK: 4, PokerCard.QUEEN: 5, PokerCard.KING: 3}
const JEWEL_RADIUS := 4.5

# 角标、中央花色与冠饰之间至少留这么宽的纸:缩到 30×42 像素(约 1/8.5)时还有一个多像素的缝,不粘成一团
const MIN_CLEARANCE := 10.0

const ARC_STEP := 0.12                    # 弧线每段约 7°:放大到 140 像素也看不出折线
const CIRCLE_SEGMENTS := 40
const BEZIER_SEGMENTS := 16
const DIAMOND_PINCH := 0.16               # 方块四边向中心收的比例:微凹的边更像牌上的方块


# —— 整张牌 ——

static func layout(card: int) -> Dictionary:
	# {"ink": 花色色, "index": 两个角标的多边形, "center": 中央花色, "crown": 冠饰轮廓(非 J/Q/K 为空), "jewels": 冠饰宝石圆心}
	var rank := PokerCard.rank(card)
	var suit := PokerCard.suit(card)
	var corner := index_polygons(rank, suit)
	var index: Array[PackedVector2Array] = corner.duplicate()
	for poly in corner:
		index.append(half_turn(poly))
	var art := {"ink": SUIT_COLORS[suit], "index": index, "center": center_polygons(rank, suit),
		"crown": PackedVector2Array(), "jewels": PackedVector2Array()}
	if CROWN_POINTS.has(rank):
		art["crown"] = crown_polygon(crown_rect(), CROWN_POINTS[rank])
		art["jewels"] = crown_jewels(crown_rect(), CROWN_POINTS[rank])
	return art


static func index_polygons(rank: int, suit: int) -> Array[PackedVector2Array]:
	# 左上角标:点数 + 正下方的花色(花色按点数栏居中,「10」变宽也不挪)
	var polys := rank_polygons(rank, rank_box(rank))
	var column_x := INDEX_ORIGIN.x + RANK_WIDTH / 2.0
	var suit_y := INDEX_ORIGIN.y + RANK_HEIGHT + INDEX_SUIT_GAP + INDEX_SUIT_HEIGHT / 2.0
	polys.append_array(suit_polygons(suit, Vector2(column_x, suit_y), INDEX_SUIT_HEIGHT))
	return polys


static func rank_box(rank: int) -> Rect2:
	return Rect2(INDEX_ORIGIN, Vector2(TEN_WIDTH if rank == 10 else RANK_WIDTH, RANK_HEIGHT))


static func center_polygons(rank: int, suit: int) -> Array[PackedVector2Array]:
	var mid := Vector2(SIZE) / 2.0
	if not CROWN_POINTS.has(rank):
		return suit_polygons(suit, mid, CENTER_SUIT_HEIGHT)
	# 冠饰与花色作为一组在牌心居中
	var bottom := mid.y + _crowned_group_height() / 2.0
	return suit_polygons(suit, Vector2(mid.x, bottom - FACE_SUIT_HEIGHT / 2.0), FACE_SUIT_HEIGHT)


static func crown_rect() -> Rect2:
	var mid := Vector2(SIZE) / 2.0
	var top := mid.y - _crowned_group_height() / 2.0
	return Rect2(Vector2(mid.x - CROWN_SIZE.x / 2.0, top), CROWN_SIZE)


static func _crowned_group_height() -> float:
	return CROWN_SIZE.y + CROWN_GAP + FACE_SUIT_HEIGHT


static func half_turn(poly: PackedVector2Array) -> PackedVector2Array:
	# 绕牌心转 180°:右下角标与左上角标中心对称
	var out := PackedVector2Array()
	for p in poly:
		out.append(Vector2(SIZE) - p)
	return out


# —— 冠饰 ——

static func crown_polygon(rect: Rect2, points: int) -> PackedVector2Array:
	# 底边平直、points 个尖角(与 CardFaces 的冠饰同一画法);尖角留出宝石的半径,宝石不出框
	var w := rect.size.x
	var base := Vector2(rect.position.x, rect.end.y)
	var peak_h := rect.size.y - JEWEL_RADIUS
	var poly := PackedVector2Array([base])
	for i in points:
		var x := w * (i + 0.5) / points
		poly.append(base + Vector2(x - w / points * 0.5, -peak_h * 0.45))
		poly.append(base + Vector2(x, -peak_h))
	poly.append(base + Vector2(w, -peak_h * 0.45))
	poly.append(base + Vector2(w, 0))
	return poly


static func crown_jewels(rect: Rect2, points: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in points:
		out.append(Vector2(rect.position.x + rect.size.x * (i + 0.5) / points, rect.position.y + JEWEL_RADIUS))
	return out


# —— 点数 ——

static func rank_polygons(rank: int, box: Rect2) -> Array[PackedVector2Array]:
	# 笔画中心线映射到点数框内缩半个笔画的范围,再加粗成圆头圆角的多边形:笔画外缘正好贴着框
	var half := rank_stroke(rank) / 2.0
	var inner := box.grow(-half)
	var polys: Array[PackedVector2Array] = []
	for line in rank_strokes(rank):
		var pts := PackedVector2Array()
		for p in line:
			pts.append(inner.position + p * inner.size)
		polys.append_array(Geometry2D.offset_polyline(pts, half, Geometry2D.JOIN_ROUND, Geometry2D.END_ROUND))
	return polys


static func rank_stroke(rank: int) -> float:
	return TEN_STROKE if rank == 10 else STROKE


static func rank_strokes(rank: int) -> Array[PackedVector2Array]:
	# 每个点数的笔画中心线,单位框 [0,1]²(y 向下)。
	# 围成圈的笔画要拆成几段分别加粗:一整条加粗时圈里会多出一个「洞」多边形,画家填色就把空心填实了
	match rank:
		2:
			return [_chain([_arc(Vector2(0.5, 0.27), Vector2(0.5, 0.27), PI + 0.5, TAU + 0.6),
				_pts([0.0, 1.0, 1.0, 1.0])])]
		3:
			return [_arc(Vector2(0.5, 0.25), Vector2(0.46, 0.25), PI + 0.5, TAU + PI / 2.0 + 0.3),
				_arc(Vector2(0.5, 0.72), Vector2(0.5, 0.28), PI * 1.5 - 0.3, TAU + PI / 2.0 + 0.9)]
		4:
			# 竖笔单独一段:斜笔、横笔与竖笔围出的三角形空心才留得住
			return [_pts([0.74, 1.0, 0.74, 0.0]), _pts([0.74, 0.0, 0.0, 0.68, 1.0, 0.68])]
		5:
			return [_chain([_pts([0.92, 0.0, 0.14, 0.0, 0.08, 0.45]),
				_arc(Vector2(0.5, 0.69), Vector2(0.5, 0.31), PI * 1.5 - 0.95, TAU + PI / 2.0 + 0.9)])]
		6:
			var six := _ring(Vector2(0.5, 0.67), Vector2(0.5, 0.33))
			six.append(_bezier(Vector2(0.0, 0.67), Vector2(0.02, 0.02), Vector2(0.82, 0.0)))
			return six
		7:
			return [_pts([0.0, 0.0, 1.0, 0.0, 0.32, 1.0])]
		8:
			var eight := _ring(Vector2(0.5, 0.24), Vector2(0.42, 0.24))
			eight.append_array(_ring(Vector2(0.5, 0.72), Vector2(0.5, 0.28)))
			return eight
		9:
			var nine := _ring(Vector2(0.5, 0.33), Vector2(0.5, 0.33))
			nine.append(_pts([1.0, 0.36, 0.4, 1.0]))
			return nine
		10:
			# 「1」只留一个短旗,「0」是窄椭圆:两字之间与「0」的空心都要在缩小后还看得出来
			var ten := _ring(Vector2(1.0 - TEN_ZERO_HALF_WIDTH, 0.5), Vector2(TEN_ZERO_HALF_WIDTH, 0.5))
			ten.append(_pts([0.0, 0.17, TEN_ONE_X, 0.0, TEN_ONE_X, 1.0]))
			return ten
		PokerCard.JACK:
			return [_chain([_pts([0.36, 0.0, 0.92, 0.0, 0.92, 0.66]),
				_arc(Vector2(0.47, 0.66), Vector2(0.45, 0.34), 0.0, PI - 0.1)])]
		PokerCard.QUEEN:
			var queen := _ring(Vector2(0.5, 0.47), Vector2(0.5, 0.47))
			queen.append(_pts([0.56, 0.7, 1.0, 1.0]))
			return queen
		PokerCard.KING:
			return [_pts([0.0, 0.0, 0.0, 1.0]), _pts([1.0, 0.0, 0.0, 0.66]), _pts([0.36, 0.42, 1.0, 1.0])]
		PokerCard.ACE:
			return [_pts([0.0, 1.0, 0.5, 0.0, 1.0, 1.0]), _pts([0.2, 0.68, 0.8, 0.68])]
	return []


# —— 花色 ——

static func suit_polygons(suit: int, center: Vector2, height: float) -> Array[PackedVector2Array]:
	# 花色由几块互相重叠的多边形拼成(同色填充,重叠处看不出接缝)
	var polys: Array[PackedVector2Array] = []
	for part in suit_parts(suit):
		var poly := PackedVector2Array()
		for p in part:
			poly.append(center + p * height)
		polys.append(poly)
	return polys


static func suit_parts(suit: int) -> Array[PackedVector2Array]:
	# 单位高度、以原点为中心(y ∈ [-0.5, 0.5])的花色部件
	match suit:
		PokerCard.SPADES:
			return _spade()
		PokerCard.HEARTS:
			return _heart()
		PokerCard.DIAMONDS:
			return _diamond()
	return _club()


static func _heart() -> Array[PackedVector2Array]:
	# 上方两个圆瓣,两条切线收到底部尖角
	var r := 0.265
	var left := Vector2(-0.255, -0.235)
	var right := Vector2(0.255, -0.235)
	var tip := Vector2(0.0, 0.5)
	var body := PackedVector2Array([_tangent(left, r, tip, 1.0), tip, _tangent(right, r, tip, -1.0), right, left])
	return [_circle(left, r), _circle(right, r), body]


static func _spade() -> Array[PackedVector2Array]:
	# 倒过来的红心(圆瓣在下、尖角朝上)加一个上窄下宽的柄
	var r := 0.235
	var left := Vector2(-0.225, 0.07)
	var right := Vector2(0.225, 0.07)
	var tip := Vector2(0.0, -0.5)
	var body := PackedVector2Array([_tangent(left, r, tip, -1.0), tip, _tangent(right, r, tip, 1.0), right, left])
	return [_circle(left, r), _circle(right, r), body, _stem(0.1, 0.2)]


static func _club() -> Array[PackedVector2Array]:
	# 品字形三个圆,中间补一块三角,下面一个柄
	var r := 0.235
	var top := Vector2(0.0, -0.265)
	var left := Vector2(-0.265, 0.075)
	var right := Vector2(0.265, 0.075)
	return [_circle(top, r), _circle(left, r), _circle(right, r), PackedVector2Array([top, right, left]),
		_stem(0.05, 0.2)]


static func _diamond() -> Array[PackedVector2Array]:
	var corners := [Vector2(0.0, -0.5), Vector2(0.39, 0.0), Vector2(0.0, 0.5), Vector2(-0.39, 0.0)]
	var poly := PackedVector2Array()
	for i in corners.size():
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % corners.size()]
		var edge := _bezier(a, (a + b) / 2.0 * (1.0 - DIAMOND_PINCH), b)
		edge.remove_at(edge.size() - 1)   # 终点是下一条边的起点
		poly.append_array(edge)
	return [poly]


static func _stem(top: float, half_base: float) -> PackedVector2Array:
	# 柄:从花色中部往下,两侧内凹地张开到底边
	var neck := 0.035
	var poly := _bezier(Vector2(neck, top), Vector2(neck, 0.42), Vector2(half_base, 0.5))
	poly.append_array(_bezier(Vector2(-half_base, 0.5), Vector2(-neck, 0.42), Vector2(-neck, top)))
	return poly


static func _tangent(center: Vector2, radius: float, from: Vector2, turn: float) -> Vector2:
	# 从圆外一点 from 引到圆上的切点;turn = ±1 选两条切线中的一条
	var d := from - center
	var angle := d.angle() + turn * acos(radius / d.length())
	return center + Vector2.from_angle(angle) * radius


# —— 曲线工具 ——

static func _pts(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, flat.size(), 2):
		out.append(Vector2(flat[i], flat[i + 1]))
	return out


static func _chain(parts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for part in parts:
		out.append_array(part)
	return out


static func _arc(center: Vector2, radius: Vector2, from: float, to: float) -> PackedVector2Array:
	# 椭圆弧;角度增大在屏幕上是顺时针(y 向下)
	var steps := maxi(2, ceili(absf(to - from) / ARC_STEP))
	var out := PackedVector2Array()
	for i in steps + 1:
		var a := lerpf(from, to, float(i) / steps)
		out.append(center + Vector2(cos(a), sin(a)) * radius)
	return out


static func _ring(center: Vector2, radius: Vector2) -> Array[PackedVector2Array]:
	# 闭合的圈拆成左右两半:单独加粗再叠起来,中间的洞才留得住
	return [_arc(center, radius, -PI / 2.0, PI / 2.0), _arc(center, radius, PI / 2.0, PI * 1.5)]


static func _bezier(a: Vector2, control: Vector2, b: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in BEZIER_SEGMENTS + 1:
		var t := float(i) / BEZIER_SEGMENTS
		out.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	return out


static func _circle(center: Vector2, radius: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in CIRCLE_SEGMENTS:
		out.append(center + Vector2.from_angle(TAU * i / CIRCLE_SEGMENTS) * radius)
	return out
