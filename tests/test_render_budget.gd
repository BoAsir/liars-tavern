extends GutTest
# RenderBudget:3D 按固定像素预算渲染(超出时降内部分辨率、FSR 放大),抗锯齿用 SMAA 替代 MSAA。


func test_small_windows_render_at_full_resolution():
	assert_eq(RenderBudget.scale_for(Vector2i(1280, 720)), 1.0)
	assert_eq(RenderBudget.scale_for(Vector2i(1920, 1080)), 1.0)


func test_4k_renders_3d_at_half_resolution():
	assert_almost_eq(RenderBudget.scale_for(Vector2i(3840, 2160)), 0.5, 0.0001)


func test_hidpi_window_scales_down_to_the_budget():
	# 4K 屏上 1280x720 逻辑尺寸的窗口实为 2560x1440 像素
	assert_almost_eq(RenderBudget.scale_for(Vector2i(2560, 1440)), 0.75, 0.0001)


func test_internal_pixels_stay_within_budget():
	for size in [Vector2i(3024, 1964), Vector2i(3456, 2234), Vector2i(2880, 1800)]:
		var scale := RenderBudget.scale_for(size)
		assert_lte(size.x * size.y * scale * scale, RenderBudget.MAX_3D_PIXELS * 1.0001, str(size))


func test_scale_never_drops_below_fsr_floor():
	assert_eq(RenderBudget.scale_for(Vector2i(6016, 3384)), RenderBudget.MIN_SCALE)


func test_degenerate_size_is_safe():
	assert_eq(RenderBudget.scale_for(Vector2i.ZERO), 1.0)


func test_apply_configures_viewport():
	var viewport := SubViewport.new()
	viewport.size = Vector2i(3840, 2160)
	add_child_autofree(viewport)
	RenderBudget.apply(viewport)
	assert_eq(viewport.msaa_3d, Viewport.MSAA_DISABLED)
	assert_eq(viewport.screen_space_aa, Viewport.SCREEN_SPACE_AA_SMAA)
	assert_eq(viewport.scaling_3d_mode, Viewport.SCALING_3D_MODE_FSR)
	assert_almost_eq(viewport.scaling_3d_scale, 0.5, 0.0001)
