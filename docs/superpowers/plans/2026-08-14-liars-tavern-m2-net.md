# M2:协议、视图与网络层

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现协议常量、公共/私有视图构建(防作弊边界)、ENet 房主权威网络层、UDP 房间发现。

**Architecture:** `Net`(autoload)持有唯一 `GameState`(仅房主),客户端意图经 RPC 到房主校验;`Views` 决定谁能看到什么;`Discovery`(autoload)在房主端广播、客户端监听。UI 层(M3/M4)只通过 `Net`/`Discovery` 的信号与方法交互。

**依赖:** M1a、M1b 完成(单测全绿)。

---

### Task 1: 协议常量 Protocol

**Files:**
- Create: `src/net/protocol.gd`

- [ ] **Step 1: 实现 `src/net/protocol.gd`**(纯常量,无行为不单测)

```gdscript
class_name Protocol
# 网络协议常量:版本不匹配的客户端会被拒绝加入。


const VERSION := 1
const DISCOVERY_PORT := 47800
const GAME_PORT := 47801
const BROADCAST_INTERVAL := 1.0
const MIN_PLAYERS := 2
const MAX_PLAYERS := 4
const TURN_TIMEOUT := 30.0

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
```

- [ ] **Step 2: 跑测试确认无解析错误后 Commit**

```bash
git add src/net/protocol.gd
git commit -m "feat: 网络协议常量"
```

### Task 2: 视图构建 Views(TDD,防作弊边界)

**Files:**
- Create: `src/net/views.gd`
- Test: `tests/test_views.gd`

- [ ] **Step 1: 写失败测试 `tests/test_views.gd`**

```gdscript
extends GutTest


func _make_gs() -> GameState:
	var gs := GameState.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	gs.start_match([1, 2, 3], rng)
	return gs


func test_public_state_shape_and_no_secrets():
	var gs := _make_gs()
	gs.play_cards(gs.current_pid, [0, 1])
	var pub := Views.public_state(gs, {1: "甲", 2: "乙", 3: "丙"})
	assert_eq(pub["target"], gs.target_card)
	assert_eq(pub["current_pid"], gs.current_pid)
	assert_eq(pub["round"], 1)
	assert_eq(pub["winner"], null)
	# 防作弊:上家出的具体牌面绝不进入公共视图
	assert_eq(pub["last_play"]["count"], 2)
	assert_false(pub["last_play"].has("cards"))
	assert_eq(pub["players"].size(), 3)
	for p in pub["players"]:
		assert_false(p.has("hand"))
		assert_true(p.has("hand_count"))
		assert_true(p.has("shots_fired"))
		assert_true(p.has("alive"))
	# 公共视图整体不含任何手牌数组与弹膛位置
	assert_false(str(pub).contains("bullet"))


func test_public_state_last_play_empty_at_round_start():
	var gs := _make_gs()
	var pub := Views.public_state(gs, {})
	assert_true(pub["last_play"].is_empty())


func test_private_state_contains_only_own_hand():
	var gs := _make_gs()
	var pid = gs.current_pid
	var priv := Views.private_state(gs, pid)
	assert_eq(priv.keys(), ["hand"])
	assert_eq(priv["hand"], gs.hands[pid])
```

- [ ] **Step 2: 跑测试验证失败**

Expected: FAIL(`Views` 未定义)。

- [ ] **Step 3: 实现 `src/net/views.gd`**

```gdscript
class_name Views
# 视图构建:决定每个客户端能看到什么。手牌牌面与弹膛位置永不进入公共视图。


static func public_state(gs: GameState, names: Dictionary) -> Dictionary:
	var players := []
	for pid in gs.seat_order:
		players.append({
			"pid": pid,
			"name": names.get(pid, str(pid)),
			"alive": gs.alive[pid],
			"hand_count": gs.hands.get(pid, []).size(),
			"shots_fired": gs.revolvers[pid].shots_fired(),
		})
	var last_play := {}
	if not gs.last_play.is_empty():
		last_play = {"pid": gs.last_play["pid"], "count": gs.last_play["count"]}
	return {
		"phase": gs.phase,
		"round": gs.round_number,
		"target": gs.target_card,
		"current_pid": gs.current_pid,
		"last_play": last_play,
		"players": players,
		"winner": gs.winner_pid,
	}


static func private_state(gs: GameState, pid) -> Dictionary:
	return {"hand": gs.hands.get(pid, [])}
```

