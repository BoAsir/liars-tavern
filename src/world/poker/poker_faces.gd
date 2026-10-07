class_name PokerFaces
# 德州扑克 52 张牌面:在离屏 SubViewport 里矢量绘制「超大角标」四色牌面(PokerFacePainter),
# 抓取成带 mipmap 的贴图。缓存与骗子酒馆的 CardFaces 分开:CardFaces.texture 遇到德州牌才转到这里,
# CardFaces.is_built 仍只管骗子酒馆的 5 张;牌背沿用 CardFaces.BACK。
# 52 张约 25 MiB,所以只在进入德州时(等待厅、迟到者进牌桌、说明书翻到德州那本)才在后台生成:
# 每帧最多 BATCH_SIZE 个 SubViewport,分批完成不卡顿;生成完刷新 3D 牌的材质并发出 built 信号,
# 2D 小牌据此重新取纹理。无头模式(哑渲染器不出图)下退化为按花色着色的小纯色纹理,逻辑照常运行。


const SIZE := PokerFaceArt.SIZE
const BATCH_SIZE := 13                     # 每帧最多这么多个 SubViewport
const FALLBACK_SIZE := 8                   # 占位与退化纹理的边长
const FALLBACK_TINT := 0.3                 # 退化纹理向花色偏的程度:无头调试时还分得出花色
const VIEWPORT_MSAA := Viewport.MSAA_8X    # 多边形自己不抗锯齿,靠离屏视口的 2D MSAA


class Notifier:
	extends RefCounted
	signal built   # 52 张牌面都有了(无头模式下是退化纹理)


# 测试钩子:替换「渲染一批牌面」,func(tree: SceneTree, cards: Array) -> Array(每张一个 Image,可为空;可以是协程)。
# 无头模式的哑渲染器既不出图也不发 frame_post_draw,单测靠它走分批、并发与打断的逻辑
static var batch_renderer := Callable()

static var _textures := {}
static var _placeholder: Texture2D = null
static var _notifier: Notifier = null
static var _building := false
static var _generation := 0                # clear() 时加一:进行中的生成发现代数变了就作废


static func texture(card: int) -> Texture2D:
	# 还没生成(或不是德州牌)时返回占位:一张素纸
	if _textures.has(card):
		return _textures[card]
	return _placeholder_texture()


static func is_built() -> bool:
	return _textures.size() == cards().size()


static func built_signal() -> Signal:
	# GDScript 没有静态信号:由一个 RefCounted 信号源代发。请连接节点的方法(节点释放时自动断开);
	# clear() 会连同所有连接一起丢掉信号源,免得退出时还挂着连接
	if _notifier == null:
		_notifier = Notifier.new()
	return _notifier.built


static func clear() -> void:
	# 退出与测试用:丢掉纹理、占位与信号源;进行中的生成在交图时发现代数变了,整批作废
	_textures = {}
	_placeholder = null
	_notifier = null
	_building = false
	_generation += 1


static func cards() -> Array[int]:
	# 全部 52 张,按点数、花色升序
	var out: Array[int] = []
	for r in range(PokerCard.RANK_MIN, PokerCard.RANK_MAX + 1):
		for s in PokerCard.SUITS:
			out.append(PokerCard.make(r, s))
	return out


static func batches(items: Array, size: int) -> Array:
	var out := []
	for start in range(0, items.size(), size):
		out.append(items.slice(start, start + size))
	return out


static func build(host: Node) -> void:
	# 只需调用一次;并发调用时等第一次完成。host 只用来找场景树:视口挂在根节点下,调用者中途释放也不影响
	if is_built():
		return
	if host == null or not host.is_inside_tree():
		push_error("PokerFaces.build:host 必须在场景树里")
		return
	var tree := host.get_tree()
	var generation := _generation
	if _building:
		while _building and generation == _generation:
			await tree.process_frame
		return
	_building = true
	if batch_renderer.is_null() and DisplayServer.get_name() == "headless":
		for card in cards():
			_textures[card] = _fallback(card)
	else:
		for batch in batches(cards(), BATCH_SIZE):
			var images: Array = await _render(tree, batch)
			if generation != _generation:
				return
			for i in batch.size():
				_textures[batch[i]] = _to_texture(images[i] if i < images.size() else null, batch[i])
	_building = false
	Card3D.refresh_materials()
	built_signal().emit()


static func _render(tree: SceneTree, batch: Array) -> Array:
	if not batch_renderer.is_null():
		return await batch_renderer.call(tree, batch)
	return await _render_viewports(tree, batch)


static func _render_viewports(tree: SceneTree, batch: Array) -> Array:
	var holder := Node.new()
	holder.name = "PokerFacesBatch"
	var viewports: Array[SubViewport] = []
	for card in batch:
		var vp := _viewport(card)
		holder.add_child(vp)
		viewports.append(vp)
	# 延迟挂到根节点:调用者可能正处在 _ready 里,那时根节点不接受新的子节点
	tree.root.add_child.call_deferred(holder)
	# UPDATE_ONCE 的视口进树后的下一次绘制才出图:等两次绘制,拿到的一定是画好的
	await RenderingServer.frame_post_draw
	await tree.process_frame
	await RenderingServer.frame_post_draw
	var images := []
	for vp in viewports:
		images.append(vp.get_texture().get_image() if is_instance_valid(vp) else null)
	if is_instance_valid(holder):
		holder.queue_free()
	return images


static func _viewport(card: int) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = SIZE
	vp.transparent_bg = true   # 圆角外透明:牌面着色器按透明度裁掉
	vp.msaa_2d = VIEWPORT_MSAA
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	vp.add_child(PokerFacePainter.new(card))
	return vp


static func _to_texture(image: Image, card: int) -> Texture2D:
	if image == null or image.is_empty():
		return _fallback(card)
	image.generate_mipmaps()   # 2D 小牌从 256 像素缩小很多倍,要用带 mipmap 的线性过滤
	return ImageTexture.create_from_image(image)


static func _fallback(card: int) -> Texture2D:
	return _solid(CardFaces.PAPER.lerp(PokerFaceArt.SUIT_COLORS[PokerCard.suit(card)], FALLBACK_TINT))


static func _placeholder_texture() -> Texture2D:
	if _placeholder == null:
		_placeholder = _solid(CardFaces.PAPER)
	return _placeholder


static func _solid(color: Color) -> Texture2D:
	var image := Image.create(FALLBACK_SIZE, FALLBACK_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(color)
	image.generate_mipmaps()   # fill 只填第 0 级:先填色再生成 mipmap
	return ImageTexture.create_from_image(image)
