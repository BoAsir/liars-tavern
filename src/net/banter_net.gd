class_name Banter
extends Node
# 丢番茄与快捷语的网络层(规格 2026-10-08 丢番茄与快捷语 §3):NetworkManager 在 _ready 里挂的子节点,
# 各端路径一致为 /root/Net/Banter。RPC 全放在这里,NetworkManager 自己的 RPC 表不变(协议仍 v5)。
# 房主权威:客户端只发意图(rpc_tomato / rpc_say),房主校验名单、目标、冷却后向全员(含房主本机)广播结果;
# 不合法的静默丢弃。等待厅与牌局都能用,在场、出局、观战的人都能丢、都能说。界面与世界只接下面两个信号。


signal tomato_thrown(from_pid: int, target_pid: int, seed: int)
signal said(pid: int, phrase_id: int)

const TOMATO_COOLDOWN := 3.0   # 秒:每人两次丢番茄之间,房主为准
const SAY_COOLDOWN := 1.5      # 秒:每人两句快捷语之间,房主为准
# 快捷语(协议里只传编号,文案改了不影响联机;两种玩法都说得通)
const PHRASES := ["你骗人!", "真的假的?", "这把稳了~", "救命啊!", "哈哈哈哈!", "快点啦…", "好牌啊!", "呜呜呜…"]
const SEED_MAX := 0x7fffffff
const HOST_ID := LobbyModel.HOST_ID

# 时钟(毫秒):测试换成可控的
var now_ms := func() -> int: return Time.get_ticks_msec()

var _net: Node = null               # 父节点 NetworkManager
var _tomato_at := {}                # 仅房主:pid -> 上次获准丢番茄的时刻(毫秒)
var _say_at := {}                   # 仅房主:pid -> 上次获准说话的时刻(毫秒)
var _local_tomato_until := 0        # 本机:按下后到这个时刻之前不再发(按钮冷却显示用,房主另有校验)
var _local_say_until := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_net = get_parent()
	_rng.randomize()
	# 回到等待厅、进新房间、离开房间、有人断线:清掉冷却记录
	for sig in [&"returned_to_lobby", &"joined_lobby", &"left_lobby"]:
		if _net != null and _net.has_signal(sig):
			_net.connect(sig, _on_reset.unbind(1) if sig == &"left_lobby" else _on_reset)
	multiplayer.peer_disconnected.connect(func(id: int):
		_tomato_at.erase(id)
		_say_at.erase(id))


func _on_reset() -> void:
	_tomato_at = {}
	_say_at = {}
	_local_tomato_until = 0
	_local_say_until = 0


# —— 本机发起 ——

func throw_tomato(target_pid: int) -> bool:
	# 返回是否发出(本机冷却中或不在房间里时不发)。房主本机走同一套校验和广播
	if not in_room() or tomato_cooldown_left() > 0.0:
		return false
	_local_tomato_until = now_ms.call() + int(TOMATO_COOLDOWN * 1000.0)
	if _net.is_host:
		_handle_tomato(HOST_ID, target_pid)
	else:
		_send_to(HOST_ID, "rpc_tomato", [target_pid])
	return true


func say(phrase_id: int) -> bool:
	if not in_room() or say_cooldown_left() > 0.0 or not is_phrase(phrase_id):
		return false
	_local_say_until = now_ms.call() + int(SAY_COOLDOWN * 1000.0)
	if _net.is_host:
		_handle_say(HOST_ID, phrase_id)
	else:
		_send_to(HOST_ID, "rpc_say", [phrase_id])
	return true


func tomato_cooldown_left() -> float:
	return maxf(_local_tomato_until - now_ms.call(), 0) / 1000.0


func say_cooldown_left() -> float:
	return maxf(_local_say_until - now_ms.call(), 0) / 1000.0


static func is_phrase(value: Variant) -> bool:
	return typeof(value) == TYPE_INT and value >= 0 and value < PHRASES.size()


static func phrase_text(phrase_id: int) -> String:
	return PHRASES[phrase_id] if is_phrase(phrase_id) else ""


