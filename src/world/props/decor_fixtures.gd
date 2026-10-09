class_name DecorFixtures
# 屋里的几件"生活痕迹":门边的衣帽架(车削立柱、四只弯脚、黄铜挂钩,顶上扣一顶牛仔帽,挂着挎包和围巾)、
# 后墙左角木箱上方的鳟鱼标本(椭圆木托、渐变鳞色、背鳍尾鳍、黄铜铭牌)、右后角大梁上倒挂晾干的香草束、
# 木箱上一盏没点的提灯。衣帽架投影(立在地上的高个子),其余进不投影的细节批。


const RACK_AT := Vector3(-3.78, 0.0, 3.94)    # 门洞左侧(从屋里看),离墙角柱、门框都有余地
const RACK_HEIGHT := 1.78
const HOOK_V := 1.6
const RACK_TINT := Color(0.56, 0.46, 0.38)
const POLE := [Vector2(0.0, 0.1), Vector2(0.042, 0.1), Vector2(0.05, 0.13), Vector2(0.03, 0.17), Vector2(0.024, 0.22),
	Vector2(0.022, 1.0), Vector2(0.03, 1.04), Vector2(0.022, 1.08), Vector2(0.02, 1.62), Vector2(0.028, 1.66),
	Vector2(0.02, 1.7), Vector2(0.018, 1.74), Vector2(0.03, 1.76), Vector2(0.03, 1.78), Vector2(0.0, 1.785)]
const HAT := [Vector2(0.0, 0.03), Vector2(0.08, 0.0), Vector2(0.19, 0.0), Vector2(0.2, 0.007), Vector2(0.19, 0.013),
	Vector2(0.09, 0.014), Vector2(0.085, 0.05), Vector2(0.078, 0.1), Vector2(0.06, 0.122), Vector2(0.03, 0.118),
	Vector2(0.0, 0.11)]
const HAT_TINT := Color(0.34, 0.23, 0.15)
const TROPHY := {"x": -3.5, "v": 2.08}
const HERB_BEAM_Z := -3.0
const HERB_X := [3.7, 3.86, 4.02]          # 离右墙不到 0.8 米(相机路线),也让开右墙梁头的托木
const HERB_TINTS := [Color(0.42, 0.46, 0.26), Color(0.5, 0.4, 0.5), Color(0.55, 0.5, 0.3)]
const LANTERN_AT := Vector3(-3.3, 0.38, -4.0)


static func add_to(props: MeshBatch, detail: MeshBatch) -> void:
	_add_coat_rack(props, detail)
	DecorTrophy.add_to(detail, DecorWalls.on_wall(RoomShapes.Wall.BACK,
		RoomShapes.u_of(RoomShapes.Wall.BACK, TROPHY["x"]), TROPHY["v"], 0.0))
	for i in HERB_X.size():
		_add_herbs(detail, Vector3(HERB_X[i], RoomCeiling.BEAM_BOTTOM, HERB_BEAM_Z + (i - 1) * 0.04), HERB_TINTS[i], i)
	_add_lantern(detail, Transform3D(Basis(Vector3.UP, 0.4), LANTERN_AT))


# —— 衣帽架 ——

