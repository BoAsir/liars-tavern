extends Node
# 局域网房间发现(autoload "Discovery")。
# 房主:每秒向全局广播、各网卡定向广播与回环地址的全部发现端口发送房间报文;
#       连续几轮都没能发到任何局域网目标时发出 broadcast_health_changed(false),恢复后发 true。
# 客户端:绑定发现端口段中第一个空闲端口监听,维护去重、过期的房间列表。
# 同机多开时每个实例绑定不同端口,因此同机最多 DISCOVERY_PORT_COUNT 个实例都能发现房间。


signal rooms_updated(rooms: Array)
signal broadcast_health_changed(healthy: bool)

const BIND_ADDRESS := "0.0.0.0"
# 连续这么多轮没有任何局域网目标发送成功,才判定广播失效(偶发失败不打扰玩家)
const BROADCAST_FAIL_TICKS := 3
# 每帧最多处理的发现报文:广播风暴时剩下的留到后面几帧,不让一帧卡死
const MAX_PACKETS_PER_FRAME := 64

var _announce := Callable()
var _sender: PacketPeerUDP = null
var _listener: PacketPeerUDP = null
var _listen_port := 0
var _listen_owner_id := 0     # 当前监听发起者的实例 id;0 = 未指定
var _room_list := RoomList.new()
var _timer: Timer = null
var _failed_ticks := 0
var _broadcast_healthy := true


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = Protocol.BROADCAST_INTERVAL
	_timer.timeout.connect(_broadcast_once)
	add_child(_timer)


# —— 房主端 ——

func start_broadcast(announce: Callable) -> void:
	# announce 每次广播时调用,返回最新的房间信息字典
	_announce = announce
	if _sender == null:
		_sender = PacketPeerUDP.new()
		_sender.set_broadcast_enabled(true)
	_reset_health()
	_timer.start()
	_broadcast_once()


func stop_broadcast() -> void:
	_timer.stop()
	_announce = Callable()
	if _sender != null:
		_sender.close()
	_sender = null
	_reset_health()


func is_broadcast_healthy() -> bool:
	return _broadcast_healthy


func _broadcast_once() -> void:
	if _sender == null or not _announce.is_valid():
		return
	var payload := RoomList.encode(_announce.call())
	var addresses := Array(IP.get_local_addresses())
	var health_targets := Lan.health_targets(addresses)
	var lan_sent := 0
	var last_error := OK
	for target in Lan.broadcast_targets(addresses):
		for port in Protocol.discovery_ports():
			var err := _send(target, port, payload)
			if err != OK:
				last_error = err
			elif health_targets.has(target):
				lan_sent += 1
	# 推测的定向广播地址发不出去很常见,不逐个告警;健康度只看必定在本链路上的目标是否发成功
	# (经网关转发的宽前缀推测地址即使"发送成功",局域网也未必收到,不能算数)
	_record_tick(lan_sent > 0, last_error)


func _send(target: String, port: int, payload: PackedByteArray) -> Error:
	var err := _sender.set_dest_address(target, port)
	return err if err != OK else _sender.put_packet(payload)


func _record_tick(lan_ok: bool, last_error := OK) -> void:
	# 回环发送总能成功,不算数;连续 BROADCAST_FAIL_TICKS 轮失败才报告,一次成功立即恢复
	_failed_ticks = 0 if lan_ok else _failed_ticks + 1
	var healthy := _failed_ticks < BROADCAST_FAIL_TICKS
	if healthy == _broadcast_healthy:
		return
	_broadcast_healthy = healthy
	if not healthy:
		push_warning("房间广播连续 %d 轮没能发到局域网(最后错误:%s),其他人可能看不到房间" % [
			BROADCAST_FAIL_TICKS, error_string(last_error)])
	broadcast_health_changed.emit(healthy)


func _reset_health() -> void:
	_failed_ticks = 0
	if not _broadcast_healthy:
		_broadcast_healthy = true
		broadcast_health_changed.emit(true)


# —— 客户端 ——

func start_listening(listen_owner: Object = null) -> bool:
	# listen_owner:发起监听的对象(主菜单传 self)。之后只有同一个 owner 或不带 owner 的 stop 生效,
	# 旧菜单迟到的 stop 不会关掉新菜单刚开的监听
	_close_listener()
	_listen_owner_id = listen_owner.get_instance_id() if listen_owner != null else 0
	_room_list.clear()
	for port in Protocol.discovery_ports():
		var udp := PacketPeerUDP.new()
		if udp.bind(port, BIND_ADDRESS) == OK:
			_listener = udp
			_listen_port = port
			break
	rooms_updated.emit([])
	return _listener != null


func stop_listening(listen_owner: Object = null) -> void:
	if listen_owner != null and listen_owner.get_instance_id() != _listen_owner_id:
		return
	_close_listener()


func is_listening() -> bool:
	return _listener != null


func listen_port() -> int:
	return _listen_port


func get_rooms() -> Array:
	return _room_list.rooms()


func _close_listener() -> void:
	if _listener != null:
		_listener.close()
	_listener = null
	_listen_port = 0
	_listen_owner_id = 0


func _process(_delta: float) -> void:
	if _listener == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var changed := false
	for i in MAX_PACKETS_PER_FRAME:
		if _listener.get_available_packet_count() == 0:
			break
		var bytes := _listener.get_packet()
		var ip := _listener.get_packet_ip()
		var info := RoomList.decode(bytes)
		if not info.is_empty() and _room_list.ingest(info, ip, now):
			changed = true
	if _room_list.prune(now):
		changed = true
	if changed:
		rooms_updated.emit(_room_list.rooms())
