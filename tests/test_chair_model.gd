extends GutTest
# 椅子:所有酒客共用同一个缓存网格(中途加入、复活不重新拼装),绘制调用与三角形数在预算内;
# 外形不越出约定的范围——酒客坐在上面、尾巴绕着它走,椅背不往前顶到酒客的后背。


const MAX_SURFACES := 3
const MAX_TRIANGLES := 3000
const SEAT_TOP := 0.475
const SEAT_TOLERANCE := 0.012
const ENVELOPE_X := 0.24
const ENVELOPE_Z := Vector2(-0.08, 0.38)
const BACK_FROM_Z := 0.3          # 座面以上的椅背部件都在这条线之后
const TOP_HEIGHT := 1.1


func test_every_patron_shares_one_chair_mesh():
	var a := Patron.new(0)
	var b := Patron.new(2)
	add_child_autofree(a)
	add_child_autofree(b)
	var chair_a := _chair(a)
	var chair_b := _chair(b)
	assert_not_null(chair_a, "酒客坐在椅子上")
	assert_same(chair_a.mesh, chair_b.mesh, "不同物种的酒客也共用同一个椅子网格")
	assert_same(chair_a.mesh, ChairModel.mesh(), "椅子网格取自缓存")


func test_chair_stays_within_its_draw_budget():
	var mesh := ChairModel.mesh()
	assert_lte(mesh.get_surface_count(), MAX_SURFACES, "椅子的表面数(绘制调用)")
	var triangles := 0
	for i in mesh.get_surface_count():
		triangles += (mesh.surface_get_arrays(i)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	assert_lte(triangles, MAX_TRIANGLES, "椅子的三角形数")


func test_chair_keeps_its_envelope():
	var box := ChairModel.mesh().get_aabb()
	assert_gte(box.position.x, -ENVELOPE_X - 0.001, "左右不超出")
	assert_lte(box.end.x, ENVELOPE_X + 0.001)
	assert_gte(box.position.z, ENVELOPE_Z.x - 0.001, "前后不超出")
	assert_lte(box.end.z, ENVELOPE_Z.y + 0.001)
	assert_lte(box.end.y, TOP_HEIGHT, "椅背不高过 1.1 米")
	assert_almost_eq(box.position.y, 0.0, 0.001, "椅腿着地")


func test_seat_is_at_sitting_height():
	# 座面中间一圈(坐窝以外)的最高点就是座面高度
	var highest := -INF
	for v in _verts():
		if absf(v.x) < 0.2 and v.z > -0.05 and v.z < 0.28 and v.y < 0.6:
			highest = maxf(highest, v.y)
	assert_almost_eq(highest, SEAT_TOP, SEAT_TOLERANCE, "座面高度")


func test_back_stays_behind_the_sitter():
	var front_most := INF
	for v in _verts():
		if v.y > SEAT_TOP + 0.03:
			front_most = minf(front_most, v.z)
	assert_gte(front_most, BACK_FROM_Z - 0.001, "座面以上的部件都在椅背线之后,不顶到酒客的后背")


# —— 工具 ——

func _chair(patron: Patron) -> MeshInstance3D:
	return patron.find_child("Chair", true, false) as MeshInstance3D


func _verts() -> PackedVector3Array:
	var mesh := ChairModel.mesh()
	var out := PackedVector3Array()
	for i in mesh.get_surface_count():
		out.append_array(mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX])
	return out
