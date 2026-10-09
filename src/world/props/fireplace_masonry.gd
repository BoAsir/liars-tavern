class_name FireplaceMasonry
# 壁炉砌体:灰浆芯(石缝里露出来的就是它)、错缝方石砌的炉体与收分的烟囱(转角石逐层左右交替咬合)、
# 弓形拱券(九块楔形拱石 + 高出一截的拱心石)、抬高的炉床石板、炉膛内衬(熏黑的耐火砖,两侧向里收)、
# 壁炉台横梁与两只木托。坐标为壁炉本地(见 TavernFireplace)。


const SEED := 1847
const JOINT := 0.016                 # 灰缝宽
const PROUD := 0.03                  # 石面凸出灰浆芯
const PROUD_JITTER := 0.008          # 每块石头凸出多少略有不同,墙面才不平板
const QUOIN_DEPTH := 0.16            # 石块埋进灰浆芯的深度;转角石的侧面也露出这么深
const BEVEL := 0.014
const BULGE := 0.008                 # 石面中心鼓起
const BODY_COURSE := 0.18            # 下部炉体的层高
const CHIMNEY_COURSE := 0.21         # 烟囱的层高(离得远,石块大一些)
const BODY_SPAN := Vector2(0.24, 0.42)
const CHIMNEY_SPAN := Vector2(0.26, 0.44)
const REVEAL := 0.1                  # 炉口内侧先是一圈石面,再往里才是熏黑的耐火砖
const BACK_Z := 0.1                  # 炉膛后壁离墙
const SPLAY := 0.7                   # 后壁宽 / 炉口宽:两侧向里收,把火光反射出来
const ARC_STEPS := 12
const VOUSSOIRS := 9
const KEYSTONE := 4                  # 正中那块是拱心石
const RING_DEPTH := 0.2              # 拱石的径向长度
const KEY_RISE := 0.07               # 拱心石高出拱圈
const KEY_FLARE := 0.022             # 拱心石顶部向两侧张开
const KEY_PROUD := 0.025             # 拱心石比其他拱石再凸出
const CORE_MARGIN := 0.02            # 灰浆芯的炉口缺口比内衬大一圈,两者不共面
const FLOOR_LIFT := 0.004            # 炉膛地面略高于炉床石板面
const HEARTH_SPLITS := [-0.58, 0.58] # 炉床三块石板的分缝(x)
const BEAM_TINT := Color(0.92, 0.84, 0.78)
const CORBEL_X := 0.93
const CORBEL_THICKNESS := 0.12


static func add_to(batch: MeshBatch) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_core(batch)
	batch.add_arrays(firebox_liner(), FireplaceMaterials.soot())
	_body_stones(batch, rng)
	_chimney_stones(batch, rng)
	_arch_stones(batch, rng)
	_hearth(batch, rng)
	_mantel(batch)


# —— 灰浆芯 ——

static func _core(batch: MeshBatch) -> void:
	var mortar := FireplaceMaterials.mortar()
	var hw := TavernFireplace.HALF_WIDTH
	var depth := TavernFireplace.BODY_DEPTH
	var notch := _arc_outline(TavernFireplace.OPENING_HALF_WIDTH + CORE_MARGIN, CORE_MARGIN, 0.0)
	var body := PackedVector2Array([Vector2(-hw, 0.0)])
	body.append_array(notch)
	body.append_array([Vector2(hw, 0.0), Vector2(hw, TavernFireplace.MANTEL_BOTTOM),
		Vector2(-hw, TavernFireplace.MANTEL_BOTTOM)])
	batch.add_part(MeshShapes.extrude(body, depth), mortar, Vector3(0, 0, depth / 2.0))
	# 横梁后面一截补到横梁顶:从上往下看不会露出缝
	var behind := Vector3(hw * 2.0, TavernFireplace.MANTEL_HEIGHT, TavernFireplace.MANTEL_BACK)
	batch.add_part(MeshKit.box(behind), mortar,
		Vector3(0, TavernFireplace.MANTEL_BOTTOM + behind.y / 2.0, behind.z / 2.0))
	var bottom := TavernFireplace.chimney_half_width(TavernFireplace.MANTEL_BOTTOM)
	var top := TavernFireplace.CHIMNEY_HALF_WIDTH.y
	var chimney := PackedVector2Array([Vector2(-bottom, TavernFireplace.MANTEL_BOTTOM),
		Vector2(bottom, TavernFireplace.MANTEL_BOTTOM), Vector2(top, Tavern.ROOM_HEIGHT),
		Vector2(-top, Tavern.ROOM_HEIGHT)])
	batch.add_part(MeshShapes.extrude(chimney, TavernFireplace.CHIMNEY_DEPTH), mortar,
		Vector3(0, 0, TavernFireplace.CHIMNEY_DEPTH / 2.0))


