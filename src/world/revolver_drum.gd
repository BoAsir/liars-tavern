class_name RevolverDrum
# 左轮转轮的网格,建在转轮枢轴的本地坐标里(绕 Z 转,-Z 朝枪口):
#   mesh       带槽线的外壁 + 开着弹膛口的前脸 + 后脸——投射阴影;
#   trim_mesh  弹膛内壁、后脸的黄铜弹壳底缘、前脸中心的轴套——小件,不投影。
# 膛数跟规则走(Revolver.CHAMBERS),按膛数缓存。第一膛在正上方,正对枪管;槽线在两膛之间。

const RADIUS := 0.0225
const LENGTH := 0.042
const CHAMBER_CIRCLE := 0.013    # = 枪管轴线高度 - 转轮轴高度:正上方那一膛对准枪管
const CHAMBER_RADIUS := 0.0047
const CHAMBER_CHAMFER := 0.0006  # 膛口倒角:黑洞外一圈亮边
const BORE_DEPTH := 0.009
const TOP_DEG := 90.0
const BACK_EDGE := 0.0025        # 后端圆角
const FRONT_EDGE := 0.002        # 前端圆角(略小,像车出来的倒角)
const FACE_OVERLAP := 0.0003     # 前、后脸比外壁端口大一点,盖住接缝
const FLUTE_DEPTH := 0.0019
const FLUTE_HALF_WIDTH := 0.2    # 槽线半宽(占弹膛间距的比例)
const FLUTE_BACK := Vector2(0.0075, 0.0115)    # 槽线后端:从后脸算起开始变深、到全深的距离
const FLUTE_FRONT := Vector2(0.0058, 0.0095)   # 槽线前端:从前脸算起
const FACE_RAYS := 12
const FACE_SHADE := 0.55         # 前脸用抛光钢、压暗到这个比例
const RIM_RADIUS := 0.0058       # 弹壳底缘比弹膛大,凸出后脸
const RIM_PROUD := 0.0012
const BUSHING_PROFILE := [Vector2(0.0042, -0.0002), Vector2(0.0042, 0.0005), Vector2(0.0034, 0.0008), Vector2(0.0, 0.0008)]


static func mesh(chambers: int) -> ArrayMesh:
	return MeshBatch.cached("revolver:drum:%d" % chambers, func(b: MeshBatch) -> void:
		var mat := RevolverModel.material()
		var blued := RevolverModel.tint(RevolverModel.Finish.BLUED)
		b.add_part(_wall(chambers), mat, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, blued)
		var face_radius := RADIUS - FRONT_EDGE + FACE_OVERLAP
		var rays := RevolverShapes.sector_rays(chambers, CHAMBER_CIRCLE, face_radius, FACE_RAYS)
		var face := RevolverShapes.holed_disc(face_radius, chambers, CHAMBER_CIRCLE, CHAMBER_RADIUS + CHAMBER_CHAMFER,
			rays, TOP_DEG)
		# 前脸被火药与擦拭磨得发亮:比外壁亮一截,黑洞洞的膛口在上面才读得出来
		b.add_part(face, mat, Vector3(0, 0, -LENGTH / 2.0), Vector3.ZERO, Vector3.ONE,
			RevolverModel.tint(RevolverModel.Finish.BRIGHT, FACE_SHADE))
		var back := PackedVector2Array([Vector2(0.0, -LENGTH / 2.0), Vector2(RADIUS - BACK_EDGE + FACE_OVERLAP, -LENGTH / 2.0)])
		b.add_part(MeshShapes.lathe(back, 24), mat, Vector3.ZERO, RevolverModel.AXIAL_ROT, Vector3.ONE, blued))


