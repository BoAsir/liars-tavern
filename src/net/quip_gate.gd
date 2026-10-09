class_name QuipGate
extends RefCounted
# 房主端的快捷对话限速:每人两句之间至少隔 MIN_INTERVAL_MS(真实时间),改过的客户端也刷不了屏。
# 比客户端的冷却略宽,前后两句到达的间隔被网络抖动压短时不误拒。


const MIN_INTERVAL_MS := int(Quips.COOLDOWN * 1000.0 * 0.8)

var _last := {}   # pid -> 上一句被接受的时刻(毫秒)


func accept(pid: int, now_ms: int) -> bool:
	if _last.has(pid) and now_ms - _last[pid] < MIN_INTERVAL_MS:
		return false
	_last[pid] = now_ms
	return true


func forget(pid: int) -> void:
	_last.erase(pid)
