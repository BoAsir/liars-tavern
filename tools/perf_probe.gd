extends SceneTree
# 性能探针:在离屏 SubViewport 里按指定分辨率渲染酒馆 + 展台,逐项关闭渲染特性,打印整帧耗时(毫秒)。
# 需要窗口渲染(不能 --headless);离屏渲染,不会占满屏幕,也不受显示器刷新率限制。
# 用法:godot --path . -s tools/perf_probe.gd -- [--size=3840x2160] [--view=seat] [--frames=120] [--cases=fsr-0.5+post-off,ssil-off] [--shot=<目录>] [--showcase=liars|poker]
# 不给 --cases 时逐项单独测一遍全部开关。--showcase=poker 用德州展台的最坏情况(8 位酒客、每摞筹码与下注摆满、
# 7 个底池,约 900 枚筹码),机位取自 TableWorld;德州的帧耗时要求不超过骗子酒馆 4 人展台的 1.25 倍(规格 §8)。
# 每行另打印该配置下一帧的绘制调用数(draw calls)。


const WARMUP_FRAMES := 60
const SHOWCASES := {"liars": "res://tools/showcase.gd", "poker": "res://tools/poker_showcase.gd"}

var opts := {}
var _viewport: SubViewport
var _tavern: Tavern
var _post_fx: PostFx
var _world: TableWorld = null   # 德州展台的牌桌:机位从它取


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=", true, 1)
		opts[kv[0]] = kv[1] if kv.size() > 1 else "true"
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size = Vector2i(320, 180)
	var dims: PackedStringArray = opts.get("size", "3840x2160").split("x")
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(int(dims[0]), int(dims[1]))
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.msaa_3d = ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")
	root.add_child(_viewport)
	_tavern = Tavern.new()
	_viewport.add_child(_tavern)
	_post_fx = PostFx.new()
	_viewport.add_child(_post_fx)
	var kind: String = opts.get("showcase", "liars")
	if not SHOWCASES.has(kind):
		push_error("unknown showcase %s (known: %s)" % [kind, ", ".join(SHOWCASES.keys())])
		quit(1)
		return
	var showcase: Node = load(SHOWCASES[kind]).new()
	if kind == "poker":
		showcase.set("worst_case", true)
	_viewport.add_child(showcase)
	await showcase.build(_tavern)
	_world = showcase.get("world") if kind == "poker" else null
	_place_camera(opts.get("view", "seat"))
	print("%s / %s  size=%s view=%s msaa=%d" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_driver_name(),
		_viewport.size, opts.get("view", "seat"), _viewport.msaa_3d])
	var toggles := _toggles()
	var cases: PackedStringArray = opts["cases"].split(",") if opts.has("cases") else PackedStringArray(toggles.keys())
	var base := await _measure()
	_report("baseline (all on)", base, base)
	_shot("baseline")
	for case in cases:
		var undos := []
		for name in case.split("+"):
			if not toggles.has(name):
				push_error("unknown toggle %s (known: %s)" % [name, ", ".join(toggles.keys())])
				quit(1)
				return
			undos.append(toggles[name].call())
		_report(case, await _measure(), base)
		_shot(case)
		undos.reverse()
		for undo in undos:
			undo.call()
	_report("baseline again (drift check)", await _measure(), base)
	quit()


