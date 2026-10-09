class_name SurfaceNoise
# 墙地噪声贴图:启动时在离屏 SubViewport 里用 GPU 烘焙一张 512² 可平铺噪声(surface_noise_bake.gdshader),
# 木纹、灰泥、石砌、墙饰着色器按 mip 采样它,代替逐像素约 80 次哈希的 fbm。
# texture() 始终返回同一份 ImageTexture:烘好之前(以及无头运行时)是 4×4 的 0.5 灰,烘好后原地换图,
# 已经绑定它的材质不用重新设参数。


const SIZE := 512
const BASE_PERIOD := 16          # R 通道第 0 层的格点数(整张图 = 16 个单位)
const OCTAVES := 5
const FALLBACK_SIZE := 4
const BAKE_SHADER := preload("res://src/world/shaders/surface_noise_bake.gdshader")

static var _texture: ImageTexture = null
static var _built := false
static var _building := false


static func period_for_octave(k: int) -> int:
	# 第 k 层的格点数:倍频正好 2,所以每层都按整张图回绕
	return BASE_PERIOD * (1 << k)


static func texture() -> ImageTexture:
	if _texture == null:
		_texture = ImageTexture.create_from_image(fallback_image())
	return _texture


static func fallback_image() -> Image:
	var image := Image.create(FALLBACK_SIZE, FALLBACK_SIZE, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.5, 0.5, 0.5, 1.0))
	return image


static func is_built() -> bool:
	return _built


static func clear() -> void:
	_texture = null
	_built = false
	_building = false


static func build(host: Node) -> void:
	# 协程,只需调用一次;并发调用时等第一次完成。无头模式的哑渲染器不出帧,保留回退灰
	if _built:
		return
	if _building:
		while _building:
			await host.get_tree().process_frame
		return
	texture()
	if DisplayServer.get_name() == "headless":
		_built = true
		return
	_building = true
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = false
	vp.use_hdr_2d = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var rect := ColorRect.new()
	rect.size = Vector2(SIZE, SIZE)
	var mat := ShaderMaterial.new()
	mat.shader = BAKE_SHADER
	rect.material = mat
	vp.add_child(rect)
	host.add_child(vp)
	await RenderingServer.frame_post_draw
	await host.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = vp.get_texture().get_image()
	vp.queue_free()
	_building = false
	if _texture == null:
		return   # 等待期间被 clear() 了(退出中)
	if image != null and not image.is_empty():
		image.convert(Image.FORMAT_RGBA8)
		image.generate_mipmaps()
		_texture.set_image(image)
	_built = true
