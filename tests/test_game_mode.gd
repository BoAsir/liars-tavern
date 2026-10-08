extends GutTest
# 玩法常量:id 校验(来自不可信报文)、德州判定、人数上限、中途加入、桌子尺寸。


func test_known_modes_are_valid():
	for mode in GameMode.ALL:
		assert_true(GameMode.is_valid(mode), mode)


func test_untrusted_values_are_not_valid_modes():
	for value in ["", "poker", "LIARS", 1, null, [GameMode.HOLDEM], {"mode": GameMode.HOLDEM}]:
		assert_false(GameMode.is_valid(value), str(value))


func test_default_mode_is_the_original_game():
	assert_eq(GameMode.DEFAULT, GameMode.LIARS)
	assert_true(GameMode.is_valid(GameMode.DEFAULT))


func test_poker_modes():
	assert_false(GameMode.is_poker(GameMode.LIARS))
	assert_true(GameMode.is_poker(GameMode.HOLDEM))
	assert_true(GameMode.is_poker(GameMode.SHORT_DECK))
	assert_true(GameMode.is_short_deck(GameMode.SHORT_DECK))
	assert_false(GameMode.is_short_deck(GameMode.HOLDEM))


func test_player_caps_per_mode():
	assert_eq(GameMode.max_players(GameMode.LIARS), 4)
	assert_eq(GameMode.max_players(GameMode.HOLDEM), 8)
	assert_eq(GameMode.max_players(GameMode.SHORT_DECK), 8)
	for mode in GameMode.ALL:
		assert_eq(GameMode.min_players(mode), 2)


func test_liars_deck_fits_the_liars_cap():
	assert_lte(GameMode.max_players(GameMode.LIARS) * Deck.HAND_SIZE, Deck.build().size())


func test_only_poker_allows_late_join():
	assert_false(GameMode.allows_late_join(GameMode.LIARS))
	assert_true(GameMode.allows_late_join(GameMode.HOLDEM))
	assert_true(GameMode.allows_late_join(GameMode.SHORT_DECK))


func test_labels():
	assert_eq(GameMode.label(GameMode.LIARS), "骗子酒馆")
	assert_eq(GameMode.label(GameMode.HOLDEM), "德州扑克·长牌")
	assert_eq(GameMode.short_label(GameMode.SHORT_DECK), "德州·短牌")
	assert_eq(GameMode.label("bogus"), GameMode.UNKNOWN_LABEL)


func test_summary_names_the_mode_and_its_player_range():
	# 等待厅标题下一行、主菜单玩法按钮的提示
	assert_eq(GameMode.summary(GameMode.SHORT_DECK), "德州扑克·短牌 · 2–8 人")
	assert_eq(GameMode.summary(GameMode.HOLDEM), "德州扑克·长牌 · 2–8 人")
	assert_eq(GameMode.summary(GameMode.LIARS), "骗子酒馆 · 2–4 人")


func test_poker_table_is_bigger_and_keeps_the_seat_gap():
	assert_eq(SeatLayout.table_radius_for(GameMode.LIARS), SeatLayout.TABLE_RADIUS)
	assert_gt(SeatLayout.table_radius_for(GameMode.HOLDEM), SeatLayout.TABLE_RADIUS)
	assert_eq(SeatLayout.table_radius_for(GameMode.SHORT_DECK), SeatLayout.POKER_TABLE_RADIUS)
	assert_almost_eq(SeatLayout.seat_radius_for(SeatLayout.TABLE_RADIUS), SeatLayout.SEAT_RADIUS, 0.0001)
	var poker := SeatLayout.POKER_TABLE_RADIUS
	assert_almost_eq(SeatLayout.seat_radius_for(poker) - poker, SeatLayout.SEAT_RADIUS - SeatLayout.TABLE_RADIUS, 0.0001)
