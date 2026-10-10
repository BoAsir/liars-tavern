extends GutTest
# 德州牌桌无头流程测试的公共装置:假 app(TableWorld + 标签层 + 镜头)、按字典生成的假视图、喂事件并等演出播完。
# 用法:测试脚本 extends 本文件;它不以 test_ 开头,GUT 不会单独当测试跑。


const PokerScreenScript := preload("res://src/ui/poker/poker_screen.gd")
const PLATE_KEY := PokerScreenScript.PLATE_KEY
const H := preload("res://tests/poker_helpers.gd")
const ME := 1
const SPEED := 12.0     # 演出加速:每批几秒的动画压到零点几秒
const MAX_WAIT := 20.0  # 真实秒


class StubTavern:
	extends Node
	var camera_rig: CameraRig


class StubApp:
	extends Node
	var world: TableWorld
	var labels: WorldLabels
	var tavern: StubTavern
	var toasts: Array = []
	var modes: Array = []

	func apply_table_mode(mode: String) -> void:
		modes.append(mode)
		world.configure_table(SeatLayout.table_radius_for(mode))

	func toast(text: String, _color := Color.WHITE) -> void:
		toasts.append(text)

	func show_rules() -> void:
		pass

	func is_rules_open() -> bool:
		return false

	func is_modal_open() -> bool:
		return false

	func confirm(message: String, confirm_text := "确定", _cancel_text := "取消") -> ConfirmOverlay:
		var overlay := ConfirmOverlay.new(message, confirm_text)
		add_child(overlay)
		return overlay


var app: StubApp
var screen: Node
var saved := {}
var stacks := {}      # pid -> 筹码(假视图按它生成)
var statuses := {}    # pid -> status
var bets := {}
var shown := {}
var confirmed := {}   # pid -> 两手之间点过「开始下一手」
var seats: Array = []
var names := {1: "我", 2: "乙", 3: "丙", 9: "迟到"}


func before_each():
	saved = {"seats": Net.seats, "pub": Net.last_public, "priv": Net.last_private, "mode": Net.game_mode, "scale": Engine.time_scale}
	# 前面的联机测试 leave() 后会把整棵树共用的 multiplayer_peer 置空,本屏幕 _ready 里要读 Net.my_pid()
	if multiplayer.multiplayer_peer == null:
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	Engine.time_scale = SPEED
	PokerFaces.clear()
	app = StubApp.new()
	add_child_autofree(app)
	app.labels = WorldLabels.new(null)
	app.add_child(app.labels)
	app.tavern = StubTavern.new()
	app.tavern.camera_rig = CameraRig.new()
	app.tavern.add_child(app.tavern.camera_rig)
	app.add_child(app.tavern)
	app.world = TableWorld.new(null)
	app.add_child(app.world)
	Net.game_mode = GameMode.HOLDEM
	Net.last_public = {}
	Net.last_private = {}


func after_each():
	Net.seats = saved["seats"]
	Net.last_public = saved["pub"]
	Net.last_private = saved["priv"]
	Net.game_mode = saved["mode"]
	Engine.time_scale = saved["scale"]
	PokerFaces.clear()


# —— 假视图 ——

func _reset_table(pids: Array) -> void:
	seats = pids.duplicate()
	stacks = {}
	statuses = {}
	bets = {}
	shown = {}
	confirmed = {}
	for pid in pids:
		stacks[pid] = PokerRules.STARTING_STACK
		statuses[pid] = PokerRules.STATUS_ACTIVE
		bets[pid] = 0
		shown[pid] = []


func _players() -> Array:
	return stacks.keys().map(func(pid): return {"pid": pid, "name": names[pid], "stack": stacks[pid], "bet": bets[pid],
		"committed": bets[pid], "status": statuses[pid], "left": false, "buyins": 1, "net": stacks[pid] - 2000, "shown": shown[pid],
		"confirmed": confirmed.get(pid, false)})


func _pub(actor: Variant, overrides := {}) -> Dictionary:
	var pub := {"mode": GameMode.HOLDEM, "hand": 1, "phase": "betting" if actor != null else "idle", "street": PokerRules.PREFLOP,
		"board": [], "pots": [], "button": 1, "sb": 2, "bb": 3, "current_pid": actor, "current_bet": 20, "actions": {},
		"blinds": [10, 20], "seats": seats.duplicate(), "players": _players(), "turn_time_left": 30.0, "ending": false, "results": []}
	if actor is int:
		var to_call: int = pub["current_bet"] - bets.get(actor, 0)
		pub["actions"] = {"pid": actor, "to_call": to_call, "call_amount": to_call, "can_check": to_call == 0, "can_raise": true,
			"can_allin": true, "min_raise_to": 40, "max_raise_to": bets.get(actor, 0) + stacks.get(actor, 0)}
	pub.merge(overrides, true)
	return pub


func _bet(pid: int, action: String, total: int, all_in := false) -> Dictionary:
	var added: int = total - bets[pid]
	stacks[pid] -= added
	bets[pid] = total
	if all_in:
		statuses[pid] = PokerRules.STATUS_ALLIN
	elif action == PokerRules.FOLD:
		statuses[pid] = PokerRules.STATUS_FOLDED
	return {"type": "action", "pid": pid, "action": action, "amount": added, "bet": total, "stack": stacks[pid], "all_in": all_in, "timeout": false}


func _blind(pid: int, kind: String, amount: int) -> Dictionary:
	stacks[pid] -= amount
	bets[pid] = amount
	return {"type": "blind", "pid": pid, "kind": kind, "amount": amount, "bet": amount, "stack": stacks[pid], "all_in": false}


func _collect() -> Dictionary:
	var total := 0
	for pid in bets:
		total += bets[pid]
		bets[pid] = 0
	return {"type": "bets_collected", "pots": [{"amount": total, "eligible": seats.duplicate()}], "refund": {}}


func _feed(events: Array, pub: Dictionary, priv := {}) -> void:
	# 同房主的顺序:先事件,再公共视图,再私有视图;然后等演出播完
	screen._on_events(events)
	screen._on_public(pub)
	if not priv.is_empty():
		screen._on_private(priv)
	await wait_until(func(): return not screen.animating and screen._intro_done, MAX_WAIT, "演出播完")


func _plate(pid: int) -> Control:
	return app.labels.get_node_for(PLATE_KEY % pid)


func _live_patrons() -> Array:
	return app.world.patrons.keys().filter(func(pid): return is_instance_valid(app.world.patrons[pid]))


func _open_table(pids: Array, late: bool) -> void:
	_reset_table(pids)
	Net.seats = pids.filter(func(pid): return not late or pid != ME).map(func(pid): return {"pid": pid, "name": names[pid]})
	screen = PokerScreenScript.new(app)
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child_autofree(screen)
