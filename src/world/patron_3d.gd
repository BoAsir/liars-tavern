class_name Patron
extends Node3D
# 酒客角色:坐在椅子上的卡通动物。原点在座位地面,面朝 -Z(牌桌中心)。
# 坐姿:身体前倾趴在牌桌上,双手搭在桌面——拿着牌也一样,牌扇自己立在胸前(爪子去扶牌会挡住牌面)。
# 待机:呼吸、眨眼、眼神与头部跟随;动作:出牌伸手、拍桌、举枪(坐直)、中弹倒下、庆祝(坐直)。


const ARM_LENGTH := 0.4
const SHOULDER := Vector3(0.21, 0.52, -0.02)
const PAW_RADIUS := 0.058
const PAW_SCALE := Vector3(1, 0.8, 1.1)
const HEAD_PIVOT := Vector3(0, 0.65, -0.02)
# 弹簧脖子:头按座位坐标的水平偏移伸出去,脖子从领口自动拉长连到头
const NECK_BASE := Vector3(0, 0.55, -0.02)
const NECK_REACH := 0.85      # 头最远水平伸出(米):4 人同时探向桌心头不相撞;头平着伸出去,高度不变
# 头只能往前、往两侧探,不往后(+Z,朝越肩镜头):往后会挡在镜头和自己的手牌之间
const NECK_MAX_BACK := 0.0
const NECK_STIFFNESS := 60.0  # 弹簧刚度与阻尼:临界阻尼(2√刚度),头跟手又停得稳,不过冲不回晃
const NECK_DAMPING := 15.5
const NECK_MIN_THICKNESS := 0.55   # 拉长时脖子变细,最细到原粗细的这个比例
const NECK_MAX_STEP := 1.0 / 60.0  # 弹簧积分的最大步长(秒):掉帧时分步积分,不会弹飞
const HIP := Vector3(0, 0.5, 0.12)
# 前倾角(弧度,绕髋部):坐着时趴向牌桌,单节手臂才够得着桌面;轮到自己时再多倾一点
const SEATED_LEAN := 0.18
const TURN_LEAN := 0.13
# 举枪、庆祝时坐直——仍留一点前倾,空着的那只手才搭得到桌面
const SITTING_UP_LEAN := 0.08
# 搭在桌上的手:掌心离身体中线的横向距离;拍桌落点更靠里
const PAW_SPREAD := 0.15
const SLAM_SPREAD := 0.08
# 出牌手势:双手抬离桌面、朝桌心前推(座位坐标)
const REACH_POINT := Vector3(0.06, SeatLayout.TABLE_TOP + 0.14, -0.75)
const HAND_RAISED := Vector3(0.24, 0.82, -0.32)
const HAND_GUN_HEAD := Vector3(0.355, 0.85, -0.05)   # 举枪手位:枪口抵在太阳穴外(枪口到头心 ≈ 0.18,头半径 0.17)
const GUN_DROP := Vector3(0.24, 0.0, -0.42)          # 中弹后枪落在面前的桌沿(座位坐标,高度另按毡面算)
const HAND_CHEER := Vector3(0.32, 1.0, -0.12)
const HAND_DEAD := Vector3(0.28, 0.0, 0.05)
# 他人的牌扇:在 CardTable.FAN_BASIS(竖立、牌面朝持牌者)基础上再上仰,牌面迎向持牌者的视线。
# FAN_POS 为座位坐标(相对髋部):前倾坐着时牌扇停在这里,轮到他再前倾时下沉也碰不到桌面
const FAN_TILT_DEG := -18.0
const FAN_POS := Vector3(0, 0.46, -0.37)
# 第三人称下自己的牌扇:举在右肩外侧、比头更靠近越肩镜头,头怎么探都只会在牌后面;牌面朝向镜头,
# 高度让牌扇停在回合横幅之上(座位坐标,相对髋部;越肩机位按它取景)
const SELF_FAN_POS := Vector3(0.48, 0.88, 0.16)
const SELF_FAN_SCALE := 1.25
# 庆祝:原地蹦几下,每次起跳/落下的时长(秒)与高度(米)
const CHEER_BOUNCES := 3
const CHEER_BOUNCE_TIME := 0.22
const CHEER_JUMP := 0.08
# 出局时打飞的帽子等散落物:挂到父节点(TableWorld)下并打上此标记,由 TableWorld 回收
const DEBRIS_GROUP := &"patron_debris"
const GREY := Color(0.42, 0.42, 0.42)   # 褪色的灰(patron.gdshader 里同值)
const FADE_TIME := 1.4
const DIE_BODY_ROT := Vector3(0.55, 0.15, -0.5)

