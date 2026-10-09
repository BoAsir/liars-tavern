class_name BarCounter
# 前吧台:深色上漆的柜身立在内收的踢脚上,正面五格凸起的门芯板、格与格之间是半圆的车木壁柱,
# 两端侧板同样嵌门芯板;厚台面带圆鼻边,台面下一道凹弧线脚、脚下一道踢脚线。
# 前面一根黄铜踏脚杆架在三只弯托上、两头弯回柜身;台面上一座三头黄铜酒头(木把手,另由 add_taps 放进不投影的批次)。
# 坐标为吧台本地:x 离墙(朝房间)、y 向上、z 沿墙。


const FRONT_X := 1.3                 # 柜身正面
const BACK_X := 0.86                 # 柜身背面(酒保那一侧)
const HALF_LENGTH := 1.75
const TOP_Y := 1.07                  # 台面顶
const TOP_THICKNESS := 0.07
const TOP_FRONT := 0.08              # 台面前沿伸出柜身
const TOP_BACK := 0.06
const TOP_END := 0.05                # 台面两端伸出
const PLINTH := 0.1                  # 踢脚高
const PLINTH_INSET := 0.035
const BASE_MOLD := 0.05              # 踢脚线高
const COVE := 0.045                  # 台面下凹弧线脚的大小
const BAYS := 5
const PILASTER_RADIUS := 0.036
const PILASTER_END := 0.06           # 两端壁柱离柜角
const PANEL_GAP := 0.05              # 门芯板与壁柱、线脚之间留的边
const PANEL_DEPTH := 0.028
const PANEL_BEVEL := 0.013
const RAIL_X := 1.39
const RAIL_Y := 0.2
const RAIL_RADIUS := 0.021
const RAIL_BRACKETS := [-1.05, 0.0, 1.05]
const TAPS_AT := Vector3(1.04, TOP_Y, 0.95)
const TAP_SPACING := 0.09
const HANDLE_TINT := Color(0.55, 0.42, 0.36)
const ALONG := Vector3(0, 0, -1)     # 部件 X 沿吧台长度摆放时的方向(配合 Y 向上,部件 +Z 朝房间)


static func add_to(batch: MeshBatch) -> void:
	_carcass(batch)
	_moldings(batch)
	_top(batch)
	_front_panels(batch)
	_end_panels(batch)
	_foot_rail(batch)


static func _carcass(batch: MeshBatch) -> void:
	var depth := FRONT_X - BACK_X
	var center_x := (FRONT_X + BACK_X) / 2.0
	var body := Vector3(HALF_LENGTH * 2.0, TOP_Y - TOP_THICKNESS - PLINTH, depth)
	batch.add_arrays(MeshShapes.rounded_box(body, 0.01, 1), BarMaterials.wood(),
		BarShapes.frame(ALONG, Vector3.UP, Vector3(center_x, PLINTH + body.y / 2.0, 0)), Color.WHITE, 0.11)
	var plinth := Vector3(body.x - PLINTH_INSET * 2.0, PLINTH, depth - PLINTH_INSET * 2.0)
	batch.add_arrays(MeshShapes.rounded_box(plinth, 0.006, 1), BarMaterials.wood(),
		BarShapes.frame(ALONG, Vector3.UP, Vector3(center_x, PLINTH / 2.0, 0)), Color(0.45, 0.4, 0.38), 0.12)


static func _moldings(batch: MeshBatch) -> void:
	# 踢脚线与台面下的凹弧线脚:正面一道,两端各一道
	var base := PackedVector2Array([Vector2(-0.01, 0), Vector2(0.024, 0), Vector2(0.024, 0.016)])
	base.append_array(BarShapes.arc(Vector2(0.006, 0.016), 0.018, 0.0, 90.0, 4).slice(1, 5))
	base.append_array([Vector2(0.004, BASE_MOLD), Vector2(-0.01, BASE_MOLD)])
	var cove := PackedVector2Array([Vector2(-0.01, -COVE), Vector2(-0.01, 0.0), Vector2(COVE, 0.0)])
	cove.append_array(BarShapes.arc(Vector2(COVE, -COVE), COVE, 90.0, 180.0, 6).slice(1, 6))
	var depth := FRONT_X - BACK_X
	var center_x := (FRONT_X + BACK_X) / 2.0
	for spec in [[base, PLINTH], [cove, TOP_Y - TOP_THICKNESS]]:
		var profile: PackedVector2Array = spec[0]
		var y: float = spec[1]
		batch.add_arrays(BarShapes.sweep(profile, HALF_LENGTH * 2.0 + 0.05), BarMaterials.wood(),
			BarShapes.frame(ALONG, Vector3.UP, Vector3(FRONT_X, y, 0)), Color.WHITE, 0.2)
		for side in [-1.0, 1.0]:
			batch.add_arrays(BarShapes.sweep(profile, depth + 0.05), BarMaterials.wood(),
				BarShapes.frame(Vector3(side, 0, 0), Vector3.UP, Vector3(center_x, y, side * HALF_LENGTH)), Color.WHITE, 0.3)


