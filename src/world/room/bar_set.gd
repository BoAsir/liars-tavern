class_name BarSet
# 吧台:客人侧框芯面板的台身(踢脚板退进 4 cm)、圆鼻台面、黄铜脚踏与支架、痰盂;台上酒头、收银机、烈酒杯、雪茄盒;
# 4 只共享网格的吧凳;后吧(下柜、柜面、壁柱、带托架的搁板、檐口)、烟熏镜与「骗子酒馆」招牌;
# 搁板上的酒瓶(Bottles,种子 2026)与台面上 4 只啤酒杯(一个 MultiMesh,沿用同一个随机数序列)。
# Bar 枢轴、酒瓶与杯子的位置和改造前一致。


const PIVOT := Vector3(-RoomLayout.INNER, 0.0, -0.6)
# 粉彩玻璃色(动森式):薄荷绿、琥珀、柔红、奶白、天蓝
const BOTTLE_COLORS := [Color(0.30, 0.58, 0.36), Color(0.82, 0.52, 0.18), Color(0.78, 0.28, 0.28),
	Color(0.86, 0.86, 0.80), Color(0.30, 0.45, 0.78)]
const GRAIN_ALONG_Y := Basis(Vector3.BACK, PI / 2.0)
const SIGN_X := -3.8875   # 招牌底板中心(贴在檐口前缘 x −3.90 上)


static func build(tavern: Node3D) -> Node3D:
	var bar := MeshKit.pivot(tavern, PIVOT, "Bar")
	RoomKit.add(bar, "Body", "bar:body", _body_recipe, {&"panel": WorldMaterials.wood("wainscot", true),
		&"top": WorldMaterials.wood("table", true), &"dark": WorldMaterials.wood("dark", true)}, MeshKit.LAYER_WORLD, true)
	RoomKit.add(bar, "BackBarFrame", "bar:frame", _frame_recipe, {&"main": WorldMaterials.wood("dark", true)},
		MeshKit.LAYER_SCENERY, false)
	RoomKit.add(bar, "Brass", "bar:brass", _brass_recipe, {&"main": WorldMaterials.prop()}, MeshKit.LAYER_SCENERY, false)
	RoomKit.add(bar, "Counter", "bar:counter", _counter_recipe, {&"main": WorldMaterials.prop()}, MeshKit.LAYER_SCENERY, false)
	RoomKit.add(bar, "MirrorSign", "bar:mirror", _mirror_recipe, {&"main": WorldMaterials.decor()}, MeshKit.LAYER_SCENERY, false)
	var stool := stool_mesh()
	for i in RoomLayout.STOOL_Z.size():
		var inst := MeshKit.add(bar, stool, null, Vector3(RoomLayout.STOOL_X, 0.0, RoomLayout.STOOL_Z[i]) - PIVOT,
			Vector3(0, i * 37.0, 0), Vector3.ONE, MeshKit.SHADOW_ON)
		inst.name = "Stool%d" % i
	_bottles_and_mugs(bar)
	var light := OmniLight3D.new()
	light.position = Vector3(0.9, 2.5, 0)
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 1.1
	light.omni_range = 3.8
	bar.add_child(light)
	return bar


static func _world(f: MeshForge) -> void:
	f.push(Transform3D(Basis.IDENTITY, -PIVOT))


# —— 酒瓶与啤酒杯(随机数的取用顺序不能变)——

static func shelf_layout() -> Dictionary:
	# 酒瓶与啤酒杯的摆放(Bar 枢轴局部坐标):{"bottles": [{pos, height, color}], "mugs": [杯底位置]}。
	# 随机数的取用顺序不能变:先 53 个酒瓶,再 4 只杯子,和改造前同一个 rng(种子 2026)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var bottles := []
	for shelf in 3:
		var y := 1.55 + shelf * 0.45
		var z := -1.35
		while z < 1.35:
			var h := rng.randf_range(Bottles.MIN_HEIGHT, Bottles.MAX_HEIGHT)
			var color: Color = BOTTLE_COLORS[rng.randi() % BOTTLE_COLORS.size()]
			bottles.append({"pos": Vector3(0.22, y + 0.02, z), "height": h, "color": color})
			z += rng.randf_range(0.1, 0.2)
	var mugs := []
	for i in 4:
		mugs.append(Vector3(1.05 + rng.randf_range(-0.15, 0.15), 1.11, -1.2 + i * 0.7 + rng.randf_range(-0.1, 0.1)))
	return {"bottles": bottles, "mugs": mugs}


