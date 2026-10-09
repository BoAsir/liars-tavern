class_name TableCandles
# 桌上的烛台:黄铜托盘(朝桌沿一侧带指环提手)上立着几只烛插,插着高矮不一的蜡烛;
# 蜡泪顺着烛身淌下,烛顶熔出浅坑、缺口朝蜡泪那一侧。每个烛台一个缓存网格(黄铜、蜡两个表面,不投影:
# 小件不值得为每盏有阴影的灯再画一遍),火苗各自一个公告板。
# 火苗与烛光的位置、参数保持原样(灯光调校在别处):烛芯根部 = 烛台原点 + CANDLE_BASE + 烛高。
# 蜡烛部件都以烛芯根部为原点建模(table_wax.gdshader 按部件坐标的高度让烛顶一段透出火光)。


# 烛台:[桌面上的方位角, 蜡烛数, 种子]。角度避开各座位的左轮摆放位置(3 人局 240° 座位的枪原本会穿过第二个烛台)
const SPOTS := [[PI * 0.76, 3, 1.0], [PI * 1.31, 2, 7.0]]
const SPOT_RADIUS := 0.7
const CANDLE_BASE := 0.012        # 烛高从烛台原点上方这么高量起(与旧版相同,火苗、烛光不挪位置)
const CANDLE_SPREAD := 0.035      # 多支蜡烛时离托盘中心的距离
const CANDLE_ANGLE_STEP := 2.1    # 相邻蜡烛的方位角间隔(弧度)
const HEIGHT_MIN := 0.07
const HEIGHT_STEP := 0.045        # 烛高 = 最矮 + 0~2 级
const FLAME_SIZE := Vector2(0.03, 0.06)
const FLAME_INTENSITY := 4.0
const FLAME_ABOVE_TOP := 0.026
const LIGHT_ABOVE_FLAME := 0.02
const SEGMENTS := 10
const TRAY_SEGMENTS := 24

# 托盘(半径, 高度;原点在桌面):圈足 → 托盘外底往外翻 → 卷边 → 内壁 → 盘心
const TRAY_PROFILE := [
	Vector2(0.0, 0.0), Vector2(0.052, 0.0), Vector2(0.056, 0.0015), Vector2(0.058, 0.0045),
	Vector2(0.066, 0.0075), Vector2(0.074, 0.011), Vector2(0.0785, 0.0135), Vector2(0.0812, 0.0162),
	Vector2(0.0798, 0.0187), Vector2(0.0768, 0.0189), Vector2(0.0742, 0.0165), Vector2(0.066, 0.0118),
	Vector2(0.058, 0.0095), Vector2(0.0, 0.0095),
]
const TRAY_FLOOR := 0.0095
# 指环提手:托盘卷边伸出、绕一圈回到托盘外底((朝外距离, 高度));顶上压一片拇指托
const HANDLE_PATH := [
	Vector2(0.0755, 0.0172), Vector2(0.086, 0.0212), Vector2(0.097, 0.0195), Vector2(0.1045, 0.0135),
	Vector2(0.1042, 0.0068), Vector2(0.0985, 0.0028), Vector2(0.0885, 0.0026), Vector2(0.0635, 0.0062),
]
const HANDLE_WIRE := 0.0028
const THUMB_POS := Vector2(0.091, 0.0228)
const THUMB_SCALE := Vector3(0.0115, 0.0026, 0.0085)
# 烛插(半径, 相对盘心的高度):接蜡的小碟(带圆边)→ 收进烛插 → 插口外沿 → 插口里(被蜡烛挡住)
const SOCKET_PROFILE := [
	Vector2(0.0, 0.0), Vector2(0.026, 0.0), Vector2(0.0283, 0.0014), Vector2(0.0288, 0.003),
	Vector2(0.0268, 0.0043), Vector2(0.0222, 0.0041), Vector2(0.0195, 0.0062), Vector2(0.0185, 0.012),
	Vector2(0.0192, 0.019), Vector2(0.0206, 0.0215), Vector2(0.0196, 0.0229), Vector2(0.0172, 0.0222),
	Vector2(0.0172, 0.016), Vector2(0.0, 0.016),
]
const SOCKET_TOP := 0.0229
const SOCKET_SEAT := 0.016        # 蜡烛底端插到烛插里这么高

# 蜡烛:半径;烛顶熔化的缺口深度、起伏;蜡泪粗细、末端泪滴
const CANDLE_RADIUS := 0.0165
const MELT_DEPTH := 0.014         # 烛顶往下这一段跟着熔化变形
const MELT_DIP := 0.0055
const MELT_RIPPLE := 0.0007
const DRIP_WIRE := 0.0034
const DRIP_BLOB := 0.0018
const DRIP_STEPS := 5
# 每道蜡泪:[相对缺口的方位角, 流下的长度占烛身的比例];第 3 道只有部分蜡烛有
const DRIPS := [[0.0, 0.62], [0.55, 0.3], [-0.7, 0.18]]
const WICK_PATH := [Vector3(0, -0.006, 0), Vector3(0, 0.004, 0), Vector3(0.0012, 0.0082, 0), Vector3(0.003, 0.0108, 0)]
const WICK_RADIUS := 0.0011
const WICK_TINT := Color(0.06, 0.045, 0.035)
const WAX_TINTS := [Color(0.82, 0.77, 0.69), Color(0.8, 0.73, 0.62), Color(0.84, 0.77, 0.67)]   # 象牙色:烛光就在头顶,太白会糊成一片


