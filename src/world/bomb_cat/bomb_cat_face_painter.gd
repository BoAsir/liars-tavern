class_name BombCatFacePainter
extends Control
# 单张炸弹猫牌面的矢量绘制(放进离屏 SubViewport 抓图,见 BombCatFaces)。全部原创:
# 奶油纸底 + 圆角奶油外边(沿用 CardFaces 的纸色与切线)、顶部主色横幅写牌名(左端一枚小圆章写首字,牌扇里只露左边也认得出)、
# 中间一圈金边圆盘里一个大图标、底部一行小字说明(BombCatCard.description)。
# 牌背:深红底、金色斜格与双线框,中央金色圆章里是一只圆滚滚的「炸弹猫」和冒火花的导火索。
# foil 为真时画烫金遮罩:底色全黑,金色(任何透明度)画白、其余画黑,驱动 card.gdshader 的金属高光。


const GOLD := CardFaces.GOLD
const INK := CardFaces.INK
const PAPER := CardFaces.PAPER
const CREAM := CardFaces.CREAM
const CORNER := 30
const BANNER := Rect2(18, 18, 284, 70)
const CHIP_CENTER := Vector2(47, 53)
const CHIP_RADIUS := 23.0
const ICON_CENTER := Vector2(160, 228)
const ICON_RADIUS := 100.0
const TEXT_BOX := Rect2(24, 348, 272, 92)
const NAME_SIZE := 40
const TEXT_SIZE := 21
const TEXT_LINE := 27.0
const BOMB_BODY := Color(0.22, 0.21, 0.29)
const METAL := Color(0.62, 0.64, 0.7)
const PINK := Color(0.97, 0.63, 0.7)
const SPARK := Color(1.0, 0.6, 0.15)
const BACK_RED := Color(0.56, 0.11, 0.13)
const BACK_BADGE := Color(0.36, 0.06, 0.08)

var card_id := ""
var foil := false
var _display: SystemFont
var _body: SystemFont


func _init(p_id := "", p_foil := false) -> void:
	card_id = p_id
	foil = p_foil
	size = Vector2(BombCatFaces.SIZE)
	_display = CardFaces.glyph_font()
	_body = SystemFont.new()
	_body.font_names = PackedStringArray(UiTheme.FONT_BODY_NAMES)
	_body.font_weight = 600


func _draw() -> void:
	if foil:
		draw_rect(Rect2(Vector2.ZERO, size), Color.BLACK)
	if card_id == BombCatFaces.BACK:
		_draw_back()
	else:
		_draw_face()


# —— 颜色 ——

func _c(color: Color) -> Color:
	# 遮罩模式:金色 → 白,其余 → 黑,透明度不变
	if not foil:
		return color
	var gold := absf(color.r - GOLD.r) + absf(color.g - GOLD.g) + absf(color.b - GOLD.b) < 0.01
	return Color(1, 1, 1, color.a) if gold else Color(0, 0, 0, color.a)


func _rounded(rect: Rect2, fill: Color, radius: int, border := 0, border_color := Color.TRANSPARENT, draw_fill := true) -> void:
	CardFaces.draw_rounded(self, rect, _c(fill), radius, border, _c(border_color), draw_fill)


func _inset(amount: float) -> Rect2:
	return Rect2(Vector2(amount, amount), size - Vector2(amount, amount) * 2.0)


func _poly(points: PackedVector2Array, color: Color, outline := 0.0, outline_color := INK) -> void:
	draw_colored_polygon(points, _c(color))
	if outline > 0.0:
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, _c(outline_color), outline, true)


func _circle(center: Vector2, radius: float, color: Color, outline := 0.0, outline_color := INK) -> void:
	draw_circle(center, radius, _c(color))
	if outline > 0.0:
		draw_arc(center, radius, 0.0, TAU, 48, _c(outline_color), outline, true)


func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	draw_line(a, b, _c(color), width, true)
	# 圆头:两端各补一个圆
	draw_circle(a, width * 0.5, _c(color))
	draw_circle(b, width * 0.5, _c(color))


