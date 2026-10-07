class_name CardFaces
# 牌面纹理:启动时在离屏 SubViewport 中用矢量绘制 Q/K/A/鬼牌与牌背,抓取成带 mipmap 的贴图。
# 无渲染环境(headless)下抓图为空,退化为纯色纹理,保证逻辑照常运行。


const SIZE := Vector2i(360, 520)
const BACK := -1
const CORNER_RADIUS := 26
const FONT_WEIGHT_BOLD := 700

const ACCENTS := {
	Card.QUEEN: Color(0.62, 0.11, 0.13),
	Card.KING: Color(0.12, 0.2, 0.44),
	Card.ACE: Color(0.08, 0.22, 0.14),
	Card.JOKER: Color(0.42, 0.13, 0.5),
}
const PAPER := Color(0.94, 0.9, 0.8)
const PAPER_EDGE := Color(0.8, 0.72, 0.56)
const INK := Color(0.16, 0.11, 0.08)
const GOLD := Color(0.8, 0.6, 0.26)
const BACK_RED := Color(0.34, 0.05, 0.06)

static var _textures := {}
static var _building := false


static func texture(kind: int) -> Texture2D:
	# 德州牌(取值 8–59)另有缓存与生成时机,转给 PokerFaces;-1 牌背与 0–3 骗子酒馆的牌仍在这里
	if PokerCard.is_card(kind):
		return PokerFaces.texture(kind)
	if _textures.has(kind):
		return _textures[kind]
	return _fallback(kind)


static func clear() -> void:
	_textures = {}


static func is_built() -> bool:
	return _textures.size() == ACCENTS.size() + 1


static func build(host: Node) -> void:
	# 只需调用一次;并发调用时等待第一次完成
	if is_built():
		return
	if _building:
		while not is_built():
			await host.get_tree().process_frame
		return
	var kinds := [BACK, Card.QUEEN, Card.KING, Card.ACE, Card.JOKER]
	if DisplayServer.get_name() == "headless":
		# 无头模式的哑渲染器不会发出 frame_post_draw,直接使用纯色纹理
		for kind in kinds:
			_textures[kind] = _fallback(kind)
		return
	_building = true
	var viewports := []
	for kind in kinds:
		var vp := SubViewport.new()
		vp.size = SIZE
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var painter := CardPainter.new()
		painter.kind = kind
		painter.size = Vector2(SIZE)
		vp.add_child(painter)
		host.add_child(vp)
		viewports.append(vp)
	await RenderingServer.frame_post_draw
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	for i in kinds.size():
		var image: Image = viewports[i].get_texture().get_image()
		if image == null or image.is_empty():
			_textures[kinds[i]] = _fallback(kinds[i])
		else:
			image.generate_mipmaps()
			_textures[kinds[i]] = ImageTexture.create_from_image(image)
		viewports[i].queue_free()
	_building = false


static func _fallback(kind: int) -> Texture2D:
	var image := Image.create(8, 8, true, Image.FORMAT_RGBA8)
	image.fill(BACK_RED if kind == BACK else PAPER.lerp(ACCENTS.get(kind, INK), 0.3))
	return ImageTexture.create_from_image(image)


static func letter_font() -> SystemFont:
	# Q/K/A 字母:与界面的西文衬线体同一组回退字体
	return _bold_font(UiTheme.FONT_LATIN_NAMES)


static func glyph_font() -> SystemFont:
	# 鬼牌汉字:与界面的展示用楷体同一组回退字体
	return _bold_font(UiTheme.FONT_DISPLAY_NAMES)


static func _bold_font(names: Array) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(names)
	font.font_weight = FONT_WEIGHT_BOLD
	return font