static func build(parent: Node3D, tavern: Tavern) -> Array[Node3D]:
	var holders: Array[Node3D] = []
	for i in SPOTS.size():
		holders.append(_holder(parent, tavern, i))
	return holders


static func mesh(index: int) -> ArrayMesh:
	var spec: Array = SPOTS[index]
	return MeshBatch.cached("table_candles:%d" % index, func(b: MeshBatch) -> void:
		_add_tray(b, SeatLayout.direction(spec[0]))
		for candle in candle_specs(spec):
			_add_candle(b, candle))


static func candle_specs(spec: Array) -> Array:
	# 每支蜡烛 {"offset", "height", "seed"}:与旧版同一套公式,火苗、烛光的位置不变
	var out := []
	var count: int = spec[1]
	for i in count:
		var offset := Vector3(cos(i * CANDLE_ANGLE_STEP), 0, sin(i * CANDLE_ANGLE_STEP)) * CANDLE_SPREAD \
			if count > 1 else Vector3.ZERO
		var height: float = HEIGHT_MIN + HEIGHT_STEP * ((i * 37 + int(spec[2])) % 3)
		out.append({"offset": offset, "height": height, "seed": spec[2] + i})
	return out


static func wax_material() -> ShaderMaterial:
	# 烛台与壁灯共用的蜡
	return WorldMaterials.cached("table_wax", func():
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://src/world/shaders/table_wax.gdshader")
		return mat)


# —— 节点:烛台、火苗、烛光 ——

static func _holder(parent: Node3D, tavern: Tavern, index: int) -> Node3D:
	var spec: Array = SPOTS[index]
	var base := SeatLayout.direction(spec[0]) * SPOT_RADIUS + Vector3(0, SeatLayout.TABLE_TOP, 0)
	# 节点名各不相同(重名会被引擎改成 @Node3D@N):tools/perf_probe.gd 按 Candles 前缀找烛光
	var holder := MeshKit.pivot(parent, base, "Candles%d" % (index + 1))
	MeshBatch.instance(holder, mesh(index), {}, "Holder", false)
	for candle in candle_specs(spec):
		_add_flame(holder, tavern, candle)
	return holder


static func _add_flame(holder: Node3D, tavern: Tavern, candle: Dictionary) -> void:
	var offset: Vector3 = candle["offset"]
	var seed: float = candle["seed"]
	var flame_y: float = CANDLE_BASE + candle["height"] + FLAME_ABOVE_TOP
	var flame := MeshKit.add(holder, MeshKit.quad(FLAME_SIZE), WorldMaterials.flame(FLAME_INTENSITY, seed),
		offset + Vector3(0, flame_y, 0))
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# 灯光参数保持原样(灯光调校在别处)
	var light := OmniLight3D.new()
	light.position = offset + Vector3(0, flame_y + LIGHT_ABOVE_FLAME, 0)
	light.light_color = Color(1.0, 0.74, 0.48)
	light.light_energy = 0.42
	light.omni_range = 2.2
	light.light_volumetric_fog_energy = 0.4
	holder.add_child(light)
	tavern.add_flicker(light, 6.0, 0.35, seed * 13.0)


# —— 托盘与烛插 ——

static func _add_tray(b: MeshBatch, outward: Vector3) -> void:
	var brass := WorldMaterials.brass()
	b.add_part(MeshShapes.lathe(PackedVector2Array(TRAY_PROFILE), TRAY_SEGMENTS), brass)
	var path := PackedVector3Array()
	for p in HANDLE_PATH:
		path.append(outward * p.x + Vector3.UP * p.y)
	b.add_part(MeshShapes.tube(path, HANDLE_WIRE, 6), brass)
	var yaw := rad_to_deg(atan2(-outward.z, outward.x))
	b.add_part(MeshKit.sphere(1.0, 8), brass, outward * THUMB_POS.x + Vector3.UP * THUMB_POS.y, Vector3(0, yaw, 0),
		THUMB_SCALE)


static func _add_candle(b: MeshBatch, candle: Dictionary) -> void:
	var offset: Vector3 = candle["offset"]
	var seed: float = candle["seed"]
	var top_y: float = CANDLE_BASE + candle["height"]
	var length := top_y - TRAY_FLOOR - SOCKET_SEAT
	var top := offset + Vector3(0, top_y, 0)
	var notch := fposmod(seed * 2.4, TAU)    # 烛顶缺口(蜡泪淌下的一侧)的方位角
	var tint: Color = WAX_TINTS[int(seed) % WAX_TINTS.size()]
	var wax := wax_material()
	b.add_part(MeshShapes.lathe(PackedVector2Array(SOCKET_PROFILE), SEGMENTS), WorldMaterials.brass(),
		offset + Vector3(0, TRAY_FLOOR, 0))
	b.add_part(candle_body(length, notch, seed), wax, top, Vector3.ZERO, Vector3.ONE, tint)
	b.add_part(_wax_collar(TRAY_FLOOR + SOCKET_TOP - top_y, seed), wax, top, Vector3.ZERO, Vector3.ONE, tint)
	var drips := DRIPS.size() if fposmod(seed * 0.618, 1.0) > 0.4 else DRIPS.size() - 1
	for k in drips:
		b.add_part(_drip(notch + DRIPS[k][0], length * DRIPS[k][1], notch), wax, top, Vector3.ZERO, Vector3.ONE, tint)
	b.add_part(wick(), wax, top, Vector3(0, rad_to_deg(seed * 1.3), 0), Vector3.ONE, WICK_TINT)


