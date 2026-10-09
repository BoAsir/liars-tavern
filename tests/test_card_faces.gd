extends GutTest
# 牌面纹理(子项目③ §3):牌背弹巢孔数 = 膛数;无头构建也绑定 5 层的牌面与烫金数组纹理;clear 释放数组。


var host: Node


func before_each():
	host = add_child_autofree(Node.new())
	CardFaces.clear()
	Card3D.clear_materials()


func after_all():
	CardFaces.clear()
	Card3D.clear_materials()


func test_back_has_one_hole_per_chamber():
	var points := CardFaces.chamber_points(Vector2(10, 20), 44.0)
	assert_eq(points.size(), Revolver.CHAMBERS)
	assert_almost_eq(points[0], Vector2(10, 20 - 44.0), Vector2.ONE * 0.0001, "第一个孔在正上方")


func test_headless_build_binds_arrays():
	await CardFaces.build(host)
	assert_eq(CardFaces.face_array().get_layers(), CardFaces.LAYERS.size())
	assert_eq(CardFaces.foil_array().get_layers(), CardFaces.LAYERS.size())
	var card: Card3D = add_child_autofree(Card3D.new())
	var mat: ShaderMaterial = card.find_children("*", "MeshInstance3D", true, false)[0].material_override
	Card3D.refresh_materials()
	assert_same(mat.get_shader_parameter("faces"), CardFaces.face_array())
	assert_same(mat.get_shader_parameter("foil"), CardFaces.foil_array())
	for kind in CardFaces.LAYERS:
		assert_true(CardFaces.texture(kind) is Texture2D, "2D 界面仍用单张贴图")


func test_clear_releases_the_arrays():
	var faces := CardFaces.face_array()
	var foil := CardFaces.foil_array()
	CardFaces.clear()
	assert_not_same(CardFaces.face_array(), faces, "换回新的替代图")
	assert_not_same(CardFaces.foil_array(), foil)
	assert_eq(CardFaces.face_array().get_width(), CardFaces.FALLBACK_SIZE)
