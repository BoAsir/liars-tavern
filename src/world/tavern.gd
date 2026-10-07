class_name Tavern
extends Node3D
# 常驻 3D 酒馆:环境与后期、灯光闪烁、吊灯摆动;房间与道具由 src/world/props/ 下各区域的建模器搭建。
# 布局:牌桌在原点;本机座位朝 -Z 看,对面墙是壁炉,左墙吧台,右墙月光窗。


const ROOM_HALF := 4.5
const ROOM_HEIGHT := 3.4
const WALL_THICKNESS := 0.2
const WAINSCOT_HEIGHT := 1.1
const FIREPLACE_X := -1.5
const WINDOW_Z := -0.9
const WINDOW_SIZE := Vector2(1.3, 1.25)
const WINDOW_BOTTOM := 1.15
const SCONCE_HEIGHT := 2.15
const LAMP_REST_SWING := 0.015

var camera_rig: CameraRig
var table_root: Node3D
var environment: Environment
var table: TavernTable

var _lamp_swing := LAMP_REST_SWING
var _flickers: Array = []   # [{"light": Light3D, "base": float, "speed": float, "depth": float, "seed": float}]
var _time := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.frequency = 1.0
	_build_environment()
	TavernRoom.build(self)
	table = TavernTable.new(self)
	add_child(table)
	TavernFireplace.build(self)
	TavernBar.build(self)
	TavernDecor.build(self)
	TavernSconces.build(self)
	PatronParts.prewarm()
	_build_dust()
	table_root = MeshKit.pivot(self, Vector3.ZERO, "TableRoot")
	camera_rig = CameraRig.new()
	add_child(camera_rig)


func _process(delta: float) -> void:
	_time += delta
	for f in _flickers:
		var n := _noise.get_noise_2d(_time * f["speed"], f["seed"])
		f["light"].light_energy = f["base"] * (1.0 + n * f["depth"])
	# 吊灯钟摆:开枪等事件会加大摆幅,随后衰减回微弱摆动
	_lamp_swing = lerpf(_lamp_swing, LAMP_REST_SWING, delta * 0.35)
	table.lamp_pivot.rotation.x = sin(_time * 1.9) * _lamp_swing
	table.lamp_pivot.rotation.z = sin(_time * 1.3 + 1.0) * _lamp_swing * 0.6


func kick_lamp(strength: float) -> void:
	_lamp_swing = maxf(_lamp_swing, strength)


func add_flicker(light: Light3D, speed: float, depth: float, seed: float) -> void:
	# 火光闪烁:每帧按噪声在基础亮度上下浮动(base 取登记时的亮度)
	_flickers.append({"light": light, "base": light.light_energy, "speed": speed, "depth": depth, "seed": seed})


func set_table_radius(radius: float) -> void:
	# 换桌面大小(德州扑克用大桌):桌面、包边、黄铜圈、桌布随半径变化,桌面高度与桌腿不变
	table.set_radius(radius)


func set_table_decor_visible(visible: bool) -> void:
	# 桌面摆设(烛台连同烛光):德州扑克收起来给筹码和公共牌腾地方
	table.set_decor_visible(visible)


# —— 环境 ——

func _build_environment() -> void:
	environment = Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.008, 0.006, 0.005)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# 暖色主光 + 冷色环境补光:避免整屏单一橘色
	environment.ambient_light_color = Color(0.27, 0.26, 0.3)
	environment.ambient_light_energy = 0.62
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.tonemap_exposure = 1.32
	environment.tonemap_white = 6.0
	environment.glow_enabled = true
	environment.glow_intensity = 0.85
	environment.glow_strength = 1.0
	environment.glow_bloom = 0.04
	# 阈值高于漫反射能达到的亮度:只有火焰、灯泡等自发光会泛光,平放在灯下的牌不会糊成一团白
	environment.glow_hdr_threshold = 1.3
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	environment.ssao_enabled = true
	environment.ssao_radius = 0.9
	environment.ssao_intensity = 1.8
	# 不开 SSIL(屏幕空间间接光):实测内部 1080p 下约 3 毫秒/帧,开关前后画面几乎看不出差别
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.05
	environment.volumetric_fog_albedo = Color(0.85, 0.84, 0.82)
	environment.volumetric_fog_anisotropy = 0.55
	environment.volumetric_fog_length = 14.0
	environment.volumetric_fog_ambient_inject = 0.04
	environment.adjustment_enabled = true
	environment.adjustment_contrast = 1.07
	environment.adjustment_saturation = 0.94
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)


# —— 浮尘 ——

func _build_dust() -> void:
	add_child(Fx.dust_motes(Vector3(0, 1.6, 0), Vector3(1.6, 1.0, 1.6)))
	add_child(Fx.dust_motes(Vector3(2.6, 1.6, -0.6), Vector3(1.6, 0.9, 0.7)))
