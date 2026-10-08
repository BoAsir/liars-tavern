class_name Fx
# 粒子与瞬时特效:壁炉火星、光束浮尘、枪口焰、硝烟、火花、出局烟尘。


# 枪口焰:枪口抵在太阳穴外 8–14 mm,往前喷的东西几乎全在头里,所以可见的火焰与火花都往侧面、往后喷;
# 几何上就不让任何面片进头(十字面片朝头最多伸出 GUN_CLEARANCE),不需要深度淡出
const CORE_SIZE := 0.16           # 星形火核(公告板)
const CORE_VIEW_OFFSET := 0.06    # 火核沿视线朝相机推近:与头的交线落在轮廓上,看不出硬切
const CROWN_BACK := 0.06          # 十字面片往后(枪口局部 +Z)伸出
const CROWN_FRONT := 0.008        # 朝头最多伸出(= Patron.GUN_CLEARANCE)
const CROWN_RADIAL := 0.07
const SPARK_DIRECTION := Vector3(0, 0, 1)   # 发射器局部:沿枪身往后,远离头
const SMOKE_FADE := 0.08          # 硝烟与头、桌面相交处的软过渡距离

static var _soft_dot_texture: GradientTexture2D = null
static var _smoke_texture: ImageTexture = null
static var _quads := {}       # 粒子面片(连同材质)按参数缓存:每次开枪不再新建网格与材质
static var _meshes := {}      # 枪口焰的火核与十字面片
static var _materials := {}   # 硝烟材质


static func clear_cache() -> void:
	_soft_dot_texture = null
	_smoke_texture = null
	_quads = {}
	_meshes = {}
	_materials = {}


static func embers(pos: Vector3) -> GPUParticles3D:
	var particles := _particles(pos, 36, 2.6, false)
	var pm := _process_material(Vector3(0.3, 0.04, 0.1), Vector3.UP, 20.0, Vector2(0.25, 0.7))
	pm.gravity = Vector3(0, 0.2, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	pm.turbulence_noise_scale = 2.5
	pm.scale_min = 0.5
	pm.scale_max = 1.3
	pm.color_ramp = _ramp([Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.35, 0.05, 0.9), Color(0.6, 0.1, 0.0, 0.0)])
	particles.process_material = pm
	particles.draw_pass_1 = _additive_quad(0.014, 5.0)
	particles.visibility_aabb = AABB(Vector3(-1, -0.2, -1), Vector3(2, 3.5, 2))
	return particles