static func _top(batch: MeshBatch) -> void:
	# 厚台面:截面后沿方正、前沿一个大圆鼻边(u 朝房间,0 = 台面前沿)
	var depth := FRONT_X + TOP_FRONT - (BACK_X - TOP_BACK)
	var r := TOP_THICKNESS / 2.0
	var profile := PackedVector2Array([Vector2(-depth, 0.0), Vector2(-r, 0.0)])
	profile.append_array(BarShapes.arc(Vector2(-r, r), r, -90.0, 90.0, 8).slice(1, 9))
	profile.append(Vector2(-depth, TOP_THICKNESS))
	batch.add_arrays(BarShapes.sweep(profile, (HALF_LENGTH + TOP_END) * 2.0), BarMaterials.top(),
		BarShapes.frame(ALONG, Vector3.UP, Vector3(FRONT_X + TOP_FRONT, TOP_Y - TOP_THICKNESS, 0)), Color.WHITE, 0.4)


static func _bay_edges() -> PackedFloat32Array:
	var edges := PackedFloat32Array()
	var span := HALF_LENGTH - PILASTER_END
	for k in BAYS + 1:
		edges.append(-span + 2.0 * span * k / BAYS)
	return edges


static func _front_panels(batch: MeshBatch) -> void:
	# 壁柱立在踢脚线上、顶到凹弧线脚;门芯板凸出柜面,木纹竖向
	var bottom := PLINTH + BASE_MOLD
	var top := TOP_Y - TOP_THICKNESS - COVE
	var column := BarShapes.pilaster(top - bottom, PILASTER_RADIUS)
	var edges := _bay_edges()
	for z in edges:
		batch.add_arrays(column, BarMaterials.wood_turned(), BarShapes.frame(ALONG, Vector3.UP, Vector3(FRONT_X, bottom, z)),
			Color.WHITE, 0.5)
	var height := top - bottom - PANEL_GAP * 2.0
	for k in BAYS:
		var width := edges[k + 1] - edges[k] - (PILASTER_RADIUS * 1.25 + PANEL_GAP) * 2.0
		var center := Vector3(FRONT_X + PANEL_DEPTH * 0.25, (top + bottom) / 2.0, (edges[k] + edges[k + 1]) / 2.0)
		batch.add_arrays(_panel(width, height), BarMaterials.wood_turned(), BarShapes.frame(ALONG, Vector3.UP, center),
			Color.WHITE, 0.55 + k * 0.07)


static func _end_panels(batch: MeshBatch) -> void:
	var bottom := PLINTH + BASE_MOLD
	var top := TOP_Y - TOP_THICKNESS - COVE
	var width := FRONT_X - BACK_X - PANEL_GAP * 2.0 - 0.04
	var height := top - bottom - PANEL_GAP * 2.0
	for side in [-1.0, 1.0]:
		var center := Vector3((FRONT_X + BACK_X) / 2.0, (top + bottom) / 2.0, side * (HALF_LENGTH + PANEL_DEPTH * 0.25))
		batch.add_arrays(_panel(width, height), BarMaterials.wood_turned(),
			BarShapes.frame(Vector3(side, 0, 0), Vector3.UP, center), Color.WHITE, 0.9 + side * 0.05)


static func _panel(width: float, height: float) -> Array:
	var rect := PackedVector2Array([Vector2(-width / 2.0, -height / 2.0), Vector2(width / 2.0, -height / 2.0),
		Vector2(width / 2.0, height / 2.0), Vector2(-width / 2.0, height / 2.0)])
	return MeshShapes.extrude(rect, PANEL_DEPTH, PANEL_BEVEL)


