class_name DebugFlags
extends Node
# 命令行调试开关(写在 -- 之后),用于联机冒烟测试与截图检查:
#   --name=甲            自动填写昵称
#   --species=物种id     本次运行想要的形象(fox/bear/…/crocodile),只覆盖本次、不写设置;
#                        每次名单更新与开局时打印 [debug] species {pid: id}(冒烟测试比对各进程)
#   --autohost[=N]       自动建房;满 N 人(默认 2)且全员准备后自动开局
#   --mode=玩法id        房主开房的玩法(liars / bomb_cat / holdem / short_deck,默认骗子酒馆)
#   --port=端口          房主优先绑定的游戏端口(并行测试互不串房)
#   --room=房名          房主的房间名
#   --autojoin=IP[:端口] 自动直连
#   --discover[=房名]    自动加入局域网发现的(指定名字的)房间
#   --bot                自动准备/选牌/出牌/质疑(走真实界面路径);开局后朝别人丢一个番茄、按 Q 说一句快捷语;
#                        炸弹猫里由 BombCatBot 出牌、偶尔不行!、摸牌、塞回、给牌(同样走牌桌的公开入口)
#   --fast[=倍率]        加速演出(Engine.time_scale,默认 3)
#   --quit-after-match   对局结束后退出(退出码 0);中途失败退出码 1
#   --shots=目录         在关键时刻截图
#   --camera=first|third 本次运行的牌桌视角(第一人称 / 越肩),只覆盖本次、不写设置
#   --update-from=IP:端口 从这个房主下载更新并装好,装好后打印 UPDATE_READY 退出(失败退出码 1)
#   --update-url=网址    同上,但从任意更新源(如 BuildInfo.FEED_URL + 平台 + "/")


const BOT_THINK := Vector2(0.6, 1.6)
const CHALLENGE_CHANCE := 0.35
const BOT_FIDGET := 1.5    # bot 按住 W 探头、松开、按住 S 收回、松开,每步这么久(秒);冒烟测试据此确认脖子偏移走通了网络
const BOT_FIDGET_KEYS := [KEY_W, KEY_S]
const SHOT_SETTLE_DRAWS := 8   # 截图前连续强制绘制的帧数(体积雾的时域累积要几帧才收敛)
const BOT_BANTER_DELAY := 2.0  # 开局后 bot 过这么久丢番茄,再过 BOT_SAY_DELAY 说快捷语(冒烟测试核对各端都收到)
const BOT_SAY_DELAY := 1.8

var app: Node
var opts := {}
var _think_timer := 0.0
var _shot_counts := {}
var _match_finished := false
var _gaze_from := {}   # 收到过谁的视线同步(冒烟测试据此确认视线消息走通)
var _neck_from := {}   # 收到过谁伸出的脖子
var _fidget_timer := BOT_FIDGET
var _fidget_step := 0
var _tomato_from := {}   # 收到过谁丢的番茄(冒烟测试据此确认丢番茄走通)
var _said_from := {}     # 收到过谁说的快捷语
var _bomb_bot: BombCatBot = null


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


static func species_override(args: PackedStringArray = OS.get_cmdline_user_args()) -> int:
	# --species=<id> 的物种下标;没给或 id 不认识时返回 UNASSIGNED(后者告警),沿用设置里的形象
	var value: String = parse_user_args(args).get("species", "")
	if value == "":
		return Species.UNASSIGNED
	var index := Species.index_of(value)
	if index == Species.UNASSIGNED:
		push_warning("--species=%s 不是已知形象(可选:%s),沿用设置里的形象" % [value, ", ".join(Species.IDS)])
	return index


static func species_line(entries: Array) -> String:
	# entries:[{pid, species}](名单或座位表,按座位顺序)→「[debug] species {1: crocodile, 2034: fox}」;没有形象写「-」
	var parts := entries.map(func(p: Dictionary) -> String:
		var index := Species.sanitize(p.get("species"))
		return "%s: %s" % [p.get("pid"), Species.IDS[index] if index != Species.UNASSIGNED else "-"])
	return "[debug] species {%s}" % ", ".join(parts)


