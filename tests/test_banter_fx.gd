extends GutTest
# 丢番茄与说话的世界表现(规格 §5、§7,无头):落点在目标头附近、各端种子一致落点一致;命中后番茄泥挂在目标 Head 下、
# 约 6 秒后释放;同一个头最多 3 块;出局的酒客被砸不报错也不反应;观战者从吧台方向丢;说话点头、返回时间表;
# 静止状态下酒客的网格数不变(场景预算)。


var world: TableWorld
var fx: BanterFx


func before_each():
	Engine.time_scale = 1.0
	world = TableWorld.new(null)
	add_child_autofree(world)
	world.arrange([{"pid": 1, "species": 0}, {"pid": 2, "species": 3}, {"pid": 3, "species": 7}, {"pid": 4, "species": 5}],
		1, true, false)
	fx = world.banter
	await wait_seconds(0.7)   # 登场动画放完


func after_each():
	Engine.time_scale = 1.0


func _visible_meshes(patron: Patron) -> int:
	return patron.find_children("*", "MeshInstance3D", true, false).filter(
		func(m: MeshInstance3D) -> bool: return m.is_visible_in_tree()).size()


func test_world_has_a_banter_fx_child():
	assert_not_null(fx)
	assert_eq(fx.get_parent(), world)


func test_hit_point_is_on_the_skull_and_deterministic_per_seed():
	var target: Patron = world.patrons[3]
	var ellipsoid := target.skull_ellipsoid()
	for seed in [1, 2, 3, 99, 12345]:
		var a := RandomNumberGenerator.new()
		a.seed = seed
		var b := RandomNumberGenerator.new()
		b.seed = seed
		var hit_a := fx.hit_point(target, a)
		var hit_b := fx.hit_point(target, b)
		assert_eq(hit_a["local"], hit_b["local"], "同一种子落点相同")
		var rel: Vector3 = (hit_a["local"] - ellipsoid[0]) / ellipsoid[1]
		assert_almost_eq(rel.length(), 1.0, 0.02, "落点在颅骨椭球表面上")
		assert_lt(Vector3(hit_a["local"]).z, ellipsoid[0].z, "落在脸那一侧(酒客面朝 -Z)")


func test_tomato_flies_from_the_throwers_hand_and_splats_on_the_target_head():
	watch_signals(fx)
	var target: Patron = world.patrons[3]
	fx.throw_tomato(2, 3, 42)
	await wait_process_frames(2)
	var flying := fx.get_tree().get_nodes_in_group(BanterFx.TOMATO_GROUP)
	assert_eq(flying.size(), 1, "蓄力时番茄在手里")
	assert_eq(flying[0].get_parent(), world.patrons[2].right_hand)
	await wait_seconds(Patron.THROW_WINDUP + BanterFx.FLIGHT_TIME * 0.5)
	flying = fx.get_tree().get_nodes_in_group(BanterFx.TOMATO_GROUP)
	assert_eq(flying.size(), 1)
	assert_eq(flying[0].get_parent(), fx, "出手后在空中飞")
	var mid_distance: float = flying[0].global_position.distance_to(target.head_position())
	await wait_seconds(BanterFx.FLIGHT_TIME * 0.5 + 0.15)
	assert_signal_emitted_with_parameters(fx, "splatted", [3])
	assert_eq(fx.get_tree().get_nodes_in_group(BanterFx.TOMATO_GROUP).filter(
		func(n: Node) -> bool: return not n.is_queued_for_deletion()).size(), 0, "番茄砸完就没了")
	var splats := BanterFx.splats_on(target)
	assert_eq(splats.size(), 1, "番茄泥挂在目标 Head 下")
	assert_eq(splats[0].get_parent(), target.head)
	assert_lt(splats[0].global_position.distance_to(target.head_position()), 0.45, "落点在头附近")
	assert_gt(mid_distance, 0.2, "飞行途中还没到")


func test_same_seed_lands_on_the_same_spot_on_every_peer():
	# 两个独立的世界(两台机器)用同一个种子:泥贴在同一处
	var other := TableWorld.new(null)
	add_child_autofree(other)
	other.arrange([{"pid": 1, "species": 0}, {"pid": 2, "species": 3}, {"pid": 3, "species": 7}, {"pid": 4, "species": 5}],
		2, true, false)
	await wait_seconds(0.7)
	fx.throw_tomato(4, 3, 777)
	other.banter.throw_tomato(4, 3, 777)
	await wait_seconds(Patron.THROW_WINDUP + BanterFx.FLIGHT_TIME + 0.2)
	var a: Node3D = BanterFx.splats_on(world.patrons[3])[0]
	var b: Node3D = BanterFx.splats_on(other.patrons[3])[0]
	assert_true(a.position.is_equal_approx(b.position), "Head 局部的落点一致")


func test_splat_is_released_after_about_six_seconds():
	var target: Patron = world.patrons[2]
	var before := _visible_meshes(target)
	var blob := fx.splat(target, Vector3(0, 0.12, -0.3), Vector3(0, 0, -1))
	assert_eq(blob.get_parent(), target.head)
	assert_eq(blob.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "小件不投影")
	# 手动推进补间(不受机器快慢影响):别的补间一起推进也无妨
	_step_tweens(BanterFx.SPLAT_LIFE - 1.5)
	assert_true(is_instance_valid(blob) and not blob.is_queued_for_deletion(), "6 秒之前还在")
	_step_tweens(1.5 + 0.2)
	assert_false(is_instance_valid(blob) and not blob.is_queued_for_deletion(), "约 6 秒后释放")
	await wait_process_frames(2)
	assert_eq(_visible_meshes(target), before, "静止状态下酒客的网格数不变")


