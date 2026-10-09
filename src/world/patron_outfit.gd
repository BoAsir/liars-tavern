class_name PatronOutfit
# 酒客服装上的小件(身体坐标,贴着 PatronTorso 的曲面摆放):衬衫领、领结/领带/波洛领绳、扣子、
# 胸袋方巾、怀表链、胸花。全部返回 Mesh.ARRAY_* 数组(顶点色带槽位),由 PatronParts 合进身体的细节批次(不投影)。


const NECK_Z := PatronTorso.NECK_Z
const COLLAR_Y := 0.576         # 衬衫领圈高度
const COLLAR_RING := 0.089      # 衬衫领圈半径(贴着脖子)
const COLLAR_GAP := 0.34        # 衬衫领前面开口的半角
const KNOT := Vector3(0, 0.553, -0.103)   # 领结/领带结的位置
const BUTTON_RADIUS := 0.0085
const VEST_BUTTONS := [0.335, 0.27, 0.205, 0.14]
const VEST_BUTTON_A := 0.012    # 马甲扣子钉在左片压过中线的那一窄条上
const POCKET := Vector2(-0.6, 0.405)      # 胸袋(角度, 高度):左胸
const CHAIN_END := Vector2(0.6, 0.19)     # 怀表链另一端(右侧马甲口袋)
const CHAIN_SAG := 0.045
const FLOWER_Y := 0.465
const SEAM_POINTS := 14
const SEAM_RANGE := Vector2(-0.02, 0.56)     # 后背中缝从下摆到领下(高度)
const SEAM_RADIUS := 0.0022
const VENT_TOP := 0.13                        # 开衩的顶
const VENT_OFFSET := 0.07                     # 开衩的另一道边离中缝的角度


static func build(spec: Dictionary, torso: PatronTorso) -> Array:
	# 返回 [arrays, ...]
	var outfit: Dictionary = spec.get("outfit", {})
	var parts := [shirt_collar()]
	match outfit.get("neckwear", "bow"):
		"bow":
			parts.append_array(bow_tie())
		"tie":
			parts.append_array(necktie(torso))
		"bolo":
			parts.append_array(bolo(torso))
	parts.append(_button(torso.frame(0.0, PatronTorso.BUTTON_Y - 0.006, 0.002), BUTTON_RADIUS * 1.25, PatronSkin.BRASS))
	if outfit.get("vest", true):
		for y in VEST_BUTTONS:
			var depth := PatronTorso.VEST_DEPTH + 0.0015 + 0.0015
			parts.append(_button(torso.frame(VEST_BUTTON_A, y, depth), BUTTON_RADIUS, PatronSkin.BRASS))
	if outfit.get("pocket_square", false):
		parts.append_array(pocket_square(torso))
	if outfit.get("watch_chain", false):
		parts.append(watch_chain(torso))
	if outfit.get("flower", false):
		parts.append_array(flower(torso, outfit.get("lapel", "shawl") == "notch"))
	parts.append(back_seam(torso))
	return parts


# —— 领子与领饰 ——

static func shirt_collar() -> Array:
	# 衬衫立领:绕脖子一圈(后面略高),前面开口处两片领尖往下翻
	var path := PackedVector3Array()
	for i in 17:
		var a := lerpf(COLLAR_GAP, TAU - COLLAR_GAP, i / 16.0)
		path.append(Vector3(sin(a) * COLLAR_RING, COLLAR_Y + 0.012 * (1.0 - cos(a)) * 0.5, NECK_Z - cos(a) * COLLAR_RING))
	var parts := [_tagged(MeshShapes.tube(path, 0.011, 8, true), PatronSkin.SHIRT)]
	for side in [-1.0, 1.0]:
		var a: float = side * COLLAR_GAP
		var root := Vector3(sin(a) * COLLAR_RING, COLLAR_Y - 0.004, NECK_Z - cos(a) * COLLAR_RING - 0.004)
		var frame := PatronGeo.frame_at(root, Vector3(sin(a) * 0.6, 0.35, -1.0))
		var tip := PackedVector2Array([Vector2(0, 0.006), Vector2(side * 0.03, -0.002), Vector2(side * 0.006, -0.034)])
		parts.append(_placed(MeshShapes.extrude(tip, 0.003, 0.001), frame, PatronSkin.SHIRT))
	return _merged(parts)


