extends SceneTree
# 视觉检查:搭建酒馆并按指定机位截图(需要窗口渲染,不能 --headless)。
# 用法:godot --path . -s tools/shot.gd -- --out=/tmp/shots --views=seat,menu,overhead [--showcase]
# --showcase 时在桌边摆上 4 名酒客、手牌与左轮,用于检查角色与道具。


const WARMUP_FRAMES := 45

var opts := {}


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
	var views: PackedStringArray = opts.get("views", "seat").split(",")
	for view in views:
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
			rig.snap(Vector3(TableWorld.THIRD_PERSON_SIDE, TableWorld.THIRD_PERSON_HEIGHT, TableWorld.THIRD_PERSON_BACK),
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
