class_name Revolver3D
extends Node3D
# 左轮手枪模型:原点在握把(手持点),枪管沿本地 -Z。转轮可旋转、击锤可扳动、开火有后坐。


const BARREL_LENGTH := 0.15
const DRUM_POS := Vector3(0, 0.045, -0.035)
const MUZZLE_POS := Vector3(0, 0.058, -0.235)

var drum: Node3D
var hammer: Node3D
var muzzle: Marker3D


func _init() -> void:
	var steel := WorldMaterials.gunmetal()
	var brass := WorldMaterials.brass()
	var wood := WorldMaterials.wood("grip")
	var body := MeshKit.pivot(self, Vector3.ZERO, "Body")
	# 握把:略后倾的圆角木柄 + 底部金属护帽
	MeshKit.add(body, MeshKit.capsule(0.016, 0.1), wood, Vector3(0, -0.02, 0.012), Vector3(-18, 0, 0), Vector3(1, 1, 1.35))
	MeshKit.add(body, MeshKit.sphere(0.018, 12), steel, Vector3(0, -0.068, 0.028), Vector3.ZERO, Vector3(0.9, 0.5, 1.3))
	# 机匣与顶梁
	MeshKit.add(body, MeshKit.box(Vector3(0.026, 0.05, 0.075)), steel, Vector3(0, 0.04, -0.01))
	MeshKit.add(body, MeshKit.box(Vector3(0.02, 0.012, 0.07)), steel, Vector3(0, 0.074, -0.04))
	# 枪管 + 下护套 + 准星
	MeshKit.add(body, MeshKit.cylinder(0.0085, 0.0085, BARREL_LENGTH, 16), steel,
		Vector3(0, 0.058, -0.16), Vector3(90, 0, 0))
	MeshKit.add(body, MeshKit.box(Vector3(0.012, 0.012, 0.09)), steel, Vector3(0, 0.046, -0.12))
	MeshKit.add(body, MeshKit.box(Vector3(0.004, 0.009, 0.008)), brass, Vector3(0, 0.069, -0.228))
	MeshKit.add(body, MeshKit.torus(0.0045, 0.0085, 16), brass, MUZZLE_POS + Vector3(0, 0, 0.004), Vector3(90, 0, 0))
	# 扳机护圈与扳机
	MeshKit.add(body, MeshKit.torus(0.016, 0.02, 24), steel, Vector3(0, 0.0, -0.022), Vector3(0, 0, 90),
		Vector3(1, 1.0, 1.25))
	MeshKit.add(body, MeshKit.box(Vector3(0.004, 0.022, 0.006)), brass, Vector3(0, 0.005, -0.02), Vector3(-12, 0, 0))
	# 转轮:弹膛孔(与规则的膛数一致)+ 槽线,绕枪管轴旋转
	drum = MeshKit.pivot(body, DRUM_POS, "Drum")
	MeshKit.add(drum, MeshKit.cylinder(0.025, 0.025, 0.046, 24), steel, Vector3.ZERO, Vector3(90, 0, 0))
	for i in Revolver.CHAMBERS:
		var a := TAU * i / Revolver.CHAMBERS
		var off := Vector3(cos(a), sin(a), 0) * 0.0145
		MeshKit.add(drum, MeshKit.cylinder(0.0055, 0.0055, 0.004, 10), WorldMaterials.iron(),
			off + Vector3(0, 0, -0.022), Vector3(90, 0, 0)).name = "Chamber%d" % (i + 1)
		MeshKit.add(drum, MeshKit.cylinder(0.003, 0.003, 0.004, 8), brass, off + Vector3(0, 0, 0.022), Vector3(90, 0, 0))
		var flute := Vector3(cos(a + PI / Revolver.CHAMBERS), sin(a + PI / Revolver.CHAMBERS), 0) * 0.024
		MeshKit.add(drum, MeshKit.box(Vector3(0.004, 0.004, 0.032)), WorldMaterials.iron(), flute)
	# 击锤:绕后端铰点扳动
	hammer = MeshKit.pivot(body, Vector3(0, 0.06, 0.022), "Hammer")
	MeshKit.add(hammer, MeshKit.box(Vector3(0.008, 0.026, 0.01)), steel, Vector3(0, 0.01, 0.002), Vector3(-25, 0, 0))
	MeshKit.add(hammer, MeshKit.box(Vector3(0.012, 0.005, 0.012)), steel, Vector3(0, 0.024, 0.01))
	muzzle = Marker3D.new()
	muzzle.position = MUZZLE_POS
	add_child(muzzle)


func spin_drum(duration: float, turns := 2.5) -> Tween:
	var tween := create_tween()
	tween.tween_property(drum, "rotation:z", drum.rotation.z + TAU * turns, duration) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
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
