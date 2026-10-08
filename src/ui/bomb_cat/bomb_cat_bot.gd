class_name BombCatBot
extends RefCounted
# 炸弹猫的机器人(调试开关 --bot 与无头流程测试共用):每次 act() 走一步,只通过牌桌的公开入口出手
# (toggle_card / submit_play / choose_target / choose_named / submit_draw / submit_nope / submit_reinsert / submit_give),
# 和真人点按钮、按快捷键是同一条路径。挑牌的办法同 tests/test_bomb_cat_fuzz.gd:随机挑一组合法的出牌。
# 每个反应窗口只掷一次骰子决定要不要「不行!」(不打自己的牌)。


const PLAY_CHANCE := 0.5     # 自己回合里先出一组牌(而不是直接摸牌)的概率
const NOPE_CHANCE := 0.3     # 别人出牌时手里有「不行!」就打的概率

var rng := RandomNumberGenerator.new()
var _window_seen := ""


func _init(seed_value := 0) -> void:
	if seed_value != 0:
		rng.seed = seed_value
	else:
		rng.randomize()


static func legal_plays(hand: Array) -> Array:
	# 手里能打出的组合(私有手牌下标):每张单出的功能牌、两张 / 三张一样的零食
	var options := []
	var by_snack := {}
	for i in hand.size():
		if BombCatCard.is_playable(hand[i]):
			options.append([i])
		elif BombCatCard.is_snack(hand[i]):
			by_snack[hand[i]] = by_snack.get(hand[i], []) + [i]
	for snack in by_snack:
		var at: Array = by_snack[snack]
		if at.size() >= 2:
			options.append(at.slice(0, 2))
		if at.size() >= 3:
			options.append(at.slice(0, 3))
	return options


func act(screen: Node) -> bool:
	# 走一步;这一刻没什么可做时返回 false
	var state: BombCatScreenState = screen.state
	var hud: BombCatHud = screen.hud
	if screen.settlement() != null:
		return false
	if screen.can_reinsert():
		return screen.submit_reinsert(rng.randi_range(0, state.reinsert_max()))
	if screen.can_give():
		var hand := state.private_hand()
		return not hand.is_empty() and screen.submit_give(rng.randi_range(0, hand.size() - 1))
	if state.pub_step() == BombCatScreenState.STEP_WINDOW and screen.can_nope():
		var window: Dictionary = state.pub["window"] if state.pub.get("window") is Dictionary else {}
		var key := str(window)
		if key != _window_seen:
			_window_seen = key
			if window.get("pid") != screen.my_pid and rng.randf() < NOPE_CHANCE:
				return screen.submit_nope()
	if hud != null and hud.prompt_kind == BombCatHud.PROMPT_TARGET:
		var targets := state.target_candidates()
		if targets.is_empty():
			screen.cancel_prompt()
			return true
		return screen.choose_target(targets[rng.randi_range(0, targets.size() - 1)])
	if hud != null and hud.prompt_kind == BombCatHud.PROMPT_NAMED:
		var names := BombCatScreenState.nameable_cards()
		return screen.choose_named(names[rng.randi_range(0, names.size() - 1)])
	if not screen.is_my_turn():
		return false
	var plays := legal_plays(state.private_hand()).filter(func(cards: Array) -> bool:
		var kind := state.selection_kind(cards)
		return not BombCatScreenState.needs_target(kind) or not state.target_candidates().is_empty())
	if not plays.is_empty() and rng.randf() < PLAY_CHANCE:
		screen.clear_selection()
		for i in plays[rng.randi_range(0, plays.size() - 1)]:
			screen.toggle_card(i)
		if screen.submit_play():
			return true
	return screen.submit_draw()
