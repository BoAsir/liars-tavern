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
	_build_barrels()
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
	# 德州放大 / 骗子酒馆复原:桌面、包边、铜嵌条与毡面按半径换网格(桌高、桌柱与腿不变),吊灯聚光跟着放宽
	TableProp.set_radius(_table, radius)
	LampProp.fit_spot(_lamp_pivot, radius)


func set_table_decor_visible(shown: bool) -> void:
	# 烛台连同它们的灯一起显示 / 隐藏;藏起来时留一盏桌沿暖光
	CandlesProp.set_decor_visible(self, _table_decor, shown, _flickers)


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
	var world_env := WorldEnvironment.new()
	world_env.environment = environment
	add_child(world_env)


# —— 房间 ——

func _build_room() -> void:
	var room := MeshKit.pivot(self, Vector3.ZERO, "Room")
	var size := ROOM_HALF * 2.0
	MeshKit.add(room, MeshKit.plane(Vector2(size, size)), WorldMaterials.wood("floor"), Vector3.ZERO, Vector3.ZERO,
		Vector3.ONE, MeshKit.SHADOW_OFF).name = "Floor"
	var ceiling := MeshKit.add(room, MeshKit.plane(Vector2(size, size)), WorldMaterials.wood("beam"),
		Vector3(0, ROOM_HEIGHT, 0), Vector3(180, 0, 0))
	ceiling.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for z in [-3.0, -1.5, 0.0, 1.5, 3.0]:
		MeshKit.add(room, MeshKit.box(Vector3(size, 0.24, 0.22)), WorldMaterials.wood("beam"),
			Vector3(0, ROOM_HEIGHT - 0.12, z))
	# 后墙(壁炉)与前墙(门)、左墙(吧台)完整;右墙为窗户开洞
	_wall(room, Vector3(0, 0, -ROOM_HALF), Vector3(size, 0, WALL_THICKNESS), "wall", 0.0, ROOM_HEIGHT, "WallBack")
	_wall(room, Vector3(0, 0, ROOM_HALF), Vector3(size, 0, WALL_THICKNESS), "wall", 0.0, ROOM_HEIGHT, "WallFront")
	_wall(room, Vector3(-ROOM_HALF, 0, 0), Vector3(WALL_THICKNESS, 0, size), "wall_side", 0.0, ROOM_HEIGHT, "WallLeft")
	_window_wall(room)


func _wall(parent: Node3D, base: Vector3, extent: Vector3, wood_preset: String,
		bottom := 0.0, top := ROOM_HEIGHT, name_prefix := "Wall", casts_panels := false,
		layers := MeshKit.LAYER_WORLD) -> void:
	# 下半截木护墙板 + 上半截灰泥,外加一道压条。实墙的护墙板与灰泥不投影(房间壳挡不住任何灯照到的东西),
	# 压条照常投影;窗墙要投影,月光柱才保持窗形
	var panel_shadow := MeshKit.SHADOW_ON if casts_panels else MeshKit.SHADOW_OFF
	var low_top := minf(WAINSCOT_HEIGHT, top)
	if low_top > bottom:
		var h := low_top - bottom
		var panel := MeshKit.add(parent, MeshKit.box(Vector3(extent.x, h, extent.z)), WorldMaterials.wood(wood_preset),
			base + Vector3(0, bottom + h / 2.0, 0), Vector3.ZERO, Vector3.ONE, panel_shadow)
		panel.name = name_prefix + "Wainscot"
		panel.layers = layers
	var high_bottom := maxf(WAINSCOT_HEIGHT, bottom)
	if top > high_bottom:
		var h2 := top - high_bottom
		var plaster := MeshKit.add(parent, MeshKit.box(Vector3(extent.x, h2, extent.z)), WorldMaterials.stone("plaster"),
			base + Vector3(0, high_bottom + h2 / 2.0, 0), Vector3.ZERO, Vector3.ONE, panel_shadow)
		plaster.name = name_prefix + "Plaster"
		plaster.layers = layers
	if bottom < WAINSCOT_HEIGHT and top > WAINSCOT_HEIGHT:
		var rail := Vector3(maxf(extent.x, 0.06) + 0.04, 0.06, maxf(extent.z, 0.06) + 0.04)
		var strip := MeshKit.add(parent, MeshKit.box(rail), WorldMaterials.wood("dark"), base + Vector3(0, WAINSCOT_HEIGHT, 0))
		strip.name = name_prefix + "Rail"
		strip.layers = layers


