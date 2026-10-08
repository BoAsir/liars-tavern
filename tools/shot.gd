extends SceneTree
# 视觉检查:搭建酒馆并按指定机位截图(需要窗口渲染,不能 --headless)。
# 用法:godot --path . -s tools/shot.gd -- --out=/tmp/shots --views=seat,menu,overhead [--showcase] [--stats]
# --showcase 时在桌边摆上 4 名酒客、手牌与左轮,用于检查角色与道具。
# --stats 时每个机位打印全帧削顶比例、每张酒客脸的削顶比例、墙面灰泥区域的亮度标准差。
# 要做前后像素对比(tools/shot_diff.gd)时加 --freeze 与引擎参数 --fixed-fps 60:搭好展台后暂停场景树(呼吸、眨眼、补间、粒子都停下),
# 每帧时长与随机数种子也固定,两次截图可比。


const CameraViews := preload("res://tools/camera_views.gd")
const ImageStats := preload("res://tools/image_stats.gd")
const WARMUP_FRAMES := 45
const FACE_RADIUS := 0.17   # 酒客头的半径(米),--stats 按它在画面上框出脸
# --stats 的灰泥取样区域(按画面比例):只有能看到大片墙面的机位才有
const PLASTER_RECTS := {
	"seat": Rect2(0.55, 0.02, 0.2, 0.12),
	"menu": Rect2(0.62, 0.2, 0.2, 0.15),
	"opponent": Rect2(0.08, 0.08, 0.15, 0.25),
	"gun": Rect2(0.25, 0.1, 0.15, 0.25),
}

var opts := {}


func _initialize() -> void:
	seed(2026)
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
	if opts.has("freeze"):
		paused = true   # 暂停场景树:_process、补间、计时器、粒子都停下,渲染照常
	var views: PackedStringArray = opts.get("views", "seat").split(",")
	for view in views:
		_place_camera(tavern.camera_rig, view)
		for i in WARMUP_FRAMES:
			await process_frame
		await RenderingServer.frame_post_draw
		var path := "%s/%s.png" % [out_dir, view]
		var image := root.get_texture().get_image()
		image.save_png(path)
		print("saved ", path)
		if opts.has("stats"):
			_print_stats(view, image)
	quit()


func _print_stats(view: String, image: Image) -> void:
	var size := image.get_size()
	print("STATS %s frame_clip=%.3f" % [view, ImageStats.clipped_ratio(image, Rect2i(Vector2i.ZERO, size))])
	var camera := root.get_camera_3d()
	for patron in root.find_children("*", "Patron", true, false):
		var head: Vector3 = patron.head_position()
		if camera.is_position_behind(head):
			continue
		var center := camera.unproject_position(head)
		var edge := camera.unproject_position(head + camera.global_basis.x * FACE_RADIUS)
		var r := center.distance_to(edge)
		var rect := Rect2i(Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0))
		if not rect.intersects(Rect2i(Vector2i.ZERO, size)):
			continue
		print("STATS %s face %s clip=%.3f" % [view, PatronParts.species(patron.species_index)["id"], ImageStats.clipped_ratio(image, rect)])
	if PLASTER_RECTS.has(view):
		var rel: Rect2 = PLASTER_RECTS[view]
		var rect := Rect2i(Rect2(rel.position * Vector2(size), rel.size * Vector2(size)))
		print("STATS %s plaster_stddev=%.1f" % [view, ImageStats.luma_stddev(image, rect)])


func _place_camera(rig: CameraRig, view: String) -> void:
	if not CameraViews.place(rig, view):
		push_warning("unknown view " + view)
