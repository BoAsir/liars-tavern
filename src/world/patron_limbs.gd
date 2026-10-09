class_name PatronLimbs
# 酒客的脖子、手臂(袖子 + 衬衫袖口 + 爪子)、腿(裤子 + 鞋)、尾巴。全部返回 Mesh.ARRAY_* 数组(顶点色带槽位)。
# 坐标:脖子是沿 +Y 的单位高(Patron 按领口到头的距离拉长);手臂在肩部枢轴坐标里,-Z 沿手臂,
# 手(爪子)在 -Z 一臂之长处;腿与尾巴在座位坐标里(不随上身前倾,脚稳稳踩在地上)。


const SLEEVE := [[0.0, 0.057], [0.12, 0.059], [0.24, 0.055], [0.31, 0.051], [0.33, 0.054]]   # [沿手臂, 半径]
const SLEEVE_END := 0.33
const SHOULDER_CAP := Vector3(0.058, 0.052, 0.058)   # 袖山:略扁的球,盖住袖筒上口又不在肩上鼓成大包
const SHIRT_CUFF := Vector2(0.326, 0.347)    # 衬衫袖口沿手臂的起止
const CUFF_RADIUS := 0.0445
const WRIST := Vector2(0.34, 0.385)
# 爪子(手部坐标 = 手臂坐标平移一臂之长):整只往上翻 PAW_PITCH,手臂斜着往下伸时掌心正好平贴桌面
const PAW_PITCH := 0.47
const PAW_DROP := 0.004       # 掌心略低于手的枢轴:掌底离枢轴 PAW_RADIUS * PAW_SCALE.y,刚好贴着桌面
const PALM := Vector3(0.05, 0.042, 0.055)
const FINGERS := [-0.027, -0.009, 0.009, 0.027]
# 腿(座位坐标,x 为右腿;左腿镜像)
# 腿的中心线:髋 → 大腿 → 膝(圆滑转弯)→ 小腿 → 脚踝,[点, 裤管半径]
const LEG := [
	[Vector3(0.095, 0.552, 0.11), 0.074], [Vector3(0.1, 0.548, -0.06), 0.07], [Vector3(0.102, 0.53, -0.158), 0.063],
	[Vector3(0.104, 0.4, -0.172), 0.057], [Vector3(0.106, 0.105, -0.17), 0.058],
]
const FOOT := Vector3(0.106, 0.0, -0.205)
const CREASE_DIR := Vector3(0, 0.7, -1.0)   # 裤线朝向:大腿朝上、小腿朝前
const CREASE_SINK := 0.985    # 裤线中心略埋进裤管表面,露出一道细棱
const CREASE_RADIUS := 0.0028
const CREASE_SKIP := 2        # 裤线从髋部往前几个路径点后才开始(臀部被外套下摆盖住)
const CUFF_HEIGHT := 0.034
const CUFF_OUT := 0.004
const LIMB_SIDES := 12
const NECK_SEGMENTS := 14


# —— 脖子 ——

static func neck(spec: Dictionary) -> Array:
	# 单位高的毛皮圆柱(略收腰):Patron 沿 Y 拉长到头部枢轴;喉咙一侧按物种斑纹取浅色
	var profile := PackedVector2Array([Vector2(0, 0), Vector2(0.083, 0.0), Vector2(0.079, 0.4), Vector2(0.077, 0.75),
		Vector2(0.079, 1.0), Vector2(0, 1.0)])
	var throat: Vector2 = PatronHead.markings(spec).call(Vector3(0, -0.8, -0.6).normalized())
	return PatronGeo.colored(MeshShapes.lathe(profile, NECK_SEGMENTS), func(v: Vector3) -> Color:
		var front := smoothstep(0.0, -0.06, v.z)
		return PatronSkin.tag(PatronSkin.FUR, throat.x * front, throat.y * front))


# —— 手臂 ——

