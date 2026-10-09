extends GutTest
# 筹码堆:金额按面额贪心拆分、每列最多 10 枚、每堆最多显示 40 枚;
# 整摞只用一个 MultiMesh(逐实例颜色)且不投影;所有筹码都落在声明的占地半径内(布局测试据此防重叠)。
# 无头模式的哑渲染器不保存 MultiMesh 的逐实例数据(读回全是 0):摆放与颜色检查纯函数 chips(),
# set_amount 照它写进 MultiMesh,这里只核对可见枚数。


const SAMPLE_STEP := 10
const SAMPLE_MAX := 60000   # 穷举到这个金额:覆盖 5000 面额从 0 到 12 枚的所有组合


func _stack(amount: int) -> ChipStack3D:
	var stack := ChipStack3D.new()
	add_child_autofree(stack)
	stack.set_amount(amount)
	return stack


func _sum(pairs: Array) -> int:
	var total := 0
	for pair in pairs:
		total += pair[0] * pair[1]
	return total


# —— 拆分 ——

func test_breakdown_of_zero_is_empty():
	assert_eq(ChipStack3D.breakdown(0), [])


func test_breakdown_is_greedy_from_the_largest_denomination():
	assert_eq(ChipStack3D.breakdown(1990), [[1000, 1], [500, 1], [100, 4], [50, 1], [10, 4]])


func test_breakdown_of_large_amounts_adds_up():
	for amount in [10, 2000, 16000, 123450, 1000000]:
		assert_eq(_sum(ChipStack3D.breakdown(amount)), amount, "金额 %d" % amount)


func test_columns_hold_at_most_ten_chips_of_one_denomination():
	assert_eq(ChipStack3D.columns(55550), [[5000, 10], [5000, 1], [500, 1], [50, 1]])


func test_columns_never_exceed_the_declared_maximum():
	var amount := 0
	while amount <= SAMPLE_MAX:
		assert_lte(ChipStack3D.columns(amount).size(), ChipStack3D.MAX_COLUMNS, "金额 %d" % amount)
		amount += SAMPLE_STEP
	for amount_big in [1000000, 135990, 299990]:
		assert_lte(ChipStack3D.columns(amount_big).size(), ChipStack3D.MAX_COLUMNS)


# —— 显示 ——

func test_display_is_capped_at_forty_chips():
	var stack := _stack(1000000)
	assert_eq(stack.chip_count(), ChipStack3D.DISPLAY_MAX)
	assert_eq(stack.multimesh().visible_instance_count, ChipStack3D.DISPLAY_MAX)


func test_small_stack_shows_every_chip():
	var stack := _stack(1990)
	assert_eq(stack.chip_count(), 11)
	assert_eq(stack.amount, 1990)


func test_zero_amount_shows_nothing():
	var stack := _stack(1990)
	stack.set_amount(0)
	assert_eq(stack.chip_count(), 0)
	assert_eq(stack.multimesh().visible_instance_count, 0)


func test_whole_stack_is_one_multimesh_without_shadows():
	var stack := _stack(4990)
	var instances := stack.find_children("*", "MultiMeshInstance3D", true, false)
	assert_eq(instances.size(), 1)
	assert_eq(stack.find_children("*", "MeshInstance3D", true, false).size(), 0, "不逐枚建网格")
	assert_eq(instances[0].cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_true(stack.multimesh().use_colors)


func test_stack_shows_exactly_the_laid_out_chips():
	for amount in [10, 1990, 55550, 1000000]:
		assert_eq(_stack(amount).chip_count(), ChipStack3D.chips(amount).size(), "金额 %d" % amount)


func test_each_chip_takes_its_denomination_color():
	var expected := []
	for column in ChipStack3D.columns(1990):
		for i in column[1]:
			expected.append(ChipStack3D.COLORS[column[0]])
	var chips := ChipStack3D.chips(1990)
	assert_eq(chips.size(), expected.size())
	for i in chips.size():
		assert_eq(chips[i]["color"], expected[i], "第 %d 枚" % i)


func test_columns_stand_on_the_base_and_grow_upwards():
	var chips := ChipStack3D.chips(400)   # 一列 4 枚 100
	for i in 4:
		var y: float = chips[i]["transform"].origin.y
		assert_almost_eq(y, ChipStack3D.CHIP_HEIGHT * (i + 0.5), 0.0001)
	assert_almost_eq(_stack(400).top_height(), ChipStack3D.CHIP_HEIGHT * 4, 0.0001)


func test_every_chip_stays_within_the_footprint():
	for amount in [10, 1990, 4990, 135990, 299990, 1000000]:
		var chips := ChipStack3D.chips(amount)
		for i in chips.size():
			var p: Vector3 = chips[i]["transform"].origin
			var reach := Vector2(p.x, p.z).length() + ChipStack3D.CHIP_RADIUS
			assert_lte(reach, ChipStack3D.footprint_radius(), "金额 %d 第 %d 枚" % [amount, i])


func test_same_amount_lays_out_the_same_way_every_time():
	assert_eq(ChipStack3D.chips(4990), ChipStack3D.chips(4990))
