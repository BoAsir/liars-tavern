extends SceneTree
# 场景开销统计:在离屏 SubViewport 里搭好酒馆 + 展台(4 名酒客、手牌、左轮),按机位打印
# 可见/阴影两遍的物件数、绘制调用、三角形数,以及整帧 GPU 耗时;另外统计静态几何(网格节点数、表面数、三角形数)。
# 需要窗口渲染(不能 --headless)。用法:
#   godot --path . -s tools/scene_stats.gd -- [--size=1920x1080] [--views=seat,menu,overhead] [--frames=120] [--json=<文件>]


const WARMUP_FRAMES := 60
const VIEWS := {
	# 与 tools/shot.gd 的同名机位一致
	"seat": [Vector3(0.55, 1.92, 2.1), Vector3(0, SeatLayout.TABLE_TOP, -0.12)],
	"menu": [Vector3(2.6, 2.1, 2.9), Vector3(-0.4, 0.9, -0.8)],
	"overhead": [Vector3(0, 2.6, 1.6), Vector3(0, SeatLayout.TABLE_TOP, 0)],
	"opponent": [Vector3(0, 1.3, 0.2), Vector3(0, 1.1, -1.25)],
	"fireplace": [Vector3(0.5, 1.4, -1.5), Vector3(-1.5, 0.8, -4.4)],
	"bar": [Vector3(0.5, 1.5, 0.8), Vector3(-4.0, 1.4, -0.6)],
}

var opts := {}
var _viewport: SubViewport
var _tavern: Tavern


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "true"
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(320, 180)
	var dims: PackedStringArray = opts.get("size", "1920x1080").split("x")
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(dims[0]), int(dims[1]))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")
	root.add_child(_viewport)
	_tavern = Tavern.new()
	_viewport.add_child(_tavern)
	var showcase: Node = load("res://tools/showcase.gd").new()
	_viewport.add_child(showcase)
	await showcase.build(_tavern)
	var report := {"adapter": RenderingServer.get_video_adapter_name(), "size": str(_viewport.size),
		"geometry": _geometry(_viewport), "views": {}}
	print("%s  size=%s" % [report["adapter"], report["size"]])
	var geo: Dictionary = report["geometry"]
	print("geometry: %d mesh nodes, %d surfaces, %d triangles (patrons: %d nodes, %d surfaces, %d triangles)" % [
		geo["nodes"], geo["surfaces"], geo["triangles"], geo["patron_nodes"], geo["patron_surfaces"], geo["patron_triangles"]])
	for view in opts.get("views", "seat,menu,overhead").split(","):
		if not VIEWS.has(view):
			push_error("unknown view %s (known: %s)" % [view, ", ".join(VIEWS.keys())])
			quit(1)
			return
		_tavern.camera_rig.snap(VIEWS[view][0], VIEWS[view][1])
		_tavern.camera_rig.fill_light.light_energy = TableWorld.SEAT_FILL_LIGHT if view == "seat" else 0.0
		var stats := await _measure()
		report["views"][view] = stats
		print("%-10s frame %6.2f ms (p95 %6.2f)  visible: %4d objects %5d draws %8d prims  shadow: %4d objects %5d draws %8d prims" % [
			view, stats["frame_ms"], stats["p95_ms"], stats["objects"], stats["draws"], stats["prims"],
			stats["shadow_objects"], stats["shadow_draws"], stats["shadow_prims"]])
	if opts.has("json"):
		var file := FileAccess.open(opts["json"], FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "  "))
	quit()


func _measure() -> Dictionary:
	# 同 tools/perf_probe.gd:先走几帧让机位生效,再连续 force_draw(不等垂直同步),GPU 排满后的吞吐即每帧耗时
	for i in WARMUP_FRAMES:
		await process_frame
	var frames := int(opts.get("frames", "120"))
	var times := PackedFloat64Array()
	RenderingServer.force_draw(false)
	var last := Time.get_ticks_usec()
	for i in frames:
		RenderingServer.force_draw(false)
		var now := Time.get_ticks_usec()
		times.append((now - last) / 1000.0)
		last = now
	times.sort()
	var total := 0.0
	for t in times:
		total += t
	var vis := Viewport.RENDER_INFO_TYPE_VISIBLE
	var shadow := Viewport.RENDER_INFO_TYPE_SHADOW
	return {
		"frame_ms": total / frames, "p95_ms": times[int(frames * 0.95)],
		"objects": _viewport.get_render_info(vis, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		"draws": _viewport.get_render_info(vis, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"prims": _viewport.get_render_info(vis, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
		"shadow_objects": _viewport.get_render_info(shadow, Viewport.RENDER_INFO_OBJECTS_IN_FRAME),
		"shadow_draws": _viewport.get_render_info(shadow, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME),
		"shadow_prims": _viewport.get_render_info(shadow, Viewport.RENDER_INFO_PRIMITIVES_IN_FRAME),
	}


static func _geometry(scene_root: Node) -> Dictionary:
	var result := {"nodes": 0, "surfaces": 0, "triangles": 0, "patron_nodes": 0, "patron_surfaces": 0, "patron_triangles": 0}
	for node in scene_root.find_children("*", "MeshInstance3D", true, false):
		var inst := node as MeshInstance3D
		if inst.mesh == null or not inst.is_visible_in_tree():
			continue
		var surfaces := inst.mesh.get_surface_count()
		var triangles := _triangles(inst.mesh)
		result["nodes"] += 1
		result["surfaces"] += surfaces
		result["triangles"] += triangles
		if _in_patron(inst):
			result["patron_nodes"] += 1
			result["patron_surfaces"] += surfaces
			result["patron_triangles"] += triangles
	return result


static func _triangles(mesh: Mesh) -> int:
	var count := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		count += indices.size() / 3 if not indices.is_empty() else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return count


static func _in_patron(node: Node) -> bool:
	var parent := node.get_parent()
	while parent != null:
		if parent is Patron:
			return true
		parent = parent.get_parent()
	return false