static func _arc_outline(half_width: float, grow: float, bottom: float) -> PackedVector2Array:
	# 炉口轮廓(从左下角上去、沿弓形拱过顶、到右下角),拱弧半径加 grow
	var c := TavernFireplace.arch_center()
	var r := TavernFireplace.arch_radius() + grow
	var half := asin(minf(half_width / r, 1.0))
	var pts := PackedVector2Array([Vector2(-half_width, bottom)])
	for k in ARC_STEPS + 1:
		var a := -half + 2.0 * half * k / ARC_STEPS
		pts.append(c + r * Vector2(sin(a), cos(a)))
	pts.append(Vector2(half_width, bottom))
	return pts


# —— 炉膛内衬 ——

static func firebox_liner() -> Array:
	# 炉口轮廓从 z = BODY_DEPTH - REVEAL 收向后壁(宽度按 SPLAY 收窄),外加后壁与炉膛地面;
	# 所有面都朝炉膛里面。熏黑的耐火砖与炭床附近的暗红余热由 fireplace_soot 着色器画
	var ow := TavernFireplace.OPENING_HALF_WIDTH
	var front := _arc_outline(ow, 0.0, TavernFireplace.HEARTH_TOP)
	var zf := TavernFireplace.BODY_DEPTH - REVEAL
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var back := PackedVector2Array()
	for p in front:
		back.append(Vector2(p.x * SPLAY, p.y))
	for i in front.size() - 1:
		var a := Vector3(front[i].x, front[i].y, zf)
		var b := Vector3(front[i + 1].x, front[i + 1].y, zf)
		var c := Vector3(back[i + 1].x, back[i + 1].y, BACK_Z)
		var d := Vector3(back[i].x, back[i].y, BACK_Z)
		var normal := (b - a).cross(d - a).normalized()
		var center := (a + c) / 2.0
		var inside := Vector3(0, TavernFireplace.HEARTH_TOP + 0.2, center.z)
		if normal.dot(inside - center) < 0.0:
			normal = -normal
		FireplaceStones.quad(verts, normals, indices, [a, b, c, d], normal)
	# 后壁:收窄后的炉口轮廓,朝房间
	var tris := Geometry2D.triangulate_polygon(back)
	var base := verts.size()
	for p in back:
		verts.append(Vector3(p.x, p.y, BACK_Z))
		normals.append(Vector3(0, 0, 1))
	for t in range(0, tris.size(), 3):
		FireplaceStones.tri(indices, verts, base + tris[t], base + tris[t + 1], base + tris[t + 2], Vector3(0, 0, 1))
	var y := TavernFireplace.HEARTH_TOP + FLOOR_LIFT
	FireplaceStones.quad(verts, normals, indices, [Vector3(-ow, y, zf), Vector3(ow, y, zf), Vector3(ow * SPLAY, y, BACK_Z),
		Vector3(-ow * SPLAY, y, BACK_Z)], Vector3.UP)
	return FireplaceStones.to_arrays(verts, normals, indices)


# —— 炉体与烟囱的石块 ——

