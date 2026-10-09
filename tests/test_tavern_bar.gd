extends GutTest
# 吧台:根节点贴着左墙、吧台暖光的参数原样保留、整体(含高脚凳)不越出划给吧台的地盘、
# 不挡住左墙上的两盏壁灯、投射阴影的三角形控制在本区预算的六成以内、酒瓶合进极少的表面、
# 网格开场建一次后复用;酒瓶与杯子的生成器三角形朝外。


const WALL_X := -Tavern.ROOM_HALF + Tavern.WALL_THICKNESS / 2.0
# 地盘:x∈[-4.4,-2.55](背面允许埋进墙里),z∈[-2.5,1.3],高不过 2.7 米
const FOOTPRINT := AABB(Vector3(-Tavern.ROOM_HALF, 0.0, -2.5), Vector3(Tavern.ROOM_HALF - 2.55, 2.7, 3.8))
const SCONCE_POINTS := [Vector3(-4.4, Tavern.SCONCE_HEIGHT, 2.0), Vector3(-4.4, Tavern.SCONCE_HEIGHT, -3.1)]
const SCONCE_CLEARANCE := 0.3
const EPSILON := 0.002
const TRIANGLE_BUDGET := 45000
const SHADOW_SHARE := 0.6
const MAX_BOTTLE_SURFACES := 4   # 玻璃、酒标、瓶塞/封蜡、陶瓶

var tavern: Tavern
var bar: Node3D


func before_each():
	tavern = Tavern.new()
	add_child_autofree(tavern)
	bar = tavern.get_node("Bar")


func test_bar_sits_against_the_left_wall():
	assert_almost_eq(bar.position, Vector3(WALL_X, 0, -0.6), Vector3.ONE * 0.0001)


func test_bar_light_keeps_its_tuned_parameters():
	var lights := bar.get_children().filter(func(node: Node) -> bool: return node is OmniLight3D)
	assert_eq(lights.size(), 1, "吧台根节点下只有一盏暖光")
	if lights.is_empty():
		return
	var light: OmniLight3D = lights[0]
	assert_almost_eq(light.position, Vector3(0.9, 2.5, 0), Vector3.ONE * 0.0001, "位置")
	assert_true(light.light_color.is_equal_approx(Color(1.0, 0.7, 0.4)), "颜色")
	assert_almost_eq(light.light_energy, 1.4, 0.0001, "亮度")
	assert_almost_eq(light.omni_range, 3.8, 0.0001, "范围")
	assert_false(light.shadow_enabled, "吧台暖光不投影")


func test_bar_stays_inside_its_footprint():
	for node in bar.find_children("*", "MeshInstance3D", true, false):
		var inst := node as MeshInstance3D
		var box := inst.global_transform * inst.mesh.get_aabb()
		assert_true(FOOTPRINT.grow(EPSILON).encloses(box), "%s 在吧台的地盘里:%s" % [inst.name, box])


func test_bar_keeps_clear_of_the_left_wall_sconces():
	for point in SCONCE_POINTS:
		var keep_out := AABB(point - Vector3.ONE * SCONCE_CLEARANCE, Vector3.ONE * SCONCE_CLEARANCE * 2.0)
		for node in bar.find_children("*", "MeshInstance3D", true, false):
			var inst := node as MeshInstance3D
			for box in _part_boxes(inst):
				assert_false(keep_out.intersects(box), "%s 不挡壁灯 %s" % [inst.name, point])


func test_bar_shadow_casters_stay_light():
	var shadow := 0
	for node in bar.find_children("*", "MeshInstance3D", true, false):
		var inst := node as MeshInstance3D
		if inst.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadow += _triangles(inst.mesh)
	assert_lte(shadow, int(TRIANGLE_BUDGET * SHADOW_SHARE), "投射阴影的三角形不超过本区预算的六成")


func test_bottles_are_merged_into_a_few_surfaces():
	var shelves := bar.get_node_or_null("Bottles") as MeshInstance3D
	assert_not_null(shelves, "酒瓶合成一个网格")
	if shelves != null:
		assert_lte(shelves.mesh.get_surface_count(), MAX_BOTTLE_SURFACES, "酒瓶只占几个表面")
		assert_eq(shelves.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "酒瓶不投影")


func test_bar_meshes_are_built_once_and_reused():
	var other := Tavern.new()
	add_child_autofree(other)
	var mine := _meshes(bar)
	var theirs := _meshes(other.get_node("Bar"))
	assert_gt(mine.size(), 0, "吧台有合批网格")
	assert_eq(mine, theirs, "第二间酒馆直接取用缓存的网格")


# —— 生成器 ——

func test_every_bottle_shape_faces_outward():
	for kind in BarBottles.KINDS:
		_assert_faces_out(BarBottles.body_arrays(kind, 0.26, 0.036), "酒瓶(%s)" % kind)


# —— 工具 ——

func _part_boxes(inst: MeshInstance3D) -> Array:
	# 合批网格的整体包围盒太大(整个吧台),按三角形逐个检查是否碰到壁灯
	var boxes := []
	for s in inst.mesh.get_surface_count():
		var arrays := inst.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for t in range(0, indices.size(), 3):
			var box := AABB(verts[indices[t]], Vector3.ZERO).expand(verts[indices[t + 1]]).expand(verts[indices[t + 2]])
			boxes.append(inst.global_transform * box)
	return boxes


func _meshes(root: Node) -> Array:
	var meshes := []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append((node as MeshInstance3D).mesh)
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
