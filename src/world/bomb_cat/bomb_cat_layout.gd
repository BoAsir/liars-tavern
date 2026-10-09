class_name BombCatLayout
# 炸弹猫牌桌布局(纯函数):桌心的牌堆与弃牌堆、各家牌扇的扇形(张数多时压缩)、自己第一人称的牌扇位置。
# 坐标是牌桌世界的(TableWorld 下,本机座位在 +Z):牌堆在桌心左边、弃牌堆在右边(本机看过去)。
# 烛台在半径 0.7 的两侧(CandlesProp.SPECS),桌心这一块是空的。


const TABLE_FOCUS := Vector3(0, SeatLayout.TABLE_TOP + 0.05, 0)   # 酒客平时看向桌心的两摞牌
const PILE_SCALE := 1.8                      # 桌上的牌放大(牌堆、弃牌堆、飞行中的牌)
const DECK_SPOT := Vector2(-0.16, 0.03)      # (x, z)
const DISCARD_SPOT := Vector2(0.16, 0.03)
const CARD_STEP := 0.0011                    # 每张牌叠高(= CardTable.PILE_STEP)
const MAX_STACK_HEIGHT := 0.09               # 牌堆最高这么高(张数异常时也不戳到吊灯)
const DISCARD_SHOWN := 5                     # 弃牌堆顶上摊开几张正面朝上的牌,其余是一块按张数缩放的纸边盒子
const DISCARD_JITTER := Vector2(0.014, 0.32) # 弃牌堆稍乱:位置抖动(米)、转角抖动(弧度)
# 牌扇(他人与自己共用):≤ COMPRESS_FROM 张时按 SPACING 排开,再多就保持总宽不变、每张挤得更近(不加网格)
const SPACING := 0.045
const COMPRESS_FROM := 10
const SPREAD_TOTAL_DEG := 36.0               # 整扇最多转这么多度
const SPREAD_MAX_DEG := 7.0                  # 相邻两张最多差这么多度(张数少时同骗子酒馆)
const DROP_EDGE := 0.02                      # 最外侧的牌比中间低这么多
const DROP_MAX := 0.008
const LAYER_STEP := 0.0016                   # 相邻两张前后错开(不相交)
# 自己的牌扇:越肩时在 Patron 摆好的基础上缩小一点(8 张以上的扇不挡对面的人);第一人称拿在镜头右下方
const MY_FAN_SCALE := 0.82
const FP_FAN_CAM := Vector3(0.3, -0.07, -0.6)
const FP_FAN_SCALE := 0.72
const BIG_TABLE_FAN_RAISE := 0.1             # 大桌越肩:德州的举牌位置再抬高一点,牌扇露在回合横幅上方
const SMALL_TABLE_FAN_RAISE := 0.13          # 小桌越肩:骗子酒馆的举牌位置再抬高一点(底部 HUD 比骗子酒馆高)
# 偷看:三张牌浮在镜头前(镜头坐标)
const PEEK_DISTANCE := 0.42
const PEEK_SPACING := 0.1
const PEEK_DROP := -0.05
const PEEK_SCALE := 0.75
# 摸到炸弹:炸弹牌立在摸牌人面前(从座位往桌心这么远、比桌面高这么多),牌面朝桌心
const BOMB_SHOW_FROM_SEAT := 0.62
const BOMB_SHOW_HEIGHT := 0.27
const BOMB_SHOW_SIDE := 0.17                 # 往摸牌人的右手边挪(特写里在脸的左下方,不挡脸)
const BOMB_SHOW_SCALE := 1.8


static func spacing_for(count: int) -> float:
	if count <= COMPRESS_FROM:
		return SPACING
	return SPACING * (COMPRESS_FROM - 1) / float(count - 1)


static func fan_width(count: int) -> float:
	# 最左到最右两张中心的距离
	return spacing_for(count) * maxi(count - 1, 0)


static func fan_slots(count: int) -> Array:
	# [{"x", "y", "rot"}],同 SeatLayout.fan_slots:x 横向,y 下沉(外侧更低),rot 绕视线轴(弧度,左正)
	var slots := []
	if count <= 0:
		return slots
	var mid := (count - 1) / 2.0
	var spacing := spacing_for(count)
	var step_deg := minf(SPREAD_MAX_DEG, SPREAD_TOTAL_DEG / maxf(count - 1, 1))
	var drop := minf(DROP_MAX, DROP_EDGE / maxf(mid * mid, 1.0))
	for i in count:
		var k := float(i) - mid
		slots.append({"x": k * spacing, "y": -k * k * drop, "rot": -k * deg_to_rad(step_deg)})
	return slots