func _toggles() -> Dictionary:
	# 名字 -> 应用这项改动并返回撤销函数;--cases 用 + 组合多项,用 , 分隔多组
	var env := _tavern.environment
	return {
		"msaa-off": func(): return _swap(_viewport, "msaa_3d", Viewport.MSAA_DISABLED),
		"ssao-off": func(): return _swap(env, "ssao_enabled", false),
		"ssil-off": func(): return _swap(env, "ssil_enabled", false),
		"fog-off": func(): return _swap(env, "volumetric_fog_enabled", false),
		"glow-off": func(): return _swap(env, "glow_enabled", false),
		"shadows-off": _shadows_off,
		"post-off": func(): return _swap(_post_fx, "visible", false),
		"post-screen": _post_screen,
		"plain-shaders": _plain_materials,
		"fsr-0.75": func(): return _scale(0.75, Viewport.SCALING_3D_MODE_FSR),
		"fsr-0.67": func(): return _scale(0.667, Viewport.SCALING_3D_MODE_FSR),
		"fsr-0.5": func(): return _scale(0.5, Viewport.SCALING_3D_MODE_FSR),
		"bilinear-0.67": func(): return _scale(0.667, Viewport.SCALING_3D_MODE_BILINEAR),
		"bilinear-0.5": func(): return _scale(0.5, Viewport.SCALING_3D_MODE_BILINEAR),
		"budget": func(): return _budget(),
		"fsr2-0.5": func(): return _scale(0.5, Viewport.SCALING_3D_MODE_FSR2),
		"fsr2-0.67": func(): return _scale(0.667, Viewport.SCALING_3D_MODE_FSR2),
		"fxaa": func(): return _swap(_viewport, "screen_space_aa", Viewport.SCREEN_SPACE_AA_FXAA),
		"smaa": func(): return _swap(_viewport, "screen_space_aa", Viewport.SCREEN_SPACE_AA_SMAA),
		"sconce-lights-off": func(): return _lights_off("Sconce"),
		"candle-lights-off": func(): return _lights_off("Candles"),
		"lamp-lights-off": func(): return _lights_off("LampPivot"),
		"fireplace-light-off": func(): return _lights_off("Fireplace"),
		"fireplace-shadow-off": func(): return _shadow_off("Fireplace"),
		"ssil-low": func(): return _ssil_quality(RenderingServer.ENV_SSIL_QUALITY_LOW),
		"ssao-low": func(): return _ssao_quality(RenderingServer.ENV_SSAO_QUALITY_LOW),
		"fog-small": _fog_small,
		"soft-shadow-hard": func(): return _soft_shadows(RenderingServer.SHADOW_QUALITY_HARD),
	}


func _budget() -> Callable:
	# 游戏实际使用的配置(RenderBudget):限制 3D 像素数 + FSR 放大 + SMAA
	var undos := [_swap(_viewport, "msaa_3d", _viewport.msaa_3d), _swap(_viewport, "screen_space_aa", _viewport.screen_space_aa),
		_swap(_viewport, "scaling_3d_mode", _viewport.scaling_3d_mode), _swap(_viewport, "scaling_3d_scale", _viewport.scaling_3d_scale)]
	RenderBudget.apply(_viewport)
	return func():
		for undo in undos:
			undo.call()


func _post_screen() -> Callable:
	# 强制走读屏幕的完整后处理(去饱和给一个看不出来的量),对比只叠加的平时状态
	_post_fx._set_param("desaturate", 0.002)
	return func(): _post_fx._set_param("desaturate", 0.0)


func _lights_under(prefix: String) -> Array:
	return _viewport.find_children("*", "Light3D", true, false).filter(
		func(l: Light3D): return String(l.get_parent().name).begins_with(prefix))


func _lights_off(prefix: String) -> Callable:
	var lights := _lights_under(prefix)
	for light in lights:
		light.visible = false
	return func():
		for light in lights:
			light.visible = true


func _shadow_off(prefix: String) -> Callable:
	var lights := _lights_under(prefix).filter(func(l): return l.shadow_enabled)
	for light in lights:
		light.shadow_enabled = false
	return func():
		for light in lights:
			light.shadow_enabled = true


func _ssil_quality(quality: RenderingServer.EnvironmentSSILQuality) -> Callable:
	RenderingServer.environment_set_ssil_quality(quality, true, 0.5, 4, 50.0, 300.0)
	return func(): RenderingServer.environment_set_ssil_quality(_setting("ssil/quality"), _setting("ssil/half_size"),
		_setting("ssil/adaptive_target"), _setting("ssil/blur_passes"), _setting("ssil/fadeout_from"), _setting("ssil/fadeout_to"))


func _ssao_quality(quality: RenderingServer.EnvironmentSSAOQuality) -> Callable:
	RenderingServer.environment_set_ssao_quality(quality, true, 0.5, 2, 50.0, 300.0)
	return func(): RenderingServer.environment_set_ssao_quality(_setting("ssao/quality"), _setting("ssao/half_size"),
		_setting("ssao/adaptive_target"), _setting("ssao/blur_passes"), _setting("ssao/fadeout_from"), _setting("ssao/fadeout_to"))


func _fog_small() -> Callable:
	RenderingServer.environment_set_volumetric_fog_volume_size(48, 48)
	return func(): RenderingServer.environment_set_volumetric_fog_volume_size(_setting("volumetric_fog/volume_size"),
		_setting("volumetric_fog/volume_depth"))


