class_name DdzLayout
# 斗地主牌桌布局(纯函数):桌心扣着的 3 张底牌与发牌处、每人面前的出牌行、「不出」牌子的位置、牌扇的显示顺序。
# 坐标是牌桌世界的(TableWorld 下,本机座位在 +Z;SeatLayout.direction 的角度约定)。3 人坐骗子酒馆的小桌:
# 本机的出牌行在桌心靠近自己这一侧,两位对手的在各自面前;桌上的牌一律按本机视角正立(牌顶朝 -Z),
# 一行里大的在左(同手牌条),重叠排开,太长就挤紧(最宽 MAX_ROW),离烛台(半径 0.7)和别人的行都有空隙。


const TABLE_FOCUS := Vector3(0, SeatLayout.TABLE_TOP + 0.05, 0)   # 酒客平时看向桌心
const CARD_STEP := 0.0011
const LAYER_STEP := 0.0009                 # 一行里后面的牌叠高一点(重叠处不闪烁)
const DECK_SPOT := Vector2(0.0, 0.07)      # 发牌处 / 底牌中心 (x, z)
const DECK_SCALE := 1.1
const BOTTOM_GAP := 0.155                  # 三张底牌之间的距离
const BOTTOM_SCALE := 1.15
const BOTTOM_TILT := [0.06, -0.03, 0.05]   # 底牌稍稍歪一点(弧度),不像摆得太整齐
const PLAY_SCALE := 1.15
const PLAY_STEP := 0.062                   # 出牌行相邻两张的距离(重叠排开)
const MAX_ROW := 0.5                       # 一行最宽这么宽(两端牌心之间)
const MY_ROW_RADIUS := 0.37                # 本机出牌行离桌心
const ROW_RADIUS := 0.4                    # 对手出牌行离桌心
const PASS_LIFT := 0.11                    # 「不出」牌子悬在出牌行上方
const ALARM_SIDE := 0.32                   # 报警徽章挂在头顶偏右
const SWEEP_SCALE := 0.4                   # 清桌:牌收向桌心时缩小到这么大
const FAN_SCALE_ME := 0.82                 # 越肩时自己的牌扇缩小(同炸弹猫小桌)
const FAN_RAISE_ME := 0.13


# —— 发牌处与底牌 ——

static func deck_transform(count := 54) -> Transform3D:
	# 牌背朝上的一摞的顶上那张(发牌时牌从这里飞出去)
	var y := SeatLayout.FELT_TOP + minf(count, 54) * CARD_STEP * 0.5 + 0.0004
	return Transform3D(Basis(Vector3.BACK, PI).scaled(Vector3.ONE * DECK_SCALE), Vector3(DECK_SPOT.x, y, DECK_SPOT.y))


static func bottom_slot(i: int, face_up := false) -> Transform3D:
	# 第 i 张底牌(0–2):扣着(牌背朝上)或翻开(正面朝上,牌顶朝 -Z)
	var x := DECK_SPOT.x + (i - 1) * BOTTOM_GAP
	var tilt: float = BOTTOM_TILT[clampi(i, 0, BOTTOM_TILT.size() - 1)]
	var basis := Basis(Vector3.UP, tilt)
	if not face_up:
		basis = basis * Basis(Vector3.BACK, PI)
	var y := SeatLayout.FELT_TOP + Card3D.THICKNESS * BOTTOM_SCALE / 2.0 + 0.0004 + i * LAYER_STEP
	return Transform3D(basis.scaled(Vector3.ONE * BOTTOM_SCALE), Vector3(x, y, DECK_SPOT.y))


# —— 出牌行 ——

static func row_center(angle: float, mine: bool) -> Vector3:
	var r := MY_ROW_RADIUS if mine else ROW_RADIUS
	var d := SeatLayout.direction(angle) * r
	return Vector3(d.x, SeatLayout.FELT_TOP, d.z)


static func row_step(count: int) -> float:
	if count <= 1:
		return PLAY_STEP
	return minf(PLAY_STEP, MAX_ROW / float(count - 1))


static func play_slot(angle: float, mine: bool, i: int, count: int) -> Transform3D:
	# 出牌行里第 i 张(从左往右)
	var c := row_center(angle, mine)
	var step := row_step(count)
	var x := c.x + (i - (count - 1) / 2.0) * step
	var y := SeatLayout.FELT_TOP + Card3D.THICKNESS * PLAY_SCALE / 2.0 + 0.0005 + i * LAYER_STEP
	return Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * PLAY_SCALE), Vector3(x, y, c.z))


static func pass_point(angle: float, mine: bool) -> Vector3:
	return row_center(angle, mine) + Vector3(0, PASS_LIFT, 0)


static func sweep_point() -> Vector3:
	return Vector3(DECK_SPOT.x, SeatLayout.FELT_TOP + 0.03, DECK_SPOT.y - 0.08)


static func row_order(cards: Array) -> Array:
	# 摆在桌上的顺序:同点数张数多的在前(三带一的三张、飞机的机身先摆),同张数点数大的在前
	var counts := {}
	for c in cards:
		if DdzHand.is_card(c):
			var r := DdzHand.rank(c)
			counts[r] = counts.get(r, 0) + 1
	var out := cards.filter(DdzHand.is_card)
	out.sort_custom(func(a: int, b: int) -> bool:
		var ca: int = counts[DdzHand.rank(a)]
		var cb: int = counts[DdzHand.rank(b)]
		if ca != cb:
			return ca > cb
		return a > b)
	return out


# —— 牌扇 ——

static func fan_index(i: int, count: int) -> int:
	# 手牌按牌 id 升序存放(私有视图的下标);牌扇与手牌条里大的在左:第 i 张摆在第 count-1-i 个位置
	return count - 1 - i


static func fan_slot(i: int, count: int, lift := 0.0) -> Transform3D:
	return BombCatLayout.fan_slot(fan_index(i, count), count, lift)