- [ ] **Step 4: 跑测试验证通过,Commit**

```bash
git add src/net/views.gd tests/test_views.gd
git commit -m "feat: 公共/私有视图构建(秘密信息不出房主)"
```

### Task 3: 房间发现 Discovery(UDP 广播)

**Files:**
- Create: `src/net/discovery.gd`

注意:autoload 注册放在 Task 4 与 `Net` 一起做——`discovery.gd` 与 `network_manager.gd` 通过全局名互相引用(`Net.lobby` / `Discovery.start_broadcast`),必须两个文件都存在后同时注册,否则脚本解析报"未找到标识符"。

- [ ] **Step 1: 实现 `src/net/discovery.gd`**

```gdscript
extends Node
# 局域网房间发现(autoload "Discovery")。
# 房主:每秒 UDP 广播房间信息;客户端:监听并维护带过期的房间列表。
# 注意:同一台机器只能有一个实例绑定监听端口,同机多开请手输 IP 直连。


signal rooms_updated(rooms: Array)

const PRUNE_AFTER := 3.0

var room_name := ""
var _broadcaster: PacketPeerUDP = null
var _listener: PacketPeerUDP = null
var _timer: Timer = null
var _rooms := {}


func _ready() -> void:
	_timer = Timer.new()
	_timer.wait_time = Protocol.BROADCAST_INTERVAL
	_timer.timeout.connect(_broadcast_once)
	add_child(_timer)


func start_broadcast(p_room_name: String) -> void:
	room_name = p_room_name
	_broadcaster = PacketPeerUDP.new()
	_broadcaster.set_broadcast_enabled(true)
	_broadcaster.set_dest_address("255.255.255.255", Protocol.DISCOVERY_PORT)
	_timer.start()
	_broadcast_once()


func stop_broadcast() -> void:
	_timer.stop()
	_broadcaster = null


func start_listening() -> void:
	_listener = PacketPeerUDP.new()
	if _listener.bind(Protocol.DISCOVERY_PORT) != OK:
		# 端口被占用(同机另一实例在监听/广播),退化为仅手输 IP
		_listener = null
	_rooms = {}
	rooms_updated.emit([])


func stop_listening() -> void:
	if _listener != null:
		_listener.close()
	_listener = null


func get_rooms() -> Array:
	var out := []
	for ip in _rooms:
		var entry: Dictionary = _rooms[ip]["info"].duplicate()
		entry["ip"] = ip
		out.append(entry)
	return out


func _broadcast_once() -> void:
	if _broadcaster == null:
		return
	var info := {
		"room": room_name,
		"host": Net.player_name,
		"players": Net.lobby.size(),
		"max": Protocol.MAX_PLAYERS,
		"version": Protocol.VERSION,
	}
	_broadcaster.put_packet(JSON.stringify(info).to_utf8_buffer())


func _process(_delta: float) -> void:
	if _listener == null:
		return
	var changed := false
	while _listener.get_available_packet_count() > 0:
		var text := _listener.get_packet().get_string_from_utf8()
		var ip := _listener.get_packet_ip()
		var info = JSON.parse_string(text)
		if info is Dictionary and info.get("version", -1) == Protocol.VERSION:
			_rooms[ip] = {"info": info, "last_seen": _now()}
			changed = true
	var now := _now()
	for ip in _rooms.keys():
		if now - _rooms[ip]["last_seen"] > PRUNE_AFTER:
			_rooms.erase(ip)
			changed = true
	if changed:
		rooms_updated.emit(get_rooms())


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
```

- [ ] **Step 2: 跑测试确认无解析错误(此时尚未注册 autoload,属预期),Commit**

```bash
git add src/net/discovery.gd
git commit -m "feat: UDP 局域网房间发现"
```

### Task 4: 网络管理 Net(ENet 房主权威)

**Files:**
- Create: `src/net/network_manager.gd`
- Modify: `project.godot`(新增 `[autoload]` 节,同时注册 Discovery 与 Net)

- [ ] **Step 1: 实现 `src/net/network_manager.gd`**

