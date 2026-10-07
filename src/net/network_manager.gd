extends Node
# 网络管理(autoload "Net"):房主权威 listen-server。
# 房主持有唯一 GameState 与等待厅名单;客户端只发意图、收视图与事件。
# UI 层只使用本类的公开方法、只读属性与信号,不直接触碰 multiplayer API。


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
signal gaze_updated(pid: int, point: Vector3, active: bool)   # 他人视线落点(发送者座位坐标系)

const HOST_ID := LobbyModel.HOST_ID
const DISCONNECT_GRACE := 1.0

# —— 只读状态(UI 读取) ——
var player_name := ""
var is_host := false
var in_game := false
var lobby_players: Array = []
var lobby_meta := {}       # {"room", "host", "addresses", "port"}
var seats: Array = []      # 本局座位顺序 [{"pid", "name"}]
var last_public := {}
var last_private := {}

var _session_active := false
var _joining := false
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

func host_game(pname: String, room_name: String, preferred_port := 0) -> Error:
	leave()
	var created := _create_server(preferred_port)
	if created["error"] != OK:
		return created["error"]
	multiplayer.multiplayer_peer = created["peer"]
	(multiplayer as SceneMultiplayer).server_relay = false
	_port = created["port"]
	player_name = Protocol.sanitize_name(pname)
	_room_name = Protocol.sanitize_text(room_name, Protocol.MAX_ROOM_NAME_LENGTH)
	_room_id = "%08x%08x" % [randi(), randi()]
	is_host = true
	_session_active = true
	_lobby = LobbyModel.new()
	_lobby.add_host(player_name)
	Discovery.start_broadcast(_room_announcement)
	joined_lobby.emit()
	_broadcast_lobby()
	return OK


func join_game(pname: String, address_text: String) -> void:
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
	is_host = false
	in_game = false
	Discovery.stop_broadcast()
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
	return {
		"id": _room_id,
		"room": _room_name,
		"host": player_name,
		"players": _lobby.size() if _lobby != null else 0,
		"max": Protocol.MAX_PLAYERS,
		"version": Protocol.VERSION,
		"port": _port,
		"open": not in_game and _lobby != null and _lobby.size() < Protocol.MAX_PLAYERS,
	}


# —— 连接生命周期 ——

func _on_connected_to_host() -> void:
	if _joining:
		_shorten_peer_timeout(HOST_ID)
		rpc_id(HOST_ID, "rpc_join_request", player_name, Protocol.VERSION)


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
	if _joining:
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
	if not is_host or not _session_active:
		return
	var id := multiplayer.get_remote_sender_id()
	if _lobby.has(id):
		return
	var deny := _join_denial(id, pname, version)
	if deny != "":
		rpc_id(id, "rpc_join_denied", deny)
		_disconnect_peer_later(id)
		return
	_lobby.add_member(id, pname)
	rpc_id(id, "rpc_join_accepted")
	_broadcast_lobby()


func _join_denial(id: int, pname: String, version: int) -> String:
	# 昵称来自不可信的对端:超长的在做任何逐字处理前就拒绝
	if pname.length() > Protocol.MAX_RAW_NAME_LENGTH:
		push_warning("拒绝连接 %d 的加入请求:昵称长度 %d 超过上限 %d"
			% [id, pname.length(), Protocol.MAX_RAW_NAME_LENGTH])
		return "昵称过长"
	return _lobby.check_join(version, in_game)


@rpc("authority", "call_remote", "reliable")
func rpc_join_denied(reason: String) -> void:
	if _joining:
		_fail_join(reason)


@rpc("authority", "call_remote", "reliable")
func rpc_join_accepted() -> void:
	if not _joining:
		return
	_joining = false
	_join_timer.stop()
	joined_lobby.emit()


# —— 等待厅 ——

func set_ready(ready: bool) -> void:
	if not is_host and _session_active and not _joining:
		rpc_id(HOST_ID, "rpc_lobby_ready", ready)


@rpc("any_peer", "call_remote", "reliable")
func rpc_lobby_ready(ready: bool) -> void:
	if not is_host or in_game:
		return
	if _lobby.set_ready(multiplayer.get_remote_sender_id(), ready):
		_broadcast_lobby()


func kick(id: int) -> void:
	if not is_host or in_game or not _lobby.remove(id):
		return
	rpc_id(id, "rpc_kicked")
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
	}
	_apply_lobby(players, meta)
	_send_to_members("rpc_lobby_state", [players, meta])


@rpc("authority", "call_remote", "reliable")
func rpc_lobby_state(players: Array, meta: Dictionary) -> void:
	_apply_lobby(players, meta)


func _apply_lobby(players: Array, meta: Dictionary) -> void:
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
	# 只发给已完成握手且连接仍然有效的成员;握手中/被拒绝/正在断开的连接都跳过
	for id in _lobby.seat_order():
		if id != HOST_ID and _is_connected(id):
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
	_send_to_members("rpc_game_started", [seats])
	game_started.emit(seats)
	# 各端进入牌桌先播开场运镜,第一局的发牌演出排在它后面
	_anim_left = Pacing.INTRO
	_after_action([_gs.round_started_event()])


@rpc("authority", "call_remote", "reliable")
func rpc_game_started(p_seats: Array) -> void:
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
		elif _is_connected(pid):
			rpc_id(pid, "rpc_state_private", priv)


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
		rpc_id(HOST_ID, "rpc_intent_play", indices)


func submit_challenge() -> void:
	if not in_game:
		return
	if is_host:
		_handle_intent(HOST_ID, "challenge", [])
	else:
		rpc_id(HOST_ID, "rpc_intent_challenge")


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
			rpc_id(pid, "rpc_intent_rejected", result["error"])
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

func send_gaze(point: Vector3, active: bool) -> void:
	if not in_game or multiplayer.multiplayer_peer == null:
		return
	if is_host:
		_relay_gaze(HOST_ID, point, active)
	else:
		rpc_id(HOST_ID, "rpc_look", point, active)


@rpc("any_peer", "call_remote", "unreliable_ordered", Protocol.GAZE_CHANNEL)
func rpc_look(point: Vector3, active: bool) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if not is_host or not in_game or not _match_names.has(sender) or not GazeSync.is_valid(point):
		return
	gaze_updated.emit(sender, point, active)
	_relay_gaze(sender, point, active)


func _relay_gaze(from_pid: int, point: Vector3, active: bool) -> void:
	for seat in seats:
		var id: int = seat["pid"]
		if id != HOST_ID and id != from_pid and _is_connected(id):
			rpc_id(id, "rpc_look_relay", from_pid, point, active)


@rpc("authority", "call_remote", "unreliable_ordered", Protocol.GAZE_CHANNEL)
func rpc_look_relay(pid: int, point: Vector3, active: bool) -> void:
	if in_game and GazeSync.is_valid(point):
		gaze_updated.emit(pid, point, active)


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
