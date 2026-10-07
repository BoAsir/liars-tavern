extends GutTest
# SeatGaze:骗子酒馆与德州牌桌共用的视线与探头。
# 光标落点按当前桌面半径判断是不是看桌面;按住方向键探头有上限,松开停在原处,拍特写时缩回、回座位再探回;
# 他人的视线只套在桌上有酒客、没被排除(出局/观战)的人身上,停发后看回牌桌给的落点;不在树内时 forget 也安全。


# 越肩机位(规格 §5.5):骗子酒馆桌与德州桌
const LIARS_CAMERA := Vector3(0.55, 1.92, 2.1)
const POKER_CAMERA := Vector3(0.55, 1.92, 2.60)
const BIG_TABLE_SPOT := Vector3(1.2, SeatLayout.TABLE_TOP, 0.3)   # 德州桌面上、骗子酒馆桌外的一点
const FRAME := 0.1
const ME := 1
const NEAR := 0.001


class ScriptedGaze:
	extends SeatGaze
	# 按键与光标由测试给定:不读键盘,也不碰镜头与视口,所以不入树也能逐帧推进
	var held := Vector3.ZERO
	var ray := {"origin": Vector3.ZERO, "direction": Vector3.FORWARD}

	func _held_neck_direction() -> Vector3:
		return held

	func _cursor_ray() -> Dictionary:
		return ray


class FakePatron:
	extends Patron
	# 只记下被要求看向哪里、脖子伸到哪里,不依赖 Patron 内部的眼睛与弹簧
	var asked_look = null   # 字段名刻意不与 Patron 自己的成员重名(模型重做分支可能新增 neck 之类)
	var asked_neck = null

	func look_at_point(point: Vector3) -> void:
		asked_look = point

	func set_neck_target(seat_offset: Vector3) -> void:
		asked_neck = seat_offset


var world: TableWorld
var gaze: ScriptedGaze
var dead := {}
var free_gaze := true
var seated := true
var stand := Vector3(0, 0.9, 0)


func before_each():
	dead = {}
	free_gaze = true
	seated = true
	world = autofree(TableWorld.new(null))
	for pid in [1, 2, 3]:
		_seat(pid)
	gaze = autofree(ScriptedGaze.new(null, world, ME))
	gaze.gaze_free = func() -> bool: return free_gaze
	gaze.at_seat = func() -> bool: return seated
	gaze.excluded = func(pid: int) -> bool: return dead.has(pid)
	gaze.rest_point = func() -> Vector3: return stand


func _seat(pid: int) -> void:
	world.patrons[pid] = autofree(FakePatron.new(pid - 1))
	world.seat_angles[pid] = SeatLayout.seat_angle(pid - 1, 0, 3)


func _patron(pid: int) -> FakePatron:
	return world.patrons[pid]


func _frames(count: int) -> void:
	for i in count:
		gaze._process(FRAME)


func _aim(origin: Vector3, at: Vector3) -> void:
	gaze.ray = {"origin": origin, "direction": at - origin}


# —— 光标落点:按桌面半径判断 ——

func test_spot_on_the_big_table_is_tabletop_only_with_its_radius():
	var dir := BIG_TABLE_SPOT - POKER_CAMERA
	var on_poker: Vector3 = SeatGaze.cursor_look_target(POKER_CAMERA, dir, SeatLayout.POKER_TABLE_RADIUS)
	assert_lt(on_poker.distance_to(BIG_TABLE_SPOT), NEAR, "德州桌:看桌面上那一点")
	var on_liars: Vector3 = SeatGaze.cursor_look_target(POKER_CAMERA, dir)
	assert_almost_eq(on_liars.distance_to(POKER_CAMERA), SeatGaze.CURSOR_LOOK_FAR, NEAR,
		"默认是骗子酒馆的桌子:那儿已在桌外,看射线上远处")


func test_spot_on_the_small_table_is_tabletop_with_either_radius():
	var spot := Vector3(0.2, SeatLayout.TABLE_TOP, -0.3)
	for radius in [SeatLayout.TABLE_RADIUS, SeatLayout.POKER_TABLE_RADIUS]:
		var target: Vector3 = SeatGaze.cursor_look_target(LIARS_CAMERA, spot - LIARS_CAMERA, radius)
		assert_lt(target.distance_to(spot), NEAR, "半径 %.2f" % radius)


