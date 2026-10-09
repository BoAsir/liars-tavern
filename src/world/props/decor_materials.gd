class_name DecorMaterials
# 陈设的材质:地毯、画布(油画、通缉令、黑板、飞镖盘共用一个着色器,按顶点色 alpha 选图案)、麻布袋、
# 上色的哑光/釉面小物(书、陶罐、帽子、鱼……颜色写在顶点色里,一个材质服务一整批)、描金画框。
# 木料沿用 RoomMaterials.timber(),铁、黄铜沿用 WorldMaterials。都经 WorldMaterials.cached 缓存。


const RUG_SHADER := preload("res://src/world/shaders/decor_rug.gdshader")
const CANVAS_SHADER := preload("res://src/world/shaders/decor_canvas.gdshader")

# 画布图案:写在部件染色的 alpha 里(decor_canvas.gdshader 按区间分支)
const CANVAS_LANDSCAPE := 0.0
const CANVAS_PORTRAIT := 0.25
const CANVAS_POSTER := 0.5
const CANVAS_CHALK := 0.75
const CANVAS_DARTBOARD := 1.0

const BURLAP := {
	"base_color": Color(0.52, 0.43, 0.31), "weave_density": Vector2(260.0, 240.0), "weave_strength": 0.4,
	"sheen": 0.0, "grime": 0.3, "roughness_base": 0.95,
}


static func rug() -> ShaderMaterial:
	return WorldMaterials.cached("decor:rug", func() -> ShaderMaterial:
		return RoomMaterials.shader_material(RUG_SHADER, {}))


static func canvas() -> ShaderMaterial:
	return WorldMaterials.cached("decor:canvas", func() -> ShaderMaterial:
		return RoomMaterials.shader_material(CANVAS_SHADER, {}))


static func burlap() -> ShaderMaterial:
	return WorldMaterials.cached("decor:burlap", func() -> ShaderMaterial:
		return RoomMaterials.shader_material(RoomMaterials.CLOTH_SHADER, BURLAP))


static func matte() -> StandardMaterial3D:
	# 哑光上色:书脊、帽子、稻草、毛线、木桶塞……
	return WorldMaterials.cached("decor:matte", func() -> StandardMaterial3D: return _tinted(0.82, 0.0, 0.4))


static func glazed() -> StandardMaterial3D:
	# 釉面:陶罐、瓷盘、鱼鳞的湿润光泽
	return WorldMaterials.cached("decor:glazed", func() -> StandardMaterial3D: return _tinted(0.3, 0.0, 0.6))


static func gilt() -> StandardMaterial3D:
	# 描金画框:金属感,顶点色控制金色深浅(旧金、暗金)
	return WorldMaterials.cached("decor:gilt", func() -> StandardMaterial3D: return _tinted(0.4, 0.6, 0.5))


static func _tinted(roughness: float, metallic: float, specular: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = roughness
	mat.metallic = metallic
	mat.metallic_specular = specular
	return mat
