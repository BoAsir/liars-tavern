class_name WorldMaterials
# 程序化材质库:所有 3D 物件共用的材质预设(带缓存,同一预设只创建一次)。


const WOOD_SHADER := preload("res://src/world/shaders/wood.gdshader")
const FELT_SHADER := preload("res://src/world/shaders/felt.gdshader")
const STONE_SHADER := preload("res://src/world/shaders/stone.gdshader")
const FLAME_SHADER := preload("res://src/world/shaders/flame.gdshader")
const PARTICLE_SHADER := preload("res://src/world/shaders/soft_particle.gdshader")
const PARTICLE_ADD_SHADER := preload("res://src/world/shaders/soft_particle_add.gdshader")
const PATRON_SHADER := preload("res://src/world/shaders/patron.gdshader")
const PATRON_EYE_SHADER := preload("res://src/world/shaders/patron_eye.gdshader")
const PROP_SHADER := preload("res://src/world/shaders/prop.gdshader")
const BOTTLE_SHADER := preload("res://src/world/shaders/bottle_glass.gdshader")
const DECOR_SHADER := preload("res://src/world/shaders/decor.gdshader")

# 木材预设:颜色 + 纹理参数
const WOOD_PRESETS := {
	"floor": {
		"color_dark": Color(0.075, 0.05, 0.035), "color_light": Color(0.25, 0.165, 0.105),
		"scale": 1.0, "ring_frequency": 7.0, "grain_axis": 0, "across_axis": 2,
		"plank_width": 0.22, "plank_length": 2.1, "roughness_base": 0.7, "wear": 0.8,
		# v2:逐板色差、倒角、钉头、酒渍;牌桌一圈和门口到吧台、壁炉前的走道踩得发亮
		"plank_tint": 0.16, "bevel": 1.0, "nails": 1.0, "stains": 0.8,
		"wear_ring": Vector4(0.0, -0.05, 2.15, 0.35), "wear_seg_a": Vector4(-0.35, 4.35, -0.3, 1.8),
		"wear_seg_b": Vector4(-1.0, -1.85, -1.5, -3.1),
		"stain_focus_a": Vector3(-2.6, -0.6, 1.6), "stain_focus_b": Vector3(0.0, 0.0, 2.6),
	},
	"wainscot": {
		# 框芯护墙板(部件空间:CUSTOM0 = 沿墙 u、离地 v、深度),四面墙与吧台台身共用一份
		"color_dark": Color(0.07, 0.045, 0.03), "color_light": Color(0.2, 0.125, 0.08),
		"scale": 1.0, "ring_frequency": 6.0, "grain_axis": 1, "across_axis": 0,
		"roughness_base": 0.66, "wear": 0.5, "varnish": 0.15,
		"pattern": 1, "panel": Vector3(0.08, 0.10, 0.045), "panel_pitch": 0.62, "panel_height": 1.1,
		"bevel": 1.0, "plank_tint": 0.12,
	},
	"ceiling": {
		# 天花板木板:板端都落在 z = 1.5k,藏在梁下
		"color_dark": Color(0.06, 0.035, 0.02), "color_light": Color(0.18, 0.10, 0.05),
		"scale": 1.0, "ring_frequency": 5.0, "grain_axis": 2, "across_axis": 0,
		"plank_width": 0.18, "plank_length": 1.5, "stagger": 0.0, "bevel": 1.0, "plank_tint": 0.1,
		"roughness_base": 0.8, "wear": 0.7,
	},
	"table": {
		"color_dark": Color(0.07, 0.035, 0.02), "color_light": Color(0.22, 0.12, 0.06),
		"scale": 1.0, "ring_frequency": 11.0, "grain_axis": 0, "across_axis": 2,
		"roughness_base": 0.55, "varnish": 0.55, "wear": 0.3,
	},
	"dark": {
		"color_dark": Color(0.05, 0.03, 0.02), "color_light": Color(0.16, 0.09, 0.05),
		"scale": 1.0, "ring_frequency": 8.0, "grain_axis": 0, "across_axis": 2,
		"roughness_base": 0.72, "wear": 0.4,
	},
	"beam": {
		"color_dark": Color(0.06, 0.035, 0.02), "color_light": Color(0.18, 0.10, 0.05),
		"scale": 1.0, "ring_frequency": 5.0, "grain_axis": 0, "across_axis": 1,
		"roughness_base": 0.8, "wear": 0.7,
	},
	"barrel": {
		"color_dark": Color(0.12, 0.06, 0.03), "color_light": Color(0.34, 0.18, 0.08),
		"scale": 1.0, "ring_frequency": 4.0, "grain_axis": 1, "across_axis": 0,
		"plank_width": 0.09, "plank_length": 9.0, "roughness_base": 0.7, "wear": 0.6,
	},
	"grip": {
		# 胡桃木握把:原来的红木在暖光里发粉
		"color_dark": Color(0.10, 0.055, 0.03), "color_light": Color(0.32, 0.18, 0.09),
		"scale": 4.0, "ring_frequency": 6.0, "grain_axis": 1, "across_axis": 0,
		"roughness_base": 0.45, "varnish": 0.6,
	},
	"log": {
		"color_dark": Color(0.07, 0.04, 0.02), "color_light": Color(0.22, 0.12, 0.06),
		"scale": 2.0, "ring_frequency": 3.0, "grain_axis": 1, "across_axis": 0,
		"roughness_base": 0.95, "wear": 1.0,
	},
}

