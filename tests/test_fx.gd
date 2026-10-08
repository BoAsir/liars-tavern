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
