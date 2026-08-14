extends GutTest


func test_play_must_be_one_to_three_cards():
	assert_false(Rules.is_play_valid(5, []))
	assert_true(Rules.is_play_valid(5, [0]))
	assert_true(Rules.is_play_valid(5, [0, 2, 4]))
	assert_false(Rules.is_play_valid(5, [0, 1, 2, 3]))


func test_play_indices_must_be_in_hand_and_unique():
	assert_false(Rules.is_play_valid(5, [-1]))
	assert_false(Rules.is_play_valid(5, [5]))
	assert_false(Rules.is_play_valid(5, [1, 1]))
	assert_false(Rules.is_play_valid(5, [1.5]))
	assert_true(Rules.is_play_valid(2, [0, 1]))


func test_honesty_all_target_or_joker():
	assert_true(Rules.is_honest([Card.QUEEN, Card.QUEEN], Card.QUEEN))
	assert_true(Rules.is_honest([Card.QUEEN, Card.JOKER], Card.QUEEN))
	assert_true(Rules.is_honest([Card.JOKER, Card.JOKER], Card.ACE))
	assert_false(Rules.is_honest([Card.QUEEN, Card.KING], Card.QUEEN))
	assert_false(Rules.is_honest([Card.KING], Card.QUEEN))
