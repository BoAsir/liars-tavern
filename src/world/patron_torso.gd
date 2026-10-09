class_name PatronTorso
extends RefCounted
# 酒客的躯干形体与西装剪裁(身体坐标:原点在髋部枢轴,+Y 沿脊柱向上,-Z 朝前)。
# 躯干截面是随高度变化的超椭圆:曲面上的点用 (绕脊柱的角度 a, 高度 y) 表示,a = 0 正前方,a > 0 偏向酒客右手(+X)。
# 外套、马甲、衬衫、翻领都按 (a, y) 剪裁,再沿法线往外/往里偏移几毫米层层叠起来:
# 外套是最外层的整件躯干(前襟开 V 领、扣子以下又分开),马甲、衬衫、裤腰只铺在开口里、略微凹进去,互不穿插。


# 躯干轮廓:[y, 半宽, 前深, 后深]。底部与领口都收成一点(坐在椅面上、被领子遮住);
# 肩部做成垫肩的方肩,把袖山盖住一半——从背后看肩头是西装的肩线,而不是两个圆球
const PROFILE := [
	[-0.05, 0.0, 0.0, 0.0],
	[-0.046, 0.09, 0.078, 0.074],
	[-0.03, 0.148, 0.118, 0.11],
	[0.0, 0.174, 0.138, 0.126],
	[0.08, 0.182, 0.146, 0.13],
	[0.18, 0.18, 0.145, 0.13],
	[0.3, 0.186, 0.142, 0.128],
	[0.4, 0.2, 0.138, 0.126],
	[0.47, 0.222, 0.124, 0.118],
	[0.525, 0.218, 0.108, 0.11],
	[0.56, 0.176, 0.094, 0.098],
	[0.585, 0.1, 0.078, 0.082],
	[0.6, 0.0, 0.0, 0.0],
]
const ROUNDNESS := 2.4        # 截面超椭圆指数:2 是椭圆,越大肩背越方正
const CENTER_Z := -0.012
const BELLY_Y := 0.1          # 肚子最鼓的高度
const BELLY_SPREAD := 0.11
const CHEST_FROM := 0.22      # 胸肩宽(chest)从这个高度往上生效
const EPS := 0.002            # 数值求法线的步长
const UV_RADIUS := 0.17       # 布料 U 坐标 = 角度 × 这个半径(米):竖条纹沿躯干"经线"走,上下对得齐
# 剪裁
const BUTTON_Y := 0.2         # 外套扣子:V 领收到这里,往下前襟又分开,露出马甲下摆与裤腰
const LAPEL_TOP := 0.552      # 翻领上端,再往上是领圈
const V_TOP := 0.6            # 外套 V 领在领口处的半角(弧度)
const CUTAWAY := 0.5          # 前襟下摆分开的半角
const VEST_V_Y := 0.36        # 马甲 V 领的底
const VEST_V_TOP := 0.36      # 马甲 V 领在领口处的半角
const VEST_SIDE := 0.85       # 马甲两片铺到的角度(藏在外套下面)
const VEST_HEM := 0.055       # 马甲前片尖角的高度
const VEST_OVERLAP := 0.035   # 马甲左右片在门襟处重叠的角度
const VEST_NOTCH := 0.03      # 马甲下摆两个尖角之间倒 V 缺口的高度
const LAPEL_WIDTH := 0.34     # 翻领最宽处(弧度,胸前约 5 厘米)
const LAPEL_EDGE := 0.0014    # 翻领折边、外缘离外套表面的高度
const LAPEL_ROLL := 0.0032    # 翻领中间隆起的高度
const LAPEL_TUCK := 1.08      # 翻领横向多走一格收进外套里
const NECK_Z := -0.02         # 脖子中心(与 Patron.NECK_BASE 一致)
const COLLAR_POINTS := 20
const COLLAR_FOLD := Vector2(0.097, 0.585)   # 领子折边:绕脖子的半径、高度
const COLLAR_BACK_RISE := 0.01               # 后颈处折边再高这么多
const EDGE_POINTS := 12
const EDGE_RADIUS := 0.0026
const SHIRT_DEPTH := -0.009   # 各层相对外套表面的偏移(米,负为凹进去)
const TIE_DEPTH := -0.0065
const VEST_DEPTH := -0.0045
const LAP_DEPTH := -0.01
const JACKET_ROWS := 26
const JACKET_COLUMNS := 40

var _belly := 0.0
var _chest := 1.0


func _init(spec: Dictionary) -> void:
	var body: Dictionary = spec.get("body", {})
	_belly = body.get("belly", 0.0)
	_chest = body.get("chest", 1.0)


# —— 形体 ——

