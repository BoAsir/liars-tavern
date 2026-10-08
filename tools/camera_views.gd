extends RefCounted
# 截图工具与性能探针共用的机位表:seat 与游戏里的越肩机位(TableWorld.third_person_view,本机座位)一致。
# tools/ 不进导出包,所以不声明 class_name,用 preload 取用。

const NAMES := ["seat", "selfshot", "gun", "menu", "overhead", "fireplace", "bar", "window", "closeup", "opponent",
	"lineup_front", "lineup_back", "lineup_heads", "lineup_left", "lineup_right",
	"focus0", "focus90", "focus180", "focus270", "focus120", "focus240", "door", "corner", "corner_front"]
# 特写机位(复刻 TableWorld.focus_view:镜头在桌心斜上方、偏向座位左侧,看向座位上的头):名字 -> 座位角(度)
const FOCUS := {"focus0": 0.0, "focus90": 90.0, "focus180": 180.0, "focus270": 270.0, "focus120": 120.0, "focus240": 240.0}


static func place(rig: CameraRig, view: String) -> bool:
	# 摆好机位返回 true;不认识的机位返回 false
	var top := SeatLayout.TABLE_TOP
	rig.fill_light.light_energy = 0.0
	match view:
		"seat":
			rig.snap(Vector3(TableWorld.THIRD_PERSON_SIDE, TableWorld.THIRD_PERSON_HEIGHT,
				SeatLayout.SEAT_RADIUS + TableWorld.THIRD_PERSON_BEHIND),
				Vector3(0, top, -0.12))
			rig.fill_light.light_energy = TableWorld.SEAT_FILL_LIGHT
		"selfshot":
			rig.snap(Vector3(-0.35, 1.42, 0.15), Vector3(0, 1.19, 1.37))
		"gun":
			rig.snap(Vector3(0.1, 1.42, 0.3), Vector3(1.25, 1.25, 0.0))
		"menu":
			rig.snap(Vector3(2.6, 2.1, 2.9), Vector3(-0.4, 0.9, -0.8))
		"overhead":
			rig.snap(Vector3(0, 2.6, 1.6), Vector3(0, top, 0))
		"fireplace":
			rig.snap(Vector3(0.5, 1.4, -1.5), Vector3(-1.5, 0.8, -4.4))
		"bar":
			rig.snap(Vector3(0.5, 1.5, 0.8), Vector3(-4.0, 1.4, -0.6))
		"window":
			rig.snap(Vector3(-1.5, 1.5, 1.5), Vector3(4.4, 1.5, -0.9))
		"closeup":
			rig.snap(Vector3(0.0, 1.05, 0.55), Vector3(0, top, -0.2))
		"opponent":
			rig.snap(Vector3(0, 1.3, 0.2), Vector3(0, 1.1, -1.25))
		# --lineup:8 个物种一字排开在 x ∈ [-2.73, 2.73]、z = 1.5,面朝 +Z
		"lineup_front":
			rig.snap(Vector3(0, 1.35, 6.1), Vector3(0, 0.85, 1.5))
		"lineup_back":
			rig.snap(Vector3(0, 1.4, -2.0), Vector3(0, 0.8, 1.5))
		"lineup_heads":
			rig.snap(Vector3(0, 1.45, 4.7), Vector3(0, 1.35, 1.5))
		"lineup_left":
			rig.snap(Vector3(-1.56, 1.35, 3.1), Vector3(-1.56, 1.0, 1.5))
		"lineup_right":
			rig.snap(Vector3(1.56, 1.35, 3.1), Vector3(1.56, 1.0, 1.5))
		"door":
			rig.snap(Vector3(0.9, 1.55, 1.0), Vector3(-0.35, 1.25, 4.4))
		"corner":
			rig.snap(Vector3(1.0, 1.6, -0.6), Vector3(3.7, 0.55, -3.5))
		"corner_front":
			rig.snap(Vector3(0.8, 1.7, 1.2), Vector3(3.5, 0.7, 3.9))
		_:
			if not FOCUS.has(view):
				return false
			var angle := deg_to_rad(FOCUS[view])
			var dir := SeatLayout.direction(angle)
			var head := dir * (SeatLayout.SEAT_RADIUS + 0.10) + Vector3(0, 1.27, 0)
			var pos := dir * 0.15 + Vector3(0, 1.42, 0) - Vector3.UP.cross(dir) * 0.35
			rig.snap(pos, head + Vector3(0, -0.08, 0))
	return true