static func arm(spec: Dictionary, side: float) -> Array:
	# side:+1 右臂 / -1 左臂(决定袖扣、拇指在哪一侧)
	var outer := side    # 手臂坐标的 +X 在右臂是外侧、在左臂是内侧
	var parts := [
		_plain(_tagged(PatronGeo.sphere(SHOULDER_CAP, 14, 9), PatronSkin.COAT)),
		_sleeve(),
		_sleeve_end(),
		_shirt_cuff(outer),
		_tagged(_round_tube(PackedVector3Array([Vector3(0, 0, -WRIST.x), Vector3(0, 0, -WRIST.y)]),
			PackedFloat32Array([0.038, 0.036]), LIMB_SIDES), PatronSkin.FUR, 0.0, _paw_dark(spec)),
	]
	for k in 3:
		var at := Vector3(outer * 0.05, 0.012 - k * 0.012, -SLEEVE_END + 0.026)
		parts.append(_placed(PatronGeo.sphere(Vector3(0.0045, 0.0045, 0.0025), 6, 4),
			Transform3D(Basis(Vector3.UP, outer * PI / 2.0), at), PatronSkin.BRASS))
	var paw_xform := Transform3D(Basis(Vector3.RIGHT, PAW_PITCH), Vector3(0, 0, -Patron.ARM_LENGTH))
	parts.append(PatronGeo.transformed(paw(spec, side), paw_xform))
	return PatronGeo.concat(parts)


static func _sleeve() -> Array:
	var arrays := PatronGeo.revolve_fn(func(angle: float, t: float) -> Vector3:
			var along := t * SLEEVE_END
			var r := PatronGeo.hermite(SLEEVE, along, 1)
			return Vector3(cos(angle) * r, sin(angle) * r * 0.94, -along),
		LIMB_SIDES, 8, Vector3(0, 0, -0.15))
	return _tagged(arrays, PatronSkin.COAT)


static func _sleeve_end() -> Array:
	# 袖口的环形端面:挡住袖筒内部,从袖口看进去不会透空
	var ring := MeshShapes.lathe(PackedVector2Array([Vector2(0.054, 0.0), Vector2(0.044, 0.0)]), LIMB_SIDES)
	var face := Transform3D(Basis(Vector3.RIGHT, PI / 2.0), Vector3(0, 0, -SLEEVE_END))
	return _tagged(PatronGeo.transformed(ring, face), PatronSkin.LINING)


static func _shirt_cuff(outer: float) -> Array:
	var cuff := _round_tube(PackedVector3Array([Vector3(0, 0, -SHIRT_CUFF.x), Vector3(0, 0, -SHIRT_CUFF.y)]),
		PackedFloat32Array([CUFF_RADIUS, CUFF_RADIUS]), LIMB_SIDES)
	var link_at := Vector3(outer * (CUFF_RADIUS + 0.001), 0.0, -(SHIRT_CUFF.x + SHIRT_CUFF.y) / 2.0)
	var link := Transform3D(Basis(Vector3.UP, outer * PI / 2.0), link_at)
	return PatronGeo.concat([
		_tagged(cuff, PatronSkin.SHIRT),
		_placed(PatronGeo.sphere(Vector3(0.0075, 0.0075, 0.0028), 8, 5), link, PatronSkin.BRASS),
		_placed(PatronGeo.sphere(Vector3(0.0048, 0.0048, 0.0024), 8, 5), link.translated_local(Vector3(0, 0, -0.0016)),
			PatronSkin.STONE),
	])


