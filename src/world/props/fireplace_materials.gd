class_name FireplaceMaterials
# 壁炉专用材质:石块、炉膛内衬、柴火、炭床四个程序化着色器,外加灰浆、壁炉台木料、铜壶、鹿角、
# 上釉的陶器、不反光的小件(蜡烛、书皮)、钟面。都经 WorldMaterials.cached 缓存,开场搭建时建好,对局中不再新建。


const STONE_SHADER := preload("res://src/world/shaders/fireplace_stone.gdshader")
const SOOT_SHADER := preload("res://src/world/shaders/fireplace_soot.gdshader")
const LOG_SHADER := preload("res://src/world/shaders/fireplace_log.gdshader")
const EMBERS_SHADER := preload("res://src/world/shaders/fireplace_embers.gdshader")

# 壁炉台横梁、钟壳、木柄:深色老橡木,顺长轴的木纹(部件按长轴为 X 建模),染色区分不同的木件
const OAK := {
	"color_dark": Color(0.04, 0.024, 0.015), "color_light": Color(0.16, 0.095, 0.055),
	"scale": 1.0, "ring_frequency": 6.0, "grain_axis": 0, "across_axis": 2,
	"roughness_base": 0.7, "varnish": 0.2, "wear": 0.65,
}


static func stone() -> ShaderMaterial:
	return _shader("fireplace:stone", STONE_SHADER)


static func soot() -> ShaderMaterial:
	return _shader("fireplace:soot", SOOT_SHADER)


static func logs() -> ShaderMaterial:
	return _shader("fireplace:logs", LOG_SHADER)


static func embers() -> ShaderMaterial:
	return _shader("fireplace:embers", EMBERS_SHADER)


static func oak() -> ShaderMaterial:
	return WorldMaterials.wood_with("fireplace:oak", OAK)


static func mortar() -> StandardMaterial3D:
	# 石缝里的灰浆:只从缝里露出来,纯色即可
	return WorldMaterials.cached("fireplace:mortar", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.13, 0.115, 0.1)
		mat.roughness = 1.0
		return mat)


static func copper() -> StandardMaterial3D:
	return WorldMaterials.cached("fireplace:copper", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.72, 0.4, 0.24)
		mat.metallic = 0.9
		mat.roughness = 0.38
		return mat)


static func bone() -> StandardMaterial3D:
	return WorldMaterials.cached("fireplace:bone", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.78, 0.7, 0.56)
		mat.roughness = 0.7
		return mat)


static func glazed() -> StandardMaterial3D:
	# 上釉的陶罐、书皮:颜色取顶点色(部件染色),一个表面装下各色小件
	return WorldMaterials.cached("fireplace:glazed", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.roughness = 0.42
		return mat)


static func matte() -> StandardMaterial3D:
	# 蜡烛、书皮、瓶塞这类不反光的小件:颜色同样取顶点色
	return WorldMaterials.cached("fireplace:matte", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.roughness = 0.78
		return mat)


static func clock_face() -> StandardMaterial3D:
	return WorldMaterials.cached("fireplace:clock_face", func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.86, 0.8, 0.66)
		mat.roughness = 0.5
		return mat)


static func _shader(key: String, shader: Shader) -> ShaderMaterial:
	return WorldMaterials.cached(key, func() -> ShaderMaterial:
		var mat := ShaderMaterial.new()
		mat.shader = shader
		return mat)
