class_name Patron
extends Node3D
# 酒客角色:坐在椅子上的卡通动物。原点在座位地面,面朝 -Z(牌桌中心)。
# 坐姿:身体前倾趴在牌桌上,双手搭在桌面——拿着牌也一样,牌扇自己立在胸前(爪子去扶牌会挡住牌面)。
# 待机:呼吸、眨眼、眼神与头部跟随;动作:出牌伸手、拍桌、举枪(坐直)、中弹倒下、庆祝(坐直)。


const ARM_LENGTH := 0.45   # 动森式大头离肩更远:举枪时手要离头心 ≈0.64 m 才能把枪口抵在太阳穴(Q 版 0.4)
const SHOULDER := Vector3(0.21, 0.38, -0.02)   # 动森式:躯干压扁加宽后肩更低,肩宽不变(举枪够得着大头;Q 版 0.205, 0.485;最初 0.21, 0.52)
const PAW_RADIUS := 0.058
const PAW_SCALE := Vector3(1, 0.8, 1.1)
const HEAD_PIVOT := Vector3(0, 0.62, -0.02)   # 动森式:下巴压在领口上,看不见脖子(Q 版 0.615;最初 0.65)
# 弹簧脖子:头按座位坐标的水平偏移伸出去,脖子从领口自动拉长连到头
const NECK_BASE := Vector3(0, 0.55, -0.02)   # 物种 LOOK 按压扁前写,构建时乘 PatronParts.BODY_SQUASH
const NECK_REACH := 0.85      # 头最远水平伸出(米):4 人同时探向桌心头不相撞;头平着伸出去,高度不变
# 头部伸出 + 头部子树往前伸的长度(吻、鼻、帽檐)不超过这么远:4 人同时探向桌心吻尖不互穿。
# Q 版大头的吻也跟着变长,按实际网格包围盒量(front_extent()),长吻物种自动少伸一点
const FRONT_REACH_MAX := 1.15
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
# —— 举枪几何(枪口相对头心的位置全在这一处)——
# 手在以肩为心、一臂长的球面上,沿 GUN_APPROACH(头局部,从头心指向举枪的一侧)一族方向找手位,
# 使枪管轴线穿过头心时枪口离头心 = 持枪净空 + GUN_CLEARANCE(枪口贴在太阳穴外 8 mm)。
# 持枪净空 = 物种 LOOK 的 gun_clearance(按实际头部网格量的,已含 Q 版头的缩放);没给时用头缩放 1.0 的默认值
# 乘以 head_scale()(头绕头心等比放大,太阳穴表面跟着往外移)。HAND_GUN_HEAD 是头缩放 1.0、默认净空下的解
# (= gun_hand_target(DEFAULT_GUN_CLEARANCE)),测试校验;运行时一律现算
const GUN_CLEARANCE := 0.008
const DEFAULT_GUN_CLEARANCE := 0.17
const GUN_APPROACH := Vector3(0.9656, 0.2414, -0.0966)   # = Vector3(1, 0.25, -0.1).normalized()
const HAND_GUN_HEAD := Vector3(0.4447, 0.7619, -0.0599)   # 动森式肩、头枢轴、臂长重算(Q 版 0.4393, 0.8066, -0.0613)
const GUN_TWIST_TIME := 0.18   # 手位到了之后转手(不转枪)对准头心的时长
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
# 第一人称(V 切换,规格 2026-10-08-first-person-toggle):眼睛 = 头心(头枢轴上方 0.12)再往上、往桌心挪一点(座位坐标),
# 落在大头里面靠前的位置——自己的头只投影不渲染,往下看时胸口与领口也在镜头后面。
# 牌扇按镜头坐标摆在画面右下、像拿在手里(FP_FAN_CAM:右、下、前),跟着眼睛平移,探头、前倾时牌在画面里不动
const FP_EYE_OFFSET := Vector3(0, 0.07, -0.12)
const FP_FAN_CAM := Vector3(0.22, -0.12, -0.55)
const FP_FAN_SCALE := 1.0
# 庆祝:原地蹦几下,每次起跳/落下的时长(秒)与高度(米)
const CHEER_BOUNCES := 3
const CHEER_BOUNCE_TIME := 0.22
const CHEER_JUMP := 0.08
# 出局时打飞的帽子等散落物:挂到父节点(TableWorld)下并打上此标记,由 TableWorld 回收
const DEBRIS_GROUP := &"patron_debris"
const GREY := Color(0.42, 0.42, 0.42)   # 褪色的灰(patron.gdshader 里同值)
const FADE_TIME := 1.4
const DIE_BODY_ROT := Vector3(0.55, 0.15, -0.5)
const DIE_HEAD_ROT := Vector3(0.3, 0.3, -0.4)
# 出局时牌扇扣在大腿上(座位坐标):身子往后仰,挂在胸前的牌会跟着翻上来戳进大头的脸
const DIE_FAN_POS := Vector3(0, 0.6, -0.1)
const DIE_FAN_TIME := 0.4
const NAMEPLATE_HEIGHT := 1.92   # 名牌挂点离座位地面:Q 版大头的帽顶坐直时 ≈1.70 m、欢呼蹦起 ≈1.78 m(之前 1.82)

