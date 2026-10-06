class_name RoomList
# 发现报文编解码 + 客户端房间列表:按房间 id 去重、优先非回环地址、超时移除、限制条数。


const MAX_TEXT := 32
# 局域网里不会有这么多真实房间;防止伪造报文(每包一个新 id)把列表与界面撑爆
const MAX_ROOMS := 64
const TEXT_FIELDS := ["id", "room", "host"]
const INT_FIELDS := ["players", "max", "version", "port"]

var _rooms := {}  # room_id -> {"info": Dictionary, "ip": String, "last_seen": float}
var _warned_full := false


static func encode(info: Dictionary) -> PackedByteArray:
	return JSON.stringify(info).to_utf8_buffer()


static func decode(bytes: PackedByteArray) -> Dictionary:
	# 不可信的网络输入:字段缺失、类型不符、版本不同、端口或人数越界一律丢弃
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return {}
	var parsed = json.data
	if not parsed is Dictionary:
		return {}
	var out := {}
	for key in TEXT_FIELDS:
		if not parsed.get(key) is String:
			return {}
		out[key] = Protocol.sanitize_text(parsed[key], MAX_TEXT)
	for key in INT_FIELDS:
		var value = parsed.get(key)
		if not (value is float or value is int):
			return {}
		out[key] = int(value)
	if out["version"] != Protocol.VERSION:
		return {}
	if out["port"] < 1 or out["port"] > 65535:
		return {}
	if not _counts_valid(out["players"], out["max"]):
		return {}
	out["open"] = parsed.get("open", true) == true
	return out


static func _counts_valid(players: int, capacity: int) -> bool:
	# 人数会驱动主菜单的座位圆点("●".repeat):越界值能让客户端卡死或崩溃
	return capacity >= Protocol.MIN_PLAYERS and capacity <= Protocol.MAX_PLAYERS \
		and players >= 0 and players <= capacity


func ingest(info: Dictionary, ip: String, now: float) -> bool:
	var id: String = info["id"]
	var existing: Dictionary = _rooms.get(id, {})
	if existing.is_empty() and _rooms.size() >= MAX_ROOMS:
		_warn_full_once()
		return false
	var chosen_ip := ip
	if not existing.is_empty() and ip == Lan.LOOPBACK and existing["ip"] != Lan.LOOPBACK:
		chosen_ip = existing["ip"]
	var changed: bool = existing.is_empty() or existing["info"] != info or existing["ip"] != chosen_ip
	_rooms[id] = {"info": info, "ip": chosen_ip, "last_seen": now}
	return changed


func prune(now: float) -> bool:
	var changed := false
	for id in _rooms.keys():
		if now - _rooms[id]["last_seen"] > Protocol.ROOM_TTL:
			_rooms.erase(id)
			changed = true
	return changed


func clear() -> void:
	_rooms = {}
	_warned_full = false


func _warn_full_once() -> void:
	# 满了说明网络上有异常广播;只提示一次,避免洪泛时刷屏
	if not _warned_full:
		_warned_full = true
		push_warning("房间列表已满(%d 个),忽略新出现的房间:局域网里可能有异常的发现广播" % MAX_ROOMS)


func rooms() -> Array:
	var out := []
	for id in _rooms:
		var entry: Dictionary = _rooms[id]["info"].duplicate()
		entry["ip"] = _rooms[id]["ip"]
		out.append(entry)
	out.sort_custom(func(a, b): return a["room"] < b["room"])
	return out
