class_name Revolver3D
extends Node3D
# 左轮手枪模型:原点在握把(手持点),枪管沿本地 -Z。转轮可旋转、击锤可扳动、开火有后坐。
# 网格由 RevolverModel(枪身、小件、击锤)与 RevolverDrum(转轮)拼装并缓存:四把枪、每局重建都
# 共用同一份网格与材质,对局中只新建节点。只有枪身和转轮投射阴影,小件、击锤不投影。


const BARREL_LENGTH := 0.15
const DRUM_POS := Vector3(0, 0.045, -0.035)
const MUZZLE_POS := Vector3(0, 0.058, -0.235)
const HAMMER_POS := Vector3(0, 0.06, 0.022)
const HAMMER_COCKED_DEG := 38.0
# 右侧朝上平放在桌上时,原点(握把)离桌面的高度:转轮最宽,枪靠它贴着桌面;
# 多出的一点是桌布与压边的厚度,枪不会陷进桌布里
const LYING_HEIGHT := RevolverDrum.RADIUS + 0.0045

var drum: Node3D
var hammer: Node3D
var muzzle: Marker3D


func _init() -> void:
	var body := MeshKit.pivot(self, Vector3.ZERO, "Body")
	MeshBatch.instance(body, RevolverModel.frame_mesh(), {}, "Frame")
	MeshBatch.instance(body, RevolverModel.trim_mesh(), {}, "Trim", false)
	# 转轮:绕本地 Z 转;每膛一个标记点(膛口位置),膛数与规则一致
	drum = MeshKit.pivot(body, DRUM_POS, "Drum")
	MeshBatch.instance(drum, RevolverDrum.mesh(Revolver.CHAMBERS), {}, "Cylinder")
	MeshBatch.instance(drum, RevolverDrum.trim_mesh(Revolver.CHAMBERS), {}, "CylinderTrim", false)
	for i in Revolver.CHAMBERS:
		var mouth := Marker3D.new()
		mouth.name = "Chamber%d" % (i + 1)
		mouth.position = RevolverDrum.chamber_mouth(i, Revolver.CHAMBERS)
		drum.add_child(mouth)
	# 击锤:绕后端铰点扳动
	hammer = MeshKit.pivot(body, HAMMER_POS, "Hammer")
	MeshBatch.instance(hammer, RevolverModel.hammer_mesh(), {}, "HammerMesh", false)
	muzzle = Marker3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = MUZZLE_POS
	add_child(muzzle)


func spin_drum(duration: float, turns := 2.5) -> Tween:
	var tween := create_tween()
	tween.tween_property(drum, "rotation:z", drum.rotation.z + TAU * turns, duration) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	return tween


func cock_hammer(duration := 0.18) -> Tween:
	# 扳起击锤的同时转轮转过一膛
	var tween := create_tween()
	tween.tween_property(hammer, "rotation:x", deg_to_rad(HAMMER_COCKED_DEG), duration).set_trans(Tween.TRANS_BACK)
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
