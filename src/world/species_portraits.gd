class_name SpeciesPortraits
# 物种头像(主菜单与等待厅的 SpeciesChip / SpeciesPicker 用):texture(i) 取第 i 个物种的头像。
# 目前只有回退:物种主色的圆片(SpeciesChip 在上面叠物种首字),纯 Image 运算,无头也能跑。
# 3D 头像烘焙(子项目② §3.1:SubViewport 里摆 8 个 Patron 头像、正交相机、读回成图集)由建模会话接入:
# 在 build 里烘好后把 _textures 换成图集切片、置 _baked = true,接口不变;SpeciesChip 轮询 is_built() 换图。


const SIZE := 72                 # 回退圆片的边长(像素);头像按控件大小缩放
const RIM := 3.0                 # 圆片描边宽度
const RIM_DARKEN := 0.45
const UNASSIGNED_COLOR := Color(0.36, 0.33, 0.3)   # 还没有形象(挑选中…)的灰圆片
# 各物种主色(sRGB,取自子项目② §2 造型表的皮毛色),只用于回退圆片;下标与 Species.IDS 一致
const FALLBACK_COLORS := [
	Color(0.80, 0.40, 0.14),   # 狐狸
	Color(0.36, 0.21, 0.11),   # 熊
	Color(0.76, 0.47, 0.45),   # 猪
	Color(0.46, 0.47, 0.52),   # 猫
	Color(0.42, 0.55, 0.28),   # 乌龟
	Color(0.78, 0.66, 0.50),   # 羊驼
	Color(0.42, 0.26, 0.14),   # 猴子
	Color(0.24, 0.46, 0.22),   # 鳄鱼
]

static var _textures: Array = []   # 下标 = 物种;build 之后才有
static var _fallbacks := {}        # 物种下标(含 UNASSIGNED)-> 回退圆片
static var _baked := false         # 是真头像(3D 烘焙)而不是回退圆片


static func build(_host: Node) -> void:
	# 菜单出来之后调用一次,不 await 也行。现在直接用回退圆片(无头安全);
	# 接入 3D 烘焙时:非无头且物种网格已预建 → SubViewport 渲一帧、读回、切成 AtlasTexture
	if is_built():
		return
	_textures = []
	for i in Species.count():
		_textures.append(fallback_texture(i))
	_baked = false


static func is_built() -> bool:
	return _textures.size() == Species.count()


static func is_baked() -> bool:
	# 假:头像是回退圆片,SpeciesChip 要在上面叠物种首字
	return _baked


static func texture(index: int) -> Texture2D:
	if is_built() and Species.is_valid(index):
		return _textures[index]
	return fallback_texture(index)


static func fallback_color(index: int) -> Color:
	return FALLBACK_COLORS[index] if Species.is_valid(index) else UNASSIGNED_COLOR


static func fallback_texture(index: int) -> Texture2D:
	# 物种主色的圆片加深色描边,边缘按像素覆盖率抗锯齿;非法下标(含 UNASSIGNED)是灰圆片
	var key := Species.sanitize(index)
	if _fallbacks.has(key):
		return _fallbacks[key]
	var fill := fallback_color(key)
	var rim := fill.darkened(RIM_DARKEN)
	var image := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(SIZE, SIZE) / 2.0
	var radius := SIZE / 2.0 - 0.5
	for y in SIZE:
		for x in SIZE:
			var d := (Vector2(x, y) + Vector2(0.5, 0.5)).distance_to(center)
			var color := rim if d > radius - RIM else fill
			color.a = clampf(radius - d + 0.5, 0.0, 1.0)
			image.set_pixel(x, y, color)
	var texture := ImageTexture.create_from_image(image)
	_fallbacks[key] = texture
	return texture


static func clear() -> void:
	_textures = []
	_fallbacks = {}
	_baked = false
