extends GutTest
# 陈设:地毯平铺在地上、盖住椅子圈;所有陈设让开别的区域的地盘(壁炉、吧台、壁灯四周、窗洞)、
# 牌桌四周的空地与相机路线;网格开场拼一次、之后共用;投影的三角形不超过本区预算的六成。


const ROOM_INNER := 4.4
const RUG_MIN_RADIUS := 2.3
const RUG_MAX_HEIGHT := 0.01
const TABLE_CLEARING := 2.3                # 牌桌 + 椅子圈:地毯以外什么都不放
const ABOVE_RUG := 0.012
const CAMERA_HEIGHT := 1.4                 # 这个高度以上离墙不得超过 WALL_REACH(相机路线)
const WALL_REACH := 0.8
const SCONCE_CLEARANCE := 0.25
const SCONCES := [Vector3(-1.7, 2.15, 4.4), Vector3(1.7, 2.15, 4.4), Vector3(1.4, 2.15, -4.4), Vector3(3.2, 2.15, -4.4),
	Vector3(-4.4, 2.15, 2.0), Vector3(-4.4, 2.15, -3.1), Vector3(4.4, 2.15, 1.7)]
const FIREPLACE := AABB(Vector3(-2.75, 0.0, -4.4), Vector3(2.5, 3.4, 0.9))
const BAR := AABB(Vector3(-4.4, 0.0, -2.5), Vector3(1.85, 2.7, 3.8))
const WINDOW_FRONT := AABB(Vector3(3.6, 1.15, -1.55), Vector3(0.8, 1.25, 1.3))
const DECOR_TRIANGLES := 40000
const SHADOW_SHARE := 0.6


func test_rug_lies_flat_and_covers_the_chair_ring():
	var verts: PackedVector3Array = DecorRug.disc()[Mesh.ARRAY_VERTEX]
	var widest := 0.0
	for v in verts:
		assert_between(v.y, 0.0, RUG_MAX_HEIGHT, "地毯贴地,厚不过 1 厘米")
		widest = maxf(widest, Vector2(v.x, v.z).length())
	assert_gte(widest, RUG_MIN_RADIUS, "地毯半径盖住八人大桌的椅子圈")


func test_decor_keeps_out_of_reserved_areas():
	var problems := []
	for v in _decor_vertices():
		var problem := _reserved_problem(v)
		if problem != "":
			problems.append("%s @ %s" % [problem, v])
	assert_eq(problems.size(), 0, "陈设让开保留区:%s" % str(problems.slice(0, 5)))


func test_decor_meshes_are_built_once_and_shared():
	assert_same(TavernDecor.props_mesh(), TavernDecor.props_mesh(), "大件网格缓存")
	assert_same(TavernDecor.detail_mesh(), TavernDecor.detail_mesh(), "细节网格缓存")


func test_small_details_do_not_cast_shadows():
	var tavern := Tavern.new()
	add_child_autofree(tavern)
	var shadow := 0
	for node in tavern.get_node("Decor").find_children("*", "MeshInstance3D", true, false):
		var inst := node as MeshInstance3D
		if inst.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			shadow += _triangles(inst.mesh)
	assert_gt(shadow, 0, "大件投影")
	assert_lte(shadow, int(DECOR_TRIANGLES * SHADOW_SHARE), "投影的三角形不超过本区预算的六成")


# —— 工具 ——

static func _reserved_problem(v: Vector3) -> String:
	if absf(v.x) > ROOM_INNER + 0.001 or absf(v.z) > ROOM_INNER + 0.001 or v.y < -0.001 or v.y > Tavern.ROOM_HEIGHT:
		return "出了房间"
	if FIREPLACE.has_point(v):
		return "壁炉"
	if BAR.has_point(v):
		return "吧台"
	if WINDOW_FRONT.has_point(v):
		return "窗洞前"
	for s in SCONCES:
		if v.distance_to(s) < SCONCE_CLEARANCE:
			return "壁灯旁"
	if v.y > ABOVE_RUG and Vector2(v.x, v.z).length() < TABLE_CLEARING:
		return "牌桌四周的空地"
	var wall_distance := minf(ROOM_INNER - absf(v.x), ROOM_INNER - absf(v.z))
	if v.y > CAMERA_HEIGHT and wall_distance > WALL_REACH:
		return "相机路线"
	return ""


static func _decor_vertices() -> PackedVector3Array:
	var verts := PackedVector3Array()
	for mesh in [TavernDecor.props_mesh(), TavernDecor.detail_mesh()]:
		for i in (mesh as ArrayMesh).get_surface_count():
			verts.append_array((mesh as ArrayMesh).surface_get_arrays(i)[Mesh.ARRAY_VERTEX])
	return verts


static func _triangles(mesh: Mesh) -> int:
	var total := 0
	for i in mesh.get_surface_count():
		total += (mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	return total
