extends RefCounted
# 截图工具与性能探针共用:在展台上摆一场结算庆祝(规格 2026-10-09-winner-celebration;tools/shot.gd --celebrate、
# tools/perf_probe.gd --celebrate)。骗子酒馆展台 4 号中弹倒下、2 号赢;德州展台 3 号与 6 号并列第一;
# 炸弹猫展台 3、5 号炸飞(黑脸)、2 号赢。机位 celebrate = 胜者特写环绕的起点(骗子酒馆 / 炸弹猫的结算机位),
# celebrate_table = 整桌环绕的起点(德州的结算机位;从本机座位那一侧开始)。
# tools/ 不进导出包,所以不声明 class_name,用 preload 取用。

const VIEWS := ["celebrate", "celebrate_table"]
const WINNERS := {"liars": [2], "poker": [3, 6], "bomb_cat": [2]}
const DOWN := {"liars": [4], "poker": [], "bomb_cat": [3, 5]}
const SEED := 1
const SETTLE := 2.6   # 秒:开演后等这么久再拍(第一炮的彩纸正在飘)


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
	return world.celebrate(WINNERS.get(kind, []), SEED)


static func view(world: TableWorld, kind: String, name: String) -> Transform3D:
	if name == "celebrate_table":
		var orbit := world.table_orbit()
		var me := SeatLayout.direction(world.seat_angles.get(world.my_pid, 0.0))
		orbit["start"] = atan2(me.x, me.z)
		return TableWorld.orbit_start(orbit)
	return TableWorld.orbit_start(world.winner_orbit(WINNERS.get(kind, [1])[0]))


static func fill(name: String) -> float:
	# 补光:特写同导演(越肩补光的 0.6 倍),整桌环绕不开
	return TableWorld.SEAT_FILL_LIGHT * 0.6 if name == "celebrate" else 0.0
