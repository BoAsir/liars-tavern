extends GutTest
# 壁炉:根节点贴着后墙、炉火光的参数原样保留(灯光由另一个会话调校)、火星留在炉膛里、
# 火苗各自独立(公告板读自己的模型矩阵)且不超过 8 簇、整体不越出划给壁炉的地盘、
# 投射阴影的三角形控制在本区预算的六成以内、网格开场建一次后复用;石块、柴、内衬的三角形朝向与法线一致,
# 错缝铺石让开炉口与拱券,拱心石高出拱圈。


const WALL_Z := -Tavern.ROOM_HALF + Tavern.WALL_THICKNESS / 2.0
# 地盘:x∈[-2.75,-0.25],离墙至多 0.9 米(世界 z ≤ -3.5),地面到天花板;背面允许埋进墙里
const FOOTPRINT := AABB(Vector3(-2.75, 0.0, -Tavern.ROOM_HALF), Vector3(2.5, Tavern.ROOM_HEIGHT, 1.0))
const EPSILON := 0.002
const MAX_FLAMES := 8
const TRIANGLE_BUDGET := 30000
const SHADOW_SHARE := 0.6

var tavern: Tavern
var fireplace: Node3D


func before_each():
	tavern = Tavern.new()
	add_child_autofree(tavern)
	fireplace = tavern.get_node("Fireplace")


func test_fireplace_sits_against_the_back_wall():
	assert_almost_eq(fireplace.position, Vector3(Tavern.FIREPLACE_X, 0, WALL_Z), Vector3.ONE * 0.0001)


func test_fire_light_keeps_its_tuned_parameters():
	var lights := fireplace.get_children().filter(func(node: Node) -> bool: return node is OmniLight3D)
	assert_eq(lights.size(), 1, "壁炉根节点下只有一盏炉火光")
	if lights.is_empty():
		return
	var light: OmniLight3D = lights[0]
	assert_almost_eq(light.position, Vector3(0, 0.5, 0.75), Vector3.ONE * 0.0001, "位置")
	assert_true(light.light_color.is_equal_approx(Color(1.0, 0.56, 0.3)), "颜色")
	assert_almost_eq(light.omni_range, 7.0, 0.0001, "范围")
	assert_true(light.shadow_enabled, "炉火光投射阴影")
	assert_almost_eq(light.light_volumetric_fog_energy, 0.6, 0.0001, "体积雾亮度")
	var flicker := _flicker_of(light)
	assert_false(flicker.is_empty(), "炉火光登记了闪烁")
	if not flicker.is_empty():
		assert_almost_eq(flicker["base"], 2.7, 0.0001, "基础亮度")
		assert_almost_eq(flicker["speed"], 3.5, 0.0001)
		assert_almost_eq(flicker["depth"], 0.3, 0.0001)
		assert_almost_eq(flicker["seed"], 50.0, 0.0001)


func test_embers_rise_from_inside_the_firebox():
	var embers := fireplace.get_children().filter(func(node: Node) -> bool: return node is GPUParticles3D)
	assert_eq(embers.size(), 1, "炉膛里有一团火星")
	if embers.is_empty():
		return
	var pos: Vector3 = embers[0].position
	assert_lt(absf(pos.x), TavernFireplace.OPENING_HALF_WIDTH, "火星在炉口宽度以内")
	assert_between(pos.y, TavernFireplace.HEARTH_TOP, TavernFireplace.SPRING_HEIGHT, "火星在炉膛高度以内")
	assert_between(pos.z, 0.05, TavernFireplace.BODY_DEPTH, "火星在炉膛深度以内")


func test_flames_are_separate_billboards_sitting_in_the_firebox():
	var flames := _flames()
	assert_between(flames.size(), 5, MAX_FLAMES, "火苗 5~8 簇")
	for flame in flames:
		assert_eq(flame.mesh.get_surface_count(), 1, "每簇火苗是单独的一个四边形")
		var pos := fireplace.to_local(flame.global_position)
		assert_lt(absf(pos.x), TavernFireplace.OPENING_HALF_WIDTH, "火苗在炉口宽度以内")
		assert_between(pos.z, 0.05, TavernFireplace.BODY_DEPTH, "火苗在炉膛里")


func test_fireplace_stays_inside_its_footprint():
	for node in fireplace.find_children("*", "MeshInstance3D", true, false):
		var inst := node as MeshInstance3D
		var box := inst.global_transform * inst.mesh.get_aabb()
		assert_true(FOOTPRINT.grow(EPSILON).encloses(box), "%s 在壁炉的地盘里:%s" % [inst.name, box])


func test_fireplace_shadow_casters_stay_light():
	var shadow := 0
	for node in fireplace.find_children("*", "MeshInstance3D", true, false):
		var inst := node as MeshInstance3D
		if inst.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadow += _triangles(inst.mesh)
	assert_lte(shadow, int(TRIANGLE_BUDGET * SHADOW_SHARE), "投射阴影的三角形不超过本区预算的六成")


func test_fireplace_meshes_are_built_once_and_reused():
	var other := Tavern.new()
	add_child_autofree(other)
	var mine := _static_meshes(fireplace)
	var theirs := _static_meshes(other.get_node("Fireplace"))
	assert_gt(mine.size(), 0, "壁炉有合批网格")
	assert_eq(mine, theirs, "第二间酒馆直接取用缓存的网格")


# —— 生成器 ——

