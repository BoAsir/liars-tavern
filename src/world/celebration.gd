class_name Celebration
extends Node3D
# 结算庆祝(规格 2026-10-09-winner-celebration):纯本地表现,不发任何网络消息——各端从自己收到的 match_over /
# session_over 开演,胜者一样,舞步、礼炮的细节可以略有不同。挂在 TableWorld 下(牌桌坐标),由 TableWorld.celebrate 建、
# stop_celebration / revive_all / clear 收:
# - 胜者(德州平局时并列第一的每个人)跳舞(PatronDance,按物种 + 种子挑一支),活着的其他人鼓掌,出局倒下的人偶尔抽一下手;
# - 胜者两侧的桌沿上各弹出一门玩具礼炮(没有胜者的酒客时摆在本机左右两侧),「砰!」一声冒烟、喷出粉彩彩纸与卷曲彩带,
#   外加一小撮金色火星;第一炮两门齐发、最大,之后每 BURST_EVERY 秒左右轮流放一炮,一直放到收起为止;
# - 场上活着的彩纸总数不超过 MAX_CONFETTI(按每股的数量与寿命记账,超了就少喷一点)。
# 音效通过 sfx 信号交给 main 播放(fanfare 开场小号、applause 掌声、cannon_pop 礼炮)。走 _process 的 delta:
# 跟随 Engine.time_scale,场景树暂停时停住。

signal sfx(sound: String)

const MAX_CONFETTI := 400
const FIRST_BURST := 0.55           # 秒:礼炮弹出来之后第一炮
const BURST_EVERY := 3.4
const FIRST_CONFETTI := 150         # 第一炮每门的彩纸 / 彩带
const FIRST_STREAMERS := 10
const CONFETTI := 100               # 之后每炮
const STREAMERS := 7
const SPARKLES := 18
const CANNON_INSET := 0.13          # 礼炮离桌沿往里这么多(米)
const CANNON_SPREAD := 0.5          # 礼炮在胜者座位方向两侧各偏这么多(米,沿桌沿切向)
const CANNON_TOE_IN := 78.0         # 礼炮往胜者那边偏的角度(度):两股彩纸在胜者头顶上方交叉
const FAR_SPREAD := 1.0             # 没有胜者酒客时两门礼炮在本机左右两侧,沿桌沿各偏这么多(米)

var winners: Array = []
var seed_value := 0
var _world: TableWorld
var _cannons: Array[PartyCannon] = []
var _t := 0.0
var _next_burst := FIRST_BURST
var _bursts := 0
var _ledger: Array = []             # [彩纸数, 到期时刻]:还在场上的每一股彩纸
var _table := {}


func setup(world: TableWorld, p_winners: Array, p_seed := 0) -> void:
	# 加进 TableWorld 之前调用
	_world = world
	winners = p_winners.duplicate()
	seed_value = p_seed
	name = "Celebration"


func _ready() -> void:
	_table = {
		"center": _world.global_position,
		"radius": _world.table_radius,
		"top": _world.global_position.y + SeatLayout.FELT_TOP,
		"floor": _world.global_position.y,
	}
	_cast()
	_place_cannons()
	sfx.emit("fanfare")
	sfx.emit("applause")


func _process(delta: float) -> void:
	_t += delta
	if _t >= _next_burst:
		_fire()
		_next_burst += BURST_EVERY


# —— 角色 ——

func _cast() -> void:
	var head := _focus()
	for pid in _world.patrons:
		var patron: Patron = _world.patrons[pid]
		if not is_instance_valid(patron):
			continue
		var seed_for := hash([seed_value, pid])
		if winners.has(pid) and patron.alive:
			patron.dance(-1, seed_value)
		elif patron.alive:
			patron.clap(seed_for)
			patron.look_at_point(head)
		else:
			patron.twitch(seed_for)


func _focus() -> Vector3:
	# 旁人看向的点:第一个胜者的头;没有胜者酒客时看桌心上方
	for pid in winners:
		if _world.patrons.has(pid):
			return _world.head_position(pid)
	return _world.to_global(Vector3(0, SeatLayout.TABLE_TOP + 0.5, 0))


