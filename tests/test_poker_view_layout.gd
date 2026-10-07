extends GutTest
# 德州机位的无头布局检查(规格 §5.5、§8):
# - 8 人桌的铭牌挂点在越肩与观战机位下投影到 1280×720,铭牌(按 150×64 估,底边中点在挂点,同 WorldLabels)
#   都在 24 像素安全边内且两两不重叠;
# - 越肩、观战、等待厅与散局环绕机位到每个头部、到 1.60 米高的帽顶的连线都不穿过吊灯罩(灯摆动 ±3 厘米)。
# 投影用游戏里同一个 CameraRig 的相机(竖直视角、近裁面一致),放进 1280×720 的 SubViewport。


const SCREEN := Vector2i(1280, 720)
const PLATE := Vector2(150, 64)       # 规格 §6.3:铭牌 ≤ 150×64
const SAFE_MARGIN := 24.0
const SEATS := 8
const SETTLE := 0.8                   # 秒:登场缩放(0.55 秒)走完,头部位置才是坐定后的
# 吊灯罩(照 Tavern._build_lamp):灯罩中心在吊点下 LAMP_DROP + 0.1,高 0.2,上口半径 0.07,
# 下口 0.36 外加一圈外径 0.37 的黄铜圈;吊点在天花板正中
const SHADE_CENTER_Y := Tavern.ROOM_HEIGHT - Tavern.LAMP_DROP - 0.1
const SHADE_HALF_HEIGHT := 0.1
const SHADE_TOP_RADIUS := 0.07
const SHADE_RIM_RADIUS := 0.37
const LAMP_SWING := 0.03              # 规格 §5.5:灯摆动 ±3 厘米
const HAT_TOP := 1.60                 # 最高的帽子
const SEGMENT_SAMPLES := 400
const ORBIT_SAMPLES := 16

var world: TableWorld
var rig: CameraRig


func before_each():
	world = TableWorld.new(null)
	add_child_autofree(world)
	world.configure_table(SeatLayout.POKER_TABLE_RADIUS)
	world.arrange(range(1, SEATS + 1).map(func(pid): return {"pid": pid}), 1, true, false)
	var viewport := SubViewport.new()
	viewport.size = SCREEN
	add_child_autofree(viewport)
	rig = CameraRig.new()
	viewport.add_child(rig)
	rig.set_process(false)   # 不要呼吸与震屏的偏移


func _settle() -> void:
	var tween := create_tween()
	tween.tween_interval(SETTLE)
	await tween.finished


func _plates(view: Transform3D) -> Array:
	rig.global_transform = view
	var rects := []
	for pid in range(1, SEATS + 1):
		var anchor := world.nameplate_anchor(pid)
		assert_false(rig.camera.is_position_behind(anchor), "%d 号的挂点在镜头前" % pid)
		var bottom_center := rig.camera.unproject_position(anchor)
		rects.append(Rect2(bottom_center - Vector2(PLATE.x / 2.0, PLATE.y), PLATE))
	return rects


func _assert_plates_fit(view: Transform3D, label: String) -> void:
	var safe := Rect2(Vector2.ONE * SAFE_MARGIN, Vector2(SCREEN) - Vector2.ONE * SAFE_MARGIN * 2.0)
	var rects := _plates(view)
	for i in rects.size():
		assert_true(safe.encloses(rects[i]), "%s:%d 号铭牌 %s 在安全边内" % [label, i + 1, rects[i]])
		for j in range(i + 1, rects.size()):
			assert_false(rects[i].intersects(rects[j]), "%s:%d 号与 %d 号铭牌重叠" % [label, i + 1, j + 1])


func _shade_clearance(from: Vector3, to: Vector3) -> float:
	# 线段离灯罩(含摆动余量)最近还有多远;≤ 0 即穿过。灯罩按上窄下宽的圆台、下沿取黄铜圈外径
	var best := INF
	for i in SEGMENT_SAMPLES + 1:
		var q := from.lerp(to, float(i) / SEGMENT_SAMPLES)
		var y := clampf(q.y, SHADE_CENTER_Y - SHADE_HALF_HEIGHT, SHADE_CENTER_Y + SHADE_HALF_HEIGHT)
		var k := (y - (SHADE_CENTER_Y - SHADE_HALF_HEIGHT)) / (SHADE_HALF_HEIGHT * 2.0)
		var radius := lerpf(SHADE_RIM_RADIUS, SHADE_TOP_RADIUS, k) + LAMP_SWING
		var above_or_below := absf(q.y - SHADE_CENTER_Y) - SHADE_HALF_HEIGHT
		var aside := Vector2(q.x, q.z).length() - radius
		best = minf(best, maxf(above_or_below, aside))
	return best


func _assert_clear_of_the_lamp(camera: Vector3, label: String) -> void:
	for pid in world.patrons:
		var head := world.head_position(pid)
		assert_gt(_shade_clearance(camera, head), 0.0, "%s → %d 号的头" % [label, pid])
		assert_gt(_shade_clearance(camera, Vector3(head.x, HAT_TOP, head.z)), 0.0, "%s → %d 号的帽顶" % [label, pid])


func test_nameplates_fit_and_do_not_overlap_over_the_shoulder():
	_assert_plates_fit(world.third_person_view(1), "越肩")


func test_nameplates_fit_and_do_not_overlap_in_the_overview():
	_assert_plates_fit(world.overview_view(), "观战")


func test_camera_lines_to_heads_and_hats_clear_the_lamp_shade():
	await _settle()
	_assert_clear_of_the_lamp(world.third_person_view(1).origin, "越肩")
	_assert_clear_of_the_lamp(world.overview_view().origin, "观战")
	_assert_clear_of_the_lamp(world.lobby_view().origin, "等待厅")


func test_closing_orbit_clears_the_lamp_shade_all_the_way_round():
	await _settle()
	var orbit := world.table_orbit()
	for i in ORBIT_SAMPLES:
		var angle := TAU * i / ORBIT_SAMPLES
		var camera: Vector3 = orbit["center"] + Vector3(sin(angle) * orbit["radius"], orbit["height"], cos(angle) * orbit["radius"])
		_assert_clear_of_the_lamp(camera, "环绕 %.0f°" % rad_to_deg(angle))