var species_index := 0
var alive := true
var body: Node3D
var head: Node3D
var fan: Node3D
var _fan_alive = null   # 出局前牌扇的位置(Transform3D);reset_pose 时放回
var _fan_fp = null      # 第一人称的牌扇(Transform3D,座位坐标,眼睛在 rest_eye 时):有值时牌扇每帧跟着眼睛平移,画面里不动
var _head_hidden := false
var _hidden_parts := {}  # 第一人称时藏起来的几何体 -> [原 cast_shadow, 原 layers](恢复用)
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
var _steady := false       # 枪抵着太阳穴:头不再随噪声晃
var _arms_locked := false
var _resting := {}         # 手臂 → 是否搭在桌上:搭着的手每帧按身体姿态重新落点(单手动作时另一只手照样搭着)
var _arm_serial := 0       # 每次手臂补间加一;歇手补间结束时据此判断期间有没有新动作
var _cheer_tweens: Array[Tween] = []   # 庆祝中的蹦跳与举手,复位时中止
var _noise := FastNoiseLite.new()
var _neck: Node3D
var _neck_target := Vector3.ZERO     # 座位坐标的头部偏移目标
var _neck_offset := Vector3.ZERO     # 当前偏移(弹簧积分)
var _neck_velocity := Vector3.ZERO
var _antics: PatronAntics          # Q 版搞笑表演(冒汗、发抖、星星、待机小动作……),见 patron_antics.gd


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
	_antics.tick(delta)


# —— 构建 ——

