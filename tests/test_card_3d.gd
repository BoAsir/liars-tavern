extends GutTest
# 卡牌牌体(子项目③ §3):一片共享的圆角薄片网格 + 一份共享材质,牌型、两面、光晕都是实例参数;
# 德州牌每张一份材质(正面单张贴图);射线拾取仍按 y=0 平面求交。


func before_each():
	Card3D.clear_materials()


func after_all():
	Card3D.clear_materials()


func _slab(card: Card3D) -> MeshInstance3D:
	var meshes := card.find_children("*", "MeshInstance3D", true, false)
	assert_eq(meshes.size(), 1, "每张牌 1 个网格实例")
	return meshes[0]


func test_card_is_one_shared_slab():
	var a: Card3D = add_child_autofree(Card3D.new())
	var b: Card3D = add_child_autofree(Card3D.new())
	b.set_kind(Card.ACE)
	assert_same(_slab(a).mesh, _slab(b).mesh, "共享网格")
	assert_same(_slab(a).material_override, _slab(b).material_override, "骗子酒馆的牌共享一份材质")
	var box := _slab(a).mesh.get_aabb()
	assert_almost_eq(box.size.x, Card3D.WIDTH, 0.0001)
	assert_almost_eq(box.size.z, Card3D.HEIGHT, 0.0001)
	assert_almost_eq(box.size.y, Card3D.THICKNESS, 0.0001)
	assert_lte(Card3D.THICKNESS, 0.0009)
	assert_almost_eq(box.get_center().y, 0.0, 0.00001, "以 y=0 为中面")
	assert_lte(_slab(a).mesh.get_faces().size() / 3, 160, "三角形")
	assert_ne(_slab(a).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "牌投影")


func test_slab_faces_point_the_right_way():
	# 正面朝 +Y、背面朝 −Y:按绕序算出的面法线与顶点法线同向(Godot 正面是顺时针)
	var mesh := Card3D.slab_mesh()
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var agree := 0
	var total := 0
	for k in range(0, idx.size(), 3):
		var face := (v[idx[k + 2]] - v[idx[k]]).cross(v[idx[k + 1]] - v[idx[k]])
		if face.length() < 1e-12:
			continue
		total += 1
		if face.dot(n[idx[k]]) > 0.0:
			agree += 1
	assert_eq(agree, total, "每个三角形的绕序都和法线一致")


func test_kind_and_both_faces_are_instance_params():
	var card: Card3D = add_child_autofree(Card3D.new())
	var slab := _slab(card)
	var unset = slab.get_instance_shader_parameter("face")
	assert_true(unset == null or int(unset) == 0, "新牌不设参数时是牌背层(着色器默认 0)")
	card.set_kind(Card.KING)
	assert_eq(int(slab.get_instance_shader_parameter("face")), CardFaces.layer(Card.KING))
	assert_eq(CardFaces.layer(Card.KING), CardFaces.LAYERS.find(Card.KING))
	card.set_both_faces(Card.JOKER)
	assert_eq(int(slab.get_instance_shader_parameter("face")), CardFaces.layer(Card.JOKER))
	assert_eq(float(slab.get_instance_shader_parameter("both_faces")), 1.0)
	card.set_glow(0.5)
	assert_eq(float(slab.get_instance_shader_parameter("glow")), 0.5)


func test_poker_cards_get_their_own_face_material():
	var card: Card3D = add_child_autofree(Card3D.new())
	var value := PokerCard.make(PokerCard.ACE, PokerCard.SPADES)
	card.set_kind(value)
	var mat: ShaderMaterial = _slab(card).material_override
	assert_same(mat, Card3D.material_for(value))
	assert_true(mat.get_shader_parameter("single_face"))
	assert_same(mat.get_shader_parameter("card_texture"), CardFaces.texture(value))
	assert_not_same(mat, Card3D.material_for(CardFaces.BACK), "和骗子酒馆的共享材质分开")


func test_ray_hits_the_center_and_misses_past_the_edge():
	var card: Card3D = add_child_autofree(Card3D.new())
	card.global_transform = Transform3D(Basis(), Vector3(0, 1, 0))
	assert_almost_eq(card.ray_hit_distance(Vector3(0, 2, 0), Vector3.DOWN), 1.0, 0.0001, "中心命中")
	assert_eq(card.ray_hit_distance(Vector3(Card3D.WIDTH * 0.6, 2, 0), Vector3.DOWN), -1.0, "牌边外不命中")