var species_index := 0
var alive := true
var body: Node3D
var head: Node3D
var fan: Node3D
var right_hand: Node3D

var _arm_l: Node3D
var _arm_r: Node3D
var _eye: MeshInstance3D       # 两只眼一个网格,patron_eye.gdshader 画眼睑/虹膜/高光/×
var _look := Vector4.ZERO      # 左右瞳孔偏移(眼面坐标),写进眼睛的实例参数
var _paw_r: MeshInstance3D
var _fist: MeshInstance3D      # 握枪时右手换成拳头
var _legs: MeshInstance3D      # 腿、鞋、尾巴(座位坐标,跟着蹦跳)
var _look_data: Dictionary     # 物种外观(species/*.gd 的 LOOK)
var _neck_base := NECK_BASE
var _neck_reach := NECK_REACH
var _brow_y := 0.222
var _brows: Array = []
var _ears: Array = []
var _hat: Node3D
var _fade_targets: Array[GeometryInstance3D] = []   # 出局时褪色的部件(帽子打飞后仍在列表里)
var _look_target := Vector3.ZERO
var _has_look := false
var _time := 0.0
var _phase := 0.0
var _blink_in := 2.0
var _breath_rate := 1.0
var _lean := SEATED_LEAN
var _sitting_up := false   # 举枪、庆祝时坐直
var _arms_locked := false
var _resting := {}         # 手臂 → 是否搭在桌上:搭着的手每帧按身体姿态重新落点(单手动作时另一只手照样搭着)
var _arm_serial := 0       # 每次手臂补间加一;歇手补间结束时据此判断期间有没有新动作
var _cheer_tweens: Array[Tween] = []   # 庆祝中的蹦跳与举手,复位时中止
var _noise := FastNoiseLite.new()
var _neck: Node3D
var _neck_target := Vector3.ZERO     # 座位坐标的头部偏移目标
var _neck_offset := Vector3.ZERO     # 当前偏移(弹簧积分)
var _neck_velocity := Vector3.ZERO


func _init(p_species_index := 0) -> void:
	species_index = p_species_index
	_phase = species_index * 1.7
	_noise.seed = species_index * 31 + 7
	_build()


func _process(delta: float) -> void:
	_time += delta
	if alive:
		_animate_idle(delta)
	_update_neck(delta)


# —— 构建 ——

