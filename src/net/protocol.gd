class_name Protocol
# 网络协议常量与地址解析。版本不匹配的客户端会被拒绝加入。


const VERSION := 1

# 发现端口段:同机多开时每个实例各绑定其中一个空闲端口,房主对每个端口都广播一份
const DISCOVERY_PORT := 47800
const DISCOVERY_PORT_COUNT := 4
# 游戏端口段:与发现端口段错开,被占用时依次顺延
const GAME_PORT := 47810
const GAME_PORT_ATTEMPTS := 10

const BROADCAST_INTERVAL := 1.0
const ROOM_TTL := 3.0
const JOIN_TIMEOUT := 8.0
# ENet 断线判定(毫秒):默认最长 30 秒才发现对方崩溃,缩短到数秒内
const PEER_TIMEOUT_LIMIT := 32
const PEER_TIMEOUT_MIN_MS := 3000
const PEER_TIMEOUT_MAX_MS := 8000
const MIN_PLAYERS := 2
const MAX_PLAYERS := 4
# ENet 传输层多留几个槽位,满员时仍能完成握手并收到"房间已满"的明确提示
const MAX_TRANSPORT_CLIENTS := MAX_PLAYERS + 2
const TURN_TIMEOUT := 30.0
const MAX_NAME_LENGTH := 12
const MAX_ROOM_NAME_LENGTH := 20

# 意图拒绝错误码(与 GameState 返回的 error 一致)
const ERR_NOT_YOUR_TURN := "not_your_turn"
const ERR_INVALID_PLAY := "invalid_play"
const ERR_NOTHING_TO_CHALLENGE := "nothing_to_challenge"
const ERR_MATCH_OVER := "match_over"

const ERROR_MESSAGES := {
	ERR_NOT_YOUR_TURN: "还没轮到你",
	ERR_INVALID_PLAY: "出牌不合法",
	ERR_NOTHING_TO_CHALLENGE: "本小局还没有人出牌,不能质疑",
	ERR_MATCH_OVER: "对局已结束",
}


static func discovery_ports() -> Array[int]:
	var ports: Array[int] = []
	for i in DISCOVERY_PORT_COUNT:
		ports.append(DISCOVERY_PORT + i)
	return ports


static func parse_address(text: String) -> Dictionary:
	# 支持 "IP" 与 "IP:端口";返回 {"ok", "ip", "port"} 或 {"ok": false, "error"}
	var trimmed := text.strip_edges()
	if trimmed == "":
		return _address_error("请输入房主的 IP 地址")
	var parts := trimmed.split(":")
	if parts.size() > 2:
		return _address_error("地址格式应为 IP 或 IP:端口")
	var host := parts[0]
	if host == "localhost":
		host = "127.0.0.1"
	if not _is_ipv4(host):
		return _address_error("IP 地址无效:%s" % parts[0])
	var port := GAME_PORT
	if parts.size() == 2:
		if not parts[1].is_valid_int():
			return _address_error("端口必须是数字")
		port = parts[1].to_int()
		if port < 1 or port > 65535:
			return _address_error("端口超出范围(1-65535)")
	return {"ok": true, "ip": host, "port": port}


static func format_address(ip: String, port: int) -> String:
	return ip if port == GAME_PORT else "%s:%d" % [ip, port]


static func sanitize_name(raw: String) -> String:
	return sanitize_text(raw, MAX_NAME_LENGTH)


static func sanitize_text(raw: String, max_length: int) -> String:
	# 去掉控制字符并截断:昵称/房名会显示在他人屏幕上,来源不可信
	var cleaned := ""
	for ch in raw.strip_edges():
		if ch.unicode_at(0) >= 32:
			cleaned += ch
	return cleaned.substr(0, max_length)


static func _is_ipv4(host: String) -> bool:
	var octets := host.split(".")
	if octets.size() != 4:
		return false
	for octet in octets:
		if not octet.is_valid_int() or octet.to_int() < 0 or octet.to_int() > 255:
			return false
	return true


static func _address_error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
