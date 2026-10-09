class_name DecorTrophy
# 鳟鱼标本:椭圆木托上一条拱着身子、张着嘴的大鳟鱼。鱼身是压扁的回转体再弯成弧形,
# 鳞色按顶点从橄榄绿的背、粉色的侧线渐变到银白的肚皮(烘进顶点色,不用贴图);
# 背鳍、尾鳍、胸鳍是薄薄的拉伸片,眼睛是黑亮的小球,木托下沿钉一块黄铜铭牌。
# xf:木托背面中心,局部 +Z 朝屋里、+X 沿墙。


const PLAQUE := Vector2(0.78, 0.34)
const PLAQUE_DEPTH := 0.028
const PLAQUE_TINT := Color(0.42, 0.32, 0.26)
const BODY_LENGTH := 0.6
const BODY := [Vector2(0.0, 0.0), Vector2(0.03, 0.012), Vector2(0.062, 0.05), Vector2(0.078, 0.12), Vector2(0.08, 0.2),
	Vector2(0.072, 0.3), Vector2(0.055, 0.4), Vector2(0.034, 0.48), Vector2(0.022, 0.54), Vector2(0.02, 0.58),
	Vector2(0.0, 0.6)]
const FLATTEN := 0.5                       # 鱼身厚度方向压扁
const ARCH := 0.06                         # 身子往上拱的高度
const BACK_COLOR := Color(0.24, 0.3, 0.16)
const STRIPE_COLOR := Color(0.72, 0.42, 0.4)
const BELLY_COLOR := Color(0.85, 0.83, 0.76)
const FIN_TINT := Color(0.5, 0.36, 0.3)


static func add_to(detail: MeshBatch, xf: Transform3D) -> void:
	_add_plaque(detail, xf)
	var fish_xf := xf * Transform3D(Basis(), Vector3(0, 0.0, PLAQUE_DEPTH + 0.045))
	detail.add_arrays(body(), DecorMaterials.glazed(), fish_xf)
	_add_fins(detail, fish_xf)
	var eye_at := Vector3(-BODY_LENGTH / 2.0 + 0.07, 0.022, 0.03)
	detail.add(MeshKit.sphere(0.013, 10), DecorMaterials.glazed(), fish_xf * Transform3D(Basis(), eye_at), Color(0.9, 0.82, 0.5))
	detail.add(MeshKit.sphere(0.009, 8), DecorMaterials.glazed(), fish_xf * Transform3D(Basis(), eye_at + Vector3(-0.002, 0, 0.006)),
		Color(0.02, 0.02, 0.02))


static func _add_plaque(detail: MeshBatch, xf: Transform3D) -> void:
	var outline := PackedVector2Array()
	for k in 28:
		var a := TAU * k / 28.0
		outline.append(Vector2(cos(a) * PLAQUE.x / 2.0, sin(a) * PLAQUE.y / 2.0))
	var plaque := MeshShapes.extrude(outline, PLAQUE_DEPTH, 0.01)
	detail.add_arrays(plaque, RoomMaterials.timber(), xf * Transform3D(Basis(), Vector3(0, 0, PLAQUE_DEPTH / 2.0)),
		RoomShapes.tint(PLAQUE_TINT, RoomShapes.GRAIN_X))
	var plate := MeshShapes.rounded_box(Vector3(0.14, 0.04, 0.004), 0.002, 1)
	detail.add_arrays(plate, WorldMaterials.brass(), xf * Transform3D(Basis(), Vector3(0, -PLAQUE.y / 2.0 + 0.045, PLAQUE_DEPTH + 0.002)))


static func body() -> Array:
	# 回转体轴(局部 Y)转成沿 X 的鱼身(绕 Z 转 90°,不镜像,绕序不变):头在 -X;压扁、拱背,再按高度烘鳞色
	var arrays := MeshShapes.lathe(PackedVector2Array(BODY), 16)
	arrays = MeshShapes.deform(arrays, func(v: Vector3) -> Vector3:
		var t := v.y / BODY_LENGTH
		var along := v.y - BODY_LENGTH / 2.0
		var arch := ARCH * (1.0 - pow(t * 2.0 - 1.0, 2.0))
		return Vector3(along, -v.x + arch, v.z * FLATTEN))
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var colors := PackedColorArray()
	for v in verts:
		var t := v.x / BODY_LENGTH + 0.5
		var h := (v.y - ARCH * (1.0 - pow(t * 2.0 - 1.0, 2.0))) / 0.08
		var col := BELLY_COLOR.lerp(STRIPE_COLOR, smoothstep(-0.5, 0.0, h))
		col = col.lerp(BACK_COLOR, smoothstep(0.05, 0.5, h))
		colors.append(col)
	arrays[Mesh.ARRAY_COLOR] = colors
	return arrays


static func _add_fins(detail: MeshBatch, xf: Transform3D) -> void:
	var half := BODY_LENGTH / 2.0
	# 尾鳍:燕尾形,贴在尾柄末端
	var tail := MeshShapes.extrude(PackedVector2Array([Vector2(0.0, -0.015), Vector2(0.09, -0.085), Vector2(0.075, -0.02),
		Vector2(0.065, 0.0), Vector2(0.075, 0.02), Vector2(0.09, 0.085), Vector2(0.0, 0.015)]), 0.008, 0.002)
	detail.add_arrays(tail, DecorMaterials.matte(), xf * Transform3D(Basis(), Vector3(half - 0.03, 0.0, 0.0)), FIN_TINT)
	var dorsal := MeshShapes.extrude(PackedVector2Array([Vector2(-0.07, 0.0), Vector2(-0.04, 0.07), Vector2(0.03, 0.05),
		Vector2(0.04, 0.0)]), 0.006, 0.002)
	detail.add_arrays(dorsal, DecorMaterials.matte(), xf * Transform3D(Basis(), Vector3(-0.02, 0.07 + ARCH * 0.9, 0.0)),
		FIN_TINT)
	var small := MeshShapes.extrude(PackedVector2Array([Vector2(-0.03, 0.0), Vector2(0.04, -0.035), Vector2(0.03, 0.0)]),
		0.005, 0.0015)
	for spec in [[Vector3(-0.12, -0.035, 0.03), 0.4], [Vector3(0.08, -0.05, 0.0), 0.0], [Vector3(0.16, -0.04, 0.0), 0.0]]:
		detail.add_arrays(small, DecorMaterials.matte(), xf * Transform3D(Basis(Vector3.UP, spec[1]), spec[0] + Vector3(0, ARCH * 0.5, 0)),
			FIN_TINT)
	# 张开的嘴:头端一道深色的口缝
	var mouth := MeshShapes.rounded_box(Vector3(0.03, 0.006, 0.042), 0.003, 1)
	detail.add_arrays(mouth, DecorMaterials.matte(), xf * MeshBatch.xform_of(Vector3(-half + 0.03, -0.008, 0), Vector3(0, 0, -12)),
		Color(0.12, 0.06, 0.05))
