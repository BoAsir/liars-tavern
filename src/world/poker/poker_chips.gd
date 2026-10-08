class_name PokerChips
extends Node3D
# 德州的筹码层(挂在 TableWorld.poker_root 下):各座位的筹码堆与本轮下注、底池、庄家按钮。
# 金额为 0 不建节点;动画方法都是协程,时长常量公开,供导演的演出预算测试读取(PokerPacing)。
# 静止的筹码堆、下注与按钮每帧按 TableWorld.seat_angle_now 摆:酒客沿圆弧换座时它们跟着同一角度走。
# 飞行中的筹码是临时的一摞,补间都挂在本节点上:中途对账(sync)或清空(clear)时协程照常走完、不卡住导演,
# 回来发现已经对过账(_epoch 变了)就不再改金额。


signal sfx(name: String)

const BET_SLIDE := 0.4        # 下注:新放进去的筹码从筹码堆滑到下注位(盲注预算 0.5、行动 0.7)
const REFUND_SLIDE := 0.2     # 一轮结束:未跟注部分先退回筹码堆
const COLLECT_SLIDE := 0.4    # 再把各家下注收进底池(两段合计在 BETS_COLLECTED 0.7 之内)
const AWARD_SLIDE := 0.8      # 底池滑向赢家(POT_WON 2.0 之内,留时间给宣告与庆祝)
const REBUY_DROP := 0.45      # 再领:一摞新筹码从上方落到座位前(REBUY 0.6 之内)
const BUTTON_MOVE := 0.9      # 庄家按钮绕桌心滑到新按钮座位前(HAND_STARTED 1.4 之内)
const SLIDE_ARC := 0.05       # 滑动时抬起的高度:贴着桌面拖会穿过别的筹码
const DROP_HEIGHT := 0.3
const LABEL_LIFT := 0.03      # 2D 金额标签挂在最高一列上方这么高

var world: TableWorld
var _stacks := {}         # pid -> ChipStack3D:座位前的筹码堆
var _bets := {}           # pid -> ChipStack3D:本轮下注
var _pots: Array = []     # 下标 = 底池序号(0 主池);分出去的置 null
var _flyers: Array = []   # 正在飞的临时筹码
var _button: DealerButton3D
var _button_pid: Variant = null
var _epoch := 0           # sync / clear 时加一


func _init(p_world: TableWorld) -> void:
	world = p_world
	name = "PokerChips"
	_button = DealerButton3D.new()
	_button.visible = false
	add_child(_button)


func _process(_delta: float) -> void:
	_follow_seats()


# —— 查询 ——

func stack_amount(pid: int) -> int:
	return _stacks[pid].amount if _stacks.has(pid) else 0


func bet_amount(pid: int) -> int:
	return _bets[pid].amount if _bets.has(pid) else 0


func pot_amounts() -> Array:
	return _pots.filter(func(pot): return pot != null).map(func(pot: ChipStack3D) -> int: return pot.amount)


func stack_node(pid: int) -> ChipStack3D:
	return _stacks.get(pid)


func bet_node(pid: int) -> ChipStack3D:
	return _bets.get(pid)


func pot_node(index: int) -> ChipStack3D:
	return _pots[index] if index >= 0 and index < _pots.size() else null


func button_node() -> DealerButton3D:
	return _button


func button_pid() -> Variant:
	return _button_pid


func stack_anchor(pid: int) -> Vector3:
	# 2D 金额标签的挂点(全局坐标):最高一列的上方;没有筹码时挂在筹码堆该在的位置
	return _anchor(_stacks.get(pid), _stack_spot(pid))


func bet_anchor(pid: int) -> Vector3:
	return _anchor(_bets.get(pid), _bet_spot(pid))


func pot_anchor(index: int) -> Vector3:
	return _anchor(pot_node(index), _pot_spot(index))


# —— 对账 ——

func sync(players: Array, pots: Array) -> void:
	# 按公共视图瞬时摆好:players / pots 同视图字段。没离开的在座者有筹码堆;
	# 离开者已下的注留在桌上等收进底池;还没登场的人(没有座位)不摆
	_epoch += 1
	_drop_flyers()
	var stacks := {}
	var bets := {}
	for p in players:
		var pid: int = p.get("pid", 0)
		if not world.seat_angles.has(pid):
			continue
		if not p.get("left", false):
			stacks[pid] = int(p.get("stack", 0))
		bets[pid] = int(p.get("bet", 0))
	_reconcile(_stacks, stacks)
	_reconcile(_bets, bets)
	_set_pots(pots.map(func(pot) -> int: return int(pot.get("amount", 0))))
	_follow_seats()


func place_button(pid: Variant) -> void:
	# 瞬时摆庄家按钮(对账用);null = 还没有按钮(第一手之前)
	_button_pid = pid
	_button.visible = pid != null and world.seat_angles.has(pid)
	if _button.visible:
		_button.move_to(_button_spot(pid), 0.0)


