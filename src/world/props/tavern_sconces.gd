class_name TavernSconces
# 壁灯:四面墙上的木牌黄铜壁灯,玻璃罩里一截蜡烛,补亮房间四周,避免只有牌桌一圈亮。
# 造型见 SconceModel:所有壁灯的木、铜、蜡、玻璃拼成两个网格(不投影);火苗与灯光每盏一份。


# [墙内表面上的位置, 朝向房间的偏航角]
const SCONCES := [
	[Vector3(-1.7, Tavern.SCONCE_HEIGHT, 4.4), 0.0], [Vector3(1.7, Tavern.SCONCE_HEIGHT, 4.4), 0.0],
	[Vector3(1.4, Tavern.SCONCE_HEIGHT, -4.4), PI], [Vector3(3.2, Tavern.SCONCE_HEIGHT, -4.4), PI],
	[Vector3(-4.4, Tavern.SCONCE_HEIGHT, 2.0), -PI / 2.0], [Vector3(-4.4, Tavern.SCONCE_HEIGHT, -3.1), -PI / 2.0],
	[Vector3(4.4, Tavern.SCONCE_HEIGHT, 1.7), PI / 2.0],
]
const FLAME_SIZE := Vector2(0.035, 0.07)
const FLAME_INTENSITY := 3.5


static func build(tavern: Tavern) -> void:
	var sconces := MeshKit.pivot(tavern, Vector3.ZERO, "Sconces")
	var xforms := placements()
	MeshBatch.instance(sconces, SconceModel.fittings_mesh(xforms), {}, "Fittings", false)
	MeshBatch.instance(sconces, SconceModel.glass_mesh(xforms), {}, "Glass", false)
	for i in xforms.size():
		_sconce(tavern, sconces, i, xforms[i], 60.0 + i)


static func placements() -> Array:
	# 每盏壁灯的变换:本地 -Z 指向房间
	var out := []
	for spec in SCONCES:
		out.append(Transform3D(Basis(Vector3.UP, spec[1]), spec[0]))
	return out


static func _sconce(tavern: Tavern, parent: Node3D, index: int, xform: Transform3D, seed: float) -> void:
	# 火苗与灯光挂在 Sconce<n> 节点下(名字各不相同,重名会被引擎改成 @Node3D@N;
	# tools/perf_probe.gd 按父节点名前缀 Sconce 找壁灯的灯光)
	var root := MeshKit.pivot(parent, xform.origin, "Sconce%d" % (index + 1))
	root.basis = xform.basis
	var flame := MeshKit.add(root, MeshKit.quad(FLAME_SIZE), WorldMaterials.flame(FLAME_INTENSITY, seed),
		SconceModel.FLAME_POS)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 灯光参数与位置保持原样(灯光调校在别处)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.05, -0.2)
	light.light_color = Color(1.0, 0.74, 0.48)
	light.light_energy = 1.0
	light.omni_range = 4.6
	light.light_volumetric_fog_energy = 0.5
	root.add_child(light)
	tavern.add_flicker(light, 4.0, 0.12, seed)