func _build() -> void:
	# 每个动画枢轴下的静态零件合成一份共享网格(按「物种:部件」缓存,所有酒客共用一份酒客材质);
	# 枢轴的名字、层级、变换都和合并前一样,动画代码不变。脖子根、眉、耳、帽的位置按物种外观
	var spec := PatronParts.species(species_index)
	_look_data = SpeciesLooks.look(species_index)
	_neck_base = _look_data["neck"].get("base", NECK_BASE)
	_neck_reach = minf(NECK_REACH, _look_data.get("anim", {}).get("neck_reach", NECK_REACH))
	MeshKit.add(self, PatronParts.chair_mesh(), null).name = "Chair"
	_legs = _add_part(self, PatronParts.part_mesh(spec, "legs"), "Legs")
	_legs.extra_cull_margin = 0.12   # 尾巴在顶点着色器里摆,会超出包围盒
	var tail: Dictionary = _look_data.get("tail", {})
	if not tail.is_empty():
		_legs.set_instance_shader_parameter("tail", Vector4(_phase, tail.get("sway", 0.12), 0.0, 0.0))
		_legs.set_instance_shader_parameter("tail_root", tail["path"][0])
	body = MeshKit.pivot(self, HIP, "Body")
	body.rotation.x = -SEATED_LEAN
	_add_part(body, PatronParts.part_mesh(spec, "body"), "BodyMesh")
	_neck = MeshKit.pivot(body, _neck_base, "Neck")
	_add_part(_neck, PatronParts.part_mesh(spec, "neck"), "NeckMesh")
	_build_head(spec)
	_fit_neck()
	_arm_l = _build_arm(-1.0, spec)
	_arm_r = _build_arm(1.0, spec)
	right_hand = _arm_r.get_node("Hand")
	fan = MeshKit.pivot(body, Vector3.ZERO, "Fan")
	fan.transform = _in_seat(Transform3D(CardTable.FAN_BASIS * Basis(Vector3.RIGHT, deg_to_rad(FAN_TILT_DEG)),
		HIP + FAN_POS))
	_resting = {_arm_l: true, _arm_r: true}
	_plant_paws()


func _build_head(spec: Dictionary) -> void:
	head = MeshKit.pivot(body, HEAD_PIVOT, "Head")
	_add_part(head, PatronParts.part_mesh(spec, "head"), "HeadMesh")
	_eye = _add_part(head, PatronParts.part_mesh(spec, "eyes"), "Eyes")
	_eye.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var eyes: Dictionary = _look_data["eyes"]
	var iris: Color = eyes.get("iris", Color(0.4, 0.28, 0.12))
	var lid_color: Color = PatronParts.palette(spec)["fur"]
	_eye.set_instance_shader_parameter("iris_color", Vector3(iris.r, iris.g, iris.b))
	_eye.set_instance_shader_parameter("lid_color", Vector3(lid_color.r, lid_color.g, lid_color.b))
	_eye.set_instance_shader_parameter("lid_rest", eyes.get("lid_rest", 0.12))
	_eye.set_instance_shader_parameter("pupil_shape", float(eyes.get("pupil", 0)))
	_eye.set_instance_shader_parameter("lashes", 1.0 if eyes.get("lashes", false) else 0.0)
	_eye.set_instance_shader_parameter("lid", 0.0)
	_eye.set_instance_shader_parameter("lid_tilt", 0.0)
	_eye.set_instance_shader_parameter("dead", 0.0)
	_eye.set_instance_shader_parameter("look", Vector4.ZERO)
	var brows: Dictionary = _look_data["brows"]
	var brow_pos: Vector3 = brows["pos"]
	_brow_y = brow_pos.y
	var brow_mesh := PatronParts.part_mesh(spec, "brow")
	for side in [-1.0, 1.0]:
		var brow := MeshKit.pivot(head, Vector3(brow_pos.x * side, brow_pos.y, brow_pos.z))
		_add_part(brow, brow_mesh, "BrowMesh")
		_brows.append(brow)
	var ears: Dictionary = _look_data.get("ears", {})
	if ears.get("kind", "none") != "none":
		var ear_mesh := PatronParts.part_mesh(spec, "ear")
		var pivot: Vector3 = ears["pivot"]
		var rot: Vector3 = ears.get("rot", Vector3.ZERO)
		for side in [-1.0, 1.0]:
			var ear := MeshKit.pivot(head)
			ear.transform = MeshForge.xf(Vector3(pivot.x * side, pivot.y, pivot.z), Vector3(rot.x, rot.y * side, rot.z * side))
			_add_part(ear, ear_mesh, "EarMesh")
			_ears.append(ear)
	var hat: Dictionary = _look_data.get("hat", {})
	_hat = MeshKit.pivot(head, Vector3.ZERO, "Hat")
	_hat.transform = MeshForge.xf(hat.get("pivot", Vector3(0, 0.255, 0.01)), hat.get("rot", Vector3(-6, 0, 9)))
	_add_part(_hat, PatronParts.part_mesh(spec, "hat"), "HatMesh")


