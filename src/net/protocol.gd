class_name Protocol
# 网络协议常量与地址解析。版本不匹配的客户端会被拒绝加入。


# v2:视线同步消息(rpc_look / rpc_look_relay);v3:消息里加上脖子偏移;v4:左轮改 5 膛(规则变了);
# v5:开房选玩法 + 德州扑克(发现报文与握手带玩法,新增 rpc_poker_intent);
#     等待厅自选形象(新增 rpc_lobby_species 意图;lobby_state、game_started 每位玩家带 species 下标);
#     炸弹猫(玩法 id bomb_cat,新增字典意图 rpc_session_intent)。三者都并入未发布的 0.7.0,不另升版本
const VERSION := 5

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
# 所有玩法的绝对人数上限(传输层槽位、发现报文校验);各玩法自己的上限一律用 GameMode.max_players(mode)
const MAX_PLAYERS := 8
# 已发布的 v3 客户端丢弃人数上限超过 4 的发现报文:报文里给它们看的旧字段 max/players 压在这以内,
# 旧玩家才看得到德州房间、能从房主那里更新。冻结,不随玩法上限变
const LEGACY_MAX_PLAYERS := 4
# ENet 传输层多留几个槽位,满员时仍能完成握手并收到"房间已满"的明确提示
const MAX_TRANSPORT_CLIENTS := MAX_PLAYERS + 2
const TURN_TIMEOUT := 30.0
# 视线同步走的 ENet 通道:与可靠的状态/事件分开,丢包重传不会拖住它们
const GAZE_CHANNEL := 1
const MAX_NAME_LENGTH := 12
const MAX_ROOM_NAME_LENGTH := 20
# 加入请求里的原始昵称超过这个长度直接拒绝(正常客户端只发清洗过的短昵称)
const MAX_RAW_NAME_LENGTH := 256
# 昵称黑名单:不能含有这些字
const NAME_BLACKLIST_CHARS := ["笑", "晓", "马", "飞", "火", "狐", "楚", "储"]
# 清洗文本时最多看原文开头 max_length 的这么多倍:耗时与原文长度无关
const SANITIZE_SCAN_FACTOR := 4

# 中文输入法常打出的字符(按码位):全角冒号/句号/全角句点/半角句号 → 半角;全角数字按码位换算
const ADDRESS_PUNCTUATION := {0xFF1A: ":", 0x3002: ".", 0xFF0E: ".", 0xFF61: "."}
const FULLWIDTH_DIGIT_ZERO := 0xFF10
# 地址里一律去掉的空白(按码位):空格、制表符、全角空格、不换行空格
const ADDRESS_SPACES := [0x20, 0x09, 0x3000, 0xA0]

# 意图拒绝错误码(与 GameState 返回的 error 一致)
const ERR_NOT_YOUR_TURN := "not_your_turn"
const ERR_INVALID_PLAY := "invalid_play"
const ERR_NOTHING_TO_CHALLENGE := "nothing_to_challenge"
const ERR_MATCH_OVER := "match_over"

const ERROR_MESSAGES := {
	ERR_NOT_YOUR_TURN: "还没轮到你",
	ERR_INVALID_PLAY: "出牌不合法",
	# 本小局还没人出牌,或上一手正是自己出的(其他人断线后回合绕回)
	ERR_NOTHING_TO_CHALLENGE: "现在没有可以质疑的出牌",
	ERR_MATCH_OVER: "对局已结束",
}


static func discovery_ports() -> Array[int]:
	var ports: Array[int] = []
	for i in DISCOVERY_PORT_COUNT:
		ports.append(DISCOVERY_PORT + i)
	return ports


static func parse_address(text: String) -> Dictionary:
	# 支持 "IP" 与 "IP:端口";返回 {"ok", "ip", "port"} 或 {"ok": false, "error"}
	var normalized := normalize_address(text)
	if normalized == "":
		return _address_error("请输入房主的 IP 地址")
	var parts := normalized.split(":")
	if parts.size() > 2:
		return _address_error("地址格式应为 IP 或 IP:端口")
	var host := parts[0]
	if host.to_lower() == "localhost":
		host = Lan.LOOPBACK
	var ip_value := Lan.ipv4_to_int(host)
	if ip_value < 0:
		return _address_error("IP 地址无效:%s" % parts[0])
	var port := GAME_PORT
	if parts.size() == 2:
		if not parts[1].is_valid_int():
			return _address_error("端口必须是数字")
		port = parts[1].to_int()
		if port < 1 or port > 65535:
			return _address_error("端口超出范围(1-65535)")
	# 规范写法(去掉前导零等),免得底层解析出不同的地址
	return {"ok": true, "ip": Lan.int_to_ipv4(ip_value), "port": port}


static func normalize_address(text: String) -> String:
	# 全角冒号/句号/数字转半角,去掉所有空白:照着等待厅抄地址时常开着中文标点
	var out := text.strip_edges()
	for code in ADDRESS_PUNCTUATION:
		out = out.replace(String.chr(code), ADDRESS_PUNCTUATION[code])
	for digit in 10:
		out = out.replace(String.chr(FULLWIDTH_DIGIT_ZERO + digit), str(digit))
	for code in ADDRESS_SPACES:
		out = out.replace(String.chr(code), "")
	return out


static func format_address(ip: String, port: int) -> String:
	return ip if port == GAME_PORT else "%s:%d" % [ip, port]


static func sanitize_name(raw: String) -> String:
	return sanitize_text(raw, MAX_NAME_LENGTH)


static func contains_blacklist_chars(name: String) -> bool:
	# 检查昵称是否含有黑名单字符
	for ch in NAME_BLACKLIST_CHARS:
		if name.find(ch) != -1:
			return true
	return false


static func validate_name(name: String) -> Dictionary:
	# 返回 {"ok": true} 或 {"ok": false, "error": "错误信息"}
	if name == "":
		return {"ok": false, "error": "昵称不能为空"}
	if contains_blacklist_chars(name):
		return {"ok": false, "error": "昵称不能含有敏感字"}
	return {"ok": true}


static func sanitize_text(raw: String, max_length: int) -> String:
	# 去掉首尾空白与所有控制字符并截断:昵称/房名会显示在他人屏幕上,来源不可信。
	# 只处理开头一段(与 max_length 成正比),百万字符的恶意输入也不会卡住房主或客户端
	var window := raw.substr(0, max_length * SANITIZE_SCAN_FACTOR)
	return window.strip_edges().strip_escapes().substr(0, max_length)


static func _address_error(message: String) -> Dictionary:
	return {"ok": false, "error": message}
