class_name Bottles
# 吧台搁板上的酒瓶:6 种车削瓶型的不透明假玻璃,每种瓶型一个 MultiMesh(一次 draw),不投影。
# 网格按单位瓶高建(轮廓 y 是瓶高比例,半径是米),实例按真实瓶高缩放 Y;瓶型由瓶高分桶得出。

const KINDS := ["whiskey", "rum", "gin", "wine", "jug", "flask"]
const MIN_HEIGHT := 0.18   # 与 Tavern 吧台随机瓶高的范围一致
const MAX_HEIGHT := 0.3
const SEGMENTS := 14
const LABEL := 0.5         # 顶点 COLOR.a:0 玻璃、0.5 标签、1 瓶塞(bottle_glass.gdshader)
const CORK := 1.0
# 瓶型轮廓 (半径 米, 高度比例),自下而上;瓶身到 0.62 为止(着色器里液体只画在瓶身)
const PROFILES := {
	"whiskey": [Vector2(0.0, 0.0), Vector2(0.038, 0.0), Vector2(0.04, 0.03), Vector2(0.04, 0.6), Vector2(0.032, 0.68),
		Vector2(0.013, 0.76), Vector2(0.013, 0.93), Vector2(0.015, 0.95), Vector2(0.015, 0.97), Vector2(0.0, 0.97)],
	"rum": [Vector2(0.0, 0.0), Vector2(0.034, 0.0), Vector2(0.043, 0.18), Vector2(0.043, 0.5), Vector2(0.034, 0.64),
		Vector2(0.014, 0.74), Vector2(0.012, 0.93), Vector2(0.015, 0.95), Vector2(0.015, 0.97), Vector2(0.0, 0.97)],
	"gin": [Vector2(0.0, 0.0), Vector2(0.034, 0.0), Vector2(0.035, 0.04), Vector2(0.035, 0.62), Vector2(0.024, 0.7),
		Vector2(0.012, 0.74), Vector2(0.012, 0.94), Vector2(0.014, 0.96), Vector2(0.0, 0.96)],
	"wine": [Vector2(0.0, 0.0), Vector2(0.033, 0.0), Vector2(0.034, 0.03), Vector2(0.034, 0.56), Vector2(0.028, 0.64),
		Vector2(0.011, 0.74), Vector2(0.01, 0.95), Vector2(0.012, 0.97), Vector2(0.0, 0.97)],
	"jug": [Vector2(0.0, 0.0), Vector2(0.03, 0.0), Vector2(0.044, 0.15), Vector2(0.046, 0.35), Vector2(0.038, 0.56),
		Vector2(0.02, 0.68), Vector2(0.016, 0.88), Vector2(0.019, 0.92), Vector2(0.0, 0.92)],
	"flask": [Vector2(0.0, 0.0), Vector2(0.028, 0.0), Vector2(0.03, 0.04), Vector2(0.03, 0.62), Vector2(0.02, 0.7),
		Vector2(0.011, 0.76), Vector2(0.011, 0.95), Vector2(0.013, 0.97), Vector2(0.0, 0.97)],
}
const LABEL_BAND := Vector2(0.25, 0.45)   # 标签从瓶高的哪儿到哪儿


static func kind_for_height(height: float) -> String:
	var t := clampf((height - MIN_HEIGHT) / (MAX_HEIGHT - MIN_HEIGHT), 0.0, 0.9999)
	return KINDS[int(t * KINDS.size())]


static func mesh(kind: String) -> ArrayMesh:
	return MeshForge.cached("bottle:" + kind, func(f: MeshForge): recipe(f, kind), {&"main": WorldMaterials.bottle_glass()})


static func recipe(f: MeshForge, kind: String) -> void:
	var profile := PackedVector2Array(PROFILES[kind])
	f.paint(Color(1, 1, 1, 0.0), 0.06)
	f.ao = 0.0
	f.lathe(profile, SEGMENTS, PackedInt32Array([1]))
	# 纸标签:贴着瓶身轮廓、略高出 1.2 mm 的一圈
	var label := PackedVector2Array()
	for k in 5:
		var y := lerpf(LABEL_BAND.x, LABEL_BAND.y, k / 4.0)
		label.append(Vector2(_radius_at(profile, y) + 0.0012, y))
	f.ao = LABEL
	f.lathe(label, SEGMENTS)
	# 瓶塞:伸出瓶口
	var top := profile[profile.size() - 1].y
	var neck_r := profile[profile.size() - 3].x * 0.85
	f.ao = CORK
	f.lathe(PackedVector2Array([Vector2(0.0, top - 0.02), Vector2(neck_r, top - 0.02), Vector2(neck_r, top + 0.08),
		Vector2(0.0, top + 0.08)]), 8, PackedInt32Array([1, 2]))


static func _radius_at(profile: PackedVector2Array, y: float) -> float:
	# 轮廓在高度 y 处的半径(相邻两点线性插值;取外壁那一侧)
	for k in range(1, profile.size()):
		var a := profile[k - 1]
		var b := profile[k]
		if a.y <= y and y <= b.y and b.y > a.y:
			return lerpf(a.x, b.x, (y - a.y) / (b.y - a.y))
	return 0.0


static func build(parent: Node3D, bottles: Array) -> void:
	# bottles: [{"pos": 瓶底位置, "height": 瓶高, "color": 玻璃色}, …];每种瓶型一个 MultiMeshInstance3D
	var by_kind := {}
	for i in bottles.size():
		var kind := kind_for_height(bottles[i]["height"])
		if not by_kind.has(kind):
			by_kind[kind] = []
		by_kind[kind].append(i)
	for kind in KINDS:
		if not by_kind.has(kind):
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.use_custom_data = true
		multimesh.mesh = mesh(kind)
		var members: Array = by_kind[kind]
		multimesh.instance_count = members.size()
		for k in members.size():
			var b: Dictionary = bottles[members[k]]
			multimesh.set_instance_transform(k, Transform3D(Basis.from_scale(Vector3(1, b["height"], 1)), b["pos"]))
			multimesh.set_instance_color(k, b["color"])
			# 液面与标签色调由瓶子序号决定(不消耗吧台的随机数,别的摆件位置不变)
			var i: int = members[k]
			multimesh.set_instance_custom_data(k, Color(0.25 + fmod(i * 0.618, 1.0) * 0.32, fmod(i * 0.381, 1.0), 0, 0))
		var inst := MultiMeshInstance3D.new()
		inst.name = "Bottles_" + kind
		inst.multimesh = multimesh
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(inst)
