class_name PokerFacePainter
extends Control
# 单张德州牌面的绘制(放进离屏 SubViewport 抓图):纸与骗子酒馆的新牌同一家族(CardFaces.draw_paper:暖奶油纸、
# 暖棕切线、极淡纸纤维、一圈软压暗),内框是花色浅色的圆角软框,中央花色垫一块花色粉彩圆盘;
# 角标、中央花色与冠饰全部来自 PokerFaceArt 的多边形。多边形本身不抗锯齿,靠视口的 2D MSAA。


const CORNER_RADIUS := 31          # 与 CardFaces 的圆角同比例(44/360 ≈ 31/256)
const FRAME_INSET := 5.0           # 内框贴着纸边走,给超大角标让出地方(角标离内框还有 5 像素)
const FRAME_WIDTH := 3
const FRAME_RADIUS := CORNER_RADIUS - int(FRAME_INSET)   # 与牌的圆角同心
const FRAME_ALPHA := 0.55          # 内框:花色浅色,半透明叠在纸上
const SPECKLES := 160              # 纸面杂点(按面积从 CardFaces 的 320 折算)
const SPECKLE_SEED := 4321         # 杂点随机种子的基数(加牌值;与 CardFaces 的 1234 错开,同一张牌每次生成都一样)
const DISC_RADIUS := 46.0          # 中央花色下的粉彩圆盘(与骗子酒馆的插画圆盘同一手法)
const DISC_TINT := 0.86            # 圆盘颜色:花色往白纸里混的比例
const CROWN_OUTLINE := 2.5
const CROWN_BAND := 0.22           # 冠饰底部色带占冠高的比例
const CROWN_ROUND := 2.5           # 冠饰齿尖磨圆的半径
const SUIT_SHINE := Color(1, 1, 1, 0.28)   # 中央花色左上的一点软高光

var card := PokerCard.MIN_VALUE


func _init(p_card: int) -> void:
	card = p_card
	size = Vector2(PokerFaceArt.SIZE)


func _draw() -> void:
	var art := PokerFaceArt.layout(card)
	var ink: Color = art["ink"]
	_draw_paper(ink)
	_draw_disc(ink, Vector2(PokerFaceArt.SIZE) / 2.0)   # 冠饰的牌整组也在牌心,冠饰从圆盘上沿冒出来
	for poly in art["index"]:
		draw_colored_polygon(poly, ink)
	for poly in art["center"]:
		draw_colored_polygon(poly, ink)
	var center_bounds := _bounds_of(art["center"])
	draw_colored_polygon(CardFaces.ellipse(center_bounds.position + center_bounds.size * Vector2(0.3, 0.28),
		center_bounds.size.x * 0.11, center_bounds.size.y * 0.07, -0.6), SUIT_SHINE)
	var crown: PackedVector2Array = art["crown"]
	if not crown.is_empty():
		_draw_crown(crown, art["jewels"], ink)


func _draw_paper(ink: Color) -> void:
	CardFaces.draw_paper(self, Rect2(Vector2.ZERO, size), CORNER_RADIUS, SPECKLE_SEED + card, SPECKLES)
	CardFaces.draw_rounded(self, _inset(FRAME_INSET), Color.TRANSPARENT, FRAME_RADIUS, FRAME_WIDTH,
		Color(_pastel(ink, 0.55), FRAME_ALPHA), false)


func _draw_disc(ink: Color, center: Vector2) -> void:
	var tint := _pastel(ink, DISC_TINT)
	draw_colored_polygon(CardFaces.ellipse(center, DISC_RADIUS, DISC_RADIUS, 0.0, 64), tint)
	draw_arc(center, DISC_RADIUS, 0.0, TAU, 64, _pastel(ink, 0.6), 2.5, true)


static func _pastel(ink: Color, amount: float) -> Color:
	# 花色往暖奶油纸里混:amount 越大越浅
	return ink.lerp(CardFaces.PAPER, amount)


func _draw_crown(crown: PackedVector2Array, jewels: PackedVector2Array, ink: Color) -> void:
	var soft := CardFaces.rounded_polygon(crown, CROWN_ROUND)
	draw_colored_polygon(soft, CardFaces.GOLD)
	var bounds := _bounds(crown)
	var band_h := bounds.size.y * CROWN_BAND
	draw_rect(Rect2(bounds.position.x + 2, bounds.end.y - band_h, bounds.size.x - 4, band_h), ink)
	var outline := soft.duplicate()
	outline.append(soft[0])
	draw_polyline(outline, ink, CROWN_OUTLINE, true)
	for jewel in jewels:
		draw_circle(jewel, PokerFaceArt.JEWEL_RADIUS, ink)


func _inset(amount: float) -> Rect2:
	return Rect2(Vector2(amount, amount), size - Vector2(amount, amount) * 2.0)


static func _bounds_of(polys: Array) -> Rect2:
	var rect := Rect2(polys[0][0], Vector2.ZERO)
	for poly in polys:
		rect = rect.merge(_bounds(poly))
	return rect


static func _bounds(poly: PackedVector2Array) -> Rect2:
	var rect := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		rect = rect.expand(p)
	return rect
