class_name RoomKit
# 房间构建器共用的小工具:挂合批网格(层与投影一次设好)、火焰公告板、道具调色板。


# 道具调色板:sRGB albedo、粗糙度、金属度(prop.gdshader 的顶点 PBR)
const BRASS := [Color(0.78, 0.56, 0.24), 0.32, 1.0]
const OLD_BRASS := [Color(0.62, 0.45, 0.2), 0.42, 1.0]
const IRON := [Color(0.10, 0.10, 0.11), 0.55, 0.8]
const TIN := [Color(0.56, 0.56, 0.57), 0.38, 0.85]
const BONE := [Color(0.72, 0.66, 0.55), 0.72, 0.0]
const HORN := [Color(0.42, 0.36, 0.28), 0.5, 0.0]
const WAX := [Color(0.72, 0.672, 0.576), 0.5, 0.0]
const CLAY := [Color(0.52, 0.27, 0.15), 0.75, 0.0]
const CACTUS := [Color(0.22, 0.36, 0.16), 0.7, 0.0]
const LEATHER := [Color(0.30, 0.17, 0.09), 0.68, 0.0]
const FELT_HAT := [Color(0.24, 0.17, 0.11), 0.85, 0.0]
const COAT := [Color(0.36, 0.27, 0.18), 0.9, 0.0]
const GILT := [Color(0.70, 0.52, 0.22), 0.35, 0.9]
const GLASS_DARK := [Color(0.12, 0.16, 0.12), 0.08, 0.0]
const ROPE := [Color(0.55, 0.44, 0.28), 0.9, 0.0]
const FOAM := [Color(0.74, 0.71, 0.62), 0.6, 0.0]
const BEER := [Color(0.62, 0.40, 0.12), 0.3, 0.0]
const PEWTER := [Color(0.48, 0.48, 0.5), 0.45, 0.75]
const BLACK := [Color(0.05, 0.045, 0.04), 0.35, 0.0]
const CREAM := [Color(0.70, 0.64, 0.52), 0.6, 0.0]
const RED_PAINT := [Color(0.45, 0.10, 0.07), 0.5, 0.0]
const LAMP_GLASS := [Color(0.62, 0.60, 0.52), 0.15, 0.0]


static func paint(f: MeshForge, swatch: Array, ao := 1.0) -> void:
	f.paint(swatch[0], swatch[1], swatch[2])
	f.ao = ao


static func add(parent: Node3D, node_name: String, key: String, recipe: Callable, materials: Dictionary, layers: int,
		casts: bool, pos := Vector3.ZERO) -> MeshInstance3D:
	# 合批网格(MeshForge.cached,同 key 共享)挂到 parent 下;layers 与投影一次设好
	var inst := MeshKit.add(parent, MeshForge.cached(key, recipe, materials), null, pos, Vector3.ZERO, Vector3.ONE,
		MeshKit.SHADOW_ON if casts else MeshKit.SHADOW_OFF)
	inst.name = node_name
	inst.layers = layers
	return inst


static func flame(parent: Node3D, size: Vector2, pos: Vector3, intensity: float, seed: float) -> MeshInstance3D:
	# 火焰公告板:共用一份材质,强度与种子按实例设定(同 Tavern._flame)
	var inst := MeshKit.add(parent, MeshKit.quad(size), WorldMaterials.flame(), pos, Vector3.ZERO, Vector3.ONE, MeshKit.SHADOW_OFF)
	inst.set_instance_shader_parameter("intensity", intensity)
	inst.set_instance_shader_parameter("seed", seed)
	return inst


static func flicker(light: Light3D, speed: float, depth: float, seed: float) -> Dictionary:
	# Tavern._flickers 的一项
	return {"light": light, "base": light.light_energy, "speed": speed, "depth": depth, "seed": seed}


static func decor_paint(f: MeshForge, mode: int, param := 0.0, tint := Color.WHITE, ao := 1.0) -> void:
	# decor 材质:UV2 = (模式, 参数),COLOR = 色调 + AO
	f.paint(tint, float(mode), param)
	f.ao = ao


static func ring_profile(points: Array) -> PackedVector2Array:
	return PackedVector2Array(points)
