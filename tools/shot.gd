extends SceneTree
# 视觉检查:搭建酒馆并按指定机位截图(需要窗口渲染,不能 --headless)。
# 用法:godot --path . -s tools/shot.gd -- --out=/tmp/shots --views=seat,menu,overhead [--showcase | --poker-showcase] [--size=1600x900] [--fov=40]
# --showcase 时在桌边摆上 4 名酒客、手牌与左轮,用于检查角色与道具。
# --poker-showcase 时摆德州展台(tools/poker_showcase.gd);德州机位 poker_seat / poker_overview / poker_lobby
# 取自 TableWorld 的机位函数(不抄数字),没有展台时另建一个放大的空德州桌。4:3 检查加引擎参数 --resolution 1280x960。
# 机位可以是下面的预设名,也可以是自由机位 "px,py,pz:tx,ty,tz"(相机位置:看向的点),
# 含自由机位时各机位改用分号分隔,如 --views="seat;0,1.4,0.5:0,1.1,-1.25"。
# 自由机位的文件名为 cam1.png、cam2.png……(按出现顺序);--fov 只作用于自由机位。
# --hud=bet,showdown,… 给展台的德州机位叠上整套 HUD(状态与 --views 按位置对应,不够的沿用最后一个;见 PokerShowcase.HUD_STATES),
# --neck=x,z 让展台上所有酒客把脖子伸到这个座位偏移(-z 朝桌心,会按 Patron.NECK_REACH 截断),检查探头的样子。
# 文件名带状态,同一机位可以拍几种底部区域。没写 --hud 时展台的德州机位也带 HUD:座位机位 bet,观战机位 spectate。
# 全套:--views=poker_seat,poker_seat,poker_seat,poker_seat,poker_seat,poker_seat,poker_seat,poker_seat,poker_overview
#       --hud=bet,wait,showdown,bust,spectate,waiting,away,settlement,spectate --poker-showcase(4:3 再加 --resolution 1280x960)


const WARMUP_FRAMES := 45
# 截图前连续强制绘制几帧再读图:窗口被其他窗口挡住时 macOS 不再调度正常绘制(等 frame_post_draw 会永远卡住),
# 强制绘制不依赖窗口可见;体积雾的时域累积也要几帧才收敛
const SETTLE_DRAWS := 8
const POKER_ME := 1
const NECK_SETTLE := 1.5   # 秒:--neck 之后等弹簧脖子停稳

var opts := {}
var _poker_world: TableWorld = null
var _poker: Node = null
var _ui: Control = null


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "true"
	process_frame.connect(_run, CONNECT_ONE_SHOT)
	process_frame.connect(_draw_when_covered)


func _draw_when_covered() -> void:
	# 窗口被别的窗口挡住时 macOS 不再调度正常绘制:牌面生成与截图里等 frame_post_draw 会永远卡住。
	# 每帧强制绘制一次(不交换缓冲),frame_post_draw 照常发出,不依赖窗口可见
	if not DisplayServer.window_can_draw():
		RenderingServer.force_draw(false)


