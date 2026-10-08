class_name PokerFacePainter
extends Control
# 单张德州牌面的绘制(放进离屏 SubViewport 抓图):纸底、做旧的纸边与金边沿用 CardFaces 的风格,
# 角标、中央花色与冠饰全部来自 PokerFaceArt 的多边形。多边形本身不抗锯齿,靠视口的 2D MSAA。


const CORNER_RADIUS := 27          # 与 CardFaces 的圆角同比例(38/360 ≈ 27/256)
const PAPER_INSET := 3.0
const FRAME_INSET := 5.0           # 金边贴着纸边走,给超大角标让出地方(角标离金边还有 5 像素)
const FRAME_WIDTH := 2
const FRAME_RADIUS := CORNER_RADIUS - int(FRAME_INSET)   # 与牌的圆角同心
const SPECKLES := 140              # 纸面杂点(按面积从 CardFaces 的 260 折算)
const SPECKLE_SEED := 4321         # 杂点随机种子的基数(加牌值;与 CardFaces 的 1234 错开,同一张牌每次生成都一样)
const SPECKLE_MARGIN := 8.0        # 杂点离牌边至少这么远,不落到纸边与金边上
const SPECKLE_HALF_MIN := 0.5      # 杂点方块的半边长范围(像素):一两个像素大
const SPECKLE_HALF_MAX := 1.6
const SPECKLE_ALPHA_MIN := 0.02    # 杂点墨色的透明度范围:几乎看不见,只让纸面不那么平
const SPECKLE_ALPHA_MAX := 0.06
const EDGE_SHADES := 5             # 纸边做旧的层数
const EDGE_SHADE_STEP := 2.0       # 每层往里缩这么多像素
const EDGE_SHADE_WIDTH := 2
const EDGE_SHADE_COLOR := Color(0.55, 0.42, 0.25, 0.05)
const CROWN_OUTLINE := 2.5
const CROWN_BAND := 0.22           # 冠饰底部色带占冠高的比例

var card := PokerCard.MIN_VALUE


func _init(p_card: int) -> void:
	card = p_card
	size = Vector2(PokerFaceArt.SIZE)


func _draw() -> void:
	var art := PokerFaceArt.layout(card)
	var ink: Color = art["ink"]
	_draw_paper()
	for poly in art["index"]:
		draw_colored_polygon(poly, ink)
	for poly in art["center"]:
		draw_colored_polygon(poly, ink)
	var crown: PackedVector2Array = art["crown"]
	if not crown.is_empty():
		_draw_crown(crown, art["jewels"], ink)


func _draw_paper() -> void:
	CardFaces.draw_rounded(self, Rect2(Vector2.ZERO, size), CardFaces.PAPER_EDGE, CORNER_RADIUS)
	CardFaces.draw_rounded(self, _inset(PAPER_INSET), CardFaces.PAPER, CORNER_RADIUS - int(PAPER_INSET))
	# 杂点画成小方块:一两个像素、几乎透明,看不出与圆点的区别;draw_circle 每个都要建一个多边形,
	# 13 张一批时光杂点就占掉十几毫秒,生成那几帧会卡
	var rng := RandomNumberGenerator.new()
	rng.seed = SPECKLE_SEED + card
	for i in SPECKLES:
		var p := Vector2(rng.randf_range(SPECKLE_MARGIN, size.x - SPECKLE_MARGIN),
			rng.randf_range(SPECKLE_MARGIN, size.y - SPECKLE_MARGIN))
		var half := Vector2.ONE * rng.randf_range(SPECKLE_HALF_MIN, SPECKLE_HALF_MAX)
		draw_rect(Rect2(p - half, half * 2.0),
			Color(CardFaces.INK, rng.randf_range(SPECKLE_ALPHA_MIN, SPECKLE_ALPHA_MAX)))
	for i in EDGE_SHADES:
		CardFaces.draw_rounded(self, _inset(PAPER_INSET + i * EDGE_SHADE_STEP), Color.TRANSPARENT,
			CORNER_RADIUS - int(PAPER_INSET), EDGE_SHADE_WIDTH, EDGE_SHADE_COLOR, false)
	CardFaces.draw_rounded(self, _inset(FRAME_INSET), Color.TRANSPARENT, FRAME_RADIUS, FRAME_WIDTH, CardFaces.GOLD, false)


func _draw_crown(crown: PackedVector2Array, jewels: PackedVector2Array, ink: Color) -> void:
	draw_colored_polygon(crown, CardFaces.GOLD)
	var bounds := _bounds(crown)
	var band_h := bounds.size.y * CROWN_BAND
	draw_rect(Rect2(bounds.position.x, bounds.end.y - band_h, bounds.size.x, band_h), ink)
	var outline := crown.duplicate()
	outline.append(crown[0])
	draw_polyline(outline, ink, CROWN_OUTLINE, true)
	for jewel in jewels:
		draw_circle(jewel, PokerFaceArt.JEWEL_RADIUS, ink)


func _inset(amount: float) -> Rect2:
	return Rect2(Vector2(amount, amount), size - Vector2(amount, amount) * 2.0)


static func _bounds(poly: PackedVector2Array) -> Rect2:
	var rect := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		rect = rect.expand(p)
	return rect
