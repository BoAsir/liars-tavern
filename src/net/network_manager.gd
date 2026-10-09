extends Node
# 网络管理(autoload "Net"):房主权威 listen-server。
# 房主持有唯一 GameState 与等待厅名单;客户端只发意图、收视图与事件。
# UI 层只使用本类的公开方法、只读属性与信号,不直接触碰 multiplayer API。
# 点对点的 RPC 一律经 _send_to 发出:对方没连着就不发(离线测试里对未知 peer 调 rpc_id 会报引擎错误)。


signal lobby_updated(players: Array)
signal joined_lobby
signal left_lobby(reason: String)
signal join_failed(reason: String)
signal game_started(seats: Array)
signal state_public_updated(state: Dictionary)
signal state_private_updated(state: Dictionary)
signal game_events(events: Array)
signal intent_rejected(code: String)
signal returned_to_lobby
signal gaze_updated(pid: int, point: Vector3, neck: Vector3, active: bool)   # 他人视线落点(发送者座位坐标系)与脖子偏移

const HOST_ID := LobbyModel.HOST_ID
const DISCONNECT_GRACE := 1.0

# —— 只读状态(UI 读取) ——
var player_name := ""
var is_host := false
var in_game := false
var lobby_players: Array = []
var lobby_meta := {}       # {"room", "host", "addresses", "port", "mode"}
var seats: Array = []      # 本局座位顺序 [{"pid", "name"}]
var last_public := {}
var last_private := {}
var game_mode := GameMode.DEFAULT   # 房主:开房时选的玩法;客户端:来自等待厅 meta 或开局 info

var _session_active := false
var _joining := false
var _awaiting_game := false        # 仅客户端:对局中入座已获准,等房主发来牌局信息(rpc_game_started)
var _lobby: LobbyModel = null      # 仅房主
var _gs: GameState = null          # 仅房主
var _match_names := {}
var _room_id := ""
var _room_name := ""
var _port := Protocol.GAME_PORT
var _turn_timer: Timer = null
var _join_timer: Timer = null
var _anim_left := 0.0              # 仅房主:客户端还要演多久(按 Pacing 预算估),随时间递减


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_host)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_host_disconnected)
	_turn_timer = _make_timer(_on_turn_timeout)
	_join_timer = _make_timer(_on_join_timeout)


func _process(delta: float) -> void:
	# delta 与 Timer 一样受 Engine.time_scale 影响,两者同步流逝
	if _anim_left > 0.0:
		_anim_left = maxf(_anim_left - delta, 0.0)


func my_pid() -> int:
	return multiplayer.get_unique_id()


# —— 建房 / 加入 / 离开 ——

func host_game(pname: String, room_name: String, preferred_port := 0, mode := GameMode.DEFAULT) -> Error:
	# 玩法开房时选定,开房后不能改(想换玩法就重开房间)
	if not GameMode.is_valid(mode):
		push_error("开房失败:未知玩法 %s" % mode)
		return ERR_INVALID_PARAMETER
	var validation := Protocol.validate_name(Protocol.sanitize_name(pname))
	if not validation["ok"]:
		push_warning("开房失败:%s" % validation["error"])
		return ERR_INVALID_PARAMETER
	leave()
	var created := _create_server(preferred_port)
	if created["error"] != OK:
		return created["error"]
	multiplayer.multiplayer_peer = created["peer"]
	(multiplayer as SceneMultiplayer).server_relay = false
	_open_room(pname, room_name, created["port"], mode)
	# 游戏端口号的 TCP 上顺带提供更新文件(ENet 走 UDP,互不占用)
	Updater.start_serving(_port)
	Discovery.start_broadcast(_room_announcement)
	joined_lobby.emit()
	_broadcast_lobby()
	return OK