func dims(y: float) -> Vector3:
	# 高度 y 处的 (半宽, 前深, 后深)
	var w := maxf(PatronGeo.hermite(PROFILE, y, 1), 0.0)
	var front := maxf(PatronGeo.hermite(PROFILE, y, 2), 0.0)
	var back := maxf(PatronGeo.hermite(PROFILE, y, 3), 0.0)
	front += _belly * exp(-pow((y - BELLY_Y) / BELLY_SPREAD, 2.0)) * smoothstep(-0.05, 0.0, y)
	w *= lerpf(1.0, _chest, smoothstep(CHEST_FROM, 0.4, y) * smoothstep(0.6, 0.5, y))
	return Vector3(w, front, back)


func point(a: float, y: float, offset := 0.0) -> Vector3:
	var p := _surface(a, y)
	return p + normal(a, y) * offset if offset != 0.0 else p


func normal(a: float, y: float) -> Vector3:
	var da := _surface(a + EPS, y) - _surface(a - EPS, y)
	var dy := _surface(a, clampf(y + EPS, -0.05, 0.6)) - _surface(a, clampf(y - EPS, -0.05, 0.6))
	var n := dy.cross(da)
	if n.length_squared() < 1e-12:
		return Vector3(sin(a), 0.0, -cos(a))
	return n.normalized()


func frame(a: float, y: float, offset := 0.0) -> Transform3D:
	# 曲面上一点的局部坐标系(-Z 朝外):扣子、口袋、胸花在这个系里建模
	return PatronGeo.frame_at(point(a, y, offset), normal(a, y))


func _surface(a: float, y: float) -> Vector3:
	var d := dims(y)
	var s := sin(a)
	var c := cos(a)
	var e := 2.0 / ROUNDNESS
	var x := d.x * signf(s) * pow(absf(s), e)
	var z := -d.y * pow(absf(c), e) if c > 0.0 else d.z * pow(absf(c), e)
	return Vector3(x, y, CENTER_Z + z)


# —— 剪裁 ——

func jacket_open(y: float) -> float:
	# 外套前襟开口的半角:扣子往上是 V 领,往下前襟分开
	if y >= BUTTON_Y:
		return V_TOP * pow(clampf((y - BUTTON_Y) / (LAPEL_TOP - BUTTON_Y), 0.0, 1.0), 0.95)
	return CUTAWAY * pow(clampf((BUTTON_Y - y) / (BUTTON_Y + 0.05), 0.0, 1.0), 1.1)


func vest_open(y: float) -> float:
	return VEST_V_TOP * clampf((y - VEST_V_Y) / (LAPEL_TOP - VEST_V_Y), 0.0, 1.0)


func patch(fn: Callable, ns: int, nt: int, offset: float, slot_tag: Color) -> Array:
	# 贴着躯干的一片:fn(s, t) -> Vector2(a, y);沿法线偏移 offset;UV 按角度 × 半径、高度取(米)
	var arrays := PatronGeo.grid(func(s: float, t: float) -> Vector3:
			var ay: Vector2 = fn.call(s, t)
			return point(ay.x, ay.y, offset),
		ns, nt, Vector3(0, 0.28, CENTER_Z), false,
		func(s: float, t: float) -> Vector2:
			var ay: Vector2 = fn.call(s, t)
			return Vector2(ay.x * UV_RADIUS, ay.y))
	return PatronGeo.colored(arrays, func(_v: Vector3) -> Color: return slot_tag)


func jacket() -> Array:
	# 外套:整件躯干去掉前襟开口;行在底部与肩颈处加密(收口圆润)
	return patch(func(s: float, t: float) -> Vector2:
			var y := _row_y(t)
			var open := jacket_open(y) if y < LAPEL_TOP else V_TOP
			return Vector2(lerpf(open, TAU - open, s), y),
		JACKET_COLUMNS, JACKET_ROWS, 0.0, PatronSkin.tag(PatronSkin.COAT))


func _row_y(t: float) -> float:
	# 行高分布:两端(底与领口)密、中段疏
	var k := t * 2.0 - 1.0
	var eased := signf(k) * (1.0 - pow(1.0 - absf(k), 1.6))
	return lerpf(-0.05, 0.6, eased * 0.5 + 0.5)


func shirt(bottom: float) -> Array:
	return patch(func(s: float, t: float) -> Vector2:
			return Vector2(lerpf(-0.75, 0.75, s), lerpf(bottom, 0.59, t)),
		10, 10, SHIRT_DEPTH, PatronSkin.tag(PatronSkin.SHIRT))


func lap() -> Array:
	# 外套前襟下摆分开处露出的裤腰
	return patch(func(s: float, t: float) -> Vector2:
			return Vector2(lerpf(-0.65, 0.65, s), lerpf(-0.045, 0.14, t)),
		10, 5, LAP_DEPTH, PatronSkin.tag(PatronSkin.TROUSERS))