static func _body_stones(batch: MeshBatch, rng: RandomNumberGenerator) -> void:
	# 正面与两个侧面同层同高;转角石逐层交替:偶数层正面的石块包住转角,奇数层侧面的包住
	var ys := _courses(TavernFireplace.HEARTH_TOP, TavernFireplace.MANTEL_BOTTOM, BODY_COURSE, rng)
	var hw := TavernFireplace.HALF_WIDTH
	var depth := TavernFireplace.BODY_DEPTH
	var front_rows := []
	var side_rows := []
	for r in ys.size() - 1:
		var front_owns := r % 2 == 0
		var half := hw + PROUD if front_owns else hw - QUOIN_DEPTH - JOINT
		front_rows.append(_band(-half, half, ys[r], ys[r + 1]))
		side_rows.append(Vector3(depth + PROUD if not front_owns else depth - QUOIN_DEPTH - JOINT, ys[r], ys[r + 1]))
	var holes := [arch_hole()]
	_lay(batch, Transform3D(Basis.IDENTITY, Vector3(0, 0, depth)), front_rows, holes, BODY_SPAN, rng)
	for side in [-1.0, 1.0]:
		_lay(batch, _side_frame(side, hw, 0.0, 0.0), _side_bands(side, side_rows), [], BODY_SPAN, rng)


static func _chimney_stones(batch: MeshBatch, rng: RandomNumberGenerator) -> void:
	# 烟囱正面是上窄下宽的梯形,两个侧面随之向里斜;转角咬合方式同下部炉体
	var bottom := TavernFireplace.MANTEL_TOP
	var ys := _courses(bottom, Tavern.ROOM_HEIGHT, CHIMNEY_COURSE, rng)
	var depth := TavernFireplace.CHIMNEY_DEPTH
	var widths := TavernFireplace.CHIMNEY_HALF_WIDTH
	var slope := (widths.x - widths.y) / (Tavern.ROOM_HEIGHT - bottom)
	var front_rows := []
	var side_rows := []
	for r in ys.size() - 1:
		var front_owns := r % 2 == 1
		var grow := PROUD if front_owns else -QUOIN_DEPTH - JOINT
		var w0 := TavernFireplace.chimney_half_width(ys[r]) + grow
		var w1 := TavernFireplace.chimney_half_width(ys[r + 1]) + grow
		front_rows.append(PackedVector2Array([Vector2(-w0, ys[r]), Vector2(w0, ys[r]), Vector2(w1, ys[r + 1]),
			Vector2(-w1, ys[r + 1])]))
		side_rows.append(Vector3(depth + PROUD if not front_owns else depth - QUOIN_DEPTH - JOINT, ys[r], ys[r + 1]))
	_lay(batch, Transform3D(Basis.IDENTITY, Vector3(0, 0, depth)), front_rows, [], CHIMNEY_SPAN, rng)
	var stretch := sqrt(1.0 + slope * slope)
	for side in [-1.0, 1.0]:
		var frame := _side_frame(side, widths.x, slope, bottom)
		var rows := []
		for row in side_rows:
			rows.append(Vector3(row.x, (row.y - bottom) * stretch, (row.z - bottom) * stretch))
		_lay(batch, frame, _side_bands(side, rows), [], CHIMNEY_SPAN, rng)


static func _courses(bottom: float, top: float, course: float, rng: RandomNumberGenerator) -> PackedFloat32Array:
	# 各层的分界高度:层高在 course 上下浮动,整体正好铺满
	var count := maxi(1, roundi((top - bottom) / course))
	var weights := PackedFloat32Array()
	var total := 0.0
	for i in count:
		weights.append(rng.randf_range(0.85, 1.15))
		total += weights[i]
	var ys := PackedFloat32Array([bottom])
	for i in count:
		ys.append(ys[i] + (top - bottom) * weights[i] / total)
	ys[count] = top
	return ys


static func _band(x0: float, x1: float, y0: float, y1: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)])


static func _side_bands(side: float, rows: Array) -> Array:
	# 侧面的一层:沿墙面从后墙(u=0)铺到前沿(u = ±extent);右侧面的 u 轴朝墙、左侧面的朝房间
	var bands := []
	for row in rows:
		var extent: float = row.x
		bands.append(_band(-extent, 0.0, row.y, row.z) if side > 0.0 else _band(0.0, extent, row.y, row.z))
	return bands