func test_log_pieces_face_outward():
	for kind in FireplaceLogs.KINDS:
		_assert_faces_out(FireplaceLogs.log_arrays(0.07, 0.5, kind, 3), "柴(%s)" % kind)


func test_log_pieces_mark_bark_split_faces_and_end_grain():
	var arrays := FireplaceLogs.log_arrays(0.07, 0.5, "quarter", 5)
	var kinds := {}
	for color in arrays[Mesh.ARRAY_COLOR] as PackedColorArray:
		kinds[snappedf(color.a, 0.5)] = true
	assert_true(kinds.has(FireplaceLogs.BARK), "有树皮")
	assert_true(kinds.has(FireplaceLogs.SPLIT), "有劈面")
	assert_true(kinds.has(FireplaceLogs.END_GRAIN), "有锯口")


func test_stones_face_outward():
	var square := PackedVector2Array([Vector2(0, 0), Vector2(0.3, 0), Vector2(0.3, 0.2), Vector2(0, 0.2)])
	_assert_faces_out(FireplaceStones.stone(square, 0.18, 0.015, 0.008), "方石")
	var clockwise := square.duplicate()
	clockwise.reverse()
	_assert_faces_out(FireplaceStones.stone(clockwise, 0.18, 0.015), "顺时针给出的轮廓")
	# 贴着拱券裁出来的凹轮廓:不鼓起,直接三角化
	var notched := PackedVector2Array([Vector2(0, 0), Vector2(0.3, 0), Vector2(0.3, 0.2), Vector2(0.15, 0.12),
		Vector2(0, 0.2)])
	_assert_faces_out(FireplaceStones.stone(notched, 0.18, 0.015, 0.008), "凹轮廓的石块")


func test_courses_leave_the_opening_and_arch_clear():
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var band := PackedVector2Array([Vector2(-1, 0.3), Vector2(1, 0.3), Vector2(1, 1.1), Vector2(-1, 1.1)])
	var hole := FireplaceMasonry.arch_hole()
	var stones := FireplaceStones.lay_rows([band], [hole], Vector2(0.24, 0.42), 0.016, rng)
	assert_gt(stones.size(), 3, "铺出了石块")
	for outline in stones:
		var overlap := Geometry2D.intersect_polygons(outline, hole)
		var area := 0.0
		for piece in overlap:
			area += absf(FireplaceStones.signed_area(piece))
		assert_lt(area, 0.0001, "石块不压进炉口与拱券")


func test_arch_has_a_raised_keystone():
	var key := FireplaceMasonry._voussoir(FireplaceMasonry.KEYSTONE, 0.0)
	var side := FireplaceMasonry._voussoir(0, 0.0)
	var key_top := FireplaceStones.bounds_of(key).end.y
	var crown := TavernFireplace.arch_center().y + TavernFireplace.arch_radius() + FireplaceMasonry.RING_DEPTH
	assert_gt(key_top, crown + 0.03, "拱心石高出拱圈")
	assert_gt(FireplaceStones.signed_area(FireplaceStones.ccw(key)), FireplaceStones.signed_area(FireplaceStones.ccw(side)),
		"拱心石比其他拱石大")


func test_firebox_liner_faces_into_the_cavity():
	var arrays := FireplaceMasonry.firebox_liner()
	_assert_faces_out(arrays, "炉膛内衬")
	# 法线都朝向炉膛里面(炉口前方的点)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var inside := Vector3(0, TavernFireplace.SPRING_HEIGHT * 0.6, TavernFireplace.BODY_DEPTH)
	var wrong := 0
	for i in verts.size():
		if normals[i].dot(inside - verts[i]) <= 0.0:
			wrong += 1
	assert_eq(wrong, 0, "内衬法线朝向炉膛(%d 个朝外)" % wrong)


# —— 工具 ——

func _flicker_of(light: Light3D) -> Dictionary:
	for entry in tavern._flickers:
		if entry["light"] == light:
			return entry
	return {}


func _flames() -> Array:
	return fireplace.find_children("*", "MeshInstance3D", true, false).filter(func(node: Node) -> bool:
		var mat := (node as MeshInstance3D).material_override as ShaderMaterial
		return mat != null and mat.shader == WorldMaterials.FLAME_SHADER)


func _static_meshes(root: Node) -> Array:
	var meshes := []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var inst := node as MeshInstance3D
		if inst.material_override == null:
			meshes.append(inst.mesh)
	return meshes


static func _triangles(mesh: Mesh) -> int:
	var total := 0
	for i in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(i)
		var indices: Variant = arrays[Mesh.ARRAY_INDEX]
		total += (indices as PackedInt32Array).size() / 3 if indices != null \
			else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	return total


func _assert_faces_out(arrays: Array, label: String) -> void:
	# Godot 正面为顺时针:三角形 (a,b,c) 的外法线 ∝ (c-a)×(b-a),应与顶点法线同向
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var wrong := 0
	var checked := 0
	for t in range(0, indices.size(), 3):
		var a := verts[indices[t]]
		var b := verts[indices[t + 1]]
		var c := verts[indices[t + 2]]
		var face := (c - a).cross(b - a)
		if face.length() < 1e-9:
			continue
		checked += 1
		var avg := normals[indices[t]] + normals[indices[t + 1]] + normals[indices[t + 2]]
		if face.normalized().dot(avg.normalized()) <= 0.0:
			wrong += 1
	assert_gt(checked, 0, label + ":有三角形")
	assert_eq(wrong, 0, label + ":所有三角形朝外(%d/%d 朝内)" % [wrong, checked])
