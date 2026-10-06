class_name DebugFlags
extends Node
# 命令行调试开关(写在 -- 之后),用于联机冒烟测试与截图检查:
#   --name=甲            自动填写昵称
#   --autohost[=N]       自动建房;满 N 人(默认 2)且全员准备后自动开局
#   --port=端口          房主优先绑定的游戏端口(并行测试互不串房)
#   --room=房名          房主的房间名
#   --autojoin=IP[:端口] 自动直连
#   --discover[=房名]    自动加入局域网发现的(指定名字的)房间
#   --bot                自动准备/选牌/出牌/质疑(走真实界面路径)
#   --fast[=倍率]        加速演出(Engine.time_scale,默认 3)
#   --quit-after-match   对局结束后退出(退出码 0);中途失败退出码 1
#   --shots=目录         在关键时刻截图


const BOT_THINK := Vector2(0.6, 1.6)
const CHALLENGE_CHANCE := 0.35

var app: Node
var opts := {}
var _think_timer := 0.0
var _shot_counts := {}
var _match_finished := false


func _init(p_app: Node) -> void:
	app = p_app
	opts = parse_user_args()


static func parse_user_args(args: PackedStringArray = OS.get_cmdline_user_args()) -> Dictionary:
	# "--key=value" → {key: value};不带值的 "--flag" → {flag: "true"};空键忽略。
	# 注意:以 -s 启动的工具脚本编译时 autoload(Net/Discovery)还没注册,引用本类会编译失败,
	# 所以 tools/*.gd 不能直接调用这里
	var out := {}
	for arg in args:
		var kv := arg.trim_prefix("--").split("=", true, 1)
		if kv[0] != "":
			out[kv[0]] = kv[1] if kv.size() > 1 else "true"
	return out


func _ready() -> void:
	if opts.is_empty():
		set_process(false)
		return
	print("[debug] flags: ", opts)
	if opts.has("fast"):
		Engine.time_scale = float(opts["fast"]) if opts["fast"] != "true" else 3.0
	Net.joined_lobby.connect(_on_joined)
	Net.lobby_updated.connect(_on_lobby)
	Net.game_events.connect(_on_events)
	Net.game_started.connect(_on_game_started)
	Net.join_failed.connect(_fail.bind("join_failed"))
	Net.left_lobby.connect(_on_left)
	if opts.has("shots"):
		DirAccess.make_dir_recursive_absolute(opts["shots"])
		_capture_later("menu", 2.5)
	var player_name: String = opts.get("name", "测试%d" % (OS.get_process_id() % 1000))
	if opts.has("autohost"):
		var room: String = opts.get("room", "%s 的酒馆" % player_name)
		var err := Net.host_game(player_name, room, int(opts.get("port", "0")))
		print("[debug] host_game -> ", error_string(err))
		if err != OK:
			_fail("host_failed")
	elif opts.has("autojoin"):
		Net.join_game(player_name, opts["autojoin"])
	elif opts.has("discover"):
		Discovery.rooms_updated.connect(_join_discovered.bind(player_name))


func _join_discovered(rooms: Array, player_name: String) -> void:
	if Net.in_game or not Net.lobby_players.is_empty() or Net.player_name != "":
		return
	var wanted: String = opts["discover"]
	for room in rooms:
		if room["open"] and (wanted == "true" or room["room"] == wanted):
			print("[debug] discovered ", room["room"], " at ", room["ip"], ":", room["port"])
			Net.join_game(player_name, Protocol.format_address(room["ip"], room["port"]))
			return


func _process(delta: float) -> void:
	if not opts.has("bot"):
		return
	var screen: Node = app.current_screen()
	if screen == null or not screen.has_method("_my_turn") or not screen._my_turn():
		_think_timer = randf_range(BOT_THINK.x, BOT_THINK.y)
		return
	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = 999.0
	_bot_act(screen)


func _bot_act(screen: Node) -> void:
	# 与界面同一规则:不能质疑自己的出牌(断线后轮转可能回到出牌者)
	var can_challenge: bool = screen._can_challenge()
	var hand_size: int = screen.cards.my_cards.size()
	if can_challenge and (randf() < CHALLENGE_CHANCE or hand_size == 0):
		screen._submit_challenge()
		return
	var indices := range(hand_size)
	indices.shuffle()
	for i in indices.slice(0, randi_range(1, mini(3, hand_size))):
		screen._toggle(i)
	screen._submit_play()


func _on_joined() -> void:
	print("[debug] joined lobby as ", Net.my_pid())
	if opts.has("shots"):
		_capture_later("lobby", 3.0)
	if opts.has("bot") and not Net.is_host:
		await get_tree().create_timer(0.8).timeout
		var screen: Node = app.current_screen()
		if screen != null and screen.has_method("_on_ready_toggled"):
			screen._on_ready_toggled()


func _on_lobby(players: Array) -> void:
	if not Net.is_host or not opts.has("autohost"):
		return
	var want := int(opts["autohost"]) if opts["autohost"] != "true" else 2
	if players.size() >= want and Net.can_start():
		print("[debug] starting game with ", players.size(), " players")
		await get_tree().create_timer(1.0).timeout
		if Net.can_start():
			Net.start_game()


func _on_events(events: Array) -> void:
	for ev in events:
		if ev["type"] == "match_over":
			print("[debug] MATCH_OVER winner=", ev["winner"])
			_match_finished = true


func _on_game_started(_seats: Array) -> void:
	# 截图与退出按演出进度触发:事件批到达时前面的动画可能还要播好几秒
	await get_tree().process_frame
	var screen: Node = app.current_screen()
	var director = screen.get("director") if screen != null else null
	if director is TableDirector:
		director.event_started.connect(_on_director_event)


func _on_director_event(ev: Dictionary) -> void:
	match ev["type"]:
		"round_started":
			_capture_once("deal", 3.0)
		"played":
			_capture_once("played", 0.55)
		"reveal":
			_capture_once("reveal", 1.2 + 0.68 * ev.get("cards", []).size())
		"gunshot":
			_capture_once("suspense", 2.0)
			_capture_once("shot_result", 3.0)
		"match_over":
			_capture_once("victory", 1.5)
			_capture_once("settlement", 3.3)
			if opts.has("quit-after-match"):
				await get_tree().create_timer(5.0 if Net.is_host else 4.0).timeout
				app.quit_game(0)


func _on_left(reason: String) -> void:
	if opts.has("quit-after-match") and not _match_finished:
		_fail("left_lobby: " + reason)


func _fail(reason: String, detail := "") -> void:
	push_error("[debug] FAIL %s %s" % [reason, detail])
	if opts.has("quit-after-match") or opts.has("autojoin") or opts.has("autohost"):
		app.quit_game(1)


# —— 截图 ——

func _capture_once(tag: String, delay: float) -> void:
	if not opts.has("shots") or _shot_counts.has(tag):
		return
	_shot_counts[tag] = true
	_capture_later(tag, delay)


func _capture_later(tag: String, delay: float) -> void:
	if not opts.has("shots"):
		return
	await get_tree().create_timer(delay).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return
	var path := "%s/%s_%s.png" % [opts["shots"], opts.get("name", "p"), tag]
	image.save_png(path)
	print("[debug] shot ", path)
