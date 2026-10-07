class_name TavernTable
extends Node3D
# 牌桌一带:圆桌(桌面随半径可变)、桌上烛台(可收起)、桌子正上方的吊灯(摆动由 Tavern 驱动)。


const LAMP_DROP := 1.3
# 烛台:[桌面上的方位角, 蜡烛数, 种子]。角度避开各座位的左轮摆放位置(3 人局 240° 座位的枪原本会穿过第二个烛台)
const CANDLE_SPOTS := [[PI * 0.76, 3, 1.0], [PI * 1.31, 2, 7.0]]
const CANDLE_RADIUS := 0.7
# felt.gdshader 里刺绣圈的默认值,对应默认桌布半径;换桌面大小时按比例缩放
const FELT_RINGS := {"radius": 0.8, "inner_ring": 0.28, "outer_ring": 0.70}
const FELT_INSET := 0.13   # 桌布比桌面半径小这么多

var tavern: Tavern
var lamp_pivot: Node3D
var radius := SeatLayout.TABLE_RADIUS

var _top: Node3D        # 随半径重建的桌面部分
var _decor: Array[Node3D] = []


func _init(p_tavern: Tavern) -> void:
	tavern = p_tavern
	name = "TavernTable"
	_build_table()
	_build_lamp()
	_build_candles()


func set_radius(p_radius: float) -> void:
	if is_equal_approx(p_radius, radius):
		return
	radius = p_radius
	_top.queue_free()
	_build_top()


func set_decor_visible(p_visible: bool) -> void:
	for holder in _decor:
		holder.visible = p_visible


# —— 牌桌 ——

func _build_table() -> void:
	var table := MeshKit.pivot(self, Vector3.ZERO, "Table")
	MeshKit.add(table, MeshKit.cylinder(0.09, 0.13, 0.62, 24), WorldMaterials.wood("dark"), Vector3(0, 0.41, 0))
	MeshKit.add(table, MeshKit.cylinder(0.16, 0.16, 0.06, 24), WorldMaterials.brass(), Vector3(0, 0.66, 0))
	MeshKit.add(table, MeshKit.cylinder(0.32, 0.46, 0.08, 32), WorldMaterials.wood("dark"), Vector3(0, 0.04, 0))
	_build_top()


func _build_top() -> void:
	_top = MeshKit.pivot(self, Vector3.ZERO, "TableTop")
	var top_y := SeatLayout.TABLE_TOP
	var r := radius
	MeshKit.add(_top, MeshKit.cylinder(r, r, 0.06, 64), WorldMaterials.wood("table"), Vector3(0, top_y - 0.03, 0))
	MeshKit.add(_top, MeshKit.cylinder(r + 0.02, r - 0.03, 0.05, 64), WorldMaterials.wood("dark"),
		Vector3(0, top_y - 0.075, 0))
	MeshKit.add(_top, MeshKit.torus(r - 0.012, r + 0.008, 96), WorldMaterials.brass(), Vector3(0, top_y, 0),
		Vector3.ZERO, Vector3(1, 0.35, 1))
	var felt_radius := r - FELT_INSET
	var felt := MeshKit.add(_top, MeshKit.cylinder(felt_radius, felt_radius, 0.004, 96), _felt_for(felt_radius),
		Vector3(0, top_y + 0.002, 0))
	felt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _felt_for(felt_radius: float) -> Material:
	# 桌布刺绣圈按桌布半径等比缩放;默认桌面直接用共享材质
	var default_radius := SeatLayout.TABLE_RADIUS - FELT_INSET
	if is_equal_approx(felt_radius, default_radius):
		return WorldMaterials.felt()
	var mat: ShaderMaterial = WorldMaterials.felt().duplicate()
	for param in FELT_RINGS:
		mat.set_shader_parameter(param, FELT_RINGS[param] * felt_radius / default_radius)
	return mat


# —— 吊灯 ——