static func ellipse(center: Vector2, rx: float, ry: float, rot := 0.0, segments := 40) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var basis := Transform2D(rot, Vector2.ZERO)
	for i in segments:
		var a := TAU * i / segments
		pts.append(center + basis * Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func star(center: Vector2, outer: float, inner: float, points := 5, rot := -PI / 2) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a := rot + PI * i / points
		pts.append(center + Vector2(cos(a), sin(a)) * (outer if i % 2 == 0 else inner))
	return pts


static func bezier(a: Vector2, b: Vector2, c: Vector2, d: Vector2, steps := 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in steps + 1:
		var t := float(i) / steps
		var u := 1.0 - t
		pts.append(a * u * u * u + b * 3.0 * u * u * t + c * 3.0 * u * t * t + d * t * t * t)
	return pts


# —— 文字 ——

func _text(font: Font, text: String, center: Vector2, font_size: int, color: Color, shadow := true) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var ascent := font.get_ascent(font_size)
	var descent := font.get_descent(font_size)
	var baseline := Vector2(center.x - text_size.x / 2.0, center.y + (ascent - descent) / 2.0)
	if shadow:
		draw_string(font, baseline + Vector2(1.5, 2.5), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _c(Color(0, 0, 0, 0.22)))
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, _c(color))


static func wrap_text(font: Font, text: String, font_size: int, width: float) -> PackedStringArray:
	# 按字符折行(中文没有空格);标点不放在行首
	var lines := PackedStringArray()
	var line := ""
	for ch in text:
		var trial := line + ch
		if line != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width \
				and ch not in [",", "。", "、", "!", ",", "!", ")"]:
			lines.append(line)
			line = ch
		else:
			line = trial
	if line != "":
		lines.append(line)
	return lines


# —— 牌面 ——

func _edge() -> void:
	_rounded(_inset(0), CardFaces.CUT_LINE, CORNER)
	_rounded(_inset(1.5), CREAM, CORNER - 1)
	_rounded(_inset(8), Color.TRANSPARENT, CORNER - 8, 1, Color(CardFaces.PAPER_EDGE, 0.9), false)


func _draw_face() -> void:
	var accent := BombCatFaces.accent(card_id)
	_edge()
	_rounded(_inset(9), PAPER, CORNER - 9)
	_speckles()
	_rounded(_inset(13), Color.TRANSPARENT, CORNER - 13, 2, GOLD, false)
	# 顶部横幅 + 首字圆章 + 牌名
	_rounded(BANNER, accent, 14)
	_rounded(Rect2(BANNER.position + Vector2(0, BANNER.size.y - 10), Vector2(BANNER.size.x, 10)), accent.darkened(0.18), 6)
	_rounded(BANNER, Color.TRANSPARENT, 14, 2, GOLD, false)
	_circle(CHIP_CENTER, CHIP_RADIUS, PAPER, 2.5, GOLD)
	var name := BombCatCard.display_name(card_id)
	_text(_display, name.substr(0, 1), CHIP_CENTER, 26, accent.darkened(0.25), false)
	_text(_display, name, Vector2(176, BANNER.get_center().y - 2), NAME_SIZE, PAPER)
	# 图标圆盘
	_circle(ICON_CENTER, ICON_RADIUS, Color(accent, 0.14))
	draw_arc(ICON_CENTER, ICON_RADIUS, 0.0, TAU, 96, _c(GOLD), 4.0, true)
	draw_arc(ICON_CENTER, ICON_RADIUS - 9.0, 0.0, TAU, 96, _c(Color(accent, 0.45)), 1.5, true)
	for i in 16:
		var a := TAU * i / 16.0
		draw_circle(ICON_CENTER + Vector2(cos(a), sin(a)) * (ICON_RADIUS + 9.0), 2.2, _c(GOLD))
	_icon(card_id, ICON_CENTER, accent)
	# 底部说明
	_rounded(TEXT_BOX, Color(accent, 0.09), 12, 1, Color(accent, 0.4))
	var lines := wrap_text(_body, BombCatCard.description(card_id), TEXT_SIZE, TEXT_BOX.size.x - 26.0)
	var top := TEXT_BOX.get_center().y - (lines.size() - 1) * TEXT_LINE / 2.0
	for i in lines.size():
		_text(_body, lines[i], Vector2(TEXT_BOX.get_center().x, top + i * TEXT_LINE), TEXT_SIZE, INK, false)


func _speckles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468 + BombCatFaces.layer(card_id)
	for i in 150:
		var p := Vector2(rng.randf_range(16, size.x - 16), rng.randf_range(16, size.y - 16))
		var half := Vector2.ONE * rng.randf_range(0.5, 1.5)
		draw_rect(Rect2(p - half, half * 2.0), _c(Color(INK, rng.randf_range(0.02, 0.05))))


func _icon(id: String, c: Vector2, accent: Color) -> void:
	match id:
		BombCatCard.BOMB:
			_bomb_cat(c + Vector2(-4, 10), 1.0, BOMB_BODY, true)
		BombCatCard.DEFUSE:
			_cutters(c, accent)
		BombCatCard.SKIP:
			_paw_trail(c, accent)
		BombCatCard.PASS_TURNS:
			_wok(c, accent)
		BombCatCard.PEEK:
			_eye(c, accent)
		BombCatCard.SHUFFLE:
			_shuffle(c, accent)
		BombCatCard.BEG:
			_beg(c)
		BombCatCard.NOPE:
			_nope(c, accent)
		BombCatCard.SNACK_FISH:
			_fish(c)
		BombCatCard.SNACK_YARN:
			_yarn(c)
		BombCatCard.SNACK_CARROT:
			_carrot(c)
		BombCatCard.SNACK_BANANA:
			_banana(c)
		BombCatCard.SNACK_CACTUS:
			_cactus(c)


# —— 图标 ——

func _bomb_cat(c: Vector2, s: float, body: Color, face: bool) -> void:
	# 圆滚滚的炸弹猫:猫耳、导火索从头顶冒出来、末端一颗火花;face = 画眼睛胡子(牌背的剪影不画)
	var outline := 3.0 * s if face else 0.0
	for side in [-1.0, 1.0]:
		var ear := PackedVector2Array([c + Vector2(side * 54, -10) * s, c + Vector2(side * 44, -72) * s, c + Vector2(side * 12, -48) * s])
		_poly(ear, body, outline)
		if face:
			_poly(PackedVector2Array([c + Vector2(side * 46, -22) * s, c + Vector2(side * 42, -58) * s, c + Vector2(side * 22, -44) * s]), PINK)
	_circle(c, 60.0 * s, body, outline)
	# 导火索接口 + 导火索 + 火花
	var socket := c + Vector2(14, -56) * s
	_rounded(Rect2(socket - Vector2(12, 9) * s, Vector2(24, 16) * s), METAL if face else body, int(4 * s), int(2 * s) if face else 0, INK)
	var fuse := bezier(socket + Vector2(0, -6) * s, socket + Vector2(4, -34) * s, socket + Vector2(34, -24) * s, socket + Vector2(40, -44) * s)
	draw_polyline(fuse, _c(Color(0.8, 0.64, 0.42) if face else body), 6.0 * s, true)
	var tip := fuse[fuse.size() - 1]
	_poly(star(tip, 24.0 * s, 9.0 * s, 8, 0.2), GOLD)
	_poly(star(tip, 14.0 * s, 6.0 * s, 8, 0.0), SPARK if face else GOLD)
	if face:
		_circle(tip, 4.0 * s, Color(1, 0.97, 0.85))
		# 高光
		_poly(ellipse(c + Vector2(-28, -24) * s, 14 * s, 8 * s, -0.7), Color(1, 1, 1, 0.28))
		# 眼睛:吓得瞪圆
		for side in [-1.0, 1.0]:
			_circle(c + Vector2(side * 22, 4) * s, 13.0 * s, Color(1, 1, 1))
			_circle(c + Vector2(side * 20, 6) * s, 6.0 * s, INK)
			_circle(c + Vector2(side * 18, 3) * s, 2.2 * s, Color(1, 1, 1))
			_circle(c + Vector2(side * 36, 22) * s, 7.0 * s, Color(PINK, 0.65))
		# 嘴:小小的 w
		var mouth := PackedVector2Array([c + Vector2(-9, 22) * s, c + Vector2(-4, 28) * s, c + Vector2(0, 23) * s,
			c + Vector2(4, 28) * s, c + Vector2(9, 22) * s])
		draw_polyline(mouth, _c(Color(1, 1, 1, 0.9)), 2.5 * s, true)
		for side in [-1.0, 1.0]:
			for k in 3:
				var from := c + Vector2(side * 30, 16 + k * 7) * s
				draw_line(from, from + Vector2(side * 30, -6 + k * 6) * s, _c(Color(1, 1, 1, 0.75)), 2.0 * s, true)


func _cutters(c: Vector2, accent: Color) -> void:
	# 剪线钳:两根杆在铆钉处交叉,上面是钳口、下面是红黄两色的握把;钳口里一根被剪断的红线冒出火星
	var pivot := c + Vector2(0, -4)
	var grips := [Color(0.9, 0.27, 0.24), Color(0.99, 0.78, 0.22)]
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		draw_set_transform(pivot, side * -0.36, Vector2.ONE)
		# 钳口(往上)
		_poly(PackedVector2Array([Vector2(-9, 2), Vector2(9, 2), Vector2(6, -38), Vector2(2 * side, -58), Vector2(-6, -40)]), METAL, 2.5)
		# 握把(往下)
		_rounded(Rect2(Vector2(-14, 12), Vector2(28, 84)), grips[i], 13, 3, INK)
		_rounded(Rect2(Vector2(-7, 22), Vector2(6, 62)), Color(1, 1, 1, 0.3), 3)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_circle(pivot, 10.0, METAL, 2.5)
	_circle(pivot, 3.5, INK)
	# 被剪断的线
	var wire := Color(0.86, 0.18, 0.2)
	draw_polyline(bezier(c + Vector2(-88, -30), c + Vector2(-60, -60), c + Vector2(-32, -44), c + Vector2(-12, -52)), _c(wire), 7.0, true)
	draw_polyline(bezier(c + Vector2(12, -54), c + Vector2(36, -60), c + Vector2(60, -34), c + Vector2(88, -44)), _c(wire), 7.0, true)
	for k in 5:
		var a := -PI / 2 + (k - 2) * 0.5
		_line(c + Vector2(0, -56) + Vector2(cos(a), sin(a)) * 12.0, c + Vector2(0, -56) + Vector2(cos(a), sin(a)) * 24.0, GOLD, 3.0)


func _paw(at: Vector2, rot: float, s: float, color: Color) -> void:
	draw_set_transform(at, rot, Vector2(s, s))
	_poly(ellipse(Vector2(0, 8), 17, 14), color)
	for p in [Vector2(-17, -10), Vector2(-6, -19), Vector2(6, -19), Vector2(17, -10)]:
		_poly(ellipse(p, 6.5, 8.0), color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paw_trail(c: Vector2, accent: Color) -> void:
	# 溜了:一串越来越淡的脚印往右上角跑出去,后面一溜烟、三道速度线
	var dark := accent.darkened(0.35)
	_paw(c + Vector2(-58, 56), 0.75, 0.7, Color(dark, 0.35))
	_paw(c + Vector2(-26, 28), 0.75, 0.82, Color(dark, 0.6))
	_paw(c + Vector2(10, -2), 0.75, 0.94, Color(dark, 0.85))
	_paw(c + Vector2(44, -36), 0.75, 1.06, dark)
	for k in 3:
		var y := -66.0 + k * 16.0
		_line(c + Vector2(-70 + k * 10, y), c + Vector2(-22 + k * 12, y + 4), Color(accent, 0.75), 5.0)
	for p in [Vector2(-78, 70), Vector2(-62, 80), Vector2(-86, 84), Vector2(-70, 92)]:
		_circle(c + p, 10.0, Color(0.85, 0.82, 0.76), 2.0, Color(INK, 0.4))


func _wok(c: Vector2, accent: Color) -> void:
	# 甩锅:一口铁锅翻着跟头飞向右上,后面一道虚线弧和箭头,锅里冒出两缕热气
	var arc := bezier(c + Vector2(-82, 70), c + Vector2(-70, 10), c + Vector2(-40, -20), c + Vector2(-8, -18))
	for i in range(0, arc.size() - 1, 3):
		draw_line(arc[i], arc[mini(i + 1, arc.size() - 1)], _c(accent.darkened(0.2)), 5.0, true)
	var rot := -0.4
	var wok_c := c + Vector2(18, 4)
	draw_set_transform(wok_c, rot, Vector2.ONE)
	_rounded(Rect2(Vector2(-112, -9), Vector2(56, 18)), Color(0.55, 0.36, 0.22), 8, 3, INK)
	_poly(ellipse(Vector2.ZERO, 62, 34), Color(0.27, 0.27, 0.32), 3.0)
	_poly(ellipse(Vector2(0, -6), 50, 22), Color(0.45, 0.46, 0.52))
	_poly(ellipse(Vector2(-14, -12), 18, 7), Color(1, 1, 1, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for k in 2:
		var x := 6.0 + k * 26.0
		draw_polyline(bezier(wok_c + Vector2(x, -38), wok_c + Vector2(x - 14, -54), wok_c + Vector2(x + 14, -64),
			wok_c + Vector2(x, -84)), _c(Color(1, 1, 1, 0.7)), 4.0, true)
	# 被甩到的那一边:冒个感叹号
	_poly(PackedVector2Array([c + Vector2(70, -74), c + Vector2(84, -74), c + Vector2(80, -40), c + Vector2(74, -40)]), accent)
	_circle(c + Vector2(77, -30), 5.0, accent)


func _eye(c: Vector2, accent: Color) -> void:
	# 偷看:三张小牌背在上面扇开,一只大眼睛从下面偷瞄
	for k in 3:
		draw_set_transform(c + Vector2(-34 + k * 34, -34), (k - 1) * 0.3, Vector2.ONE)
		_rounded(Rect2(Vector2(-22, -32), Vector2(44, 62)), BACK_RED, 7, 3, GOLD)
		_circle(Vector2.ZERO, 8.0, GOLD)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var eye_c := c + Vector2(0, 34)
	var lid := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0
		lid.append(eye_c + Vector2(lerpf(-66, 66, t), -sin(t * PI) * 40))
	for i in range(23, 0, -1):
		var t := float(i) / 24.0
		lid.append(eye_c + Vector2(lerpf(-66, 66, t), sin(t * PI) * 32))
	_poly(lid, Color(1, 1, 1), 4.0)
	_circle(eye_c + Vector2(8, -2), 25.0, accent)
	_circle(eye_c + Vector2(10, -2), 12.0, INK)
	_circle(eye_c + Vector2(2, -10), 6.0, Color(1, 1, 1))
	for k in 5:
		var t := 0.2 + k * 0.15
		var p := eye_c + Vector2(lerpf(-66, 66, t), -sin(t * PI) * 40)
		_line(p, p + Vector2((t - 0.5) * 22, -14), INK, 3.5)


func _shuffle(c: Vector2, accent: Color) -> void:
	# 洗牌:两张牌交叉,外面一圈首尾相接的循环箭头
	var dark := accent.darkened(0.15)
	for half in 2:
		var from := deg_to_rad(-160.0 + half * 180.0)
		var to := deg_to_rad(-30.0 + half * 180.0)
		draw_arc(c, 70.0, from, to, 40, _c(dark), 12.0, true)
		var end := c + Vector2(cos(to), sin(to)) * 70.0
		var tangent := Vector2(-sin(to), cos(to))
		var normal := Vector2(cos(to), sin(to))
		_poly(PackedVector2Array([end + tangent * 22.0, end + normal * 17.0, end - normal * 17.0]), dark)
	draw_set_transform(c + Vector2(-12, 2), -0.3, Vector2.ONE)
	_rounded(Rect2(Vector2(-25, -36), Vector2(50, 72)), BACK_RED, 8, 3, GOLD)
	_circle(Vector2.ZERO, 9.0, GOLD)
	draw_set_transform(c + Vector2(14, -2), 0.28, Vector2.ONE)
	_rounded(Rect2(Vector2(-25, -36), Vector2(50, 72)), PAPER, 8, 3, accent)
	_poly(star(Vector2.ZERO, 16, 7), accent)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _paw_pad(c: Vector2, s: float) -> void:
	# 掌心朝前的猫爪:白爪 + 粉色肉垫
	_circle(c, 62.0 * s, Color(1, 0.98, 0.94), 3.5 * s)
	_poly(ellipse(c + Vector2(0, 16) * s, 30 * s, 24 * s), PINK)
	for p in [Vector2(-34, -14), Vector2(-13, -34), Vector2(13, -34), Vector2(34, -14)]:
		_poly(ellipse(c + p * s, 10 * s, 12 * s), PINK)


func _beg(c: Vector2) -> void:
	# 讨要:伸出来的猫爪,上方一颗小心心和亮晶晶
	_paw_pad(c + Vector2(0, 16), 1.0)
	var heart := c + Vector2(52, -62)
	var pts := PackedVector2Array()
	for i in 40:
		var t := TAU * i / 40.0
		pts.append(heart + Vector2(16 * pow(sin(t), 3), -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))) * 1.3)
	_poly(pts, Color(0.92, 0.28, 0.4), 2.5)
	_poly(star(c + Vector2(-60, -56), 12, 4, 4), GOLD)
	_poly(star(c + Vector2(-42, -78), 7, 2.5, 4), GOLD)


func _nope(c: Vector2, accent: Color) -> void:
	# 不行!:一只伸出来的爪子,压一个红色禁止标志
	_paw_pad(c, 0.72)
	draw_arc(c, 76.0, 0.0, TAU, 64, _c(accent), 15.0, true)
	var d := Vector2(cos(-PI * 0.75), sin(-PI * 0.75)) * 76.0
	_line(c + d, c - d, accent, 15.0)


func _fish(c: Vector2) -> void:
	# 鱼干:斜着的一条小鱼,身上几道鱼刺纹
	var body := Color(0.86, 0.63, 0.36)
	var dark := Color(0.58, 0.38, 0.2)
	draw_set_transform(c, -0.3, Vector2.ONE)
	_poly(PackedVector2Array([Vector2(46, 0), Vector2(84, -30), Vector2(74, 0), Vector2(84, 30)]), body, 3.0)
	_poly(ellipse(Vector2(-6, 0), 60, 30), body, 3.0)
	_line(Vector2(-40, 0), Vector2(46, 0), dark, 3.0)
	for k in 5:
		var x := -22.0 + k * 14.0
		_line(Vector2(x, -18), Vector2(x + 6, 0), dark, 2.5)
		_line(Vector2(x, 18), Vector2(x + 6, 0), dark, 2.5)
	_circle(Vector2(-40, -6), 7.0, Color(1, 1, 1), 2.0)
	_circle(Vector2(-41, -6), 3.0, INK)
	draw_polyline(PackedVector2Array([Vector2(-62, 6), Vector2(-56, 10), Vector2(-50, 8)]), _c(INK), 2.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _yarn(c: Vector2) -> void:
	# 毛线球:两根毛衣针斜插在后面,球上几道缠线,一根线头卷出来
	var wool := Color(0.93, 0.52, 0.72)
	var dark := Color(0.7, 0.3, 0.5)
	for side in [-1.0, 1.0]:
		_line(c + Vector2(side * -70, -66), c + Vector2(side * 40, 54), Color(0.66, 0.46, 0.28), 6.0)
		_circle(c + Vector2(side * -70, -66), 8.0, Color(0.9, 0.75, 0.3), 2.0)
	var ball := c + Vector2(0, 6)
	_circle(ball, 58.0, wool, 3.0)
	for k in 4:
		var center := ball + Vector2(-90 + k * 50, -70 + k * 10)
		var pts := PackedVector2Array()
		for i in 60:
			var a := TAU * i / 60.0
			var p := center + Vector2(cos(a), sin(a)) * 110.0
			if p.distance_to(ball) < 54.0:
				pts.append(p)
		if pts.size() > 1:
			draw_polyline(pts, _c(dark), 3.0, true)
	draw_polyline(bezier(ball + Vector2(44, 36), ball + Vector2(90, 40), ball + Vector2(60, 90), ball + Vector2(92, 82)), _c(dark), 3.5, true)


func _carrot(c: Vector2) -> void:
	# 胡萝卜:斜着一根,顶上三片叶子,身上几道浅纹
	draw_set_transform(c, 0.5, Vector2.ONE)
	for k in 3:
		_poly(ellipse(Vector2(-14 + k * 14, -66), 9, 26, (k - 1) * 0.45), Color(0.32, 0.66, 0.3), 2.5)
	var body := PackedVector2Array()
	for i in 13:
		var a := PI + PI * i / 12.0
		body.append(Vector2(cos(a) * 30, -40 + sin(a) * 12))
	body.append(Vector2(6, 78))
	body.append(Vector2(-4, 78))
	_poly(body, Color(0.98, 0.55, 0.16), 3.0)
	for k in 4:
		var y := -22.0 + k * 22.0
		var w := 24.0 - k * 5.0
		_line(Vector2(-w, y), Vector2(-w + 12, y + 2), Color(0.8, 0.36, 0.08), 3.0)
		_line(Vector2(w - 2, y + 10), Vector2(w - 12, y + 12), Color(0.8, 0.36, 0.08), 3.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _banana(c: Vector2) -> void:
	# 香蕉:一弯月牙(中间胖、两头尖),一头是褐色的蒂、一头是黑尖
	var center := c + Vector2(0, -78)
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var highlight := PackedVector2Array()
	for i in 25:
		var t := float(i) / 24.0
		var a := deg_to_rad(lerpf(22.0, 158.0, t))
		var thick := 40.0 * sin(t * PI) + 3.0
		var dir := Vector2(cos(a), sin(a))
		outer.append(center + dir * 116.0)
		inner.append(center + dir * (116.0 - thick))
		if t > 0.15 and t < 0.85:
			highlight.append(center + dir * (116.0 - thick * 0.62))
	inner.reverse()
	_poly(outer + inner, Color(0.99, 0.84, 0.26), 3.0)
	draw_polyline(highlight, _c(Color(1, 0.97, 0.7)), 5.0, true)
	_circle(outer[outer.size() - 1], 6.0, Color(0.3, 0.2, 0.12))
	draw_set_transform(outer[0], -0.9, Vector2.ONE)
	_rounded(Rect2(Vector2(-6, -22), Vector2(12, 24)), Color(0.5, 0.36, 0.18), 4, 2, INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _cactus(c: Vector2) -> void:
	# 仙人掌:陶盆里一株胖仙人掌,两只小胳膊,头顶开一朵粉花,还有一张笑脸
	var green := Color(0.38, 0.7, 0.38)
	_rounded(Rect2(c + Vector2(-66, -22), Vector2(26, 52)), green, 13, 3, INK)
	_rounded(Rect2(c + Vector2(-66, 8), Vector2(46, 22)), green, 11, 0)
	_rounded(Rect2(c + Vector2(42, -46), Vector2(26, 48)), green, 13, 3, INK)
	_rounded(Rect2(c + Vector2(22, -12), Vector2(46, 20)), green, 10, 0)
	_rounded(Rect2(c + Vector2(-28, -70), Vector2(56, 120)), green, 28, 3, INK)
	for p in [Vector2(-14, -40), Vector2(14, -50), Vector2(-16, 20), Vector2(16, 12), Vector2(-56, -6), Vector2(55, -30)]:
		_line(c + p, c + p + Vector2(4, -5), Color(0.95, 0.95, 0.85), 2.0)
	_circle(c + Vector2(-10, -16), 4.0, INK)
	_circle(c + Vector2(10, -16), 4.0, INK)
	draw_arc(c + Vector2(0, -8), 8.0, 0.3, PI - 0.3, 12, _c(INK), 2.5, true)
	for k in 5:
		var a := TAU * k / 5.0
		_circle(c + Vector2(0, -74) + Vector2(cos(a), sin(a)) * 8.0, 7.0, Color(0.98, 0.55, 0.7))
	_circle(c + Vector2(0, -74), 5.0, Color(1, 0.9, 0.4))
	var pot := PackedVector2Array([c + Vector2(-44, 44), c + Vector2(44, 44), c + Vector2(34, 92), c + Vector2(-34, 92)])
	_poly(pot, Color(0.82, 0.44, 0.26), 3.0)
	_rounded(Rect2(c + Vector2(-50, 36), Vector2(100, 18)), Color(0.88, 0.52, 0.32), 6, 3, INK)


# —— 牌背 ——

func _draw_back() -> void:
	_edge()
	_rounded(_inset(9), BACK_RED, CORNER - 9)
	var inner := _inset(24)
	var spacing := 22.0
	var line_color := Color(GOLD, 0.24)
	var t := -inner.size.y
	while t < inner.size.x:
		_clipped_line(inner, Vector2(inner.position.x + t, inner.position.y), Vector2(1, 1), line_color)
		_clipped_line(inner, Vector2(inner.end.x - t, inner.position.y), Vector2(-1, 1), line_color)
		t += spacing
	_rounded(_inset(15), Color.TRANSPARENT, CORNER - 15, 3, GOLD, false)
	_rounded(_inset(22), Color.TRANSPARENT, CORNER - 22, 1, GOLD, false)
	for corner in 4:
		var flip := Vector2(1 if corner % 2 == 0 else -1, 1 if corner < 2 else -1)
		var origin := Vector2(0 if corner % 2 == 0 else size.x, 0 if corner < 2 else size.y)
		_poly(star(origin + Vector2(40, 40) * flip, 9.0, 3.5, 4), GOLD)
	# 中央圆章:金圈 + 炸弹猫剪影(金色)+ 火花
	var center := size / 2.0
	_circle(center, 96.0, BACK_BADGE)
	draw_arc(center, 96.0, 0.0, TAU, 96, _c(GOLD), 5.0, true)
	draw_arc(center, 84.0, 0.0, TAU, 96, _c(Color(GOLD, 0.55)), 1.5, true)
	for i in 24:
		var a := TAU * i / 24.0
		draw_line(center + Vector2(cos(a), sin(a)) * 87.0, center + Vector2(cos(a), sin(a)) * 92.0, _c(GOLD), 2.0, true)
	_bomb_cat(center + Vector2(-6, 14), 0.78, GOLD, false)
	# 剪影上点两只眼睛(深红,露出底色)
	for side in [-1.0, 1.0]:
		_circle(center + Vector2(-6, 14) + Vector2(side * 17, 4) * 0.78, 6.0, BACK_BADGE)


func _clipped_line(rect: Rect2, origin: Vector2, dir: Vector2, color: Color) -> void:
	# 斜线裁剪到矩形内(解析求交:沿 dir 的参数区间与矩形的交)
	var t0 := -INF
	var t1 := INF
	for axis in 2:
		var o := origin[axis]
		var d := dir[axis]
		var lo := rect.position[axis]
		var hi := rect.end[axis]
		if absf(d) < 0.0001:
			if o < lo or o > hi:
				return
			continue
		var a := (lo - o) / d
		var b := (hi - o) / d
		t0 = maxf(t0, minf(a, b))
		t1 = minf(t1, maxf(a, b))
	if t1 > t0:
		draw_line(origin + dir * t0, origin + dir * t1, _c(color), 2.0, true)
