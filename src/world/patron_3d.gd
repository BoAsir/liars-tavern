class_name Patron
extends Node3D
# 酒客角色:坐在椅子上的卡通动物。原点在座位地面,面朝 -Z(牌桌中心)。
# 待机:呼吸、眨眼、眼神与头部跟随;动作:出牌伸手、拍桌、举枪、中弹倒下、庆祝。
# 拿着牌时双手也搭在桌上,牌扇自己立在胸前——爪子去扶牌会挡住牌面。


const ARM_LENGTH := 0.4
# 肩略靠前:坐直时单节手臂才够得着桌沿,手掌能搭到桌面上
const SHOULDER := Vector3(0.21, 0.52, -0.06)
const PAW_RADIUS := 0.058
const PAW_SCALE := Vector3(1, 0.8, 1.1)
const HEAD_PIVOT := Vector3(0, 0.65, -0.02)
const HIP := Vector3(0, 0.5, 0.12)
# 搭在桌沿上:恰好一臂之长,掌底贴着桌面(拿着牌时也是这个姿势)
const HAND_REST := Vector3(0.16, 0.33, -0.41)
const HAND_REACH := Vector3(0.06, 0.33, -0.66)
const HAND_RAISED := Vector3(0.24, 0.82, -0.32)
const HAND_SLAM := Vector3(0.12, 0.29, -0.52)
const HAND_GUN_HEAD := Vector3(0.33, 0.85, -0.05)
const HAND_CHEER := Vector3(0.32, 1.0, -0.12)
const HAND_DEAD := Vector3(0.28, 0.0, 0.05)
# 他人的牌扇:在 CardTable.FAN_BASIS(竖立、牌面朝持牌者)基础上再上仰,牌面迎向持牌者的视线
const FAN_TILT_DEG := -18.0
# 第三人称下自己的牌扇:举到右胸前、略放大,牌面朝向越肩镜头
const SELF_FAN_POS := Vector3(0.36, 0.62, -0.3)
const SELF_FAN_SCALE := 1.4
# 庆祝:原地蹦几下,每次起跳/落下的时长(秒)与高度(米)
const CHEER_BOUNCES := 3
const CHEER_BOUNCE_TIME := 0.22
const CHEER_JUMP := 0.08
# 出局时打飞的帽子等散落物:挂到父节点(TableWorld)下并打上此标记,由 TableWorld 回收
const DEBRIS_GROUP := &"patron_debris"
const GREY := Color(0.42, 0.42, 0.42)
const LAPEL_DARKEN := 0.35

var species_index := 0
var alive := true
var body: Node3D
var head: Node3D
var fan: Node3D
var right_hand: Node3D

var _arm_l: Node3D
var _arm_r: Node3D
var _eyes: Array = []      # [{"pivot", "pupil", "marks"}]
var _brows: Array = []
var _ears: Array = []
var _hat: Node3D
var _materials: Array = []
var _look_target := Vector3.ZERO
var _has_look := false
var _time := 0.0
var _phase := 0.0
var _blink_in := 2.0
var _breath_rate := 1.0
var _lean := 0.0
var _arms_locked := false
var _cheer_tweens: Array[Tween] = []   # 庆祝中的蹦跳与举手,复位时中止
var _noise := FastNoiseLite.new()


func _init(p_species_index := 0) -> void:
	species_index = p_species_index
	_phase = species_index * 1.7
	_noise.seed = species_index * 31 + 7
	_build()


func _process(delta: float) -> void:
	_time += delta
	if alive:
		_animate_idle(delta)


# —— 构建 ——

