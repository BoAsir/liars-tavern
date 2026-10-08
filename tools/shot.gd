extends SceneTree
# 视觉检查:搭建酒馆并按指定机位截图(需要窗口渲染,不能 --headless)。
# 用法:godot --path . -s tools/shot.gd -- --out=/tmp/shots --views=seat,menu,overhead [--showcase | --poker-showcase] [--stats]
# --showcase 时在桌边摆上 4 名酒客、手牌与左轮,用于检查角色与道具;--scene=menu 时是主菜单状态(空牌桌与空椅子)。
# 骗子酒馆机位表见 tools/camera_views.gd。
# --poker-showcase 时摆德州展台(tools/poker_showcase.gd);德州机位 poker_seat / poker_overview / poker_lobby
# 取自 TableWorld 的机位函数(不抄数字),没有展台时另建一个放大的空德州桌。4:3 检查加引擎参数 --resolution 1280x960。
# --hud=bet,showdown,… 给展台的德州机位叠上整套 HUD(状态与 --views 按位置对应,不够的沿用最后一个;见 PokerShowcase.HUD_STATES),
# 文件名带状态,同一机位可以拍几种底部区域。
# --stats 时每个机位打印全帧削顶比例、每张酒客脸与爪子的发白(亮度 ≥ 0.85)/削顶比例、墙面灰泥区域的亮度标准差。
# 要做前后像素对比(tools/shot_diff.gd)时加 --freeze 与引擎参数 --fixed-fps 60:搭好展台后暂停场景树(呼吸、眨眼、补间、粒子都停下),
# 每帧时长与随机数种子也固定,两次截图可比。


const CameraViews := preload("res://tools/camera_views.gd")
const ImageStats := preload("res://tools/image_stats.gd")
const WARMUP_FRAMES := 45
const SETTLE_DRAWS := 8   # 截图前连续强制绘制的帧数(体积雾的时域累积要几帧才收敛;同 DebugFlags)
const POKER_ME := 1
const LINEUP_SPACING := 0.78   # --lineup 时酒客之间的间距(米)
const LINEUP_Z := 1.5          # 排在牌桌前面,不和桌子重叠
const FACE_RADIUS := 0.17   # 酒客头的半径(米),--stats 按它在画面上框出脸
const PAW_RADIUS := 0.06    # 爪子的半径(米)
# --stats 的灰泥取样区域(按画面比例):只有能看到大片墙面的机位才有
const PLASTER_RECTS := {
	"seat": Rect2(0.55, 0.02, 0.2, 0.12),
	"menu": Rect2(0.62, 0.2, 0.2, 0.15),
	"opponent": Rect2(0.08, 0.08, 0.15, 0.25),
	"gun": Rect2(0.25, 0.1, 0.15, 0.25),
}

var opts := {}
var _poker_world: TableWorld = null
var _poker: Node = null
var _showcase: Node = null
var _ui: Control = null


