class_name Revolver3D
extends Node3D
# 左轮手枪模型:原点在握把(手持点),枪管沿本地 -Z。转轮可旋转、击锤可扳动、开火有后坐。


const BARREL_LENGTH := 0.15
const DRUM_POS := Vector3(0, 0.045, -0.035)
const MUZZLE_POS := Vector3(0, 0.058, -0.235)
const REST_HALF_WIDTH := 0.026   # 侧放时离桌面的高度:转轮半径 0.025 + 1 mm(槽线外缘也在 0.026)
# 合批:机身 / 转轮 / 击锤各一份共享网格(所有左轮共用);钢、铁、黄铜走顶点 PBR(prop 材质),木握把单独一个 surface
const STEEL := [Color(0.30, 0.31, 0.34), 0.38, 0.70]  # [sRGB 颜色, 粗糙度, 金属度],枪钢:原来太黑,背景又暗,枪读成一团黑
const BRASS := [Color(0.78, 0.56, 0.24), 0.32, 1.0]   # 同 WorldMaterials.brass()
const IRON := [Color(0.09, 0.09, 0.1), 0.55, 0.8]     # 同 WorldMaterials.iron()

var drum: Node3D
var hammer: Node3D
var muzzle: Marker3D


static func forge_jobs() -> Array:
	# 启动时后台预建(材质在主线程先建好)
	return [
		["revolver:body", body_recipe, {&"metal": WorldMaterials.prop(), &"grip": WorldMaterials.wood("grip", true)}],
		["revolver:drum", drum_recipe, {&"metal": WorldMaterials.prop()}],
		["revolver:hammer", hammer_recipe, {&"metal": WorldMaterials.prop()}],
	]


func _init() -> void:
	var body := MeshKit.pivot(self, Vector3.ZERO, "Body")
	MeshKit.add(body, MeshForge.cached("revolver:body", body_recipe,
		{&"metal": WorldMaterials.prop(), &"grip": WorldMaterials.wood("grip", true)}), null).name = "BodyMesh"
	# 转轮:弹膛(与规则的膛数一致)+ 槽线,绕枪管轴旋转
	drum = MeshKit.pivot(body, DRUM_POS, "Drum")
	MeshKit.add(drum, MeshForge.cached("revolver:drum", drum_recipe, {&"metal": WorldMaterials.prop()}), null).name = "DrumMesh"
	for i in Revolver.CHAMBERS:
		var marker := Marker3D.new()
		marker.name = "Chamber%d" % (i + 1)
		marker.position = _chamber_offset(i) + Vector3(0, 0, -0.022)
		drum.add_child(marker)
	# 击锤:绕后端铰点扳动
	hammer = MeshKit.pivot(body, Vector3(0, 0.06, 0.022), "Hammer")
	MeshKit.add(hammer, MeshForge.cached("revolver:hammer", hammer_recipe, {&"metal": WorldMaterials.prop()}), null).name = "HammerMesh"
	muzzle = Marker3D.new()
	muzzle.position = MUZZLE_POS
	add_child(muzzle)


static func _paint(f: MeshForge, m: Array) -> void:
	f.paint(m[0], m[1], m[2])


static func _chamber_offset(i: int) -> Vector3:
	# 第一个弹膛在转轮 12 点位,与枪管同轴
	var a := PI / 2.0 + TAU * i / Revolver.CHAMBERS
	return Vector3(cos(a), sin(a), 0) * 0.0145