func _ready() -> void:
	if opts.is_empty():
		set_process(false)
		return
	print("[debug] flags: ", opts)
	print("[debug] build=%d active_update=%d installer=%d" % [BuildInfo.build(), UpdateBoot.active_build,
		UpdateBoot.installer["build"]])
	if opts.has("update-from") or opts.has("update-url"):
		_update_from(opts.get("update-from", ""), opts.get("update-url", ""))
		return
	if opts.has("fast"):
		Engine.time_scale = float(opts["fast"]) if opts["fast"] != "true" else 3.0
	Net.joined_lobby.connect(_on_joined)
	Net.lobby_updated.connect(_on_lobby)
	Net.game_events.connect(_on_events)
	Net.game_started.connect(_on_game_started)
	Net.gaze_updated.connect(func(pid: int, _point: Vector3, neck: Vector3, _active: bool):
		_gaze_from[pid] = true
		if neck != Vector3.ZERO:
			_neck_from[pid] = true)
	Net.banter.tomato_thrown.connect(func(from_pid: int, _target: int, _seed: int): _tomato_from[from_pid] = true)
	Net.banter.said.connect(func(pid: int, _phrase: int): _said_from[pid] = true)
	Net.join_failed.connect(_fail.bind("join_failed"))
	Net.left_lobby.connect(_on_left)
	if opts.has("shots"):
		DirAccess.make_dir_recursive_absolute(opts["shots"])
		_capture_later("menu", 2.5)
	var player_name: String = opts.get("name", "测试%d" % (OS.get_process_id() % 1000))
	if opts.has("autohost"):
		var room: String = opts.get("room", "%s 的酒馆" % player_name)
		var err := Net.host_game(player_name, room, int(opts.get("port", "0")), host_mode(opts), _species())
		print("[debug] host_game -> ", error_string(err))
		if err != OK:
			_fail("host_failed")
	elif opts.has("autojoin"):
		Net.join_game(player_name, opts["autojoin"], _species())
	elif opts.has("discover"):
		Discovery.rooms_updated.connect(_join_discovered.bind(player_name))


func _join_discovered(rooms: Array, player_name: String) -> void:
	if Net.in_game or not Net.lobby_players.is_empty() or Net.player_name != "":
		return
	var wanted: String = opts["discover"]
	for room in rooms:
		if room["open"] and (wanted == "true" or room["room"] == wanted):
			print("[debug] discovered ", room["room"], " at ", room["ip"], ":", room["port"])
			Net.join_game(player_name, Protocol.format_address(room["ip"], room["port"]), _species())
			return


static func host_mode(flags: Dictionary) -> String:
	# --mode=<玩法 id>;没给或不认识时用默认玩法(后者告警)
	var mode: String = flags.get("mode", GameMode.DEFAULT)
	if not GameMode.is_valid(mode):
		push_warning("--mode=%s 不是已知玩法(可选:%s),用默认玩法" % [mode, ", ".join(GameMode.ALL)])
		return GameMode.DEFAULT
	return mode


func _species() -> int:
	# 本机想要的形象:main 已经按设置解析好,--species 覆盖本次运行
	return Species.sanitize(app.get("species"))


func _process(delta: float) -> void:
	if not opts.has("bot"):
		return
	_fidget(delta)
	var screen: Node = app.current_screen()
	if screen != null and screen.get("state") is BombCatScreenState:
		_bomb_bot_tick(screen, delta)
		return
	if screen == null or not screen.has_method("_my_turn") or not screen._my_turn():
		_think_timer = randf_range(BOT_THINK.x, BOT_THINK.y)
		return
	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = 999.0
	_bot_act(screen)


func _update_from(address: String, url: String) -> void:
	Updater.changed.connect(_on_update_changed)
	if url != "":
		Updater.check(url, "网络")
		return
	var addr := Protocol.parse_address(address)
	Updater.check(Updater.lan_source(addr["ip"], addr["port"]), "房主")


func _on_update_changed() -> void:
	match Updater.state:
		Updater.State.AVAILABLE:
			Updater.download()
		Updater.State.READY:
			print("[debug] UPDATE_READY build=%d" % Updater.manifest["build"])
			get_tree().quit(0)
		Updater.State.BLOCKED, Updater.State.FAILED:
			print("[debug] UPDATE_FAIL ", Updater.message)
			get_tree().quit(1)