func _initialize() -> void:
	seed(2026)
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
	RenderBudget.apply(root)
	var tavern := Tavern.new()
	root.add_child(tavern)
	if opts.has("lineup"):
		# 8 个物种一字排开(面朝镜头),配 lineup_front / lineup_back / lineup_heads 机位
		for i in Species.count():
			var patron := Patron.new(i)
			patron.position = Vector3((i - (Species.count() - 1) * 0.5) * LINEUP_SPACING, 0, LINEUP_Z)
			patron.rotation.y = PI
			tavern.table_root.add_child(patron)
			patron.look_at_point(Vector3(0, 1.2, 3.0))
	if opts.get("scene", "") == "menu":
		var world := TableWorld.new(tavern)
		tavern.table_root.add_child(world)
		world.clear()
	elif opts.has("showcase"):
		var script: GDScript = load("res://tools/showcase.gd")
		var showcase: Node = script.new()
		root.add_child(showcase)
		await showcase.build(tavern)
		_showcase = showcase
	if opts.has("poker-showcase"):
		var poker: Node = load("res://tools/poker_showcase.gd").new()
		root.add_child(poker)
		await poker.build(tavern)
		_poker_world = poker.world
		_poker = poker
	if opts.has("freeze"):
		paused = true   # 暂停场景树:_process、补间、计时器停下,渲染照常
		# 火焰着色器按渲染时间 TIME 跳动、粒子在 GPU 上推进,暂停树管不到:一并停下
		WorldMaterials.flame().set_shader_parameter("speed", 0.0)
		for particles: GPUParticles3D in root.find_children("*", "GPUParticles3D", true, false):
			particles.speed_scale = 0.0
	var views: PackedStringArray = opts.get("views", "seat").split(",")
	var hud_states: PackedStringArray = opts.get("hud", "").split(",")
	for index in views.size():
		var view: String = views[index]
		var hud_state: String = hud_states[mini(index, hud_states.size() - 1)]
		if view.begins_with("poker_"):
			_place_poker_camera(tavern, view)
			_stage_hud(tavern, view, hud_state)
		else:
			_place_camera(tavern.camera_rig, view)
		for i in WARMUP_FRAMES:
			await process_frame
		for i in SETTLE_DRAWS:
			RenderingServer.force_draw(false)
		if view.begins_with("flash") and _showcase != null:
			# 开一枪:2 帧后拍枪口焰,再过 0.6 秒拍硝烟(flashclose 是同一枪的特写机位)
			_showcase.fire()
			for i in 2:
				await process_frame
			_save(out_dir, view)
			await create_timer(0.6).timeout
			_save(out_dir, view.replace("flash", "smoke"))
			continue
		var image := _save(out_dir, view if hud_state == "" else view + "_" + hud_state)
		if opts.has("stats"):
			_print_stats(view, image)
	quit()


func _save(out_dir: String, file: String) -> Image:
	RenderingServer.force_draw(false)
	var path := "%s/%s.png" % [out_dir, file]
	var image := root.get_texture().get_image()
	image.save_png(path)
	print("saved ", path)
	return image


func _place_camera(rig: CameraRig, view: String) -> void:
	if not CameraViews.place(rig, view):
		push_warning("unknown view " + view)


func _print_stats(view: String, image: Image) -> void:
	var size := image.get_size()
	print("STATS %s frame_clip=%.3f" % [view, ImageStats.clipped_ratio(image, Rect2i(Vector2i.ZERO, size))])
	var camera := root.get_camera_3d()
	for patron in root.find_children("*", "Patron", true, false):
		var id: String = PatronParts.species(patron.species_index)["id"]
		_print_region(view, "face " + id, image, camera, patron.head_position(), FACE_RADIUS)
		for hand: Node3D in [patron.find_child("ArmL", true, false).get_node("Hand"), patron.right_hand]:
			_print_region(view, "paw " + id, image, camera, hand.global_position, PAW_RADIUS)
	if PLASTER_RECTS.has(view):
		var rel: Rect2 = PLASTER_RECTS[view]
		var rect := Rect2i(Rect2(rel.position * Vector2(size), rel.size * Vector2(size)))
		print("STATS %s plaster_stddev=%.1f" % [view, ImageStats.luma_stddev(image, rect)])


func _print_region(view: String, label: String, image: Image, camera: Camera3D, center_3d: Vector3, radius: float) -> void:
	# 按球心与半径在画面上框出一块(脸、爪),打印发白与削顶比例
	if camera.is_position_behind(center_3d):
		return
	var center := camera.unproject_position(center_3d)
	var r := center.distance_to(camera.unproject_position(center_3d + camera.global_basis.x * radius))
	var rect := Rect2i(Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0))
	if rect.intersection(Rect2i(Vector2i.ZERO, image.get_size())).get_area() < 16:
		return
	print("STATS %s %s washed=%.3f clip=%.3f" % [view, label, ImageStats.washed_ratio(image, rect), ImageStats.clipped_ratio(image, rect)])


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
