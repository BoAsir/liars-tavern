extends SceneTree
# 生成应用图标 icon.png(512×512):深色圆角底 + 两张交叠的牌(牌背 + 鬼牌)。需要窗口渲染,不能 --headless。
# 用法:godot --path . -s tools/make_icon.gd


const SIZE := 512
const OUT := "res://icon.png"


func _initialize() -> void:
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var host := Node.new()
	root.add_child(host)
	await CardFaces.build(host)
	var back: Image = CardFaces.texture(CardFaces.BACK).get_image()
	var joker: Image = CardFaces.texture(Card.JOKER).get_image()
	if back == null or joker == null:
		push_error("牌面纹理不可用(需要窗口渲染)")
		quit(1)
		return
	for img in [back, joker]:
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
	var icon := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	_fill_rounded(icon, Color(0.1, 0.06, 0.04), 96)
	_blit_card(icon, back, Vector2i(70, 70), -0.18)
	_blit_card(icon, joker, Vector2i(200, 92), 0.16)
	var err := icon.save_png(ProjectSettings.globalize_path(OUT))
	print("icon -> ", OUT, " ", error_string(err))
	quit(0 if err == OK else 1)


func _fill_rounded(img: Image, color: Color, radius: int) -> void:
	for y in SIZE:
		for x in SIZE:
			var cx := clampi(x, radius, SIZE - 1 - radius)
			var cy := clampi(y, radius, SIZE - 1 - radius)
			if Vector2(x - cx, y - cy).length() <= radius:
				img.set_pixel(x, y, color)


func _blit_card(dst: Image, card: Image, origin: Vector2i, angle: float) -> void:
	# 缩放到高 330 后按角度旋转贴上(逐像素反向采样,保留圆角透明)
	var scaled: Image = card.duplicate()
	scaled.resize(int(card.get_width() * 330.0 / card.get_height()), 330, Image.INTERPOLATE_LANCZOS)
	var w: int = scaled.get_width()
	var h: int = scaled.get_height()
	var center := Vector2(origin) + Vector2(w, h) / 2.0
	for y in SIZE:
		for x in SIZE:
			var p := Vector2(x, y) - center
			var local := p.rotated(-angle) + Vector2(w, h) / 2.0
			if local.x < 0 or local.y < 0 or local.x >= w - 1 or local.y >= h - 1:
				continue
			var c: Color = scaled.get_pixelv(Vector2i(local))
			if c.a < 0.05:
				continue
			dst.set_pixel(x, y, dst.get_pixel(x, y).blend(c))
