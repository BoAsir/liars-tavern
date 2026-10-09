class_name PatronHead
# 酒客的头:按物种参数把球"捏"成头型(腮帮、眉骨、下巴、口鼻一体成型,没有拼接缝),
# 毛色斑纹烘进顶点色;鼻子、腮毛、胡须等贴在头型表面上。
# 头部坐标:原点在头的枢轴(脖子顶端),头心在 CENTER,-Z 朝前。
# 脸上的部件都用"球面方向"定位(偏航 yaw、俯仰 pitch,捏形之前的单位球方向),经 point() 映射到捏好的表面,
# 换头型时眼睛、眉毛、嘴自动贴着新表面走。


const CENTER := Vector3(0, 0.1, 0)    # 比头部枢轴高 0.1 米:头坐得低一点,领口上方露出的脖子短
const HEAD_SEGMENTS := 36
const HEAD_RINGS := 24
const NORMAL_STEP := 0.01     # 数值求法线的角度步长(弧度)
const NOSE_SEGMENTS := 16
const SNOUT_SIDE_SHADE := 0.8   # 猪鼻圆饼侧壁的明暗


# —— 头型 ——

static func sculpt(spec: Dictionary) -> Callable:
	# 返回 fn(d: 头部坐标里的单位方向) -> 表面点(头部坐标)
	var h: Dictionary = spec["head"]
	var radius: float = h["radius"]
	var scale: Vector3 = h["scale"]
	var cheek: float = h.get("cheek", 0.0)
	var jowl: float = h.get("jowl", 0.0)
	var brow: float = h.get("brow", 0.0)
	var chin: float = h.get("chin", 0.0)
	var axis := snout_axis(spec)
	var s: Dictionary = spec["snout"]
	var snout_cos := cos(deg_to_rad(s["spread"]))
	var snout_len: float = s["length"]
	var taper: float = s["taper"]
	var flat_tip: float = s.get("flat", 0.0)
	return func(d: Vector3) -> Vector3:
		var p := d * radius * scale
		var lower := smoothstep(0.3, -0.5, d.y)
		var front := smoothstep(0.35, -0.6, d.z)
		p.x *= 1.0 + cheek * lower * smoothstep(0.05, 0.75, absf(d.x)) * (1.0 - front * 0.4)
		p.y -= jowl * radius * lower * smoothstep(0.2, 0.8, absf(d.x)) * front
		p.x *= 1.0 + jowl * lower * front * 0.6
		p.z -= brow * radius * exp(-pow((d.y - 0.42) / 0.16, 2.0)) * front * (1.0 - absf(d.x) * 0.8)
		p.z -= chin * radius * smoothstep(-0.4, -0.85, d.y) * front
		# 口鼻:绕口鼻轴把前面一片往外拉长、侧面收细;flat > 0 时端面压平(猪鼻)
		var w := smoothstep(snout_cos, 1.0, d.dot(axis))
		var along := p.dot(axis)
		var lateral := p - axis * along
		var pull := snout_len * pow(w, 1.3)
		var tip := along + pull
		if flat_tip > 0.0:
			tip = minf(tip, lerpf(tip, radius * scale.z + snout_len * 0.92, flat_tip * w))
		return CENTER + axis * tip + lateral * (1.0 - taper * w)


static func snout_axis(spec: Dictionary) -> Vector3:
	var pitch := deg_to_rad(spec["snout"]["pitch"])
	return Vector3(0, -sin(pitch), -cos(pitch))


static func dir(yaw: float, pitch: float) -> Vector3:
	# yaw > 0 朝酒客自己的右手边(+X),pitch > 0 朝上
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch))


static func point(shape: Callable, yaw: float, pitch: float, lift := 0.0) -> Vector3:
	var p: Vector3 = shape.call(dir(yaw, pitch))
	return p + normal(shape, yaw, pitch) * lift if lift != 0.0 else p


static func normal(shape: Callable, yaw: float, pitch: float) -> Vector3:
	var du: Vector3 = shape.call(dir(yaw + NORMAL_STEP, pitch)) - shape.call(dir(yaw - NORMAL_STEP, pitch))
	var dv: Vector3 = shape.call(dir(yaw, pitch + NORMAL_STEP)) - shape.call(dir(yaw, pitch - NORMAL_STEP))
	var n := du.cross(dv).normalized()
	var outward: Vector3 = shape.call(dir(yaw, pitch)) - CENTER
	return n if n.dot(outward) >= 0.0 else -n