static func paw(spec: Dictionary, side: float) -> Array:
	# 爪子(手部坐标,-Z 朝指尖、+Y 朝手背):圆润的掌 + 四根短指(或两瓣蹄子)+ 拇指 + 肉垫,熊有爪
	var paws: Dictionary = spec.get("paws", {})
	var dark := _paw_dark(spec)
	var parts := [_tagged(PatronGeo.sphere(PALM, 16, 10), PatronSkin.FUR, 0.0, dark, Vector3(0, -PAW_DROP, 0))]
	if paws.get("kind", "paw") == "hoof":
		for x in [-0.013, 0.013]:
			var toe := PatronGeo.sphere(Vector3(0.019, 0.021, 0.026), 10, 7)
			parts.append(_tagged(toe, PatronSkin.CLAW, 0.0, 0.0, Vector3(x, -0.022, -0.046)))
		return PatronGeo.concat(parts)
	for x in FINGERS:
		var spread: float = x * 1.6
		var finger := Transform3D(Basis(Vector3.UP, -spread), Vector3(x * 1.08, -0.026, -0.049 + absf(x) * 0.35))
		parts.append(_placed(PatronGeo.sphere(Vector3(0.0135, 0.0135, 0.02), 9, 6), finger, PatronSkin.FUR, 0.0, dark))
		parts.append(_placed(PatronGeo.sphere(Vector3(0.0085, 0.0035, 0.009), 8, 4),
			finger.translated_local(Vector3(0, -0.012, -0.004)), PatronSkin.PAD))
		if paws.get("tips", false):
			# 青蛙的指尖:圆鼓鼓的吸盘
			parts.append(_placed(PatronGeo.sphere(Vector3(0.0105, 0.008, 0.0105), 8, 5),
				finger.translated_local(Vector3(0, -0.004, -0.017)), PatronSkin.PAD))
		if paws.get("claws", false):
			var claw := MeshShapes.tube(PackedVector3Array([Vector3(0, 0, -0.012), Vector3(0, -0.006, -0.026)]),
				PackedFloat32Array([0.0042, 0.0006]), 6, true)
			parts.append(_placed(claw, finger, PatronSkin.CLAW))
	var thumb := Transform3D(Basis(Vector3.UP, side * 0.65), Vector3(-side * 0.046, -0.02, -0.016))
	parts.append(_placed(PatronGeo.sphere(Vector3(0.0125, 0.0125, 0.019), 9, 6), thumb, PatronSkin.FUR, 0.0, dark))
	parts.append(_tagged(PatronGeo.sphere(Vector3(0.024, 0.005, 0.02), 10, 5), PatronSkin.PAD, 0.0, 0.0,
		Vector3(0, -0.044, 0.004)))
	return PatronGeo.concat(parts)


static func _paw_dark(spec: Dictionary) -> float:
	# 狐狸的"黑袜子":爪子与手腕取深色
	return 1.0 if spec.get("paws", {}).get("dark", false) else 0.0


# —— 腿 ——

static func legs(spec: Dictionary) -> Array:
	var parts := []
	for side in [-1.0, 1.0]:
		var points := PackedVector3Array()
		var radii := PackedFloat32Array()
		for joint in LEG:
			points.append(joint[0] * Vector3(side, 1, 1))
			radii.append(joint[1])
		var path := PatronGeo.smooth_path(points, 4)
		var along := PatronGeo.resample(radii, path.size())
		parts.append(_tagged(_round_tube(path, along, LIMB_SIDES), PatronSkin.TROUSERS))
		parts.append(_crease(path, along))
		if spec.get("outfit", {}).get("shoes", "oxford") != "boot":   # 靴子:裤脚塞进靴筒,没有翻边
			parts.append(_cuff(path[path.size() - 1], radii[radii.size() - 1]))
		parts.append(shoe(spec, side))
	return PatronGeo.concat(parts)


static func _crease(path: PackedVector3Array, radii: PackedFloat32Array) -> Array:
	# 熨出来的裤线:大腿上面、小腿前面一道细棱(方向取"上 + 前"垂直于裤管的分量,膝盖处自然转过去)
	var line := PackedVector3Array()
	for i in path.size():
		var tangent := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
		var front := CREASE_DIR - tangent * CREASE_DIR.dot(tangent)
		line.append(path[i] + front.normalized() * radii[i] * CREASE_SINK)
	return _tagged(MeshShapes.tube(line.slice(CREASE_SKIP), CREASE_RADIUS, 4, true), PatronSkin.TROUSERS)


static func _cuff(ankle: Vector3, radius: float) -> Array:
	# 裤脚翻边:比裤管粗一圈的一截,上沿一道折痕(压暗)
	var cuff := _round_tube(PackedVector3Array([ankle + Vector3(0, -0.004, 0), ankle + Vector3(0, CUFF_HEIGHT, 0)]),
		PackedFloat32Array([radius + CUFF_OUT, radius + CUFF_OUT]), LIMB_SIDES)
	return PatronGeo.colored(cuff, func(v: Vector3) -> Color:
		return PatronSkin.tag(PatronSkin.TROUSERS, 0.0, 0.0, lerpf(1.0, 0.8, smoothstep(CUFF_HEIGHT * 0.6, CUFF_HEIGHT, v.y - ankle.y))))


