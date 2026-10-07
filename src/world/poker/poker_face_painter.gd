class_name PokerFacePainter
extends Control
# 单张德州牌面的绘制(放进离屏 SubViewport 抓图):纸底、做旧的纸边与金边沿用 CardFaces 的风格,
# 角标、中央花色与冠饰全部来自 PokerFaceArt 的多边形。多边形本身不抗锯齿,靠视口的 2D MSAA。


const CORNER_RADIUS := 18          # 与 CardFaces 的圆角同比例
const PAPER_INSET := 3.0
const FRAME_INSET := 5.0           # 金边贴着纸边走,给超大角标让出地方(角标离金边还有 5 像素)
const FRAME_WIDTH := 2
const FRAME_RADIUS := CORNER_RADIUS - int(FRAME_INSET)   # 与牌的圆角同心
const SPECKLES := 140              # 纸面杂点(按面积从 CardFaces 的 260 折算)
const EDGE_SHADES := 5             # 纸边做旧的层数
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
	_rounded(Rect2(Vector2.ZERO, size), CardFaces.PAPER_EDGE, CORNER_RADIUS)
	_rounded(_inset(PAPER_INSET), CardFaces.PAPER, CORNER_RADIUS - int(PAPER_INSET))
	var rng := RandomNumberGenerator.new()
	rng.seed = 4321 + card
	for i in SPECKLES:
		var p := Vector2(rng.randf_range(8, size.x - 8), rng.randf_range(8, size.y - 8))
		draw_circle(p, rng.randf_range(0.5, 1.6), Color(CardFaces.INK, rng.randf_range(0.02, 0.06)))
	for i in EDGE_SHADES:
		_rounded(_inset(PAPER_INSET + i * 2), Color.TRANSPARENT, CORNER_RADIUS - int(PAPER_INSET), 2,
			Color(0.55, 0.42, 0.25, 0.05), false)
	_rounded(_inset(FRAME_INSET), Color.TRANSPARENT, FRAME_RADIUS, FRAME_WIDTH, CardFaces.GOLD, false)


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


func _rounded(rect: Rect2, fill: Color, radius: int, border := 0, border_color := Color.TRANSPARENT,
		draw_fill := true) -> void:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.draw_center = draw_fill
	box.set_corner_radius_all(radius)
	box.set_border_width_all(border)
	box.border_color = border_color
	box.anti_aliasing = true
	draw_style_box(box, rect)


static func _bounds(poly: PackedVector2Array) -> Rect2:
	var rect := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		rect = rect.expand(p)
	return rect
