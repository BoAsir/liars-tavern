class_name CardFaces
# 牌面纹理:启动时在离屏 SubViewport 中用矢量绘制 Q/K/A/鬼牌与牌背,抓取成带 mipmap 的贴图;
# 同一帧再画一遍烫金遮罩(金色画白、其余画黑)。3D 卡牌用两份数组纹理(层序见 LAYERS):牌面 face_array()、
# 烫金 foil_array();2D 界面仍用单张贴图 texture(kind)。
# 无渲染环境(headless)下抓图为空,退化为纯色纹理与 8×8 的替代数组,保证逻辑照常运行。


const SIZE := Vector2i(360, 520)
const FOIL_SIZE := Vector2i(180, 260)
const BACK := -1
const CORNER_RADIUS := 26
const FONT_WEIGHT_BOLD := 700
const LAYERS := [BACK, Card.QUEEN, Card.KING, Card.ACE, Card.JOKER]   # 数组纹理的层序:0 = 牌背
const FALLBACK_SIZE := 8

const ACCENTS := {
	Card.QUEEN: Color(0.62, 0.11, 0.13),
	Card.KING: Color(0.12, 0.2, 0.44),
	Card.ACE: Color(0.08, 0.22, 0.14),
	Card.JOKER: Color(0.42, 0.13, 0.5),
}
const PAPER := Color(0.94, 0.9, 0.8)
const PAPER_EDGE := Color(0.8, 0.72, 0.56)
const CREAM := Color(0.9, 0.84, 0.68)        # 奶油外边(牌背在绿毡上要靠它和桌面分开)
const CUT_LINE := Color(0.3, 0.2, 0.12)      # 外沿 1 px 深色切线
const INK := Color(0.16, 0.11, 0.08)
const GOLD := Color(0.8, 0.6, 0.26)
const BACK_RED := Color(0.34, 0.05, 0.06)

static var _textures := {}
static var _face_array: Texture2DArray = null
static var _foil_array: Texture2DArray = null
static var _fallback_faces: Texture2DArray = null
static var _fallback_foil: Texture2DArray = null
static var _building := false


static func chamber_points(center: Vector2, radius: float) -> PackedVector2Array:
	# 牌背上的弹巢:孔数与规则的膛数一致,第一个孔在正上方
	var points := PackedVector2Array()
	for i in Revolver.CHAMBERS:
		var a := -PI / 2 + TAU * i / Revolver.CHAMBERS
		points.append(center + Vector2(cos(a), sin(a)) * radius)
	return points


static func texture(kind: int) -> Texture2D:
	# 德州牌(取值 8–59)另有缓存与生成时机,转给 PokerFaces;-1 牌背与 0–3 骗子酒馆的牌仍在这里
	if PokerCard.is_card(kind):
		return PokerFaces.texture(kind)
	if _textures.has(kind):
		return _textures[kind]
	return _fallback(kind)


static func layer(kind: int) -> int:
	# 牌型在数组纹理里的层;不认识的(德州牌)给牌背层
	return maxi(LAYERS.find(kind), 0)


static func face_array() -> Texture2DArray:
	if _face_array != null:
		return _face_array
	if _fallback_faces == null:
		var images: Array[Image] = []
		for kind in LAYERS:
			images.append(_fallback_image(kind))
		_fallback_faces = _array(images)
	return _fallback_faces


static func foil_array() -> Texture2DArray:
	if _foil_array != null:
		return _foil_array
	if _fallback_foil == null:
		var images: Array[Image] = []
		for kind in LAYERS:
			var image := Image.create(FALLBACK_SIZE, FALLBACK_SIZE, true, Image.FORMAT_R8)
			image.fill(Color.BLACK)
			images.append(image)
		_fallback_foil = _array(images)
	return _fallback_foil