func _build_arm(side: float, spec: Dictionary) -> Node3D:
	var pivot := MeshKit.pivot(body, _mirror(SHOULDER, side), "ArmR" if side > 0 else "ArmL")
	_add_part(pivot, PatronParts.part_mesh(spec, "arm"), "ArmMesh")
	var hand := MeshKit.pivot(pivot, Vector3(0, 0, -ARM_LENGTH), "Hand")
	var paw := _add_part(hand, PatronParts.part_mesh(spec, "paw_r" if side > 0 else "paw_l"), "PawMesh")
	if side > 0:
		_paw_r = paw
		_fist = _add_part(hand, PatronParts.part_mesh(spec, "fist"), "FistMesh")
		_fist.visible = false
	return pivot


func _set_fist(on: bool) -> void:
	# 握枪时右手换成拳头(枪挂在 Hand 上,张开的爪会把握把吞进掌心)
	if _fist == null:
		return
	_fist.visible = on
	_paw_r.visible = not on


func _add_part(parent: Node3D, mesh: ArrayMesh, node_name: String) -> MeshInstance3D:
	# 合并网格的材质挂在网格上(共享网格 + 共享材质才能自动实例化);出局褪色的目标收进 _fade_targets
	var inst := MeshKit.add(parent, mesh, null)
	inst.name = node_name
	_fade_targets.append(inst)
	return inst


# —— 待机 ——

func _animate_idle(delta: float) -> void:
	var breath := sin(_time * 1.6 * _breath_rate + _phase)
	body.scale = Vector3(1.0 - breath * 0.004, 1.0 + breath * 0.012, 1.0)
	var lean := SITTING_UP_LEAN if _sitting_up else _lean
	body.rotation.x = lerpf(body.rotation.x, -lean + breath * 0.01, minf(delta * 4.0, 1.0))
	_plant_paws()
	var yaw := 0.0
	var pitch := 0.0
	if _has_look:
		var local := body.to_local(_look_target) - head.position
		yaw = clampf(atan2(-local.x, -local.z), -0.7, 0.7)
		pitch = clampf(atan2(local.y, Vector2(local.x, local.z).length()), _look_data.get("anim", {}).get("look_pitch_min", -0.45), 0.35)
	yaw += _noise.get_noise_1d(_time * 0.4) * 0.08
	pitch += _noise.get_noise_1d(_time * 0.3 + 40.0) * 0.05
	head.rotation.y = lerpf(head.rotation.y, yaw, minf(delta * 3.0, 1.0))
	head.rotation.x = lerpf(head.rotation.x, pitch, minf(delta * 3.0, 1.0))
	head.rotation.z = _noise.get_noise_1d(_time * 0.25 + 90.0) * 0.06
	_update_look(delta)
	_legs.position.y = maxf(body.position.y - HIP.y, 0.0)   # 腿跟着蹦跳,下沉时不入地
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_in = randf_range(1.8, 5.5)
		_blink()


func _update_look(delta: float) -> void:
	# 瞳孔看向目标:按两只眼各自的位置算方向,换成眼面坐标的偏移;变化很小时不写实例参数
	var target := Vector4.ZERO
	if _has_look:
		var eye_pos: Vector3 = _look_data["eyes"]["pos"]
		var local := head.to_local(_look_target)
		for side in [-1.0, 1.0]:
			var dir := (local - Vector3(eye_pos.x * side, eye_pos.y, eye_pos.z)).normalized()
			var offset := Vector2(dir.x, dir.y) * 0.45
			if side < 0.0:
				target.x = offset.x
				target.y = offset.y
			else:
				target.z = offset.x
				target.w = offset.y
	var next := _look.lerp(target, minf(delta * 8.0, 1.0))
	if (next - _look).length() > 0.002:
		_look = next
		_eye.set_instance_shader_parameter("look", _look)


