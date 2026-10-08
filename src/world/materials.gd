class_name WorldMaterials
# 程序化材质库:所有 3D 物件共用的材质预设(带缓存,同一预设只创建一次)。


const WOOD_SHADER := preload("res://src/world/shaders/wood.gdshader")
const FELT_SHADER := preload("res://src/world/shaders/felt.gdshader")
const STONE_SHADER := preload("res://src/world/shaders/stone.gdshader")
const FLAME_SHADER := preload("res://src/world/shaders/flame.gdshader")
const PARTICLE_SHADER := preload("res://src/world/shaders/soft_particle.gdshader")
const PARTICLE_ADD_SHADER := preload("res://src/world/shaders/soft_particle_add.gdshader")
const PATRON_SHADER := preload("res://src/world/shaders/patron.gdshader")
const PROP_SHADER := preload("res://src/world/shaders/prop.gdshader")

# 木材预设:颜色 + 纹理参数
const WOOD_PRESETS := {
	"floor": {
		"color_dark": Color(0.075, 0.05, 0.035), "color_light": Color(0.25, 0.165, 0.105),
		"scale": 1.0, "ring_frequency": 7.0, "grain_axis": 0, "across_axis": 2,
		"plank_width": 0.22, "plank_length": 2.1, "roughness_base": 0.7, "wear": 0.8,
	},
	"wall": {
		"color_dark": Color(0.07, 0.045, 0.03), "color_light": Color(0.2, 0.125, 0.08),
		"scale": 1.0, "ring_frequency": 6.0, "grain_axis": 1, "across_axis": 0,
		"plank_width": 0.18, "plank_length": 3.0, "roughness_base": 0.66, "wear": 0.5,
	},
	"wall_side": {
		"color_dark": Color(0.07, 0.045, 0.03), "color_light": Color(0.2, 0.125, 0.08),
		"scale": 1.0, "ring_frequency": 6.0, "grain_axis": 1, "across_axis": 2,
		"plank_width": 0.18, "plank_length": 3.0, "roughness_base": 0.66, "wear": 0.5,
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
		"color_dark": Color(0.16, 0.05, 0.02), "color_light": Color(0.45, 0.17, 0.07),
		"scale": 4.0, "ring_frequency": 6.0, "grain_axis": 1, "across_axis": 0,
		"roughness_base": 0.45, "varnish": 1.0,
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
		return mat)


static func patron() -> ShaderMaterial:
	# 所有酒客共用的顶点 PBR 材质(出局褪色走实例参数 fade)
	return _cached("patron", func():
		var mat := ShaderMaterial.new()
		mat.shader = PATRON_SHADER
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
		match kind:
			"fireplace":
				mat.set_shader_parameter("block_size", 0.22)
				mat.set_shader_parameter("soot", 0.9)
				mat.set_shader_parameter("soot_height", 1.4)
			"plaster":
				mat.set_shader_parameter("color_a", Vector3(0.3, 0.27, 0.23))
				mat.set_shader_parameter("color_b", Vector3(0.19, 0.17, 0.15))
				mat.set_shader_parameter("soot", 0.35)
				mat.set_shader_parameter("soot_height", 3.6)
		return mat)


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


static func gunmetal() -> StandardMaterial3D:
	return _cached("gunmetal", func(): return _standard(Color(0.16, 0.17, 0.2), 0.92, 0.3))


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