func vest_half(side: float) -> Array:
	# 马甲的一片(side = +1 右片 / -1 左片):内缘是 V 领,V 底以下越过中线与另一片重叠;
	# 下摆在门襟两侧各有一个尖角,两尖之间是倒 V 的缺口。左片压在右片上面(多凸出 1.5 毫米),扣子钉在左片上
	var depth := VEST_DEPTH + (0.0015 if side < 0.0 else 0.0)
	return patch(func(s: float, t: float) -> Vector2:
			var hem := VEST_HEM + VEST_NOTCH * (1.0 - smoothstep(0.0, 0.14, s)) + 0.085 * smoothstep(0.14, 0.8, s)
			var y := lerpf(hem, 0.585, t)
			var overlap := VEST_OVERLAP * (1.0 - smoothstep(VEST_V_Y - 0.01, VEST_V_Y + 0.03, y))
			return Vector2(side * lerpf(vest_open(y) - overlap, VEST_SIDE, s), y),
		10, 12, depth, PatronSkin.tag(PatronSkin.VEST))


# —— 翻领、领圈、门襟滚边 ——

func lapel(side: float, notch: bool) -> Array:
	# 翻领:沿外套 V 领边从扣子翻到领口,上宽下窄(notch 时领口下方有缺角);
	# 截面中间隆起(翻折的厚度),外缘一圈收进外套表面以下,侧面看不出缝
	var arrays := PatronGeo.grid(func(s: float, t: float) -> Vector3:
			var y := lerpf(BUTTON_Y, LAPEL_TOP, t)
			var v := s * LAPEL_TUCK
			var a := side * (jacket_open(y) + minf(v, 1.0) * lapel_width(t, notch))
			var lift := LAPEL_EDGE + LAPEL_ROLL * sqrt(sin(PI * minf(v, 1.0))) if v <= 1.0 else -0.002
			return point(a, y, lift),
		6, 16, Vector3(0, 0.28, CENTER_Z), false,
		func(s: float, t: float) -> Vector2: return Vector2(s * 0.05, t * (LAPEL_TOP - BUTTON_Y)))
	return PatronGeo.colored(arrays, func(_v: Vector3) -> Color: return PatronSkin.tag(PatronSkin.TRIM))


func lapel_width(t: float, notch: bool) -> float:
	# 翻领宽度(弧度),t = 0 扣子处 → 1 领口
	var w := LAPEL_WIDTH * pow(sin(t * PI / 2.0), 0.75) * (1.0 - 0.18 * pow(t, 6.0))
	if notch:
		w *= 1.0 - 0.6 * exp(-pow((t - 0.84) / 0.04, 2.0))
	return w


func collar(notch: bool) -> Array:
	# 领子:从两侧翻领上端绕过后颈的一圈——内沿(折边)立在脖子旁,外沿翻下来搭在肩上,中间略鼓;
	# 折边再滚一道给出厚度。青果领与翻领同色缎面,平驳领与外套同料
	var start := V_TOP + lapel_width(1.0, notch) * 0.6
	var fold := func(a: float) -> Vector3:
		var back := (1.0 - cos(a)) * 0.5
		return Vector3(sin(a) * COLLAR_FOLD.x, COLLAR_FOLD.y + COLLAR_BACK_RISE * back, NECK_Z - cos(a) * COLLAR_FOLD.x)
	var arrays := PatronGeo.grid(func(s: float, t: float) -> Vector3:
			var a := lerpf(start, TAU - start, s)
			var rest := point(a, LAPEL_TOP + 0.004 * (1.0 - cos(a)) * 0.5, 0.004)
			return (fold.call(a) as Vector3).lerp(rest, t) + normal(a, LAPEL_TOP) * 0.006 * sin(PI * t),
		COLLAR_POINTS, 3, Vector3(0, 0.5, CENTER_Z), false,
		func(s: float, t: float) -> Vector2: return Vector2(s * 0.5, t * 0.04))
	var path := PackedVector3Array()
	for i in COLLAR_POINTS + 1:
		path.append(fold.call(lerpf(start, TAU - start, float(i) / COLLAR_POINTS)))
	var slot := PatronSkin.COAT if notch else PatronSkin.TRIM
	var parts := [arrays, MeshShapes.tube(path, EDGE_RADIUS * 1.2, 6, true)]
	return PatronGeo.colored(PatronGeo.concat(parts), func(_v: Vector3) -> Color: return PatronSkin.tag(slot))


func front_edges(side: float) -> Array:
	# 门襟滚边:扣子以上是翻领的折边(缎面),以下是外套前襟的边;给零厚度的布边一点厚度
	var arrays := []
	for part in [[BUTTON_Y, LAPEL_TOP, PatronSkin.TRIM], [-0.035, BUTTON_Y, PatronSkin.COAT]]:
		var path := PackedVector3Array()
		for i in EDGE_POINTS:
			var y := lerpf(part[0], part[1], float(i) / (EDGE_POINTS - 1))
			path.append(point(side * jacket_open(y), y, EDGE_RADIUS * 0.5))
		var slot: int = part[2]
		arrays.append(PatronGeo.colored(MeshShapes.tube(path, EDGE_RADIUS, 6, false),
			func(_v: Vector3) -> Color: return PatronSkin.tag(slot)))
	return arrays
