extends GutTest
# 特效:一次性粒子(硝烟/登场烟尘/枪口火花)寿命结束后自行释放;加色粒子用加色混合的着色器。


const FAST_CLOCK := 8.0   # 粒子寿命以秒计:加速时钟,测试不必真等
const MAX_WAIT := 6.0     # 加速后的游戏秒:最长的硝烟寿命约 3.2 秒
const EMBER_CHECK := 3.0  # 超过火星的一个寿命(2.6 秒)

var parent: Node3D


func before_each():
	parent = add_child_autofree(Node3D.new())


func after_each():
	Engine.time_scale = 1.0


func _particles(root: Node) -> Array:
	return root.find_children("*", "GPUParticles3D", true, false)


func _freed(node: Node) -> Callable:
	# 按实例 id 判断:直接捕获节点的 lambda 在节点释放后调用会报错
	var id := node.get_instance_id()
	return func() -> bool: return not is_instance_id_valid(id)


func test_smoke_puff_frees_itself_after_its_lifetime():
	Fx.smoke_puff(parent, Vector3.ZERO)
	var smoke: GPUParticles3D = _particles(parent)[0]
	Engine.time_scale = FAST_CLOCK
	assert_true(await wait_until(_freed(smoke), MAX_WAIT), "硝烟应自行释放")


func test_muzzle_sparks_free_themselves_before_the_flash_does():
	# 火花在进入场景树之前就开始发射,同样要能结束并释放
	Fx.muzzle_flash(parent, Transform3D.IDENTITY)
	var sparks: GPUParticles3D = _particles(parent)[0]
	var flash: Node = parent.get_child(0)
	assert_true(await wait_until(_freed(sparks), 1.0), "火花应自行释放")
	assert_true(is_instance_valid(flash), "枪口焰节点稍后才由自己的补间释放")


func test_continuous_embers_keep_emitting():
	var embers := Fx.embers(Vector3.ZERO)
	parent.add_child(embers)
	Engine.time_scale = FAST_CLOCK
	await wait_seconds(EMBER_CHECK)
	assert_true(is_instance_valid(embers) and embers.emitting)


func test_additive_particles_use_the_additive_shader():
	assert_eq(WorldMaterials.particle(true, 1.0, 1.0).shader, WorldMaterials.PARTICLE_ADD_SHADER)
	assert_eq(WorldMaterials.particle(false, 1.0, 1.0).shader, WorldMaterials.PARTICLE_SHADER)
	assert_string_contains(WorldMaterials.PARTICLE_ADD_SHADER.code, "blend_add")
	assert_false(WorldMaterials.PARTICLE_SHADER.code.contains("blend_add"))


func test_effect_quads_and_particle_materials_are_shared():
	# 每次开枪不再新建网格与材质:同参数的粒子面片与材质共用一份
	assert_same(Fx._additive_quad(0.32, 9.0), Fx._additive_quad(0.32, 9.0))
	assert_same(Fx._lit_quad(0.12, Color.WHITE), Fx._lit_quad(0.12, Color.WHITE))
	assert_not_same(Fx._lit_quad(0.12, Color.WHITE), Fx._lit_quad(0.12, Color.RED))
	assert_same(WorldMaterials.particle(true, 5.0, 1.6), WorldMaterials.particle(true, 5.0, 1.6))
	assert_not_same(WorldMaterials.particle(true, 5.0, 1.6), WorldMaterials.particle(false, 5.0, 1.6))


# —— 子项目③ §8:星形火核、沿枪管的十字面片、往后喷的火花、絮状硝烟 ——

func _meshes_of(root: Node) -> Array:
	return root.find_children("*", "MeshInstance3D", true, false)


func test_flash_and_smoke_materials_are_cached():
	Fx.muzzle_flash(parent, Transform3D.IDENTITY)
	Fx.muzzle_flash(parent, Transform3D.IDENTITY)
	var flashes := parent.get_children().filter(func(n): return n.get_child_count() > 0 and n.get_child(0) is OmniLight3D)
	assert_eq(flashes.size(), 2)
	var a := _meshes_of(flashes[0])
	var b := _meshes_of(flashes[1])
	assert_eq(a.size(), 2, "火核 + 十字面片")
	for i in a.size():
		assert_same(a[i].mesh, b[i].mesh, "同一份网格(连同材质)")
	Fx.smoke_puff(parent, Vector3.ZERO)
	Fx.smoke_puff(parent, Vector3.ONE)
	var smokes := _particles(parent).filter(func(p): return p.draw_pass_1 == Fx.smoke_quad())
	assert_eq(smokes.size(), 2, "两次硝烟共用一份面片与材质")


func test_node_order_light_core_crown_sparks():
	Fx.muzzle_flash(parent, Transform3D.IDENTITY)
	var root: Node = parent.get_child(0)
	assert_true(root.get_child(0) is OmniLight3D)
	assert_same((root.get_child(1) as MeshInstance3D).mesh, Fx.core_mesh())
	assert_same((root.get_child(2) as MeshInstance3D).mesh, Fx.crown_mesh())
	assert_true(root.get_child(3) is GPUParticles3D, "火花在最后")


func test_smoke_rotates_and_fades_softly():
	var mat := Fx.smoke_material()
	assert_true(mat is StandardMaterial3D, "受光的标准材质,不新增着色器")
	assert_eq(mat.billboard_mode, BaseMaterial3D.BILLBOARD_PARTICLES)
	assert_true(mat.proximity_fade_enabled)
	assert_almost_eq(mat.proximity_fade_distance, 0.08, 0.0001)
	assert_not_null(mat.albedo_texture, "絮团贴图")
	Fx.smoke_puff(parent, Vector3.ZERO)
	var pm: ParticleProcessMaterial = _particles(parent)[0].process_material
	assert_gte(pm.angle_max - pm.angle_min, 180.0, "随机初始角")
	assert_lte(_particles(parent)[0].lifetime, 3.2, "硝烟寿命")


func test_flash_stays_outside_the_head():
	# 十字面片所有顶点在枪口局部 z ≥ −GUN_CLEARANCE(朝头那一侧最多伸出 8 mm);火花沿枪身往后喷
	var verts: PackedVector3Array = Fx.crown_mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in verts:
		assert_gte(v.z, -Patron.GUN_CLEARANCE - 1e-6)
	Fx.muzzle_flash(parent, Transform3D.IDENTITY)
	var sparks: GPUParticles3D = _particles(parent)[0]
	assert_eq((sparks.process_material as ParticleProcessMaterial).direction, Vector3(0, 0, 1))


func test_shared_particle_include_has_no_depth_texture():
	# 火星一直可见,共享 include 引用深度纹理会让每帧多一次深度拷贝
	var text := FileAccess.get_file_as_string("res://src/world/shaders/soft_particle.gdshaderinc")
	assert_false(text.contains("hint_depth_texture"))