func in_room() -> bool:
	# 在等待厅或牌局里(握手完成):对局中入座者握手期间也不能丢;界面据此显示 T / Q 小圆牌
	return _net != null and _net.get("_session_active") == true and _net.get("_joining") == false \
		and (_net.is_host or not _net.lobby_players.is_empty() or _net.in_game)


# —— 意图(客户端 → 房主) ——
# 参数不加类型:来自不可信对端,在 _handle_* 里校验类型、范围与名单

@rpc("any_peer", "call_remote", "reliable")
func rpc_tomato(target_pid) -> void:
	_handle_tomato(multiplayer.get_remote_sender_id(), target_pid)


@rpc("any_peer", "call_remote", "reliable")
func rpc_say(phrase_id) -> void:
	_handle_say(multiplayer.get_remote_sender_id(), phrase_id)


func _handle_tomato(from_pid: int, target_pid: Variant) -> void:
	if not _host_accepts(from_pid):
		return
	if typeof(target_pid) != TYPE_INT or target_pid == from_pid or not patron_holders().has(target_pid):
		return
	if _cooling(_tomato_at, from_pid, TOMATO_COOLDOWN):
		return
	var seed := _rng.randi_range(0, SEED_MAX)
	tomato_thrown.emit(from_pid, target_pid, seed)
	_send_to_members("rpc_tomato_thrown", [from_pid, target_pid, seed])


func _handle_say(pid: int, phrase_id: Variant) -> void:
	if not _host_accepts(pid) or not is_phrase(phrase_id):
		return
	if _cooling(_say_at, pid, SAY_COOLDOWN):
		return
	said.emit(pid, phrase_id)
	_send_to_members("rpc_said", [pid, phrase_id])


func _host_accepts(pid: int) -> bool:
	# 只有房主处理意图;发送者必须在名单里(已握手的成员,含观战者与中途入座者)
	var lobby: LobbyModel = _net.get("_lobby") if _net != null else null
	return _net != null and _net.is_host and _net.get("_session_active") == true and lobby != null and lobby.has(pid)


func _cooling(table: Dictionary, pid: int, seconds: float) -> bool:
	# 冷却中返回 true;否则记下这一次
	var now: int = now_ms.call()
	if table.has(pid) and now - int(table[pid]) < int(seconds * 1000.0):
		return true
	table[pid] = now
	return false


func patron_holders() -> Array:
	# 桌上有酒客的人(能被砸的目标):对局中按会话的座位表(出局的酒客还在桌上;德州等下一手才登场的新人不在),
	# 等待厅里是已分到形象的成员。都要还在名单里
	var lobby: LobbyModel = _net.get("_lobby")
	if lobby == null:
		return []
	var session = _net.get("_session")
	if _net.in_game and session != null:
		return session.seats_with_patrons().filter(func(pid): return lobby.has(pid))
	return lobby.seat_order().filter(func(pid): return lobby.species_of(pid) != Species.UNASSIGNED)


# —— 广播(房主 → 全员) ——

@rpc("authority", "call_remote", "reliable")
func rpc_tomato_thrown(from_pid, target_pid, seed) -> void:
	if _net == null or _net.is_host or not in_room():
		return
	if typeof(from_pid) != TYPE_INT or typeof(target_pid) != TYPE_INT or typeof(seed) != TYPE_INT:
		return
	tomato_thrown.emit(from_pid, target_pid, seed)


@rpc("authority", "call_remote", "reliable")
func rpc_said(pid, phrase_id) -> void:
	if _net == null or _net.is_host or not in_room():
		return
	if typeof(pid) != TYPE_INT or not is_phrase(phrase_id):
		return
	said.emit(pid, phrase_id)


func _send_to_members(method: StringName, args: Array) -> void:
	var lobby: LobbyModel = _net.get("_lobby")
	for id in lobby.seat_order():
		if id != HOST_ID:
			_send_to(id, method, args)


func _send_to(id: int, method: StringName, args: Array = []) -> void:
	# 同 NetworkManager._send_to:只发给连接仍然有效的对端
	if _net != null and _net._is_connected(id):
		callv("rpc_id", [id, method] + args)