static var _cache := {}


static func wood(preset: String, part_space := false) -> ShaderMaterial:
	# part_space:给 MeshForge 合并网格用,木纹按部件自己的局部坐标算。变体一律新建,不 duplicate()
	# (实测 duplicate 出来的材质木纹会走样)
	return _cached("wood:%s:%s" % [preset, part_space], func():
		var mat := ShaderMaterial.new()
		mat.shader = WOOD_SHADER
		for key in WOOD_PRESETS[preset]:
			var value = WOOD_PRESETS[preset][key]
			mat.set_shader_parameter(key, Vector3(value.r, value.g, value.b) if value is Color else value)
		mat.set_shader_parameter("use_part_space", part_space)
		mat.set_shader_parameter("surface_noise", SurfaceNoise.texture())
		return mat)


static func patron() -> ShaderMaterial:
	# 所有酒客共用的顶点 PBR 材质(出局褪色走实例参数 fade)
	return _cached("patron", func():
		var mat := ShaderMaterial.new()
		mat.shader = PATRON_SHADER
		return mat)


static func bottle_glass() -> ShaderMaterial:
	# 酒瓶 MultiMesh 共用的不透明假玻璃
	return _cached("bottle_glass", func():
		var mat := ShaderMaterial.new()
		mat.shader = BOTTLE_SHADER
		return mat)


static func patron_eye() -> ShaderMaterial:
	# 所有酒客眼睛共用(眨眼、看向、表情、出局都走实例参数)
	return _cached("patron_eye", func():
		var mat := ShaderMaterial.new()
		mat.shader = PATRON_EYE_SHADER
		return mat)


static func prop() -> ShaderMaterial:
	# 道具共用的顶点 PBR 材质
	return _cached("prop", func():
		var mat := ShaderMaterial.new()
		mat.shader = PROP_SHADER
		return mat)


static func felt() -> ShaderMaterial:
	return _cached("felt", func():
		var mat := ShaderMaterial.new()
		mat.shader = FELT_SHADER
		return mat)


static func stone(kind: String) -> ShaderMaterial:
	return _cached("stone:" + kind, func():
		var mat := ShaderMaterial.new()
		mat.shader = STONE_SHADER
		mat.set_shader_parameter("surface_noise", SurfaceNoise.texture())
		match kind:
			"fireplace":
				# 行高 0.2、块宽 0.32,网格原点对齐壁炉外框左下前角:砖面边上没有细条
				mat.set_shader_parameter("block_size", RoomLayout.FIRE_COURSE)
				mat.set_shader_parameter("grid_origin", RoomLayout.FIRE_GRID_ORIGIN)
				mat.set_shader_parameter("soot", 0.9)
				mat.set_shader_parameter("soot_height", 1.4)
			"plaster":
				mat.set_shader_parameter("color_a", Vector3(0.31, 0.275, 0.23))
				mat.set_shader_parameter("color_b", Vector3(0.19, 0.165, 0.14))
				mat.set_shader_parameter("brick_amount", 0.18)
				mat.set_shader_parameter("crack_amount", 0.5)
				mat.set_shader_parameter("rail_y", RoomLayout.RAIL_TOP)
				mat.set_shader_parameter("ceiling_y", Tavern.ROOM_HEIGHT)
				mat.set_shader_parameter("top_soot", 0.45)
				var halos := []
				for sconce in Tavern.SCONCES:
					halos.append(Vector4(sconce[0].x, sconce[0].y + 0.05, sconce[0].z, 0.0))
				mat.set_shader_parameter("halos", halos)
				mat.set_shader_parameter("halo_count", halos.size())
		return mat)


