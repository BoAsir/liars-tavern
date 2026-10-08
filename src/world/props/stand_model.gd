class_name StandModel
# 桌心目标牌立架的网格配方(纯数组运算):固定不转的车削底座 + 会转的立轴与叉形夹。
# 坐标都在 TargetStand(桌面 TABLE_TOP 处)局部;底座在内部抬高到毡面(FELT_TOP)上。


const FELT := SeatLayout.FELT_TOP - SeatLayout.TABLE_TOP
const SKIRT_RADIUS := 0.044   # 裙边很矮(≤ 2 mm):牌堆里有少量牌会伸进 r < 0.045
const BODY_TOP := FELT + 0.019
const CLIP_BOTTOM := 0.091    # 叉形夹叶片下端(牌底在 STAND_HEIGHT − 0.006 = 0.094)
const LEAF_OFFSET := 0.0012   # 两片叶片在牌法线方向(立架局部 Z)的偏移


static func base(f: MeshForge) -> void:
	# s0 = 深色木:ogee 线脚的车削主体(r ≤ 0.030)+ 矮裙边;s1 = prop:黄铜嵌线与轴承帽
	f.surface(&"wood")
	f.lathe(PackedVector2Array([Vector2(0.0, FELT), Vector2(SKIRT_RADIUS, FELT), Vector2(SKIRT_RADIUS, FELT + 0.0014),
		Vector2(SKIRT_RADIUS - 0.0015, FELT + 0.0019), Vector2(0.031, FELT + 0.0019), Vector2(0.030, FELT + 0.0035),
		Vector2(0.0285, FELT + 0.0055), Vector2(0.025, FELT + 0.0072), Vector2(0.0215, FELT + 0.0092),
		Vector2(0.0205, FELT + 0.0118), Vector2(0.0175, FELT + 0.0142), Vector2(0.0125, FELT + 0.0158),
		Vector2(0.0105, FELT + 0.0172), Vector2(0.0098, BODY_TOP), Vector2(0.0, BODY_TOP)]),
		48, PackedInt32Array([1, 2, 4, 13]))
	f.surface(&"metal")
	WorldMaterials.paint_prop(f, "brass")
	f.lathe(PackedVector2Array([Vector2(0.0365, FELT + 0.0019), Vector2(0.0372, FELT + 0.0025), Vector2(0.0395, FELT + 0.0025),
		Vector2(0.0402, FELT + 0.0019)]), 48)
	f.lathe(PackedVector2Array([Vector2(0.0, BODY_TOP - 0.0005), Vector2(0.0085, BODY_TOP - 0.0005), Vector2(0.0082, BODY_TOP + 0.0012),
		Vector2(0.006, BODY_TOP + 0.0028), Vector2(0.0, BODY_TOP + 0.0034)]), 24, PackedInt32Array([1]))


static func clip(f: MeshForge, top: float) -> void:
	# 立轴(r 4.5 mm,两道珠环)+ 叉形夹:两片 1 mm 黄铜叶片夹住牌底 6 mm(不投影)
	var xf := MeshForge.xf
	f.surface(&"metal")
	WorldMaterials.paint_prop(f, "brass")
	var y0 := BODY_TOP
	f.lathe(PackedVector2Array([Vector2(0.0045, y0), Vector2(0.0045, 0.033), Vector2(0.0065, 0.0355), Vector2(0.0045, 0.038),
		Vector2(0.0042, 0.080), Vector2(0.0062, 0.0825), Vector2(0.0042, 0.085), Vector2(0.004, CLIP_BOTTOM - 0.002),
		Vector2(0.0, CLIP_BOTTOM - 0.002)]), 16)
	f.box(Vector3(0.026, 0.0035, 0.0044), xf.call(Vector3(0, CLIP_BOTTOM - 0.0005, 0)))
	for side in [-1.0, 1.0]:
		f.box(Vector3(0.022, top - CLIP_BOTTOM + 0.002, 0.001), xf.call(Vector3(0, (top + CLIP_BOTTOM) / 2.0 + 0.001, side * LEAF_OFFSET)))
		f.sphere(0.0016, 8, xf.call(Vector3(0, top - 0.002, side * (LEAF_OFFSET + 0.0006))))
