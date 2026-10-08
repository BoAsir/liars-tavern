extends GutTest
# 房间的运行时贴图(无头):SurfaceNoise 回退 4×4 灰、倍频周期;DecorAtlas 回退纸色、区域表、通缉令与赏金文案。


func after_all():
	# 换过贴图之后,材质缓存与合批网格缓存一起重建:网格的 surface 上挂着旧材质,别的测试按身份比较材质
	WorldMaterials.clear_cache()
	MeshForge.clear_cache()


func test_surface_noise_falls_back_to_mid_grey_headless():
	SurfaceNoise.clear()
	var tex := SurfaceNoise.texture()
	assert_not_null(tex)
	assert_eq(tex.get_width(), 4)
	var image := tex.get_image()
	assert_almost_eq(image.get_pixel(1, 2).r, 0.5, 0.01)
	assert_almost_eq(image.get_pixel(3, 0).b, 0.5, 0.01)
	assert_same(SurfaceNoise.texture(), tex, "始终是同一份贴图:烘好后原地换图,材质不用重新绑定")


func test_surface_noise_octaves_double_exactly_so_the_tile_wraps():
	for k in SurfaceNoise.OCTAVES:
		assert_eq(SurfaceNoise.period_for_octave(k), 16 * int(pow(2, k)))


func test_build_and_clear_headless():
	await RoomTextures.build(self)
	assert_true(RoomTextures.is_built())
	assert_true(SurfaceNoise.is_built() and DecorAtlas.is_built())
	var noise := SurfaceNoise.texture()
	RoomTextures.clear()
	assert_false(SurfaceNoise.is_built())
	assert_false(DecorAtlas.is_built())
	assert_not_same(SurfaceNoise.texture(), noise, "clear 之后重新建")
	WorldMaterials.clear_cache()   # 已建的材质还绑着旧贴图(游戏里只在退出时 clear)
	MeshForge.clear_cache()


func test_materials_bind_the_shared_textures():
	assert_same(WorldMaterials.wood("floor").get_shader_parameter("surface_noise"), SurfaceNoise.texture())
	assert_same(WorldMaterials.stone("plaster").get_shader_parameter("surface_noise"), SurfaceNoise.texture())
	assert_same(WorldMaterials.decor().get_shader_parameter("atlas"), DecorAtlas.texture())


func test_atlas_falls_back_to_parchment_headless():
	var tex := DecorAtlas.texture()
	assert_not_null(tex)
	assert_eq(tex.get_width(), 8)


func test_atlas_rects_are_normalised_and_do_not_overlap():
	var ids := DecorAtlas.all_ids()
	var posters := ids.filter(func(id): return id.begins_with("poster"))
	assert_eq(posters.size(), Species.count(), "每个物种一张通缉令")
	var rects := []
	for id in ids:
		var r := DecorAtlas.rect(id)
		assert_true(r.position.x >= 0.0 and r.position.y >= 0.0 and r.end.x <= 1.0 + 1e-6 and r.end.y <= 1.0 + 1e-6, "%s 在 [0,1] 内" % id)
		for other in rects:
			assert_false(r.intersects(other[1]), "%s 与 %s 不重叠" % [id, other[0]])
		rects.append([id, r])


func test_every_species_has_a_joke_bounty_without_money():
	var money := RegEx.create_from_string("[0-9$¥€£]")
	for id in Species.IDS:
		assert_true(DecorAtlas.BOUNTIES.has(id), "%s 有赏金文案" % id)
		for line: String in DecorAtlas.bounty(id):
			assert_null(money.search(line), "%s 的赏金没有数字或货币符号:%s" % [id, line])
			assert_false(line.contains("筹码") or line.to_lower().contains("chip"), "%s 的赏金不提筹码" % id)
	assert_eq(DecorAtlas.bounty("dragon"), DecorAtlas.BOUNTY_FALLBACK, "不认识的物种用回退文案")


func test_every_species_has_a_poster_drawing():
	# 通缉令头像按物种 id 分画法;每个物种都要有(未知物种走通用画法并告警)
	var source := (load("res://src/world/room/decor_atlas.gd") as GDScript).source_code
	for id in Species.IDS:
		assert_true(source.contains('"%s":' % id), "通缉令有 %s 的画法" % id)