func _build() -> void:
	# 每个动画枢轴下的静态零件合成一份共享网格(按「物种:部件」缓存,所有酒客共用一份酒客材质);
	# 枢轴的名字、层级、变换都和合并前一样,动画代码不变。脖子根、眉、耳、帽的位置按物种外观
	var spec := PatronParts.species(species_index)
	_look_data = SpeciesLooks.look(species_index)
	_neck_base = _look_data["neck"].get("base", NECK_BASE) * Vector3(1.0, PatronParts.BODY_SQUASH, 1.0)
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
	_neck_reach = minf(_neck_reach, FRONT_REACH_MAX - front_extent())
	_fit_neck()
	_arm_l = _build_arm(-1.0, spec)
	_arm_r = _build_arm(1.0, spec)
	right_hand = _arm_r.get_node("Hand")
	fan = MeshKit.pivot(body, Vector3.ZERO, "Fan")
	fan.transform = _in_seat(Transform3D(CardTable.FAN_BASIS * Basis(Vector3.RIGHT, deg_to_rad(FAN_TILT_DEG)),
		HIP + FAN_POS))
	_resting = {_arm_l: true, _arm_r: true}
	_plant_paws()
	_antics = PatronAntics.new()
	add_child(_antics)
	_antics.setup(self)


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
	var brow_pos := PatronParts.brow_point(_look_data)   # Q 版:LOOK 坐标按头心放大(PatronParts.head_point)
	_brow_y = brow_pos.y
	var brow_mesh := PatronParts.part_mesh(spec, "brow")
	for side in [-1.0, 1.0]:
		var brow := MeshKit.pivot(head, Vector3(brow_pos.x * side, brow_pos.y, brow_pos.z))
		_add_part(brow, brow_mesh, "BrowMesh")
		_brows.append(brow)
	var ears: Dictionary = _look_data.get("ears", {})
	if ears.get("kind", "none") != "none":
		var ear_mesh := PatronParts.part_mesh(spec, "ear")
		var pivot := PatronParts.head_point(_look_data, ears["pivot"])
		var rot: Vector3 = ears.get("rot", Vector3.ZERO)
		for side in [-1.0, 1.0]:
			var ear := MeshKit.pivot(head)
			ear.transform = MeshForge.xf(Vector3(pivot.x * side, pivot.y, pivot.z), Vector3(rot.x, rot.y * side, rot.z * side))
			_add_part(ear, ear_mesh, "EarMesh")
			_ears.append(ear)
	var hat: Dictionary = _look_data.get("hat", {})
	_hat = MeshKit.pivot(head, Vector3.ZERO, "Hat")
	_hat.transform = MeshForge.xf(PatronParts.head_point(_look_data, hat.get("pivot", Vector3(0, 0.255, 0.01))),
		hat.get("rot", Vector3(-6, 0, 9)))
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
	# 枪抵着太阳穴时屏住不动(头一晃,只隔 8 mm 的枪口就戳进头里);搞笑表演的头部偏移同样屏住
	var wobble := 0.0 if _steady else 1.0
	yaw += (_noise.get_noise_1d(_time * 0.4) * 0.08 + _antics.head_add.y) * wobble
	pitch += (_noise.get_noise_1d(_time * 0.3 + 40.0) * 0.05 + _antics.head_add.x) * wobble
	head.rotation.y = lerpf(head.rotation.y, yaw, minf(delta * 3.0, 1.0))
	head.rotation.x = lerpf(head.rotation.x, pitch, minf(delta * 3.0, 1.0))
	head.rotation.z = lerpf(head.rotation.z, (_noise.get_noise_1d(_time * 0.25 + 90.0) * 0.06 + _antics.head_add.z) * wobble,
		minf(delta * 12.0, 1.0))
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
		var eye_pos := PatronParts.head_point(_look_data, _look_data["eyes"]["pos"])
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
	if randf() < 0.4 and not _ears.is_empty() and not _steady:
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


func front_extent() -> float:
	# 静止时头部子树(头、帽)从头枢轴往前(-Z)伸出多远,按网格包围盒量(不读顶点)
	var front := 0.0
	for inst: MeshInstance3D in [head.get_node("HeadMesh"), head.get_node("Hat/HatMesh")]:
		var xform := Transform3D.IDENTITY   # 构建时还不在场景树里:沿父节点链乘到头枢轴
		var node: Node3D = inst
		while node != head:
			xform = node.transform * xform
			node = node.get_parent()
		front = maxf(front, -(xform * inst.get_aabb()).position.z)
	return front


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
	if _fan_fp != null and alive:
		_place_fan_first_person()


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


func eye_position() -> Vector3:
	# 第一人称的眼睛(全局)
	return global_transform * eye_local()


func eye_local() -> Vector3:
	# 第一人称的眼睛(座位坐标):头心(不含转头,只含前倾、呼吸、蹦跳与脖子偏移)+ FP_EYE_OFFSET
	return body.transform * (head.position + Vector3(0, 0.12, 0)) + FP_EYE_OFFSET


static func rest_eye() -> Vector3:
	# 坐着(SEATED_LEAN)、脖子没探出时的眼睛,座位坐标:第一人称镜头的朝向、手里牌扇的位置都按它定
	return HIP + Basis(Vector3.RIGHT, -SEATED_LEAN) * (HEAD_PIVOT + Vector3(0, 0.12, 0)) + FP_EYE_OFFSET


