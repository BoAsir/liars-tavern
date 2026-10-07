class_name UpdateServer
extends Node
# 房主开房时顺带提供的极简 HTTP 文件服务(TCP,端口号与游戏端口相同):只回答固定几个路径的 GET,
# 内容是房主自己正在运行的那份签名更新包。客户端自己验签名,这里不必可信,但要扛得住乱来的连接:
# 限制总连接数与单个地址的连接数、请求头长度、空闲与总时长,只认白名单路径;
# 正文直接从内存里的那一份分块写出,不按请求复制整个文件。


const MAX_CLIENTS := 8
const MAX_PER_ADDRESS := 2
const MAX_REQUEST_BYTES := 2048
const IDLE_TIMEOUT := 15.0
const MAX_LIFETIME := 120.0   # 一个连接最多活这么久(秒):慢慢读的连接不能一直占着名额
const CHUNK := 256 * 1024

var _server: TCPServer = null
var _files := {}      # URL 路径 -> PackedByteArray
var _clients: Array = []   # [{"peer", "address", "request", "head", "body", "sent", "idle", "age"}]


func start(port: int, files: Dictionary) -> Error:
	stop()
	_server = TCPServer.new()
	var err := _server.listen(port)
	if err != OK:
		_server = null
		return err
	_files = files
	return OK


func stop() -> void:
	for client in _clients:
		client["peer"].disconnect_from_host()
	_clients = []
	if _server != null:
		_server.stop()
	_server = null
	_files = {}


func is_serving() -> bool:
	return _server != null and _server.is_listening()


func _process(delta: float) -> void:
	if _server == null:
		return
	while _server.is_connection_available():
		var peer := _server.take_connection()
		var address := peer.get_connected_host()
		if _clients.size() >= MAX_CLIENTS or _count_from(address) >= MAX_PER_ADDRESS:
			peer.disconnect_from_host()
			continue
		_clients.append({"peer": peer, "address": address, "request": PackedByteArray(), "head": PackedByteArray(),
			"body": PackedByteArray(), "sent": 0, "idle": 0.0, "age": 0.0})
	for client in _clients.duplicate():
		if not _serve(client, delta):
			client["peer"].disconnect_from_host()
			_clients.erase(client)


func _count_from(address: String) -> int:
	return _clients.filter(func(c): return c["address"] == address).size()


func _serve(client: Dictionary, delta: float) -> bool:
	# 返回 false 表示这个连接该关了
	var peer: StreamPeerTCP = client["peer"]
	peer.poll()
	if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return false
	client["idle"] += delta
	client["age"] += delta
	if client["idle"] > IDLE_TIMEOUT or client["age"] > MAX_LIFETIME:
		return false
	if client["head"].is_empty():
		return _read_request(client, peer)
	# 先写响应头,再从共享的正文里按偏移切块写出(PackedByteArray 写时复制,不改它就不会复制整份)
	var head_size: int = client["head"].size()
	var total: int = head_size + client["body"].size()
	var sent: int = client["sent"]
	if sent >= total:
		return false
	var chunk: PackedByteArray
	if sent < head_size:
		chunk = client["head"].slice(sent)
	else:
		chunk = client["body"].slice(sent - head_size, mini(sent - head_size + CHUNK, client["body"].size()))
	var result := peer.put_partial_data(chunk)
	if result[0] != OK:
		return false
	if result[1] > 0:
		client["sent"] += result[1]
		client["idle"] = 0.0
	return true


func _read_request(client: Dictionary, peer: StreamPeerTCP) -> bool:
	var available := peer.get_available_bytes()
	if available > 0:
		var result := peer.get_partial_data(mini(available, MAX_REQUEST_BYTES))
		if result[0] != OK:
			return false
		client["request"].append_array(result[1])
		client["idle"] = 0.0
	var text: String = client["request"].get_string_from_utf8()
	if not text.contains("\r\n\r\n"):
		if client["request"].size() >= MAX_REQUEST_BYTES:
			_set_response(client, [400, PackedByteArray()])
		return true
	_set_response(client, respond_to(text.get_slice("\r\n", 0)))
	return true


func _set_response(client: Dictionary, status_body: Array) -> void:
	client["body"] = status_body[1]
	client["head"] = head_for(status_body[0], status_body[1].size())


func respond_to(request_line: String) -> Array:
	# 返回 [状态码, 正文];正文是 _files 里的同一份,不复制
	var parts := request_line.split(" ")
	if parts.size() != 3 or not parts[2].begins_with("HTTP/1."):
		return [400, PackedByteArray()]
	if parts[0] != "GET":
		return [405, PackedByteArray()]
	if not _files.has(parts[1]):
		return [404, PackedByteArray()]
	return [200, _files[parts[1]]]


static func head_for(status: int, length: int) -> PackedByteArray:
	var reason: String = {200: "OK", 400: "Bad Request", 404: "Not Found", 405: "Method Not Allowed"}.get(status, "Error")
	return ("HTTP/1.1 %d %s\r\nContent-Type: application/octet-stream\r\nContent-Length: %d\r\nConnection: close\r\n\r\n" \
		% [status, reason, length]).to_utf8_buffer()