func _set_lid(value: float) -> void:
	_eye.set_instance_shader_parameter("lid", value)


func _blink() -> void:
	var speed: float = _look_data.get("anim", {}).get("blink_speed", 1.0)
	var tween := create_tween()
	tween.tween_method(_set_lid, 0.0, 1.0, 0.06 / speed)
	tween.tween_method(_set_lid, 1.0, 0.0, 0.08 / speed)
	if randf() < 0.4 and not _ears.is_empty():
		var ear: Node3D = _ears[randi() % _ears.size()]
		var base := ear.rotation.x
		var twitch := create_tween()
		twitch.tween_property(ear, "rotation:x", base - 0.3, 0.07)
		twitch.tween_property(ear, "rotation:x", base, 0.15)


# —— 弹簧脖子 ——

func set_neck_target(seat_offset: Vector3) -> void:
	# 长吻的物种(鳄鱼)伸得近一点:4 人同时探向桌心,吻尖也不互穿
	_neck_target = clamp_neck(seat_offset).limit_length(_neck_reach)


func neck_reach() -> float:
	return _neck_reach


static func clamp_neck(seat_offset: Vector3) -> Vector3:
	# 座位坐标的水平偏移(-Z 朝桌心):只取水平分量(头平着伸出去,高度不变),不往后,最远 NECK_REACH
	return Vector3(seat_offset.x, 0.0, minf(seat_offset.z, NECK_MAX_BACK)).limit_length(NECK_REACH)


func neck_offset() -> Vector3:
	return _neck_offset


func _update_neck(delta: float) -> void:
	var target := _neck_target if alive else Vector3.ZERO
	var left := delta
	while left > 0.0:
		var step := minf(left, NECK_MAX_STEP)
		var accel := (target - _neck_offset) * NECK_STIFFNESS - _neck_velocity * NECK_DAMPING
		_neck_velocity += accel * step
		_neck_offset += _neck_velocity * step
		left -= step
	# 偏移按座位坐标给出:换到(前倾、出局时歪倒的)身体局部坐标,头才是水平地探出去
	head.position = HEAD_PIVOT + body.quaternion.inverse() * _neck_offset
	_fit_neck()


func _fit_neck() -> void:
	var span := head.position - _neck_base
	var length := maxf(span.length(), 0.001)
	var thickness := clampf(sqrt((HEAD_PIVOT - _neck_base).length() / length), NECK_MIN_THICKNESS, 1.0)
	_neck.basis = Basis(Quaternion(Vector3.UP, span / length)) * Basis.from_scale(Vector3(thickness, length, thickness))


func look_at_point(point: Vector3) -> void:
	_look_target = point
	_has_look = true


func head_position() -> Vector3:
	return head.global_transform * Vector3(0, 0.12, 0)


func nameplate_anchor() -> Vector3:
	return global_transform * Vector3(0, 1.82, 0.1)


func set_active(active: bool) -> void:
	_lean = SEATED_LEAN + (TURN_LEAN if active else 0.0)
	_breath_rate = 1.8 if active else 1.0


func set_expression(kind: String) -> void:
	var angles := {"neutral": 0.0, "angry": -0.38, "worried": 0.4, "happy": 0.15, "smug": -0.15}
	var lift := 0.02 if kind in ["worried", "happy"] else 0.0
	var tween := create_tween().set_parallel()
	for i in _brows.size():
		var side := -1.0 if i == 0 else 1.0
		tween.tween_property(_brows[i], "rotation:z", angles.get(kind, 0.0) * -side, 0.18)
		tween.tween_property(_brows[i], "position:y", _brow_y + lift, 0.18)
	var tilts := {"angry": 0.25, "worried": -0.2}
	tween.tween_method(func(v: float): _eye.set_instance_shader_parameter("lid_tilt", v),
		float(_eye.get_instance_shader_parameter("lid_tilt")), tilts.get(kind, 0.0), 0.18)