func _build_lamp() -> void:
	lamp_pivot = MeshKit.pivot(self, Vector3(0, Tavern.ROOM_HEIGHT, 0), "LampPivot")
	MeshKit.add(lamp_pivot, MeshKit.cylinder(0.006, 0.006, LAMP_DROP, 6), WorldMaterials.iron(),
		Vector3(0, -LAMP_DROP / 2.0, 0))
	var shade_y := -LAMP_DROP - 0.1
	var shade_mesh := MeshKit.cylinder(0.07, 0.36, 0.2, 48)
	shade_mesh.cap_bottom = false
	var shade_mat := StandardMaterial3D.new()
	shade_mat.albedo_color = Color(0.12, 0.2, 0.14)
	shade_mat.metallic = 0.6
	shade_mat.roughness = 0.35
	shade_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	MeshKit.add(lamp_pivot, shade_mesh, shade_mat, Vector3(0, shade_y, 0))
	MeshKit.add(lamp_pivot, MeshKit.torus(0.355, 0.37, 48), WorldMaterials.brass(), Vector3(0, shade_y - 0.1, 0))
	MeshKit.add(lamp_pivot, MeshKit.sphere(0.055), WorldMaterials.emissive(Color(1.0, 0.82, 0.55), 9.0),
		Vector3(0, shade_y - 0.06, 0))
	var spot := SpotLight3D.new()
	spot.position = Vector3(0, shade_y - 0.05, 0)
	spot.rotation_degrees = Vector3(-90, 0, 0)
	spot.light_color = Color(1.0, 0.84, 0.66)
	spot.light_energy = 3.5
	spot.spot_range = 3.4
	spot.spot_angle = 52.0
	spot.spot_angle_attenuation = 0.7
	spot.shadow_enabled = true
	spot.shadow_blur = 1.5
	spot.light_volumetric_fog_energy = 2.2
	lamp_pivot.add_child(spot)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, shade_y + 0.05, 0)
	fill.light_color = Color(1.0, 0.72, 0.45)
	fill.light_energy = 1.5
	fill.omni_range = 7.5
	fill.light_volumetric_fog_energy = 0.3
	lamp_pivot.add_child(fill)
	tavern.add_flicker(spot, 0.7, 0.04, 3.0)


# —— 烛台 ——

func _build_candles() -> void:
	var top_y := SeatLayout.TABLE_TOP
	for spec in CANDLE_SPOTS:
		var base := SeatLayout.direction(spec[0]) * CANDLE_RADIUS + Vector3(0, top_y, 0)
		var holder := MeshKit.pivot(self, base, "Candles")
		_decor.append(holder)
		MeshKit.add(holder, MeshKit.cylinder(0.07, 0.08, 0.012, 24), WorldMaterials.brass(), Vector3(0, 0.006, 0))
		for i in spec[1]:
			var offset := Vector3(cos(i * 2.1) * 0.035, 0, sin(i * 2.1) * 0.035) if spec[1] > 1 else Vector3.ZERO
			var height: float = 0.07 + 0.045 * ((i * 37 + int(spec[2])) % 3)
			_candle(holder, offset, height, spec[2] + i)


func _candle(parent: Node3D, offset: Vector3, height: float, seed: float) -> void:
	var wax := WorldMaterials.emissive(Color(0.9, 0.84, 0.72), 0.03)
	MeshKit.add(parent, MeshKit.cylinder(0.016, 0.018, height, 16), wax, offset + Vector3(0, 0.012 + height / 2.0, 0))
	MeshKit.add(parent, MeshKit.sphere(0.012, 10), wax, offset + Vector3(0.012, 0.012 + height * 0.8, 0),
		Vector3.ZERO, Vector3(0.6, 1.4, 0.6))
	var flame_y := 0.012 + height + 0.026
	MeshKit.add(parent, MeshKit.quad(Vector2(0.03, 0.06)), WorldMaterials.flame(4.0, seed), offset + Vector3(0, flame_y, 0))
	var light := OmniLight3D.new()
	light.position = offset + Vector3(0, flame_y + 0.02, 0)
	light.light_color = Color(1.0, 0.74, 0.48)
	light.light_energy = 0.42
	light.omni_range = 2.2
	light.light_volumetric_fog_energy = 0.4
	parent.add_child(light)
	tavern.add_flicker(light, 6.0, 0.35, seed * 13.0)
