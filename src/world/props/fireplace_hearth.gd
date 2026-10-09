class_name FireplaceHearth
# 炉床上的家什:右边一副火钳架(铸铁座、顶上黄铜球,挂着火铲、炉刷、拨火棍),左边码着一小堆劈柴,
# 炉膛左壁上一根可以转动的铁吊臂,S 钩挂着一把铜水壶悬在火上。
# 火钳架与柴堆在炉口外、离炉火光很近,投影能把它们"放"在炉床上(add_casters,并进砌体网格);
# 吊臂与水壶在炉膛里,不投影(add_details)。坐标为壁炉本地。


const TOOLS_AT := Vector3(0.98, 0.0, 0.75)
const TOOLS_HEIGHT := 0.6
const HOOK_SPREAD := 0.07
# 柴堆:[截面, 半径, 长度, 位置(相对柴堆原点), 绕长轴的转角, 种子]
const PILE_AT := Vector3(-0.86, 0.0, 0.0)
const PILE := [
	["half", 0.052, 0.42, Vector3(0.0, 0.0, 0.705), 180.0, 21],
	["round", 0.05, 0.4, Vector3(0.03, 0.0, 0.815), 0.0, 22],
	["quarter", 0.062, 0.44, Vector3(-0.02, 0.085, 0.76), 200.0, 23],
]
const CRANE_PIVOT := Vector3(-0.47, 0.0, 0.43)
const CRANE_HEIGHT := Vector2(0.34, 0.84)    # 吊臂立柱的上下端
const CRANE_REACH := Vector3(0.27, 0.0, -0.04)
const KETTLE_DROP := 0.13                    # 水壶提梁顶离吊臂


static func add_casters(batch: MeshBatch) -> void:
	_tool_stand(batch, TOOLS_AT + Vector3(0, TavernFireplace.HEARTH_TOP, 0))
	_log_pile(batch)


static func add_details(batch: MeshBatch) -> void:
	_crane(batch)


# —— 火钳架 ——

static func _tool_stand(batch: MeshBatch, base: Vector3) -> void:
	var iron := WorldMaterials.iron()
	var brass := WorldMaterials.brass()
	var foot := PackedVector2Array([Vector2(0, 0), Vector2(0.07, 0), Vector2(0.07, 0.01), Vector2(0.05, 0.022),
		Vector2(0.02, 0.036), Vector2(0.012, 0.05), Vector2(0, 0.05)])
	batch.add_part(MeshShapes.lathe(foot, 14), iron, base)
	batch.add_part(MeshKit.cylinder(0.008, 0.008, TOOLS_HEIGHT - 0.05, 8), iron,
		base + Vector3(0, 0.05 + (TOOLS_HEIGHT - 0.05) / 2.0, 0))
	batch.add_part(MeshKit.sphere(0.017, 10), brass, base + Vector3(0, TOOLS_HEIGHT + 0.012, 0))
	# 顶上的横担两头弯成挂钩,前面再伸出一个
	var s := HOOK_SPREAD
	var top := TOOLS_HEIGHT - 0.015
	var bar := PackedVector3Array([Vector3(-s, top - 0.03, 0), Vector3(-s - 0.008, top - 0.008, 0),
		Vector3(-s + 0.012, top, 0), Vector3(s - 0.012, top, 0), Vector3(s + 0.008, top - 0.008, 0),
		Vector3(s, top - 0.03, 0)])
	batch.add_part(MeshShapes.tube(bar, 0.005, 6), iron, base)
	var arm := PackedVector3Array([Vector3(0, top, 0), Vector3(0, top, s - 0.012), Vector3(0, top - 0.008, s + 0.008),
		Vector3(0, top - 0.03, s)])
	batch.add_part(MeshShapes.tube(arm, 0.005, 6), iron, base)
	var hang := top - 0.035
	_shovel(batch, base + Vector3(-s, hang, 0))
	_brush(batch, base + Vector3(s, hang, 0))
	_poker(batch, base + Vector3(0, hang, s))


static func _tool_shaft(batch: MeshBatch, top: Vector3, length: float) -> void:
	# 每件家什:挂环(黄铜)+ 铁杆
	batch.add_part(MeshKit.torus(0.008, 0.013, 12), WorldMaterials.brass(), top, Vector3(90, 0, 0))
	batch.add_part(MeshKit.cylinder(0.0055, 0.0055, length, 6), WorldMaterials.iron(),
		top - Vector3(0, 0.013 + length / 2.0, 0))


static func _shovel(batch: MeshBatch, top: Vector3) -> void:
	_tool_shaft(batch, top, 0.42)
	var blade := MeshShapes.rounded_box(Vector3(0.075, 0.095, 0.006), 0.003, 1)
	batch.add_part(blade, WorldMaterials.iron(), top - Vector3(0, 0.49, 0), Vector3(0, 90, 0))


