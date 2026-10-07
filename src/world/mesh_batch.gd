class_name MeshBatch
extends RefCounted
# 合批建模:把许多小几何体按"槽位"合并成一个 ArrayMesh,每个槽位一个表面(= 一次绘制调用)。
# 槽位是 Material 时,材质直接烘进网格(静态道具共用材质);是字符串时只记名字,实例化时按名字给材质
# (每个酒客各有一套能单独褪色的材质,网格却能按物种共用)。
# 每个顶点额外带两组自定义数据,供程序化着色器使用:
#   CUSTOM0.xyz = 部件自身坐标(合并前的物体坐标):木纹、桌布等按物体坐标取纹理的着色器,合并前后纹理一致;
#   CUSTOM1.x   = LOCAL_MARKER + 部件种子(0..1):>= LOCAL_MARKER 表示来自合批,种子让同批的木板、瓶子各不相同。
# 顶点色 = 部件的 tint(材质读取 COLOR 才生效:StandardMaterial3D 需开 vertex_color_use_as_albedo)。
# 建好的网格可按 key 缓存(cached):同一样东西只拼装一次,中途加入、复活的酒客直接取用,对局中不卡顿。


const LOCAL_MARKER := 2.0
const CUSTOM_FLAGS := (Mesh.ARRAY_CUSTOM_RGB_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT) \
	| (Mesh.ARRAY_CUSTOM_R_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT)

static var _cache := {}

var _surfaces := {}   # 槽位 -> _Surface
var _order := []      # 槽位按首次使用的顺序排列,决定表面顺序
var _parts := 0


class _Surface:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var local := PackedVector3Array()
	var seeds := PackedFloat32Array()
	var indices := PackedInt32Array()


# —— 添加部件 ——

func add(mesh: Mesh, slot: Variant, xform := Transform3D.IDENTITY, tint := Color.WHITE, seed := -1.0) -> MeshBatch:
	# 基础几何体(PrimitiveMesh)直接在 CPU 上生成顶点;其他网格逐个表面读出
	if mesh is PrimitiveMesh:
		return add_arrays((mesh as PrimitiveMesh).get_mesh_arrays(), slot, xform, tint, seed)
	for i in mesh.get_surface_count():
		add_arrays(mesh.surface_get_arrays(i), slot, xform, tint, seed)
	return self


func add_part(mesh: Variant, slot: Variant, pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scale := Vector3.ONE,
		tint := Color.WHITE, seed := -1.0) -> MeshBatch:
	# 与 MeshKit.add 相同的摆放参数;mesh 可以是 Mesh 或 MeshShapes 生成的数组
	var xform := xform_of(pos, rot_deg, scale)
	if mesh is Array:
		return add_arrays(mesh, slot, xform, tint, seed)
	return add(mesh, slot, xform, tint, seed)


func add_arrays(arrays: Array, slot: Variant, xform := Transform3D.IDENTITY, tint := Color.WHITE,
		seed := -1.0) -> MeshBatch:
	var src: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	if src.is_empty():
		return self
	var surface := _surface(slot)
	var base := surface.verts.size()
	var count := src.size()
	surface.verts.append_array(xform * src)
	surface.local.append_array(src)
	surface.normals.append_array(_transform_normals(arrays[Mesh.ARRAY_NORMAL], xform.basis, count))
	var uvs: Variant = arrays[Mesh.ARRAY_TEX_UV]
	if uvs != null and (uvs as PackedVector2Array).size() == count:
		surface.uvs.append_array(uvs)
	else:
		surface.uvs.append_array(_filled_vec2(count))
	surface.colors.append_array(_tinted_colors(arrays[Mesh.ARRAY_COLOR], tint, count))
	var part_seed := seed if seed >= 0.0 else fposmod(sin(_parts * 12.9898 + 4.1) * 43758.5453, 1.0)
	var seeds := PackedFloat32Array()
	seeds.resize(count)
	seeds.fill(LOCAL_MARKER + clampf(part_seed, 0.0, 0.999))
	surface.seeds.append_array(seeds)
	_append_indices(surface, arrays[Mesh.ARRAY_INDEX], base, count, xform.basis.determinant() < 0.0)
	_parts += 1
	return self


# —— 生成 ——

func is_empty() -> bool:
	return _order.is_empty()


func slots() -> Array:
	return _order.duplicate()


func triangle_count() -> int:
	var total := 0
	for slot in _order:
		total += (_surfaces[slot] as _Surface).indices.size() / 3
	return total