func dancers() -> Array:
	# 正在跳舞的胜者 pid
	return winners.filter(func(pid) -> bool: return _world.patrons.has(pid) and _world.patrons[pid].is_dancing())


# —— 礼炮 ——

func _place_cannons() -> void:
	# 胜者面前的桌沿两侧各一门,炮口朝桌外上方、往胜者那边偏一点;没有胜者酒客时放在本机座位的左右两侧
	var anchor := -1
	for pid in winners:
		if _world.patrons.has(pid):
			anchor = pid
			break
	var angle: float
	var spread := CANNON_SPREAD
	if anchor >= 0:
		angle = _world.seat_angles.get(anchor, 0.0)
	else:
		angle = _world.seat_angles.get(_world.my_pid, 0.0) + PI
		spread = FAR_SPREAD
	var out := SeatLayout.direction(angle)          # 桌心 → 座位
	var tangent := Vector3(out.z, 0.0, -out.x)
	var edge := out * (_world.table_radius - CANNON_INSET) + Vector3(0, SeatLayout.FELT_TOP, 0)
	for k in 2:
		var side := -1.0 if k == 0 else 1.0
		var cannon := PartyCannon.new()
		cannon.name = "Cannon%d" % k
		add_child(cannon)
		var pos := edge + tangent * spread * side
		# 炮口(局部 −Z)朝座位方向(桌外),再往胜者那边转一点:两股彩纸在胜者头顶交叉
		var aim := out.rotated(Vector3.UP, deg_to_rad(CANNON_TOE_IN) * -side * (1.0 if anchor >= 0 else 0.0))
		cannon.transform = Transform3D(Basis.looking_at(aim, Vector3.UP), pos)
		cannon.pop_in(0.08 * k)
		Fx.smoke_puff(self, to_local(cannon.global_position) + Vector3(0, 0.06, 0), 6, Color(0.85, 0.82, 0.78))
		_cannons.append(cannon)


func cannons() -> Array[PartyCannon]:
	return _cannons


func _fire() -> void:
	# 第一炮两门齐发、最大;之后左右轮流
	var first := _bursts == 0
	var which: Array = _cannons if first else [_cannons[_bursts % _cannons.size()]]
	for cannon: PartyCannon in which:
		# 彩带先占额度,剩下的给彩纸;额度用完这一炮就只冒烟
		var budget := budget_left()
		var streamers := mini(FIRST_STREAMERS if first else STREAMERS, budget)
		var confetti := mini(FIRST_CONFETTI if first else CONFETTI, budget - streamers)
		var muzzle := cannon.muzzle_transform()
		cannon.fire()
		if confetti + streamers > 0:
			ConfettiFx.burst(self, muzzle, _table, confetti, streamers, Vector2(3.4, 6.0) if first else Vector2(3.0, 5.4))
			_ledger.append([confetti + streamers, _t + ConfettiFx.STREAMER_LIFETIME + 0.2])
		Fx.smoke_puff(self, to_local(muzzle.origin), 5, Color(0.82, 0.8, 0.78))
		Fx.sparkles(self, muzzle.origin, muzzle.basis.y, SPARKLES)
	sfx.emit("cannon_pop")
	_bursts += 1


func budget_left() -> int:
	# 还能再喷多少片彩纸 + 彩带(场上活着的不超过 MAX_CONFETTI)
	_ledger = _ledger.filter(func(entry: Array) -> bool: return entry[1] > _t)
	var alive := 0
	for entry in _ledger:
		alive += entry[0]
	return maxi(MAX_CONFETTI - alive, 0)


func alive_confetti() -> int:
	# 场上还没收走的彩纸粒子总数(按粒子节点的 amount 算,含彩带)
	var total := 0
	for node in get_children():
		if node is GPUParticles3D and node.is_in_group(&"confetti") and not node.is_queued_for_deletion():
			total += node.amount
	return total


func bursts() -> int:
	return _bursts


# —— 收起 ——

func stop() -> void:
	# 舞步、鼓掌、抽手全部停下(活着的人坐回去、双手搭回桌上),礼炮与彩纸一并收走
	if _world != null and is_instance_valid(_world):
		for pid in _world.patrons:
			var patron: Patron = _world.patrons[pid]
			if is_instance_valid(patron):
				patron.stop_dance()
	queue_free()
