extends GutTest
# 快捷对话(类似炉石的表情):文案(用户审过的 9 条)、编号校验,房主端的限速。


func test_the_nine_reviewed_lines():
	assert_eq(Quips.LINES, ["你好呀!", "打得不错", "谢谢", "我很抱歉", "哇哦!", "哎呀……",
		"快点吧,我等到花儿都谢了", "给阿姨倒一杯卡布奇诺", "17 张牌你能秒我?"])


func test_lines_have_no_suit_or_emoji_glyphs():
	# 界面字体里没有花色与 emoji 字形(德州规格 §6.1)
	for line: String in Quips.LINES:
		for ch in ["♠", "♥", "♦", "♣"]:
			assert_false(line.contains(ch), line)
		for i in line.length():
			assert_lt(line.unicode_at(i), 0x1F000, line)


func test_index_validation_takes_untrusted_values():
	assert_true(Quips.is_valid(0))
	assert_true(Quips.is_valid(8))
	assert_false(Quips.is_valid(9))
	assert_false(Quips.is_valid(-1))
	assert_false(Quips.is_valid("1"))
	assert_false(Quips.is_valid(1.0))
	assert_false(Quips.is_valid(null))
	assert_eq(Quips.text(2), "谢谢")
	assert_eq(Quips.text(42), "")


func test_gate_limits_each_player_separately():
	var gate := QuipGate.new()
	assert_true(gate.accept(10, 1000))
	assert_false(gate.accept(10, 1000 + QuipGate.MIN_INTERVAL_MS - 1), "冷却中")
	assert_true(gate.accept(11, 1001), "别人不受影响")
	assert_true(gate.accept(10, 1000 + QuipGate.MIN_INTERVAL_MS))
	gate.forget(10)
	assert_true(gate.accept(10, 1000 + QuipGate.MIN_INTERVAL_MS + 1), "离开后重来不留旧记录")


func test_gate_interval_tolerates_network_jitter():
	# 客户端按 Quips.COOLDOWN 本地冷却;房主放宽一点,前后两条到达的间隔被网络抖动压短也不误拒
	assert_lt(QuipGate.MIN_INTERVAL_MS, int(Quips.COOLDOWN * 1000.0))
	assert_gt(QuipGate.MIN_INTERVAL_MS, int(Quips.COOLDOWN * 500.0))