static func _bottles_and_mugs(bar: Node3D) -> void:
	var layout := shelf_layout()
	Bottles.build(bar, layout["bottles"])
	var mugs := MultiMesh.new()
	mugs.transform_format = MultiMesh.TRANSFORM_3D
	mugs.mesh = mug_mesh()
	mugs.instance_count = layout["mugs"].size()
	for i in mugs.instance_count:
		mugs.set_instance_transform(i, Transform3D(Basis(Vector3.UP, i * 0.9 - 0.4), layout["mugs"][i]))
	var holder := MeshKit.pivot(bar, Vector3.ZERO, "BarTop")
	var inst := MultiMeshInstance3D.new()
	inst.name = "Mugs"
	inst.multimesh = mugs
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holder.add_child(inst)


static func mug_mesh() -> ArrayMesh:
	# 木桶状啤酒杯:车削杯身 + 两道铁箍 + 泡沫顶(不发光)+ 把手
	return MeshForge.cached("bar:mug", func(f: MeshForge):
		RoomKit.paint(f, [Color(0.64, 0.42, 0.24), 0.65, 0.0])
		f.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.043, 0.0), Vector2(0.046, 0.06), Vector2(0.044, 0.12),
			Vector2(0.038, 0.12), Vector2(0.038, 0.11), Vector2(0.0, 0.11)]), 14, PackedInt32Array([1, 3, 4]))
		RoomKit.paint(f, RoomKit.IRON)
		for y in [0.022, 0.098]:
			f.torus(0.044, 0.05, 14, MeshForge.xf(Vector3(0, y, 0), Vector3.ZERO, Vector3(1, 0.5, 1)))
		RoomKit.paint(f, RoomKit.FOAM)
		f.lathe(PackedVector2Array([Vector2(0.0, 0.112), Vector2(0.04, 0.112), Vector2(0.037, 0.128), Vector2(0.02, 0.136),
			Vector2(0.0, 0.137)]), 12)
		RoomKit.paint(f, RoomKit.IRON)
		f.torus(0.022, 0.032, 12, MeshForge.xf(Vector3(0.05, 0.062, 0), Vector3(90, 0, 0), Vector3(1, 1.2, 1))),
		{&"main": WorldMaterials.prop()})


static func stool_mesh() -> ArrayMesh:
	# 吧凳(也给钢琴凳用):圆鼓鼓的木座面 + 胖软垫、四条外撇的粗腿、黄铜脚圈(动森式:矮胖圆润)
	return MeshForge.cached("stool", func(f: MeshForge):
		f.surface(&"wood")
		f.part_space = true
		f.paint(Color.WHITE, 0.7)
		f.seed = 1.0
		# 座面:圆角车削盘(上下沿各一道 1.5 cm 圆角)
		var seat := PackedVector2Array([Vector2(0.0, 0.695), Vector2(0.15, 0.695)])
		for k in range(1, 4):
			var a := -PI / 2.0 + PI / 2.0 * k / 3.0
			seat.append(Vector2(0.155, 0.71) + Vector2(cos(a), sin(a)) * 0.015)
		for k in range(1, 4):
			var a := PI / 2.0 * k / 3.0
			seat.append(Vector2(0.155, 0.73) + Vector2(cos(a), sin(a)) * 0.015)
		seat.append(Vector2(0.0, 0.745))
		f.lathe(seat, 20)
		f.part_basis = GRAIN_ALONG_Y
		for k in 4:
			var a := PI / 4.0 + k * PI / 2.0
			var top := Vector3(cos(a), 0, sin(a)) * 0.095 + Vector3(0, 0.70, 0)
			var foot := Vector3(cos(a), 0, sin(a)) * 0.165
			var d := top - foot
			var basis := Basis(Quaternion(Vector3.UP, d.normalized()))
			f.seed = 2.0 + k
			f.cylinder(0.024, 0.03, d.length(), 10, MeshForge.CAPS_BOTH, Transform3D(basis, (top + foot) / 2.0))
			f.sphere(0.03, 10, MeshForge.xf(foot + Vector3(0, 0.012, 0), Vector3.ZERO, Vector3(1, 0.5, 1)))   # 圆脚
		f.part_basis = Basis.IDENTITY
		f.part_space = false
		f.surface(&"prop")
		# 胖软垫:柔红,顶面鼓起
		RoomKit.paint(f, RoomKit.RED_PAINT)
		var cushion := PackedVector2Array([Vector2(0.0, 0.742), Vector2(0.13, 0.742)])
		for k in range(1, 7):
			var a := -PI / 2.0 + PI * 0.75 * k / 6.0
			cushion.append(Vector2(0.13, 0.765) + Vector2(cos(a), sin(a)) * Vector2(0.025, 0.023))
		cushion.append_array([Vector2(0.08, 0.792), Vector2(0.0, 0.796)])
		f.lathe(cushion, 20)
		RoomKit.paint(f, RoomKit.BRASS)
		f.torus(0.124, 0.146, 24, MeshForge.xf(Vector3(0, 0.28, 0), Vector3.ZERO, Vector3(1, 1.3, 1))),
		{&"wood": WorldMaterials.wood("dark", true), &"prop": WorldMaterials.prop()})


