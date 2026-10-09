class_name PatronFaceRig
extends RefCounted
# 酒客脸部的动画:眼珠跟着视线转、上眼睑眨眼与随表情开合/倾斜、眉毛挑起/皱起、耳朵随表情耷拉或竖起并偶尔抖一下、
# 嘴按表情换形(各表情的嘴网格都已按物种缓存,换嘴只是换网格引用)。
# 表情状态是几个浮点数(补间),每帧按它们重新摆放眼睑、眉毛、耳朵——补间之间互不打架,眨眼叠加在任何表情上。


# 各表情相对平时的变化:lid 上眼睑开度增减、lid_tilt 眼睑内眼角下压(弧度,负为上挑)、
# brow_tilt 眉毛内端下压(弧度,负为八字眉)、brow_raise 眉毛抬高(米)、ears 耳朵往后倒(弧度,负为往前耷拉)
const FACES := {
	"neutral": {"lid": 0.0, "lid_tilt": 0.0, "brow_tilt": 0.0, "brow_raise": 0.0, "ears": 0.0},
	"angry": {"lid": -0.22, "lid_tilt": 0.26, "brow_tilt": 0.42, "brow_raise": -0.005, "ears": 0.4},
	"worried": {"lid": 0.12, "lid_tilt": -0.22, "brow_tilt": -0.42, "brow_raise": 0.012, "ears": -0.35},
	"happy": {"lid": -0.14, "lid_tilt": 0.0, "brow_tilt": -0.12, "brow_raise": 0.01, "ears": -0.1},
	"smug": {"lid": -0.34, "lid_tilt": 0.06, "brow_tilt": 0.16, "brow_raise": 0.004, "ears": 0.12},
}
const EXPRESSION_TIME := 0.18
const BLINK_CLOSE := 0.06
const BLINK_OPEN := 0.08
const BLINK_GAP := Vector2(1.8, 5.5)    # 两次眨眼的间隔(秒)
const TWITCH_CHANCE := 0.4              # 眨眼时顺便抖一下耳朵的概率
const TWITCH := 0.3
const GAZE_YAW := 0.38                  # 眼珠最多转这么多(弧度),再多靠转头
const GAZE_PITCH := 0.3
const GAZE_SPEED := 8.0

var lid_open := 1.0          # 当前上眼睑开度(含表情)
var lid_tilt := 0.0
var brow_tilt := 0.0
var brow_raise := 0.0
var ear_droop := 0.0
var blink := 0.0             # 眨眼:0 睁 → 1 闭
var twitch := [0.0, 0.0]

var _owner: Node3D
var _meshes: Dictionary
var _material: Material
var _rest_open := 1.0
var _eyes: Array[MeshInstance3D] = []
var _lids: Array[MeshInstance3D] = []
var _brows: Array[MeshInstance3D] = []
var _ears: Array[MeshInstance3D] = []
var _eye_rest: Array[Transform3D] = []
var _brow_rest: Array[Transform3D] = []
var _ear_rest: Array[Transform3D] = []
var _gaze: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _mouth: MeshInstance3D
var _x_eyes: MeshInstance3D
var _blink_in := 2.0
var _expression := "neutral"
var _tweens: Array = []   # 进行中的表情/眨眼补间:出局时一并停下,免得把闭上的眼又补间开


func _init(owner: Node3D, head: Node3D, spec: Dictionary, meshes: Dictionary, material: Material) -> void:
	_owner = owner
	_meshes = meshes
	_material = material
	_rest_open = spec["eyes"].get("open", 1.0)
	lid_open = _rest_open
	var shape := PatronHead.sculpt(spec)
	for side in [-1.0, 1.0]:
		var suffix := "R" if side > 0.0 else "L"
		var low := suffix.to_lower()
		var rest := PatronFace.eye_rest(spec, shape, side)
		_eye_rest.append(rest)
		_eyes.append(_part(head, "eye", "Eye" + suffix, rest))
		_lids.append(_part(head, "lid_" + low, "Lid" + suffix, rest))
		var brow := PatronFace.brow_frame(spec, shape, side)
		_brow_rest.append(brow)
		_brows.append(_part(head, "brow_" + low, "Brow" + suffix, brow))
		if (meshes["ear"] as ArrayMesh).get_surface_count() > 0:   # 没有耳朵的物种(青蛙)不建耳朵节点
			var ear := PatronEars.pivot(spec, shape, side)
			_ear_rest.append(ear)
			_ears.append(_part(head, "ear", "Ear" + suffix, ear))
	_mouth = _part(head, "mouth:neutral", "Mouth", Transform3D.IDENTITY)
	_x_eyes = _part(head, "x_eyes", "XEyes", Transform3D.IDENTITY)
	_x_eyes.visible = false
	_apply()