func _soft_shadows(quality: RenderingServer.ShadowQuality) -> Callable:
	RenderingServer.positional_soft_shadow_filter_set_quality(quality)
	RenderingServer.directional_soft_shadow_filter_set_quality(quality)
	return func():
		RenderingServer.positional_soft_shadow_filter_set_quality(
			ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality"))
		RenderingServer.directional_soft_shadow_filter_set_quality(
			ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality"))


func _setting(key: String) -> Variant:
	return ProjectSettings.get_setting("rendering/environment/" + key)


func _swap(target: Object, property: String, value: Variant) -> Callable:
	var old: Variant = target.get(property)
	target.set(property, value)
	return func(): target.set(property, old)


func _scale(scale: float, mode: Viewport.Scaling3DMode) -> Callable:
	var undo_scale := _swap(_viewport, "scaling_3d_scale", scale)
	var undo_mode := _swap(_viewport, "scaling_3d_mode", mode)
	return func():
		undo_scale.call()
		undo_mode.call()


func _shadows_off() -> Callable:
	var lights := _viewport.find_children("*", "Light3D", true, false).filter(func(l): return l.shadow_enabled)
	for light in lights:
		light.shadow_enabled = false
	return func():
		for light in lights:
			light.shadow_enabled = true


func _plain_materials() -> Callable:
	# 把程序化 ShaderMaterial 换成同色的 StandardMaterial3D,估算这些着色器的片元开销
	var swapped := []
	for node in _viewport.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node.mesh == null:
			continue
		for i in mesh_node.mesh.get_surface_count():
			var mat := mesh_node.get_active_material(i)
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader.get_mode() == Shader.MODE_SPATIAL:
				var plain := StandardMaterial3D.new()
				var tint: Variant = (mat as ShaderMaterial).get_shader_parameter("color_light")
				plain.albedo_color = tint if tint is Color else Color(0.4, 0.3, 0.2)
				swapped.append([mesh_node, i, mesh_node.get_surface_override_material(i)])
				mesh_node.set_surface_override_material(i, plain)
	print("  (swapped %d procedural surfaces)" % swapped.size())
	return func():
		for entry in swapped:
			entry[0].set_surface_override_material(entry[1], entry[2])


func _measure() -> Dictionary:
	# Metal 上 viewport_get_measured_render_time_gpu 恒为 0,窗口呈现又会被系统按刷新率节流:
	# 先走几帧让改动生效,再连续 force_draw(不交换缓冲、不等垂直同步),GPU 排满后吞吐就是每帧 GPU 耗时
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
	return {"avg": total / frames, "p95": times[int(frames * 0.95)]}


func _shot(label: String) -> void:
	# --shot=<目录> 时把每组配置的画面存成 PNG,对比画质损失
	if not opts.has("shot"):
		return
	DirAccess.make_dir_recursive_absolute(opts["shot"])
	var path := "%s/%s.png" % [opts["shot"], label]
	_viewport.get_texture().get_image().save_png(path)


func _report(label: String, m: Dictionary, base: Dictionary) -> void:
	print("%-30s frame %6.2f ms  p95 %6.2f ms  (%+6.2f ms vs base, %5.1f fps)  draw calls %d" % [
		label, m["avg"], m["p95"], m["avg"] - base["avg"], 1000.0 / m["avg"],
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])


func _place_camera(view: String) -> void:
	var rig := _tavern.camera_rig
	var top := SeatLayout.TABLE_TOP
	if _world != null:
		# 德州展台:本机座位 = 1 号的越肩或观战机位
		var xform := _world.overview_view() if view == "overview" else _world.third_person_view(1)
		rig.snap(xform.origin, xform.origin - xform.basis.z)
		rig.fill_light.light_energy = 0.0 if view == "overview" else TableWorld.SEAT_FILL_LIGHT
		return
	match view:
		"menu":
			rig.snap(Vector3(2.6, 2.1, 2.9), Vector3(-0.4, 0.9, -0.8))
		"overhead":
			rig.snap(Vector3(0, 2.6, 1.6), Vector3(0, top, 0))
		_:
			rig.snap(Vector3(0.55, 1.92, 2.1), Vector3(0, top, -0.12))
			rig.fill_light.light_energy = TableWorld.SEAT_FILL_LIGHT
