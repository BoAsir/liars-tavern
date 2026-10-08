class_name LiarsSession
extends GameSession
# 骗子酒馆会话:原样搬走 NetworkManager 里 GameState / Views / Pacing 的用法,行为零变化。
# 超时代打手牌第一张;断线即出局;没有下一手、不收中途加入的人。


const TIMEOUT_PLAY := [0]   # 超时代打:手牌第一张

var _gs: GameState = null
var _names := {}


func start(seat_order: Array, names: Dictionary, rng: RandomNumberGenerator) -> Array:
	_names = names.duplicate()
	_gs = GameState.new()
	_gs.start_match(seat_order, rng)
	return [_gs.round_started_event()]


func handle_intent(pid: int, intent: Dictionary) -> Dictionary:
	# 不属于本玩法的 kind、缺字段或字段类型不对一律 invalid_play(意图来自不可信对端)
	var kind: Variant = intent.get("kind")
	if not kind is String:
		return rejected(Protocol.ERR_INVALID_PLAY)
	var result: Dictionary
	if kind == "play" and intent.get("indices") is Array:
		result = _gs.play_cards(pid, intent["indices"])
	elif kind == "challenge":
		result = _gs.challenge(pid)
	else:
		return rejected(Protocol.ERR_INVALID_PLAY)
	if not result["ok"]:
		return rejected(result["error"])
	return accepted(result["events"], true)


func on_disconnect(pid: int) -> Array:
	return _gs.eliminate_player(pid)


func on_turn_timeout() -> Dictionary:
	return handle_intent(_gs.current_pid, {"kind": "play", "indices": TIMEOUT_PLAY})


func public_view(turn_time_left: float) -> Dictionary:
	return Views.public_state(_gs, _names, turn_time_left)


func private_view(pid: int) -> Dictionary:
	return Views.private_state(_gs, pid)


func viewers() -> Array:
	return _gs.seat_order.duplicate()


func is_over() -> bool:
	return _gs.phase == GameState.Phase.MATCH_OVER


func has_turn() -> bool:
	return _gs.phase == GameState.Phase.PLAYING and _gs.current_pid != null


func estimate(events: Array) -> float:
	return Pacing.estimate(events)


func turn_timer_after(events: Array, pending: float, time_left: float) -> float:
	return Pacing.turn_timer_after(events, pending, time_left)


func seats_with_patrons() -> Array:
	return _gs.seat_order.duplicate() if _gs != null else []


func name_of(pid: int) -> String:
	return _names.get(pid, str(pid))