func _step_tweens(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		var step := minf(left, 0.1)
		for tween in get_tree().get_processed_tweens():
			if tween.is_valid():
				tween.custom_step(step)
		left -= step


func test_at_most_three_splats_per_head_oldest_first():
	var target: Patron = world.patrons[4]
	var blobs := []
	for i in 5:
		blobs.append(fx.splat(target, Vector3(0.02 * i, 0.12, -0.3), Vector3(0, 0, -1)))
	var left := BanterFx.splats_on(target)
	assert_eq(left.size(), BanterFx.MAX_SPLATS)
	assert_eq(left, blobs.slice(2), "最旧的先没")


func test_dead_patron_gets_the_splat_but_no_reaction():
	var target: Patron = world.patrons[3]
	target.die()
	await wait_seconds(0.2)
	watch_signals(fx)
	fx.throw_tomato(2, 3, 5)
	await wait_seconds(Patron.THROW_WINDUP + BanterFx.FLIGHT_TIME + 0.2)
	assert_signal_emitted(fx, "splatted")
	assert_eq(BanterFx.splats_on(target).size(), 1)
	assert_null(target._wipe_tween, "出局的不抹脸")


func test_living_target_wipes_its_face_and_recovers():
	var target: Patron = world.patrons[2]
	target.hit_by_tomato(Vector3.ZERO)
	assert_true(target._arms_locked, "抹脸时手被占着")
	await wait_seconds(1.0)
	assert_false(target._arms_locked, "抹完把手搭回桌上")


func test_thrower_without_patron_throws_from_the_bar():
	fx.throw_tomato(99, 3, 8)
	await wait_process_frames(2)
	var flying := fx.get_tree().get_nodes_in_group(BanterFx.TOMATO_GROUP)
	assert_eq(flying.size(), 1)
	assert_eq(flying[0].get_parent(), fx, "没有手可握:直接飞")
	assert_lt(flying[0].global_position.distance_to(world.to_global(BanterFx.SPECTATOR_FROM)), 0.6)


func test_busy_thrower_throws_without_the_pose():
	var thrower: Patron = world.patrons[2]
	thrower._arms_locked = true   # 正在举枪 / 拍桌
	fx.throw_tomato(2, 3, 8)
	await wait_process_frames(2)
	var flying := fx.get_tree().get_nodes_in_group(BanterFx.TOMATO_GROUP)
	assert_eq(flying[0].get_parent(), fx)
	thrower._arms_locked = false


func test_unknown_target_does_nothing():
	fx.throw_tomato(1, 42, 1)
	await wait_process_frames(2)
	assert_eq(fx.get_tree().get_nodes_in_group(BanterFx.TOMATO_GROUP).size(), 0)


func test_clear_removes_tomatoes_in_flight():
	fx.throw_tomato(99, 3, 1)
	await wait_process_frames(1)
	world.clear()
	await wait_process_frames(1)
	assert_eq(fx.get_tree().get_nodes_in_group(BanterFx.TOMATO_GROUP).size(), 0)


func test_eight_tomatoes_at_once_stay_cheap():
	for k in 8:
		fx.throw_tomato(99, 1 + k % 4, k)
	await wait_seconds(BanterFx.FLIGHT_TIME + 0.3)
	var total := 0
	for pid in world.patrons:
		total += BanterFx.splats_on(world.patrons[pid]).size()
	assert_eq(total, 8)
	for pid in world.patrons:
		assert_lte(BanterFx.splats_on(world.patrons[pid]).size(), BanterFx.MAX_SPLATS)


func test_say_returns_the_layout_and_nods_without_voice_when_disabled():
	var speaker: Patron = world.patrons[2]
	assert_false(fx.voice_enabled, "无头 / 静音时不出声")
	var plan := fx.say(2, 4, Species.UNASSIGNED)
	assert_eq(plan, AnimalVoice.phrase_layout(speaker.species_index, 4, AnimalVoice.bucket_for(2)), "按酒客的物种念")
	assert_null(speaker.head.get_node_or_null("Voice"), "不出声时不建声源")
	var peak := 0.0
	for i in 20:
		await wait_process_frames(1)
		peak = maxf(peak, speaker._antics.nod)
	assert_gt(peak, 0.01, "头随音节点一下")


func test_say_without_patron_uses_the_fallback_species():
	var plan := fx.say(77, 0, 6)
	assert_eq(plan, AnimalVoice.phrase_layout(6, 0, AnimalVoice.bucket_for(77)))


func test_meshes_come_from_the_forge_cache_with_the_prop_material():
	assert_same(BanterFx.tomato_mesh(), BanterFx.tomato_mesh())
	assert_same(BanterFx.splat_mesh(), BanterFx.splat_mesh())
	assert_same(BanterFx.splat_mesh().surface_get_material(0), WorldMaterials.prop())
	assert_same(BanterFx.tomato_mesh().surface_get_material(0), WorldMaterials.prop())


func test_juice_splash_is_capped_and_frees_itself():
	var particles := Fx.juice_splash(world, Vector3(0, 1.4, 0), Vector3.FORWARD, 100)
	assert_lte(particles.amount, Fx.JUICE_MAX)
	assert_eq(particles.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_true(particles.finished.is_connected(particles.queue_free))