func _window_wall(room: Node3D) -> void:
	var x := ROOM_HALF
	var z0 := WINDOW_Z - WINDOW_SIZE.x / 2.0
	var z1 := WINDOW_Z + WINDOW_SIZE.x / 2.0
	var top := WINDOW_BOTTOM + WINDOW_SIZE.y
	var front_len := ROOM_HALF - z1
	var back_len := z0 + ROOM_HALF
	_wall(room, Vector3(x, 0, z1 + front_len / 2.0), Vector3(WALL_THICKNESS, 0, front_len), "wall_side",
		0.0, ROOM_HEIGHT, "WindowWall0", true, MeshKit.LAYER_MOON)
	_wall(room, Vector3(x, 0, z0 - back_len / 2.0), Vector3(WALL_THICKNESS, 0, back_len), "wall_side",
		0.0, ROOM_HEIGHT, "WindowWall1", true, MeshKit.LAYER_MOON)
	_wall(room, Vector3(x, 0, WINDOW_Z), Vector3(WALL_THICKNESS, 0, WINDOW_SIZE.x), "wall_side",
		0.0, WINDOW_BOTTOM, "WindowWall2", true, MeshKit.LAYER_MOON)
	_wall(room, Vector3(x, 0, WINDOW_Z), Vector3(WALL_THICKNESS, 0, WINDOW_SIZE.x), "wall_side",
		top, ROOM_HEIGHT, "WindowWall3", true, MeshKit.LAYER_MOON)


# —— 牌桌 ——

func _build_table() -> void:
	_table = TableProp.build(self)


# —— 吊灯 ——

func _build_lamp() -> void:
	_lamp_pivot = LampProp.build(self, ROOM_HEIGHT, _flickers)


# —— 烛台 ——

func _build_candles() -> void:
	_table_decor = CandlesProp.build(self, _flickers)


func _flame(parent: Node3D, size: Vector2, pos: Vector3, intensity: float, seed: float) -> MeshInstance3D:
	# 火焰公告板:共用一份材质,强度与种子按实例设定
	var flame := MeshKit.add(parent, MeshKit.quad(size), WorldMaterials.flame(), pos)
	flame.set_instance_shader_parameter("intensity", intensity)
	flame.set_instance_shader_parameter("seed", seed)
	return flame


# —— 壁炉 ——

func _build_fireplace() -> void:
	var z := -ROOM_HALF + WALL_THICKNESS / 2.0
	var fp := MeshKit.pivot(self, Vector3(FIREPLACE_X, 0, z), "Fireplace")
	var stone := WorldMaterials.stone("fireplace")
	MeshKit.add(fp, MeshKit.box(Vector3(0.42, 1.0, 0.5)), stone, Vector3(-0.78, 0.5, 0.25))
	MeshKit.add(fp, MeshKit.box(Vector3(0.42, 1.0, 0.5)), stone, Vector3(0.78, 0.5, 0.25))
	MeshKit.add(fp, MeshKit.box(Vector3(1.98, 0.45, 0.55)), stone, Vector3(0, 1.22, 0.27))
	MeshKit.add(fp, MeshKit.box(Vector3(2.2, 0.08, 0.68)), WorldMaterials.wood("dark"), Vector3(0, 1.48, 0.3))
	MeshKit.add(fp, MeshKit.box(Vector3(1.2, 1.0, 0.1)), WorldMaterials.iron(), Vector3(0, 0.5, 0.05))
	MeshKit.add(fp, MeshKit.box(Vector3(1.4, 1.9, 0.42)), stone, Vector3(0, 2.47, 0.2))
	MeshKit.add(fp, MeshKit.box(Vector3(0.95, 0.04, 0.45)), WorldMaterials.iron(), Vector3(0, 0.02, 0.28))
	for i in 3:
		MeshKit.add(fp, MeshKit.cylinder(0.055, 0.06, 0.62, 12), WorldMaterials.wood("log"),
			Vector3(-0.08 + i * 0.08, 0.1 + (i % 2) * 0.07, 0.3), Vector3(90, 0, 70 + i * 22))
	MeshKit.add(fp, MeshKit.sphere(0.2, 16), WorldMaterials.emissive(Color(1.0, 0.32, 0.06), 4.0),
		Vector3(0, 0.05, 0.3), Vector3.ZERO, Vector3(1.6, 0.25, 0.8))
	for i in 6:
		var h := 0.36 + 0.14 * ((i * 7) % 3)
		_flame(fp, Vector2(h * 0.75, h), Vector3(-0.3 + i * 0.12, 0.08 + h / 2.0, 0.32 + (i % 2) * 0.04), 3.0, 20.0 + i)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.5, 0.75)
	light.light_color = Color(1.0, 0.56, 0.3)
	light.light_energy = 2.7
	light.omni_range = 7.0
	light.shadow_enabled = true
	light.shadow_caster_mask = MeshKit.LAYER_WORLD
	light.light_volumetric_fog_energy = 0.6
	fp.add_child(light)
	_flickers.append({"light": light, "base": light.light_energy, "speed": 3.5, "depth": 0.3, "seed": 50.0})
	fp.add_child(Fx.embers(Vector3(0, 0.3, 0.3)))