# —— 手臂 ——

func rest_arms(animate := true) -> void:
	# 双手搭回桌上;动作进行中(动作锁)时不打断,动作结束后由动作自己调用。
	# 搭好之后每帧重新落点,呼吸、前倾都不会让手悬空或按进桌里
	if _arms_locked:
		return
	var tween := pose_arms(rest_target(-1.0), rest_target(1.0), 0.3 if animate else 0.0)
	var serial := _arm_serial
	tween.finished.connect(func():
		if serial == _arm_serial:
			_resting = {_arm_l: true, _arm_r: true})


func rest_target(side: float, spread := PAW_SPREAD) -> Vector3:
	# 手搭在桌上的落点(身体局部坐标):按当前肩位,手臂伸直一臂之长、掌底贴着桌面
	var shoulder := body.transform * _mirror(SHOULDER, side)
	var paw_y := SeatLayout.TABLE_TOP + PAW_RADIUS * PAW_SCALE.y
	var dy := paw_y - shoulder.y
	var reach := sqrt(maxf(ARM_LENGTH * ARM_LENGTH - dy * dy, 0.0))
	var dx := spread * side - shoulder.x
	var dz := -sqrt(maxf(reach * reach - dx * dx, 0.0))
	return _to_body(Vector3(shoulder.x + dx, paw_y, shoulder.z + dz))


func _plant_paws() -> void:
	if _resting.get(_arm_l, false):
		_set_arm(_arm_l, rest_target(-1.0))
	if _resting.get(_arm_r, false):
		_set_arm(_arm_r, rest_target(1.0))


func present_hand_to(viewer: Vector3) -> void:
	# 第三人称:把牌扇移到右胸前并放大,牌面法线指向镜头、牌顶朝上,越肩即可看清点数
	# 按座位的静止姿态计算(登场缩放动画期间 global 坐标不可靠),并抵消坐姿前倾
	var seat_basis := global_basis.orthonormalized()
	var fan_seat := HIP + SELF_FAN_POS
	var fan_world := global_position + seat_basis * fan_seat
	var normal := (viewer - fan_world).normalized()
	var bottom := -(Vector3.UP - normal * Vector3.UP.dot(normal)).normalized()
	var world_basis := Basis(normal.cross(bottom), normal, bottom)
	fan.transform = _in_seat(Transform3D((seat_basis.inverse() * world_basis).scaled(Vector3.ONE * SELF_FAN_SCALE), fan_seat))


func pose_arms(left_target: Vector3, right_target: Vector3, duration: float) -> Tween:
	var tween := create_tween().set_parallel()
	_tween_arm(tween, _arm_l, left_target, duration)
	_tween_arm(tween, _arm_r, right_target, duration)
	return tween


func pose_right(target: Vector3, duration: float, trans := Tween.TRANS_CUBIC) -> Tween:
	var tween := create_tween()
	_tween_arm(tween, _arm_r, target, duration, trans)
	return tween


func reach_toward_center() -> void:
	# 出牌手势:双手抬离桌面前推,再收回桌上
	if _arms_locked or not alive:
		return
	_arms_locked = true
	await pose_arms(_to_body(_mirror(REACH_POINT, -1.0)), _to_body(REACH_POINT), 0.22).finished
	await get_tree().create_timer(0.12).timeout
	_arms_locked = false
	rest_arms()


func slam_table() -> void:
	# 拍桌:抬手蓄力 → 砸下;在砸到桌面的瞬间返回,收手在后台进行
	if not alive:
		return
	_arms_locked = true
	set_expression("angry")
	await pose_right(HAND_RAISED, 0.2, Tween.TRANS_BACK).finished
	await pose_right(rest_target(1.0, SLAM_SPREAD), 0.08, Tween.TRANS_EXPO).finished
	_finish_slam()


