class_name TableWorld
extends Node3D
# 牌桌上的角色层:按座位摆放酒客与左轮,提供座位几何查询。卡牌交给 CardTable。
# 等待厅与对局共用:等待厅显示全部玩家(含自己),对局中自己的角色隐藏(第一人称)。


const REVOLVER_RADIUS := 0.6
const REVOLVER_SIDE := 0.2
const FIRST_PERSON_HEIGHT := 1.36
const FIRST_PERSON_RADIUS := 1.4

var tavern: Tavern
var cards: CardTable
var patrons := {}      # pid -> Patron
var revolvers := {}    # pid -> Revolver3D
var seat_angles := {}  # pid -> float
var my_pid := 0
var _show_self := true


func _init(p_tavern: Tavern) -> void:
	tavern = p_tavern


func _ready() -> void:
	cards = CardTable.new(self)
	add_child(cards)


# —— 座位 ——

func arrange(players: Array, p_my_pid: int, show_self: bool, with_revolvers: bool) -> void:
	# players: [{"pid", ...}] 按座位顺序;新玩家弹出登场,离开的玩家消失
	my_pid = p_my_pid
	_show_self = show_self
	var order := players.map(func(p): return p["pid"])
	var my_index := maxi(order.find(my_pid), 0)
	for pid in patrons.keys():
		if not order.has(pid):
			patrons[pid].vanish()
			patrons.erase(pid)
	for pid in revolvers.keys():
		if not order.has(pid) or not with_revolvers:
			revolvers[pid].queue_free()
			revolvers.erase(pid)
	seat_angles = {}
	for i in order.size():
		var pid = order[i]
		var angle := SeatLayout.seat_angle(i, my_index, order.size())
		seat_angles[pid] = angle
		var visible_patron: bool = show_self or pid != my_pid
		if visible_patron:
			_place_patron(pid, i, angle)
		elif patrons.has(pid):
			patrons[pid].queue_free()
			patrons.erase(pid)
		if with_revolvers:
			_place_revolver(pid, angle)


func _place_patron(pid: int, seat_index: int, angle: float) -> void:
	var xform := seat_transform(angle)
	if patrons.has(pid):
		var tween := create_tween()
		tween.tween_property(patrons[pid], "transform", xform, 0.6).set_trans(Tween.TRANS_CUBIC)
		return
	var patron := Patron.new(seat_index)
	patron.transform = xform
	add_child(patron)
	patron.appear()
	patrons[pid] = patron


func _place_revolver(pid: int, angle: float) -> void:
	if not revolvers.has(pid):
		var gun := Revolver3D.new()
		add_child(gun)
		revolvers[pid] = gun
	revolvers[pid].global_transform = revolver_rest(pid)


func revive_all() -> void:
	# 新一局开始前:倒下的酒客换成新的(带登场动画),帽子等散落物一并清理
	for pid in patrons.keys():
		var old: Patron = patrons[pid]
		if old.alive:
			continue
		var fresh := Patron.new(old.species_index)
		fresh.transform = old.transform
		old.queue_free()
		add_child(fresh)
		fresh.appear()
		patrons[pid] = fresh
	for child in get_children():
		if child.name.begins_with("Hat"):
			child.queue_free()


func clear() -> void:
	for pid in patrons:
		patrons[pid].queue_free()
	for pid in revolvers:
		revolvers[pid].queue_free()
	patrons = {}
	revolvers = {}
	seat_angles = {}
	cards.clear_all()


# —— 几何查询 ——

func seat_transform(angle: float) -> Transform3D:
	var pos := SeatLayout.seat_position(angle)
	return Transform3D(Basis.looking_at(-SeatLayout.direction(angle), Vector3.UP), pos)


func seat_right(pid: int) -> Vector3:
	return seat_transform(seat_angles.get(pid, 0.0)).basis.x


func revolver_rest(pid: int) -> Transform3D:
	# 平放在座位右前方桌面上,枪管斜指桌心
	var angle: float = seat_angles.get(pid, 0.0)
	var dir := SeatLayout.direction(angle)
	var pos := dir * REVOLVER_RADIUS + seat_right(pid) * REVOLVER_SIDE + Vector3(0, SeatLayout.TABLE_TOP + 0.013, 0)
	var aim := (-dir + seat_right(pid) * -0.35).normalized()
	var basis := Basis.looking_at(aim, Vector3.UP) * Basis(Vector3.BACK, PI / 2.0)
	return Transform3D(basis, pos)


func first_person_view(pid: int) -> Transform3D:
	var angle: float = seat_angles.get(pid, 0.0)
	var dir := SeatLayout.direction(angle)
	var pos := dir * FIRST_PERSON_RADIUS + Vector3(0, FIRST_PERSON_HEIGHT, 0)
	var target := -dir * 0.3 + Vector3(0, SeatLayout.TABLE_TOP - 0.06, 0)
	return Transform3D(Basis.looking_at(target - pos, Vector3.UP), pos)


func focus_view(pid: int) -> Transform3D:
	# 聚焦某位酒客的特写机位:从桌心斜上方看向其头部
	var angle: float = seat_angles.get(pid, 0.0)
	var dir := SeatLayout.direction(angle)
	var head := head_position(pid)
	var pos := dir * 0.15 + Vector3(0, 1.42, 0) + seat_right(pid) * -0.35
	return Transform3D(Basis.looking_at(head + Vector3(0, -0.08, 0) - pos, Vector3.UP), pos)


func head_position(pid: int) -> Vector3:
	if patrons.has(pid):
		return patrons[pid].head_position()
	var angle: float = seat_angles.get(pid, 0.0)
	return SeatLayout.seat_position(angle) + Vector3(0, 1.32, 0)


func overview_view() -> Transform3D:
	var pos := Vector3(0, 1.95, 2.45)
	return Transform3D(Basis.looking_at(Vector3(0, 0.8, -0.15) - pos, Vector3.UP), pos)


func reveal_view() -> Transform3D:
	var pos := Vector3(0, 1.35, 0.95)
	return Transform3D(Basis.looking_at(Vector3(0, SeatLayout.TABLE_TOP, 0.18) - pos, Vector3.UP), pos)


func look_all_at(point: Vector3) -> void:
	for pid in patrons:
		patrons[pid].look_at_point(point)
