extends GutTest
# RPC 编号冻结(德州规格 §3.3):Godot 按方法名排序给 RPC 编号。握手用到的编号、参数与 @rpc 模式一变,
# 旧版本连上来就收不到「版本不匹配」的明确拒绝,也就不会去从房主那里更新。
# 跨版本连接时引擎报的 checksum 错误属预期,不是这里要防的。


const NETWORK_MANAGER := "res://src/net/network_manager.gd"
# 排序后下标 0–7 的 RPC:不得增删改名;新 RPC 的名字必须排在 rpc_join_request 之后
const FROZEN_NAMES := [
	"rpc_game_events", "rpc_game_started", "rpc_intent_challenge", "rpc_intent_play",
	"rpc_intent_rejected", "rpc_join_accepted", "rpc_join_denied", "rpc_join_request",
]


func _script() -> Script:
	return load(NETWORK_MANAGER) as Script


func _rpc_config() -> Dictionary:
	return _script().get_rpc_config()


func _sorted_rpc_names() -> Array:
	var names := _rpc_config().keys().map(func(key) -> String: return String(key))
	names.sort()
	return names


func _arg_types(method: String) -> Array:
	for info in _script().get_script_method_list():
		if info["name"] == method:
			return info["args"].map(func(arg: Dictionary) -> int: return arg["type"])
	return []


func test_first_eight_rpc_ids_are_frozen():
	assert_eq(_sorted_rpc_names().slice(0, FROZEN_NAMES.size()), FROZEN_NAMES)


func test_new_rpcs_sort_after_the_join_request():
	for method: String in _sorted_rpc_names().slice(FROZEN_NAMES.size()):
		assert_true(method > "rpc_join_request", method)


func test_handshake_parameters_are_frozen():
	assert_eq(_arg_types("rpc_join_request"), [TYPE_STRING, TYPE_INT], "rpc_join_request(pname: String, version: int)")
	assert_eq(_arg_types("rpc_join_denied"), [TYPE_STRING], "rpc_join_denied(reason: String)")


func test_handshake_rpc_modes_are_frozen():
	var config := _rpc_config()
	var request: Dictionary = config["rpc_join_request"]
	assert_eq(request["rpc_mode"], MultiplayerAPI.RPC_MODE_ANY_PEER)
	assert_eq(request["transfer_mode"], MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	assert_false(request["call_local"])
	assert_eq(request.get("channel", 0), 0)
	var denied: Dictionary = config["rpc_join_denied"]
	assert_eq(denied["rpc_mode"], MultiplayerAPI.RPC_MODE_AUTHORITY)
	assert_eq(denied["transfer_mode"], MultiplayerPeer.TRANSFER_MODE_RELIABLE)
	assert_false(denied["call_local"])
	assert_eq(denied.get("channel", 0), 0)