func _open_room(pname: String, room_name: String, port: int, mode: String) -> void:
	# 房主一侧的房间状态,不碰网络:离线测试据此搭出房主
	_port = port
	game_mode = mode
	player_name = Protocol.sanitize_name(pname)
	_room_name = Protocol.sanitize_text(room_name, Protocol.MAX_ROOM_NAME_LENGTH)
	_room_id = "%08x%08x" % [randi(), randi()]
	is_host = true
	_session_active = true
	_lobby = LobbyModel.new()
	_lobby.add_host(player_name)


func join_game(pname: String, address_text: String) -> void:
	var validation := Protocol.validate_name(Protocol.sanitize_name(pname))
	if not validation["ok"]:
		join_failed.emit(validation["error"])
		return
	var addr := Protocol.parse_address(address_text)
	if not addr["ok"]:
		join_failed.emit(addr["error"])
		return
	leave()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(addr["ip"], addr["port"])
	if err != OK:
		join_failed.emit("无法发起连接(错误 %d)" % err)
		return
	multiplayer.multiplayer_peer = peer
	player_name = Protocol.sanitize_name(pname)
	_session_active = true
	_joining = true
	_join_timer.start(Protocol.JOIN_TIMEOUT)


func leave() -> void:
	# 先清标志再关闭连接:关闭过程中触发的断线回调据此忽略
	_session_active = false
	_joining = false
	_awaiting_game = false
	is_host = false
	in_game = false
	game_mode = GameMode.DEFAULT
	Discovery.stop_broadcast()
	Updater.stop_serving()
	_turn_timer.stop()
	_join_timer.stop()
	_anim_left = 0.0
	var peer := multiplayer.multiplayer_peer
	if peer is ENetMultiplayerPeer:
		peer.close()
	multiplayer.multiplayer_peer = null
	_lobby = null
	_gs = null
	lobby_players = []
	lobby_meta = {}
	seats = []
	last_public = {}
	last_private = {}


func end_session(reason := "") -> void:
	# 结束联机并让界面回到主菜单;reason 非空时主菜单会弹出说明(主动离开传空串)
	leave()
	left_lobby.emit(reason)


func _create_server(preferred_port: int) -> Dictionary:
	# preferred_port > 0 时优先绑定它(测试隔离用),失败再走默认端口段
	var candidates: Array[int] = []
	if preferred_port > 0:
		candidates.append(preferred_port)
	for i in Protocol.GAME_PORT_ATTEMPTS:
		candidates.append(Protocol.GAME_PORT + i)
	var last_err := ERR_CANT_CREATE
	for port in candidates:
		var peer := ENetMultiplayerPeer.new()
		last_err = peer.create_server(port, Protocol.MAX_TRANSPORT_CLIENTS)
		if last_err == OK:
			return {"error": OK, "peer": peer, "port": port}
	return {"error": last_err}


func _room_announcement() -> Dictionary:
	var cap := max_players()
	var seated := _lobby.size() if _lobby != null else 0
	var legacy_max := mini(cap, Protocol.LEGACY_MAX_PLAYERS)
	return {
		"id": _room_id,
		"room": _room_name,
		"host": player_name,
		# 旧字段压在已发布的 v3 客户端接受的范围里(上限 4):旧玩家也看得到德州房间、能从房主更新;
		# 真实人数与玩法上限在 v4 字段 seated/cap 里
		"players": mini(seated, legacy_max),
		"max": legacy_max,
		"seated": seated,
		"cap": cap,
		"mode": game_mode,
		"playing": in_game,
		"version": Protocol.VERSION,
		"port": _port,
		"open": _lobby != null and seated < cap and (not in_game or _accepting_late_join()),
		"build": BuildInfo.build(),
		"ver": BuildInfo.version(),
		"update": Updater.is_serving(),   # 能从这个房主这里下载他正在运行的版本
		"plat": BuildInfo.platform(),     # 更新包按平台分:只有同平台的玩家能从这里更新
	}


func _accepting_late_join() -> bool:
	# 对局中还收不收新玩家(规格 §3.3):德州现金局在会话没散局、没结算时收,骗子酒馆永远不收。
	# 德州会话由网络会话部分接入(规格 §4.2),在那之前没有能接人的会话
	return false