func _part(head: Node3D, mesh_key: String, node_name: String, xform: Transform3D) -> MeshInstance3D:
	# 脸上的小件都不投影(省掉每盏投影灯的一遍绘制,阴影里也看不出来)
	var inst := MeshBatch.instance(head, _meshes[mesh_key], {PatronSkin.SLOT: _material}, node_name, false)
	inst.transform = xform
	return inst


# —— 表情 ——

func set_expression(kind: String) -> void:
	var face: Dictionary = FACES.get(kind, FACES["neutral"])
	_expression = kind if FACES.has(kind) else "neutral"
	var tween := _track(_owner.create_tween().set_parallel())
	tween.tween_property(self, "lid_open", clampf(_rest_open + face["lid"], 0.15, 1.0), EXPRESSION_TIME)
	tween.tween_property(self, "lid_tilt", face["lid_tilt"], EXPRESSION_TIME)
	tween.tween_property(self, "brow_tilt", face["brow_tilt"], EXPRESSION_TIME)
	tween.tween_property(self, "brow_raise", face["brow_raise"], EXPRESSION_TIME)
	tween.tween_property(self, "ear_droop", face["ears"], EXPRESSION_TIME * 1.5)
	_set_mouth(_expression)


func expression() -> String:
	return _expression


func _set_mouth(kind: String) -> void:
	_mouth.mesh = _meshes["mouth:" + kind]
	_mouth.set_surface_override_material(0, _material)


# —— 每帧 ——

func update(delta: float, alive: bool, look: Variant) -> void:
	# look:视线目标(全局坐标)或 null
	if alive:
		_blink_in -= delta
		if _blink_in <= 0.0:
			_blink_in = randf_range(BLINK_GAP.x, BLINK_GAP.y)
			_start_blink()
		for i in _eyes.size():
			var target := _gaze_angles(i, look) if look != null else Vector2.ZERO
			_gaze[i] = _gaze[i].lerp(target, minf(delta * GAZE_SPEED, 1.0))
	_apply()


func _gaze_angles(i: int, look: Vector3) -> Vector2:
	var head := _eyes[i].get_parent() as Node3D
	var local := (head.global_transform * _eye_rest[i]).affine_inverse() * look
	var yaw := clampf(atan2(local.x, -local.z), -GAZE_YAW, GAZE_YAW)
	var pitch := clampf(atan2(local.y, Vector2(local.x, local.z).length()), -GAZE_PITCH, GAZE_PITCH)
	return Vector2(yaw, pitch)


func _apply() -> void:
	var open := lid_open * (1.0 - blink)
	for i in _eyes.size():
		var side := -1.0 if i == 0 else 1.0
		var gaze := Basis(Vector3.UP, -_gaze[i].x) * Basis(Vector3.RIGHT, _gaze[i].y)
		_eyes[i].transform = _eye_rest[i] * Transform3D(gaze, Vector3.ZERO)
		var lid := Basis(Vector3.BACK, side * lid_tilt) * Basis(Vector3.RIGHT, PatronFace.lid_angle(open))
		_lids[i].transform = _eye_rest[i] * Transform3D(lid, Vector3.ZERO)
		_brows[i].transform = _brow_rest[i] * Transform3D(Basis(Vector3.BACK, side * brow_tilt), Vector3(0, brow_raise, 0))
		if i < _ears.size():
			_ears[i].transform = _ear_rest[i] * Transform3D(Basis(Vector3.RIGHT, ear_droop + twitch[i]), Vector3.ZERO)


func _start_blink() -> void:
	var tween := _track(_owner.create_tween())
	tween.tween_property(self, "blink", 1.0, BLINK_CLOSE)
	tween.tween_property(self, "blink", 0.0, BLINK_OPEN)
	if randf() < TWITCH_CHANCE:
		var i := randi() % twitch.size()
		var flick := _track(_owner.create_tween())
		flick.tween_method(func(v: float) -> void: twitch[i] = v, 0.0, TWITCH, 0.07)
		flick.tween_method(func(v: float) -> void: twitch[i] = v, TWITCH, 0.0, 0.15)


func _track(tween: Tween) -> Tween:
	_tweens = _tweens.filter(func(t: Tween) -> bool: return t.is_valid() and t.is_running())
	_tweens.append(tween)
	return tween


# —— 出局 ——

func knock_out() -> void:
	# 闭眼画叉、吐舌头
	for tween in _tweens:
		if tween.is_valid():
			tween.kill()
	_tweens = []
	lid_open = 0.0
	blink = 0.0
	lid_tilt = 0.0
	_x_eyes.visible = true
	for eye in _eyes:
		eye.visible = false
	_set_mouth("dead")
	_apply()