func _build() -> void:
	var spec := PatronParts.species(species_index)
	var mats := {
		"fur": _mat(spec["fur"], 0.75), "muzzle": _mat(spec["muzzle"], 0.8), "dark": _mat(spec["dark"], 0.6),
		"coat": _mat(spec["coat"], 0.85), "accent": _mat(spec["accent"], 0.5),
		"nose": _mat(Color(0.05, 0.04, 0.04), 0.15), "white": _mat(Color(0.97, 0.96, 0.93), 0.25),
		"pupil": _mat(Color(0.03, 0.03, 0.04), 0.1), "hat": _mat(spec["dark"].darkened(0.4), 0.7),
	}
	PatronParts.build_chair(self)
	body = MeshKit.pivot(self, HIP, "Body")
	MeshKit.add(body, MeshKit.capsule(0.2, 0.62), mats["coat"], Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1, 1, 0.85))
	MeshKit.add(body, MeshKit.sphere(0.19, 20), mats["coat"], Vector3(0, 0.12, -0.05), Vector3.ZERO, Vector3(1.05, 0.85, 0.95))
	# 衬衫前襟 + 领结
	MeshKit.add(body, MeshKit.sphere(0.09, 16), mats["white"], Vector3(0, 0.43, -0.15), Vector3(-10, 0, 0),
		Vector3(0.75, 1.15, 0.35))
	for side in [-1.0, 1.0]:
		MeshKit.add(body, MeshKit.prism(Vector3(0.05, 0.05, 0.02)), mats["accent"], Vector3(0.026 * side, 0.535, -0.175),
			Vector3(-10, 0, -90 * side))
	MeshKit.add(body, MeshKit.sphere(0.013, 8), mats["accent"], Vector3(0, 0.535, -0.18))
	# 翻领用压暗的外套色:浅色强调色做翻领会在胸前拼出一个突兀的「A」字
	var lapel := _mat(spec["coat"].darkened(LAPEL_DARKEN), 0.8)
	for side in [-1.0, 1.0]:
		MeshKit.add(body, MeshKit.box(Vector3(0.05, 0.24, 0.02)), lapel, Vector3(0.06 * side, 0.43, -0.17),
			Vector3(-8, 0, 18 * side))
	for y in [0.3, 0.2, 0.1]:
		MeshKit.add(body, MeshKit.sphere(0.014, 8), WorldMaterials.brass(), Vector3(0, y, -0.205 + (0.3 - y) * 0.15))
	# 宽肩 + 短脖子 + 领口
	MeshKit.add(body, MeshKit.sphere(0.2, 20), mats["coat"], Vector3(0, 0.47, -0.01), Vector3.ZERO, Vector3(1.22, 0.55, 0.85))
	MeshKit.add(body, MeshKit.cylinder(0.075, 0.085, 0.1, 16), mats["fur"], Vector3(0, 0.6, -0.02))
	MeshKit.add(body, MeshKit.torus(0.075, 0.1, 24), mats["coat"], Vector3(0, 0.565, -0.02))
	_build_head(spec, mats)
	_arm_l = _build_arm(-1.0, mats)
	_arm_r = _build_arm(1.0, mats)
	right_hand = _arm_r.get_node("Hand")
	fan = MeshKit.pivot(body, Vector3(0, 0.44, -0.37), "Fan")
	fan.basis = CardTable.FAN_BASIS * Basis(Vector3.RIGHT, deg_to_rad(FAN_TILT_DEG))
	_set_arm(_arm_l, _mirror(HAND_REST, -1.0))
	_set_arm(_arm_r, HAND_REST)


func _build_head(spec: Dictionary, mats: Dictionary) -> void:
	head = MeshKit.pivot(body, HEAD_PIVOT, "Head")
	MeshKit.add(head, MeshKit.sphere(0.17, 28), mats["fur"], Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1, 0.95, 1))
	MeshKit.add(head, MeshKit.sphere(0.12, 20), mats["muzzle"], Vector3(0, 0.08, -0.07), Vector3.ZERO, Vector3(1.05, 0.8, 0.9))
	PatronParts.build_snout(head, spec, mats)
	for side in [-1.0, 1.0]:
		var pivot := MeshKit.pivot(head, Vector3(0.062 * side, 0.165, -0.13))
		MeshKit.add(pivot, MeshKit.sphere(0.042, 18), mats["white"], Vector3.ZERO, Vector3.ZERO, Vector3(1, 1.1, 0.8))
		var pupil := MeshKit.add(pivot, MeshKit.sphere(0.021, 12), mats["pupil"], Vector3(0, 0, -0.03))
		MeshKit.add(pupil, MeshKit.sphere(0.006, 6), WorldMaterials.emissive(Color.WHITE, 2.0), Vector3(0.007, 0.008, -0.016))
		var marks := MeshKit.pivot(pivot, Vector3(0, 0, -0.036))
		for angle in [45.0, -45.0]:
			MeshKit.add(marks, MeshKit.box(Vector3(0.055, 0.009, 0.01)), mats["pupil"], Vector3.ZERO, Vector3(0, 0, angle))
		marks.visible = false
		_eyes.append({"pivot": pivot, "pupil": pupil, "marks": marks})
		var brow := MeshKit.pivot(head, Vector3(0.064 * side, 0.222, -0.142))
		MeshKit.add(brow, MeshKit.box(Vector3(0.062, 0.013, 0.018)), mats["dark"])
		_brows.append(brow)
	_ears = PatronParts.build_ears(head, spec["ears"], mats["fur"], mats["dark"])
	_hat = PatronParts.build_hat(head, spec["hat"], mats["hat"], mats["accent"])