static func shoe(spec: Dictionary, side: float) -> Array:
	# 皮鞋:圆头往前收窄的鞋身 + 鞋底 + 鞋跟;牛仔靴再加一截靴筒、高一点的跟
	var boot: bool = spec.get("outfit", {}).get("shoes", "oxford") == "boot"
	var at := FOOT * Vector3(side, 1, 1)
	var body := MeshShapes.deform(MeshShapes.rounded_box(Vector3(0.082, 0.06, 0.17), 0.026, 3), func(v: Vector3) -> Vector3:
		var toe := smoothstep(0.0, -0.085, v.z)
		return Vector3(v.x * (1.0 - toe * 0.2), v.y * (1.0 - toe * 0.25) - toe * 0.006, v.z))
	var heel_height := 0.03 if boot else 0.016
	var parts := [
		_tagged(body, PatronSkin.SHOES, 0.0, 0.0, at + Vector3(0, heel_height + 0.028, -0.01)),
		_tagged(MeshShapes.rounded_box(Vector3(0.086, 0.012, 0.176), 0.005, 1), PatronSkin.SOLE, 0.0, 0.0,
			at + Vector3(0, heel_height + 0.002, -0.01)),
		_tagged(MeshShapes.rounded_box(Vector3(0.07, heel_height, 0.05), 0.004, 1), PatronSkin.SOLE, 0.0, 0.0,
			at + Vector3(0, heel_height / 2.0, 0.045)),
	]
	if boot:
		var shaft := _round_tube(PackedVector3Array([at + Vector3(0, 0.06, 0.03), at + Vector3(0, 0.27, 0.035)]),
			PackedFloat32Array([0.05, 0.062]), LIMB_SIDES)
		parts.append(_tagged(shaft, PatronSkin.SHOES))
	return PatronGeo.concat(parts)


# —— 尾巴 ——

static func tail(spec: Dictionary) -> Array:
	# 座位坐标里的尾巴(以 tail_root 为原点):从臀后绕到椅子侧面垂下,不穿过椅面与椅背
	var t: Dictionary = spec.get("tail", {})
	match t.get("kind", ""):
		"bushy":
			return PatronTails.bushy(t)
		"slender":
			return PatronTails.slender(t)
		"curl":
			return PatronTails.curl(t)
		"puff":
			return PatronTails.puff(t)
	return []


# —— 工具 ——

static func _round_tube(path: PackedVector3Array, radii: PackedFloat32Array, sides: int) -> Array:
	# 管子(两端封口)+ 按米计的 UV:绕一圈的 U 乘上周长,布料图案在袖子、裤腿上和躯干一样密
	var arrays := MeshShapes.tube(path, radii, sides, true)
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var mean := 0.0
	for r in radii:
		mean += r / radii.size()
	for i in uvs.size():
		uvs[i].x *= TAU * mean
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	return arrays


static func _plain(arrays: Array) -> Array:
	# UV 全归零:球面的 UV 在两极打旋,肩头这种圆球不画布料图案,免得格纹拧成漩涡
	var out := arrays.duplicate()
	var blank := PackedVector2Array()
	blank.resize((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())
	out[Mesh.ARRAY_TEX_UV] = blank
	return out


static func _tagged(arrays: Array, slot: int, light := 0.0, dark := 0.0, offset := Vector3.ZERO) -> Array:
	var moved := PatronGeo.transformed(arrays, Transform3D(Basis(), offset)) if offset != Vector3.ZERO else arrays
	return PatronGeo.colored(moved, func(_v: Vector3) -> Color: return PatronSkin.tag(slot, light, dark))


static func _placed(arrays: Array, xform: Transform3D, slot: int, light := 0.0, dark := 0.0) -> Array:
	return _tagged(PatronGeo.transformed(arrays, xform), slot, light, dark)
