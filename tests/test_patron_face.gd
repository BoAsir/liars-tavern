extends GutTest
# 酒客的五官与材质:表情换嘴、眨眼靠眼睑不压扁眼珠、出局画叉吐舌并整身褪色;
# 网格按物种预先建好(prewarm),同物种共用网格、各自一份材质;物种表是数据驱动的。

const REQUIRED_KEYS := ["id", "label", "fur", "muzzle", "dark", "coat", "accent"]
const SHAPE_KEYS := ["head", "snout", "nose", "eyes", "brows", "mouth", "ears", "hat"]

var patron: Patron


func before_each():
	patron = Patron.new(0)
	add_child_autofree(patron)


func _mouth() -> MeshInstance3D:
	return patron.head.get_node("Mouth")


func test_every_species_has_the_required_and_shape_keys():
	for spec in PatronParts.SPECIES:
		for key in REQUIRED_KEYS + SHAPE_KEYS:
			assert_true(spec.has(key), "%s 有 %s" % [spec.get("id", "?"), key])


func test_prewarm_builds_every_species_mesh_up_front():
	PatronParts.prewarm()
	for spec in PatronParts.SPECIES:
		for part in ["torso", "skull", "eye", "hat", "arm_r", "mouth:angry", "mouth:dead"]:
			assert_true(MeshBatch.is_cached("patron:%s:%s" % [spec["id"], part]), "%s 的 %s 已缓存" % [spec["id"], part])


func test_expression_swaps_the_mouth_mesh():
	var neutral := _mouth().mesh
	for kind in ["angry", "worried", "happy", "smug"]:
		patron.set_expression(kind)
		assert_eq(patron.expression(), kind)
		assert_ne(_mouth().mesh, neutral, "%s 的嘴和平时不同" % kind)
	patron.set_expression("neutral")
	assert_eq(_mouth().mesh, neutral, "回到平时的嘴")


func test_unknown_expression_falls_back_to_neutral():
	patron.set_expression("confused")
	assert_eq(patron.expression(), "neutral")


func test_blinking_moves_the_lids_not_the_eyes():
	var eye: Node3D = patron.head.get_node("EyeR")
	var lid: Node3D = patron.head.get_node("LidR")
	var eye_scale := eye.scale
	var open_lid := lid.basis
	patron._face.blink = 1.0
	patron._face._apply()
	assert_eq(eye.scale, eye_scale, "眼珠不被压扁")
	assert_false(lid.basis.is_equal_approx(open_lid), "眼睑转下来盖住眼睛")


func test_death_shows_x_eyes_and_fades_only_this_patron():
	var other := Patron.new(0)
	add_child_autofree(other)
	patron.die()
	assert_true(patron.head.get_node("XEyes").visible, "叉叉眼")
	assert_false(patron.head.get_node("EyeR").visible, "眼珠藏起来")
	assert_ne(patron.skin_material(), other.skin_material(), "每名酒客一份材质")
	await wait_seconds(PatronSkin.FADE_TIME + 0.2)
	assert_almost_eq(float(patron.skin_material().get_shader_parameter("death")), 1.0, 0.01, "出局的人褪成灰色")
	var other_death: Variant = other.skin_material().get_shader_parameter("death")
	assert_true(other_death == null or is_zero_approx(float(other_death)), "别人不受影响")


func test_tail_stays_outside_the_chair():
	# 尾巴的每个顶点都不进入椅面、椅背的包络(座位坐标)
	for i in PatronParts.SPECIES.size():
		var p := Patron.new(i)
		add_child_autofree(p)
		var tail := p.get_node_or_null("Tail") as MeshInstance3D
		if tail == null:
			continue
		var verts: PackedVector3Array = tail.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var inside := 0
		for v in verts:
			var seat_v := tail.transform * v
			var in_seat := absf(seat_v.x) < 0.24 and seat_v.y > 0.42 and seat_v.y < 0.48 and seat_v.z > -0.08 and seat_v.z < 0.36
			var in_back := absf(seat_v.x) < 0.24 and seat_v.y > 0.48 and seat_v.y < 1.1 and seat_v.z > 0.30 and seat_v.z < 0.38
			if in_seat or in_back:
				inside += 1
		assert_eq(inside, 0, "%s 的尾巴不穿过椅子" % PatronParts.species(i)["id"])
