extends Node
# 局域网房间发现(autoload "Discovery")。
# 房主:每秒向全局广播、各网卡定向广播与回环地址的全部发现端口发送房间报文;
# 客户端:绑定发现端口段中第一个空闲端口监听,维护去重、过期的房间列表。
# 同机多开时每个实例绑定不同端口,因此同机最多 DISCOVERY_PORT_COUNT 个实例都能发现房间。


signal rooms_updated(rooms: Array)

const BIND_ADDRESS := "0.0.0.0"

var _announce := Callable()
var _sender: PacketPeerUDP = null
var _listener: PacketPeerUDP = null
var _listen_port := 0
var _room_list := RoomList.new()
var _timer: Timer = null
var _warned_targets := {}


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
	_timer.start()
	_broadcast_once()


func stop_broadcast() -> void:
	_timer.stop()
	_announce = Callable()
	if _sender != null:
		_sender.close()
	_sender = null


func is_broadcasting() -> bool:
	return _sender != null


func _broadcast_once() -> void:
	if _sender == null or not _announce.is_valid():
		return
	var payload := RoomList.encode(_announce.call())
	for target in Lan.broadcast_targets(Array(IP.get_local_addresses())):
		for port in Protocol.discovery_ports():
			_sender.set_dest_address(target, port)
			var err := _sender.put_packet(payload)
			if err != OK and not _warned_targets.has(target):
				# 某些网卡/无网络时全局广播会失败,只提示一次,其余目标照常发送
				_warned_targets[target] = true
				push_warning("房间广播发送到 %s 失败(错误 %d)" % [target, err])


# —— 客户端 ——

func start_listening() -> bool:
	stop_listening()
	_room_list.clear()
	for port in Protocol.discovery_ports():
		var udp := PacketPeerUDP.new()
		if udp.bind(port, BIND_ADDRESS) == OK:
			_listener = udp
			_listen_port = port
			break
	rooms_updated.emit([])
	return _listener != null


func stop_listening() -> void:
	if _listener != null:
		_listener.close()
	_listener = null
	_listen_port = 0


func is_listening() -> bool:
	return _listener != null


func listen_port() -> int:
	return _listen_port


func get_rooms() -> Array:
	return _room_list.rooms()


func _process(_delta: float) -> void:
	if _listener == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var changed := false
	while _listener.get_available_packet_count() > 0:
		var bytes := _listener.get_packet()
		var ip := _listener.get_packet_ip()
		var info := RoomList.decode(bytes)
		if not info.is_empty() and _room_list.ingest(info, ip, now):
			changed = true
	if _room_list.prune(now):
		changed = true
	if changed:
		rooms_updated.emit(_room_list.rooms())
