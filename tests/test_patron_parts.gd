extends GutTest
# 物种分配:新酒客取第一个没人用的物种,同桌不撞脸。


func test_first_free_species_starts_from_zero():
	assert_eq(PatronParts.first_free_species([]), 0)


func test_first_free_species_fills_the_gap_left_by_a_leaver():
	assert_eq(PatronParts.first_free_species([0, 2]), 1)
	assert_eq(PatronParts.first_free_species([1, 0, 3]), 2)


func test_first_free_species_wraps_only_when_every_species_is_taken():
	var all := range(PatronParts.SPECIES.size())
	assert_eq(PatronParts.first_free_species(all), 0)
	assert_eq(PatronParts.first_free_species(all + [0]), 1)


func test_palettes_are_capped_so_faces_do_not_wash_out():
	# 近白的底色在烛光 + ACES 下会过曝发白:所有酒客颜色按最大通道等比压到 ALBEDO_CAP 以下(保持色相)
	for i in PatronParts.SPECIES.size():
		var pal := PatronParts.palette(PatronParts.species(i))
		for key in ["fur", "muzzle", "dark", "coat", "accent", "hat", "lapel", "paw"]:
			var c: Color = pal[key][0]
			assert_lte(maxf(c.r, maxf(c.g, c.b)), PatronParts.ALBEDO_CAP + 0.0001, "%d %s" % [i, key])


func test_capping_keeps_the_hue():
	var pig := PatronParts.palette(PatronParts.species(2))
	var raw: Color = PatronParts.SPECIES[2]["fur"]
	var capped: Color = pig["fur"][0]
	assert_almost_eq(capped.r / capped.g, raw.r / raw.g, 0.01)


func test_eye_white_and_paw_shade_limits():
	for channel in [PatronParts.EYE_WHITE.r, PatronParts.EYE_WHITE.g, PatronParts.EYE_WHITE.b]:
		assert_lte(channel, 0.72)
	assert_gt(PatronParts.PAW_SHADE, 0.0)
	assert_lte(PatronParts.PAW_SHADE, 0.8)
