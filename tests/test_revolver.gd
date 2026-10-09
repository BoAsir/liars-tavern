extends GutTest


func test_five_chambers_fifth_pull_is_certain():
	# 五膛左轮装一发:不管子弹在哪一膛,扣满 5 次正好中 1 次
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 50:
		var revolver := Revolver.new(rng)
		assert_between(revolver.bullet_chamber, 1, 5)
		var hits := 0
		for pull in 5:
			if revolver.pull_trigger():
				hits += 1
		assert_eq(hits, 1)


func test_shots_fired_counts_pulls():
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var revolver := Revolver.new(rng)
	assert_eq(revolver.shots_fired(), 0)
	revolver.pull_trigger()
	assert_eq(revolver.shots_fired(), 1)


func test_bullet_in_chamber_one_hits_immediately():
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var revolver := Revolver.new(rng)
	revolver.bullet_chamber = 1
	revolver.next_chamber = 1
	assert_true(revolver.pull_trigger())