func _finish_slam() -> void:
	await get_tree().create_timer(0.35).timeout
	_arms_locked = false
	rest_arms()


func pick_up(gun: Node3D, duration: float) -> void:
	# 伸手到桌上的左轮,握住后挂到右手上
	_arms_locked = true
	var gun_local := body.to_local(gun.global_position)
	await pose_right(gun_local + Vector3(0, 0.03, 0), duration).finished
	gun.reparent(right_hand, true)
	_set_fist(true)
	var tween := create_tween()
	tween.tween_property(gun, "transform", Transform3D(Basis(), Vector3(0, -0.01, -0.02)), 0.12)
	await tween.finished


func raise_gun_to_head(gun: Node3D, duration: float) -> void:
	_sitting_up = true
	var tween := pose_right(HAND_GUN_HEAD, duration, Tween.TRANS_BACK)
	await tween.finished
	# 枪口对准太阳穴
	var aim := Transform3D(Basis.looking_at(head_position() - gun.global_position, Vector3.UP), gun.global_position)
	var settle := create_tween()
	settle.tween_property(gun, "global_transform", aim, 0.18).set_trans(Tween.TRANS_SINE)
	set_expression("worried")
	await settle.finished


func lower_gun(gun: Node3D, rest: Transform3D, table_parent: Node3D, duration: float) -> void:
	_sitting_up = false
	set_expression("neutral")
	await pose_right(body.to_local(rest.origin) + Vector3(0, 0.03, 0), duration).finished
	gun.reparent(table_parent, true)
	_set_fist(false)
	var tween := create_tween()
	tween.tween_property(gun, "global_transform", rest, 0.15)
	await tween.finished
	_arms_locked = false
	rest_arms()


func relief() -> void:
	set_expression("happy")
	var tween := create_tween()
	tween.tween_property(body, "position:y", HIP.y - 0.03, 0.25).set_trans(Tween.TRANS_SINE)
	tween.tween_property(body, "position:y", HIP.y, 0.4).set_trans(Tween.TRANS_SINE)


# —— 出局 / 庆祝 / 进出场 ——