# —— 连接生命周期 ——

func _on_connected_to_host() -> void:
	if _joining:
		_shorten_peer_timeout(HOST_ID)
		_send_to(HOST_ID, "rpc_join_request", [player_name, Protocol.VERSION])


func _on_peer_connected(id: int) -> void:
	if is_host and _session_active:
		_shorten_peer_timeout(id)


func _shorten_peer_timeout(id: int) -> void:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null:
		return
	var packet_peer := peer.get_peer(id)
	if packet_peer != null:
		packet_peer.set_timeout(
			Protocol.PEER_TIMEOUT_LIMIT, Protocol.PEER_TIMEOUT_MIN_MS, Protocol.PEER_TIMEOUT_MAX_MS
		)


func _on_connection_failed() -> void:
	if _joining:
		_fail_join("连接失败:请确认房主 IP、端口与防火墙设置")


func _on_join_timeout() -> void:
	if not _joining:
		return
	if _awaiting_game:
		_fail_join("房主没有发来牌局信息")
	else:
		_fail_join("连接超时:%d 秒内没有收到房主响应" % int(Protocol.JOIN_TIMEOUT))


func _on_host_disconnected() -> void:
	if not _session_active:
		return
	if _joining:
		_fail_join("房主断开了连接")
	else:
		end_session("与房主断开连接,房间已解散")


func _on_peer_disconnected(id: int) -> void:
	if not is_host or not _session_active:
		return
	if in_game and _gs != null:
		var events := _gs.eliminate_player(id)
		if not events.is_empty():
			_after_action(events)
	if _lobby.remove(id):
		_broadcast_lobby()


func _fail_join(reason: String) -> void:
	leave()
	join_failed.emit(reason)


# —— 加入握手 ——

@rpc("any_peer", "call_remote", "reliable")
func rpc_join_request(pname: String, version: int) -> void:
	# 参数与 @rpc 模式冻结(规格 §3.3):旧版本靠它收到「版本不匹配」。处理放在可离线测试的函数里
	_handle_join_request(multiplayer.get_remote_sender_id(), pname, version)


func _handle_join_request(id: int, pname: String, version: int) -> void:
	if not is_host or not _session_active or _lobby.has(id):
		return
	var deny := _join_denial(id, pname, version)
	if deny != "":
		_send_to(id, "rpc_join_denied", [deny])
		_disconnect_peer_later(id)
		return
	_lobby.add_member(id, pname)
	# 获准里带上玩法:客户端一进等待厅就要按玩法摆桌,带 meta 的名单比它晚到。
	# 对局中入座(德州)的人先不进等待厅:客户端保持「加入中」,等随后发来的牌局信息
	_send_to(id, "rpc_join_accepted", [{"in_game": in_game, "mode": game_mode}])
	_broadcast_lobby()


func _join_denial(id: int, pname: String, version: int) -> String:
	# 昵称来自不可信的对端:超长的在做任何逐字处理前就拒绝;黑名单在sanitize之后检查
	if pname.length() > Protocol.MAX_RAW_NAME_LENGTH:
		push_warning("拒绝连接 %d 的加入请求:昵称长度 %d 超过上限 %d"
			% [id, pname.length(), Protocol.MAX_RAW_NAME_LENGTH])
		return "昵称过长"
	var sanitized := Protocol.sanitize_name(pname)
	var validation := Protocol.validate_name(sanitized)
	if not validation["ok"]:
		return validation["error"]
	return _lobby.check_join(version, in_game, game_mode, _accepting_late_join())


@rpc("authority", "call_remote", "reliable")
func rpc_join_denied(reason: String) -> void:
	if _joining:
		_fail_join(reason)


