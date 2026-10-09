class_name LobbyModel
# 等待厅名单(仅房主持有):加入校验、准备状态、开局条件。座位顺序 = 加入顺序。


const HOST_ID := 1
const DEFAULT_NAME := "酒客"
const IN_GAME_REASON := "游戏已开始,请等这一局结束"
const WINDING_DOWN_REASON := "牌局正在散局,请稍后再来"

var _order: Array = []
var _members := {}  # peer_id -> {"name": String, "ready": bool}


func add_host(host_name: String) -> void:
	_order = []
	_members = {}
	_insert(HOST_ID, host_name, true)


func check_join(version: int, in_game: bool, mode: String, accepting_late: bool) -> String:
	# 返回空串表示允许加入,否则为拒绝原因。判定顺序固定:
	# ① 版本必须最先判断:主菜单靠「版本」字样去问房主要更新,对局中、满员的房间也得先报这个;
	# ② 已开局时只有正在接受中途入座的德州牌局能进(散局中或已结算的德州另有文案);
	# ③ 人数按玩法上限,只数已完成握手、仍连着的等待厅成员
	if version != Protocol.VERSION:
		return "版本不匹配(房主 v%d / 你 v%d),请更新游戏" % [Protocol.VERSION, version]
	if in_game and not accepting_late:
		return WINDING_DOWN_REASON if GameMode.allows_late_join(mode) else IN_GAME_REASON
	var cap := GameMode.max_players(mode)
	if _members.size() >= cap:
		return "房间已满(%d/%d)" % [_members.size(), cap]
	return ""


func add_member(id: int, raw_name: String) -> void:
	_insert(id, raw_name, false)


func remove(id: int) -> bool:
	if id == HOST_ID or not _members.has(id):
		return false
	_members.erase(id)
	_order.erase(id)
	return true


func has(id: int) -> bool:
	return _members.has(id)


func size() -> int:
	return _members.size()


func set_ready(id: int, ready: bool) -> bool:
	if id == HOST_ID or not _members.has(id):
		return false
	_members[id]["ready"] = ready
	return true


func reset_ready() -> void:
	for id in _members:
		_members[id]["ready"] = id == HOST_ID


func can_start() -> bool:
	if _members.size() < Protocol.MIN_PLAYERS:
		return false
	for id in _members:
		if not _members[id]["ready"]:
			return false
	return true


func seat_order() -> Array:
	return _order.duplicate()


func names() -> Dictionary:
	var out := {}
	for id in _order:
		out[id] = _members[id]["name"]
	return out


func view() -> Array:
	var out := []
	for id in _order:
		out.append({
			"pid": id,
			"name": _members[id]["name"],
			"ready": _members[id]["ready"],
			"is_host": id == HOST_ID,
		})
	return out


func _insert(id: int, raw_name: String, ready: bool) -> void:
	_members[id] = {"name": _unique_name(raw_name), "ready": ready}
	_order.append(id)


func _unique_name(raw_name: String) -> String:
	var base := Protocol.sanitize_name(raw_name)
	if base == "":
		base = "%s %d" % [DEFAULT_NAME, _order.size() + 1]
	var taken := {}
	for id in _members:
		taken[_members[id]["name"]] = true
	if not taken.has(base):
		return base
	var n := 2
	while taken.has("%s %d" % [base, n]):
		n += 1
	return "%s %d" % [base, n]
