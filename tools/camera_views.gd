extends RefCounted
# 截图工具与性能探针共用的机位表:seat 与游戏里的越肩机位(TableWorld.third_person_view,本机座位)一致。
# tools/ 不进导出包,所以不声明 class_name,用 preload 取用。

const NAMES := ["seat", "selfshot", "gun", "menu", "overhead", "fireplace", "bar", "window", "closeup", "opponent"]


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
		_:
			return false
	return true
