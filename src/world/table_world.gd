class_name TableWorld
extends Node3D
# 牌桌上的角色层:按座位摆放酒客与左轮,提供座位几何查询。卡牌交给 CardTable。
# 等待厅与对局共用:都显示全部玩家(含自己);对局中镜头在自己角色身后越肩(第三人称)。


# 左轮放在座位右前方、翻牌行之外(翻牌行在本机座位前 CardTable.REVEAL_Z 处)
const REVOLVER_RADIUS := 0.78
const REVOLVER_SIDE := 0.32
const THIRD_PERSON_BACK := 2.1
const THIRD_PERSON_HEIGHT := 1.92
const THIRD_PERSON_SIDE := 0.55
const SEAT_FILL_LIGHT := 0.9   # 越肩机位的补光强度(CameraRig.fill_light)
const LOBBY_SHIFT := 0.95      # 等待厅机位向右平移(米)

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
			_place_patron(pid, angle)
		elif patrons.has(pid):
			patrons[pid].queue_free()
			patrons.erase(pid)
		if with_revolvers:
			_place_revolver(pid, angle)


func _place_patron(pid: int, angle: float) -> void:
	var xform := seat_transform(angle)
	if patrons.has(pid):
		var tween := create_tween()
		tween.tween_property(patrons[pid], "transform", xform, 0.6).set_trans(Tween.TRANS_CUBIC)
		return
	# 物种跟人走:新来的取第一个没人用的物种,之后一直沿用(换座、复活都不变)
	var used := patrons.values().map(func(p: Patron) -> int: return p.species_index)
	var patron := Patron.new(PatronParts.first_free_species(used))
	patron.transform = xform
	add_child(patron)
	patron.appear()
	patrons[pid] = patron


func species_of(pid: int) -> Dictionary:
	# 该玩家角色的物种外观(等待厅名单据此显示动物,与 3D 角色一致);还没有角色时返回 {}
	if not patrons.has(pid):
		return {}
	return PatronParts.species(patrons[pid].species_index)


func _place_revolver(pid: int, angle: float) -> void:
	if not revolvers.has(pid):
		var gun := Revolver3D.new()
		add_child(gun)
		revolvers[pid] = gun
	revolvers[pid].global_transform = revolver_rest(pid)


func revive_all() -> void:
	# 新一局开始前:倒下的酒客换成新的(带登场动画),活着的复位姿势(如胜者的庆祝),帽子等散落物一并清理
	for pid in patrons.keys():
		var old: Patron = patrons[pid]
		if old.alive:
			old.reset_pose()
			continue
		var fresh := Patron.new(old.species_index)
		fresh.transform = old.transform
		old.queue_free()
		add_child(fresh)
		fresh.appear()
		patrons[pid] = fresh
	_clear_debris()


func clear() -> void:
	for pid in patrons:
		patrons[pid].queue_free()
	for pid in revolvers:
		revolvers[pid].queue_free()
	patrons = {}
	revolvers = {}
	seat_angles = {}
	cards.clear_all()
	_clear_debris()


func _clear_debris() -> void:
	# 出局时打飞的帽子等:Patron 把它们挂到本节点下并打上 DEBRIS_GROUP 标记
	for child in get_children():
		if child.is_in_group(Patron.DEBRIS_GROUP):
			child.queue_free()


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


func third_person_view(pid: int) -> Transform3D:
	# 越过右肩看向桌心:自己的角色在画面左下,牌扇在其右侧,对手与桌面在画面中央
	var angle: float = seat_angles.get(pid, 0.0)
	var dir := SeatLayout.direction(angle)
	var pos := dir * THIRD_PERSON_BACK + seat_right(pid) * THIRD_PERSON_SIDE + Vector3(0, THIRD_PERSON_HEIGHT, 0)
	var target := -dir * 0.12 + Vector3(0, SeatLayout.TABLE_TOP, 0)
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
	# 观战机位:从自己座位后上方俯看整桌,越过自己(倒下的)角色的头顶
	var pos := Vector3(0, 2.7, 2.4)
	return Transform3D(Basis.looking_at(Vector3(0, SeatLayout.TABLE_TOP, -0.25) - pos, Vector3.UP), pos)


func lobby_view() -> Transform3D:
	# 等待厅机位:整体右移,牌桌落在画面左侧,右侧留给等待厅面板;抬高以免自己的角色挡住桌面
	var pos := Vector3(LOBBY_SHIFT, 2.6, 2.5)
	return Transform3D(Basis.looking_at(Vector3(LOBBY_SHIFT, 0.75, -0.1) - pos, Vector3.UP), pos)


func reveal_view(liar_pid: int) -> Transform3D:
	# 俯看本机座位前的翻牌行,同时把出牌者(被翻牌的人)的脸收进画面:对面座位少转一点,侧座多转一点
	var pos := Vector3(0, 1.42, 1.05)
	var target := Vector3(0, 0.86, 0.0)
	if liar_pid != my_pid and seat_angles.has(liar_pid):
		var sideways := absf(sin(float(seat_angles[liar_pid])))
		var row := Vector3(0, SeatLayout.TABLE_TOP, CardTable.REVEAL_Z)
		target = row.lerp(head_position(liar_pid), lerpf(0.35, 0.5, sideways))
	return Transform3D(Basis.looking_at(target - pos, Vector3.UP), pos)


func look_all_at(point: Vector3) -> void:
	for pid in patrons:
		patrons[pid].look_at_point(point)
