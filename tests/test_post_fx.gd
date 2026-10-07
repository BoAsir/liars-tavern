extends GutTest
# PostFx:切屏复位(打断举枪紧张、色差脉冲、中弹染红)。


var fx: PostFx


func before_each():
	fx = PostFx.new()
	add_child_autofree(fx)


func _flash_alpha() -> float:
	var color: Color = fx._mat.get_shader_parameter("flash_color")
	return color.a


func _assert_calm():
	assert_almost_eq(fx._param("vignette"), PostFx.BASE_VIGNETTE, 0.001)
	assert_almost_eq(fx._param("desaturate"), 0.0, 0.001)
	assert_almost_eq(fx._param("aberration"), 0.0, 0.001)
	assert_almost_eq(_flash_alpha(), 0.0, 0.001)


func test_starts_calm():
	_assert_calm()


func test_reset_restores_calm_immediately():
	fx.set_tension(1.0, 0.05)
	fx.flash(Color(0.25, 0.0, 0.0, 0.85), 5.0)
	await wait_seconds(0.15)
	assert_gt(fx._param("vignette"), PostFx.BASE_VIGNETTE + 0.1)
	assert_gt(_flash_alpha(), 0.1)
	fx.reset()
	_assert_calm()


func test_reset_stops_running_tweens():
	fx.set_tension(1.0, 0.3)
	fx.pulse_aberration(1.6, 0.3)
	fx.flash(Color(0.25, 0.0, 0.0, 0.85), 0.3)
	await wait_process_frames(2)
	fx.reset()
	await wait_seconds(0.45)
	_assert_calm()


func test_reset_with_duration_eases_back_to_calm():
	fx.set_tension(1.0, 0.05)
	fx.flash(Color(0.25, 0.0, 0.0, 0.85), 5.0)
	await wait_seconds(0.15)
	fx.reset(0.2)
	await wait_process_frames(2)
	assert_gt(_flash_alpha(), 0.0, "复位是渐变的,不是一下切回")
	await wait_seconds(0.35)
	_assert_calm()


func test_calm_screen_skips_the_screen_copy():
	# 平静时只叠加暗角/闪光/颗粒,不读屏幕纹理(4K 下整屏拷贝约 2 毫秒)
	assert_false(fx.reads_screen())


func test_flash_alone_does_not_need_the_screen():
	fx.flash(Color(0.25, 0.0, 0.0, 0.85), 5.0)
	await wait_process_frames(2)
	assert_false(fx.reads_screen())


func test_tension_and_aberration_switch_to_screen_pass():
	fx.set_tension(1.0, 0.05)
	await wait_seconds(0.1)
	assert_true(fx.reads_screen(), "去饱和、色差要读屏幕")
	fx.reset()
	assert_false(fx.reads_screen(), "复位后回到只叠加")
	fx.pulse_aberration(1.6, 0.2)
	await wait_process_frames(3)
	assert_true(fx.reads_screen())
	await wait_seconds(0.3)
	assert_false(fx.reads_screen(), "色差回落到 0 后不再读屏幕")


func test_overlay_tracks_the_same_parameters():
	fx.set_tension(0.0, 0.0)
	fx.flash(Color(0.25, 0.0, 0.0, 0.85), 5.0)
	await wait_process_frames(2)
	var overlay: ShaderMaterial = fx._overlay_mat
	assert_almost_eq(overlay.get_shader_parameter("vignette"), fx._param("vignette"), 0.001)
	assert_eq(overlay.get_shader_parameter("flash_color"), fx._mat.get_shader_parameter("flash_color"))


func test_aberration_pulse_eases_back_from_its_peak():
	fx.pulse_aberration(1.6, 0.5)
	await wait_seconds(0.15)
	# 峰值在 0.1 秒;之后应从峰值逐渐回落,而不是瞬间掉回原值
	assert_gt(fx._param("aberration"), 1.0)
	await wait_seconds(0.5)
	assert_almost_eq(fx._param("aberration"), 0.0, 0.001)
