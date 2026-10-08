extends SceneTree
# 视觉检查:搭建酒馆并按指定机位截图(需要窗口渲染,不能 --headless)。
# 用法:godot --path . -s tools/shot.gd -- --out=/tmp/shots --views=seat,menu,overhead [--showcase]
# --showcase 时在桌边摆上 4 名酒客、手牌与左轮,用于检查角色与道具。


const CameraViews := preload("res://tools/camera_views.gd")
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
	if not CameraViews.place(rig, view):
		push_warning("unknown view " + view)