static func clear() -> void:
	_textures = {}
	_face_array = null
	_foil_array = null
	_fallback_faces = null
	_fallback_foil = null


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
	if DisplayServer.get_name() == "headless":
		# 无头模式的哑渲染器不会发出 frame_post_draw,直接使用纯色纹理(数组用替代图)
		for kind in LAYERS:
			_textures[kind] = _fallback(kind)
		return
	_building = true
	var viewports := []
	for foil in [false, true]:
		for kind in LAYERS:
			var vp := SubViewport.new()
			vp.size = SIZE
			vp.transparent_bg = not foil
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE
			var painter := CardPainter.new()
			painter.kind = kind
			painter.foil = foil
			painter.size = Vector2(SIZE)
			vp.add_child(painter)
			host.add_child(vp)
			viewports.append(vp)
	await RenderingServer.frame_post_draw
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var faces: Array[Image] = []
	var foils: Array[Image] = []
	var complete := true
	for i in LAYERS.size():
		var image: Image = viewports[i].get_texture().get_image()
		var mask: Image = viewports[i + LAYERS.size()].get_texture().get_image()
		if image == null or image.is_empty():
			_textures[LAYERS[i]] = _fallback(LAYERS[i])
			complete = false
		else:
			image.generate_mipmaps()
			_textures[LAYERS[i]] = ImageTexture.create_from_image(image)
			faces.append(image)
		if mask == null or mask.is_empty():
			complete = false
		else:
			mask.convert(Image.FORMAT_R8)
			mask.resize(FOIL_SIZE.x, FOIL_SIZE.y, Image.INTERPOLATE_LANCZOS)
			mask.generate_mipmaps()
			foils.append(mask)
	for vp in viewports:
		vp.queue_free()
	# 数组要求各层同尺寸:任意一张抓图为空就整组用替代图
	if complete:
		_face_array = _array(faces)
		_foil_array = _array(foils)
	_building = false


static func _array(images: Array[Image]) -> Texture2DArray:
	var array := Texture2DArray.new()
	array.create_from_images(images)
	return array


static func _fallback_image(kind: int) -> Image:
	var image := Image.create(FALLBACK_SIZE, FALLBACK_SIZE, true, Image.FORMAT_RGBA8)
	image.fill(BACK_RED if kind == BACK else PAPER.lerp(ACCENTS.get(kind, INK), 0.3))
	return image


static func _fallback(kind: int) -> Texture2D:
	return ImageTexture.create_from_image(_fallback_image(kind))


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


static func draw_rounded(target: CanvasItem, rect: Rect2, fill: Color, radius: int, border := 0,
		border_color := Color.TRANSPARENT, draw_fill := true) -> void:
	# 抗锯齿的圆角矩形(可只画边框),骗子酒馆与德州牌面的纸底、纸边、金边都用它;只能在 target 的 _draw 里调用
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.draw_center = draw_fill
	box.set_corner_radius_all(radius)
	box.set_border_width_all(border)
	box.border_color = border_color
	box.anti_aliasing = true
	target.draw_style_box(box, rect)


