class_name BarBack
# 背吧(靠墙的酒架):下面一排矮柜(正面嵌凸板,上面一层清漆台面,台面上两只躺在木托上的酒桶,
# 桶头装黄铜龙头),上面三层酒架——竖拼木板的背板、两侧与正中三块立板(正面贴半圆车木壁柱)、
# 每层搁板下两对涡卷托架,顶上一道横板、一排齿饰和出挑的檐口。坐标为吧台本地。


const HALF_LENGTH := 1.62
const CABINET_DEPTH := 0.44
const CABINET_TOP := 0.96            # 矮柜台面顶
const CABINET_PLINTH := 0.08
const SHELF_DEPTH := 0.28
const SHELVES := [1.36, 1.73, 2.1]   # 各层搁板面的高度(最低一层在酒桶上方)
const SHELF_THICKNESS := 0.035
const UPRIGHT := 0.045               # 立板厚
const FRIEZE := Vector2(2.44, 2.58)  # 檐口下的横板
const CROWN_RISE := 0.12             # 檐口高(顶 = FRIEZE.y + CROWN_RISE = 2.7)
const CROWN_REACH := 0.09            # 檐口出挑
const DENTIL := Vector3(0.02, 0.026, 0.022)
const DENTIL_SPACING := 0.05
const BRACKET_Z := [-1.2, -0.42, 0.42, 1.2]
const KEG_CLEAR_Z := -0.6             # 最低一层搁板在酒桶上方的那一段不装托架
const DOORS := 6
const KEG_Z := [-1.3, -0.9]
const KEG_RADIUS := Vector2(0.135, 0.158)   # 桶头、桶腰的半径
const KEG_LENGTH := 0.4
const KEG_X := 0.22
const CRADLE_HEIGHT := 0.035
const ALONG := Vector3(0, 0, -1)     # 部件 X 沿墙摆放时的方向(配合 Y 向上,部件 +Z 朝房间)


static func add_to(batch: MeshBatch) -> void:
	_cabinet(batch)
	_shelving(batch)
	_crown(batch)
	for z in KEG_Z:
		_keg(batch, Vector3(KEG_X, CABINET_TOP + CRADLE_HEIGHT + KEG_RADIUS.y, z))


# —— 矮柜 ——

static func _cabinet(batch: MeshBatch) -> void:
	var wood := BarMaterials.wood()
	var length := HALF_LENGTH * 2.0
	var body := Vector3(length, CABINET_TOP - 0.04 - CABINET_PLINTH, CABINET_DEPTH)
	batch.add_arrays(MeshShapes.rounded_box(body, 0.008, 1), wood,
		BarShapes.frame(ALONG, Vector3.UP, Vector3(body.z / 2.0, CABINET_PLINTH + body.y / 2.0, 0)), Color.WHITE, 0.21)
	var plinth := Vector3(length - 0.04, CABINET_PLINTH, CABINET_DEPTH - 0.04)
	batch.add_arrays(MeshShapes.rounded_box(plinth, 0.005, 1), wood,
		BarShapes.frame(ALONG, Vector3.UP, Vector3(plinth.z / 2.0, plinth.y / 2.0, 0)), Color(0.45, 0.4, 0.38), 0.22)
	var top := Vector3(length + 0.04, 0.04, CABINET_DEPTH + 0.03)
	batch.add_arrays(MeshShapes.rounded_box(top, 0.012, 2), BarMaterials.top(),
		BarShapes.frame(ALONG, Vector3.UP, Vector3(top.z / 2.0, CABINET_TOP - 0.02, 0)), Color.WHITE, 0.23)
	# 柜门:每扇一块凸板 + 一颗黄铜拉手
	var door_w := length / DOORS
	var door_h := body.y - 0.08
	var rect := PackedVector2Array([Vector2(-door_w / 2.0 + 0.03, -door_h / 2.0), Vector2(door_w / 2.0 - 0.03, -door_h / 2.0),
		Vector2(door_w / 2.0 - 0.03, door_h / 2.0), Vector2(-door_w / 2.0 + 0.03, door_h / 2.0)])
	var panel := MeshShapes.extrude(rect, 0.024, 0.01)
	for i in DOORS:
		var z := -HALF_LENGTH + door_w * (i + 0.5)
		var center := Vector3(CABINET_DEPTH + 0.006, CABINET_PLINTH + body.y / 2.0, z)
		batch.add_arrays(panel, BarMaterials.wood_turned(), BarShapes.frame(ALONG, Vector3.UP, center), Color.WHITE, 0.3 + i * 0.05)
		var knob_z := z + (door_w / 2.0 - 0.07) * (1.0 if i % 2 == 0 else -1.0)
		batch.add_part(MeshKit.sphere(0.012, 8), WorldMaterials.brass(),
			Vector3(CABINET_DEPTH + 0.026, CABINET_PLINTH + body.y * 0.62, knob_z))