func remove_seat(pid: int) -> void:
	# 离桌:筹码跟人走;已下的注留在桌上,等这一轮收进底池
	_set_amount(_stacks, pid, 0)


func clear() -> void:
	_epoch += 1
	_drop_flyers()
	_reconcile(_stacks, {})
	_reconcile(_bets, {})
	_set_pots([])
	place_button(null)


# —— 动画(协程)——

func bet(pid: int, total: int, stack: int) -> void:
	# 盲注 / 跟注 / 下注 / 加注 / 全下:total 是本轮累计,stack 是剩下的;新放进去的部分从筹码堆滑到下注位
	var epoch := _epoch
	var added := total - bet_amount(pid)
	_set_amount(_stacks, pid, stack)
	if added <= 0 or not world.seat_angles.has(pid):
		_set_amount(_bets, pid, total)
		return
	sfx.emit("chips_push" if stack == 0 else "chips")
	var flyer := _launch(added, _stack_spot(pid), pid)
	await _fly([[flyer, _bet_spot(pid)]], BET_SLIDE)
	if epoch == _epoch:
		_set_amount(_bets, pid, total)


func collect(pots: Array, refund: Dictionary) -> void:
	# 一轮结束(bets_collected):先把未跟注的部分退回筹码堆,再把各家下注收进底池;pots 是收完后的全部底池
	var epoch := _epoch
	if refund.get("amount", 0) is int and refund.get("amount", 0) > 0 and refund.get("pid") is int:
		await _refund(refund["pid"], refund["amount"])
		if epoch != _epoch:
			return
	var flights := []
	for pid in _bets.keys():
		flights.append([_bets[pid], _pot_spot(0, 1)])
		_flyers.append(_bets[pid])
		_bets.erase(pid)
	if not flights.is_empty():
		sfx.emit("chips")
		await _fly(flights, COLLECT_SLIDE)
	if epoch == _epoch:
		_set_pots(pots.map(func(pot) -> int: return int(pot.get("amount", 0))))


func _refund(pid: int, amount: int) -> void:
	var epoch := _epoch
	_set_amount(_bets, pid, bet_amount(pid) - amount)
	var flyer := _launch(amount, _bet_spot(pid), pid)
	await _fly([[flyer, _stack_spot(pid)]], REFUND_SLIDE)
	if epoch == _epoch and world.patrons.has(pid):
		_set_amount(_stacks, pid, stack_amount(pid) + amount)


func award(index: int, shares: Dictionary, stacks: Dictionary) -> void:
	# 分一个底池(pot_won):底池按份额滑向各赢家的筹码堆。stacks 里有的按它定格,没有的加上份额;
	# 已离开的赢家:筹码滑到他的空座位前就收走
	var epoch := _epoch
	var from := _pot_spot(index)
	if pot_node(index) != null:
		_pots[index].queue_free()
		_pots[index] = null
	var flights := []
	for pid in shares:
		if shares[pid] is int and shares[pid] > 0 and world.seat_angles.has(pid):
			flights.append([_launch(shares[pid], from, pid), _stack_spot(pid)])
	if not flights.is_empty():
		sfx.emit("chips")
		await _fly(flights, AWARD_SLIDE)
	if epoch != _epoch:
		return
	for pid in shares:
		if world.patrons.has(pid) and shares[pid] is int:
			var stack: Variant = stacks.get(pid)
			_set_amount(_stacks, pid, stack if stack is int else stack_amount(pid) + shares[pid])


func rebuy(pid: int, stack: int) -> void:
	# 再领:一摞新筹码从座位前上方落下
	var epoch := _epoch
	var added := stack - stack_amount(pid)
	if added <= 0 or not world.seat_angles.has(pid):
		_set_amount(_stacks, pid, stack)
		return
	sfx.emit("chips")
	var spot := _stack_spot(pid)
	var flyer := _launch(added, spot + Vector3.UP * DROP_HEIGHT, pid)
	var ref: WeakRef = weakref(flyer)   # 补间期间可能被对账收走:不直接捕获节点
	var tween := create_tween()
	tween.tween_method(func(y: float) -> void:
		var node: Node3D = ref.get_ref()
		if node != null:
			node.position.y = y,
		spot.y + DROP_HEIGHT, spot.y, REBUY_DROP).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tween.finished
	_land([flyer])
	if epoch == _epoch:
		_set_amount(_stacks, pid, stack)


func move_button(pid: int, duration := BUTTON_MOVE) -> void:
	# 新一手(hand_started):按钮绕桌心滑到新按钮座位前;第一次出现时直接落位。
	# 先按新座位表 arrange 再调用:目标按新座位算,换座滑动与按钮滑动一起走
	if not world.seat_angles.has(pid):
		place_button(null)
		return
	var shown := _button.visible
	_button_pid = pid
	_button.visible = true
	var target := PokerLayout.button_position(world.seat_angles[pid], world.table_radius)
	if not shown or duration <= 0.0:
		_button.move_to(target, 0.0)
		return
	_button.move_to(target, duration)
	# 等自己的计时补间,不等按钮的:按钮半路被清掉时导演也不会卡住
	var wait := create_tween()
	wait.tween_interval(duration)
	await wait.finished