func _build_arm(side: float, mats: Dictionary) -> Node3D:
	var pivot := MeshKit.pivot(body, _mirror(SHOULDER, side), "ArmR" if side > 0 else "ArmL")
	MeshKit.add(pivot, MeshKit.sphere(0.07, 14), mats["coat"])
	MeshKit.add(pivot, MeshKit.capsule(0.055, ARM_LENGTH), mats["coat"], Vector3(0, 0, -ARM_LENGTH / 2.0), Vector3(90, 0, 0))
	MeshKit.add(pivot, MeshKit.cylinder(0.06, 0.06, 0.05, 16), mats["muzzle"], Vector3(0, 0, -ARM_LENGTH + 0.04),
		Vector3(90, 0, 0))
	var hand := MeshKit.pivot(pivot, Vector3(0, 0, -ARM_LENGTH), "Hand")
	MeshKit.add(hand, MeshKit.sphere(PAW_RADIUS, 16), mats["fur"], Vector3.ZERO, Vector3.ZERO, PAW_SCALE)
	return pivot


func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	# 每个角色独立材质:出局时需要单独褪色
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.rim_enabled = true
	mat.rim = 0.3
	mat.rim_tint = 0.5
	_materials.append(mat)
	return mat


# —— 待机 ——

func _animate_idle(delta: float) -> void:
	var breath := sin(_time * 1.6 * _breath_rate + _phase)
	body.scale = Vector3(1.0 - breath * 0.004, 1.0 + breath * 0.012, 1.0)
	body.rotation.x = lerpf(body.rotation.x, -_lean + breath * 0.01, minf(delta * 4.0, 1.0))
	var yaw := 0.0
	var pitch := 0.0
	if _has_look:
		var local := body.to_local(_look_target) - HEAD_PIVOT
		yaw = clampf(atan2(-local.x, -local.z), -0.7, 0.7)
		pitch = clampf(atan2(local.y, Vector2(local.x, local.z).length()), -0.45, 0.35)
	yaw += _noise.get_noise_1d(_time * 0.4) * 0.08
	pitch += _noise.get_noise_1d(_time * 0.3 + 40.0) * 0.05
	head.rotation.y = lerpf(head.rotation.y, yaw, minf(delta * 3.0, 1.0))
	head.rotation.x = lerpf(head.rotation.x, pitch, minf(delta * 3.0, 1.0))
	head.rotation.z = _noise.get_noise_1d(_time * 0.25 + 90.0) * 0.06
	for eye in _eyes:
		var target_offset := Vector3.ZERO
		if _has_look:
			var dir: Vector3 = eye["pivot"].to_local(_look_target).normalized()
			target_offset = Vector3(dir.x, dir.y, 0.0) * 0.012
		eye["pupil"].position = eye["pupil"].position.lerp(Vector3(0, 0, -0.03) + target_offset, minf(delta * 8.0, 1.0))
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink_in = randf_range(1.8, 5.5)
		_blink()


func _blink() -> void:
	var tween := create_tween().set_parallel()
	for eye in _eyes:
		tween.tween_property(eye["pivot"], "scale:y", 0.1, 0.06)
	tween.chain()
	for eye in _eyes:
		tween.parallel().tween_property(eye["pivot"], "scale:y", 1.0, 0.08)
	if randf() < 0.4 and not _ears.is_empty():
		var ear: Node3D = _ears[randi() % _ears.size()]
		var base := ear.rotation.x
		var twitch := create_tween()
		twitch.tween_property(ear, "rotation:x", base - 0.3, 0.07)
		twitch.tween_property(ear, "rotation:x", base, 0.15)


func look_at_point(point: Vector3) -> void:
	_look_target = point
	_has_look = true


func head_position() -> Vector3:
	return head.global_transform * Vector3(0, 0.12, 0)


func nameplate_anchor() -> Vector3:
	return global_transform * Vector3(0, 1.82, 0.1)


func set_active(active: bool) -> void:
	_lean = 0.13 if active else 0.0
	_breath_rate = 1.8 if active else 1.0


func set_expression(kind: String) -> void:
	var angles := {"neutral": 0.0, "angry": -0.38, "worried": 0.4, "happy": 0.15, "smug": -0.15}
	var lift := 0.02 if kind in ["worried", "happy"] else 0.0
	var tween := create_tween().set_parallel()
	for i in _brows.size():
		var side := -1.0 if i == 0 else 1.0
		tween.tween_property(_brows[i], "rotation:z", angles.get(kind, 0.0) * -side, 0.18)
		tween.tween_property(_brows[i], "position:y", 0.222 + lift, 0.18)


# —— 手臂 ——

