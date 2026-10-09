class_name RoomList
# 发现报文编解码 + 客户端房间列表:按房间 id 去重、优先非回环地址、超时移除、限制条数。
# 解码后的房间:{"id", "room", "host", "version", "port", "open", "mode", "playing", "seated", "cap",
#   "compatible", "build", "ver", "update", "plat"};列表里另加 "ip"。
# 报文里的 players/max 是给已发布的 v3 解析器看的旧字段(德州房间压在 4 以内),解码后只留 seated/cap。


const MAX_TEXT := 32
# 局域网里不会有这么多真实房间;防止伪造报文(每包一个新 id)把列表与界面撑爆
const MAX_ROOMS := 64
const MAX_BUILD := 1_000_000
const MAX_VERSION_TEXT := 16
const TEXT_FIELDS := ["id", "room", "host"]
const INT_FIELDS := ["version", "port"]

var _rooms := {}  # room_id -> {"info": Dictionary, "ip": String, "last_seen": float}
var _warned_full := false


static func encode(info: Dictionary) -> PackedByteArray:
	return JSON.stringify(info).to_utf8_buffer()


static func decode(bytes: PackedByteArray) -> Dictionary:
	# 不可信的网络输入:字段缺失、类型不符、端口或人数越界一律丢弃
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
		if not _is_number(parsed.get(key)):
			return {}
		out[key] = int(parsed[key])
	if out["port"] < 1 or out["port"] > 65535:
		return {}
	var open = parsed.get("open", true)
	if not open is bool:
		return {}  # 和其他字段一样按类型丢弃:非 bool 与 bool 比较在 GDScript 里是运行时错误
	out["open"] = open
	if not _decode_mode(parsed, out) or not _decode_counts(parsed, out):
		return {}
	# 协议版本不同或玩法不认识的房间也留着(标成不兼容):房主版本更新时,界面可以提示从房主那里更新
	out["compatible"] = out["version"] == Protocol.VERSION and GameMode.is_valid(out["mode"])
	return _decode_build(parsed, out)


static func _decode_mode(parsed: Dictionary, out: Dictionary) -> bool:
	# v4 字段:旧房主不带,缺了按骗子酒馆、没开局处理;带了但类型不对照样整包丢弃。
	# 玩法 id 只截断不清洗:界面只显示认识的玩法名,不会把它原样画出来
	var mode = parsed.get("mode", GameMode.LIARS)
	var playing = parsed.get("playing", false)
	if not mode is String or not playing is bool:
		return false
	out["mode"] = mode.substr(0, MAX_TEXT)
	out["playing"] = playing
	return true


static func _decode_counts(parsed: Dictionary, out: Dictionary) -> bool:
	# 人数会驱动主菜单的座位显示:越界值能让客户端卡死或崩溃。
	# 带 cap/seated 的 v4 报文以它们为准(两个必须同时出现);没有的(旧房主)用 players/max
	var with_cap := parsed.has("cap") or parsed.has("seated")
	var seated = parsed.get("seated") if with_cap else parsed.get("players")
	var cap = parsed.get("cap") if with_cap else parsed.get("max")
	if not _is_number(seated) or not _is_number(cap):
		return false
	if not _counts_valid(int(seated), int(cap), _cap_limit(out["mode"])):
		return false
	out["seated"] = int(seated)
	out["cap"] = int(cap)
	return true


static func _cap_limit(mode: String) -> int:
	# 认识的玩法按它自己的上限(骗子酒馆报 5 人照样丢弃);不认识的玩法(更新版本的)只卡绝对上限,
	# 这样它也能列出来、提示从房主那里更新
	return GameMode.max_players(mode) if GameMode.is_valid(mode) else Protocol.MAX_PLAYERS


static func _is_number(value: Variant) -> bool:
	# JSON 里的数字解析出来是 float;bool 不算数字
	return value is float or value is int


static func _decode_build(parsed: Dictionary, out: Dictionary) -> Dictionary:
	# 版本信息是后加的字段:旧房主不带,缺了按 0 / 空串 / 不提供更新处理;带了但类型不对照样整包丢弃
	var build = parsed.get("build", 0)
	var ver = parsed.get("ver", "")
	var update = parsed.get("update", false)
	var plat = parsed.get("plat", "")
	if not (build is float or build is int) or not ver is String or not update is bool or not plat is String:
		return {}
	out["plat"] = Protocol.sanitize_text(plat, MAX_VERSION_TEXT)
	out["build"] = clampi(int(build), 0, MAX_BUILD)
	out["ver"] = Protocol.sanitize_text(ver, MAX_VERSION_TEXT)
	out["update"] = update
	return out


static func _counts_valid(seated: int, cap: int, limit: int) -> bool:
	return cap >= Protocol.MIN_PLAYERS and cap <= limit and seated >= 0 and seated <= cap


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