# —— 内部 ——

func _stack_spot(pid: int) -> Vector3:
	return PokerLayout.stack_position(world.seat_angle_now(pid), world.table_radius)


func _bet_spot(pid: int) -> Vector3:
	return PokerLayout.bet_position(world.seat_angle_now(pid), world.table_radius)


func _button_spot(pid: int) -> Vector3:
	return PokerLayout.button_position(world.seat_angle_now(pid), world.table_radius)


func _pot_spot(index: int, count := -1) -> Vector3:
	# 收注时各家筹码先滑到底池那一排的中间(count = 1),收完再按底池个数排开
	if count < 0:
		if pot_node(index) != null:
			return _pots[index].position
		count = maxi(_pots.size(), index + 1)
	return PokerLayout.pot_position(index, count)


func _anchor(node: ChipStack3D, spot: Vector3) -> Vector3:
	var top := 0.0
	if node != null:
		spot = node.position
		top = node.top_height()
	return to_global(spot + Vector3.UP * (top + LABEL_LIFT))


func _follow_seats() -> void:
	for pid in _stacks:
		_pin(_stacks[pid], pid, _stack_spot(pid))
	for pid in _bets:
		_pin(_bets[pid], pid, _bet_spot(pid))
	if _button_pid != null and not _button.is_moving() and world.seat_angles.has(_button_pid):
		_button.position = _button_spot(_button_pid)


func _pin(node: Node3D, pid: int, spot: Vector3) -> void:
	# 没有座位的人(离桌后已重排)留在原处,等收进底池或清掉
	if world.seat_angles.has(pid):
		node.position = spot
		node.rotation = Vector3(0.0, -world.seat_angle_now(pid), 0.0)


func _reconcile(nodes: Dictionary, amounts: Dictionary) -> void:
	for pid in nodes.keys():
		if not amounts.has(pid):
			_set_amount(nodes, pid, 0)
	for pid in amounts:
		_set_amount(nodes, pid, amounts[pid])


func _set_amount(nodes: Dictionary, pid: int, amount: int) -> void:
	if amount <= 0:
		if nodes.has(pid):
			nodes[pid].queue_free()
			nodes.erase(pid)
		return
	if not nodes.has(pid):
		if not world.seat_angles.has(pid):
			return   # 没有座位的人不建:摆不到位置,会留在桌心底下
		nodes[pid] = _new_stack()
		# Dictionary 的 == 比内容,这里要比是不是同一个
		_pin(nodes[pid], pid, _stack_spot(pid) if is_same(nodes, _stacks) else _bet_spot(pid))
	nodes[pid].set_amount(amount)


func _set_pots(amounts: Array) -> void:
	for pot in _pots:
		if pot != null:
			pot.queue_free()
	_pots = []
	for i in amounts.size():
		var pot: ChipStack3D = null
		if amounts[i] > 0:
			pot = _new_stack()
			pot.position = PokerLayout.pot_position(i, amounts.size())
			pot.set_amount(amounts[i])
		_pots.append(pot)


func _new_stack() -> ChipStack3D:
	var stack := ChipStack3D.new()
	add_child(stack)
	return stack


func _launch(amount: int, from: Vector3, pid: int) -> ChipStack3D:
	var flyer := _new_stack()
	flyer.set_amount(amount)
	flyer.position = from
	flyer.rotation = Vector3(0.0, -world.seat_angle_now(pid), 0.0)
	_flyers.append(flyer)
	return flyer


func _fly(flights: Array, duration: float) -> void:
	# flights: [[节点, 目标位置]]:沿抬起的弧线同时滑过去,到了就收走。补间挂在本节点上;
	# 节点半路可能被对账收走,只捕获弱引用
	var tween := create_tween().set_parallel()
	for flight in flights:
		var ref: WeakRef = weakref(flight[0])
		var from: Vector3 = flight[0].position
		var to: Vector3 = flight[1]
		var mid := (from + to) / 2.0 + Vector3.UP * SLIDE_ARC
		tween.tween_method(func(t: float) -> void:
			var node: Node3D = ref.get_ref()
			if node != null:
				node.position = from.lerp(mid, t).lerp(mid.lerp(to, t), t),
			0.0, 1.0, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	_land(flights.map(func(flight): return flight[0]))


func _land(nodes: Array) -> void:
	for node in nodes:
		_flyers.erase(node)
		if is_instance_valid(node):
			node.queue_free()


func _drop_flyers() -> void:
	_land(_flyers.duplicate())
	_flyers = []
