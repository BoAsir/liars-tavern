class_name MeshKit
# 程序化建模小工具:用基础几何体快速拼装模型。所有尺寸单位为米。
# 基础体按参数缓存:同参数返回同一份网格(相同网格 + 相同材质才会被 Forward+ 自动实例化)。
# 缓存里的网格只读,调用方不能改它的属性;要变体就加参数(如圆柱的 caps)。参数量化到 0.1 mm,网格按量化后的值建。

const CAPS_NONE := 0
const CAPS_TOP := 1
const CAPS_BOTTOM := 2
const CAPS_BOTH := 3

static var _cache := {}   # key -> 只读 PrimitiveMesh


static func add(parent: Node3D, mesh: Mesh, material: Material, pos := Vector3.ZERO,
		rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = material
	inst.position = pos
	inst.rotation_degrees = rot_deg
	inst.scale = scale
	parent.add_child(inst)
	return inst


static func pivot(parent: Node3D, pos := Vector3.ZERO, node_name := "") -> Node3D:
	var node := Node3D.new()
	if node_name != "":
		node.name = node_name
	node.position = pos
	parent.add_child(node)
	return node


static func box(size: Vector3) -> BoxMesh:
	return _cached("box:%s" % _qv3(size), func():
		var mesh := BoxMesh.new()
		mesh.size = _rv3(size)
		return mesh)


static func cylinder(top_radius: float, bottom_radius: float, height: float, segments := 32,
		caps := CAPS_BOTH) -> CylinderMesh:
	return _cached("cyl:%d,%d,%d,%d,%d" % [_q(top_radius), _q(bottom_radius), _q(height), segments, caps], func():
		var mesh := CylinderMesh.new()
		mesh.top_radius = _r(top_radius)
		mesh.bottom_radius = _r(bottom_radius)
		mesh.height = _r(height)
		mesh.radial_segments = segments
		mesh.rings = 1
		mesh.cap_top = caps & CAPS_TOP != 0
		mesh.cap_bottom = caps & CAPS_BOTTOM != 0
		return mesh)


static func sphere(radius: float, segments := 24) -> SphereMesh:
	return _cached("sph:%d,%d" % [_q(radius), segments], func():
		var mesh := SphereMesh.new()
		mesh.radius = _r(radius)
		mesh.height = _r(radius) * 2.0
		mesh.radial_segments = segments
		mesh.rings = maxi(segments / 2, 6)
		return mesh)


static func hemisphere(radius: float, segments := 24) -> SphereMesh:
	# 独立缓存,不改 sphere() 的结果;rings 规则与 sphere() 相同
	return _cached("hemi:%d,%d" % [_q(radius), segments], func():
		var mesh := SphereMesh.new()
		mesh.radius = _r(radius)
		mesh.height = _r(radius)
		mesh.radial_segments = segments
		mesh.rings = maxi(segments / 2, 6)
		mesh.is_hemisphere = true
		return mesh)


static func capsule(radius: float, height: float, segments := 20) -> CapsuleMesh:
	return _cached("cap:%d,%d,%d" % [_q(radius), _q(height), segments], func():
		var mesh := CapsuleMesh.new()
		mesh.radius = _r(radius)
		mesh.height = maxf(_r(height), _r(radius) * 2.0)
		mesh.radial_segments = segments
		mesh.rings = 6
		return mesh)


static func torus(inner_radius: float, outer_radius: float, segments := 32) -> TorusMesh:
	return _cached("tor:%d,%d,%d" % [_q(inner_radius), _q(outer_radius), segments], func():
		var mesh := TorusMesh.new()
		mesh.inner_radius = _r(inner_radius)
		mesh.outer_radius = _r(outer_radius)
		mesh.rings = segments
		mesh.ring_segments = 12
		return mesh)


static func plane(size: Vector2) -> PlaneMesh:
	return _cached("pln:%d,%d" % [_q(size.x), _q(size.y)], func():
		var mesh := PlaneMesh.new()
		mesh.size = Vector2(_r(size.x), _r(size.y))
		return mesh)


static func quad(size: Vector2) -> QuadMesh:
	return _cached("quad:%d,%d" % [_q(size.x), _q(size.y)], func():
		var mesh := QuadMesh.new()
		mesh.size = Vector2(_r(size.x), _r(size.y))
		return mesh)


static func prism(size: Vector3) -> PrismMesh:
	return _cached("prism:%s" % _qv3(size), func():
		var mesh := PrismMesh.new()
		mesh.size = _rv3(size)
		return mesh)


static func clear_cache() -> void:
	_cache = {}


static func audit_cache() -> PackedStringArray:
	# 按缓存网格的当前属性重算 key,对不上的(被调用方改写过)列出来
	var bad := PackedStringArray()
	for key in _cache:
		if _key_of(_cache[key]) != key:
			bad.append(key)
	return bad


# —— 缓存与量化 ——

static func _cached(key: String, factory: Callable) -> Variant:
	if not _cache.has(key):
		_cache[key] = factory.call()
	return _cache[key]


static func _q(x: float) -> int:
	return roundi(x * 10000.0)


static func _r(x: float) -> float:
	return _q(x) / 10000.0


static func _qv3(v: Vector3) -> String:
	return "%d,%d,%d" % [_q(v.x), _q(v.y), _q(v.z)]


static func _rv3(v: Vector3) -> Vector3:
	return Vector3(_r(v.x), _r(v.y), _r(v.z))


static func _key_of(mesh: Mesh) -> String:
	if mesh is BoxMesh:
		return "box:%s" % _qv3(mesh.size)
	if mesh is CylinderMesh:
		var caps := (CAPS_TOP if mesh.cap_top else 0) | (CAPS_BOTTOM if mesh.cap_bottom else 0)
		return "cyl:%d,%d,%d,%d,%d" % [_q(mesh.top_radius), _q(mesh.bottom_radius), _q(mesh.height), mesh.radial_segments, caps] \
			if mesh.rings == 1 else "cyl:changed"
	if mesh is SphereMesh:
		var prefix := "hemi" if mesh.is_hemisphere else "sph"
		var expected_height: float = mesh.radius if mesh.is_hemisphere else mesh.radius * 2.0
		if not is_equal_approx(mesh.height, expected_height) or mesh.rings != maxi(mesh.radial_segments / 2, 6):
			return prefix + ":changed"
		return "%s:%d,%d" % [prefix, _q(mesh.radius), mesh.radial_segments]
	if mesh is CapsuleMesh:
		return "cap:%d,%d,%d" % [_q(mesh.radius), _q(mesh.height), mesh.radial_segments]
	if mesh is TorusMesh:
		return "tor:%d,%d,%d" % [_q(mesh.inner_radius), _q(mesh.outer_radius), mesh.rings]
	if mesh is QuadMesh:   # QuadMesh 是 PlaneMesh 的子类,先判断
		return "quad:%d,%d" % [_q(mesh.size.x), _q(mesh.size.y)]
	if mesh is PlaneMesh:
		return "pln:%d,%d" % [_q(mesh.size.x), _q(mesh.size.y)]
	if mesh is PrismMesh:
		return "prism:%s" % _qv3(mesh.size)
	return "unknown"