static func _brush(batch: MeshBatch, top: Vector3) -> void:
	_tool_shaft(batch, top, 0.4)
	batch.add_part(MeshKit.cylinder(0.011, 0.011, 0.02, 8), WorldMaterials.brass(), top - Vector3(0, 0.42, 0))
	batch.add_part(MeshKit.cylinder(0.02, 0.028, 0.09, 10), WorldMaterials.iron(), top - Vector3(0, 0.475, 0))


static func _poker(batch: MeshBatch, top: Vector3) -> void:
	_tool_shaft(batch, top, 0.43)
	var tip := PackedVector3Array([Vector3(0, -0.44, 0), Vector3(0, -0.5, 0), Vector3(0, -0.52, 0.012),
		Vector3(0, -0.505, 0.03)])
	batch.add_part(MeshShapes.tube(tip, PackedFloat32Array([0.0055, 0.0055, 0.005, 0.004]), 6), WorldMaterials.iron(), top)


# —— 柴堆 ——

static func _log_pile(batch: MeshBatch) -> void:
	# 横着码在炉床左前方(炉口外,柴不烧焦,露出浅色劈面与年轮)
	var logs := FireplaceMaterials.logs()
	for spec in PILE:
		var at: Vector3 = PILE_AT + spec[3] + Vector3(0, TavernFireplace.HEARTH_TOP + spec[1], 0)
		batch.add_part(FireplaceLogs.log_arrays(spec[1], spec[2], spec[0], spec[5]), logs, at, Vector3(0, 90, spec[4]))


# —— 吊臂与水壶 ——

static func _crane(batch: MeshBatch) -> void:
	# 立柱靠两个铁环卡在炉膛左壁上,横臂伸向火的上方,一根斜撑;S 钩挂着铜水壶
	var iron := WorldMaterials.iron()
	var pivot := CRANE_PIVOT
	var low := pivot + Vector3(0, CRANE_HEIGHT.x, 0)
	var high := pivot + Vector3(0, CRANE_HEIGHT.y, 0)
	batch.add_part(MeshShapes.tube(PackedVector3Array([low, high]), 0.009, 6), iron)
	for y in [CRANE_HEIGHT.x + 0.04, CRANE_HEIGHT.y - 0.04]:
		batch.add_part(MeshKit.box(Vector3(0.05, 0.018, 0.016)), iron, pivot + Vector3(-0.025, y, 0))
	var arm_end := high - Vector3(0, 0.03, 0) + CRANE_REACH
	batch.add_part(MeshShapes.tube(PackedVector3Array([high - Vector3(0, 0.03, 0), arm_end]), 0.008, 6), iron)
	var brace_start := pivot + Vector3(0, CRANE_HEIGHT.x + 0.12, 0)
	batch.add_part(MeshShapes.tube(PackedVector3Array([brace_start, high - Vector3(0, 0.03, 0) + CRANE_REACH * 0.6]),
		0.006, 6), iron)
	var hook := PackedVector3Array([arm_end + Vector3(0, 0.01, 0), arm_end + Vector3(0.012, -0.01, 0),
		arm_end + Vector3(0, -0.035, 0), arm_end + Vector3(-0.012, -0.06, 0), arm_end + Vector3(0, -0.08, 0)])
	batch.add_part(MeshShapes.tube(hook, 0.004, 6), iron)
	_kettle(batch, arm_end - Vector3(0, KETTLE_DROP, 0))


static func _kettle(batch: MeshBatch, handle_top: Vector3) -> void:
	# 矮胖的铜壶:壶身、壶盖与盖钮、弯弯的壶嘴、铁提梁
	var copper := FireplaceMaterials.copper()
	var body_top := handle_top - Vector3(0, 0.07, 0)
	var base := body_top - Vector3(0, 0.1, 0)
	var body := PackedVector2Array([Vector2(0, 0), Vector2(0.06, 0), Vector2(0.085, 0.025), Vector2(0.09, 0.055),
		Vector2(0.075, 0.085), Vector2(0.045, 0.1), Vector2(0.045, 0.1), Vector2(0, 0.1)])
	batch.add_part(MeshShapes.lathe(body, 16), copper, base)
	var lid := PackedVector2Array([Vector2(0, 0), Vector2(0.047, 0), Vector2(0.04, 0.014), Vector2(0.012, 0.022),
		Vector2(0.014, 0.034), Vector2(0, 0.038)])
	batch.add_part(MeshShapes.lathe(lid, 14), copper, body_top)
	var spout := PackedVector3Array([base + Vector3(0.07, 0.04, 0), base + Vector3(0.11, 0.07, 0),
		base + Vector3(0.13, 0.1, 0), base + Vector3(0.15, 0.115, 0)])
	batch.add_part(MeshShapes.tube(spout, PackedFloat32Array([0.016, 0.011, 0.008, 0.007]), 8), copper)
	var handle := PackedVector3Array()
	for k in 9:
		var a := PI * k / 8.0
		handle.append(body_top + Vector3(0, sin(a) * 0.07, cos(a) * 0.055))
	batch.add_part(MeshShapes.tube(handle, 0.004, 6), WorldMaterials.iron())