func nameplate_anchor() -> Vector3:
	return global_transform * Vector3(0, NAMEPLATE_HEIGHT, 0.1)


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
	hold_fan(_in_seat(Transform3D((seat_basis.inverse() * world_basis).scaled(Vector3.ONE * SELF_FAN_SCALE), fan_seat)))


func present_hand_first_person(seat: Transform3D, view: Transform3D, cam_offset := FP_FAN_CAM, fan_scale := FP_FAN_SCALE) -> void:
	# 第一人称:牌扇拿在镜头右下方(cam_offset),牌面正对眼睛、牌顶朝画面上方;之后每帧跟着眼睛平移
	# (探头、轮到自己前倾、呼吸都不会让牌在画面里挪动)。seat = 座位的静止变换,view = 脖子没探出时的第一人称机位
	_fan_fp = first_person_fan(seat, view, cam_offset, fan_scale)
	_place_fan_first_person()


func hold_fan(xform: Transform3D) -> void:
	# 越肩:自己的牌扇停在 xform(身体局部),不再跟着眼睛走
	_fan_fp = null
	fan.transform = xform


func holds_fan_first_person() -> bool:
	return _fan_fp != null


func _place_fan_first_person() -> void:
	# 座位坐标里的牌扇按眼睛离开 rest_eye 的位移平移,再换到身体局部(身体前倾、呼吸缩放都抵消掉)
	var seat_xform: Transform3D = _fan_fp
	seat_xform.origin += eye_local() - rest_eye()
	fan.transform = body.transform.affine_inverse() * seat_xform


static func first_person_fan(seat: Transform3D, view: Transform3D, cam_offset: Vector3, fan_scale: float) -> Transform3D:
	# 纯函数:第一人称手里的牌扇在座位坐标里的变换(德州的底牌也用它,只是 cam_offset 不同)。
	# 位置 = 机位 × cam_offset;牌面法线指向眼睛、牌顶朝镜头的上方;放大 fan_scale
	var fan_world := view * cam_offset
	var normal := (view.origin - fan_world).normalized()
	var up := view.basis.y.normalized()
	var bottom := -(up - normal * up.dot(normal)).normalized()
	var world_basis := Basis(normal.cross(bottom), normal, bottom)
	var seat_basis := seat.basis.orthonormalized()
	return Transform3D((seat_basis.inverse() * world_basis).scaled(Vector3.ONE * fan_scale),
		seat_basis.inverse() * (fan_world - seat.origin))


# —— 第一人称:藏起自己的头 ——

func set_head_hidden(hidden: bool) -> void:
	# 只在本机:头、眼、眉、耳、帽、脖子与挂在头上的表演件(汗珠、舌头……)不渲染,但照样投影(自己的影子还在桌上)。
	# 本来就不投影的(眼睛、眉、汗珠)挪到镜头不看的 LAYER_LOCAL_HIDDEN;藏着期间新挂到头上的东西(番茄印子等)也一并处理。
	# 恢复时按记下的原值放回,即使帽子已经被打飞、挂到了别处
	if hidden == _head_hidden:
		return
	_head_hidden = hidden
	if hidden:
		for root: Node in [head, _neck]:
			for node in root.find_children("*", "GeometryInstance3D", true, false):
				_hide_part(node)
		if is_inside_tree():
			get_tree().node_added.connect(_on_node_added)
	else:
		if is_inside_tree() and get_tree().node_added.is_connected(_on_node_added):
			get_tree().node_added.disconnect(_on_node_added)
		for node in _hidden_parts:
			if is_instance_valid(node):
				node.cast_shadow = _hidden_parts[node][0]
				node.layers = _hidden_parts[node][1]
		_hidden_parts.clear()


func is_head_hidden() -> bool:
	return _head_hidden


func _hide_part(node: GeometryInstance3D) -> void:
	if _hidden_parts.has(node) or not is_instance_valid(node):
		return
	_hidden_parts[node] = [node.cast_shadow, node.layers]
	if node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
		node.layers = MeshKit.LAYER_LOCAL_HIDDEN   # 镜头不看这一层;它本来就不投影
	else:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