static func point_at(shape: Callable, d: Vector3, lift := 0.0) -> Vector3:
	# 任意方向 d(头部坐标的单位向量)上的表面点:嘴、人中这类按口鼻局部角度摆放的部件用
	var p: Vector3 = shape.call(d.normalized())
	return p + normal_at(shape, d) * lift if lift != 0.0 else p


static func normal_at(shape: Callable, d: Vector3) -> Vector3:
	var dn := d.normalized()
	var t1 := dn.cross(Vector3.UP if absf(dn.y) < 0.95 else Vector3.RIGHT).normalized()
	var t2 := dn.cross(t1)
	var du: Vector3 = shape.call((dn + t1 * NORMAL_STEP).normalized()) - shape.call((dn - t1 * NORMAL_STEP).normalized())
	var dv: Vector3 = shape.call((dn + t2 * NORMAL_STEP).normalized()) - shape.call((dn - t2 * NORMAL_STEP).normalized())
	var n := du.cross(dv).normalized()
	var outward: Vector3 = shape.call(dn) - CENTER
	return n if n.dot(outward) >= 0.0 else -n


static func frame(shape: Callable, yaw: float, pitch: float, lift := 0.0) -> Transform3D:
	# 表面上一点的局部坐标系:-Z 朝外(法线),Y 尽量朝上;部件在这个系里建模,贴着脸摆
	var n := normal(shape, yaw, pitch)
	var up := (Vector3.UP - n * Vector3.UP.dot(n)).normalized()
	var x := up.cross(-n).normalized()
	return Transform3D(Basis(x, up, -n), point(shape, yaw, pitch, lift))


# —— 头部网格 ——

static func skull(spec: Dictionary) -> Array:
	# 极点朝着口鼻轴:口鼻尖是一圈放射状的三角形,拉长后依然圆润
	var shape := sculpt(spec)
	var to_axis := Basis(Quaternion(Vector3.UP, snout_axis(spec)))
	var arrays := PatronGeo.ellipsoid_fn(func(d: Vector3) -> Vector3: return shape.call(to_axis * d),
		HEAD_SEGMENTS, HEAD_RINGS, CENTER)
	var marks := markings(spec)
	return PatronGeo.colored(arrays, func(v: Vector3) -> Color:
		var d := _dir_of(shape, v)
		var m: Vector2 = marks.call(d)
		return PatronSkin.tag(PatronSkin.FUR, m.x, m.y, _occlusion(d)))


static func markings(spec: Dictionary) -> Callable:
	# 返回 fn(方向) -> Vector2(浅色比例, 深色比例):口鼻/下巴/腮的浅色、虎斑、眼周等,全由物种表里的斑块描述。
	# 斑块:{"dir", "size"(角度半径,弧度), "soft", "light" 或 "dark", "mirror", "below"(只取某高度以下)}
	var patches: Array = spec.get("markings", [])
	var stripes: Dictionary = spec.get("stripes", {})
	return func(d: Vector3) -> Vector2:
		var m := Vector2.ZERO
		for patch in patches:
			var amount := _patch(patch, d)
			if patch.has("dark"):
				m.y = maxf(m.y, amount * patch["dark"])
			else:
				m.x = maxf(m.x, amount * patch.get("light", 1.0))
		if not stripes.is_empty():
			m.y = maxf(m.y, _stripes(stripes, d) * (1.0 - m.x))
		return m


static func _patch(patch: Dictionary, d: Vector3) -> float:
	var center: Vector3 = (patch["dir"] as Vector3).normalized()
	var size: float = patch["size"]
	var soft: float = patch.get("soft", 0.15)
	var probe := d
	if patch.get("mirror", false):
		probe.x = absf(d.x) * signf(center.x)
	var angle := acos(clampf(probe.dot(center), -1.0, 1.0))
	var amount := smoothstep(size + soft, size - soft, angle)
	if patch.has("below"):
		amount *= smoothstep(patch["below"] + 0.08, patch["below"] - 0.08, d.y)
	return amount


static func _stripes(stripes: Dictionary, d: Vector3) -> float:
	# 虎斑:头顶到后脑一道道横向条纹(按偏航角分条),额头中间那几道短一些
	var count: float = stripes["count"]
	var top := smoothstep(stripes.get("from", 0.35), 0.75, d.y)
	var yaw := atan2(d.x, -d.z)
	var band := absf(sin(yaw * count * 0.5 + d.y * 2.0))
	var stripe := smoothstep(0.45, 0.8, band)
	return stripe * top * stripes.get("strength", 0.7)