static func _foot_rail(batch: MeshBatch) -> void:
	# 黄铜踏脚杆:两头圆滑地弯回柜身;三只弯托从柜面伸出来托住它,托脚贴一块圆座
	var brass := WorldMaterials.brass()
	var end := HALF_LENGTH - 0.08
	var path := PackedVector3Array([Vector3(FRONT_X - 0.01, RAIL_Y, -end), Vector3(RAIL_X - 0.035, RAIL_Y, -end + 0.025),
		Vector3(RAIL_X - 0.005, RAIL_Y, -end + 0.07), Vector3(RAIL_X, RAIL_Y, -end + 0.11), Vector3(RAIL_X, RAIL_Y, end - 0.11),
		Vector3(RAIL_X - 0.005, RAIL_Y, end - 0.07), Vector3(RAIL_X - 0.035, RAIL_Y, end - 0.025),
		Vector3(FRONT_X - 0.01, RAIL_Y, end)])
	batch.add_part(MeshShapes.tube(path, RAIL_RADIUS, 12, false), brass)
	for z in RAIL_BRACKETS:
		var arm := PackedVector3Array([Vector3(FRONT_X, RAIL_Y + 0.07, z), Vector3(FRONT_X + 0.05, RAIL_Y + 0.055, z),
			Vector3(RAIL_X - 0.012, RAIL_Y + 0.025, z), Vector3(RAIL_X, RAIL_Y, z)])
		batch.add_part(MeshShapes.tube(arm, PackedFloat32Array([0.01, 0.009, 0.008, 0.008]), 8), brass)
		batch.add_part(MeshKit.cylinder(0.022, 0.026, 0.008, 12), brass, Vector3(FRONT_X + 0.004, RAIL_Y + 0.07, z),
			Vector3(0, 0, -90))


# —— 酒头(不投影的批次) ——

static func add_taps(batch: MeshBatch) -> void:
	# 黄铜立柱顶上一根横担,三个龙头朝酒保那一侧(-x)弯下;木把手竖在横担上,微微后仰
	var brass := WorldMaterials.brass()
	var base := TAPS_AT
	var flange := PackedVector2Array([Vector2(0, 0), Vector2(0.055, 0), Vector2(0.055, 0.008), Vector2(0.034, 0.02),
		Vector2(0.026, 0.045), Vector2(0, 0.045)])
	batch.add_part(MeshShapes.lathe(flange, 16), brass, base)
	batch.add_part(MeshKit.cylinder(0.024, 0.026, 0.27, 14), brass, base + Vector3(0, 0.045 + 0.135, 0))
	var bar_y := 0.33
	var half := TAP_SPACING * 1.5
	batch.add_part(MeshShapes.tube(PackedVector3Array([base + Vector3(0, bar_y, -half), base + Vector3(0, bar_y, half)]),
		0.022, 12), brass)
	for side in [-1.0, 1.0]:
		batch.add_part(MeshKit.sphere(0.024, 12), brass, base + Vector3(0, bar_y, side * half))
	for i in 3:
		var z := (i - 1) * TAP_SPACING
		var spout := PackedVector3Array([base + Vector3(0, bar_y, z), base + Vector3(-0.06, bar_y, z),
			base + Vector3(-0.078, bar_y - 0.018, z), base + Vector3(-0.08, bar_y - 0.06, z)])
		batch.add_part(MeshShapes.tube(spout, PackedFloat32Array([0.011, 0.011, 0.01, 0.009]), 8), brass)
		_tap_handle(batch, base + Vector3(0, bar_y + 0.02, z), i)
	batch.add_part(MeshShapes.rounded_box(Vector3(0.11, 0.014, 0.34), 0.004, 1), brass, base + Vector3(-0.1, 0.007, 0))


static func _tap_handle(batch: MeshBatch, at: Vector3, index: int) -> void:
	var handle := PackedVector2Array([Vector2(0, 0), Vector2(0.011, 0), Vector2(0.011, 0.02), Vector2(0.015, 0.05),
		Vector2(0.019, 0.11), Vector2(0.018, 0.14), Vector2(0.011, 0.155), Vector2(0, 0.158)])
	var tilt := Vector3(0, 0, 9.0 + index * 3.0)
	batch.add_part(MeshKit.cylinder(0.013, 0.013, 0.022, 10), WorldMaterials.brass(), at, tilt)
	batch.add_part(MeshShapes.lathe(handle, 10), BarMaterials.wood_turned(), at + Vector3(-0.002, 0.008, 0), tilt,
		Vector3.ONE, HANDLE_TINT.lightened(index * 0.12))