func _on_node_added(node: Node) -> void:
	# 延后一帧处理:挂件常在 add_child 之后才设 cast_shadow
	if node is GeometryInstance3D and (head.is_ancestor_of(node) or _neck.is_ancestor_of(node)):
		_hide_added.call_deferred(node)


func _hide_added(node: GeometryInstance3D) -> void:
	if _head_hidden and is_instance_valid(node) and (head.is_ancestor_of(node) or _neck.is_ancestor_of(node)):
		_hide_part(node)


func _exit_tree() -> void:
	set_head_hidden(false)


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
	# 伸手到桌上的左轮,握住后挂到右手上(爪心 = 枪原点,枪管沿手的 −Z)。
	# 先放下视线:导演层刚让开枪者看自己的头,俯仰被夹住;这时清掉,举枪前头就回正了
	_arms_locked = true
	_has_look = false
	_steady = true
	var gun_local := body.to_local(gun.global_position)
	await pose_right(gun_local + Vector3(0, 0.03, 0), duration).finished
	gun.reparent(right_hand, true)
	_set_fist(true)
	var tween := create_tween()
	tween.tween_property(gun, "transform", Revolver3D.HOLD_OFFSET, 0.12)
	await tween.finished


func raise_gun_to_head(gun: Node3D, duration: float) -> void:
	# 手举到按物种净空求出的手位,再「转手不转枪」:枪相对手始终是 HOLD_OFFSET,拳头一直包着握把
	_sitting_up = true
	_has_look = false
	var tween := pose_right(gun_hand_target(_gun_clearance()), duration, Tween.TRANS_BACK)
	await tween.finished
	var aim := gun_pose(right_hand.global_position, head_position())
	# 身体呼吸是非均匀缩放:各个基先正交化
	var arm_basis := _arm_r.global_basis.orthonormalized()
	var hand_basis := arm_basis.inverse() * aim.basis * Revolver3D.HOLD_OFFSET.basis.inverse()
	var settle := create_tween()
	settle.tween_property(right_hand, "quaternion", hand_basis.orthonormalized().get_rotation_quaternion(), GUN_TWIST_TIME) \
		.set_trans(Tween.TRANS_SINE)
	set_expression("worried")
	await settle.finished


func _gun_clearance() -> float:
	return gun_clearance_for(species_index)


static func gun_clearance_for(index: int) -> float:
	# 物种的持枪净空(头心沿举枪方向到头部最外表面的距离,含毛、耳朵、帽子)
	var spec := PatronParts.species(index)
	if spec.has("gun_clearance"):
		return spec["gun_clearance"]
	var look := SpeciesLooks.look(index)
	if look.has("gun_clearance"):
		return look["gun_clearance"]
	return DEFAULT_GUN_CLEARANCE * head_scale()


static func head_scale() -> float:
	# 酒客头的等比缩放(子项目② 的大头版会加 PatronParts.HEAD_SCALE;没有时为 1.0)
	return float((PatronParts as Script).get_script_constant_map().get("HEAD_SCALE", 1.0))


static func gun_aim(origin: Vector3, center: Vector3) -> Basis:
	# 枪的朝向:枪管轴线(比枪原点高 BARREL_Y)穿过 center;定点迭代 3 次
	var aim := Basis.looking_at(center - origin, Vector3.UP)
	for i in 3:
		aim = Basis.looking_at(center - (origin + aim.y * Revolver3D.BARREL_Y), Vector3.UP)
	return aim


static func gun_pose(hand: Vector3, center: Vector3) -> Transform3D:
	# 握在 hand 处的枪对准 center 时的变换(枪原点 = 手位 + 手基 × HOLD_OFFSET,枪相对手不转)
	var aim := Basis.looking_at(center - hand, Vector3.UP)
	for i in 3:
		aim = gun_aim(hand + aim * Revolver3D.HOLD_OFFSET.origin, center)
	return Transform3D(aim, hand + aim * Revolver3D.HOLD_OFFSET.origin)