static func _occlusion(d: Vector3) -> float:
	# 烘焙的明暗:下巴底与脖子连接处压暗(那里接受不到顶光,也让头和脖子分开)
	return lerpf(1.0, 0.72, smoothstep(-0.45, -0.95, d.y))


static func _dir_of(shape: Callable, v: Vector3) -> Vector3:
	# 网格顶点 → 大致的球面方向(给斑纹取样):口鼻被拉长过,按头心方向近似就够用
	var d := (v - CENTER).normalized()
	return d if d.length_squared() > 0.5 else Vector3.FORWARD


# —— 鼻子与口鼻细节 ——

static func nose(spec: Dictionary, batch: MeshBatch, shape: Callable) -> void:
	var n: Dictionary = spec["nose"]
	var tip: Vector3 = shape.call(snout_axis(spec))
	var basis := Basis.looking_at(snout_axis(spec), Vector3.UP)
	var size: Vector3 = n["size"]
	match n["shape"]:
		"disc":
			_pig_snout(spec, batch, tip, basis, size)
		"beak":
			batch.add_arrays(PatronBeak.upper(spec, shape), PatronSkin.SLOT)
		"dots":
			_dot_nostrils(batch, shape, spec, size)
		_:
			var arrays := PatronGeo.ellipsoid_fn(func(d: Vector3) -> Vector3:
				# 上宽下窄的圆角三角(熊、猫),"oval" 时不收窄
				var widen: float = 1.0 + n.get("heart", 0.0) * d.y
				return Vector3(d.x * size.x * widen, d.y * size.y, d.z * size.z), NOSE_SEGMENTS, 10)
			var nose_xform := Transform3D(basis, tip + basis * Vector3(0, n.get("raise", 0.0), size.z * n.get("sink", 0.35)))
			batch.add_arrays(arrays, PatronSkin.SLOT, nose_xform, PatronSkin.tag(PatronSkin.NOSE))
			_nostrils(batch, nose_xform, size)


static func _nostrils(batch: MeshBatch, nose: Transform3D, size: Vector3) -> void:
	# 鼻头下沿两个深色鼻孔 + 鼻梁上一点亮光(卡通的湿鼻头)
	for side in [-1.0, 1.0]:
		var hole := PatronGeo.sphere(Vector3(size.x * 0.24, size.y * 0.15, size.z * 0.22), 8, 5)
		var at := Vector3(side * size.x * 0.42, -size.y * 0.32, -size.z * 0.78)
		batch.add_arrays(hole, PatronSkin.SLOT, nose * Transform3D(Basis(Vector3.BACK, side * 0.35), at),
			PatronSkin.tag(PatronSkin.LASH))
	var glint := PatronGeo.sphere(Vector3(size.x * 0.22, size.y * 0.13, size.z * 0.12), 8, 5)
	batch.add_arrays(glint, PatronSkin.SLOT, nose * Transform3D(Basis(Vector3.RIGHT, -0.6), Vector3(-size.x * 0.28,
		size.y * 0.55, -size.z * 0.62)), PatronSkin.tag(PatronSkin.TEETH))


static func _pig_snout(spec: Dictionary, batch: MeshBatch, tip: Vector3, basis: Basis, size: Vector3) -> void:
	# 猪鼻:前端微凹的圆饼(回转体,沿口鼻轴),两个椭圆鼻孔
	var r := size.x
	var profile := PackedVector2Array([Vector2(0, 0), Vector2(r * 0.86, 0.004), Vector2(r, size.z * 0.35),
		Vector2(r * 0.96, size.z), Vector2(r * 0.9, size.z * 1.4)])
	# 端面用更粉的鼻头色,侧壁压暗一点:圆饼从脸上"立"起来,不和脸混成一片
	var snout := PatronGeo.colored(MeshShapes.lathe(profile, 28), func(v: Vector3) -> Color:
		return PatronSkin.tag(PatronSkin.NOSE, 0.0, 0.0, lerpf(1.0, SNOUT_SIDE_SHADE, smoothstep(0.003, size.z, v.y))))
	var disc_basis := basis * Basis(Vector3.RIGHT, PI / 2.0)
	batch.add_arrays(snout, PatronSkin.SLOT, Transform3D(disc_basis.scaled(Vector3(1, 1, size.y / size.x)), tip - basis.z * 0.006))
	for side in [-1.0, 1.0]:
		var hole := PatronGeo.sphere(Vector3(r * 0.2, r * 0.32, 0.006), 12, 8)
		var pos := tip + basis * Vector3(side * r * 0.4, 0.0, -0.002)
		batch.add_arrays(hole, PatronSkin.SLOT, Transform3D(basis * Basis(Vector3.FORWARD, side * 0.25), pos),
			PatronSkin.tag(PatronSkin.MOUTH, 0.0, 0.0, 0.6))