# —— 酒架 ——

static func _shelving(batch: MeshBatch) -> void:
	var height := FRIEZE.y - CABINET_TOP
	var back := Vector3(0.02, height, HALF_LENGTH * 2.0)
	batch.add_part(MeshKit.box(back), BarMaterials.panel(), Vector3(back.x / 2.0, CABINET_TOP + height / 2.0, 0))
	for z in [-HALF_LENGTH + UPRIGHT / 2.0, 0.0, HALF_LENGTH - UPRIGHT / 2.0]:
		var board := Vector3(SHELF_DEPTH, height, UPRIGHT)
		batch.add_part(MeshShapes.rounded_box(board, 0.008, 1), BarMaterials.wood_turned(),
			Vector3(SHELF_DEPTH / 2.0, CABINET_TOP + height / 2.0, z))
		batch.add_arrays(BarShapes.pilaster(FRIEZE.x - CABINET_TOP, UPRIGHT * 0.5), BarMaterials.wood_turned(),
			BarShapes.frame(ALONG, Vector3.UP, Vector3(SHELF_DEPTH, CABINET_TOP, z)), Color.WHITE, 0.4)
	var bracket := BarShapes.scroll_bracket(SHELF_DEPTH - 0.04, 0.13, 0.03)
	for y in SHELVES:
		var shelf := Vector3(HALF_LENGTH * 2.0, SHELF_THICKNESS, SHELF_DEPTH)
		batch.add_arrays(MeshShapes.rounded_box(shelf, 0.008, 2), BarMaterials.wood(),
			BarShapes.frame(ALONG, Vector3.UP, Vector3(SHELF_DEPTH / 2.0, y - SHELF_THICKNESS / 2.0, 0)), Color.WHITE, y)
		for z in BRACKET_Z:
			if y == SHELVES[0] and z < KEG_CLEAR_Z:
				continue
			# 托架的侧影在部件 XY 平面(x 朝外 = 吧台本地 +X 朝房间),厚度沿墙,不用转
			batch.add_part(bracket, BarMaterials.wood(), Vector3(0.02, y - SHELF_THICKNESS, z))


static func _crown(batch: MeshBatch) -> void:
	# 横板 + 齿饰 + 檐口:檐口截面从横板正面向上、向外出挑,顶面一直铺回墙根
	var wood := BarMaterials.wood()
	var face := SHELF_DEPTH + 0.02
	var frieze := Vector3(HALF_LENGTH * 2.0 + 0.04, FRIEZE.y - FRIEZE.x, 0.03)
	batch.add_arrays(MeshShapes.rounded_box(frieze, 0.006, 1), wood,
		BarShapes.frame(ALONG, Vector3.UP, Vector3(face - frieze.z / 2.0, (FRIEZE.x + FRIEZE.y) / 2.0, 0)), Color.WHITE, 0.5)
	var count := int((HALF_LENGTH * 2.0) / DENTIL_SPACING)
	for i in count:
		var z := -HALF_LENGTH + DENTIL_SPACING * (i + 0.5)
		batch.add_part(MeshKit.box(DENTIL), wood, Vector3(face + DENTIL.z / 2.0, FRIEZE.y - DENTIL.y / 2.0 - 0.012, z))
	var r := CROWN_REACH
	var profile := PackedVector2Array([Vector2(-face, 0.0), Vector2(0.0, 0.0), Vector2(0.012, 0.004), Vector2(0.014, 0.014),
		Vector2(0.02, 0.018)])
	profile.append_array(BarShapes.arc(Vector2(0.02, 0.018 + r * 0.7), r * 0.7, 270.0, 360.0, 6).slice(1, 7))
	profile.append_array([Vector2(r, CROWN_RISE * 0.8), Vector2(r, CROWN_RISE), Vector2(-face, CROWN_RISE)])
	batch.add_arrays(BarShapes.sweep(profile, HALF_LENGTH * 2.0 + 0.1), wood,
		BarShapes.frame(ALONG, Vector3.UP, Vector3(face, FRIEZE.y, 0)), Color.WHITE, 0.6)


