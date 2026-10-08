extends GutTest
# 角色层:物种按玩家稳定分配、复活时复位幸存者的姿势、清理出局时打飞的帽子。


const FAST_CLOCK := 8.0   # 庆祝动画以秒计:加速时钟,测试不必真等
const CLOCK_SLACK := 0.4  # 游戏秒:物理帧计时与补间的处理帧之间至多差一个(加速后的)物理帧

var world: TableWorld


func before_each():
	world = TableWorld.new(null)
	add_child_autofree(world)


func after_each():
	Engine.time_scale = 1.0


func _arrange(pids: Array) -> void:
	world.arrange(pids.map(func(pid): return {"pid": pid}), pids[0], true, false)


func _species() -> Dictionary:
	var result := {}
	for pid in world.patrons:
		result[pid] = world.patrons[pid].species_index
	return result


func _debris() -> Array:
	return world.get_children().filter(func(node: Node) -> bool:
		return node.is_in_group(Patron.DEBRIS_GROUP) and not node.is_queued_for_deletion())


func _right_arm_points_at(patron: Patron, target: Vector3) -> bool:
	# 手臂从肩膀指向目标点(手在臂长末端),比较方向即可判断姿势
	var hand := patron.body.to_local(patron.right_hand.global_position) - Patron.SHOULDER
	return hand.normalized().distance_to((target - Patron.SHOULDER).normalized()) < 0.01


# —— 物种 ——

func test_new_patrons_take_distinct_species_in_seat_order():
	_arrange([1, 2, 3])
	assert_eq(_species(), {1: 0, 2: 1, 3: 2})


func test_newcomer_takes_the_species_a_leaver_freed_and_others_keep_theirs():
	_arrange([1, 2, 3])
	_arrange([1, 3])
	_arrange([1, 3, 4])
	assert_eq(_species(), {1: 0, 3: 2, 4: 1})


func test_revived_patron_keeps_its_species():
	_arrange([1, 2, 3])
	var old: Patron = world.patrons[2]
	old.die()
	world.revive_all()
	assert_ne(world.patrons[2], old, "倒下的酒客换成新实例")
	assert_true(world.patrons[2].alive)
	assert_eq(_species(), {1: 0, 2: 1, 3: 2})


func test_species_of_matches_the_patron_model():
	_arrange([1, 2, 3])
	_arrange([1, 3])
	assert_eq(world.species_of(3), PatronParts.species(2))
	assert_eq(world.species_of(99), {}, "没有角色的玩家")


# —— 复活时复位幸存者 ——

func test_revive_all_releases_the_winners_cheer_pose():
	_arrange([1, 2])
	var winner: Patron = world.patrons[1]
	winner.celebrate()
	world.revive_all()
	assert_eq(world.patrons[1], winner, "幸存者沿用原实例")
	winner.rest_arms(false)
	await wait_process_frames(3)
	assert_true(_right_arm_points_at(winner, winner.rest_target(1.0)), "复位后双手能搭回桌上")
	assert_almost_eq(winner.body.position.y, Patron.HIP.y, 0.0001, "庆祝的蹦跳已停止")


func test_celebrate_unlocks_the_arms_once_its_bounces_end():
	_arrange([1, 2])
	var winner: Patron = world.patrons[1]
	Engine.time_scale = FAST_CLOCK
	winner.celebrate()
	await wait_seconds(Patron.CHEER_BOUNCES * Patron.CHEER_BOUNCE_TIME * 2.0 + CLOCK_SLACK)
	assert_true(_right_arm_points_at(winner, Patron.HAND_CHEER), "跳完后双手仍举着")
	winner.rest_arms(false)
	await wait_process_frames(3)
	assert_true(_right_arm_points_at(winner, winner.rest_target(1.0)), "动作锁已解除")


# —— 散落物 ——

func test_revive_all_removes_every_knocked_off_hat():
	_arrange([1, 2, 3, 4])
	for pid in [2, 3, 4]:
		world.patrons[pid].die()
	assert_eq(_debris().size(), 3, "三顶帽子都落到了桌边")
	world.revive_all()
	assert_eq(_debris().size(), 0)


func test_clear_removes_knocked_off_hats():
	_arrange([1, 2])
	world.patrons[2].die()
	world.clear()
	assert_eq(_debris().size(), 0)


# —— 主菜单空椅子 ——

func _empty_chairs() -> Array:
	return world.get_children().filter(func(n: Node) -> bool: return String(n.name).begins_with("EmptyChair"))


func test_cleared_table_shows_four_shared_empty_chairs():
	world.clear()
	var chairs := _empty_chairs()
	assert_eq(chairs.size(), 4)
	for chair: MeshInstance3D in chairs:
		assert_true(chair.visible)
		assert_same(chair.mesh, chairs[0].mesh, "共用一份椅子网格(自动实例化)")


func test_arranging_players_hides_the_empty_chairs():
	_arrange([1, 2])
	for chair: MeshInstance3D in _empty_chairs():
		assert_false(chair.visible, "有真人酒客时空椅子收起(酒客自带椅子)")
	world.clear()
	for chair: MeshInstance3D in _empty_chairs():
		assert_true(chair.visible)