# —— 蜡烛 ——

static func candle_body(length: float, notch: float, seed: float, r := CANDLE_RADIUS) -> Array:
	# 烛身 + 烛顶(原点在烛芯根部):外缘一圈蜡唇,中间熔成浅坑;缺口一侧的蜡唇塌下去。壁灯里的短蜡烛也用它
	var profile := PackedVector2Array([Vector2(0.0, -length), Vector2(r * 0.95, -length), Vector2(r, -length + 0.002),
		Vector2(r, -0.007), Vector2(r * 0.985, -0.0025), Vector2(r * 0.93, 0.0), Vector2(r * 0.8, -0.0014),
		Vector2(r * 0.5, -0.0045), Vector2(r * 0.2, -0.0058), Vector2(0.0, -0.006)])
	return TableShapes.warp(MeshShapes.lathe(profile, SEGMENTS), func(v: Vector3) -> Vector3:
		return Vector3(v.x, v.y - _melt(atan2(v.z, v.x), notch, seed) * _top_weight(v.y), v.z))


static func wick() -> Array:
	# 烛芯:从烛顶浅坑里探出、微微弯着的一小截(顶点色染黑)
	return MeshShapes.tube(PackedVector3Array(WICK_PATH), WICK_RADIUS, 4)


static func _melt(angle: float, notch: float, seed: float) -> float:
	# 烛顶在该方位往下塌多少:缺口处最深,其余一圈微微起伏
	return MELT_DIP * pow(maxf(cos(angle - notch), 0.0), 4.0) + MELT_RIPPLE * sin(angle * 5.0 + seed * 7.0)


static func _top_weight(y: float) -> float:
	var t := clampf(1.0 + y / MELT_DEPTH, 0.0, 1.0)
	return t * t


static func _drip(angle: float, run: float, notch: float) -> Array:
	# 一道蜡泪:从蜡唇翻出来,贴着烛身往下淌,末端鼓成泪滴
	var lip := -MELT_DIP * pow(maxf(cos(angle - notch), 0.0), 4.0)
	var path := PackedVector3Array([_on_candle(angle, CANDLE_RADIUS * 0.86, lip - 0.0006)])
	var radii := PackedFloat32Array([DRIP_WIRE * 0.8])
	for i in DRIP_STEPS + 1:
		var t := float(i) / DRIP_STEPS
		var wobble := sin(t * 4.0 + angle * 3.0) * 0.05
		path.append(_on_candle(angle + wobble, CANDLE_RADIUS + 0.0004, lerpf(lip - 0.0025, lip - run, t)))
		radii.append(lerpf(DRIP_WIRE * 0.85, DRIP_WIRE, t) + DRIP_BLOB * t * t)
	var tip := lip - run
	var blob := DRIP_WIRE + DRIP_BLOB
	path.append(_on_candle(angle, CANDLE_RADIUS + 0.0002, tip - blob * 0.55))
	radii.append(blob * 0.75)
	path.append(_on_candle(angle, CANDLE_RADIUS - 0.0002, tip - blob * 0.95))
	radii.append(blob * 0.2)
	return MeshShapes.tube(path, radii, 5)


static func _on_candle(angle: float, radius: float, y: float) -> Vector3:
	return Vector3(cos(angle) * radius, y, sin(angle) * radius)


static func _wax_collar(socket_y: float, seed: float) -> Array:
	# 烛插口上积的一圈蜡:盖住烛身插进烛插的接缝,外缘不规则地漫过插口
	var r := CANDLE_RADIUS
	var profile := PackedVector2Array([Vector2(r - 0.0004, socket_y + 0.0042), Vector2(r + 0.0022, socket_y + 0.0036),
		Vector2(0.0196, socket_y + 0.0016), Vector2(0.0211, socket_y - 0.0004), Vector2(0.0204, socket_y - 0.0016)])
	return TableShapes.warp(MeshShapes.lathe(profile, SEGMENTS), func(v: Vector3) -> Vector3:
		# 只让外缘起伏:贴着烛身的内缘不动,不会和烛身之间露出缝
		var radius := Vector2(v.x, v.z).length()
		var reach := maxf(radius - r, 0.0) * 0.45 * sin(atan2(v.z, v.x) * 3.0 + seed * 5.0)
		var k := (radius + reach) / maxf(radius, 1e-6)
		return Vector3(v.x * k, v.y, v.z * k))
