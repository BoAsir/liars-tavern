class_name Tavern
extends Node3D
# 常驻 3D 酒馆:房间、牌桌、灯光、环境与道具(全部程序化生成)。
# 布局:牌桌在原点;本机座位朝 -Z 看,对面墙是壁炉,左墙吧台,右墙月光窗。


const ROOM_HALF := 4.5
const ROOM_HEIGHT := 3.4
const WALL_THICKNESS := 0.2
const WAINSCOT_HEIGHT := 1.1
const LAMP_DROP := 1.3
const FIREPLACE_X := -1.5
const WINDOW_Z := -0.9
const WINDOW_SIZE := Vector2(1.3, 1.25)
const WINDOW_BOTTOM := 1.15
const SCONCE_HEIGHT := 2.15
const CANDLE_ENERGY := 0.42   # 一支蜡烛的光(烛台的灯按支数折算)
# 壁灯:[墙内表面上的位置, 朝向房间的偏航角]。补亮房间四周,避免只有牌桌一圈亮
const SCONCES := [
	[Vector3(-1.7, SCONCE_HEIGHT, 4.4), 0.0], [Vector3(1.7, SCONCE_HEIGHT, 4.4), 0.0],
	[Vector3(1.4, SCONCE_HEIGHT, -4.4), PI], [Vector3(3.2, SCONCE_HEIGHT, -4.4), PI],
	[Vector3(-4.4, SCONCE_HEIGHT, 2.0), -PI / 2.0], [Vector3(-4.4, SCONCE_HEIGHT, -3.1), -PI / 2.0],
	[Vector3(4.4, SCONCE_HEIGHT, 1.7), PI / 2.0],
]

var camera_rig: CameraRig
var table_root: Node3D
var environment: Environment

var _lamp_pivot: Node3D
var _table: Node3D                       # 牌桌模型:德州时按半径放大
var _table_decor: Array[Node3D] = []     # 桌面摆设(烛台):德州时隐藏,给筹码与公共牌让位
var _lamp_swing := 0.015
var _flickers: Array = []   # [{"light": Light3D, "base": float, "speed": float, "depth": float, "seed": float}]
var _time := 0.0
var _noise := FastNoiseLite.new()


func _ready() -> void:
	_noise.frequency = 1.0
	_build_environment()
	_build_room()
	_build_table()
	_build_lamp()
	_build_candles()
	_build_fireplace()
	_build_bar()
	_build_window()
	_build_sconces()
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
	_lamp_swing = lerpf(_lamp_swing, 0.015, delta * 0.35)
	_lamp_pivot.rotation.x = sin(_time * 1.9) * _lamp_swing
	_lamp_pivot.rotation.z = sin(_time * 1.3 + 1.0) * _lamp_swing * 0.6


func kick_lamp(strength: float) -> void:
	_lamp_swing = maxf(_lamp_swing, strength)


func set_table_radius(radius: float) -> void:
	# 接口桩:整张桌子按半径在水平方向缩放。3D 模型重做分支(feature/model-detail)会换成
	# 按半径重建桌面、包边、铜圈与绒布且桌腿不动的正式实现,合并时以那边为准
	var k := radius / SeatLayout.TABLE_RADIUS
	_table.scale = Vector3(k, 1.0, k)
	# 德州灯光补丁(规格 §9;合并时核对模型重做分支做了没有,做了就删掉这段):吊灯聚光在桌面高度只照到
	# 半径约 1.5 米,放大的桌沿在半影外。按桌面半径放宽到照到桌沿外 EDGE_REACH,再加一点半影;
	# 骗子酒馆桌保持 _build_lamp 里原来的角度
	const LIARS_SPOT_ANGLE := 52.0
	const EDGE_REACH := 0.15
	const SOFT_EDGE_DEG := 2.5
	for spot in _lamp_pivot.get_children().filter(func(n: Node) -> bool: return n is SpotLight3D):
		var drop: float = (_lamp_pivot.transform * spot.transform).origin.y - SeatLayout.TABLE_TOP
		var needed := rad_to_deg(atan((radius + EDGE_REACH) / drop)) + SOFT_EDGE_DEG
		spot.spot_angle = maxf(LIARS_SPOT_ANGLE, needed)