# —— 酒桶 ——

static func _keg(batch: MeshBatch, center: Vector3) -> void:
	# 桶身是鼓肚的回转体(两头开口),桶头另装一块嵌进去的圆板;四道铁箍;正面桶头一只黄铜龙头;
	# 生成时桶轴沿 Y,绕 Z 转 -90° 躺下、桶轴朝房间
	var half := KEG_LENGTH / 2.0
	var r := KEG_RADIUS
	var body := PackedVector2Array()
	for k in 7:
		var t := -1.0 + 2.0 * k / 6.0
		body.append(Vector2(lerpf(r.y, r.x, t * t), t * half))
	var lying := Vector3(0, 0, -90)
	batch.add_part(MeshShapes.lathe(body, 20), BarMaterials.keg(), center, lying)
	for side in [-1.0, 1.0]:
		batch.add_part(MeshKit.cylinder(r.x - 0.012, r.x - 0.012, 0.02, 20), BarMaterials.keg(),
			center + Vector3(side * (half - 0.022), 0, 0), lying)
	for y in [-half + 0.03, -half * 0.45, half * 0.45, half - 0.03]:
		var radius := lerpf(r.y, r.x, pow(y / half, 2.0)) + 0.004
		var hoop := PackedVector2Array([Vector2(radius, y - 0.013), Vector2(radius, y + 0.013)])
		batch.add_part(MeshShapes.lathe(hoop, 20), WorldMaterials.iron(), center, lying)
	_spigot(batch, center + Vector3(half - 0.01, -0.03, 0))
	for x in [-0.12, 0.12]:
		_cradle(batch, Vector3(center.x + x, CABINET_TOP, center.z))


static func _spigot(batch: MeshBatch, at: Vector3) -> void:
	var brass := WorldMaterials.brass()
	batch.add_part(MeshKit.cylinder(0.022, 0.026, 0.012, 12), brass, at, Vector3(0, 0, -90))
	batch.add_part(MeshKit.cylinder(0.011, 0.012, 0.07, 10), brass, at + Vector3(0.04, 0, 0), Vector3(0, 0, -90))
	batch.add_part(MeshKit.cylinder(0.009, 0.007, 0.04, 8), brass, at + Vector3(0.07, -0.02, 0))
	batch.add_part(MeshKit.box(Vector3(0.012, 0.05, 0.012)), brass, at + Vector3(0.055, 0.03, 0))


static func _cradle(batch: MeshBatch, at: Vector3) -> void:
	# 木托:方木块,顶上挖出与桶腰同半径的弧槽
	var w := 0.16
	var notch := BarShapes.arc(Vector2(0, CRADLE_HEIGHT + KEG_RADIUS.y), KEG_RADIUS.y - 0.002, -60.0, -120.0, 6)
	var outline := PackedVector2Array([Vector2(-w, 0), Vector2(w, 0), Vector2(w, CRADLE_HEIGHT + 0.07)])
	for p in notch:
		if p.x < w and p.x > -w:
			outline.append(p)
	outline.append(Vector2(-w, CRADLE_HEIGHT + 0.07))
	batch.add_arrays(MeshShapes.extrude(outline, 0.04, 0.006), BarMaterials.wood(),
		BarShapes.frame(ALONG, Vector3.UP, at), Color(0.8, 0.72, 0.66), at.z)