static func body_recipe(f: MeshForge) -> void:
	var xf := MeshForge.xf
	# 握把:略后倾的圆角木柄
	f.surface(&"grip")
	f.part_space = true
	f.capsule(0.016, 0.1, 20, xf.call(Vector3(0, -0.02, 0.012), Vector3(-18, 0, 0), Vector3(1, 1, 1.35)))
	f.part_space = false
	f.surface(&"metal")
	_paint(f, STEEL)
	# 底部金属护帽、机匣与顶梁
	f.sphere(0.018, 12, xf.call(Vector3(0, -0.068, 0.028), Vector3.ZERO, Vector3(0.9, 0.5, 1.3)))
	f.box(Vector3(0.026, 0.05, 0.075), xf.call(Vector3(0, 0.04, -0.01)))
	f.box(Vector3(0.02, 0.012, 0.07), xf.call(Vector3(0, 0.074, -0.04)))
	# 枪管 + 下护套
	f.cylinder(0.0085, 0.0085, BARREL_LENGTH, 16, MeshForge.CAPS_BOTH, xf.call(Vector3(0, 0.058, -0.16), Vector3(90, 0, 0)))
	f.box(Vector3(0.012, 0.012, 0.09), xf.call(Vector3(0, 0.046, -0.12)))
	# 扳机护圈
	f.torus(0.016, 0.02, 24, xf.call(Vector3(0, 0.0, -0.022), Vector3(0, 0, 90), Vector3(1, 1.0, 1.25)))
	# 准星、枪口环、扳机
	_paint(f, BRASS)
	f.box(Vector3(0.004, 0.009, 0.008), xf.call(Vector3(0, 0.069, -0.228)))
	f.torus(0.0045, 0.0085, 16, xf.call(MUZZLE_POS + Vector3(0, 0, 0.004), Vector3(90, 0, 0)))
	f.box(Vector3(0.004, 0.022, 0.006), xf.call(Vector3(0, 0.005, -0.02), Vector3(-12, 0, 0)))


static func drum_recipe(f: MeshForge) -> void:
	var xf := MeshForge.xf
	f.surface(&"metal")
	_paint(f, STEEL)
	f.cylinder(0.025, 0.025, 0.046, 24, MeshForge.CAPS_BOTH, xf.call(Vector3.ZERO, Vector3(90, 0, 0)))
	for i in Revolver.CHAMBERS:
		var off := _chamber_offset(i)
		_paint(f, IRON)
		f.cylinder(0.0055, 0.0055, 0.004, 10, MeshForge.CAPS_BOTH, xf.call(off + Vector3(0, 0, -0.022), Vector3(90, 0, 0)))
		_paint(f, BRASS)
		f.cylinder(0.003, 0.003, 0.004, 8, MeshForge.CAPS_BOTH, xf.call(off + Vector3(0, 0, 0.022), Vector3(90, 0, 0)))
		var a := PI / 2.0 + TAU * i / Revolver.CHAMBERS + PI / Revolver.CHAMBERS
		_paint(f, IRON)
		f.box(Vector3(0.004, 0.004, 0.032), xf.call(Vector3(cos(a), sin(a), 0) * 0.024))


static func hammer_recipe(f: MeshForge) -> void:
	var xf := MeshForge.xf
	f.surface(&"metal")
	_paint(f, STEEL)
	f.box(Vector3(0.008, 0.026, 0.01), xf.call(Vector3(0, 0.01, 0.002), Vector3(-25, 0, 0)))
	f.box(Vector3(0.012, 0.005, 0.012), xf.call(Vector3(0, 0.024, 0.01)))


func spin_drum(duration: float, turns := 2.5) -> Tween:
	# 转整数格停下,总有一个弹膛对准枪管(转几格与子弹位置无关,所有弹膛外观一样)
	var step := TAU / Revolver.CHAMBERS
	var target := snappedf(drum.rotation.z, step) + step * roundi(turns * Revolver.CHAMBERS)
	var tween := create_tween()
	tween.tween_property(drum, "rotation:z", target, duration).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	return tween


func cock_hammer(duration := 0.18) -> Tween:
	var tween := create_tween()
	tween.tween_property(hammer, "rotation:x", deg_to_rad(38.0), duration).set_trans(Tween.TRANS_BACK)
	tween.parallel().tween_property(drum, "rotation:z", drum.rotation.z + TAU / Revolver.CHAMBERS, duration)
	return tween


func release_hammer() -> Tween:
	var tween := create_tween()
	tween.tween_property(hammer, "rotation:x", 0.0, 0.04)
	return tween


func recoil() -> Tween:
	# 枪口上跳后回位
	var base := rotation
	var tween := create_tween()
	tween.tween_property(self, "rotation:x", base.x + 0.5, 0.05).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation:x", base.x, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	return tween


func muzzle_transform() -> Transform3D:
	return muzzle.global_transform