static func _add_coat_rack(props: MeshBatch, detail: MeshBatch) -> void:
	var timber := RoomMaterials.timber()
	var xf := Transform3D(Basis(), RACK_AT)
	props.add_arrays(MeshShapes.lathe(PackedVector2Array(POLE), 12), timber, xf, RoomShapes.tint(RACK_TINT, RoomShapes.GRAIN_Y))
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var out := Vector3(cos(a), 0, sin(a))
		var foot := PackedVector3Array([Vector3(0, 0.15, 0) + out * 0.02, out * 0.14 + Vector3(0, 0.09, 0),
			out * 0.24 + Vector3(0, 0.03, 0), out * 0.27 + Vector3(0, 0.018, 0)])
		props.add_arrays(MeshShapes.tube(foot, PackedFloat32Array([0.022, 0.018, 0.015, 0.016]), 8), timber, xf,
			RoomShapes.tint(RACK_TINT, RoomShapes.GRAIN_Z))
	var brass := WorldMaterials.brass()
	for k in 4:
		var a := TAU * k / 4.0
		var out := Vector3(cos(a), 0, sin(a))
		var hook := PackedVector3Array([Vector3(0, HOOK_V, 0), out * 0.07 + Vector3(0, HOOK_V - 0.02, 0),
			out * 0.12 + Vector3(0, HOOK_V + 0.01, 0), out * 0.13 + Vector3(0, HOOK_V + 0.05, 0)])
		detail.add_arrays(MeshShapes.tube(hook, 0.006, 6), brass, xf)
		detail.add(MeshKit.sphere(0.011, 8), brass, xf * Transform3D(Basis(), out * 0.13 + Vector3(0, HOOK_V + 0.055, 0)))
	_add_hat(props, xf * MeshBatch.xform_of(Vector3(0.01, RACK_HEIGHT - 0.035, 0), Vector3(-8, 30, 6)))
	_add_satchel(detail, xf, Vector3(0, 0, -0.12))
	_add_scarf(detail, xf * MeshBatch.xform_of(Vector3(-0.12, HOOK_V + 0.02, 0), Vector3(0, 0, 0)))


static func _add_hat(props: MeshBatch, xf: Transform3D) -> void:
	# 牛仔帽:回转体再把帽檐两侧往上卷、帽顶前后捏出凹痕;一圈深色帽带
	var hat := MeshShapes.deform(MeshShapes.lathe(PackedVector2Array(HAT), 20), func(v: Vector3) -> Vector3:
		var side := maxf(absf(v.x) - 0.09, 0.0)
		var front := maxf(absf(v.z) - 0.09, 0.0)
		var dent := 0.025 * maxf(0.0, 1.0 - absf(v.x) / 0.05) * smoothstep(0.08, 0.12, v.y)
		return Vector3(v.x, v.y + side * side * 3.5 - front * front * 0.8 - dent, v.z))
	props.add_arrays(hat, DecorMaterials.matte(), xf, HAT_TINT)
	var band := MeshShapes.lathe(PackedVector2Array([Vector2(0.0915, 0.016), Vector2(0.089, 0.036)]), 20)
	props.add_arrays(band, DecorMaterials.matte(), xf, Color(0.12, 0.08, 0.06))


static func _add_satchel(detail: MeshBatch, rack: Transform3D, hook_out: Vector3) -> void:
	# 挎包:皮背带搭在挂钩上,包身垂在立柱侧面(带翻盖与黄铜扣)
	var leather := Color(0.42, 0.24, 0.13)
	var top := hook_out + Vector3(0, HOOK_V + 0.03, 0)
	var bag_at := hook_out * 1.25 + Vector3(0, HOOK_V - 0.42, 0)
	var strap := PackedVector3Array([bag_at + Vector3(-0.1, 0.1, 0), top + Vector3(-0.01, 0, 0), bag_at + Vector3(0.1, 0.1, 0)])
	detail.add_arrays(MeshShapes.tube(strap, 0.008, 5), DecorMaterials.matte(), rack, leather * 0.8)
	var body := MeshShapes.rounded_box(Vector3(0.26, 0.2, 0.08), 0.03, 2)
	var bag_xf := rack * Transform3D(Basis(), bag_at)
	detail.add_arrays(body, DecorMaterials.matte(), bag_xf, leather)
	var outward := hook_out.normalized()
	var flap := MeshShapes.rounded_box(Vector3(0.262, 0.12, 0.012), 0.006, 1)
	var flap_xf := bag_xf * Transform3D(Basis(Vector3.UP, atan2(outward.x, outward.z)), Vector3.ZERO)
	detail.add_arrays(flap, DecorMaterials.matte(), flap_xf * Transform3D(Basis(), Vector3(0, 0.045, 0.042)), leather * 0.85)
	detail.add(MeshKit.box(Vector3(0.03, 0.024, 0.008)), WorldMaterials.brass(), flap_xf * Transform3D(Basis(), Vector3(0, -0.01, 0.05)))