func test_floor_beyond_either_table_looks_far_along_the_ray():
	var floor_spot := Vector3(1.9, SeatLayout.TABLE_TOP, 0.6)
	for radius in [SeatLayout.TABLE_RADIUS, SeatLayout.POKER_TABLE_RADIUS]:
		var target: Vector3 = SeatGaze.cursor_look_target(POKER_CAMERA, floor_spot - POKER_CAMERA, radius)
		assert_almost_eq(target.distance_to(POKER_CAMERA), SeatGaze.CURSOR_LOOK_FAR, NEAR, "半径 %.2f" % radius)


func test_own_head_looks_at_the_cursor_on_the_current_table():
	_aim(POKER_CAMERA, BIG_TABLE_SPOT)
	world.table_radius = SeatLayout.POKER_TABLE_RADIUS
	_frames(1)
	assert_lt(_patron(ME).asked_look.distance_to(BIG_TABLE_SPOT), NEAR, "德州桌:低头看桌面上那一点")
	world.table_radius = SeatLayout.TABLE_RADIUS
	_frames(1)
	assert_almost_eq(_patron(ME).asked_look.distance_to(POKER_CAMERA), SeatGaze.CURSOR_LOOK_FAR, NEAR,
		"换回骗子酒馆的桌子:同一点在桌外")


# —— 自己探头 ——

func test_held_key_stretches_the_neck_up_to_the_reach():
	gaze.held = Vector3(0, 0, -1)
	_frames(1)
	assert_almost_eq(gaze.neck_input().z, -SeatGaze.NECK_SPEED * FRAME, 0.0001, "按住 W 朝桌心探出")
	_frames(30)
	assert_almost_eq(gaze.neck_input().length(), Patron.NECK_REACH, 0.0001, "探到上限为止")
	assert_eq(_patron(ME).asked_neck, gaze.neck_input(), "自己的头跟着探出去")


func test_neck_stays_out_while_the_camera_is_away_and_comes_back():
	# 拍特写时缩回脖子(别闯进镜头),但记着探到哪里;回到座位后头再探回去
	gaze.held = Vector3(-1, 0, 0)
	_frames(3)
	var reached := gaze.neck_input()
	gaze.held = Vector3.ZERO
	free_gaze = false
	_frames(5)
	assert_eq(_patron(ME).asked_neck, Vector3.ZERO, "特写时缩回")
	assert_eq(gaze.neck_input(), reached, "松开就停在原处,特写期间也记着")
	free_gaze = true
	_frames(1)
	assert_eq(_patron(ME).asked_neck, reached, "回到座位探回原处")


func test_neck_is_kept_but_not_used_away_from_the_seat_camera():
	# 观战俯视等不在越肩机位时:不跟光标、不探头,按键也不读
	gaze.held = Vector3(0, 0, -1)
	_frames(2)
	var reached := gaze.neck_input()
	seated = false
	_frames(3)
	assert_eq(gaze.neck_input(), reached, "离开越肩机位时按着键也不再探")
	assert_eq(_patron(ME).asked_neck, Vector3.ZERO)


func test_excluded_self_drops_the_neck():
	gaze.held = Vector3(0, 0, -1)
	_frames(3)
	dead[ME] = true
	_frames(1)
	assert_eq(gaze.neck_input(), Vector3.ZERO, "出局(或观战)后探头归零")
	assert_eq(_patron(ME).asked_neck, Vector3.ZERO)


# —— 他人的视线 ——

func test_others_follow_their_gaze_from_their_own_seat():
	# 对方发来的落点在他自己的座位坐标系里,套到本机画面里他的座位上
	var local := Vector3(0.1, 0.0, -1.0)
	gaze.receive(2, local, Vector3(0, 0, -0.3), true)
	_frames(1)
	var expected := world.seat_transform(world.seat_angles[2]) * local
	assert_lt(_patron(2).asked_look.distance_to(expected), 0.0001)
	assert_eq(_patron(2).asked_neck, Vector3(0, 0, -0.3))