# —— 台身 ——

static func _body_recipe(f: MeshForge) -> void:
	_world(f)
	var x0 := RoomLayout.BAR_X.x
	var x1 := RoomLayout.BAR_X.y
	var z0 := RoomLayout.BAR_Z.x
	var z1 := RoomLayout.BAR_Z.y
	var top := RoomLayout.BAR_TOP_Y
	var kick := 0.10
	# 客人侧面板:u 沿 z(拉伸成整数块面板),v = 离地高度
	f.surface(&"panel")
	f.part_space = true
	f.paint(Color.WHITE, 0.66)
	var length := z1 - z0
	var stretch := 0.62 / RoomLayout.panel_fit(length, 0.62)
	f.part_basis = Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(stretch, 0, 0))
	f.part_origin = Vector3(stretch * length / 2.0, (top + kick) / 2.0, 0.0)
	f.seed = 5.0
	RoomKit.rounded_box(f, Vector3(x1 - x0, top - kick, length), 0.04,
		MeshForge.xf(Vector3((x0 + x1) / 2.0, (top + kick) / 2.0, (z0 + z1) / 2.0)))
	# 两端:u 沿 x
	var depth := x1 - x0
	var stretch_end := 0.62 / RoomLayout.panel_fit(depth, 0.62)
	f.part_basis = Basis.from_scale(Vector3(stretch_end, 1, 1))
	f.part_origin = Vector3(stretch_end * depth / 2.0, (top + kick) / 2.0, 0.0)
	for z in [z0 - 0.006, z1 + 0.006]:
		f.seed = 6.0 + z
		f.box(Vector3(depth, top - kick, 0.012), MeshForge.xf(Vector3((x0 + x1) / 2.0, (top + kick) / 2.0, z)))
	# 后吧下柜:面朝 +x,u 沿 z
	var bz0 := RoomLayout.BACKBAR_Z.x
	var bz1 := RoomLayout.BACKBAR_Z.y
	var blen := bz1 - bz0
	var bstretch := 0.62 / RoomLayout.panel_fit(blen, 0.62)
	f.part_basis = Basis(Vector3(0, 0, -1), Vector3(0, 1, 0), Vector3(bstretch, 0, 0))
	f.part_origin = Vector3(bstretch * blen / 2.0, 0.46 + 0.1, 0.0)
	f.seed = 7.0
	RoomKit.rounded_box(f, Vector3(RoomLayout.INNER + RoomLayout.BACKBAR_FRONT, 0.82, blen), 0.035,
		MeshForge.xf(Vector3((-RoomLayout.INNER + RoomLayout.BACKBAR_FRONT) / 2.0, 0.51, (bz0 + bz1) / 2.0)))
	f.part_basis = Basis.IDENTITY
	f.part_origin = Vector3.ZERO
	# 台面:客人侧 3 cm 圆鼻;后吧柜面
	f.surface(&"top")
	f.paint(Color.WHITE, 0.55)
	f.seed = 8.0
	var nose := PackedVector2Array([Vector2(0.74, top), Vector2(0.74, top + 0.06), Vector2(0.03, top + 0.06)])
	for k in range(1, 10):
		var a := PI / 2.0 + k * PI / 10.0
		nose.append(Vector2(0.03, top + 0.03) + Vector2(cos(a), sin(a)) * 0.03)
	nose.append(Vector2(0.03, top))
	var along_z := Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0))
	f.part_basis = Basis.IDENTITY
	RoomKit.extrude_smooth(f, nose, 3.52, Transform3D(along_z, Vector3(-2.96, 0.0, (-2.36 + 1.16) / 2.0)))
	f.seed = 9.0
	RoomKit.extrude_smooth(f, RoomKit.round_rect(0.47, 0.03, 0.014), blen + 0.02,
		Transform3D(along_z, Vector3((-RoomLayout.INNER + RoomLayout.BACKBAR_FRONT + 0.02) / 2.0, 0.935, (bz0 + bz1) / 2.0)))
	# 踢脚板(退进 4 cm)与下柜踢脚
	f.surface(&"dark")
	f.paint(Color.WHITE, 0.72)
	f.seed = 10.0
	f.box(Vector3(x1 - 0.04 - x0, kick, length - 0.08), MeshForge.xf(Vector3((x0 + x1 - 0.04) / 2.0, kick / 2.0, (z0 + z1) / 2.0)))
	f.box(Vector3(0.43, 0.1, blen), MeshForge.xf(Vector3(RoomLayout.BACKBAR_FRONT - 0.215 - 0.02, 0.05, (bz0 + bz1) / 2.0)))
	f.part_space = false