static func _side_frame(side: float, half_width: float, slope: float, y0: float) -> Transform3D:
	# 侧面(side = 1 右、-1 左)的墙面坐标系:X 沿墙面水平、Y 沿墙面向上(烟囱收分时向里斜)、Z 朝外。
	# 右手系:右侧面的 X 朝后墙(-Z),左侧面的 X 朝房间(+Z)
	var up := Vector3(-side * slope, 1.0, 0.0).normalized()
	var out := Vector3(side, slope, 0.0).normalized()
	return Transform3D(Basis(up.cross(out), up, out), Vector3(side * half_width, y0, 0.0))


static func _lay(batch: MeshBatch, frame: Transform3D, rows: Array, holes: Array, span: Vector2,
		rng: RandomNumberGenerator) -> void:
	var stone := FireplaceMaterials.stone()
	for outline in FireplaceStones.lay_rows(rows, holes, span, JOINT, rng):
		var proud := PROUD + rng.randf_range(-PROUD_JITTER, PROUD_JITTER)
		var arrays := FireplaceStones.stone(outline, QUOIN_DEPTH + proud, BEVEL, BULGE)
		batch.add_arrays(arrays, stone, frame * Transform3D(Basis.IDENTITY, Vector3(0, 0, -QUOIN_DEPTH)),
			Color.WHITE, rng.randf())


# —— 拱券 ——

static func arch_hole() -> PackedVector2Array:
	# 墙面石块要让开的区域:炉口 + 拱圈 + 拱心石(内缩半道灰缝,石块收缩后正好贴齐炉口)
	var ow := TavernFireplace.OPENING_HALF_WIDTH - JOINT / 2.0
	var c := TavernFireplace.arch_center()
	var outer := TavernFireplace.arch_radius() + RING_DEPTH
	var half := TavernFireplace.arch_half_angle()
	var pts := PackedVector2Array([Vector2(-ow, -0.5), Vector2(-ow, TavernFireplace.SPRING_HEIGHT)])
	for k in ARC_STEPS + 1:
		var a := -half + 2.0 * half * k / ARC_STEPS
		pts.append(c + outer * Vector2(sin(a), cos(a)))
	pts.append_array([Vector2(ow, TavernFireplace.SPRING_HEIGHT), Vector2(ow, -0.5)])
	var merged := Geometry2D.merge_polygons(FireplaceStones.ccw(pts), _voussoir(KEYSTONE, 0.0))
	for poly in merged:
		if not Geometry2D.is_polygon_clockwise(poly):
			return poly
	return pts


static func _voussoir(index: int, shrink: float) -> PackedVector2Array:
	# 第 index 块拱石的轮廓(拱心石顶部高出拱圈并向两侧张开);内弧向里让半道灰缝
	var c := TavernFireplace.arch_center()
	var r := TavernFireplace.arch_radius() - shrink
	var outer := TavernFireplace.arch_radius() + RING_DEPTH
	var half := TavernFireplace.arch_half_angle()
	var step := 2.0 * half / VOUSSOIRS
	var a0 := -half + index * step
	var a1 := a0 + step
	var pts := PackedVector2Array()
	for k in 3:
		var a := lerpf(a0, a1, k / 2.0)
		pts.append(c + r * Vector2(sin(a), cos(a)))
	if index == KEYSTONE:
		var top := outer + KEY_RISE
		var flare := KEY_FLARE / top
		pts.append_array([c + outer * Vector2(sin(a1), cos(a1)), c + top * Vector2(sin(a1 + flare), cos(a1 + flare)),
			c + top * Vector2(sin(a0 - flare), cos(a0 - flare)), c + outer * Vector2(sin(a0), cos(a0))])
	else:
		for k in 3:
			var a := lerpf(a1, a0, k / 2.0)
			pts.append(c + outer * Vector2(sin(a), cos(a)))
	return pts


