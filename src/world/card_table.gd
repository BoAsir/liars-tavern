class_name CardTable
extends Node3D
# 卡牌层:自己的手牌(自己角色举在胸前、牌面朝镜头)、他人手中的牌背、出牌区、翻牌区、桌心目标牌立牌。
# 动画方法均为协程(await 到动画结束);音效通过 sfx 信号交给上层播放。


signal sfx(name: String)

const DEAL_STAGGER := 0.055
const DEAL_FLIGHT := 0.32
const PLAY_FLIGHT := 0.42
const SWEEP_FLIGHT := 0.4
const LIFT_HOVER := 0.012
const LIFT_SELECTED := 0.032
const REVEAL_Z := 0.38
const STAND_HEIGHT := 0.085
const STAND_SPIN := 0.45
# 卡牌本地系(+Y 法线, -Z 牌顶)→ 竖立面向持牌者:X→右,Y→朝向持牌者,Z→向下
const FAN_BASIS := Basis(Vector3(1, 0, 0), Vector3(0, 0, 1), Vector3(0, -1, 0))

var world: TableWorld
var hand_root: Node3D        # 自己角色的牌扇节点(第三人称)
var my_cards: Array = []     # Card3D,下标与私有手牌一致
var held := {}               # pid -> Array[Card3D](他人牌背)
var pile: Array = []
var last_play: Array = []
var revealed: Array = []
var selected := {}
var hovered := -1
var target_kind := CardFaces.BACK

var _stand: Node3D
var _target_card: Card3D
var _pile_seed := 0
var _my_holding := false


func _init(p_world: TableWorld) -> void:
	world = p_world


func _ready() -> void:
	_build_stand()


func _process(delta: float) -> void:
	_stand.rotation.y += STAND_SPIN * delta


# —— 目标牌立牌 ——

func _build_stand() -> void:
	_stand = MeshKit.pivot(self, Vector3(0, SeatLayout.TABLE_TOP, 0), "TargetStand")
	MeshKit.add(_stand, MeshKit.cylinder(0.045, 0.055, 0.014, 32), WorldMaterials.brass(), Vector3(0, 0.007, 0))
	MeshKit.add(_stand, MeshKit.cylinder(0.004, 0.005, STAND_HEIGHT, 8), WorldMaterials.brass(),
		Vector3(0, STAND_HEIGHT / 2.0, 0))
	MeshKit.add(_stand, MeshKit.box(Vector3(0.03, 0.012, 0.008)), WorldMaterials.brass(), Vector3(0, STAND_HEIGHT, 0))
	_target_card = Card3D.new()
	_target_card.transform = Transform3D(FAN_BASIS, Vector3(0, STAND_HEIGHT + Card3D.HEIGHT / 2.0 - 0.006, 0))
	_stand.add_child(_target_card)
	_target_card.set_both_faces(CardFaces.BACK)