func set_table_decor_visible(shown: bool) -> void:
	# 接口桩:烛台连同它们的灯一起显示/隐藏(正式实现同上)
	for holder in _table_decor:
		holder.visible = shown
	# 德州灯光补丁(规格 §9;合并时以模型重做分支为准):烛台一藏,桌沿与酒客的脸少了暖色补光,
	# 换一盏桌心上方、不投影、像烛光一样微微起伏的暖光
	var rim := get_node_or_null("TableRimLight") as OmniLight3D
	if rim == null and not shown:
		rim = OmniLight3D.new()
		rim.name = "TableRimLight"
		rim.position = Vector3(0, SeatLayout.TABLE_TOP + 0.35, 0)
		rim.light_color = Color(1.0, 0.74, 0.48)
		rim.light_energy = 0.9
		rim.omni_range = 2.8
		rim.light_volumetric_fog_energy = 0.0
		add_child(rim)
		_flickers.append({"light": rim, "base": rim.light_energy, "speed": 3.0, "depth": 0.08, "seed": 91.0})
	if rim != null:
		rim.visible = not shown


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
	environment.ssao_light_affect = 0.35   # 环境光遮蔽也压暗直射光:墙角、椅脚、压在桌上的手臂才有接触暗部
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
	RoomProps.atmosphere(self, environment)   # 暖色 LUT 与分层体积雾
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)


# —— 房间 ——

func _build_room() -> void:
	RoomShell.build(self)   # 墙地、线脚与木构(src/world/room/)


# —— 牌桌 ——

func _build_table() -> void:
	var table := MeshKit.pivot(self, Vector3.ZERO, "Table")
	_table = table
	var top_y := SeatLayout.TABLE_TOP
	var r := SeatLayout.TABLE_RADIUS
	MeshKit.add(table, MeshKit.cylinder(r, r, 0.06, 64), WorldMaterials.wood("table"), Vector3(0, top_y - 0.03, 0))
	MeshKit.add(table, MeshKit.cylinder(r + 0.02, r - 0.03, 0.05, 64), WorldMaterials.wood("dark"),
		Vector3(0, top_y - 0.075, 0))
	MeshKit.add(table, MeshKit.torus(r - 0.012, r + 0.008, 96), WorldMaterials.brass(), Vector3(0, top_y, 0),
		Vector3.ZERO, Vector3(1, 0.35, 1))
	var felt_thickness := SeatLayout.FELT_TOP - top_y
	var felt := MeshKit.add(table, MeshKit.cylinder(SeatLayout.FELT_RADIUS, SeatLayout.FELT_RADIUS, felt_thickness, 96),
		WorldMaterials.felt(), Vector3(0, top_y + felt_thickness / 2.0, 0))
	felt.name = "Felt"
	felt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	MeshKit.add(table, MeshKit.cylinder(0.09, 0.13, 0.62, 24), WorldMaterials.wood("dark"), Vector3(0, 0.41, 0))
	MeshKit.add(table, MeshKit.cylinder(0.16, 0.16, 0.06, 24), WorldMaterials.brass(), Vector3(0, 0.66, 0))
	MeshKit.add(table, MeshKit.cylinder(0.32, 0.46, 0.08, 32), WorldMaterials.wood("dark"), Vector3(0, 0.04, 0))


# —— 吊灯 ——