static func dust_motes(center: Vector3, extents: Vector3) -> GPUParticles3D:
	# 受光照的浮尘:只有落在灯光/月光里的才看得见
	var particles := _particles(center, 140, 14.0, false)
	particles.preprocess = 14.0
	var pm := _process_material(extents, Vector3.UP, 180.0, Vector2(0.005, 0.02))
	pm.gravity = Vector3(0, -0.002, 0)
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.15
	pm.turbulence_noise_speed_random = 0.3
	pm.color_ramp = _ramp([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
	particles.process_material = pm
	particles.draw_pass_1 = _lit_quad(0.007, Color(1.0, 0.95, 0.85))
	particles.visibility_aabb = AABB(-extents * 1.5, extents * 3.0)
	return particles


static func muzzle_flash(parent: Node3D, xform: Transform3D) -> void:
	# 节点顺序:闪光灯、星形火核、沿枪管的十字面片、火花
	var root := Node3D.new()
	parent.add_child(root)
	root.global_transform = xform
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.38)
	light.light_energy = 10.0   # 灯就在脸旁 1 cm:原来的 16 把整张脸冲成一片白
	light.omni_range = 5.0
	root.add_child(light)
	var core := MeshInstance3D.new()
	core.mesh = core_mesh()
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	core.scale = Vector3.ONE * 0.4
	core.set_instance_shader_parameter("spin", randf() * TAU)
	root.add_child(core)
	var crown := MeshInstance3D.new()
	crown.mesh = crown_mesh()
	crown.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	crown.set_instance_shader_parameter("spin", randf() * TAU)
	crown.scale = Vector3(0.3, 0.3, 1.0)
	root.add_child(crown)
	root.add_child(_burst(Vector3.ZERO, SPARK_DIRECTION, 26, 0.35, Color(1.0, 0.75, 0.3), 70.0))
	var tween := root.create_tween().set_parallel()
	tween.tween_property(light, "light_energy", 0.0, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(core, "scale", Vector3.ONE * 1.3, 0.07)
	tween.tween_property(core, "scale", Vector3.ONE * 0.01, 0.1).set_delay(0.07)
	tween.tween_property(crown, "scale", Vector3.ONE, 0.05)
	tween.tween_property(crown, "scale", Vector3(0.01, 0.01, 1.0), 0.12).set_delay(0.05)
	tween.chain().tween_interval(1.2)
	tween.chain().tween_callback(root.queue_free)


static func core_mesh() -> ArrayMesh:
	if not _meshes.has("core"):
		_meshes["core"] = _fire_quads(func(f: MeshForge):
			f.paint(Color(1.0, 0.72, 0.36), 1.0)
			_quad(f, Vector3(-CORE_SIZE / 2.0, -CORE_SIZE / 2.0, 0), Vector3(CORE_SIZE, 0, 0), Vector3(0, CORE_SIZE, 0)),
			WorldMaterials.muzzle_fire(1, true, 9.0, 1.4, CORE_VIEW_OFFSET))
	return _meshes["core"]


static func crown_mesh() -> ArrayMesh:
	# 两片互相垂直、平面都包含枪管轴线(枪口局部 Z)的四边形:z ∈ [−CROWN_FRONT, CROWN_BACK],径向 ±CROWN_RADIAL;
	# UV.x 沿枪管(枪口点在 crown_origin),UV.y 径向
	if not _meshes.has("crown"):
		_meshes["crown"] = _fire_quads(func(f: MeshForge):
			f.paint(Color(1.0, 0.7, 0.32), 1.0)
			var length := CROWN_FRONT + CROWN_BACK
			for axis in [Vector3.RIGHT, Vector3.UP]:
				_quad(f, Vector3(0, 0, -CROWN_FRONT) - axis * CROWN_RADIAL, Vector3(0, 0, length), axis * CROWN_RADIAL * 2.0),
			WorldMaterials.muzzle_fire(2, false, 12.0, 1.0))
		(_meshes["crown"].surface_get_material(0) as ShaderMaterial).set_shader_parameter("crown_origin",
			CROWN_FRONT / (CROWN_FRONT + CROWN_BACK))
	return _meshes["crown"]


static func _quad(f: MeshForge, corner: Vector3, u: Vector3, v: Vector3) -> void:
	# 一片双面可见的四边形(soft_particle_add 是 cull_disabled):UV.x 沿 u、UV.y 沿 v
	var n := u.cross(v).normalized()
	f.raw(PackedVector3Array([corner, corner + u, corner + u + v, corner + v]), PackedVector3Array([n, n, n, n]),
		PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]), PackedInt32Array([0, 1, 2, 0, 2, 3]))


static func _fire_quads(recipe: Callable, material: Material) -> ArrayMesh:
	return MeshForge.commit(MeshForge.run(recipe), {&"main": material})


static func smoke_puff(parent: Node3D, pos: Vector3, amount := 18, tint := Color(0.75, 0.72, 0.7)) -> void:
	# 絮状硝烟:fbm 絮团贴图,粒子各自旋转,与头和桌面相交处软过渡;登场 / 离场的烟尘共用
	var particles := _particles(pos, amount, 2.8, true)
	particles.explosiveness = 0.85
	var pm := _process_material(Vector3.ONE * 0.02, Vector3.UP, 60.0, Vector2(0.05, 0.25))
	pm.gravity = Vector3(0, 0.06, 0)
	pm.damping_min = 0.4
	pm.damping_max = 0.8
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	pm.angular_velocity_min = -30.0
	pm.angular_velocity_max = 30.0
	pm.scale_curve = _curve_texture([Vector2(0, 0.3), Vector2(1, 2.2)])
	pm.color_ramp = _ramp([Color(tint, 0.0), Color(tint, 0.75), Color(tint, 0.5), Color(tint, 0.0)])   # 絮团贴图比圆点稀:浓度早一点到顶
	particles.process_material = pm
	particles.draw_pass_1 = smoke_quad()
	parent.add_child(particles)
	_emit_once(particles)


static func smoke_quad() -> QuadMesh:
	if not _meshes.has("smoke"):
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.16, 0.16)
		mesh.material = smoke_material()
		_meshes["smoke"] = mesh
	return _meshes["smoke"]


static func smoke_material() -> StandardMaterial3D:
	if not _materials.has("smoke"):
		var mat := StandardMaterial3D.new()
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES   # 自动读粒子的 angle
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = _smoke()
		mat.roughness = 1.0
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.shadow_to_opacity = false
		mat.proximity_fade_enabled = true
		mat.proximity_fade_distance = SMOKE_FADE
		_materials["smoke"] = mat
	return _materials["smoke"]