class CardPainter:
	extends Control
	# 单张牌面的矢量绘制

	var kind := BACK
	var _letters := CardFaces.letter_font()
	var _glyphs := CardFaces.glyph_font()

	func _draw() -> void:
		if kind == BACK:
			_draw_back()
		else:
			_draw_face()

	func _card_rect(inset: float) -> Rect2:
		return Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)

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

	# —— 牌面 ——

	func _draw_face() -> void:
		var accent: Color = CardFaces.ACCENTS[kind]
		_rounded(_card_rect(0), CardFaces.PAPER_EDGE, CardFaces.CORNER_RADIUS)
		_rounded(_card_rect(4), CardFaces.PAPER, CardFaces.CORNER_RADIUS - 4)
		_paper_texture()
		_rounded(_card_rect(18), Color.TRANSPARENT, 14, 3, CardFaces.GOLD, false)
		_rounded(_card_rect(25), Color.TRANSPARENT, 10, 1, Color(accent, 0.5), false)
		var center := size / 2.0
		draw_circle(center, 112.0, Color(accent, 0.08))
		draw_arc(center, 112.0, 0.0, TAU, 96, CardFaces.GOLD, 4.0, true)
		draw_arc(center, 100.0, 0.0, TAU, 96, Color(accent, 0.6), 1.5, true)
		for i in 24:
			var a := TAU * i / 24.0
			draw_line(center + Vector2(cos(a), sin(a)) * 104.0, center + Vector2(cos(a), sin(a)) * 110.0,
				CardFaces.GOLD, 2.0, true)
		match kind:
			Card.QUEEN:
				_crown(center + Vector2(0, -78), accent, 5)
			Card.KING:
				_crown(center + Vector2(0, -78), accent, 3)
			Card.ACE:
				_star(center + Vector2(0, -84), 26.0, accent)
			Card.JOKER:
				_jester_hat(center + Vector2(0, -80), accent)
		var label: String = Card.NAMES[kind]
		var big_font: Font = _glyphs if kind == Card.JOKER else _letters
		_centered_text(big_font, label, center + Vector2(0, 30), 150, accent)
		_corner_index(label, accent, big_font, false)
		_corner_index(label, accent, big_font, true)

	func _paper_texture() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 1234 + kind
		for i in 260:
			var p := Vector2(rng.randf_range(10, size.x - 10), rng.randf_range(10, size.y - 10))
			draw_circle(p, rng.randf_range(0.6, 2.2), Color(CardFaces.INK, rng.randf_range(0.02, 0.06)))
		for i in 6:
			_rounded(_card_rect(4 + i * 3), Color.TRANSPARENT, CardFaces.CORNER_RADIUS - 4, 3,
				Color(0.55, 0.42, 0.25, 0.05), false)

	func _corner_index(label: String, accent: Color, font: Font, flipped: bool) -> void:
		if flipped:
			draw_set_transform(size, PI, Vector2.ONE)
		_centered_text(font, label, Vector2(54, 74), 54, accent)
		_pip(Vector2(54, 112), accent)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _pip(at: Vector2, accent: Color) -> void:
		var pts := PackedVector2Array([at + Vector2(0, -11), at + Vector2(8, 0), at + Vector2(0, 11), at + Vector2(-8, 0)])
		draw_colored_polygon(pts, accent)

	func _centered_text(font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var ascent := font.get_ascent(font_size)
		var descent := font.get_descent(font_size)
		var baseline := Vector2(center.x - text_size.x / 2.0, center.y + (ascent - descent) / 2.0)
		draw_string(font, baseline + Vector2(2, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0, 0, 0, 0.18))
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	func _crown(base: Vector2, accent: Color, points: int) -> void:
		var w := 92.0
		var h := 46.0
		var poly := PackedVector2Array([base + Vector2(-w / 2, 0)])
		for i in points:
			var x := -w / 2 + w * (i + 0.5) / points
			poly.append(base + Vector2(x - w / points * 0.5, -h * 0.45))
			poly.append(base + Vector2(x, -h))
		poly.append(base + Vector2(w / 2, -h * 0.45))
		poly.append(base + Vector2(w / 2, 0))
		draw_colored_polygon(poly, CardFaces.GOLD)
		draw_polyline(poly + PackedVector2Array([poly[0]]), accent, 2.5, true)
		draw_rect(Rect2(base + Vector2(-w / 2, -2), Vector2(w, 10)), accent)
		for i in points:
			var x := -w / 2 + w * (i + 0.5) / points
			draw_circle(base + Vector2(x, -h - 5), 6.0, accent)
		for i in 3:
			draw_circle(base + Vector2(-24 + i * 24, 3), 3.5, CardFaces.GOLD)

	func _star(center: Vector2, radius: float, accent: Color) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI / 2 + TAU * i / 10.0
			var r := radius if i % 2 == 0 else radius * 0.45
			pts.append(center + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, CardFaces.GOLD)
		draw_polyline(pts + PackedVector2Array([pts[0]]), accent, 2.5, true)

	func _jester_hat(base: Vector2, accent: Color) -> void:
		var tips := [Vector2(-52, -40), Vector2(0, -56), Vector2(52, -40)]
		var colors := [accent, CardFaces.GOLD, accent]
		for i in 3:
			var poly := PackedVector2Array([base + Vector2(-30 + i * 20, 0), base + tips[i], base + Vector2(-10 + i * 20, 0)])
			draw_colored_polygon(poly, colors[i])
			draw_circle(base + tips[i], 7.0, CardFaces.GOLD if i != 1 else accent)
		draw_rect(Rect2(base + Vector2(-34, -2), Vector2(68, 10)), CardFaces.INK)

	# —— 牌背 ——

	func _draw_back() -> void:
		_rounded(_card_rect(0), Color(0.2, 0.03, 0.04), CardFaces.CORNER_RADIUS)
		_rounded(_card_rect(4), CardFaces.BACK_RED, CardFaces.CORNER_RADIUS - 4)
		var inner := _card_rect(22)
		var spacing := 22.0
		var line_color := Color(CardFaces.GOLD, 0.22)
		var span := inner.size.x + inner.size.y
		var t := -span
		while t < span:
			_clipped_line(inner, Vector2(inner.position.x + t, inner.position.y), Vector2(1, 1), line_color)
			_clipped_line(inner, Vector2(inner.end.x - t, inner.position.y), Vector2(-1, 1), line_color)
			t += spacing
		_rounded(_card_rect(14), Color.TRANSPARENT, 16, 4, CardFaces.GOLD, false)
		_rounded(_card_rect(22), Color.TRANSPARENT, 10, 1, Color(CardFaces.GOLD, 0.6), false)
		var center := size / 2.0
		draw_circle(center, 86.0, Color(0.12, 0.02, 0.03))
		draw_arc(center, 86.0, 0.0, TAU, 96, CardFaces.GOLD, 4.0, true)
		draw_arc(center, 74.0, 0.0, TAU, 96, Color(CardFaces.GOLD, 0.5), 1.5, true)
		for i in 6:
			var a := -PI / 2 + TAU * i / 6.0
			var p := center + Vector2(cos(a), sin(a)) * 44.0
			draw_circle(p, 15.0, CardFaces.GOLD)
			draw_circle(p, 10.0, Color(0.08, 0.01, 0.02))
		draw_circle(center, 9.0, CardFaces.GOLD)
		for corner in [Vector2(40, 40), Vector2(size.x - 40, 40), Vector2(40, size.y - 40), Vector2(size.x - 40, size.y - 40)]:
			draw_circle(corner, 6.0, CardFaces.GOLD)

	func _clipped_line(rect: Rect2, origin: Vector2, dir: Vector2, color: Color) -> void:
		# 斜线裁剪到矩形内:沿方向步进求出入矩形的两端点
		var a := Vector2.INF
		var b := Vector2.INF
		var steps := int((rect.size.x + rect.size.y) * 1.5)
		for i in steps:
			var p := origin + dir * float(i)
			if rect.has_point(p):
				if a == Vector2.INF:
					a = p
				b = p
		if a != Vector2.INF:
			draw_line(a, b, color, 2.0, true)