# —— 吧台 ——

func _build_bar() -> void:
	var x := -ROOM_HALF + WALL_THICKNESS / 2.0
	var bar := MeshKit.pivot(self, Vector3(x, 0, -0.6), "Bar")
	MeshKit.add(bar, MeshKit.box(Vector3(0.62, 1.05, 3.4)), WorldMaterials.wood("wall_side"), Vector3(1.05, 0.525, 0))
	MeshKit.add(bar, MeshKit.box(Vector3(0.74, 0.06, 3.5)), WorldMaterials.wood("table"), Vector3(1.05, 1.08, 0))
	MeshKit.add(bar, MeshKit.cylinder(0.018, 0.018, 3.3, 12), WorldMaterials.brass(), Vector3(1.46, 0.2, 0),
		Vector3(90, 0, 0))
	for z in [-1.4, 0.0, 1.4]:
		MeshKit.add(bar, MeshKit.box(Vector3(0.12, 0.025, 0.025)), WorldMaterials.brass(), Vector3(1.4, 0.2, z))
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var bottle_colors := [Color(0.15, 0.35, 0.12), Color(0.55, 0.3, 0.05), Color(0.45, 0.05, 0.05),
		Color(0.75, 0.75, 0.7), Color(0.1, 0.15, 0.35)]
	var bottles := []
	for shelf in 3:
		var y := 1.55 + shelf * 0.45
		MeshKit.add(bar, MeshKit.box(Vector3(0.3, 0.04, 3.0)), WorldMaterials.wood("dark"), Vector3(0.22, y, 0))
		var z := -1.35
		while z < 1.35:
			# 随机数的取用顺序不能变:后面啤酒杯的位置也取自同一个 rng
			var h := rng.randf_range(Bottles.MIN_HEIGHT, Bottles.MAX_HEIGHT)
			var color: Color = bottle_colors[rng.randi() % bottle_colors.size()]
			bottles.append({"pos": Vector3(0.22, y + 0.02, z), "height": h, "color": color})
			z += rng.randf_range(0.1, 0.2)
	Bottles.build(bar, bottles)
	for i in 4:
		_mug(bar, Vector3(1.05 + rng.randf_range(-0.15, 0.15), 1.11, -1.2 + i * 0.7 + rng.randf_range(-0.1, 0.1)))
	var light := OmniLight3D.new()
	light.position = Vector3(0.9, 2.5, 0)
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 1.4
	light.omni_range = 3.8
	bar.add_child(light)


func _mug(parent: Node3D, base: Vector3) -> void:
	MeshKit.add(parent, MeshKit.cylinder(0.045, 0.042, 0.12, 16), WorldMaterials.wood("barrel"), base + Vector3(0, 0.06, 0))
	MeshKit.add(parent, MeshKit.cylinder(0.04, 0.04, 0.005, 16), WorldMaterials.beer(), base + Vector3(0, 0.118, 0))
	MeshKit.add(parent, MeshKit.torus(0.025, 0.035, 12), WorldMaterials.iron(), base + Vector3(0.05, 0.06, 0),
		Vector3(90, 0, 0))


# —— 月光窗 ——