static func _add_scarf(detail: MeshBatch, xf: Transform3D) -> void:
	# 围巾:侧面是一个倒 U(搭在钩上的两条垂尾,一长一短),沿 Z 拉出宽度
	var outline := PackedVector2Array([Vector2(-0.03, -0.55), Vector2(-0.018, -0.55), Vector2(-0.016, -0.1),
		Vector2(-0.008, -0.01), Vector2(0.008, -0.01), Vector2(0.016, -0.1), Vector2(0.02, -0.4), Vector2(0.032, -0.4),
		Vector2(0.03, -0.1), Vector2(0.018, 0.008), Vector2(0.0, 0.016), Vector2(-0.018, 0.008), Vector2(-0.03, -0.1)])
	var scarf := MeshShapes.extrude(outline, 0.15, 0.004)
	detail.add_arrays(scarf, DecorMaterials.matte(), xf * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3.ZERO),
		Color(0.5, 0.14, 0.12))


# —— 香草束 ——

static func _add_herbs(detail: MeshBatch, hang: Vector3, tint: Color, seed: int) -> void:
	# 一根麻绳从梁底垂下,扎住一把倒挂的枝叶:几条细长的叶簇向下散开
	var top := hang + Vector3(0, -0.14 - seed * 0.03, 0)
	detail.add_arrays(MeshShapes.tube(PackedVector3Array([hang, top]), 0.003, 4), DecorMaterials.matte(), Transform3D.IDENTITY,
		DecorStorage.TWINE_TINT)
	detail.add(MeshKit.cylinder(0.016, 0.016, 0.03, 8), DecorMaterials.matte(), Transform3D(Basis(), top + Vector3(0, -0.015, 0)),
		DecorStorage.TWINE_TINT)
	var sprig := MeshKit.sphere(1.0, 6)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77 + seed
	for k in 7:
		var a := TAU * k / 7.0 + rng.randf_range(-0.3, 0.3)
		var spread := rng.randf_range(10.0, 22.0)
		var length := rng.randf_range(0.11, 0.16)
		var basis := Basis(Vector3.UP, a) * Basis(Vector3.BACK, deg_to_rad(spread))
		var center := top + Vector3(0, -0.03, 0) + basis * Vector3(0, -length, 0)
		var shade := tint * rng.randf_range(0.8, 1.1)
		detail.add(sprig, DecorMaterials.matte(), Transform3D(basis * Basis.from_scale(Vector3(0.028, length, 0.02)), center), shade)


# —— 提灯 ——

static func _add_lantern(detail: MeshBatch, xf: Transform3D) -> void:
	# 没点的铁皮提灯:圆底座、四根立柱夹着烟熏的玻璃、尖顶、提环
	var iron := WorldMaterials.iron()
	detail.add_arrays(MeshShapes.lathe(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.075, 0.0), Vector2(0.075, 0.02),
		Vector2(0.06, 0.03), Vector2(0.0, 0.03)]), 12), iron, xf)
	detail.add_arrays(MeshShapes.lathe(PackedVector2Array([Vector2(0.0, 0.03), Vector2(0.05, 0.03), Vector2(0.05, 0.2),
		Vector2(0.0, 0.2)]), 8), DecorMaterials.glazed(), xf, Color(0.16, 0.13, 0.09))
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var p := Vector3(cos(a), 0, sin(a)) * 0.055
		detail.add_arrays(MeshShapes.tube(PackedVector3Array([p + Vector3(0, 0.02, 0), p + Vector3(0, 0.21, 0)]), 0.006, 5),
			iron, xf)
	detail.add_arrays(MeshShapes.lathe(PackedVector2Array([Vector2(0.0, 0.2), Vector2(0.072, 0.2), Vector2(0.07, 0.215),
		Vector2(0.02, 0.27), Vector2(0.012, 0.29), Vector2(0.0, 0.29)]), 12), iron, xf)
	var ring := MeshKit.torus(0.03, 0.038, 10)
	ring.ring_segments = 5
	detail.add(ring, iron, xf * MeshBatch.xform_of(Vector3(0, 0.32, 0), Vector3(90, 0, 0)))
