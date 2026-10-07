class_name GazeSync
extends RefCounted
# 视线同步:每位玩家的角色看向自己光标所指之处,其他人的屏幕上也跟着转头。
# 每台机器都把"自己"摆在前排,座位整体转了不同角度,所以视线落点按发送者自己的座位坐标系传输。
# 发送端:节流 + 心跳(视线不动时也定期补发);交还给演出时立即发一次释放。
# 接收端:超过 STALE 秒收不到就视为释放,交还给本地演出。纯逻辑,不碰网络与场景。


const SEND_INTERVAL := 0.1   # 两次发送的最短间隔(秒)
const HEARTBEAT := 0.4       # 视线不动时的补发间隔(秒),须明显短于 STALE
const MIN_MOVE := 0.03       # 落点移动小于此距离(米)不算变化
const STALE := 1.2           # 接收端多久收不到就释放(秒)
const MAX_RANGE := 8.0       # 合法落点离发送者座位的最远距离(米;牌桌加酒馆的尺度)

var _sent_point := Vector3.ZERO
var _sent_active := false
var _since_send := INF
var _remote := {}            # pid -> {"point": Vector3, "age": float}
var _released: Array = []    # 已收到释放、等下一次 tick 交还演出的 pid


static func to_seat_local(seat: Transform3D, world_point: Vector3) -> Vector3:
	return seat.affine_inverse() * world_point


static func from_seat_local(seat: Transform3D, local_point: Vector3) -> Vector3:
	return seat * local_point


static func is_valid(point: Vector3) -> bool:
	return point.is_finite() and point.length() <= MAX_RANGE


func outgoing(delta: float, point: Vector3, active: bool) -> Dictionary:
	# 返回这一帧要发的 {"point", "active"};不用发时返回空字典
	_since_send += delta
	if not active:
		if not _sent_active:
			return {}
		return _mark_sent(point, false)
	if not _sent_active:
		return _mark_sent(point, true)
	if _since_send < SEND_INTERVAL:
		return {}
	if point.distance_to(_sent_point) < MIN_MOVE and _since_send < HEARTBEAT:
		return {}
	return _mark_sent(point, true)


func _mark_sent(point: Vector3, active: bool) -> Dictionary:
	_sent_point = point
	_sent_active = active
	_since_send = 0.0
	return {"point": point, "active": active}


func receive(pid: int, point: Vector3, active: bool) -> void:
	if active:
		_remote[pid] = {"point": point, "age": 0.0}
		_released.erase(pid)
	elif _remote.has(pid):
		_remote.erase(pid)
		if not _released.has(pid):
			_released.append(pid)


func tick(delta: float) -> Array:
	# 推进时间,返回这一帧该交还给演出的 pid(收到释放或超时)
	var released := _released
	_released = []
	for pid in _remote.keys():
		_remote[pid]["age"] += delta
		if _remote[pid]["age"] > STALE:
			_remote.erase(pid)
			released.append(pid)
	return released


func live_targets() -> Dictionary:
	# pid -> 发送者座位坐标系里的落点
	var targets := {}
	for pid in _remote:
		targets[pid] = _remote[pid]["point"]
	return targets


func forget(pid: int) -> void:
	_remote.erase(pid)
	_released.erase(pid)
