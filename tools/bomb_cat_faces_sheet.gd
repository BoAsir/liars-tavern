extends SceneTree
# 炸弹猫牌面验收图(需要窗口渲染,不能 --headless):
#   bomb_faces_full.png   14 张全尺寸(320×462)总览:第一行牌背 + 炸弹 + 拆弹 + 五张功能牌,第二行不行! + 五种零食
#   bomb_faces_strip.png  按 2D 手牌条的实际尺寸(带 mipmap 的线性过滤)缩小,1:1 像素,再 ×2 最近邻放大
#   bomb_foil_full.png    烫金遮罩
# 用法:godot --path . -s tools/bomb_cat_faces_sheet.gd -- --out=/tmp/bomb_faces


const GAP := 8
const BACKDROP := Color(0.09, 0.07, 0.06)
const COLUMNS := 7
const STRIP_CARD := Vector2i(70, 101)   # = BombCatHandStrip.CARD_SIZE

var opts := {}


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "true"
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var out_dir: String = opts.get("out", OS.get_user_data_dir() + "/bomb_faces")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var host := Node.new()
	root.add_child(host)
	var started := Time.get_ticks_msec()
	await BombCatFaces.build(host)
	print("built in %d ms, layers=%d" % [Time.get_ticks_msec() - started, BombCatFaces.face_array().get_layers()])
	if BombCatFaces.texture(BombCatFaces.BACK).get_width() != BombCatFaces.SIZE.x:
		push_error("牌面没有生成出来(需要窗口渲染)")
		quit(1)
		return
	_save(_full(func(i: int) -> Image: return BombCatFaces.face_array().get_layer_data(i), BombCatFaces.SIZE),
		out_dir + "/bomb_faces_full.png")
	_save(_full(func(i: int) -> Image:
		var img := BombCatFaces.foil_array().get_layer_data(i)
		img.convert(Image.FORMAT_RGBA8)
		return img, BombCatFaces.FOIL_SIZE), out_dir + "/bomb_foil_full.png")
	var strip := await _strip()
	_save(strip, out_dir + "/bomb_faces_strip.png")
	strip.resize(strip.get_width() * 2, strip.get_height() * 2, Image.INTERPOLATE_NEAREST)
	_save(strip, out_dir + "/bomb_faces_strip_x2.png")
	quit()


func _full(layer_image: Callable, card: Vector2i) -> Image:
	var count := BombCatFaces.layer_count()
	var rows := ceili(float(count) / COLUMNS)
	var sheet := Image.create(COLUMNS * (card.x + GAP) + GAP, rows * (card.y + GAP) + GAP, false, Image.FORMAT_RGBA8)
	sheet.fill(BACKDROP)
	for i in count:
		var img: Image = layer_image.call(i)
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		var at := Vector2i(GAP + (i % COLUMNS) * (card.x + GAP), GAP + (i / COLUMNS) * (card.y + GAP))
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	return sheet


func _strip() -> Image:
	var count := BombCatFaces.layer_count()
	var cell := STRIP_CARD + Vector2i(GAP, GAP)
	var vp := SubViewport.new()
	vp.size = Vector2i(COLUMNS * cell.x + GAP, 2 * cell.y + GAP)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var backdrop := ColorRect.new()
	backdrop.color = BACKDROP
	backdrop.size = Vector2(vp.size)
	vp.add_child(backdrop)
	for i in count:
		var rect := TextureRect.new()
		rect.texture = BombCatFaces.texture(BombCatFaces.LAYERS[i])
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.size = Vector2(STRIP_CARD)
		rect.position = Vector2(GAP + (i % COLUMNS) * cell.x, GAP + (i / COLUMNS) * cell.y)
		vp.add_child(rect)
	root.add_child(vp)
	for i in 3:
		await RenderingServer.frame_post_draw
	var image := vp.get_texture().get_image()
	vp.queue_free()
	return image


func _save(image: Image, path: String) -> void:
	var err := image.save_png(path)
	print("saved %s %dx%d %s" % [path, image.get_width(), image.get_height(), error_string(err)])