func _run() -> void:
	var out_dir: String = opts.get("out", OS.get_user_data_dir() + "/shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	if opts.has("size"):
		var dims: PackedStringArray = opts["size"].split("x")
		root.size = Vector2i(int(dims[0]), int(dims[1]))
	RenderBudget.apply(root)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var tavern := Tavern.new()
	root.add_child(tavern)
	if opts.has("showcase"):
		var script: GDScript = load("res://tools/showcase.gd")
		var showcase: Node = script.new()
		root.add_child(showcase)
		await showcase.build(tavern)
	if opts.has("poker-showcase"):
		var poker: Node = load("res://tools/poker_showcase.gd").new()
		root.add_child(poker)
		await poker.build(tavern)
		_poker_world = poker.world
		_poker = poker
	if opts.has("neck"):
		await _stretch_necks(opts["neck"])
	var views: PackedStringArray = opts.get("views", "seat").split(";" if opts.get("views", "").contains(":") else ",")
	var hud_states: PackedStringArray = opts.get("hud", "").split(",")
	var custom := 0
	var default_fov := tavern.camera_rig.camera.fov
	for index in views.size():
		var view: String = views[index]
		var label := view
		var hud_state: String = hud_states[mini(index, hud_states.size() - 1)]
		if hud_state == "" and _poker != null and view.begins_with("poker_"):
			hud_state = PokerShowcase.SPECTATE_STATE if view == "poker_overview" else PokerShowcase.BET_STATE
		tavern.camera_rig.camera.fov = default_fov
		if view.contains(":"):
			custom += 1
			label = "cam%d" % custom
			var ends := view.split(":")
			tavern.camera_rig.snap(_vec(ends[0]), _vec(ends[1]))
			tavern.camera_rig.fill_light.light_energy = 0.0
			tavern.camera_rig.camera.fov = float(opts.get("fov", str(default_fov)))
		elif view.begins_with("poker_"):
			_place_poker_camera(tavern, view)
			_stage_hud(tavern, view, hud_state)
		else:
			_place_camera(tavern.camera_rig, view)
		for i in WARMUP_FRAMES:
			await process_frame
		for i in SETTLE_DRAWS:
			RenderingServer.force_draw(false)
		var path := "%s/%s.png" % [out_dir, label if hud_state == "" else label + "_" + hud_state]
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
	quit()


func _vec(text: String) -> Vector3:
	var parts := text.split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _stretch_necks(spec: String) -> void:
	var xz := spec.split_floats(",")
	var offset := Vector3(xz[0], 0.0, xz[1] if xz.size() > 1 else 0.0)
	for patron in root.find_children("*", "Patron", true, false):
		(patron as Patron).set_neck_target(offset)
	await create_timer(NECK_SETTLE).timeout


func _place_camera(rig: CameraRig, view: String) -> void:
	var top := SeatLayout.TABLE_TOP
	match view:
		"seat":
			# 与 TableWorld.third_person_view(本机座位)一致的越肩机位
			rig.snap(Vector3(TableWorld.THIRD_PERSON_SIDE, TableWorld.THIRD_PERSON_HEIGHT, SeatLayout.SEAT_RADIUS + TableWorld.THIRD_PERSON_BEHIND),
				Vector3(0, top, -0.12))
			rig.fill_light.light_energy = TableWorld.SEAT_FILL_LIGHT
		"selfshot":
			rig.snap(Vector3(-0.35, 1.42, 0.15), Vector3(0, 1.19, 1.37))
		"gun":
			rig.snap(Vector3(0.1, 1.42, 0.3), Vector3(1.25, 1.25, 0.0))
		"menu":
			rig.snap(Vector3(2.6, 2.1, 2.9), Vector3(-0.4, 0.9, -0.8))
		"overhead":
			rig.snap(Vector3(0, 2.6, 1.6), Vector3(0, top, 0))
		"fireplace":
			rig.snap(Vector3(0.5, 1.4, -1.5), Vector3(-1.5, 0.8, -4.4))
		"bar":
			rig.snap(Vector3(0.5, 1.5, 0.8), Vector3(-4.0, 1.4, -0.6))
		"window":
			rig.snap(Vector3(-1.5, 1.5, 1.5), Vector3(4.4, 1.5, -0.9))
		"closeup":
			rig.snap(Vector3(0.0, 1.05, 0.55), Vector3(0, top, -0.2))
		"opponent":
			rig.snap(Vector3(0, 1.3, 0.2), Vector3(0, 1.1, -1.25))
		_:
			push_warning("unknown view " + view)


func _place_poker_camera(tavern: Tavern, view: String) -> void:
	# 德州机位:取自 TableWorld(本机座位 = 1 号)。观战机位下本机的酒客藏起来(规格 §5.5),
	# 等待厅里桌上还没有筹码与牌
	var world := _poker_table(tavern)
	var rig := tavern.camera_rig
	world.set_patron_visible(POKER_ME, view != "poker_overview")
	world.poker_root.visible = view != "poker_lobby"
	for pid in world.patrons:
		world.patrons[pid].fan.visible = view != "poker_lobby"
	rig.fill_light.light_energy = 0.0
	var xform: Transform3D
	match view:
		"poker_seat":
			xform = world.third_person_view(POKER_ME)
			rig.fill_light.light_energy = TableWorld.SEAT_FILL_LIGHT
		"poker_overview":
			xform = world.overview_view()
		"poker_lobby":
			xform = world.lobby_view()
		_:
			push_warning("unknown view " + view)
			return
	rig.snap(xform.origin, xform.origin - xform.basis.z)


func _poker_table(tavern: Tavern) -> TableWorld:
	if _poker_world == null:
		_poker_world = TableWorld.new(tavern)
		tavern.table_root.add_child(_poker_world)
		_poker_world.configure_table(SeatLayout.POKER_TABLE_RADIUS)
		tavern.set_table_decor_visible(false)
		_poker_world.cards.set_stand_visible(false)
	return _poker_world


func _stage_hud(tavern: Tavern, view: String, state: String) -> void:
	# 德州 HUD 叠在展台上(等待厅机位没有 HUD);同 main._ui_layer:CanvasLayer + 全屏根控件 + 主题
	if _poker == null or state == "" or view == "poker_lobby":
		return
	if _ui == null:
		var layer := CanvasLayer.new()
		root.add_child(layer)
		_ui = Control.new()
		_ui.theme = UiTheme.theme()
		_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
		_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_ui)
	_poker.stage_hud(_ui, tavern.camera_rig.camera, state)