func test_excluded_players_do_not_follow():
	dead[3] = true
	gaze.receive(2, Vector3(0, 0, -1), Vector3(0, 0, -0.3), true)
	gaze.receive(3, Vector3(0, 0, -1), Vector3(0, 0, -0.3), true)
	_frames(1)
	assert_not_null(_patron(2).asked_look, "没被排除的人照常跟随")
	assert_null(_patron(3).asked_look, "出局/观战的人不跟随")
	assert_null(_patron(3).asked_neck)
	gaze.receive(3, Vector3(0, 0, -1), Vector3.ZERO, false)
	_frames(1)
	assert_null(_patron(3).asked_look, "停发时也不去扭他的头")


func test_released_gaze_turns_back_to_the_rest_point():
	gaze.receive(2, Vector3(0, 0, -1), Vector3(0, 0, -0.3), true)
	_frames(1)
	gaze.receive(2, Vector3(0, 0, -1), Vector3.ZERO, false)
	_frames(1)
	assert_eq(_patron(2).asked_look, stand, "停发后看回牌桌给的落点")
	assert_eq(_patron(2).asked_neck, Vector3.ZERO, "并缩回脖子")


func test_silent_gaze_times_out_to_the_rest_point():
	gaze.receive(2, Vector3(0, 0, -1), Vector3(0, 0, -0.3), true)
	_frames(ceili(GazeSync.STALE / FRAME) + 1)
	assert_eq(_patron(2).asked_look, stand, "收不到心跳就交还")
	assert_eq(_patron(2).asked_neck, Vector3.ZERO)


func test_close_up_pulls_everyone_elses_neck_back():
	gaze.receive(2, Vector3(0, 0, -1), Vector3(0, 0, -0.3), true)
	free_gaze = false
	_frames(1)
	assert_eq(_patron(2).asked_neck, Vector3.ZERO, "特写时他人的脖子也缩回")
	assert_eq(_patron(3).asked_neck, Vector3.ZERO)
	assert_null(_patron(2).asked_look, "视线交还给演出,不跟随")


func test_ignores_own_invalid_and_patronless_gazes():
	seated = false   # 自己的头不跟光标:看得出远端视线有没有套到自己身上
	gaze.receive(ME, Vector3(0, 0, -1), Vector3.ZERO, true)
	gaze.receive(2, Vector3(NAN, 0, 0), Vector3.ZERO, true)
	gaze.receive(3, Vector3.ZERO, Vector3(0, 0, -GazeSync.MAX_NECK - 0.1), true)
	gaze.receive(9, Vector3(0, 0, -1), Vector3.ZERO, true)   # 桌上还没有他的酒客
	_seat(9)
	_frames(1)
	assert_null(_patron(ME).asked_look, "自己的视线不经网络回来")
	assert_null(_patron(2).asked_look, "非法落点丢弃")
	assert_null(_patron(3).asked_look, "非法脖子偏移丢弃")
	assert_null(_patron(9).asked_look, "没有酒客时收到的视线不留到他登场")


# —— 生命周期 ——

func test_forget_is_safe_out_of_the_tree():
	assert_false(gaze.is_inside_tree())
	gaze.receive(2, Vector3(0, 0, -1), Vector3(0, 0, -0.3), true)
	gaze.forget(2)
	gaze.forget(42)
	_frames(1)
	assert_null(_patron(2).asked_look, "忘掉的人不再跟随")
	assert_null(_patron(2).asked_neck, "也不当成停发去扭他的头")


func test_listens_to_net_gaze_once_in_the_tree():
	Net.gaze_updated.emit(2, Vector3(0, 0, -1), Vector3(0, 0, -0.3), true)
	_frames(1)
	assert_null(_patron(2).asked_look, "入树前不收")
	add_child(gaze)
	gaze.set_process(false)   # 入树时会自动打开逐帧处理:关掉,仍由测试推进
	Net.gaze_updated.emit(2, Vector3(0, 0, -1), Vector3(0, 0, -0.3), true)
	_frames(1)
	assert_not_null(_patron(2).asked_look, "入树后经 Net 收到他人视线")