static func _smoke() -> ImageTexture:
	# 64×64 絮团:FastNoiseLite fbm × 径向衰减(代码生成,缓存一份)
	if _smoke_texture == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM
		noise.fractal_octaves = 4
		noise.frequency = 0.06
		noise.seed = 7
		var image := Image.create(64, 64, true, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
				var fall := clampf(1.0 - d, 0.0, 1.0)
				var n := noise.get_noise_2d(x, y) * 0.5 + 0.5
				var a := clampf(pow(fall, 1.3) * (0.45 + 1.1 * n), 0.0, 1.0)
				image.set_pixel(x, y, Color(1, 1, 1, a))
		image.generate_mipmaps()
		_smoke_texture = ImageTexture.create_from_image(image)
	return _smoke_texture


static func _burst(pos: Vector3, direction: Vector3, amount: int, lifetime: float, color: Color,
		spread := 35.0) -> GPUParticles3D:
	var particles := _particles(pos, amount, lifetime, true)
	particles.explosiveness = 1.0
	var pm := _process_material(Vector3.ONE * 0.005, direction, spread, Vector2(1.2, 3.0))
	pm.gravity = Vector3(0, -3.0, 0)
	pm.color_ramp = _ramp([color, Color(color, 0.0)])
	particles.process_material = pm
	particles.draw_pass_1 = _additive_quad(0.01, 6.0)
	_emit_once(particles)
	return particles


static func _emit_once(particles: GPUParticles3D) -> void:
	# 开始一轮一次性发射,结束(finished)后节点自行释放
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


# —— 构件 ——

static func _particles(pos: Vector3, amount: int, lifetime: float, one_shot: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	# 新建节点默认就在发射:一次性粒子要先停下,之后 _emit_once 才会开启新的一轮并在结束时发出 finished;
	# 否则那次 emitting = true 被当成"发射中重开",finished 信号被取消,节点永远不会释放
	particles.emitting = not one_shot
	particles.position = pos
	particles.amount = amount
	particles.lifetime = lifetime
	particles.one_shot = one_shot
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return particles


static func _process_material(extents: Vector3, direction: Vector3, spread: float,
		velocity: Vector2) -> ParticleProcessMaterial:
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = extents
	pm.direction = direction.normalized()
	pm.spread = spread
	pm.initial_velocity_min = velocity.x
	pm.initial_velocity_max = velocity.y
	pm.gravity = Vector3.ZERO
	return pm


static func _additive_quad(size: float, boost: float) -> QuadMesh:
	var key := "add:%s:%s" % [size, boost]
	if not _quads.has(key):
		_quads[key] = _build_additive_quad(size, boost)
	return _quads[key]


static func _lit_quad(size: float, color: Color) -> QuadMesh:
	var key := "lit:%s:%s" % [size, color.to_html()]
	if not _quads.has(key):
		_quads[key] = _build_lit_quad(size, color)
	return _quads[key]


static func _build_additive_quad(size: float, boost: float) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var mat := WorldMaterials.particle(true, boost, 1.6)
	mesh.material = mat
	return mesh


static func _build_lit_quad(size: float, color: Color) -> QuadMesh:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var mat := StandardMaterial3D.new()
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = color
	mat.albedo_texture = _soft_dot()
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shadow_to_opacity = false
	mesh.material = mat
	return mesh


static func _soft_dot() -> GradientTexture2D:
	if _soft_dot_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		_soft_dot_texture = GradientTexture2D.new()
		_soft_dot_texture.gradient = gradient
		_soft_dot_texture.fill = GradientTexture2D.FILL_RADIAL
		_soft_dot_texture.fill_from = Vector2(0.5, 0.5)
		_soft_dot_texture.fill_to = Vector2(1.0, 0.5)
		_soft_dot_texture.width = 64
		_soft_dot_texture.height = 64
	return _soft_dot_texture


static func _ramp(colors: Array) -> GradientTexture1D:
	var gradient := Gradient.new()
	var offsets := PackedFloat32Array()
	var packed := PackedColorArray()
	for i in colors.size():
		offsets.append(float(i) / (colors.size() - 1))
		packed.append(colors[i])
	gradient.offsets = offsets
	gradient.colors = packed
	var tex := GradientTexture1D.new()
	tex.gradient = gradient
	return tex


static func _curve_texture(points: Array) -> CurveTexture:
	var curve := Curve.new()
	curve.max_value = 3.0
	for p in points:
		curve.add_point(p)
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex
