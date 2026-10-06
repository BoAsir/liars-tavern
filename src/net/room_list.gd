class_name RoomList
# 发现报文编解码 + 客户端房间列表:按房间 id 去重、优先非回环地址、超时移除。


const MAX_TEXT := 32
const LOOPBACK := "127.0.0.1"
const TEXT_FIELDS := ["id", "room", "host"]
const INT_FIELDS := ["players", "max", "version", "port"]

var _rooms := {}  # room_id -> {"info": Dictionary, "ip": String, "last_seen": float}


static func encode(info: Dictionary) -> PackedByteArray:
	return JSON.stringify(info).to_utf8_buffer()


static func decode(bytes: PackedByteArray) -> Dictionary:
	# 不可信的网络输入:字段缺失、类型不符、版本不同、端口越界一律丢弃
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
	out["open"] = parsed.get("open", true) == true
	return out


func ingest(info: Dictionary, ip: String, now: float) -> bool:
	var id: String = info["id"]
	var existing: Dictionary = _rooms.get(id, {})
	var chosen_ip := ip
	if not existing.is_empty() and ip == LOOPBACK and existing["ip"] != LOOPBACK:
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


func rooms() -> Array:
	var out := []
	for id in _rooms:
		var entry: Dictionary = _rooms[id]["info"].duplicate()
		entry["ip"] = _rooms[id]["ip"]
		out.append(entry)
	out.sort_custom(func(a, b): return a["room"] < b["room"])
	return out