```gdscript
extends Node
# 网络管理(autoload "Net"):房主权威 listen-server。
# 房主持有唯一 GameState;客户端只发意图、收视图与事件。
# UI 层只使用本类的公开方法与信号,不直接触碰 multiplayer API。


signal lobby_updated(players: Array)
signal joined_lobby
signal left_lobby(reason: String)
signal join_failed(reason: String)
signal game_started
signal state_public_updated(state: Dictionary)
signal state_private_updated(state: Dictionary)
signal game_events(events: Array)
signal intent_rejected(code: String)
signal returned_to_lobby

var player_name := ""
var is_host := false
var lobby := {}                # peer_id -> {"name": String, "ready": bool}
var gs: GameState = null       # 仅房主非空
var _turn_timer: Timer = null


func my_pid() -> int:
	# UI 层用它比对 current_pid,避免直接触碰 multiplayer API
	return multiplayer.get_unique_id()


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_host)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_host_disconnected)
	_turn_timer = Timer.new()
	_turn_timer.one_shot = true
	_turn_timer.timeout.connect(_on_turn_timeout)
	add_child(_turn_timer)


# —— 建房 / 加入 / 离开 ——

func host_game(pname: String, room_name: String) -> Error:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(Protocol.GAME_PORT, Protocol.MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	player_name = pname
	is_host = true
	lobby = {1: {"name": pname, "ready": true}}
	Discovery.start_broadcast(room_name)
	joined_lobby.emit()
	_broadcast_lobby()
	return OK


func join_game(pname: String, ip: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, Protocol.GAME_PORT) != OK:
		join_failed.emit("无法发起连接")
		return
	multiplayer.multiplayer_peer = peer
	player_name = pname
	is_host = false


func leave() -> void:
	Discovery.stop_broadcast()
	_turn_timer.stop()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	lobby = {}
	gs = null
	is_host = false


# —— 连接生命周期 ——

func _on_connected_to_host() -> void:
	rpc_id(1, "rpc_join_request", player_name, Protocol.VERSION)


func _on_connection_failed() -> void:
	leave()
	join_failed.emit("连接失败:请确认 IP 与房间是否存在")


func _on_peer_connected(_id: int) -> void:
	pass  # 等待对方的 rpc_join_request


func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	if gs != null:
		var events := gs.eliminate_player(id)
		if not events.is_empty():
			_after_action(events)
	if lobby.has(id):
		lobby.erase(id)
		_broadcast_lobby()


func _on_host_disconnected() -> void:
	leave()
	left_lobby.emit("与房主断开连接,房间已解散")


# —— 加入握手 ——

@rpc("any_peer", "call_remote", "reliable")
func rpc_join_request(pname: String, version: int) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	var deny := ""
	if version != Protocol.VERSION:
		deny = "版本不匹配(房主 v%d / 你 v%d)" % [Protocol.VERSION, version]
	elif gs != null:
		deny = "游戏已开始"
	elif lobby.size() >= Protocol.MAX_PLAYERS:
		deny = "房间已满"
	if deny != "":
		rpc_id(id, "rpc_join_denied", deny)
		return
	lobby[id] = {"name": pname, "ready": false}
	rpc_id(id, "rpc_join_accepted")
	_broadcast_lobby()


@rpc("authority", "call_remote", "reliable")
func rpc_join_denied(reason: String) -> void:
	leave()
	join_failed.emit(reason)


@rpc("authority", "call_remote", "reliable")
func rpc_join_accepted() -> void:
	joined_lobby.emit()


# —— 等待厅 ——

func set_ready(ready: bool) -> void:
	if not is_host:
		rpc_id(1, "rpc_lobby_ready", ready)


@rpc("any_peer", "call_remote", "reliable")
func rpc_lobby_ready(ready: bool) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if lobby.has(id):
		lobby[id]["ready"] = ready
		_broadcast_lobby()


func kick(id: int) -> void:
	if not is_host or id == 1:
		return
	multiplayer.multiplayer_peer.disconnect_peer(id)
	lobby.erase(id)
	_broadcast_lobby()


func can_start() -> bool:
	if lobby.size() < Protocol.MIN_PLAYERS:
		return false
	for id in lobby:
		if not lobby[id]["ready"]:
			return false
	return true


func lobby_view() -> Array:
	var out := []
	for id in lobby:
		out.append({
			"pid": id,
			"name": lobby[id]["name"],
			"ready": lobby[id]["ready"],
			"is_host": id == 1,
		})
	return out


func _broadcast_lobby() -> void:
	var players := lobby_view()
	lobby_updated.emit(players)
	if is_host:
		rpc("rpc_lobby_state", players)


@rpc("authority", "call_remote", "reliable")
func rpc_lobby_state(players: Array) -> void:
	lobby_updated.emit(players)


# —— 开局与状态同步 ——

func start_game() -> void:
	if not is_host or gs != null or not can_start():
		return
	Discovery.stop_broadcast()
	var seat_order := lobby.keys()
	seat_order.sort()
	gs = GameState.new()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	gs.start_match(seat_order, rng)
	rpc("rpc_game_started")
	game_started.emit()
	await get_tree().process_frame
	_after_action([gs.round_started_event()])


@rpc("authority", "call_remote", "reliable")
func rpc_game_started() -> void:
	game_started.emit()


func _sync_all() -> void:
	var names := {}
	for id in lobby:
		names[id] = lobby[id]["name"]
	var pub := Views.public_state(gs, names)
	state_public_updated.emit(pub)
	rpc("rpc_state_public", pub)
	for pid in gs.seat_order:
		if pid == 1:
			state_private_updated.emit(Views.private_state(gs, 1))
		elif lobby.has(pid):
			rpc_id(pid, "rpc_state_private", Views.private_state(gs, pid))


@rpc("authority", "call_remote", "reliable")
func rpc_state_public(state: Dictionary) -> void:
	state_public_updated.emit(state)


@rpc("authority", "call_remote", "reliable")
func rpc_state_private(state: Dictionary) -> void:
	state_private_updated.emit(state)


# —— 意图 ——

func submit_play(indices: Array) -> void:
	if is_host:
		_handle_intent(1, "play", indices)
	else:
		rpc_id(1, "rpc_intent_play", indices)


func submit_challenge() -> void:
	if is_host:
		_handle_intent(1, "challenge", [])
	else:
		rpc_id(1, "rpc_intent_challenge")


@rpc("any_peer", "call_remote", "reliable")
func rpc_intent_play(indices: Array) -> void:
	if is_host:
		_handle_intent(multiplayer.get_remote_sender_id(), "play", indices)


@rpc("any_peer", "call_remote", "reliable")
func rpc_intent_challenge() -> void:
	if is_host:
		_handle_intent(multiplayer.get_remote_sender_id(), "challenge", [])


func _handle_intent(pid: int, kind: String, indices: Array) -> void:
	if gs == null:
		return
	var result: Dictionary
	if kind == "play":
		result = gs.play_cards(pid, indices)
	else:
		result = gs.challenge(pid)
	if not result["ok"]:
		if pid == 1:
			intent_rejected.emit(result["error"])
		else:
			rpc_id(pid, "rpc_intent_rejected", result["error"])
		return
	_after_action(result["events"])


func _after_action(events: Array) -> void:
	game_events.emit(events)
	rpc("rpc_game_events", events)
	_sync_all()
	if gs.phase == GameState.Phase.MATCH_OVER:
		_turn_timer.stop()
	else:
		_turn_timer.start(Protocol.TURN_TIMEOUT)


@rpc("authority", "call_remote", "reliable")
func rpc_intent_rejected(code: String) -> void:
	intent_rejected.emit(code)


@rpc("authority", "call_remote", "reliable")
func rpc_game_events(events: Array) -> void:
	game_events.emit(events)


# —— 回合限时(仅房主):超时代打手牌第一张 ——

func _on_turn_timeout() -> void:
	if gs != null and gs.phase == GameState.Phase.PLAYING and gs.current_pid != null:
		_handle_intent(gs.current_pid, "play", [0])


# —— 结算后回到等待厅 ——

func request_rematch_lobby() -> void:
	if not is_host:
		return
	gs = null
	_turn_timer.stop()
	for id in lobby:
		lobby[id]["ready"] = id == 1
	Discovery.start_broadcast(Discovery.room_name)
	rpc("rpc_returned_to_lobby")
	returned_to_lobby.emit()
	_broadcast_lobby()


@rpc("authority", "call_remote", "reliable")
func rpc_returned_to_lobby() -> void:
	gs = null
	returned_to_lobby.emit()
```

- [ ] **Step 2: 在 `project.godot` 的 `[display]` 节之前插入**

```ini
[autoload]

Discovery="*res://src/net/discovery.gd"
Net="*res://src/net/network_manager.gd"
```

- [ ] **Step 3: 跑测试(确认两个 autoload 在 headless 下加载无报错、原有测试全绿)**

Run: 跑测试命令。
Expected: 全部 PASS,无解析/加载错误输出。

- [ ] **Step 4: Commit**

```bash
git add src/net/network_manager.gd project.godot
git commit -m "feat: ENet 房主权威网络层(握手/等待厅/意图/视图分发/超时代打)"
```