class CardPainter:
	extends Control
	# 单张牌面的矢量绘制;foil 时画烫金遮罩:底色全黑,金色画白、其余画黑

	var kind := BACK
	var foil := false
	var _letters := CardFaces.letter_font()
	var _glyphs := CardFaces.glyph_font()

	func _draw() -> void:
		if foil:
			draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
		if kind == BACK:
			_draw_back()
		else:
			_draw_face()

	func _ink(color: Color) -> Color:
		# 遮罩模式:金色(任何透明度)→ 白,其余 → 黑,透明度不变
		if not foil:
			return color
		var gold := absf(color.r - CardFaces.GOLD.r) + absf(color.g - CardFaces.GOLD.g) + absf(color.b - CardFaces.GOLD.b) < 0.01
		return Color(1, 1, 1, color.a) if gold else Color(0, 0, 0, color.a)

	func _rounded(rect: Rect2, fill: Color, radius: int, border := 0, border_color := Color.TRANSPARENT,
			draw_fill := true) -> void:
		CardFaces.draw_rounded(self, rect, _ink(fill), radius, border, _ink(border_color), draw_fill)

	func _card_rect(inset: float) -> Rect2:
		return Rect2(Vector2(inset, inset), size - Vector2(inset, inset) * 2.0)

	func _edge(band: float) -> void:
		# 外沿 1 px 深色切线 + 奶油外边(宽 band)
		_rounded(_card_rect(0), CardFaces.CUT_LINE, CardFaces.CORNER_RADIUS)
		_rounded(_card_rect(1.5), CardFaces.CREAM, CardFaces.CORNER_RADIUS - 1)
		_rounded(_card_rect(band - 1), Color.TRANSPARENT, CardFaces.CORNER_RADIUS - int(band), 1,
			Color(CardFaces.PAPER_EDGE, 0.9), false)

	# —— 牌面 ——

	func _draw_face() -> void:
		var accent: Color = CardFaces.ACCENTS[kind]
		_edge(10.0)
		_rounded(_card_rect(10), CardFaces.PAPER, CardFaces.CORNER_RADIUS - 10)
		_paper_texture()
		# 金色内框:双线
		_rounded(_card_rect(17), Color.TRANSPARENT, 14, 3, CardFaces.GOLD, false)
		_rounded(_card_rect(23), Color.TRANSPARENT, 10, 1, CardFaces.GOLD, false)
		_rounded(_card_rect(27), Color.TRANSPARENT, 8, 1, Color(accent, 0.45), false)
		var center := size / 2.0
		draw_circle(center, 112.0, _ink(Color(accent, 0.08)))
		draw_arc(center, 112.0, 0.0, TAU, 96, _ink(CardFaces.GOLD), 4.0, true)
		draw_arc(center, 100.0, 0.0, TAU, 96, _ink(Color(accent, 0.6)), 1.5, true)
		for i in 24:
			var a := TAU * i / 24.0
			draw_line(center + Vector2(cos(a), sin(a)) * 104.0, center + Vector2(cos(a), sin(a)) * 110.0,
				_ink(CardFaces.GOLD), 2.0, true)
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
			var p := Vector2(rng.randf_range(14, size.x - 14), rng.randf_range(14, size.y - 14))
			draw_circle(p, rng.randf_range(0.6, 2.2), _ink(Color(CardFaces.INK, rng.randf_range(0.02, 0.06))))
		for i in 6:
			_rounded(_card_rect(10 + i * 3), Color.TRANSPARENT, CardFaces.CORNER_RADIUS - 10, 3,
				Color(0.55, 0.42, 0.25, 0.05), false)

	func _corner_index(label: String, accent: Color, font: Font, flipped: bool) -> void:
		if flipped:
			draw_set_transform(size, PI, Vector2.ONE)
		_centered_text(font, label, Vector2(56, 76), 52, accent)
		_pip(Vector2(56, 113), accent)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	func _pip(at: Vector2, accent: Color) -> void:
		var pts := PackedVector2Array([at + Vector2(0, -11), at + Vector2(8, 0), at + Vector2(0, 11), at + Vector2(-8, 0)])
		draw_colored_polygon(pts, _ink(accent))

	func _centered_text(font: Font, text: String, center: Vector2, font_size: int, color: Color) -> void:
		var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
		var ascent := font.get_ascent(font_size)
		var descent := font.get_descent(font_size)
		var baseline := Vector2(center.x - text_size.x / 2.0, center.y + (ascent - descent) / 2.0)
		draw_string(font, baseline + Vector2(2, 3), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _ink(Color(0, 0, 0, 0.18)))
		draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _ink(color))

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
		draw_colored_polygon(poly, _ink(CardFaces.GOLD))
		draw_polyline(poly + PackedVector2Array([poly[0]]), _ink(accent), 2.5, true)
		draw_rect(Rect2(base + Vector2(-w / 2, -2), Vector2(w, 10)), _ink(accent))
		for i in points:
			var x := -w / 2 + w * (i + 0.5) / points
			draw_circle(base + Vector2(x, -h - 5), 6.0, _ink(accent))
		for i in 3:
			draw_circle(base + Vector2(-24 + i * 24, 3), 3.5, _ink(CardFaces.GOLD))

	func _star(center: Vector2, radius: float, accent: Color) -> void:
		var pts := PackedVector2Array()
		for i in 10:
			var a := -PI / 2 + TAU * i / 10.0
			var r := radius if i % 2 == 0 else radius * 0.45
			pts.append(center + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, _ink(CardFaces.GOLD))
		draw_polyline(pts + PackedVector2Array([pts[0]]), _ink(accent), 2.5, true)

	func _jester_hat(base: Vector2, accent: Color) -> void:
		var tips := [Vector2(-52, -40), Vector2(0, -56), Vector2(52, -40)]
		var colors := [accent, CardFaces.GOLD, accent]
		for i in 3:
			var poly := PackedVector2Array([base + Vector2(-30 + i * 20, 0), base + tips[i], base + Vector2(-10 + i * 20, 0)])
			draw_colored_polygon(poly, _ink(colors[i]))
			draw_circle(base + tips[i], 7.0, _ink(CardFaces.GOLD if i != 1 else accent))
		draw_rect(Rect2(base + Vector2(-34, -2), Vector2(68, 10)), _ink(CardFaces.INK))

	# —— 牌背 ——

	func _draw_back() -> void:
		_edge(12.0)
		_rounded(_card_rect(12), CardFaces.BACK_RED, CardFaces.CORNER_RADIUS - 12)
		var inner := _card_rect(26)
		var spacing := 22.0
		var line_color := Color(CardFaces.GOLD, 0.22)
		var span := inner.size.x + inner.size.y
		var t := -span
		while t < span:
			_clipped_line(inner, Vector2(inner.position.x + t, inner.position.y), Vector2(1, 1), line_color)
			_clipped_line(inner, Vector2(inner.end.x - t, inner.position.y), Vector2(-1, 1), line_color)
			t += spacing
		# 双边框 + 四角卷草
		_rounded(_card_rect(17), Color.TRANSPARENT, 16, 3, CardFaces.GOLD, false)
		_rounded(_card_rect(24), Color.TRANSPARENT, 10, 1, CardFaces.GOLD, false)
		for corner in 4:
			_scroll(corner)
		# 中心转轮徽章:孔数 = 膛数,第一个孔在 12 点
		var center := size / 2.0
		draw_circle(center, 86.0, _ink(Color(0.12, 0.02, 0.03)))
		draw_arc(center, 86.0, 0.0, TAU, 96, _ink(CardFaces.GOLD), 4.0, true)
		draw_arc(center, 74.0, 0.0, TAU, 96, _ink(Color(CardFaces.GOLD, 0.5)), 1.5, true)
		for p in CardFaces.chamber_points(center, 44.0):
			draw_circle(p, 15.0, _ink(CardFaces.GOLD))
			draw_circle(p, 10.0, _ink(Color(0.08, 0.01, 0.02)))
		draw_circle(center, 9.0, _ink(CardFaces.GOLD))

	func _scroll(corner: int) -> void:
		# 角上的卷草:一道弧、两个相对的小卷和一粒圆珠,按角镜像
		var flip := Vector2(1 if corner % 2 == 0 else -1, 1 if corner < 2 else -1)
		var origin := Vector2(0 if corner % 2 == 0 else size.x, 0 if corner < 2 else size.y)
		var gold := _ink(CardFaces.GOLD)
		var arc := PackedVector2Array()
		for k in 13:
			var a := PI * 0.5 * k / 12.0
			arc.append(origin + (Vector2(48, 48) - Vector2(cos(a), sin(a)) * 16.0) * flip)
		draw_polyline(arc, gold, 2.0, true)
		for swap in [false, true]:
			var curl := PackedVector2Array()
			for k in 17:
				var a := TAU * 0.8 * k / 16.0
				var r := 7.0 - k * 0.3
				var d := Vector2(cos(a), sin(a)) * r
				var p := Vector2(52, 34) + d if not swap else Vector2(34, 52) + Vector2(d.y, d.x)
				curl.append(origin + p * flip)
			draw_polyline(curl, gold, 1.6, true)
		draw_circle(origin + Vector2(36, 36) * flip, 4.0, gold)

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
			draw_line(a, b, _ink(color), 2.0, true)