func _build_window() -> void:
	var x := ROOM_HALF - WALL_THICKNESS / 2.0
	var center := Vector3(x, WINDOW_BOTTOM + WINDOW_SIZE.y / 2.0, WINDOW_Z)
	var frame := MeshKit.pivot(self, center, "Window")
	var wood := WorldMaterials.wood("dark")
	var w := WINDOW_SIZE.x
	var h := WINDOW_SIZE.y
	MeshKit.add(frame, MeshKit.box(Vector3(0.26, 0.08, w + 0.16)), wood, Vector3(0, -h / 2.0, 0))
	MeshKit.add(frame, MeshKit.box(Vector3(0.24, 0.08, w + 0.16)), wood, Vector3(0, h / 2.0, 0))
	MeshKit.add(frame, MeshKit.box(Vector3(0.24, h, 0.08)), wood, Vector3(0, 0, -w / 2.0))
	MeshKit.add(frame, MeshKit.box(Vector3(0.24, h, 0.08)), wood, Vector3(0, 0, w / 2.0))
	MeshKit.add(frame, MeshKit.box(Vector3(0.06, h, 0.04)), wood, Vector3(0, 0, 0))
	MeshKit.add(frame, MeshKit.box(Vector3(0.06, 0.04, w)), wood, Vector3(0, 0.1, 0))
	var pane := WorldMaterials.glass(Color(0.35, 0.45, 0.7))
	var pane_inst := MeshKit.add(frame, MeshKit.box(Vector3(0.01, h, w)), pane, Vector3(0.02, 0, 0))
	pane_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for part in frame.get_children():
		part.layers = MeshKit.LAYER_MOON
	# 月光从窗外斜射进屋:体积雾里形成一道冷色光柱,窗棂投下影子。只有窗框和窗墙给月光投影:
	# 酒客、牌桌的月光影子几乎看不见,却占去一整轮阴影 pass
	var moon := SpotLight3D.new()
	moon.name = "Moon"
	moon.light_color = Color(0.5, 0.62, 1.0)
	moon.light_energy = 3.0
	moon.spot_range = 9.0
	moon.spot_angle = 24.0
	moon.shadow_enabled = true
	moon.shadow_caster_mask = MeshKit.LAYER_MOON
	moon.light_volumetric_fog_energy = 2.5
	add_child(moon)
	moon.look_at_from_position(center + Vector3(2.2, 1.5, 0.6), Vector3(0.5, 0.2, -0.6))


# —— 木桶 ——

func _build_barrels() -> void:
	var spots := [Vector3(3.7, 0, -3.6), Vector3(3.1, 0, -3.9), Vector3(3.85, 0, -2.9)]
	for i in spots.size():
		var barrel := MeshKit.pivot(self, spots[i], "Barrel")
		barrel.rotation.y = i * 1.3
		MeshKit.add(barrel, MeshKit.cylinder(0.27, 0.27, 0.8, 24), WorldMaterials.wood("barrel"), Vector3(0, 0.4, 0),
			Vector3.ZERO, Vector3(1, 1, 1))
		MeshKit.add(barrel, MeshKit.cylinder(0.3, 0.3, 0.5, 24), WorldMaterials.wood("barrel"), Vector3(0, 0.4, 0))
		for y in [0.12, 0.68]:
			MeshKit.add(barrel, MeshKit.torus(0.275, 0.3, 32), WorldMaterials.iron(), Vector3(0, y, 0),
				Vector3.ZERO, Vector3(1, 0.6, 1))
	MeshKit.add(self, MeshKit.cylinder(0.27, 0.27, 0.8, 24), WorldMaterials.wood("barrel"),
		Vector3(3.4, 0.27, -3.0), Vector3(90, 30, 0))


# —— 壁灯 ——

func _build_sconces() -> void:
	for i in SCONCES.size():
		_sconce(SCONCES[i][0], SCONCES[i][1], 60.0 + i)


func _sconce(wall_point: Vector3, yaw: float, seed: float) -> void:
	# 本地 -Z 指向房间内:黄铜底板 + 弯臂 + 玻璃灯罩里的一簇火苗
	var root := MeshKit.pivot(self, wall_point, "Sconce")
	root.rotation.y = yaw
	MeshKit.add(root, MeshKit.box(Vector3(0.1, 0.22, 0.02)), WorldMaterials.brass(), Vector3(0, 0, -0.01))
	MeshKit.add(root, MeshKit.cylinder(0.008, 0.008, 0.14, 8), WorldMaterials.brass(), Vector3(0, -0.04, -0.08),
		Vector3(90, 0, 0))
	MeshKit.add(root, MeshKit.cylinder(0.04, 0.022, 0.035, 16), WorldMaterials.brass(), Vector3(0, -0.03, -0.15))
	MeshKit.add(root, MeshKit.cylinder(0.032, 0.036, 0.12, 16), WorldMaterials.glass(Color(1.0, 0.92, 0.8)),
		Vector3(0, 0.045, -0.15))
	_flame(root, Vector2(0.035, 0.07), Vector3(0, 0.03, -0.15), 3.5, seed)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 0.05, -0.2)
	light.light_color = Color(1.0, 0.74, 0.48)
	light.light_energy = 1.0
	light.omni_range = 4.6
	light.light_volumetric_fog_energy = 0.5
	root.add_child(light)
	_flickers.append({"light": light, "base": light.light_energy, "speed": 4.0, "depth": 0.12, "seed": seed})


# —— 浮尘 ——

func _build_dust() -> void:
	add_child(Fx.dust_motes(Vector3(0, 1.6, 0), Vector3(1.6, 1.0, 1.6)))
	add_child(Fx.dust_motes(Vector3(2.6, 1.6, -0.6), Vector3(1.6, 0.9, 0.7)))