static func fan_slot(i: int, count: int, lift := 0.0) -> Transform3D:
	# 牌扇节点(Patron.fan)里第 i 张的局部变换;lift 往牌顶方向抬起(选中、悬停)
	var slots := fan_slots(count)
	if i < 0 or i >= slots.size():
		return Transform3D()
	var slot: Dictionary = slots[i]
	var basis := Basis(Vector3.UP, slot["rot"])
	var pos := Vector3(slot["x"], i * LAYER_STEP, -slot["y"]) + basis * Vector3(0, 0, -lift)
	return Transform3D(basis, pos)


static func stack_height(count: int) -> float:
	return minf(maxi(count, 0) * CARD_STEP, MAX_STACK_HEIGHT)


static func deck_position() -> Vector3:
	return Vector3(DECK_SPOT.x, SeatLayout.FELT_TOP, DECK_SPOT.y)


static func discard_position() -> Vector3:
	return Vector3(DISCARD_SPOT.x, SeatLayout.FELT_TOP, DISCARD_SPOT.y)


static func deck_top(count: int) -> Transform3D:
	# 牌堆顶那张(牌背朝上)
	var y := SeatLayout.FELT_TOP + stack_height(count) + Card3D.THICKNESS * PILE_SCALE / 2.0 + 0.0003
	return Transform3D(Basis(Vector3.BACK, PI).scaled(Vector3.ONE * PILE_SCALE), Vector3(DECK_SPOT.x, y, DECK_SPOT.y))


static func discard_slot(index: int) -> Transform3D:
	# 弃牌堆里从下往上数第 index 张(正面朝上):确定性的稍乱(各端一致、同一张牌不会因为后面又压上牌而挪动)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["discard", index])
	var off := Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * DISCARD_JITTER.x
	var rot := rng.randf_range(-1, 1) * DISCARD_JITTER.y
	var y := SeatLayout.FELT_TOP + stack_height(index) + CARD_STEP * 0.5 + 0.0003
	return Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * PILE_SCALE), Vector3(DISCARD_SPOT.x + off.x, y, DISCARD_SPOT.y + off.y))


static func peek_slot(i: int, count: int) -> Transform3D:
	# 镜头坐标(镜头看 -Z):牌面朝镜头、牌顶朝上,三张一字排开
	var x := (i - (count - 1) / 2.0) * PEEK_SPACING
	return Transform3D(CardTable.FAN_BASIS.scaled(Vector3.ONE * PEEK_SCALE), Vector3(x, PEEK_DROP, -PEEK_DISTANCE))


static func facing(normal: Vector3) -> Basis:
	# 竖立的牌:牌面法线朝 normal(取水平分量),牌顶朝上(同 CardTable.FAN_BASIS 的取法)
	var n := Vector3(normal.x, 0, normal.z).normalized()
	if n.length_squared() < 0.001:
		n = Vector3.BACK
	return Basis(n.cross(Vector3.DOWN), n, Vector3.DOWN)


static func bomb_show(seat_angle: float, seat_radius: float) -> Transform3D:
	# 摸到炸弹:炸弹牌立在摸牌人面前、牌面朝桌心(特写机位从桌心拍过去)
	var dir := SeatLayout.direction(seat_angle)
	var right := Vector3.UP.cross(dir).normalized()   # 摸牌人的右手边(同 TableWorld.seat_right)
	var pos := dir * (seat_radius - BOMB_SHOW_FROM_SEAT) + right * BOMB_SHOW_SIDE + Vector3(0, SeatLayout.TABLE_TOP + BOMB_SHOW_HEIGHT, 0)
	return Transform3D(facing(-dir).scaled(Vector3.ONE * BOMB_SHOW_SCALE), pos)


static func bomb_view(world: TableWorld, pid: int) -> Transform3D:
	# 摸到炸弹的特写机位:从桌心斜上方看摸牌人的脸,炸弹牌立在他面前、偏画面下方
	var dir := SeatLayout.direction(world.seat_angle_now(pid))
	var head := world.head_position(pid)
	var pos := dir * (world.seat_radius - 1.55) + Vector3(0, 1.45, 0) + world.seat_right(pid) * -0.3
	return Transform3D(Basis.looking_at(head + Vector3(0, -0.22, 0) - pos, Vector3.UP), pos)