func rest_arms(animate := true) -> void:
	# 双手搭回桌上;动作进行中(动作锁)时不打断,动作结束后由动作自己调用
	if _arms_locked:
		return
	pose_arms(_mirror(HAND_REST, -1.0), HAND_REST, 0.3 if animate else 0.0)


func present_hand_to(viewer: Vector3) -> void:
	# 第三人称:把牌扇移到右胸前并放大,牌面法线指向镜头、牌顶朝上,越肩即可看清点数
	# 按座位的静止姿态计算(登场缩放动画期间 global 坐标不可靠)
	var seat_basis := global_basis.orthonormalized()
	var fan_world := global_position + seat_basis * (HIP + SELF_FAN_POS)
	var normal := (viewer - fan_world).normalized()
	var bottom := -(Vector3.UP - normal * Vector3.UP.dot(normal)).normalized()
	var world_basis := Basis(normal.cross(bottom), normal, bottom)
	fan.transform = Transform3D((seat_basis.inverse() * world_basis).scaled(Vector3.ONE * SELF_FAN_SCALE), SELF_FAN_POS)


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
	# 出牌手势:双手前推再收回
	if _arms_locked or not alive:
		return
	_arms_locked = true
	await pose_arms(_mirror(HAND_REACH, -1.0), HAND_REACH, 0.22).finished
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
	await pose_right(HAND_SLAM, 0.08, Tween.TRANS_EXPO).finished
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
	var tween := create_tween()
	tween.tween_property(gun, "transform", Transform3D(Basis(), Vector3(0, -0.01, -0.02)), 0.12)
	await tween.finished


func raise_gun_to_head(gun: Node3D, duration: float) -> void:
	var tween := pose_right(HAND_GUN_HEAD, duration, Tween.TRANS_BACK)
	await tween.finished
	# 枪口对准太阳穴
	var aim := Transform3D(Basis.looking_at(head_position() - gun.global_position, Vector3.UP), gun.global_position)
	var settle := create_tween()
	settle.tween_property(gun, "global_transform", aim, 0.18).set_trans(Tween.TRANS_SINE)
	set_expression("worried")
	await settle.finished


func lower_gun(gun: Node3D, rest: Transform3D, table_parent: Node3D, duration: float) -> void:
	set_expression("neutral")
	await pose_right(body.to_local(rest.origin) + Vector3(0, 0.03, 0), duration).finished
	gun.reparent(table_parent, true)
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
	for eye in _eyes:
		eye["pupil"].visible = false
		eye["marks"].visible = true
	if gun != null and table_parent != null:
		gun.reparent(table_parent, true)
		var drop := create_tween()
		var landing := Vector3(gun.global_position.x, SeatLayout.TABLE_TOP + 0.02, gun.global_position.z)
		drop.tween_property(gun, "global_position", landing.lerp(global_position, 0.25), 0.45).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		drop.parallel().tween_property(gun, "rotation", Vector3(0, gun.rotation.y + 1.8, PI / 2.0), 0.45)
	var fall := create_tween().set_parallel()
	fall.tween_property(body, "rotation", Vector3(0.55, 0.15, -0.5), 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	fall.tween_property(head, "rotation", Vector3(-0.5, 0.3, -0.45), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween_arm(fall, _arm_l, _mirror(HAND_DEAD, -1.0), 0.5, Tween.TRANS_BOUNCE)
	_tween_arm(fall, _arm_r, HAND_DEAD, 0.5, Tween.TRANS_BOUNCE)
	_knock_hat_off()
	for mat in _materials:
		var target: Color = mat.albedo_color.lerp(GREY * mat.albedo_color.get_luminance() * 1.6, 0.85)
		fall.tween_property(mat, "albedo_color", target, 1.4)


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
	# 回到等待厅 / 新一局开始:停下庆祝,解除动作锁,恢复中性表情、坐正、空手
	for tween in _cheer_tweens:
		if tween.is_valid():
			tween.kill()
	_cheer_tweens = []
	_arms_locked = false
	set_expression("neutral")
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
	tween.tween_property(arm, "quaternion", _arm_quat(arm, target), maxf(duration, 0.001)) \
		.set_trans(trans).set_ease(Tween.EASE_IN_OUT if trans != Tween.TRANS_BACK else Tween.EASE_OUT)


func _arm_quat(arm: Node3D, target: Vector3) -> Quaternion:
	var dir := target - arm.position
	var up := Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.95 else Vector3.BACK
	return Basis.looking_at(dir, up).get_rotation_quaternion()


static func _mirror(v: Vector3, side: float) -> Vector3:
	return Vector3(v.x * side, v.y, v.z)
