class_name DdzHats
# 斗地主的身份帽(定地主时戴上,新的一手摘掉):地主戴小瓜皮帽,农民戴草帽(网格见 DdzProps,所有人共用)。
# 帽子挂在酒客自己帽子的枢轴(Head/Hat)下面:跳舞时的抛帽、点头、晃脑都带着它;酒客原来的帽子网格(HatMesh)先藏起来,
# 摘帽时放回。帽口贴着颅骨上部一圈(Patron.skull_ellipsoid,各物种的大头不一样大),所以每个物种都戴得正。
# 挂在头下面的东西,第一人称藏头(Patron.set_head_hidden)时一并只投影不渲染(戴帽时头已藏着也会被 node_added 接住)。


const NODE := "DdzRoleHat"
const ROLE_META := &"ddz_role"
const SEAT_HEIGHT := 0.55        # 帽口在颅骨中心之上 半轴 × 这么多(那一圈的宽度约为半轴的 0.84)
const TILT := Vector3(-8, 0, 7)  # 歪戴一点(度),Q 版更俏皮
const POP_TIME := 0.42


static func put_on(patron: Patron, role: String, pop := true) -> Node3D:
	# role:DdzState.ROLE_LANDLORD / ROLE_FARMER;其他值等于摘帽。返回帽子节点(没有帽子枢轴时为空)
	take_off(patron)
	if role != DdzState.ROLE_LANDLORD and role != DdzState.ROLE_FARMER:
		return null
	var pivot := _pivot(patron)
	if pivot == null:
		return null
	var own := pivot.get_node_or_null("HatMesh")
	if own is Node3D:
		own.visible = false
	var holder := Node3D.new()
	holder.name = NODE
	holder.set_meta(ROLE_META, role)
	var mesh := DdzProps.landlord_hat() if role == DdzState.ROLE_LANDLORD else DdzProps.straw_hat()
	var inst := MeshKit.add(holder, mesh, null, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, MeshKit.SHADOW_ON)
	inst.name = "HatMesh"
	pivot.add_child(holder)
	var rest := rest_transform(patron, pivot)
	holder.transform = rest
	if pop:
		# 「啵」地一下:从小弹到比原来大一点再落回去
		var basis := rest.basis
		holder.transform = Transform3D(basis.scaled(Vector3.ONE * 0.05), rest.origin + basis.y.normalized() * 0.08)
		var tween := holder.create_tween()
		tween.tween_method(func(t: float) -> void:
			var k := 1.0 + 0.32 * sin(t * PI) * (1.0 - t)
			var lift := 0.08 * (1.0 - t) * (1.0 - t)
			holder.transform = Transform3D(basis.scaled(Vector3.ONE * maxf(t * k, 0.05)), rest.origin + basis.y.normalized() * lift),
			0.0, 1.0, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return holder


static func take_off(patron: Patron) -> void:
	var pivot := _pivot(patron)
	if pivot == null:
		return
	var old := pivot.get_node_or_null(NODE)
	if old != null:
		pivot.remove_child(old)
		old.queue_free()
	var own := pivot.get_node_or_null("HatMesh")
	if own is Node3D:
		own.visible = true


static func role_of(patron: Patron) -> String:
	var pivot := _pivot(patron)
	var hat: Node = pivot.get_node_or_null(NODE) if pivot != null else null
	return str(hat.get_meta(ROLE_META, "")) if hat != null else ""


static func hat_node(patron: Patron) -> Node3D:
	var pivot := _pivot(patron)
	return pivot.get_node_or_null(NODE) if pivot != null else null


static func rest_transform(patron: Patron, pivot: Node3D) -> Transform3D:
	# 帽子枢轴局部:帽口中心在颅骨上部、按颅骨半轴缩放(帽子按 SKULL_REF 建),再抵消枢轴自己的位置与歪戴角度
	var skull: Array = patron.skull_ellipsoid()
	var center: Vector3 = skull[0]
	var radii: Vector3 = skull[1]
	var s := Vector3(radii.x, radii.y, minf(radii.z, radii.x * 1.1)) / DdzProps.SKULL_REF
	var head_local := Transform3D(Basis.from_euler(TILT * PI / 180.0) * Basis.from_scale(s), center + Vector3(0, radii.y * SEAT_HEIGHT, 0))
	return pivot.transform.affine_inverse() * head_local


static func _pivot(patron: Patron) -> Node3D:
	if patron == null or not is_instance_valid(patron) or patron.head == null:
		return null
	return patron.head.get_node_or_null("Hat")
