extends RefCounted
# 截图工具与性能探针共用:在展台上摆一场结算庆祝(规格 2026-10-09-winner-celebration;tools/shot.gd --celebrate、
# tools/perf_probe.gd --celebrate)。骗子酒馆展台 4 号中弹倒下、2 号赢;德州展台 3 号与 4 号并列第一(--celebrate-winners=1,2,… 可换,例如 8 人全员平局);
# 炸弹猫展台 3、5 号炸飞(黑脸)、2 号赢。机位 celebrate = 游戏里结算环绕的起点(TableWorld.celebration_orbit:
# 围着胜者转、胜者在画面左边;并列的人挨着就绕他们转、散得开就整桌环绕),celebrate_table = 整桌环绕的起点(从本机座位那一侧开始)。
# tools/ 不进导出包,所以不声明 class_name,用 preload 取用。

const VIEWS := ["celebrate", "celebrate_table"]
const WINNERS := {"liars": [2], "poker": [3, 4], "bomb_cat": [2]}
const DOWN := {"liars": [4], "poker": [], "bomb_cat": [3, 5]}
const SEED := 1
const SETTLE := 2.6   # 秒:开演后等这么久再拍(第一炮的彩纸正在飘)


static var winners_override: Array = []   # --celebrate-winners:换掉 WINNERS 里的胜者


static func winners(kind: String) -> Array:
	return winners_override if not winners_override.is_empty() else WINNERS.get(kind, [])


static func stage(world: TableWorld, kind: String) -> Celebration:
	for pid in DOWN.get(kind, []):
		var patron: Patron = world.patrons.get(pid)
		if patron == null or not patron.alive:
			continue
		if world.revolvers.has(pid) and world.revolvers[pid].get_parent() != world:
			patron.die(world.revolvers[pid], world)   # 举着枪的那位:枪掉回桌上
		else:
			patron.die()
		if kind == "bomb_cat":
			patron.set_soot(1.0)
	return world.celebrate(winners(kind), SEED)


static func view(world: TableWorld, kind: String, name: String, view_aspect := 16.0 / 9.0) -> Transform3D:
	# celebrate:游戏里的结算机位起点(TableWorld.celebration_orbit,胜者在画面左边);celebrate_table:整桌环绕起点(从本机座位那一侧)
	var orbit := world.celebration_orbit(winners(kind))
	if name == "celebrate_table":
		orbit = world.table_orbit()
		orbit["frame"] = TableWorld.SETTLEMENT_FRAME
		var me := SeatLayout.direction(world.seat_angles.get(world.my_pid, 0.0))
		orbit["start"] = atan2(me.x, me.z)
	elif not orbit.has("start"):
		var me2 := SeatLayout.direction(world.seat_angles.get(world.my_pid, 0.0))
		orbit["start"] = atan2(me2.x, me2.z)
	return TableWorld.orbit_start(orbit, view_aspect)


static func fill(world: TableWorld, kind: String, name: String) -> float:
	# 补光同导演:围着胜者转时越肩补光的 0.6 倍,整桌环绕不开
	return 0.0 if name == "celebrate_table" else world.celebration_orbit(winners(kind)).get("fill", 0.0)
