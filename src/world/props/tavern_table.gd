class_name TavernTable
extends Node3D
# 牌桌一带:圆桌(桌面随半径可变)、桌上烛台(可收起)、桌子正上方的吊灯(摆动由 Tavern 驱动)。
# 造型分别在 TableModel(桌子)、LampModel(吊灯)、TableCandles(烛台)里;这里只管节点、换桌面半径与收起摆设。


const LAMP_DROP := 1.3
const POKER_RADIUS := 1.45   # 德州扑克的大桌:和骗子酒馆的桌面一起在开场预建,换桌时只换网格

var tavern: Tavern
var lamp_pivot: Node3D
var radius := SeatLayout.TABLE_RADIUS

var _solid: MeshInstance3D     # 木、皮:投射阴影
var _trim: MeshInstance3D      # 绒布与黄铜细件:不投影
var _decor: Array[Node3D] = []


func _init(p_tavern: Tavern) -> void:
	tavern = p_tavern
	name = "TavernTable"
	for r in [SeatLayout.TABLE_RADIUS, POKER_RADIUS]:
		TableModel.prebuild(r)
	_build_table()
	lamp_pivot = MeshKit.pivot(self, Vector3(0, Tavern.ROOM_HEIGHT, 0), "LampPivot")
	LampModel.build(lamp_pivot, tavern, LAMP_DROP)
	_decor = TableCandles.build(self, tavern)


func set_radius(p_radius: float) -> void:
	# 桌面、包边、黄铜嵌线、桌布(连同刺绣圈)换成该半径的缓存网格;桌面高度、中柱与桌脚不变
	if is_equal_approx(p_radius, radius):
		return
	radius = p_radius
	_solid.mesh = TableModel.solid_mesh(radius)
	_trim.mesh = TableModel.trim_mesh(radius)


func set_decor_visible(p_visible: bool) -> void:
	# 烛台节点连同挂在下面的烛光一起显隐
	for holder in _decor:
		holder.visible = p_visible


func _build_table() -> void:
	var table := MeshKit.pivot(self, Vector3.ZERO, "Table")
	_solid = MeshBatch.instance(table, TableModel.solid_mesh(radius), {}, "Solid")
	_trim = MeshBatch.instance(table, TableModel.trim_mesh(radius), {}, "Trim", false)