static func bow_tie() -> Array:
	# 领结:两片蓬起的翅膀(倒角拉伸再鼓起来)+ 中间的结
	var frame := PatronGeo.frame_at(KNOT, Vector3(0, -0.22, -1.0))
	var parts := []
	for side in [-1.0, 1.0]:
		var wing := PackedVector2Array([Vector2(side * 0.006, 0.007), Vector2(side * 0.04, 0.022), Vector2(side * 0.05, 0.012),
			Vector2(side * 0.05, -0.012), Vector2(side * 0.04, -0.022), Vector2(side * 0.006, -0.007)])
		var puffed := MeshShapes.deform(MeshShapes.extrude(wing, 0.014, 0.004), func(v: Vector3) -> Vector3:
			var k := clampf(absf(v.x) / 0.05, 0.0, 1.0)
			return Vector3(v.x, v.y * (0.8 + 0.35 * k), v.z * (1.2 - 0.5 * k)))
		parts.append(_placed(puffed, frame, PatronSkin.TIE))
	parts.append(_placed(MeshShapes.rounded_box(Vector3(0.017, 0.02, 0.018), 0.006, 2), frame, PatronSkin.TIE))
	return [_merged(parts)]


static func necktie(torso: PatronTorso) -> Array:
	# 领带:结 + 铺在衬衫上、钻进马甲 V 领里的领带身(上窄下宽)
	var frame := PatronGeo.frame_at(KNOT + Vector3(0, -0.002, 0.002), Vector3(0, -0.2, -1.0))
	var knot := MeshShapes.deform(MeshShapes.rounded_box(Vector3(0.026, 0.026, 0.018), 0.007, 2), func(v: Vector3) -> Vector3:
		return Vector3(v.x * (1.0 + v.y * 14.0), v.y, v.z))
	var blade := torso.patch(func(s: float, t: float) -> Vector2:
			var y := lerpf(0.3, 0.54, t)
			var half := (0.016 + 0.008 * (0.54 - y) / 0.24) / 0.15
			return Vector2(lerpf(-half, half, s), y),
		3, 8, PatronTorso.TIE_DEPTH, PatronSkin.tag(PatronSkin.TIE))
	return [_merged([_placed(knot, frame, PatronSkin.TIE), blade])]


static func bolo(torso: PatronTorso) -> Array:
	# 波洛领绳(西部牛仔):两股细绳从领口垂下,中间一枚黄铜镶宝石的领扣
	var parts := []
	for side in [-1.0, 1.0]:
		var path := PackedVector3Array()
		for i in 8:
			var k := i / 7.0
			var y := lerpf(0.57, 0.44, k)
			path.append(torso.point(side * lerpf(0.2, 0.03, k), y, PatronTorso.TIE_DEPTH + 0.0025))
		parts.append(_tagged(MeshShapes.tube(path, 0.0016, 5, true), PatronSkin.LASH))
	var frame := torso.frame(0.0, 0.515, PatronTorso.TIE_DEPTH + 0.004)
	var slide := MeshShapes.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.016, 0), Vector2(0.017, 0.003),
		Vector2(0.012, 0.005), Vector2(0, 0.0055)]), 14)
	var tilt := Basis(Vector3.RIGHT, -PI / 2.0).scaled(Vector3(1, 1, 1.25))
	parts.append(_placed(PatronGeo.transformed(slide, Transform3D(tilt, Vector3.ZERO)), frame, PatronSkin.BRASS))
	parts.append(_placed(PatronGeo.sphere(Vector3(0.0085, 0.0105, 0.004), 10, 6), frame.translated_local(Vector3(0, 0, -0.004)),
		PatronSkin.STONE))
	return [_merged(parts)]


static func back_seam(torso: PatronTorso) -> Array:
	# 后背中缝 + 下摆开衩:越肩视角下自己的背影占画面一大块,一道缝线让它读成剪裁过的外套而不是一截圆柱
	var path := PackedVector3Array()
	for i in SEAM_POINTS:
		var y := lerpf(SEAM_RANGE.x, SEAM_RANGE.y, float(i) / (SEAM_POINTS - 1))
		path.append(torso.point(PI, y, SEAM_RADIUS * 0.4))
	var seam := _tagged(MeshShapes.tube(path, SEAM_RADIUS, 5, true), PatronSkin.TRIM)
	var vent := PackedVector3Array()
	for i in 4:
		var y := lerpf(SEAM_RANGE.x, VENT_TOP, i / 3.0)
		vent.append(torso.point(PI + VENT_OFFSET, y, SEAM_RADIUS * 0.4))
	return _merged([seam, _tagged(MeshShapes.tube(vent, SEAM_RADIUS * 0.8, 5, true), PatronSkin.TRIM)])


# —— 扣子、口袋、表链、胸花 ——

