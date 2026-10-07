extends SceneTree
# 视觉检查:搭建酒馆并按指定机位截图(需要窗口渲染,不能 --headless)。
# 用法:godot --path . -s tools/shot.gd -- --out=/tmp/shots --views=seat,menu,overhead [--showcase] [--size=1600x900] [--fov=40]
# --showcase 时在桌边摆上 4 名酒客、手牌与左轮,用于检查角色与道具。
# 机位可以是下面的预设名,也可以是自由机位 "px,py,pz:tx,ty,tz"(相机位置:看向的点),
# 含自由机位时各机位改用分号分隔,如 --views="seat;0,1.4,0.5:0,1.1,-1.25"。
# 自由机位的文件名为 cam1.png、cam2.png……(按出现顺序);--fov 只作用于自由机位。


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
	if opts.has("size"):
		var dims: PackedStringArray = opts["size"].split("x")
		root.size = Vector2i(int(dims[0]), int(dims[1]))
	RenderBudget.apply(root)
	var tavern := Tavern.new()
	root.add_child(tavern)
	if opts.has("showcase"):
		var script: GDScript = load("res://tools/showcase.gd")
		var showcase: Node = script.new()
		root.add_child(showcase)
		await showcase.build(tavern)
	var views: PackedStringArray = opts.get("views", "seat").split(";" if opts.get("views", "").contains(":") else ",")
	var custom := 0
	var default_fov := tavern.camera_rig.camera.fov
	for view in views:
		var label := view
		tavern.camera_rig.camera.fov = default_fov
		if view.contains(":"):
			custom += 1
			label = "cam%d" % custom
			var ends := view.split(":")
			tavern.camera_rig.snap(_vec(ends[0]), _vec(ends[1]))
			tavern.camera_rig.fill_light.light_energy = 0.0
			tavern.camera_rig.camera.fov = float(opts.get("fov", str(default_fov)))
		else:
			_place_camera(tavern.camera_rig, view)
		for i in WARMUP_FRAMES:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [out_dir, label]
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
	quit()


func _vec(text: String) -> Vector3:
	var parts := text.split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))


func _place_camera(rig: CameraRig, view: String) -> void:
	var top := SeatLayout.TABLE_TOP
	match view:
		"seat":
			# 与 TableWorld.third_person_view(本机座位)一致的越肩机位
			rig.snap(Vector3(0.55, 1.92, 2.1), Vector3(0, top, -0.12))
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
