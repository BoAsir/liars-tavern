class_name RoomMaterials
# 房间的材质:地板/天花板木板、灰泥、木料、窗外夜空、窗帘绒布。都经 WorldMaterials.cached 缓存,
# 开场建一次,之后共用(陈设也用这里的木料)。颜色一律按 sRGB 写。


const BOARDS_SHADER := preload("res://src/world/shaders/room_boards.gdshader")
const PLASTER_SHADER := preload("res://src/world/shaders/room_plaster.gdshader")
const TIMBER_SHADER := preload("res://src/world/shaders/room_timber.gdshader")
const SKY_SHADER := preload("res://src/world/shaders/room_sky.gdshader")
const CLOTH_SHADER := preload("res://src/world/shaders/decor_cloth.gdshader")

const CEILING_BOARDS := {
	"color_dark": Color(0.2, 0.15, 0.12), "color_light": Color(0.4, 0.3, 0.22),
	"plank_width": 0.17, "plank_length": 2.6, "knot_chance": 0.2, "nail_radius": 0.0, "wear": 0.0,
	"roughness_base": 0.85,
}
const CURTAIN_VELVET := {
	"base_color": Color(0.5, 0.12, 0.12), "weave_density": Vector2(420.0, 420.0), "weave_strength": 0.1,
	"sheen": 0.9, "grime": 0.12, "roughness_base": 0.8,
}


static func floor_boards() -> ShaderMaterial:
	return WorldMaterials.cached("room:floor", func() -> ShaderMaterial: return shader_material(BOARDS_SHADER, {}))


static func ceiling_boards() -> ShaderMaterial:
	return WorldMaterials.cached("room:ceiling", func() -> ShaderMaterial:
		return shader_material(BOARDS_SHADER, CEILING_BOARDS))


static func plaster() -> ShaderMaterial:
	return WorldMaterials.cached("room:plaster", func() -> ShaderMaterial: return shader_material(PLASTER_SHADER, {}))


static func timber() -> ShaderMaterial:
	return WorldMaterials.cached("room:timber", func() -> ShaderMaterial: return shader_material(TIMBER_SHADER, {}))


static func sky() -> ShaderMaterial:
	return WorldMaterials.cached("room:sky", func() -> ShaderMaterial: return shader_material(SKY_SHADER, {}))


static func velvet() -> ShaderMaterial:
	return WorldMaterials.cached("room:velvet", func() -> ShaderMaterial:
		return shader_material(CLOTH_SHADER, CURTAIN_VELVET))


static func shader_material(shader: Shader, params: Dictionary) -> ShaderMaterial:
	# 颜色按 Color 传(sRGB):source_color 的 uniform 只对 Color 值做 sRGB → 线性换算,与着色器里写的默认值一致
	var mat := ShaderMaterial.new()
	mat.shader = shader
	for param in params:
		mat.set_shader_parameter(param, params[param])
	return mat