func _build_lamp() -> void:
	_lamp_pivot = MeshKit.pivot(self, Vector3(0, ROOM_HEIGHT, 0), "LampPivot")
	MeshKit.add(_lamp_pivot, MeshKit.cylinder(0.006, 0.006, LAMP_DROP, 6), WorldMaterials.iron(),
		Vector3(0, -LAMP_DROP / 2.0, 0))
	var shade_y := -LAMP_DROP - 0.1
	var shade_mesh := MeshKit.cylinder(0.07, 0.36, 0.2, 48, MeshKit.CAPS_TOP)
	MeshKit.add(_lamp_pivot, shade_mesh, WorldMaterials.enamel(Color(0.16, 0.27, 0.19)), Vector3(0, shade_y, 0))
	MeshKit.add(_lamp_pivot, MeshKit.torus(0.355, 0.37, 48), WorldMaterials.brass(), Vector3(0, shade_y - 0.1, 0))
	MeshKit.add(_lamp_pivot, MeshKit.sphere(0.055), WorldMaterials.emissive(Color(1.0, 0.82, 0.55), 4.0),
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
	spot.shadow_caster_mask = MeshKit.LAYER_WORLD   # 窗户层只给月光投影
	spot.shadow_blur = 1.5
	spot.light_volumetric_fog_energy = 2.2
	_lamp_pivot.add_child(spot)
	var fill := OmniLight3D.new()
	fill.position = Vector3(0, shade_y + 0.05, 0)
	fill.light_color = Color(1.0, 0.72, 0.45)
	fill.light_energy = 1.5
	fill.omni_range = 7.5
	fill.light_volumetric_fog_energy = 0.3
	_lamp_pivot.add_child(fill)
	_flickers.append({"light": spot, "base": spot.light_energy, "speed": 0.7, "depth": 0.04, "seed": 3.0})


# —— 烛台 ——

func _build_candles() -> void:
	var top_y := SeatLayout.TABLE_TOP
	# 角度避开各座位的左轮摆放位置(3 人局 240° 座位的枪原本会穿过第二个烛台)
	var specs := [[PI * 0.76, 3, 1.0], [PI * 1.31, 2, 7.0]]
	for k in specs.size():
		var spec: Array = specs[k]
		var base := SeatLayout.direction(spec[0]) * 0.7 + Vector3(0, top_y, 0)
		# 名字以 Candles 开头:性能探针按这个前缀找烛光;两个烛台各自命名,免得重名被自动改名
		var holder := MeshKit.pivot(self, base, "Candles%d" % k)
		_table_decor.append(holder)
		MeshKit.add(holder, MeshKit.cylinder(0.07, 0.08, 0.012, 24), WorldMaterials.brass(), Vector3(0, 0.006, 0))
		var total_height := 0.0
		for i in spec[1]:
			var offset := Vector3(cos(i * 2.1) * 0.035, 0, sin(i * 2.1) * 0.035) if spec[1] > 1 else Vector3.ZERO
			var height: float = 0.07 + 0.045 * ((i * 37 + int(spec[2])) % 3)
			_candle(holder, offset, height, spec[2] + i)
			total_height += height
		# 每个烛台一盏灯(每支一盏会在近处的脸上叠出亮斑):放在烛台中心、平均烛高之上,总亮度按支数折算
		var light := OmniLight3D.new()
		light.position = Vector3(0, 0.012 + total_height / spec[1] + 0.05, 0)
		light.light_color = Color(1.0, 0.74, 0.48)
		light.light_energy = CANDLE_ENERGY * spec[1] * 0.75
		light.omni_range = 2.4
		light.light_volumetric_fog_energy = 0.4
		holder.add_child(light)
		_flickers.append({"light": light, "base": light.light_energy, "speed": 6.0, "depth": 0.35, "seed": spec[2] * 13.0})


func _flame(parent: Node3D, size: Vector2, pos: Vector3, intensity: float, seed: float) -> MeshInstance3D:
	# 火焰公告板:共用一份材质,强度与种子按实例设定
	var flame := MeshKit.add(parent, MeshKit.quad(size), WorldMaterials.flame(), pos)
	flame.set_instance_shader_parameter("intensity", intensity)
	flame.set_instance_shader_parameter("seed", seed)
	return flame


func _candle(parent: Node3D, offset: Vector3, height: float, seed: float) -> void:
	var wax := WorldMaterials.emissive(Color(0.72, 0.672, 0.576), 0.03)   # 蜡色压到 0.72 以下,烛光下不再泛白
	MeshKit.add(parent, MeshKit.cylinder(0.016, 0.018, height, 16), wax, offset + Vector3(0, 0.012 + height / 2.0, 0))
	MeshKit.add(parent, MeshKit.sphere(0.012, 10), wax, offset + Vector3(0.012, 0.012 + height * 0.8, 0),
		Vector3.ZERO, Vector3(0.6, 1.4, 0.6))
	var flame_y := 0.012 + height + 0.026
	_flame(parent, Vector2(0.03, 0.06), offset + Vector3(0, flame_y, 0), 4.0, seed)


# —— 壁炉 ——

func _build_fireplace() -> void:
	_flickers.append_array(FireplaceSet.build(self))   # 石体、台梁、柴、炉具、牛骷髅与炉火(src/world/room/)


# —— 吧台 ——

func _build_bar() -> void:
	BarSet.build(self)   # 台身、后吧、烟熏镜、吧凳、酒瓶与啤酒杯、吧台灯(src/world/room/)


# —— 门窗与陈设 ——

func _build_window() -> void:
	OpeningsSet.build(self)   # 月光窗、窗帘、窗外夜景与月光;前墙弹簧门与街景(src/world/room/)


func _build_sconces() -> void:
	# 墙饰、钢琴、衣帽架、角落杂物、地毯、贴花与黄铜蜡烛壁灯(src/world/room/)
	_flickers.append_array(RoomProps.build(self))


# —— 浮尘 ——

func _build_dust() -> void:
	add_child(Fx.dust_motes(Vector3(0, 1.6, 0), Vector3(1.6, 1.0, 1.6)))
	add_child(Fx.dust_motes(Vector3(2.6, 1.6, -0.6), Vector3(1.6, 0.9, 0.7)))