static func _frame_recipe(f: MeshForge) -> void:
	# 后吧框架:壁柱、带托架的搁板、檐口、招牌底板
	_world(f)
	f.part_space = true
	f.paint(Color.WHITE, 0.72)
	var up := Basis(Vector3(0, 1, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1))
	for z in [-2.20, 1.00]:
		f.seed = 20.0 + z
		RoomKit.extrude_smooth(f, RoomKit.round_rect(0.12, 0.1, 0.035), 2.62 - 0.95,
			Transform3D(up, Vector3(-RoomLayout.INNER + 0.05, (0.95 + 2.62) / 2.0, z)))
	for shelf in 3:
		var y := 1.55 + shelf * 0.45
		f.seed = 30.0 + shelf
		RoomKit.rounded_box(f, Vector3(0.3, 0.04, 3.0), 0.016, MeshForge.xf(Vector3(-4.18, y, -0.6)))
		f.box(Vector3(0.012, 0.02, 3.0), MeshForge.xf(Vector3(-4.035, y + 0.03, -0.6)))
		# 托架
		for z in [-1.8, -0.6, 0.6]:
			f.extrude_x(PackedVector2Array([Vector2(0.0, y - 0.02), Vector2(0.24, y - 0.02), Vector2(0.22, y - 0.05), Vector2(0.0, y - 0.16)]),
				0.03, RoomShell.wall_frame("left", z))
	# 檐口(冠顶)
	var cornice := PackedVector2Array([Vector2(0.0, 2.62), Vector2(0.43, 2.62)])
	for k in range(1, 5):   # 下沿四分之一圆(卡通的圆润檐口)
		var a := -PI / 2.0 + PI / 2.0 * k / 4.0
		cornice.append(Vector2(0.43, 2.64) + Vector2(cos(a), sin(a)) * 0.02)
	cornice.append(Vector2(0.45, 2.72))
	for k in range(0, 5):
		var a := -PI / 2.0 + PI / 2.0 * k / 4.0
		cornice.append(Vector2(0.475, 2.765) + Vector2(cos(a), sin(a)) * 0.025)
	cornice.append_array([Vector2(0.50, 2.815)])
	for k in range(1, 5):
		var a := PI / 2.0 * k / 4.0
		cornice.append(Vector2(0.475, 2.815) + Vector2(cos(a), sin(a)) * 0.025)
	cornice.append(Vector2(0.0, 2.84))
	f.seed = 40.0
	RoomKit.extrude_smooth(f, cornice, RoomLayout.BACKBAR_Z.y - RoomLayout.BACKBAR_Z.x + 0.08,
		RoomShell.wall_frame("left", (RoomLayout.BACKBAR_Z.x + RoomLayout.BACKBAR_Z.y) / 2.0))
	# 招牌底板
	f.seed = 41.0
	RoomKit.rounded_box(f, Vector3(0.025, 0.29, 2.48), 0.012, MeshForge.xf(Vector3(SIGN_X, 2.785, -0.6)))
	f.part_space = false


