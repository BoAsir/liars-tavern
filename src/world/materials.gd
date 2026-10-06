class_name WorldMaterials
# 程序化材质库:所有 3D 物件共用的材质预设(带缓存,同一预设只创建一次)。


const WOOD_SHADER := preload("res://src/world/shaders/wood.gdshader")
const FELT_SHADER := preload("res://src/world/shaders/felt.gdshader")
const STONE_SHADER := preload("res://src/world/shaders/stone.gdshader")
const FLAME_SHADER := preload("res://src/world/shaders/flame.gdshader")
const PARTICLE_SHADER := preload("res://src/world/shaders/soft_particle.gdshader")

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


static func wood(preset: String) -> ShaderMaterial:
	return _cached("wood:" + preset, func():
		var mat := ShaderMaterial.new()
		mat.shader = WOOD_SHADER
		for key in WOOD_PRESETS[preset]:
			var value = WOOD_PRESETS[preset][key]
			mat.set_shader_parameter(key, Vector3(value.r, value.g, value.b) if value is Color else value)
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


static func flame(intensity: float, seed: float) -> ShaderMaterial:
	# 每簇火焰独立实例,seed 让相邻火苗不同步
	var mat := ShaderMaterial.new()
	mat.shader = FLAME_SHADER
	mat.set_shader_parameter("intensity", intensity)
	mat.set_shader_parameter("seed", seed)
	return mat


static func particle(additive: bool, boost: float, softness: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PARTICLE_SHADER
	mat.render_priority = 1
	mat.set_shader_parameter("additive", additive)
	mat.set_shader_parameter("emission_boost", boost)
	mat.set_shader_parameter("softness", softness)
	return mat


static func gunmetal() -> StandardMaterial3D:
	return _cached("gunmetal", func(): return _standard(Color(0.16, 0.17, 0.2), 0.92, 0.3))


static func brass() -> StandardMaterial3D:
	return _cached("brass", func(): return _standard(Color(0.78, 0.56, 0.24), 1.0, 0.32))


static func iron() -> StandardMaterial3D:
	return _cached("iron", func(): return _standard(Color(0.09, 0.09, 0.1), 0.8, 0.55))


static func cloth(color: Color) -> StandardMaterial3D:
	return _cached("cloth:" + color.to_html(), func():
		var mat := _standard(color, 0.0, 0.85)
		mat.rim_enabled = true
		mat.rim = 0.35
		mat.rim_tint = 0.6
		return mat)


static func skin(color: Color) -> StandardMaterial3D:
	return _cached("skin:" + color.to_html(), func():
		var mat := _standard(color, 0.0, 0.6)
		mat.rim_enabled = true
		mat.rim = 0.25
		mat.rim_tint = 0.4
		return mat)


static func glossy(color: Color) -> StandardMaterial3D:
	return _cached("glossy:" + color.to_html(), func(): return _standard(color, 0.0, 0.15))


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


static func unique(base: Material) -> Material:
	# 需要单独改色/淡出的物件(如出局变灰)使用独立副本
	return base.duplicate()


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
