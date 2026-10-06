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
