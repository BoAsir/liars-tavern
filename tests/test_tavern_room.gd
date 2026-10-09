extends GutTest
# 房间:木构架、护墙板、门、窗帘都贴着墙,不伸进屋里;壁炉开间留给壁炉;月光的参数原样保留
# (灯光另有调校);网格开场拼一次、之后共用;投影的三角形不超过本区预算的六成。


const ROOM_INNER := 4.4
const WALL_REACH := 0.35                   # 梁以下的建筑构件离墙不超过这么远(托木最深 0.3)
const BELOW_BEAMS := 2.9
const FIREPLACE_BAY := AABB(Vector3(-2.74, 0.01, -4.39), Vector3(2.48, 3.19, 0.89))   # 边界上的顶梁端头不算
const ROOM_TRIANGLES := 30000
const SHADOW_SHARE := 0.6


func test_architecture_hugs_the_walls_below_the_beams():
	var intruding := []
	for v in _room_vertices():
		if v.y <= 0.02 or v.y >= BELOW_BEAMS:
			continue
		var wall_distance := minf(ROOM_INNER - absf(v.x), ROOM_INNER - absf(v.z))
		if wall_distance > WALL_REACH:
			intruding.append(v)
	assert_eq(intruding.size(), 0, "梁以下的构件都贴着墙:%s" % str(intruding.slice(0, 5)))


func test_fireplace_bay_is_left_free():
	var inside := []
	for v in _room_vertices():
		if FIREPLACE_BAY.has_point(v):
			inside.append(v)
	assert_eq(inside.size(), 0, "壁炉开间留空:%s" % str(inside.slice(0, 5)))


func test_moonlight_keeps_its_tuned_parameters():
	var tavern := Tavern.new()
	add_child_autofree(tavern)
	var moon: SpotLight3D = null
	for child in tavern.get_children():
		if child is SpotLight3D:
			moon = child
	assert_not_null(moon, "月光")
	if moon == null:
		return
	assert_eq(moon.light_color, Color(0.5, 0.62, 1.0), "颜色")
	assert_almost_eq(moon.light_energy, 3.0, 0.001, "亮度")
	assert_almost_eq(moon.spot_range, 9.0, 0.001, "范围")
	assert_almost_eq(moon.spot_angle, 24.0, 0.001, "张角")
	assert_true(moon.shadow_enabled, "投影")
	assert_almost_eq(moon.light_volumetric_fog_energy, 2.5, 0.001, "体积雾")


func test_room_meshes_are_built_once_and_shared():
	assert_same(TavernRoom.shell_mesh(), TavernRoom.shell_mesh(), "墙面网格缓存")
	assert_same(TavernRoom.frame_mesh(), TavernRoom.frame_mesh(), "木构架网格缓存")


func test_shadow_casting_share_stays_small():
	var shadow := _triangles(TavernRoom.frame_mesh())
	assert_gt(shadow, 0, "木构架投影")
	assert_lte(shadow, int(ROOM_TRIANGLES * SHADOW_SHARE), "投影的三角形不超过本区预算的六成")


# —— 工具 ——

static func _room_vertices() -> PackedVector3Array:
	var verts := PackedVector3Array()
	for mesh in [TavernRoom.shell_mesh(), TavernRoom.frame_mesh()]:
		for i in (mesh as ArrayMesh).get_surface_count():
			verts.append_array((mesh as ArrayMesh).surface_get_arrays(i)[Mesh.ARRAY_VERTEX])
	return verts


static func _triangles(mesh: Mesh) -> int:
	var total := 0
	for i in mesh.get_surface_count():
		total += (mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return total
