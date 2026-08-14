extends GutTest


func test_exactly_one_hit_in_six_pulls():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 20:
		var revolver := Revolver.new(rng)
		var hits := 0
		for pull in 6:
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