static func _button(frame: Transform3D, radius: float, slot: int) -> Array:
	# 扣子:扁圆面包形(回转体),正面朝外
	var profile := PackedVector2Array([Vector2(0, 0), Vector2(radius, 0), Vector2(radius * 1.02, radius * 0.25),
		Vector2(radius * 0.7, radius * 0.45), Vector2(0, radius * 0.38)])
	var face_out := Basis(Vector3.RIGHT, -PI / 2.0)
	return _placed(PatronGeo.transformed(MeshShapes.lathe(profile, 10), Transform3D(face_out, Vector3.ZERO)), frame, slot)


static func pocket_square(torso: PatronTorso) -> Array:
	# 左胸口袋:一道袋口嵌条 + 露出来的三个方巾尖角
	var frame := torso.frame(POCKET.x, POCKET.y, 0.002)
	var welt := _placed(MeshShapes.rounded_box(Vector3(0.068, 0.01, 0.004), 0.0018, 1), frame, PatronSkin.TRIM)
	var peaks := []
	for k in 3:
		var x := (k - 1) * 0.017
		var h := 0.026 - absf(k - 1) * 0.006
		var tri := PackedVector2Array([Vector2(x - 0.013, 0.0), Vector2(x + 0.013, 0.0), Vector2(x + 0.002, h)])
		var peak_frame := frame.translated_local(Vector3(0, 0.003, -0.0015 - k * 0.0006))
		peaks.append(_placed(MeshShapes.extrude(tri, 0.0024, 0.0008), peak_frame, PatronSkin.POCKET))
	return [welt, _merged(peaks)]


static func watch_chain(torso: PatronTorso) -> Array:
	# 怀表链:从马甲扣子垂成一道弧,挂进右边的马甲口袋;扣子那头一根小横杆
	var path := PackedVector3Array()
	var start := Vector2(VEST_BUTTON_A, VEST_BUTTONS[2])
	for i in 12:
		var k := i / 11.0
		var a := lerpf(start.x, CHAIN_END.x, k)
		var y := lerpf(start.y, CHAIN_END.y, k) - CHAIN_SAG * sin(PI * k)
		path.append(torso.point(a, y, PatronTorso.VEST_DEPTH + 0.0045))
	var chain := _tagged(MeshShapes.tube(path, 0.0017, 5, true), PatronSkin.BRASS)
	var bar_frame := torso.frame(start.x, start.y - 0.004, PatronTorso.VEST_DEPTH + 0.005)
	var bar := MeshShapes.tube(PackedVector3Array([Vector3(-0.012, 0, 0), Vector3(0.012, 0, 0)]), 0.0016, 5, true)
	return _merged([chain, _placed(bar, bar_frame, PatronSkin.BRASS)])


static func flower(torso: PatronTorso, notch: bool) -> Array:
	# 胸花(插在左翻领上):五片花瓣 + 花心 + 一片叶子
	var t := (FLOWER_Y - PatronTorso.BUTTON_Y) / (PatronTorso.LAPEL_TOP - PatronTorso.BUTTON_Y)
	var a := -(torso.jacket_open(FLOWER_Y) + torso.lapel_width(t, notch) * 0.55)
	var frame := torso.frame(a, FLOWER_Y, 0.008)
	var parts := []
	for k in 5:
		var angle := TAU * k / 5.0
		var petal := PatronGeo.sphere(Vector3(0.008, 0.008, 0.004), 8, 5)
		parts.append(_placed(petal, frame.translated_local(Vector3(cos(angle), sin(angle), 0) * 0.0075), PatronSkin.POCKET))
	parts.append(_placed(PatronGeo.sphere(Vector3(0.005, 0.005, 0.004), 8, 5), frame.translated_local(Vector3(0, 0, -0.003)),
		PatronSkin.BRASS))
	var leaf := PatronGeo.sphere(Vector3(0.006, 0.013, 0.002), 8, 5)
	parts.append(_placed(leaf, frame * Transform3D(Basis(Vector3.BACK, -0.7), Vector3(0.008, -0.014, 0.003)), PatronSkin.COAT))
	return [_merged(parts)]


# —— 工具 ——

static func _placed(arrays: Array, frame: Transform3D, slot: int) -> Array:
	return _tagged(PatronGeo.transformed(arrays, frame), slot)


static func _tagged(arrays: Array, slot: int) -> Array:
	return PatronGeo.colored(arrays, func(_v: Vector3) -> Color: return PatronSkin.tag(slot))


static func _merged(parts: Array) -> Array:
	# 几块数组拼成一块(都已摆进身体坐标):少一次 add_arrays,部件坐标(CUSTOM0)即身体坐标
	return PatronGeo.concat(parts)
