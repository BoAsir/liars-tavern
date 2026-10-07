extends GutTest
# 弹簧脖子:头按座位坐标的水平偏移伸出去(越远越往上探),脖子自动拉长连着头;
# 松开后弹回原位(带一点回弹);伸出距离有上限;出局时缩回。


const SETTLE := 1.5      # 秒:登场缩放与弹簧都稳定下来
const EPS := 0.03        # 米

var world: TableWorld
var patron: Patron


func before_each():
	world = TableWorld.new(null)
	add_child_autofree(world)
	world.arrange([{"pid": 1}, {"pid": 2}], 1, true, false)
	patron = world.patrons[2]


func _seat_head() -> Vector3:
	return patron.transform.affine_inverse() * patron.head_position()


func _neck_top() -> Vector3:
	# 脖子网格顶端(座位坐标):单位高的圆柱沿脖子节点的 Y 轴拉长
	var neck: Node3D = patron.body.get_node("Neck")
	return patron.transform.affine_inverse() * (neck.global_transform * Vector3.UP)


func _head_pivot() -> Vector3:
	return patron.transform.affine_inverse() * patron.head.global_position


func test_head_moves_forward_and_rises_when_neck_stretches():
	await wait_seconds(SETTLE)
	var rest := _seat_head()
	patron.set_neck_target(Vector3(0, 0, -0.4))
	await wait_seconds(SETTLE)
	var moved := _seat_head() - rest
	assert_almost_eq(moved.z, -0.4, EPS, "往前(朝桌心)伸出 0.4 米")
	assert_almost_eq(moved.y, 0.4 * Patron.NECK_RISE, EPS, "伸得越远头抬得越高")
	assert_almost_eq(moved.x, 0.0, EPS)


func test_neck_mesh_reaches_the_head():
	patron.set_neck_target(Vector3(0.3, 0, -0.3))
	await wait_seconds(SETTLE)
	assert_lt(_neck_top().distance_to(_head_pivot()), 0.005, "脖子顶端始终连着头")


func test_reach_is_limited():
	patron.set_neck_target(Vector3(0, 0, -5.0))
	await wait_seconds(SETTLE)
	var flat := Vector2(patron.neck_offset().x, patron.neck_offset().z)
	assert_almost_eq(flat.length(), Patron.NECK_REACH, EPS)


func test_springs_back_with_overshoot_when_released():
	patron.set_neck_target(Vector3(0, 0, -0.5))
	await wait_seconds(SETTLE)
	patron.set_neck_target(Vector3.ZERO)
	var max_overshoot := 0.0
	for i in 40:
		await wait_frames(1)
		max_overshoot = maxf(max_overshoot, patron.neck_offset().z)
	await wait_seconds(SETTLE)
	assert_gt(max_overshoot, 0.005, "弹回时冲过原位一点(像弹簧)")
	assert_lt(patron.neck_offset().length(), 0.01, "最终回到原位")


func test_neck_retracts_on_death():
	patron.set_neck_target(Vector3(-0.4, 0, 0))
	await wait_seconds(SETTLE)
	patron.die()
	await wait_seconds(SETTLE)
	assert_lt(patron.neck_offset().length(), 0.01)