static func _dot_nostrils(batch: MeshBatch, shape: Callable, spec: Dictionary, size: Vector3) -> void:
	# 青蛙:吻端两个小小的深色鼻孔,左右分开、微微隆起
	var snout := Basis.looking_at(snout_axis(spec), Vector3.UP)
	for side in [-1.0, 1.0]:
		var d := snout * dir(side * size.x, size.y)
		var hole := PatronGeo.sphere(Vector3(size.z, size.z * 0.7, size.z * 0.5), 8, 5)
		var frame := PatronGeo.frame_at(point_at(shape, d, -size.z * 0.15), normal_at(shape, d))
		batch.add_arrays(hole, PatronSkin.SLOT, frame, PatronSkin.tag(PatronSkin.LASH))


static func whiskers(spec: Dictionary, batch: MeshBatch, shape: Callable) -> void:
	# 胡须:从口鼻两侧的胡须垫往外、略往下弯的细管(不投影)
	var w: Dictionary = spec.get("whiskers", {})
	if w.is_empty():
		return
	for side in [-1.0, 1.0]:
		for k in int(w["count"]):
			var spread: float = (k - (w["count"] - 1) / 2.0) * w["fan"]
			var root := point(shape, side * w["yaw"], w["pitch"] + spread * 0.25, -0.004)
			var out := Vector3(side, spread - 0.12, -0.25).normalized()
			var length: float = w["length"] * (1.0 - absf(spread) * 0.6)
			var path := PackedVector3Array()
			for i in 6:
				var t := i / 5.0
				path.append(root + out * length * t + Vector3(0, -0.012 * t * t, 0.02 * t * t))
			var radii := PatronGeo.resample(PackedFloat32Array([0.0016, 0.0011, 0.0004]), path.size())
			batch.add_arrays(MeshShapes.tube(path, radii, 5, false), PatronSkin.SLOT, Transform3D.IDENTITY,
				PatronSkin.tag(PatronSkin.WHISKER))


static func tufts(spec: Dictionary, batch: MeshBatch, shape: Callable) -> void:
	# 腮毛:脸颊两侧往外、往下翘的几簇尖毛(狐狸、猫),毛色按斑纹取浅/深
	var t: Dictionary = spec.get("tufts", {})
	if t.is_empty():
		return
	var marks := markings(spec)
	for side in [-1.0, 1.0]:
		for k in int(t["count"]):
			var pitch: float = t["pitch"] - k * t["step"]
			var yaw: float = side * (t["yaw"] + k * 0.08)
			var f := frame(shape, yaw, pitch, -0.014)
			var length: float = t["length"] * (1.0 - k * 0.18)
			var out := (f.basis * Vector3(side * 0.9, -0.35 - k * 0.25, -0.35)).normalized()
			var path := PackedVector3Array([f.origin, f.origin + out * length * 0.5 + Vector3(0, 0.006, 0),
				f.origin + out * length])
			var radii := PackedFloat32Array([t["width"], t["width"] * 0.55, 0.0005])
			var tuft := MeshShapes.tube(PatronGeo.smooth_path(path, 3), PatronGeo.resample(radii, 7), 7, false)
			var m: Vector2 = marks.call(dir(yaw, pitch))
			batch.add_arrays(_flattened(tuft, f.origin, f.basis.z, 0.4), PatronSkin.SLOT, Transform3D.IDENTITY,
				PatronSkin.tag(PatronSkin.FUR, m.x, m.y))


static func _flattened(arrays: Array, origin: Vector3, axis: Vector3, amount: float) -> Array:
	# 沿 axis 方向压扁(毛簇贴着脸,成片状而不是圆锥)
	return MeshShapes.deform(arrays, func(v: Vector3) -> Vector3:
		var off := v - origin
		return v - axis * off.dot(axis) * amount)
