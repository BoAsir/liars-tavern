class_name Fx
# 粒子与瞬时特效:壁炉火星、光束浮尘、枪口焰、硝烟、火花、出局烟尘。


static var _soft_dot_texture: GradientTexture2D = null


static func clear_cache() -> void:
	_soft_dot_texture = null


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
	var root := Node3D.new()
	parent.add_child(root)
	root.global_transform = xform
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.72, 0.38)
	light.light_energy = 16.0
	light.omni_range = 5.0
	root.add_child(light)
	var flash := MeshInstance3D.new()
	flash.mesh = _additive_quad(0.32, 9.0)
	flash.scale = Vector3.ONE * 0.4
	root.add_child(flash)
	root.add_child(_burst(Vector3.ZERO, -xform.basis.z, 26, 0.35, Color(1.0, 0.75, 0.3)))
	var tween := root.create_tween().set_parallel()
	tween.tween_property(light, "light_energy", 0.0, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(flash, "scale", Vector3.ONE * 1.3, 0.07)
	tween.tween_property(flash, "scale", Vector3.ONE * 0.01, 0.1).set_delay(0.07)
	tween.chain().tween_interval(1.2)
	tween.chain().tween_callback(root.queue_free)


static func smoke_puff(parent: Node3D, pos: Vector3, amount := 18, tint := Color(0.75, 0.72, 0.7)) -> void:
	var particles := _particles(pos, amount, 2.8, true)
	particles.explosiveness = 0.85
	var pm := _process_material(Vector3.ONE * 0.02, Vector3.UP, 60.0, Vector2(0.05, 0.25))
	pm.gravity = Vector3(0, 0.06, 0)
	pm.damping_min = 0.4
	pm.damping_max = 0.8
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	pm.scale_curve = _curve_texture([Vector2(0, 0.3), Vector2(1, 2.2)])
	pm.color_ramp = _ramp([Color(tint, 0.0), Color(tint, 0.45), Color(tint, 0.0)])
	particles.process_material = pm
	particles.draw_pass_1 = _lit_quad(0.12, Color.WHITE)
	parent.add_child(particles)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)


static func sparks(parent: Node3D, pos: Vector3, direction: Vector3, color := Color(1.0, 0.8, 0.35)) -> void:
	parent.add_child(_burst(pos, direction, 20, 0.5, color))


static func _burst(pos: Vector3, direction: Vector3, amount: int, lifetime: float, color: Color) -> GPUParticles3D:
	var particles := _particles(pos, amount, lifetime, true)
	particles.explosiveness = 1.0
	var pm := _process_material(Vector3.ONE * 0.005, direction, 35.0, Vector2(1.2, 3.0))
	pm.gravity = Vector3(0, -3.0, 0)
	pm.color_ramp = _ramp([color, Color(color, 0.0)])
	particles.process_material = pm
	particles.draw_pass_1 = _additive_quad(0.01, 6.0)
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	return particles


# —— 构件 ——

static func _particles(pos: Vector3, amount: int, lifetime: float, one_shot: bool) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
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
	var mesh := QuadMesh.new()
	mesh.size = Vector2(size, size)
	var mat := WorldMaterials.particle(true, boost, 1.6)
	mesh.material = mat
	return mesh


static func _lit_quad(size: float, color: Color) -> QuadMesh:
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
