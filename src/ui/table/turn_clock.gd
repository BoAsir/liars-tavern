class_name TurnClock
extends RefCounted
# 回合倒计时(客户端显示用)。房主在公共状态里附带回合计时的剩余秒数(含演出补时),
# 每次收到就以它为准;两次之间按帧时长扣减。帧时长随 Engine.time_scale 缩放,与房主的 Timer 同速。
# 显示值封顶 TURN_TIMEOUT:演出补时还没用完时圆环停在满格,归零的那一刻正是房主代打的时刻。
# 旧版房主不发剩余时间:退回原来的本地计时,每次轮转从整 30 秒开始。


var _left := 0.0
var _from_host := false


func sync_from_host(value: Variant) -> void:
	# 网络数据不可信:只接受有限的非负数;缺失(-1)或异常时保持当前计时
	if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
		return
	var left := float(value)
	if not is_finite(left) or left < 0.0:
		return
	_left = left
	_from_host = true


func restart_turn() -> void:
	# 演出播到新的行动者:有房主时间就不动它(它已含演出补时),否则本地从整回合开始
	if not _from_host:
		_left = Protocol.TURN_TIMEOUT


func tick(delta: float) -> void:
	_left = maxf(_left - delta, 0.0)


func remaining() -> float:
	return clampf(_left, 0.0, Protocol.TURN_TIMEOUT)


func has_host_time() -> bool:
	return _from_host