func set_target(kind: int, animate := true) -> void:
	target_kind = kind
	if not animate:
		_target_card.set_both_faces(kind)
		return
	sfx.emit("flip")
	var tween := create_tween()
	tween.tween_property(_target_card, "scale", Vector3(0.05, 1.0, 1.0), 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(_target_card.set_both_faces.bind(kind))
	tween.tween_property(_target_card, "scale", Vector3(1.25, 1.0, 1.25), 0.16).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_target_card, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_method(_target_card.set_glow.bind(Color(1.0, 0.8, 0.35)), 1.6, 0.0, 0.9)
	await tween.finished


func stand_position() -> Vector3:
	return _stand.global_position + Vector3(0, STAND_HEIGHT, 0)


# —— 自己的手牌 ——

func attach_hand(fan_root: Node3D) -> void:
	hand_root = fan_root


func my_kinds() -> Array:
	return my_cards.map(func(c): return c.kind)


func set_selection(p_selected: Dictionary, p_hovered: int) -> void:
	selected = p_selected
	hovered = p_hovered
	_layout_mine(0.12)


func pick(origin: Vector3, direction: Vector3) -> int:
	var best := -1
	var best_dist := INF
	for i in my_cards.size():
		var dist: float = my_cards[i].ray_hit_distance(origin, direction)
		if dist >= 0.0 and dist < best_dist:
			best_dist = dist
			best = i
	return best


func _layout_mine(duration: float) -> void:
	for i in my_cards.size():
		var lift := LIFT_SELECTED if selected.has(i) else (LIFT_HOVER if i == hovered else 0.0)
		var card: Card3D = my_cards[i]
		_move_local(card, fan_slot(i, my_cards.size(), lift), duration)
		var glow := 0.75 if selected.has(i) else (0.3 if i == hovered else 0.0)
		card.set_glow(glow)
	var holding := not my_cards.is_empty()
	if holding != _my_holding and world.patrons.has(world.my_pid):
		_my_holding = holding
		world.patrons[world.my_pid].set_holding(holding)


# —— 他人手牌 ——

func _layout_held(pid: int, duration: float) -> void:
	var cards: Array = held.get(pid, [])
	for i in cards.size():
		_move_local(cards[i], fan_slot(i, cards.size(), 0.0), duration)
	if world.patrons.has(pid):
		world.patrons[pid].set_holding(not cards.is_empty())


func _fan_of(pid: int) -> Node3D:
	return world.patrons[pid].fan if world.patrons.has(pid) else null


static func fan_slot(i: int, count: int, lift: float) -> Transform3D:
	var slot: Dictionary = SeatLayout.fan_slots(count)[i]
	var basis := Basis(Vector3.UP, slot["rot"])
	var pos := Vector3(slot["x"], i * 0.0016, -slot["y"]) + basis * Vector3(0, 0, -lift)
	return Transform3D(basis, pos)


# —— 发牌 ——

func deal(order: Array, counts: Dictionary, my_hand: Array) -> void:
	var rounds := 0
	for pid in order:
		rounds = maxi(rounds, counts.get(pid, 0))
	var delay := 0.0
	for r in rounds:
		for pid in order:
			var count: int = counts.get(pid, 0)
			if r < count:
				_deal_one(pid, r, count, my_hand, delay)
				delay += DEAL_STAGGER
	await get_tree().create_timer(delay + DEAL_FLIGHT + 0.05).timeout
	_layout_mine(0.15)
	for pid in held:
		_layout_held(pid, 0.15)


func _deal_one(pid: int, index: int, count: int, my_hand: Array, delay: float) -> void:
	var card := Card3D.new()
	add_child(card)
	card.global_transform = Transform3D(Basis(Vector3.BACK, PI).scaled(Vector3.ONE * 0.4), stand_position())
	card.visible = false
	var parent: Node3D
	if pid == world.my_pid:
		card.set_kind(my_hand[index] if index < my_hand.size() else CardFaces.BACK)
		my_cards.append(card)
		parent = hand_root
	else:
		if not held.has(pid):
			held[pid] = []
		held[pid].append(card)
		parent = _fan_of(pid)
	await get_tree().create_timer(delay).timeout
	if not is_instance_valid(card) or parent == null:
		return
	card.visible = true
	sfx.emit("deal")
	var target := parent.global_transform * fan_slot(index, count, 0.0)
	await card.fly_to(target, DEAL_FLIGHT, 0.18, 0.0).finished
	if is_instance_valid(card) and is_instance_valid(parent):
		card.reparent(parent, true)


# —— 出牌 ——

func play(pid: int, count: int, my_indices: Array) -> void:
	var nodes := _take_from_hand(pid, count, my_indices)
	last_play = nodes
	var flights := []
	for card in nodes:
		card.reparent(self, true)
		var off := SeatLayout.pile_offset(pile.size(), _pile_seed)
		var pos := Vector3(off["pos"].x, SeatLayout.TABLE_TOP + 0.003 + pile.size() * 0.0011, off["pos"].y)
		var basis := Basis(Vector3.UP, off["rot"]) * Basis(Vector3.BACK, PI)
		pile.append(card)
		card.set_glow(0.0)
		flights.append(card.fly_to(Transform3D(basis, pos), PLAY_FLIGHT, 0.14, 0.6))
	sfx.emit("slide")
	if pid == world.my_pid:
		selected = {}
		hovered = -1
		_layout_mine(0.2)
	else:
		_layout_held(pid, 0.2)
	if not flights.is_empty():
		await flights[-1].finished
	sfx.emit("slap")


func _take_from_hand(pid: int, count: int, my_indices: Array) -> Array:
	var nodes := []
	if pid == world.my_pid:
		var indices := my_indices.duplicate()
		if indices.size() != count:
			indices = range(mini(count, my_cards.size()))
		indices.sort()
		indices.reverse()
		for i in indices:
			if i < my_cards.size():
				nodes.append(my_cards[i])
				my_cards.remove_at(i)
		nodes.reverse()
	else:
		var cards: Array = held.get(pid, [])
		for i in mini(count, cards.size()):
			nodes.append(cards.pop_back())
	# 视觉与状态不同步时(如中途加入渲染)补足缺的牌
	while nodes.size() < count:
		var card := Card3D.new()
		add_child(card)
		card.global_transform = Transform3D(Basis(Vector3.BACK, PI), world.head_position(pid) + Vector3(0, -0.35, 0))
		nodes.append(card)
	return nodes


# —— 翻牌 ——

func gather_for_reveal(count: int) -> void:
	# 把上家那组牌从出牌区移到翻牌行(背面朝上排好)
	var nodes := last_play.duplicate()
	while nodes.size() < count:
		var card := Card3D.new()
		add_child(card)
		card.global_transform = Transform3D(Basis(Vector3.BACK, PI), Vector3(0, SeatLayout.TABLE_TOP + 0.01, 0))
		nodes.append(card)
	revealed = nodes.slice(0, count)
	var xs := SeatLayout.reveal_slots(revealed.size())
	var tween: Tween = null
	for i in revealed.size():
		var card: Card3D = revealed[i]
		pile.erase(card)
		var pos := Vector3(xs[i], SeatLayout.TABLE_TOP + 0.004, REVEAL_Z)
		tween = card.fly_to(Transform3D(Basis(Vector3.BACK, PI), pos), 0.38, 0.1)
	sfx.emit("slide")
	if tween != null:
		await tween.finished


func flip_revealed(index: int, kind: int, matches: bool) -> void:
	if index >= revealed.size():
		return
	var card: Card3D = revealed[index]
	card.set_kind(kind)
	sfx.emit("flip")
	await card.flip_to_face(0.28, 0.06).finished
	card.pulse_glow(Color(0.35, 1.0, 0.45) if matches else Color(1.0, 0.25, 0.15), 2.2, 0.6)


# —— 收牌 / 同步 ——

func sweep() -> void:
	var all := pile + revealed + my_cards
	for pid in held:
		all.append_array(held[pid])
	pile = []
	revealed = []
	last_play = []
	my_cards = []
	selected = {}
	hovered = -1
	for pid in held.keys() + [world.my_pid]:
		if world.patrons.has(pid):
			world.patrons[pid].set_holding(false)
	held = {}
	_my_holding = false
	_pile_seed += 1
	if all.is_empty():
		return
	sfx.emit("sweep")
	var tween: Tween = null
	for card in all:
		if not is_instance_valid(card):
			continue
		card.reparent(self, true)
		tween = card.fly_to(Transform3D(Basis(Vector3.BACK, PI).scaled(Vector3.ONE * 0.2), stand_position()),
			SWEEP_FLIGHT + randf() * 0.12, 0.1, 1.2)
		tween.tween_callback(card.queue_free)
	if tween != null:
		await tween.finished


func drop_held(pid: int) -> void:
	# 断线出局者的手牌直接收走
	for card in held.get(pid, []):
		card.reparent(self, true)
		var tween: Tween = card.fly_to(Transform3D(Basis().scaled(Vector3.ONE * 0.2), stand_position()), SWEEP_FLIGHT, 0.1)
		tween.tween_callback(card.queue_free)
	held.erase(pid)


func sync(counts: Dictionary, my_hand: Array) -> void:
	# 兜底对账:动画结束后按最新状态瞬时修正牌数(正常流程下不会触发)
	if my_kinds() != my_hand:
		for card in my_cards:
			card.queue_free()
		my_cards = []
		for kind in my_hand:
			var card := Card3D.new()
			card.set_kind(kind)
			hand_root.add_child(card)
			my_cards.append(card)
		selected = {}
		hovered = -1
		_layout_mine(0.0)
	for pid in counts:
		if pid == world.my_pid or not world.patrons.has(pid):
			continue
		var cards: Array = held.get(pid, [])
		var want: int = counts[pid]
		if cards.size() == want:
			continue
		while cards.size() > want:
			cards.pop_back().queue_free()
		while cards.size() < want:
			var card := Card3D.new()
			_fan_of(pid).add_child(card)
			cards.append(card)
		held[pid] = cards
		_layout_held(pid, 0.0)


func clear_all() -> void:
	for card in pile + revealed + my_cards:
		if is_instance_valid(card):
			card.queue_free()
	for pid in held:
		for card in held[pid]:
			if is_instance_valid(card):
				card.queue_free()
	pile = []
	revealed = []
	last_play = []
	my_cards = []
	held = {}
	selected = {}
	hovered = -1
	set_target(CardFaces.BACK, false)


func _move_local(card: Node3D, target: Transform3D, duration: float) -> void:
	if duration <= 0.0:
		card.transform = target
		return
	var tween := card.create_tween()
	tween.tween_property(card, "transform", target, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
