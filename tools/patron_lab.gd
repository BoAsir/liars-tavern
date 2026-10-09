extends SceneTree
# 酒客造型检查:4 名酒客落座(可指定物种、表情、动作),按酒客相对的机位截图(需要窗口渲染,不能 --headless)。
# 用法:godot --path . -s tools/patron_lab.gd -- --out=/tmp/lab [--species=0,1,2,3] [--expr=neutral,angry,worried,happy]
#       [--views=face3,body3,three3,side2,back4] [--dead=3] [--gun=4] [--cheer=2] [--neck=2] [--active=2] [--cards]
#       [--nohat] [--size=1280x720] [--fov=30]
# 机位(n = 1..4 号座位):face 脸部特写、prof 头部侧面、body 上半身正面、three 四分之三侧、side 侧面全身(看腿与尾巴)、
# back 背后斜上方(看尾巴与椅子)、top 头顶俯视(看帽子与耳朵)。也可写自由机位 "px,py,pz:tx,ty,tz"(分号分隔)。


const WARMUP_FRAMES := 40
# 截图前强制绘制几帧再读图:窗口被挡住时 macOS 不调度正常绘制(等 frame_post_draw 会卡住)
const SETTLE_DRAWS := 6

var opts := {}
var world: TableWorld


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "true"
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var out_dir: String = opts.get("out", OS.get_user_data_dir() + "/lab")
	DirAccess.make_dir_recursive_absolute(out_dir)
	if opts.has("size"):
		var dims: PackedStringArray = opts["size"].split("x")
		root.size = Vector2i(int(dims[0]), int(dims[1]))
	RenderBudget.apply(root)
	var tavern := Tavern.new()
	root.add_child(tavern)
	await _seat_patrons(tavern)
	var camera := tavern.camera_rig.camera
	camera.fov = float(opts.get("fov", "30"))
	var views: PackedStringArray = opts.get("views", "face3,body3").split(";" if opts.get("views", "").contains(":") else ",")
	var custom := 0
	for view in views:
		var label := view
		var eye_target: Array
		if view.contains(":"):
			custom += 1
			label = "cam%d" % custom
			var ends := view.split(":")
			eye_target = [_vec(ends[0]), _vec(ends[1])]
		else:
			eye_target = _preset(view)
		tavern.camera_rig.snap(eye_target[0], eye_target[1])
		tavern.camera_rig.fill_light.light_energy = 0.0
		for i in WARMUP_FRAMES:
			await process_frame
		for i in SETTLE_DRAWS:
			RenderingServer.force_draw(false)
		var path := "%s/%s.png" % [out_dir, label]
		root.get_texture().get_image().save_png(path)
		print("saved ", path)
	quit()


func _seat_patrons(tavern: Tavern) -> void:
	world = TableWorld.new(tavern)
	tavern.table_root.add_child(world)
	world.arrange([{"pid": 1}, {"pid": 2}, {"pid": 3}, {"pid": 4}], 1, true, opts.has("gun"))
	var species: PackedStringArray = opts.get("species", "").split(",", false)
	for i in species.size():
		_replace(i + 1, int(species[i]))
	if opts.has("cards"):
		await CardFaces.build(world)
		Card3D.refresh_materials()
		world.cards.deal([1, 2, 3, 4], {1: 5, 2: 5, 3: 4, 4: 3}, [Card.QUEEN, Card.KING, Card.JOKER, Card.ACE, Card.KING])
	await create_timer(0.8).timeout
	world.look_all_at(Vector3(0, 1.25, 0.0))
	var expressions: PackedStringArray = opts.get("expr", "").split(",", false)
	for i in expressions.size():
		world.patrons[i + 1].set_expression(expressions[i])
	if opts.has("active"):
		world.patrons[int(opts["active"])].set_active(true)
	if opts.has("neck"):
		world.patrons[int(opts["neck"])].set_neck_target(Vector3(0, 0, -0.45))
	if opts.has("cheer"):
		world.patrons[int(opts["cheer"])].celebrate()
	if opts.has("gun"):
		var pid := int(opts["gun"])
		await world.patrons[pid].pick_up(world.revolvers[pid], 0.2)
		await world.patrons[pid].raise_gun_to_head(world.revolvers[pid], 0.3)
	if opts.has("dead"):
		world.patrons[int(opts["dead"])].die()
	if opts.has("nohat"):
		for pid in world.patrons:
			world.patrons[pid].find_child("Hat", true, false).visible = false
	await create_timer(1.6).timeout


func _replace(pid: int, species_index: int) -> void:
	var old: Patron = world.patrons[pid]
	var fresh := Patron.new(species_index)
	fresh.transform = old.transform
	old.free()
	world.add_child(fresh)
	world.patrons[pid] = fresh


func _preset(view: String) -> Array:
	# 按某号座位酒客的朝向放机位:forward 指向桌心,right 是酒客的右手边
	var pid := int(view.right(1))
	var patron: Patron = world.patrons[pid]
	var seat := patron.global_position
	var forward := -patron.global_basis.z
	var right := patron.global_basis.x
	var head := patron.head_position()
	match view.left(-1):
		"face":
			return [head + forward * 0.62 + Vector3(0, 0.03, 0), head + Vector3(0, -0.01, 0)]
		"body":
			return [head + forward * 1.45 + Vector3(0, 0.0, 0), head + Vector3(0, -0.3, 0)]
		"three":
			return [head + (forward * 0.75 + right * 0.6) + Vector3(0, 0.05, 0), head + Vector3(0, -0.12, 0)]
		"prof":
			return [head + right * 0.7 + Vector3(0, 0.03, 0), head + Vector3(0, -0.01, 0)]
		"side":
			return [seat + right * 1.9 + forward * 0.2 + Vector3(0, 0.85, 0), seat + Vector3(0, 0.62, 0)]
		"back":
			return [seat - forward * 1.3 + right * 0.9 + Vector3(0, 1.3, 0), seat + Vector3(0, 0.6, 0)]
		"top":
			return [head + forward * 0.45 + Vector3(0, 0.55, 0), head + Vector3(0, 0.1, 0)]
	push_warning("unknown view " + view)
	return [Vector3(0, 1.5, 2), Vector3.ZERO]


func _vec(text: String) -> Vector3:
	var parts := text.split(",")
	return Vector3(float(parts[0]), float(parts[1]), float(parts[2]))
