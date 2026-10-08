extends SceneTree
# 视觉检查:搭建酒馆并按指定机位截图(需要窗口渲染,不能 --headless)。
# 用法:godot --path . -s tools/shot.gd -- --out=/tmp/shots --views=seat,menu,overhead [--showcase | --poker-showcase]
# --showcase 时在桌边摆上 4 名酒客、手牌与左轮,用于检查角色与道具。
# --poker-showcase 时摆德州展台(tools/poker_showcase.gd);德州机位 poker_seat / poker_overview / poker_lobby
# 取自 TableWorld 的机位函数(不抄数字),没有展台时另建一个放大的空德州桌。4:3 检查加引擎参数 --resolution 1280x960。


const WARMUP_FRAMES := 45
const POKER_ME := 1

var opts := {}
var _poker_world: TableWorld = null


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "true"
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var out_dir: String = opts.get("out", OS.get_user_data_dir() + "/shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	RenderBudget.apply(root)
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
	var views: PackedStringArray = opts.get("views", "seat").split(",")
	for view in views:
		if view.begins_with("poker_"):
			_place_poker_camera(tavern, view)
		else:
			_place_camera(tavern.camera_rig, view)
		for i in WARMUP_FRAMES:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [out_dir, view]
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
	quit()


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
