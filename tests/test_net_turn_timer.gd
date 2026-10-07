extends GutTest
# 房主回合计时的真实接线(不是 Pacing 的纯函数):开局预算含开场运镜、断线只顺延不重置、剩余时间进公共状态。
# 用一个离线的 NetworkManager 实例(不是 Net 自动加载):没有对端时 _is_connected 全为 false,不会真的发 RPC。


const NetworkManagerScript := preload("res://src/net/network_manager.gd")
const EPS := 0.05

var net: Node


func before_each():
	net = NetworkManagerScript.new()
	add_child_autofree(net)  # _ready 里创建计时器
	net.is_host = true
	net._session_active = true
	var lobby := LobbyModel.new()
	lobby.add_host("房主")
	for id in [10, 11]:
		lobby.add_member(id, "客%d" % id)
		lobby.set_ready(id, true)
	net._lobby = lobby


func _guest_not_on_turn() -> int:
	for pid in [10, 11]:
		if net._gs.current_pid != pid:
			return pid
	return 10


func test_first_turn_budget_includes_intro_and_round_started():
	net.start_game()
	var expected := Protocol.TURN_TIMEOUT + Pacing.INTRO + Pacing.ROUND_STARTED
	assert_almost_eq(net._turn_timer.time_left, expected, EPS)
	assert_almost_eq(net.last_public["turn_time_left"], expected, EPS, "公共状态里的剩余时间要和刚起的计时器一致")


func test_bystander_disconnect_extends_instead_of_resetting():
	net.start_game()
	var before: float = net._turn_timer.time_left
	net._on_peer_disconnected(_guest_not_on_turn())
	assert_almost_eq(net._turn_timer.time_left, before + Pacing.ELIMINATED, EPS,
		"非当前玩家断线只补上出局演出,不能把当前玩家的时间重置")
	assert_almost_eq(net.last_public["turn_time_left"], net._turn_timer.time_left, EPS)


func test_accepted_action_restarts_a_full_turn_from_the_batch_budget():
	net.start_game()
	var actor: int = net._gs.current_pid
	net._handle_intent(actor, "play", [0])
	var events := [{"type": "played", "pid": actor, "count": 1}, {"type": "turn", "pid": 0}]
	assert_almost_eq(net._turn_timer.time_left, Protocol.TURN_TIMEOUT + Pacing.estimate(events), EPS,
		"玩家行动后开场运镜的欠账已清零,新回合 = 30 秒 + 本批演出")


func test_leave_resets_timer_and_public_time():
	net.start_game()
	net.leave()
	assert_true(net._turn_timer.is_stopped())
	assert_eq(net._anim_left, 0.0)