static func _brass_recipe(f: MeshForge) -> void:
	# 黄铜脚踏(4 个 L 形支架)与两只痰盂
	_world(f)
	RoomKit.paint(f, RoomKit.BRASS)
	var rail := PackedVector3Array([Vector3(-2.88, 0.20, -2.20), Vector3(-2.88, 0.20, 1.00)])
	f.tube(rail, 0.022, 12)
	for z in [-2.0, -0.9, 0.0, 0.85]:
		f.box(Vector3(0.2, 0.02, 0.03), MeshForge.xf(Vector3(-2.98, 0.20, z)))
		f.box(Vector3(0.02, 0.2, 0.03), MeshForge.xf(Vector3(-3.07, 0.11, z)))
	for z in [-1.5, 0.1]:
		RoomKit.paint(f, RoomKit.OLD_BRASS)
		f.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.07, 0.0), Vector2(0.105, 0.05), Vector2(0.095, 0.1),
			Vector2(0.06, 0.12), Vector2(0.085, 0.145), Vector2(0.075, 0.148), Vector2(0.045, 0.125), Vector2(0.0, 0.12)]), 16,
			PackedInt32Array([1, 4, 5, 6]), MeshForge.xf(Vector3(-2.80, 0.0, z)))


static func _counter_recipe(f: MeshForge) -> void:
	# 台上:酒头塔、收银机、烈酒杯、雪茄盒、服务铃
	_world(f)
	var top := RoomLayout.BAR_TOP_Y + 0.06
	# 酒头:底座、立柱、横梁上 3 个龙头与手柄
	var tx := -3.45
	var tz := 0.45
	RoomKit.paint(f, RoomKit.BRASS)
	f.cylinder(0.06, 0.07, 0.02, 16, MeshForge.CAPS_BOTH, MeshForge.xf(Vector3(tx, top + 0.01, tz)))
	f.cylinder(0.022, 0.026, 0.26, 12, MeshForge.CAPS_BOTH, MeshForge.xf(Vector3(tx, top + 0.15, tz)))
	f.cylinder(0.02, 0.02, 0.28, 12, MeshForge.CAPS_BOTH, MeshForge.xf(Vector3(tx, top + 0.27, tz), Vector3(90, 0, 0)))
	for k in 3:
		var z := tz - 0.1 + k * 0.1
		RoomKit.paint(f, RoomKit.BRASS)
		f.cylinder(0.008, 0.01, 0.06, 8, MeshForge.CAPS_BOTH, MeshForge.xf(Vector3(tx + 0.035, top + 0.24, z), Vector3(0, 0, 70)))
		RoomKit.paint(f, RoomKit.BLACK if k != 1 else RoomKit.CREAM)
		f.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.009, 0.0), Vector2(0.014, 0.07), Vector2(0.011, 0.1), Vector2(0.0, 0.105)]),
			8, PackedInt32Array(), MeshForge.xf(Vector3(tx, top + 0.285, z), Vector3(0, 0, -8)))
	# 收银机:主体、斜面键盘、顶上的金额窗、侧摇把
	var r := Vector3(-3.42, top, -1.75)
	RoomKit.paint(f, [Color(0.66, 0.50, 0.30), 0.55, 0.45])   # 收银机用暗一点的缎面青铜:吧台灯就在上方,亮黄铜会糊成一块发光的方块
	f.box(Vector3(0.3, 0.18, 0.34), MeshForge.xf(r + Vector3(0, 0.09, 0)))
	f.extrude_x(PackedVector2Array([Vector2(-0.15, 0.0), Vector2(0.15, 0.0), Vector2(0.15, 0.05), Vector2(-0.05, 0.14), Vector2(-0.15, 0.14)]),
		0.32, Transform3D(Basis(Vector3(0, 0, 1), Vector3.UP, Vector3(-1, 0, 0)), r + Vector3(0, 0.18, 0)))
	f.box(Vector3(0.12, 0.08, 0.26), MeshForge.xf(r + Vector3(-0.07, 0.36, 0)))
	RoomKit.paint(f, RoomKit.CREAM)
	f.box(Vector3(0.004, 0.05, 0.2), MeshForge.xf(r + Vector3(-0.008, 0.36, 0)))
	RoomKit.paint(f, RoomKit.BLACK)
	for row in 3:
		for col in 5:
			f.cylinder(0.009, 0.009, 0.01, 8, MeshForge.CAPS_BOTH, MeshForge.xf(r + Vector3(0.10 - row * 0.065, 0.215 + row * 0.03, -0.12 + col * 0.06), Vector3(0, 0, 66)))
	RoomKit.paint(f, RoomKit.OLD_BRASS)
	f.cylinder(0.008, 0.008, 0.16, 8, MeshForge.CAPS_BOTH, MeshForge.xf(r + Vector3(0, 0.12, 0.25), Vector3(90, 0, 0)))
	f.sphere(0.02, 10, MeshForge.xf(r + Vector3(0, 0.12, 0.33)))
	# 烈酒杯 5 只(深色厚玻璃)
	RoomKit.paint(f, RoomKit.GLASS_DARK)
	for k in 5:
		var p := Vector3(-3.25 + (k % 2) * 0.07, top, -0.95 + k * 0.08)
		f.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.022, 0.0), Vector2(0.026, 0.06), Vector2(0.023, 0.06),
			Vector2(0.019, 0.012), Vector2(0.0, 0.012)]), 10, PackedInt32Array([1, 2, 3]), MeshForge.xf(p))
	RoomKit.paint(f, RoomKit.BEER)
	f.cylinder(0.019, 0.017, 0.03, 10, MeshForge.CAPS_TOP, MeshForge.xf(Vector3(-3.25, top + 0.028, -0.95)))
	# 雪茄盒
	RoomKit.paint(f, [Color(0.66, 0.38, 0.24), 0.6, 0.0])
	f.box(Vector3(0.14, 0.05, 0.22), MeshForge.xf(Vector3(-3.5, top + 0.025, -0.35), Vector3(0, 8, 0)))
	RoomKit.paint(f, RoomKit.CREAM)
	f.box(Vector3(0.1, 0.003, 0.08), MeshForge.xf(Vector3(-3.5, top + 0.051, -0.35), Vector3(0, 8, 0)))
	# 服务铃
	RoomKit.paint(f, RoomKit.BRASS)
	f.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.04, 0.0), Vector2(0.04, 0.008), Vector2(0.034, 0.012),
		Vector2(0.03, 0.04), Vector2(0.012, 0.055), Vector2(0.006, 0.07), Vector2(0.0, 0.072)]), 14, PackedInt32Array([1, 2, 3]),
		MeshForge.xf(Vector3(-3.2, top, 0.85)))


static func _mirror_recipe(f: MeshForge) -> void:
	# 烟熏镜(UV = 镜面局部米制坐标,v 自下而上)与「骗子酒馆」招牌
	_world(f)
	var size := RoomLayout.MIRROR_SIZE
	var face := Basis(Vector3(0, 0, -1), Vector3.UP, Vector3(1, 0, 0))   # 朝 +x(屋里)
	RoomKit.decor_paint(f, 2, 0.0)
	f.quad(size, Rect2(0, size.y, size.x, -size.y),
		Transform3D(face, Vector3(-RoomLayout.INNER + 0.01, 0.95 + size.y / 2.0, (-2.14 + 0.94) / 2.0)))
	RoomKit.decor_paint(f, 0, 0.0, Color(1, 1, 1), 1.0)
	f.quad(Vector2(2.4, 0.25), DecorAtlas.rect("sign_tavern"),
		Transform3D(face, Vector3(SIGN_X + 0.0125 + RoomLayout.FLAT_OFFSET, 2.785, -0.6)))