func die(gun: Node3D = null, table_parent: Node3D = null) -> void:
	alive = false
	_arms_locked = true
	_eye.set_instance_shader_parameter("dead", 1.0)
	_set_fist(false)
	if gun != null and table_parent != null:
		gun.reparent(table_parent, true)
		var drop := create_tween()
		var landing := global_transform * Vector3(GUN_DROP.x, SeatLayout.FELT_TOP + Revolver3D.REST_HALF_WIDTH, GUN_DROP.z)
		drop.tween_property(gun, "global_position", landing, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		drop.parallel().tween_property(gun, "rotation", Vector3(0, gun.rotation.y + 1.8, PI / 2.0), 0.45)
	var fall := create_tween().set_parallel()
	var body_rot: Vector3 = _look_data.get("anim", {}).get("die_body_rot", DIE_BODY_ROT)   # 乌龟侧倒,龟壳不穿椅背
	fall.tween_property(body, "rotation", body_rot, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fall.tween_property(head, "rotation", Vector3(-0.5, 0.3, -0.45), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_arm(fall, _arm_l, _mirror(HAND_DEAD, -1.0), 0.5, Tween.TRANS_BOUNCE)
	_tween_arm(fall, _arm_r, HAND_DEAD, 0.5, Tween.TRANS_BOUNCE)
	_knock_hat_off()
	fall.tween_method(_set_fade, 0.0, 1.0, FADE_TIME)
	if not _look_data.get("tail", {}).is_empty():
		fall.tween_method(func(v: float): _legs.set_instance_shader_parameter("tail",
			Vector4(_phase, _look_data["tail"].get("sway", 0.12), v, 0.0)), 0.0, 1.0, FADE_TIME)


func _set_fade(value: float) -> void:
	for target in _fade_targets:
		if is_instance_valid(target):
			target.set_instance_shader_parameter("fade", value)


func _knock_hat_off() -> void:
	if _hat == null:
		return
	var hat := _hat
	_hat = null
	var start := hat.global_position
	var landing := global_transform * Vector3(-0.35, 0.05, 0.45)
	# 重名的节点在 reparent 后会被改名,不能靠名字找回:打上散落物标记
	hat.add_to_group(DEBRIS_GROUP)
	hat.reparent(get_parent(), true)
	var tween := hat.create_tween()
	tween.tween_method(func(t: float):
		hat.global_position = start.lerp(landing, t) + Vector3.UP * sin(t * PI) * 0.45
		hat.rotation = Vector3(t * 4.0, t * 2.0, t * 1.4),
		0.0, 1.0, 0.8).set_ease(Tween.EASE_IN)


func celebrate() -> void:
	# 举起双手、原地蹦几下;蹦完解除动作锁(双手仍举着,直到下次持牌或 reset_pose)
	if not alive:
		return
	_arms_locked = true
	_sitting_up = true
	set_expression("happy")
	var bounce := create_tween().set_loops(CHEER_BOUNCES)
	bounce.tween_property(body, "position:y", HIP.y + CHEER_JUMP, CHEER_BOUNCE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bounce.tween_property(body, "position:y", HIP.y, CHEER_BOUNCE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_cheer_tweens = [bounce, pose_arms(_mirror(HAND_CHEER, -1.0), HAND_CHEER, 0.3)]
	await bounce.finished
	_arms_locked = false


func reset_pose() -> void:
	# 回到等待厅 / 新一局开始:停下庆祝,解除动作锁,恢复中性表情、前倾坐姿、双手搭回桌上
	for tween in _cheer_tweens:
		if tween.is_valid():
			tween.kill()
	_cheer_tweens = []
	_arms_locked = false
	_sitting_up = false
	_neck_target = Vector3.ZERO
	set_expression("neutral")
	_set_fist(false)
	body.position = HIP
	rest_arms(false)


func appear() -> void:
	scale = Vector3.ONE * 0.01
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Fx.smoke_puff(get_parent(), global_position + Vector3(0, 0.9, 0), 14, Color(0.9, 0.85, 0.78))


func vanish() -> void:
	Fx.smoke_puff(get_parent(), global_position + Vector3(0, 0.9, 0), 14, Color(0.9, 0.85, 0.78))
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)


# —— 工具 ——

func _set_arm(arm: Node3D, target: Vector3) -> void:
	arm.quaternion = _arm_quat(arm, target)


func _tween_arm(tween: Tween, arm: Node3D, target: Vector3, duration: float, trans := Tween.TRANS_CUBIC) -> void:
	_resting[arm] = false
	_arm_serial += 1
	tween.tween_property(arm, "quaternion", _arm_quat(arm, target), maxf(duration, 0.001)) \
		.set_trans(trans).set_ease(Tween.EASE_IN_OUT if trans != Tween.TRANS_BACK else Tween.EASE_OUT)


func _arm_quat(arm: Node3D, target: Vector3) -> Quaternion:
	var dir := target - arm.position
	var up := Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.95 else Vector3.BACK
	return Basis.looking_at(dir, up).get_rotation_quaternion()


func _to_body(seat_point: Vector3) -> Vector3:
	return body.transform.affine_inverse() * seat_point


static func _in_seat(seat_xform: Transform3D) -> Transform3D:
	# 座位坐标 → 前倾坐姿下的身体局部坐标:挂在身体上的东西坐着时停在座位里调好的位置
	return Transform3D(Basis(Vector3.RIGHT, -SEATED_LEAN), HIP).affine_inverse() * seat_xform


static func _mirror(v: Vector3, side: float) -> Vector3:
	return Vector3(v.x * side, v.y, v.z)
