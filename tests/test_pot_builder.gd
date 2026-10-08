extends GutTest
# 边池、未跟注退回与分池(规格 §2.4 退回、§2.5 底池)。

const A := 1
const B := 2
const C := 3
const D := 4
const ORDER := [A, B, C, D]


func _pot(amount: int, eligible: Array) -> Dictionary:
	return {"amount": amount, "eligible": eligible}


# —— build ——

func test_equal_contributions_make_one_pot():
	assert_eq(PotBuilder.build({A: 100, B: 100, C: 100}, {}, ORDER), [_pot(300, [A, B, C])])


func test_short_all_in_creates_a_side_pot():
	var pots := PotBuilder.build({A: 50, B: 200, C: 200}, {}, ORDER)
	assert_eq(pots, [_pot(150, [A, B, C]), _pot(300, [B, C])])


func test_folded_money_is_dead_but_stays_in_the_pot():
	assert_eq(PotBuilder.build({A: 100, B: 300, C: 300}, {A: true}, ORDER), [_pot(700, [B, C])])


func test_two_all_ins_make_three_layers():
	var pots := PotBuilder.build({A: 50, B: 120, C: 300, D: 300}, {}, ORDER)
	assert_eq(pots, [_pot(200, [A, B, C, D]), _pot(210, [B, C, D]), _pot(360, [C, D])])


func test_layer_without_eligible_players_merges_into_the_pot_below():
	# X 下 500 后离开(弃牌)、Y 全下 200、Z 全下 300:300–500 那层只有 X 的死钱,并入 Z 的边池
	var x := 7
	var y := 8
	var z := 9
	var pots := PotBuilder.build({x: 500, y: 200, z: 300}, {x: true}, [x, y, z])
	assert_eq(pots, [_pot(600, [y, z]), _pot(400, [z])])


func test_adjacent_layers_with_the_same_eligible_players_merge():
	# A 弃牌时投入 80,夹在中间也不会把 B/C 的底池切成两层
	assert_eq(PotBuilder.build({A: 80, B: 200, C: 200}, {A: true}, ORDER), [_pot(480, [B, C])])


func test_eligible_lists_follow_seat_order_and_skip_zero_contributions():
	var pots := PotBuilder.build({C: 100, A: 100, D: 0, B: 40}, {B: true}, ORDER)
	assert_eq(pots, [_pot(240, [A, C])])
	assert_eq(PotBuilder.build({}, {}, ORDER), [])


func test_total_is_always_preserved():
	var committed := {A: 30, B: 470, C: 250, D: 90}
	var pots := PotBuilder.build(committed, {B: true, D: true}, ORDER)
	var total := 0
	for pot in pots:
		total += pot["amount"]
		assert_false(pot["eligible"].is_empty())
	assert_eq(total, 840)


func test_when_no_live_player_contributed_the_pot_goes_to_the_live_players():
	# 极端断线:还没行动的人之外全都离开了,他一分没投也拿得走这些死钱
	assert_eq(PotBuilder.build({A: 0, B: 10, C: 20}, {B: true, C: true}, ORDER), [_pot(30, [A])])


# —— uncalled ——

func test_uncalled_refund_goes_down_to_the_second_highest_bet_including_folded():
	# X 下注 300、Y 全下跟 100、Z 加注到 900、X 弃牌 → Z 退 600(不是 800)
	assert_eq(PotBuilder.uncalled({A: 300, B: 100, C: 900}), {"pid": C, "amount": 600})


func test_no_refund_when_the_top_bet_is_matched():
	assert_eq(PotBuilder.uncalled({A: 300, B: 300, C: 100}), {})
	assert_eq(PotBuilder.uncalled({}), {})
	assert_eq(PotBuilder.uncalled({A: 0, B: 0}), {})


func test_lone_bet_is_refunded_in_full():
	assert_eq(PotBuilder.uncalled({A: 40, B: 0}), {"pid": A, "amount": 40})
	assert_eq(PotBuilder.uncalled({A: 10, B: 20}), {"pid": B, "amount": 10}, "全员弃牌给大盲:退回小盲之上的 10")


# —— split ——

func test_split_gives_the_odd_chip_to_the_first_winner_after_the_button():
	assert_eq(PotBuilder.split(30, [A, B], 10), {A: 20, B: 10})
	assert_eq(PotBuilder.split(30, [B, A], 10), {B: 20, A: 10})
	assert_eq(PotBuilder.split(70, [A, B, C], 10), {A: 30, B: 20, C: 20})


func test_split_even_and_single_winner():
	assert_eq(PotBuilder.split(40, [A, B], 10), {A: 20, B: 20})
	assert_eq(PotBuilder.split(1230, [C], 10), {C: 1230})
