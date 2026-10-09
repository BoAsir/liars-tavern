class_name ConfettiFx
# 礼炮的彩纸与卷曲彩带(规格 2026-10-09-winner-celebration):GPUParticles3D 一次性喷发,运动在 confetti_motion.gdshader
# 里算(阻力、飘、翻滚、落桌 / 落地平躺、最后缩没),画法在 confetti.gdshader(不打光的粉彩、不投影、不透明)。
# 网格与材质按参数缓存:彩纸面片、彩带网格、画法材质全体共用;运动材质按牌桌(桌心、半径、桌面、地板)各一份。
# 每次喷发的方向来自发射器的朝向(局部 +Y),数量由调用方给(Celebration 管总数上限)。

const MOTION_SHADER := preload("res://src/world/shaders/confetti_motion.gdshader")
const DRAW_SHADER := preload("res://src/world/shaders/confetti.gdshader")
const LIFETIME := 5.2           # 秒:飞出去、飘下来、平躺一会儿、缩没
const STREAMER_LIFETIME := 5.6
const EXPLOSIVENESS := 0.96     # 一声「砰」里几乎同时喷出(留一点点先后,像一股)
const VISIBILITY := AABB(Vector3(-4, -2, -4), Vector3(8, 6, 8))

static var _cache := {}


static func clear_cache() -> void:
	_cache.clear()


static func burst(parent: Node3D, xform: Transform3D, table: Dictionary, confetti: int, streamers: int,
		speed := Vector2(3.0, 5.5)) -> Array[GPUParticles3D]:
	# 在 xform(全局;+Y 为喷射方向)喷一股:confetti 片彩纸 + streamers 条彩带。
	# table = {"center": 全局桌心, "radius": 桌面半径, "top": 全局桌面高, "floor": 全局地板高}。返回建出的粒子节点(结束后自行释放)
	var out: Array[GPUParticles3D] = []
	if confetti > 0:
		out.append(_emit(parent, xform, confetti, LIFETIME, motion(table, false, speed), paper_quad()))
	if streamers > 0:
		out.append(_emit(parent, xform, streamers, STREAMER_LIFETIME, motion(table, true, speed), streamer_mesh()))
	return out


static func _emit(parent: Node3D, xform: Transform3D, amount: int, lifetime: float, process: ShaderMaterial,
		mesh: Mesh) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = "Confetti"
	particles.emitting = false   # 一次性粒子先停着,加进树后再开(见 Fx._particles 的说明)
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = EXPLOSIVENESS
	particles.local_coords = false
	particles.fixed_fps = 0      # 逐帧推进:翻滚得快,插值会把旋转矩阵插扁
	particles.interpolate = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = VISIBILITY
	particles.process_material = process
	particles.draw_pass_1 = mesh
	particles.add_to_group(&"confetti")
	parent.add_child(particles)
	particles.global_transform = xform
	particles.emitting = true
	particles.finished.connect(particles.queue_free)
	return particles


static func motion(table: Dictionary, streamer: bool, speed: Vector2) -> ShaderMaterial:
	var center: Vector3 = table.get("center", Vector3.ZERO)
	var key := "motion:%s:%.3f:%.3f:%.3f:%s:%s" % [center, table.get("radius", SeatLayout.TABLE_RADIUS),
		table.get("top", SeatLayout.FELT_TOP), table.get("floor", 0.0), streamer, speed]
	if not _cache.has(key):
		var mat := ShaderMaterial.new()
		mat.shader = MOTION_SHADER
		mat.set_shader_parameter("table_center", center)
		mat.set_shader_parameter("table_radius", table.get("radius", SeatLayout.TABLE_RADIUS))
		mat.set_shader_parameter("table_top", table.get("top", SeatLayout.FELT_TOP))
		mat.set_shader_parameter("floor_y", table.get("floor", 0.0))
		mat.set_shader_parameter("speed", speed)
		mat.set_shader_parameter("streamer", 1.0 if streamer else 0.0)
		_cache[key] = mat
	return _cache[key]


static func draw_material() -> ShaderMaterial:
	if not _cache.has("draw"):
		var mat := ShaderMaterial.new()
		mat.shader = DRAW_SHADER
		_cache["draw"] = mat
	return _cache["draw"]


static func paper_quad() -> QuadMesh:
	# 一片 1 米见方的面片,大小由粒子变换缩放(方片 / 长纸条)
	if not _cache.has("paper"):
		var mesh := QuadMesh.new()
		mesh.size = Vector2.ONE
		mesh.material = draw_material()
		_cache["paper"] = mesh
	return _cache["paper"]


static func streamer_mesh() -> ArrayMesh:
	# 卷曲彩带:一条窄纸带绕成弹簧(螺旋 2.5 圈、长 0.17 m),纸带宽度沿螺旋轴;原点在中间
	if not _cache.has("streamer"):
		_cache["streamer"] = MeshForge.cached("confetti:streamer", func(f: MeshForge):
			f.paint(Color.WHITE, 1.0)
			var points := PackedVector3Array()
			var normals := PackedVector3Array()
			var uvs := PackedVector2Array()
			var indices := PackedInt32Array()
			var steps := 40
			var turns := 2.5
			var length := 0.17
			var radius := 0.02
			var width := 0.011
			for i in steps + 1:
				var s := float(i) / steps
				var a := s * turns * TAU
				var radial := Vector3(cos(a), 0.0, sin(a))
				var c := radial * radius * (1.0 - 0.25 * s) + Vector3(0.0, (s - 0.5) * length, 0.0)
				for side: float in [-0.5, 0.5]:
					points.append(c + Vector3(0.0, side * width, 0.0))
					normals.append(radial)
					uvs.append(Vector2(s, side + 0.5))
				if i > 0:
					var k := (i - 1) * 2
					indices.append_array([k, k + 2, k + 1, k + 1, k + 2, k + 3])
			f.raw(points, normals, uvs, indices),
			{&"main": draw_material()})
	return _cache["streamer"]
