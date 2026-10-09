class_name BarStools
# 前吧台前的三只高脚凳:四条外撇的车木腿、腿间一圈黄铜踏脚环、腿底黄铜脚套,
# 木座盘上一块鼓起的酒红皮革坐垫,坐垫下沿一道黄铜包边。凳子立得离踏脚杆一拳远,
# 整个落在吧台地盘里(离墙 ≤ 1.75 米,不碰牌桌外圈的椅子)。坐标为吧台本地。


const STOOLS := [Vector3(1.55, 0, -1.08), Vector3(1.55, 0, 0.02), Vector3(1.55, 0, 1.12)]
const TURNS := [4.0, -5.0, 2.0]      # 每只略转一点,别像排队;转多了靠柜子那条腿会碰到踏脚杆
const SEAT_HEIGHT := 0.76            # 坐垫顶
const CUSHION := 0.07                # 坐垫厚
const SEAT_RADIUS := 0.165
const BOARD := 0.03                  # 坐垫下木座盘的厚度
const LEG_TOP := 0.105               # 腿顶离凳轴(座盘底下)
const LEG_FOOT := 0.17               # 腿脚离凳轴
const LEG_ANGLE := 45.0              # 腿在对角线上:朝柜子的那两条腿离踏脚杆最远
const LEG_RADII := [0.016, 0.02, 0.014, 0.019, 0.015, 0.0135]   # 车木腿自上而下的粗细(两道鼓起的珠子)
const FERRULE := 0.035               # 黄铜脚套长
const RING_Y := 0.29                 # 踏脚环高度
const RING_TUBE := 0.009
const SEGMENTS := 20
const TACKS := 14                    # 坐垫包边上的铜钉


static func add_to(batch: MeshBatch) -> void:
	for i in STOOLS.size():
		_stool(batch, STOOLS[i], TURNS[i], 0.3 + i * 0.2)


static func add_details(batch: MeshBatch) -> void:
	# 铜钉太小,放进不投影的批次
	# 铜钉是低多边形的小圆顶(轴先转到 +X,再绕 Y 转到各自的方向),每颗二十个三角形
	var brass := WorldMaterials.brass()
	var tack := MeshShapes.lathe(PackedVector2Array([Vector2(0, 0), Vector2(0.0058, 0), Vector2(0.0044, 0.003),
		Vector2(0, 0.0045)]), 5)
	var y := SEAT_HEIGHT - CUSHION + 0.016
	for i in STOOLS.size():
		for k in TACKS:
			var a := TAU * k / TACKS + deg_to_rad(TURNS[i])
			batch.add_part(tack, brass, STOOLS[i] + Vector3(cos(a), 0, sin(a)) * (SEAT_RADIUS + 0.003) + Vector3(0, y, 0),
				Vector3(0, -rad_to_deg(a), -90))


static func _stool(batch: MeshBatch, at: Vector3, turn: float, seed: float) -> void:
	var board_y := SEAT_HEIGHT - CUSHION - BOARD
	# 木座盘:下沿倒圆
	var board := PackedVector2Array([Vector2(0, 0), Vector2(SEAT_RADIUS - 0.012, 0), Vector2(SEAT_RADIUS + 0.004, 0.012),
		Vector2(SEAT_RADIUS + 0.006, BOARD), Vector2(0, BOARD)])
	batch.add_part(MeshShapes.lathe(board, SEGMENTS), BarMaterials.wood(), at + Vector3(0, board_y, 0), Vector3(0, turn, 0),
		Vector3.ONE, Color.WHITE, seed)
	# 鼓起的皮革坐垫:侧面饱满、顶面微拱
	var r := SEAT_RADIUS
	var cushion := PackedVector2Array([Vector2(0, 0), Vector2(r, 0), Vector2(r + 0.006, 0.018), Vector2(r + 0.004, 0.036),
		Vector2(r - 0.01, 0.054), Vector2(r * 0.7, 0.066), Vector2(r * 0.35, CUSHION - 0.001), Vector2(0, CUSHION)])
	batch.add_part(MeshShapes.lathe(cushion, SEGMENTS), BarMaterials.leather(), at + Vector3(0, SEAT_HEIGHT - CUSHION, 0))
	var band := PackedVector2Array([Vector2(r + 0.0065, -0.002), Vector2(r + 0.0075, 0.016)])
	batch.add_part(MeshShapes.lathe(band, SEGMENTS), WorldMaterials.brass(), at + Vector3(0, SEAT_HEIGHT - CUSHION, 0))
	for k in 4:
		_leg(batch, at, deg_to_rad(LEG_ANGLE + 90.0 * k + turn), board_y, seed + k * 0.05)
	var ring_r := lerpf(LEG_FOOT, LEG_TOP, RING_Y / board_y)
	batch.add_part(MeshKit.torus(ring_r - RING_TUBE, ring_r + RING_TUBE, 24), WorldMaterials.brass(), at + Vector3(0, RING_Y, 0))


static func _leg(batch: MeshBatch, at: Vector3, angle: float, top_y: float, seed: float) -> void:
	var dir := Vector3(cos(angle), 0, sin(angle))
	var top := at + dir * LEG_TOP + Vector3(0, top_y, 0)
	var foot := at + dir * LEG_FOOT
	var path := PackedVector3Array()
	for k in LEG_RADII.size():
		path.append(top.lerp(foot, float(k) / (LEG_RADII.size() - 1)))
	batch.add_part(MeshShapes.tube(path, PackedFloat32Array(LEG_RADII), 8), BarMaterials.wood_turned(), Vector3.ZERO,
		Vector3.ZERO, Vector3.ONE, Color.WHITE, seed)
	var along := (foot - top).normalized()
	var ferrule := PackedVector3Array([foot - along * FERRULE, foot])
	batch.add_part(MeshShapes.tube(ferrule, LEG_RADII[-1] + 0.002, 8), WorldMaterials.brass())
