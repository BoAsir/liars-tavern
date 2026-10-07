class_name SeatGaze
extends Node
# 视线与探头(从 TableScreen 抽出,骗子酒馆与德州的牌桌共用):
# 自己的角色转头看光标所指之处、按住 WASD 把头探出去,落点与脖子偏移同步给其他人;
# 其他人的角色照他们发来的视线转头、伸脖子,停发或超时后看回牌桌给的落点。
# 牌桌各自的状态(镜头在不在常驻机位、谁出局或观战)经下面几个回调告诉它;收发节流与超时在 GazeSync。


const CURSOR_LOOK_FAR := 4.0    # 光标指向桌面以上时,取射线上这么远的一点作为视线目标(米)
const NECK_SPEED := 0.9         # 按住 WASD 时头部移动的速度(米/秒);松开就停在原处
# WASD → 座位坐标的方向(-Z 朝桌心,+X 是越肩镜头里的右边);按物理键位,换键盘布局也在同一位置
const NECK_KEYS := {KEY_W: Vector3(0, 0, -1), KEY_S: Vector3(0, 0, 1), KEY_A: Vector3(-1, 0, 0), KEY_D: Vector3(1, 0, 0)}

var app: Node
var world: TableWorld
var my_pid := 0
# 牌桌提供的判断(默认值只为单独使用时能跑)
var gaze_free := func() -> bool: return true              # 镜头停在常驻机位(越肩或观战俯视)且没在结算:视线归各玩家自己,否则交还演出
var at_seat := func() -> bool: return true                # 镜头在自己座位的越肩机位:只有这时自己的头才跟光标、读 WASD
var excluded := func(_pid: int) -> bool: return false     # 出局/观战的人:不跟随视线;是自己时探头归零
var rest_point := func() -> Vector3: return Vector3.ZERO  # 他人停发视线后看回哪里

var _gaze := GazeSync.new()
var _neck_input := Vector3.ZERO   # WASD 移到的头部偏移(座位坐标);拍特写时保留,回到座位后头再探回去


func _init(p_app: Node, p_world: TableWorld, p_my_pid: int) -> void:
	app = p_app
	world = p_world
	my_pid = p_my_pid


func _ready() -> void:
	Net.gaze_updated.connect(receive)


func _process(delta: float) -> void:
	_follow_cursor_with_head(delta)
	_follow_remote_gazes(delta)


func receive(pid: int, point: Vector3, neck: Vector3, active: bool) -> void:
	# 他人的视线(他自己座位坐标系里的落点与脖子偏移):只收桌上有酒客的其他人,网络来的数据先校验
	if pid != my_pid and world.patrons.has(pid) and GazeSync.is_valid(point, neck):
		_gaze.receive(pid, point, neck, active)


func forget(pid: int) -> void:
	# 不再跟随此人(如出局):只清视线记录、不碰场景,不在树内时也安全
	_gaze.forget(pid)


func neck_input() -> Vector3:
	return _neck_input


# —— 自己:光标与探头 ——

func _follow_cursor_with_head(delta: float) -> void:
	# 自己的角色转头、转眼看向光标所指之处,按住 WASD 伸长脖子把头探出去;
	# 落点(换算到自己座位坐标系)与脖子偏移同步给其他人
	var me: Patron = world.patrons.get(my_pid)
	var active: bool = gaze_free.call() and at_seat.call() and not excluded.call(my_pid) and me != null
	var target := Vector3.ZERO
	if excluded.call(my_pid):
		_neck_input = Vector3.ZERO
	elif active:
		_neck_input = next_neck_input(_neck_input, _held_neck_direction(), delta)
	if active:
		var ray := _cursor_ray()
		target = cursor_look_target(ray["origin"], ray["direction"], world.table_radius)
		me.look_at_point(target)
		target = GazeSync.to_seat_local(_seat_of(my_pid), target)
	if me != null:
		# 拍特写时先缩回脖子(别闯进镜头),回到座位后再伸到原来的位置
		me.set_neck_target(_neck_input if active else Vector3.ZERO)
	var out := _gaze.outgoing(delta, target, _neck_input, active)
	if not out.is_empty():
		Net.send_gaze(out["point"], out["neck"], out["active"])


func _cursor_ray() -> Dictionary:
	# 光标在当前镜头里的射线 {"origin", "direction"}
	var camera: Camera3D = app.tavern.camera_rig.camera
	var mouse := get_viewport().get_mouse_position()
	return {"origin": camera.project_ray_origin(mouse), "direction": camera.project_ray_normal(mouse)}


func _held_neck_direction() -> Vector3:
	# 说明书、确认框打开时不读;输入框有焦点时(如聊天)也不读
	if app.is_modal_open() or get_viewport().gui_get_focus_owner() is LineEdit:
		return Vector3.ZERO
	var dir := Vector3.ZERO
	for key in NECK_KEYS:
		if Input.is_physical_key_pressed(key):
			dir += NECK_KEYS[key]
	return dir


static func next_neck_input(current: Vector3, held: Vector3, delta: float) -> Vector3:
	# 按住方向键时头朝那个方向持续移动(斜向不更快),最远到 NECK_REACH;松开就停在原处,按反方向收回
	if held == Vector3.ZERO:
		return current
	return (current + held.normalized() * NECK_SPEED * delta).limit_length(Patron.NECK_REACH)


static func cursor_look_target(origin: Vector3, direction: Vector3, table_radius := SeatLayout.TABLE_RADIUS) -> Vector3:
	# 光标射线落在桌面上就看桌面上那一点(低头看牌、看出牌区);
	# 指向桌面以上或桌外(对手、墙、天花板)时取射线上远处一点。桌面半径随玩法:德州桌更大
	var dir := direction.normalized()
	if dir.y < -0.01:
		var t := (SeatLayout.TABLE_TOP - origin.y) / dir.y
		if t > 0.0 and t < CURSOR_LOOK_FAR:
			var hit := origin + dir * t
			if Vector2(hit.x, hit.z).length() <= table_radius:
				return hit
	return origin + dir * CURSOR_LOOK_FAR


# —— 他人:跟随发来的视线 ——

func _follow_remote_gazes(delta: float) -> void:
	# 其他玩家的角色看向他们各自光标所指之处、伸出脖子;对方停发或超时后缩回脖子看回牌桌给的落点,等下一段演出接管
	var released := _gaze.tick(delta)
	if not gaze_free.call():
		# 拍特写时所有人的脖子都缩回来,别让伸长的脖子闯进镜头
		for pid in world.patrons:
			if pid != my_pid:
				world.patrons[pid].set_neck_target(Vector3.ZERO)
		return
	for pid in released:
		if world.patrons.has(pid) and not excluded.call(pid):
			world.patrons[pid].look_at_point(rest_point.call())
			world.patrons[pid].set_neck_target(Vector3.ZERO)
	var targets := _gaze.live_targets()
	for pid in targets:
		if world.patrons.has(pid) and not excluded.call(pid):
			var patron: Patron = world.patrons[pid]
			patron.look_at_point(GazeSync.from_seat_local(_seat_of(pid), targets[pid]["point"]))
			patron.set_neck_target(targets[pid]["neck"])


func _seat_of(pid: int) -> Transform3D:
	return world.seat_transform(world.seat_angles.get(pid, 0.0))