@rpc("authority", "call_remote", "reliable")
func rpc_join_accepted(info: Dictionary) -> void:
	# info = {"in_game": bool, "mode": String}。玩法在发 joined_lobby 之前写好:等待厅一建起来就按它摆桌。
	# 对局中入座:不进等待厅,「加入中」与加入计时都保持,直到 rpc_game_started 到达;
	# 超时按「房主没有发来牌局信息」失败
	if not _joining:
		return
	_take_mode(info.get("mode"))
	var late = info.get("in_game", false)
	if late is bool and late:
		_awaiting_game = true
		return
	_finish_join()
	joined_lobby.emit()


func _finish_join() -> void:
	_joining = false
	_awaiting_game = false
	_join_timer.stop()


func _take_mode(mode: Variant) -> void:
	# 客户端的玩法来自房主(获准、等待厅 meta、开局 info),是不可信输入:
	# 认识的才写入,不认识的忽略并保留当前玩法
	if GameMode.is_valid(mode):
		game_mode = mode


# —— 等待厅 ——

func set_ready(ready: bool) -> void:
	if not is_host and _session_active and not _joining:
		_send_to(HOST_ID, "rpc_lobby_ready", [ready])


@rpc("any_peer", "call_remote", "reliable")
func rpc_lobby_ready(ready: bool) -> void:
	if not is_host or in_game:
		return
	if _lobby.set_ready(multiplayer.get_remote_sender_id(), ready):
		_broadcast_lobby()


func kick(id: int) -> void:
	if not is_host or in_game or not _lobby.remove(id):
		return
	_send_to(id, "rpc_kicked")
	_disconnect_peer_later(id)
	_broadcast_lobby()


@rpc("authority", "call_remote", "reliable")
func rpc_kicked() -> void:
	if _session_active:
		end_session("你被房主请出了房间")


func can_start() -> bool:
	return is_host and not in_game and _lobby != null and _lobby.can_start()


func _broadcast_lobby() -> void:
	var players := _lobby.view()
	var meta := {
		"room": _room_name,
		"host": player_name,
		"addresses": Lan.local_private_ipv4s(),
		"port": _port,
		"mode": game_mode,
	}
	_apply_lobby(players, meta)
	_send_to_members("rpc_lobby_state", [players, meta])


@rpc("authority", "call_remote", "reliable")
func rpc_lobby_state(players: Array, meta: Dictionary) -> void:
	_apply_lobby(players, meta)


func _apply_lobby(players: Array, meta: Dictionary) -> void:
	_take_mode(meta.get("mode"))
	lobby_players = players
	lobby_meta = meta
	lobby_updated.emit(players)


func _disconnect_peer_later(id: int) -> void:
	# 给对方留时间收到拒绝/踢出原因;对方通常会先自行断开
	await get_tree().create_timer(DISCONNECT_GRACE).timeout
	var peer := multiplayer.multiplayer_peer
	if is_host and peer is ENetMultiplayerPeer and multiplayer.get_peers().has(id):
		peer.disconnect_peer(id)


func _send_to_members(method: StringName, args: Array) -> void:
	# 只发给已完成握手的成员;握手中/被拒绝的连接不在名单里,正在断开的由 _send_to 跳过
	for id in _lobby.seat_order():
		if id != HOST_ID:
			_send_to(id, method, args)


func _send_to(id: int, method: StringName, args: Array = []) -> void:
	# 点对点 RPC 的唯一出口:只发给连接仍然有效的对端
	if _is_connected(id):
		callv("rpc_id", [id, method] + args)


func _is_connected(id: int) -> bool:
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if peer == null or not multiplayer.get_peers().has(id):
		return false
	var packet_peer := peer.get_peer(id)
	return packet_peer != null and packet_peer.get_state() == ENetPacketPeer.STATE_CONNECTED


# —— 开局与状态同步 ——

func start_game() -> void:
	if not can_start():
		return
	in_game = true
	last_public = {}
	last_private = {}
	var order := _lobby.seat_order()
	_match_names = _lobby.names()
	seats = []
	for pid in order:
		seats.append({"pid": pid, "name": _match_names[pid]})
	_gs = GameState.new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_gs.start_match(order, rng)
	_send_to_members("rpc_game_started", [seats, {"mode": game_mode, "late": false}])
	game_started.emit(seats)
	# 各端进入牌桌先播开场运镜,第一局的发牌演出排在它后面
	_anim_left = Pacing.INTRO
	_after_action([_gs.round_started_event()])