static func decor() -> ShaderMaterial:
	# 墙饰、外景、烟熏镜、地毯、布料、余烬共用一份(模式写在顶点 UV2.x 上,可以跨物件合并)
	return _cached("decor", func():
		var mat := ShaderMaterial.new()
		mat.shader = DECOR_SHADER
		mat.set_shader_parameter("atlas", DecorAtlas.texture())
		mat.set_shader_parameter("surface_noise", SurfaceNoise.texture())
		mat.set_shader_parameter("rug_sizes", RoomLayout.rug_sizes())
		mat.set_shader_parameter("mirror_size", RoomLayout.MIRROR_SIZE)
		return mat)


static func lut() -> GradientTexture1D:
	# 暖色 1D 调色表:暗部微冷、高光微暖,高光不提亮(Environment.adjustment_color_correction,逐通道查表)
	return _cached("lut", func():
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 0.82, 1.0])
		gradient.colors = PackedColorArray([Color(0.0, 0.004, 0.018), Color(0.170, 0.178, 0.196),
			Color(0.505, 0.497, 0.478), Color(0.835, 0.815, 0.775), Color(1.0, 0.985, 0.95)])
		var tex := GradientTexture1D.new()
		tex.gradient = gradient
		tex.width = 256
		return tex)


static func decal_soft() -> GradientTexture2D:
	# 接地贴花:中心 alpha 0.7 的径向黑色渐变
	return _cached("decal_soft", func():
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		gradient.colors = PackedColorArray([Color(0, 0, 0, 0.7), Color(0, 0, 0, 0.45), Color(0, 0, 0, 0.0)])
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.width = 64
		tex.height = 64
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		return tex)


static func flame() -> ShaderMaterial:
	# 所有火焰共用这一份;强度与种子是实例参数(set_instance_shader_parameter),见 Tavern._flame
	return _cached("flame", func():
		var mat := ShaderMaterial.new()
		mat.shader = FLAME_SHADER
		return mat)


static func particle(additive: bool, boost: float, softness: float) -> ShaderMaterial:
	# 混合模式是着色器的编译期 render_mode,只能换着色器而不能用 uniform 切换;同参数共用一份
	return _cached("particle:%s:%s:%s" % [additive, boost, softness], func():
		var mat := ShaderMaterial.new()
		mat.shader = PARTICLE_ADD_SHADER if additive else PARTICLE_SHADER
		mat.render_priority = 1
		mat.set_shader_parameter("emission_boost", boost)
		mat.set_shader_parameter("softness", softness)
		return mat)


static func brass() -> StandardMaterial3D:
	return _cached("brass", func(): return _standard(Color(0.78, 0.56, 0.24), 1.0, 0.32))


static func iron() -> StandardMaterial3D:
	return _cached("iron", func(): return _standard(Color(0.09, 0.09, 0.1), 0.8, 0.55))


static func glass(color: Color) -> StandardMaterial3D:
	return _cached("glass:" + color.to_html(), func():
		var mat := _standard(color, 0.0, 0.06)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.55
		mat.metallic_specular = 0.8
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b) * 0.08
		return mat)


static func enamel(color: Color) -> StandardMaterial3D:
	# 珐琅(灯罩):不是金属,背景近乎全黑时金属会显成一块黑;无底圆锥要看得见内壁,双面渲染
	return _cached("enamel:" + color.to_html(), func():
		var mat := _standard(color, 0.0, 0.5)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		return mat)


static func beer() -> StandardMaterial3D:
	# 啤酒液面:不自发光(原来在暗处像一块发亮的金片)
	return _cached("beer", func(): return _standard(Color(0.78, 0.6, 0.28), 0.0, 0.25))


static func emissive(color: Color, energy: float) -> StandardMaterial3D:
	return _cached("emissive:%s:%.2f" % [color.to_html(), energy], func():
		var mat := _standard(color, 0.0, 0.5)
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
		return mat)


static func clear_cache() -> void:
	_cache = {}


static func _standard(color: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat


static func _cached(key: String, factory: Callable) -> Variant:
	# 返回 Variant:调用方声明的具体材质类型在运行时校验
	if not _cache.has(key):
		_cache[key] = factory.call()
	return _cache[key]