static func _arch_stones(batch: MeshBatch, rng: RandomNumberGenerator) -> void:
	var stone := FireplaceMaterials.stone()
	var frame := Transform3D(Basis.IDENTITY, Vector3(0, 0, TavernFireplace.BODY_DEPTH - QUOIN_DEPTH))
	for i in VOUSSOIRS:
		var key := i == KEYSTONE
		var proud := PROUD + (KEY_PROUD if key else rng.randf_range(0.0, PROUD_JITTER))
		for outline in FireplaceStones.shrunk(_voussoir(i, JOINT / 2.0), JOINT / 2.0):
			batch.add_arrays(FireplaceStones.stone(outline, QUOIN_DEPTH + proud, BEVEL, BULGE), stone, frame,
				Color.WHITE, rng.randf())


# —— 炉床 ——

static func _hearth(batch: MeshBatch, rng: RandomNumberGenerator) -> void:
	# 三块大石板:两端的从墙根铺到前沿(大半压在炉体下面),中间那块只铺炉口前一段(炉膛里是内衬地面)。
	# 石板轮廓画在 (x, -z) 平面上,正面朝上
	var frame := Transform3D(Basis(Vector3.RIGHT, Vector3(0, 0, -1), Vector3.UP), Vector3.ZERO)
	var hh := TavernFireplace.HEARTH_HALF_WIDTH
	var front := TavernFireplace.HEARTH_DEPTH
	var xs := [-hh, HEARTH_SPLITS[0], HEARTH_SPLITS[1], hh]
	for i in 3:
		var back := TavernFireplace.BODY_DEPTH - REVEAL if i == 1 else 0.0
		var rect := Rect2(xs[i], -front, xs[i + 1] - xs[i], front - back)
		for outline in FireplaceStones.shrunk(FireplaceStones.chipped_rect(rect, rng), JOINT / 2.0):
			batch.add_arrays(FireplaceStones.stone(outline, TavernFireplace.HEARTH_TOP, BEVEL * 1.4, BULGE * 0.5),
				FireplaceMaterials.stone(), frame, Color.WHITE, rng.randf())


# —— 壁炉台 ——

static func _mantel(batch: MeshBatch) -> void:
	# 粗木横梁(后半截埋进烟囱)+ 两只涡卷木托
	var oak := FireplaceMaterials.oak()
	var depth := TavernFireplace.MANTEL_FRONT - TavernFireplace.MANTEL_BACK
	var size := Vector3(TavernFireplace.MANTEL_HALF_WIDTH * 2.0, TavernFireplace.MANTEL_HEIGHT, depth)
	batch.add_part(MeshShapes.rounded_box(size, 0.03, 2), oak,
		Vector3(0, TavernFireplace.MANTEL_BOTTOM + size.y / 2.0, TavernFireplace.MANTEL_BACK + depth / 2.0),
		Vector3.ZERO, Vector3.ONE, BEAM_TINT, 0.37)
	var corbel := MeshShapes.extrude(_corbel_profile(), CORBEL_THICKNESS, 0.008)
	for side in [-1.0, 1.0]:
		batch.add_part(corbel, oak, Vector3(side * CORBEL_X, TavernFireplace.MANTEL_BOTTOM, TavernFireplace.BODY_DEPTH),
			Vector3(0, -90, 0), Vector3.ONE, BEAM_TINT, 0.6 + side * 0.2)


static func _corbel_profile() -> PackedVector2Array:
	# 木托侧影:x 朝房间、y 向下。顶面托住横梁,前端一个圆鼓鼓的涡卷向下收回墙面
	var pts := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.2, 0.0), Vector2(0.2, -0.03)])
	var steps := 8
	for k in range(1, steps + 1):
		var t := float(k) / steps
		pts.append(Vector2(0.035 + 0.165 * (1.0 - t * t), -0.03 - 0.2 * t))
	pts.append_array([Vector2(0.055, -0.245), Vector2(0.03, -0.26), Vector2(0.0, -0.26)])
	return pts