@rpc("authority", "call_remote", "reliable")
func rpc_game_started(p_seats: Array, info: Dictionary) -> void:
	# info = {"mode", "late"}:发出 game_started 之前玩法已设好。对局中入座的人到这里才算加入完成,
	# 直接进牌桌、不经过等待厅;房主总是先发获准(可靠有序),没获准就到的牌局信息不理
	if _joining and not _awaiting_game:
		return
	_take_mode(info.get("mode"))
	if _joining:
		_finish_join()
	in_game = true
	seats = p_seats
	last_public = {}
	last_private = {}
	game_started.emit(seats)


func _sync_all() -> void:
	var pub := Views.public_state(_gs, _match_names, _turn_time_left())
	_apply_public(pub)
	_send_to_members("rpc_state_public", [pub])
	for pid in _gs.seat_order:
		var priv := Views.private_state(_gs, pid)
		if pid == HOST_ID:
			_apply_private(priv)
		else:
			_send_to(pid, "rpc_state_private", [priv])


@rpc("authority", "call_remote", "reliable")
func rpc_state_public(state: Dictionary) -> void:
	_apply_public(state)


@rpc("authority", "call_remote", "reliable")
func rpc_state_private(state: Dictionary) -> void:
	_apply_private(state)


func _apply_public(state: Dictionary) -> void:
	last_public = state
	state_public_updated.emit(state)


func _apply_private(state: Dictionary) -> void:
	last_private = state
	state_private_updated.emit(state)


# —— 意图 ——

func submit_play(indices: Array) -> void:
	if not in_game:
		return
	if is_host:
		_handle_intent(HOST_ID, "play", indices)
	else:
		_send_to(HOST_ID, "rpc_intent_play", [indices])


func submit_challenge() -> void:
	if not in_game:
		return
	if is_host:
		_handle_intent(HOST_ID, "challenge", [])
	else:
		_send_to(HOST_ID, "rpc_intent_challenge")


func max_players() -> int:
	# 当前玩法的人数上限
	return GameMode.max_players(game_mode)


# —— 德州意图:接口先行(德州规格 §4.3),由网络会话实现 ——

func submit_poker_action(_action: String, _amount := 0) -> void:
	# fold / check / call / raise(amount 为「加注到」)/ allin
	pass


func request_rebuy() -> void:
	submit_poker_action(PokerRules.REBUY)


func request_spectate() -> void:
	submit_poker_action(PokerRules.SPECTATE)


func end_poker_session() -> void:
	# 仅房主:有进行中的手牌就打完这一手再结算
	pass


@rpc("any_peer", "call_remote", "reliable")
func rpc_intent_play(indices: Array) -> void:
	if is_host:
		_handle_intent(multiplayer.get_remote_sender_id(), "play", indices)


@rpc("any_peer", "call_remote", "reliable")
func rpc_intent_challenge() -> void:
	if is_host:
		_handle_intent(multiplayer.get_remote_sender_id(), "challenge", [])


func _handle_intent(pid: int, kind: String, indices: Array) -> void:
	if _gs == null or not in_game:
		return
	var result: Dictionary
	if kind == "play":
		result = _gs.play_cards(pid, indices)
	else:
		result = _gs.challenge(pid)
	if not result["ok"]:
		if pid == HOST_ID:
			intent_rejected.emit(result["error"])
		else:
			_send_to(pid, "rpc_intent_rejected", [result["error"]])
		return
	# 行动者那一端要先播完排队的演出才能出手(超时代打时预算也早已耗尽):
	# 之前的预算余量不再顺延,否则玩家出手越快,多给的时间越积越多
	_anim_left = 0.0
	_after_action(result["events"])