static func trim_mesh(chambers: int) -> ArrayMesh:
	return MeshBatch.cached("revolver:drum_trim:%d" % chambers, func(b: MeshBatch) -> void:
		var mat := RevolverModel.material()
		var face_radius := RADIUS - FRONT_EDGE + FACE_OVERLAP
		var rays := RevolverShapes.sector_rays(chambers, CHAMBER_CIRCLE, face_radius, FACE_RAYS)
		var rim := PackedVector2Array([Vector2(0.0, -LENGTH / 2.0 - RIM_PROUD), Vector2(RIM_RADIUS, -LENGTH / 2.0 - RIM_PROUD),
			Vector2(RIM_RADIUS, -LENGTH / 2.0 + 0.0003)])
		for k in chambers:
			var theta := deg_to_rad(TOP_DEG) + TAU * k / chambers
			var center := Vector2.from_angle(theta) * CHAMBER_CIRCLE
			b.add_part(RevolverShapes.bore(CHAMBER_RADIUS, CHAMBER_CHAMFER, BORE_DEPTH, rays, theta), mat,
				Vector3(center.x, center.y, -LENGTH / 2.0), Vector3.ZERO, Vector3.ONE,
				RevolverModel.tint(RevolverModel.Finish.BORE))
			b.add_part(MeshShapes.lathe(rim, RevolverModel.SMALL_SEGMENTS), mat, Vector3(center.x, center.y, 0),
				RevolverModel.AXIAL_ROT, Vector3.ONE, RevolverModel.tint(RevolverModel.Finish.BRASS))
		var bushing := PackedVector2Array()
		for p in BUSHING_PROFILE:
			bushing.append(p + Vector2(0, LENGTH / 2.0))
		b.add_part(MeshShapes.lathe(bushing, 12), mat, Vector3.ZERO, RevolverModel.AXIAL_ROT, Vector3.ONE,
			RevolverModel.tint(RevolverModel.Finish.BRIGHT)))


static func chamber_mouth(index: int, chambers: int) -> Vector3:
	# 第 index 膛的膛口(转轮本地坐标)。按转轮转动方向的反向编号:扳一次击锤(转轮 +1/膛数 圈),
	# 下一膛转到正上方对准枪管
	var a := deg_to_rad(TOP_DEG) - TAU * index / chambers
	return Vector3(cos(a) * CHAMBER_CIRCLE, sin(a) * CHAMBER_CIRCLE, -LENGTH / 2.0)


static func _wall(chambers: int) -> Array:
	# 外壁剖面 (半径, z):后脸接口 → 后圆角 → 槽线由浅到深再变浅 → 前圆角 → 前脸接口
	var back := LENGTH / 2.0
	var rows := [
		[Vector2(RADIUS - BACK_EDGE, back), 0.0],
		[Vector2(RADIUS - BACK_EDGE * 0.29, back - BACK_EDGE * 0.29), 0.0],
		[Vector2(RADIUS, back - BACK_EDGE), 0.0],
		[Vector2(RADIUS, back - FLUTE_BACK.x), 0.0],
		[Vector2(RADIUS, back - FLUTE_BACK.y), 1.0],
		[Vector2(RADIUS, -back + FLUTE_FRONT.y), 1.0],
		[Vector2(RADIUS, -back + FLUTE_FRONT.x), 0.0],
		[Vector2(RADIUS, -back + FRONT_EDGE), 0.0],
		[Vector2(RADIUS - FRONT_EDGE * 0.29, -back + FRONT_EDGE * 0.29), 0.0],
		[Vector2(RADIUS - FRONT_EDGE, -back), 0.0],
	]
	var profile := PackedVector2Array()
	var depth := PackedFloat32Array()
	for row in rows:
		profile.append(row[0])
		depth.append((row[1] as float) * FLUTE_DEPTH)
	var w := FLUTE_HALF_WIDTH
	var columns := PackedFloat32Array([0.0, 0.5 - w, 0.5 - w / 2.0, 0.5, 0.5 + w / 2.0, 0.5 + w])
	var column_depth := PackedFloat32Array([0.0, 0.0, 0.75, 1.0, 0.75, 0.0])
	return RevolverShapes.fluted_wall(profile, depth, chambers, columns, column_depth, TOP_DEG + 180.0 / chambers)