func build() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for slot in _order:
		var surface: _Surface = _surfaces[slot]
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = surface.verts
		arrays[Mesh.ARRAY_NORMAL] = surface.normals
		arrays[Mesh.ARRAY_TEX_UV] = surface.uvs
		arrays[Mesh.ARRAY_COLOR] = surface.colors
		arrays[Mesh.ARRAY_CUSTOM0] = surface.local.to_byte_array().to_float32_array()
		arrays[Mesh.ARRAY_CUSTOM1] = surface.seeds
		arrays[Mesh.ARRAY_INDEX] = surface.indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, CUSTOM_FLAGS)
		var index := mesh.get_surface_count() - 1
		if slot is Material:
			mesh.surface_set_material(index, slot)
		else:
			mesh.surface_set_name(index, str(slot))
	return mesh


func commit(parent: Node3D, node_name := "", materials := {}, cast_shadow := true) -> MeshInstance3D:
	return instance(parent, build(), materials, node_name, cast_shadow)


static func instance(parent: Node3D, mesh: ArrayMesh, materials := {}, node_name := "",
		cast_shadow := true) -> MeshInstance3D:
	# 字符串槽位按名字从 materials 取材质(实例级覆盖,网格本身可被多个实例共用)
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	if node_name != "":
		inst.name = node_name
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i) != null:
			continue
		var slot_name := mesh.surface_get_name(i)
		if materials.has(slot_name):
			inst.set_surface_override_material(i, materials[slot_name])
		else:
			push_error("MeshBatch: no material for slot '%s'" % slot_name)
	if not cast_shadow:
		inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)
	return inst


static func cached(key: String, builder: Callable) -> ArrayMesh:
	# builder: func(batch: MeshBatch) -> void。同一 key 只拼装一次
	if not _cache.has(key):
		var batch := MeshBatch.new()
		builder.call(batch)
		_cache[key] = batch.build()
	return _cache[key]


static func is_cached(key: String) -> bool:
	return _cache.has(key)


static func clear_cache() -> void:
	_cache = {}


static func xform_of(pos := Vector3.ZERO, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	# 与 Node3D 的 position / rotation_degrees(YXZ 欧拉角)/ scale 组合方式相同
	var rot := Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z))
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scale), pos)


# —— 内部 ——

func _surface(slot: Variant) -> _Surface:
	if not _surfaces.has(slot):
		_surfaces[slot] = _Surface.new()
		_order.append(slot)
	return _surfaces[slot]


static func _transform_normals(normals: Variant, basis: Basis, count: int) -> PackedVector3Array:
	if normals == null or (normals as PackedVector3Array).size() != count:
		var up := PackedVector3Array()
		up.resize(count)
		up.fill(Vector3.UP)
		return up
	# 法线用逆转置矩阵变换;只有旋转 + 等比缩放时整批原生变换,非等比缩放才逐个归一化
	var normal_basis := basis.inverse().transposed()
	var scale := basis.get_scale()
	if is_equal_approx(scale.x, scale.y) and is_equal_approx(scale.y, scale.z):
		return Transform3D(normal_basis.orthonormalized(), Vector3.ZERO) * (normals as PackedVector3Array)
	var out := Transform3D(normal_basis, Vector3.ZERO) * (normals as PackedVector3Array)
	for i in out.size():
		out[i] = out[i].normalized()
	return out


static func _filled_vec2(count: int) -> PackedVector2Array:
	var arr := PackedVector2Array()
	arr.resize(count)
	return arr


static func _tinted_colors(colors: Variant, tint: Color, count: int) -> PackedColorArray:
	var out := PackedColorArray()
	if colors != null and (colors as PackedColorArray).size() == count:
		out = (colors as PackedColorArray).duplicate()
		if tint != Color.WHITE:
			for i in count:
				out[i] = out[i] * tint
		return out
	out.resize(count)
	out.fill(tint)
	return out


static func _append_indices(surface: _Surface, indices: Variant, base: int, count: int, mirrored: bool) -> void:
	# 镜像变换(行列式为负)会把三角形翻到背面,交换两个顶点恢复正面朝外
	var src: PackedInt32Array = indices if indices != null else PackedInt32Array(range(count))
	var start := surface.indices.size()
	surface.indices.resize(start + src.size())
	var a := 1 if mirrored else 2
	var b := 2 if mirrored else 1
	for t in range(0, src.size(), 3):
		surface.indices[start + t] = src[t] + base
		surface.indices[start + t + a] = src[t + 2] + base
		surface.indices[start + t + b] = src[t + 1] + base
