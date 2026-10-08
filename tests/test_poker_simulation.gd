extends GutTest
# 随机模拟(规格 §8):固定 8 个种子 × 150 手,开局 2–8 人,长短牌各半;每一步随机合法动作,
# 穿插随机再领、观战、离座回来、加入、离开、超时与该被拒绝的意图(模拟器见 poker_sim.gd,不变量见 poker_sim_checks.gd)。
# 更长的浸泡在 soak_poker_simulation.gd 里:文件名不以 test_ 开头,全量测试不跑,只在命令行点名时跑(见那个文件)。

const Sim := preload("res://tests/poker_sim.gd")
const SEEDS := [3, 14, 15, 92, 65, 35, 89, 79]
const HANDS_PER_SEED := 150
const TIME_BUDGET_MSEC := 10000

# 模拟必须真的走到这些情形,否则「没出错」说明不了什么
const MUST_COVER := [
	"hand_started", "turn", "street", "bets_collected", "refund", "side_pots", "reveal_allin", "reveal_showdown",
	"pot_won", "split", "uncontested", "hand_over", "timeout", "away", "sit_in", "rebuy", "spectate",
	"player_joined", "player_left", "session_over", "rejected",
]


func test_random_hands_keep_every_invariant():
	var started := Time.get_ticks_msec()
	var covered := {}
	for i in SEEDS.size():
		var sim := Sim.new(SEEDS[i], i)
		var error: String = sim.run(HANDS_PER_SEED)
		assert_eq(error, "", "随机模拟出错")
		if error != "":
			return
		covered.merge(sim.stats)
	var elapsed := Time.get_ticks_msec() - started
	assert_lt(elapsed, TIME_BUDGET_MSEC, "%d 个种子 × %d 手应在 10 秒内跑完" % [SEEDS.size(), HANDS_PER_SEED])
	for key in MUST_COVER:
		assert_true(covered.has(key), "模拟没有走到:" + key)