func _fidget(delta: float) -> void:
	# 对局中轮流按住 W、S:走与真人相同的按键读取,头探出去再收回来
	_fidget_timer -= delta
	if not Net.in_game or _fidget_timer > 0.0:
		return
	_fidget_timer = BOT_FIDGET
	var key := InputEventKey.new()
	key.physical_keycode = BOT_FIDGET_KEYS[floori(_fidget_step / 2.0) % BOT_FIDGET_KEYS.size()]
	key.pressed = _fidget_step % 2 == 0
	Input.parse_input_event(key)
	_fidget_step += 1


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


func _bomb_bot_tick(screen: Node, delta: float) -> void:
	# 炸弹猫:想一会儿再走一步;这一刻没事可做就过一小会儿再看(反应窗口只有 3 秒)
	if _bomb_bot == null:
		_bomb_bot = BombCatBot.new()
	_think_timer -= delta
	if _think_timer > 0.0:
		return
	if _bomb_bot.act(screen):
		_think_timer = randf_range(BOT_THINK.x, BOT_THINK.y)
	else:
		_think_timer = 0.25


func _bot_banter(seats: Array) -> void:
	# 走真实界面:光标移到下家的头上按 T(界面按屏幕投影选目标),再按 Q 打开快捷语面板、按数字说出
	await get_tree().create_timer(BOT_BANTER_DELAY + randf() * 0.5).timeout
	var order := seats.map(func(s): return s["pid"])
	var me := order.find(Net.my_pid())
	var target: int = order[(me + 1) % order.size()]
	var view: BanterView = app.get("banter_view")
	var world: TableWorld = app.get("world")
	if view != null and world != null and world.patrons.has(target):
		var camera: Camera3D = app.tavern.camera_rig.camera
		var head: Vector3 = world.patrons[target].head_position()
		var picked := BanterView.pick_target(camera, camera.unproject_position(head), world.patrons, Net.my_pid())
		if picked == target:
			view.throw_at_cursor(camera.unproject_position(head))
		else:
			Net.banter.throw_tomato(target)   # 镜头在拍特写、下家不在画面里:直接发
	await get_tree().create_timer(BOT_SAY_DELAY).timeout
	for keycode in [KEY_Q, KEY_1 + randi() % Banter.PHRASES.size()]:
		for pressed in [true, false]:
			var key := InputEventKey.new()
			key.keycode = keycode
			key.pressed = pressed
			Input.parse_input_event(key)
			await get_tree().process_frame


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
	# 对局中的名单更新(有人散场离开、德州有人入座)不打印:冒烟测试比对的最后一条要是开局时的座位表
	if not Net.in_game:
		print(species_line(players))
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
			print("[debug] GAZE peers=%d necks=%d" % [_gaze_from.size(), _neck_from.size()])
			print("[debug] BANTER tomatoes=%d said=%d" % [_tomato_from.size(), _said_from.size()])
			print("[debug] MATCH_OVER winner=", ev["winner"])
			_match_finished = true


func _on_game_started(seats: Array) -> void:
	print(species_line(seats))
	if opts.has("bot"):
		_bot_banter(seats)
	# 截图与退出按演出进度触发:事件批到达时前面的动画可能还要播好几秒
	await get_tree().process_frame
	var screen: Node = app.current_screen()
	var director = screen.get("director") if screen != null else null
	if director is TableDirector or director is BombCatDirector:
		director.event_started.connect(_on_director_event)
		if opts.has("camera"):
			director.seat_camera.set_first_person(opts["camera"] == "first", false)
			_capture_once("seat", 3.0)


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
		"bomb_drawn":
			_capture_once("bomb", 1.0)
		"exploded":
			_capture_once("exploded", 1.6)
		"defused":
			_capture_once("defused", 1.2)
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
	# 窗口被别的窗口挡住时 macOS 不再调度正常绘制,等 frame_post_draw 会永远卡住;
	# 强制绘制几帧再读图,不依赖窗口可见(同 tools/shot.gd)
	for i in SHOT_SETTLE_DRAWS:
		RenderingServer.force_draw(false)
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		return
	var path := "%s/%s_%s.png" % [opts["shots"], opts.get("name", "p"), tag]
	image.save_png(path)
	print("[debug] shot ", path)