func _after_action(events: Array) -> void:
	# 先定计时再同步:公共视图里的 turn_time_left 要反映这一批之后的截止时间
	_schedule_turn_timer(events)
	game_events.emit(events)
	_send_to_members("rpc_game_events", [events])
	_sync_all()


func _schedule_turn_timer(events: Array) -> void:
	# 演出期间玩家无法行动:新回合从客户端演完所有排队事件(含断线时还没播完的上一批)后才计满时间;
	# 只有断线出局(回合没换人)时保留剩余时间,只补上这段演出,不能把计时重置
	_anim_left = Pacing.pending_after(_anim_left, events)
	if _gs.phase == GameState.Phase.MATCH_OVER:
		_turn_timer.stop()
		return
	_turn_timer.start(Pacing.turn_timer_after(events, _anim_left, _turn_time_left()))


func _turn_time_left() -> float:
	# 房主计时器剩余秒数;没在计时(未开局/已结束)为 0
	if _turn_timer.is_stopped() or _gs == null or _gs.phase != GameState.Phase.PLAYING:
		return 0.0
	return _turn_timer.time_left


@rpc("authority", "call_remote", "reliable")
func rpc_intent_rejected(code: String) -> void:
	intent_rejected.emit(code)


@rpc("authority", "call_remote", "reliable")
func rpc_game_events(events: Array) -> void:
	game_events.emit(events)


# —— 视线同步:不可靠有序、走独立通道,丢包由 GazeSync 的心跳与超时兜底 ——
# 方法名刻意排在 rpc_join_* 之后:RPC 按方法名排序编号,握手消息的编号不变,
# 旧版本仍能收到"版本不匹配"的明确拒绝

func send_gaze(point: Vector3, neck: Vector3, active: bool) -> void:
	if not in_game or multiplayer.multiplayer_peer == null:
		return
	if is_host:
		_relay_gaze(HOST_ID, point, neck, active)
	else:
		_send_to(HOST_ID, "rpc_look", [point, neck, active])


@rpc("any_peer", "call_remote", "unreliable_ordered", Protocol.GAZE_CHANNEL)
func rpc_look(point: Vector3, neck: Vector3, active: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not is_host or not in_game or not _match_names.has(sender) or not GazeSync.is_valid(point, neck):
		return
	gaze_updated.emit(sender, point, neck, active)
	_relay_gaze(sender, point, neck, active)


func _relay_gaze(from_pid: int, point: Vector3, neck: Vector3, active: bool) -> void:
	for seat in seats:
		var id: int = seat["pid"]
		if id != HOST_ID and id != from_pid:
			_send_to(id, "rpc_look_relay", [from_pid, point, neck, active])


@rpc("authority", "call_remote", "unreliable_ordered", Protocol.GAZE_CHANNEL)
func rpc_look_relay(pid: int, point: Vector3, neck: Vector3, active: bool) -> void:
	if in_game and GazeSync.is_valid(point, neck):
		gaze_updated.emit(pid, point, neck, active)


# —— 回合限时(仅房主):超时代打手牌第一张 ——

func _on_turn_timeout() -> void:
	if _gs != null and _gs.phase == GameState.Phase.PLAYING and _gs.current_pid != null:
		_handle_intent(_gs.current_pid, "play", [0])


# —— 结算后回到等待厅 ——

func request_rematch_lobby() -> void:
	if not is_host or not in_game or _gs == null or _gs.phase != GameState.Phase.MATCH_OVER:
		return
	_gs = null
	in_game = false
	_turn_timer.stop()
	_anim_left = 0.0
	_lobby.reset_ready()
	_send_to_members("rpc_returned_to_lobby", [])
	returned_to_lobby.emit()
	_broadcast_lobby()


@rpc("authority", "call_remote", "reliable")
func rpc_returned_to_lobby() -> void:
	in_game = false
	returned_to_lobby.emit()


func _make_timer(callback: Callable) -> Timer:
	var timer := Timer.new()
	timer.one_shot = true
	timer.timeout.connect(callback)
	add_child(timer)
	return timer
