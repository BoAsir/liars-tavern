class_name BarMaterials
# 吧台专用材质:深色上漆的吧台木料(柜台、酒架、凳子;木纹顺部件自身的 X 轴,建模时让长边沿 X)、
# 更亮的清漆台面、酒架背板(竖拼木板)、酒桶木、凳面皮革、酒瓶玻璃与酒标(程序化着色器)、
# 瓶塞/封蜡与陶壶(颜色取顶点色)、啤酒泡沫。都经 WorldMaterials.cached 缓存,开场搭建时建好,对局中不再新建。


const GLASS_SHADER := preload("res://src/world/shaders/bar_glass.gdshader")
const LABEL_SHADER := preload("res://src/world/shaders/bar_label.gdshader")

# 吧台木料:红褐色的老桃花心木,清漆打得发亮,磨损少
const WOOD := {
	"color_dark": Color(0.045, 0.02, 0.012), "color_light": Color(0.2, 0.085, 0.045),
	"scale": 1.0, "ring_frequency": 9.0, "grain_axis": 0, "across_axis": 2,
	"roughness_base": 0.5, "varnish": 0.6, "wear": 0.25,
}
# 台面:同一种木头、颜色略浅,厚清漆,胳膊肘常年磨出的亮面
const TOP := {
	"color_dark": Color(0.06, 0.028, 0.016), "color_light": Color(0.25, 0.12, 0.06),
	"scale": 1.0, "ring_frequency": 10.0, "grain_axis": 0, "across_axis": 2,
	"roughness_base": 0.42, "varnish": 0.9, "wear": 0.35,
}
# 酒架背板:竖拼的窄木板,比柜台暗,把酒瓶衬出来
const PANEL := {
	"color_dark": Color(0.035, 0.02, 0.013), "color_light": Color(0.12, 0.068, 0.04),
	"scale": 1.0, "ring_frequency": 6.0, "grain_axis": 1, "across_axis": 2,
	"plank_width": 0.13, "plank_length": 3.0, "roughness_base": 0.66, "wear": 0.45,
}


static func wood() -> ShaderMaterial:
	return WorldMaterials.wood_with("bar:wood", WOOD)


static func wood_turned() -> ShaderMaterial:
	# 同一种木头,木纹顺部件的 Y 轴:竖着的车木柱、凳腿、立板、竖向的门芯板
	return WorldMaterials.wood_with("bar:wood_turned", WOOD.merged({"grain_axis": 1, "across_axis": 0}, true))


static func top() -> ShaderMaterial:
	return WorldMaterials.wood_with("bar:top", TOP)


static func panel() -> ShaderMaterial:
	return WorldMaterials.wood_with("bar:panel", PANEL)


static func keg() -> ShaderMaterial:
	return WorldMaterials.wood("barrel")


static func leather() -> StandardMaterial3D:
	return WorldMaterials.cached("bar:leather", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.07, 0.05)
		mat.roughness = 0.42
		mat.clearcoat_enabled = true
		mat.clearcoat = 0.25
		mat.clearcoat_roughness = 0.4
		return mat)


static func glass() -> ShaderMaterial:
	return _shader("bar:glass", GLASS_SHADER)


static func label() -> ShaderMaterial:
	return _shader("bar:label", LABEL_SHADER)


static func cap() -> StandardMaterial3D:
	# 软木塞、封蜡、锡箔:颜色取顶点色
	return _tinted("bar:cap", 0.6)


static func ceramic() -> StandardMaterial3D:
	# 粗陶壶、陶罐:颜色取顶点色,釉面微亮
	return _tinted("bar:ceramic", 0.42)


static func foam() -> StandardMaterial3D:
	return WorldMaterials.cached("bar:foam", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.93, 0.88, 0.76)
		mat.roughness = 0.85
		return mat)


static func _tinted(key: String, roughness: float) -> StandardMaterial3D:
	return WorldMaterials.cached(key, func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.roughness = roughness
		return mat)


static func _shader(key: String, shader: Shader) -> ShaderMaterial:
	return WorldMaterials.cached(key, func() -> ShaderMaterial:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		return mat)