static func gun_hand_target(clearance: float) -> Vector3:
	# 纯函数(身体局部):名义头心 C0 = HEAD_PIVOT + (0, 0.12, 0);手在肩球面上沿 GUN_APPROACH 一族方向二分,
	# 使对准 C0 后 |枪口 − C0| = clearance + GUN_CLEARANCE
	var center := HEAD_PIVOT + Vector3(0, 0.12, 0)
	var want := clearance + GUN_CLEARANCE
	var lo := 0.25
	var hi := 2.0
	for i in 32:
		var mid := (lo + hi) * 0.5
		var hand := SHOULDER + (center + GUN_APPROACH * mid - SHOULDER).normalized() * ARM_LENGTH
		if (gun_pose(hand, center) * Revolver3D.MUZZLE_POS).distance_to(center) < want:
			lo = mid
		else:
			hi = mid
	return SHOULDER + (center + GUN_APPROACH * ((lo + hi) * 0.5) - SHOULDER).normalized() * ARM_LENGTH


func lower_gun(gun: Node3D, rest: Transform3D, table_parent: Node3D, duration: float) -> void:
	_sitting_up = false
	_steady = false
	set_expression("neutral")
	var untwist := create_tween()
	untwist.tween_property(right_hand, "quaternion", Quaternion.IDENTITY, duration)
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
	_antics.relief()
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
		# 侧放(REST_ROLL:转轮与底帽同时着地),最低点在毡面上
		var landing := global_transform * Vector3(GUN_DROP.x, SeatLayout.FELT_TOP + Revolver3D.REST_HALF_WIDTH, GUN_DROP.z)
		drop.tween_property(gun, "global_position", landing, 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		drop.parallel().tween_property(gun, "rotation", Vector3(0, gun.rotation.y + 1.8, PI / 2.0 + Revolver3D.REST_ROLL), 0.45)
	right_hand.quaternion = Quaternion.IDENTITY
	_steady = false
	var fall := create_tween().set_parallel()
	var body_rot: Vector3 = _look_data.get("anim", {}).get("die_body_rot", DIE_BODY_ROT)   # 乌龟侧倒,龟壳不穿椅背
	fall.tween_property(body, "rotation", body_rot, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# 头往后仰、歪向一边(动森式大头往前栽会砸进自己的牌扇),脸朝上,头顶转星星
	fall.tween_property(head, "rotation", DIE_HEAD_ROT, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_arm(fall, _arm_l, _mirror(HAND_DEAD, -1.0), 0.5, Tween.TRANS_BOUNCE)
	_tween_arm(fall, _arm_r, HAND_DEAD, 0.5, Tween.TRANS_BOUNCE)
	_knock_hat_off()
	_fan_alive = fan.transform
	var body_final := Transform3D(Basis.from_euler(body_rot), HIP)
	var lap := Transform3D(Basis(Vector3.BACK, PI), DIE_FAN_POS)   # 平放、牌背朝上
	fall.tween_property(fan, "transform", body_final.affine_inverse() * lap, DIE_FAN_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_method(_set_fade, 0.0, 1.0, FADE_TIME)
	if not _look_data.get("tail", {}).is_empty():
		fall.tween_method(func(v: float): _legs.set_instance_shader_parameter("tail",
			Vector4(_phase, _look_data["tail"].get("sway", 0.12), v, 0.0)), 0.0, 1.0, FADE_TIME)
	_antics.die()


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
	_antics.celebrate()
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
	right_hand.quaternion = Quaternion.IDENTITY
	_steady = false
	set_head_hidden(false)   # 镜头若仍在第一人称,SeatCamera 下一帧再藏
	body.position = HIP
	if _fan_alive != null:
		fan.transform = _fan_alive
		_fan_alive = null
	rest_arms(false)
	_antics.reset()


func startle() -> void:
	# 被吓一跳(有人喊「骗子!」拍桌、旁边有人中枪):原地一蹦、眼睛瞪圆、帽子弹起、耳朵炸开
	_antics.startle()


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
