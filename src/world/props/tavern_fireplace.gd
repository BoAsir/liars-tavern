class_name TavernFireplace
# 壁炉:后墙正中偏左的石砌壁炉,是对面玩家身后最常入镜的背景。
# 砌体(错缝方石、弓形拱券与拱心石、炉床、炉膛内衬、壁炉台横梁与木托、收分的烟囱)由 FireplaceMasonry 搭;
# 柴架、柴火、炭床由 FireplaceFire 摆;壁炉台上的钟、烛台、陶罐与鹿角由 FireplaceMantel 布置;
# 火钳架、吊壶、柴堆由 FireplaceHearth 布置。这里管根节点、各部件的合批与投影、火苗(各自独立的公告板)、
# 炉火光(带阴影)与火星。
# 本地坐标:原点在后墙内表面、壁炉正中的地面,+Z 朝房间,+X 向右(从牌桌看过去)。


# —— 尺寸(各建模器共用)——
const HALF_WIDTH := 1.05             # 下部炉体灰浆芯的半宽(石面再凸出一点)
const BODY_DEPTH := 0.6              # 下部炉体灰浆芯的正面离墙
const HEARTH_TOP := 0.12             # 抬高的炉床面 = 炉膛地面
const HEARTH_HALF_WIDTH := 1.22
const HEARTH_DEPTH := 0.88           # 炉床前沿离墙(地盘上限 0.9)
const OPENING_HALF_WIDTH := 0.52
const SPRING_HEIGHT := 0.66          # 拱脚
const ARCH_RISE := 0.3               # 弓形拱的拱高
const MANTEL_BOTTOM := 1.38
const MANTEL_HEIGHT := 0.18
const MANTEL_TOP := MANTEL_BOTTOM + MANTEL_HEIGHT
const MANTEL_HALF_WIDTH := 1.18
const MANTEL_BACK := 0.34            # 横梁后半截埋进烟囱
const MANTEL_FRONT := 0.84
const CHIMNEY_DEPTH := 0.46
const CHIMNEY_HALF_WIDTH := Vector2(0.86, 0.62)   # 烟囱在横梁上方、天花板处的半宽(收分)

# 火苗:[底部位置, 高度]。中间高、两边矮,前排两簇小火舌贴着前面那根柴;总数不超过 8(每簇一次绘制)
const FLAMES := [
	[Vector3(0.0, 0.3, 0.27), 0.66], [Vector3(-0.16, 0.29, 0.25), 0.52], [Vector3(0.17, 0.3, 0.29), 0.54],
	[Vector3(-0.3, 0.26, 0.28), 0.36], [Vector3(0.31, 0.27, 0.26), 0.38],
	[Vector3(-0.07, 0.31, 0.39), 0.3], [Vector3(0.09, 0.3, 0.41), 0.28],
]
const FLAME_ASPECT := 0.72           # 公告板宽 / 高
const FLAME_INTENSITY := 3.0
const FLAME_SEED := 20.0
const EMBERS_AT := Vector3(0, 0.34, 0.3)
const LIGHT_AT := Vector3(0, 0.5, 0.75)


static func build(tavern: Tavern) -> void:
	var z := -Tavern.ROOM_HALF + Tavern.WALL_THICKNESS / 2.0
	var fp := MeshKit.pivot(tavern, Vector3(Tavern.FIREPLACE_X, 0, z), "Fireplace")
	# 砌体、横梁、火钳架投影:炉火光被横梁挡住、照不到上面的烟囱,炉体在两侧墙上落下影子
	var masonry := MeshBatch.cached("fireplace:masonry", func(batch: MeshBatch) -> void:
		FireplaceMasonry.add_to(batch)
		FireplaceHearth.add_casters(batch))
	MeshBatch.instance(fp, masonry, {}, "Masonry")
	# 炉膛里的柴火与炭床、台面摆设都不投影:光源在炉口外侧,柴火的影子只会反常地落在炉膛后壁;
	# 台面上的东西本就在横梁的影子里
	var details := MeshBatch.cached("fireplace:details", func(batch: MeshBatch) -> void:
		FireplaceFire.add_to(batch)
		FireplaceMantel.add_to(batch)
		FireplaceHearth.add_details(batch))
	MeshBatch.instance(fp, details, {}, "Details", false)
	_build_flames(fp)
	_build_light(tavern, fp)
	fp.add_child(Fx.embers(EMBERS_AT))


static func arch_radius() -> float:
	# 弓形拱:跨度 2 × OPENING_HALF_WIDTH、拱高 ARCH_RISE 的圆弧半径
	return (OPENING_HALF_WIDTH * OPENING_HALF_WIDTH + ARCH_RISE * ARCH_RISE) / (2.0 * ARCH_RISE)


static func arch_center() -> Vector2:
	return Vector2(0.0, SPRING_HEIGHT + ARCH_RISE - arch_radius())


static func arch_half_angle() -> float:
	# 拱脚处的半角(从竖直方向量起)
	return asin(OPENING_HALF_WIDTH / arch_radius())


static func chimney_half_width(y: float) -> float:
	var t := clampf((y - MANTEL_TOP) / (Tavern.ROOM_HEIGHT - MANTEL_TOP), 0.0, 1.0)
	return lerpf(CHIMNEY_HALF_WIDTH.x, CHIMNEY_HALF_WIDTH.y, t)


static func _build_flames(fp: Node3D) -> void:
	# 火焰着色器是读自身模型矩阵的公告板:每簇单独一个节点,不能合批
	for i in FLAMES.size():
		var base: Vector3 = FLAMES[i][0]
		var height: float = FLAMES[i][1]
		var flame := MeshKit.add(fp, MeshKit.quad(Vector2(height * FLAME_ASPECT, height)),
			WorldMaterials.flame(FLAME_INTENSITY, FLAME_SEED + i), base + Vector3(0, height / 2.0, 0))
		flame.name = "Flame%d" % i


static func _build_light(tavern: Tavern, fp: Node3D) -> void:
	# 参数由灯光调校会话维护(tools/perf_probe.gd 按父节点名 Fireplace 找它),这里原样保留
	var light := OmniLight3D.new()
	light.position = LIGHT_AT
	light.light_color = Color(1.0, 0.56, 0.3)
	light.light_energy = 2.7
	light.omni_range = 7.0
	light.shadow_enabled = true
	light.light_volumetric_fog_energy = 0.6
	fp.add_child(light)
	tavern.add_flicker(light, 3.5, 0.3, 50.0)
