extends GutTest
# 性能预算:模型加细节不能拖慢帧率。各区域的网格表面数(≈ 每帧绘制调用)与三角形数不超过上限,
# 投射阴影的三角形总数有上限(阴影要按光源再画几遍);同物种的酒客共用网格资源
# (中途加入、每局复活时直接取用缓存,不在对局中重新拼装)。
# 预算对照:重做前整间酒馆 + 4 名酒客共 745 个表面、约 8.9 万个三角形,每个部件一次绘制调用。


# 区域根节点名 -> [表面数上限, 三角形上限]
const AREA_BUDGETS := {
	"Room": [24, 30000],
	"Decor": [30, 40000],
	"Fireplace": [30, 30000],
	"Bar": [24, 45000],
	"TavernTable": [30, 30000],
	"Sconces": [16, 10000],
}
const PATRON_BUDGET := [40, 25000]     # 每名酒客(含椅子,不含手牌)
const REVOLVER_BUDGET := [8, 6000]     # 每把左轮
const SHADOW_TRIANGLES := 200000       # 4 人局整个场景里投射阴影的三角形总数

var tavern: Tavern
var world: TableWorld


func before_each():
	tavern = Tavern.new()
	add_child_autofree(tavern)
	world = TableWorld.new(tavern)
	tavern.table_root.add_child(world)
	world.arrange([{"pid": 1}, {"pid": 2}, {"pid": 3}, {"pid": 4}], 1, true, true)


func test_each_tavern_area_stays_within_budget():
	for area in AREA_BUDGETS:
		var root := tavern.get_node_or_null(area)
		assert_not_null(root, "区域根节点 %s 存在" % area)
		if root == null:
			continue
		var stats := _stats(root)
		assert_lte(stats["surfaces"], AREA_BUDGETS[area][0], "%s 的表面数(绘制调用)" % area)
		assert_lte(stats["triangles"], AREA_BUDGETS[area][1], "%s 的三角形数" % area)


func test_each_patron_stays_within_budget():
	for pid in world.patrons:
		var stats := _stats(world.patrons[pid])
		assert_lte(stats["surfaces"], PATRON_BUDGET[0], "酒客 %d 的表面数(绘制调用)" % pid)
		assert_lte(stats["triangles"], PATRON_BUDGET[1], "酒客 %d 的三角形数" % pid)


func test_each_revolver_stays_within_budget():
	for pid in world.revolvers:
		var stats := _stats(world.revolvers[pid])
		assert_lte(stats["surfaces"], REVOLVER_BUDGET[0], "左轮 %d 的表面数" % pid)
		assert_lte(stats["triangles"], REVOLVER_BUDGET[1], "左轮 %d 的三角形数" % pid)


func test_shadow_casting_triangles_stay_within_budget():
	assert_lte(_stats(tavern)["shadow_triangles"], SHADOW_TRIANGLES, "投射阴影的三角形总数")


func test_patrons_of_one_species_share_their_meshes():
	var a := Patron.new(0)
	var b := Patron.new(0)
	add_child_autofree(a)
	add_child_autofree(b)
	var meshes_a := _meshes(a)
	var meshes_b := _meshes(b)
	assert_eq(meshes_a.size(), meshes_b.size(), "同物种酒客的部件数一致")
	var shared := 0
	for i in mini(meshes_a.size(), meshes_b.size()):
		if meshes_a[i] == meshes_b[i]:
			shared += 1
	assert_eq(shared, meshes_a.size(), "同物种酒客的每个网格都取自缓存(%d/%d 共用)" % [shared, meshes_a.size()])


# —— 统计 ——

static func _stats(root: Node) -> Dictionary:
	var result := {"surfaces": 0, "triangles": 0, "shadow_triangles": 0}
	var nodes: Array = [root] if root is MeshInstance3D else []
	nodes.append_array(root.find_children("*", "MeshInstance3D", true, false))
	for node in nodes:
		var inst := node as MeshInstance3D
		if inst.mesh == null or not inst.visible or _is_card(inst):
			continue
		var triangles := 0
		for i in inst.mesh.get_surface_count():
			var arrays := inst.mesh.surface_get_arrays(i)
			var indices: Variant = arrays[Mesh.ARRAY_INDEX]
			triangles += (indices as PackedInt32Array).size() / 3 if indices != null \
				else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		result["surfaces"] += inst.mesh.get_surface_count()
		result["triangles"] += triangles
		if inst.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			result["shadow_triangles"] += triangles
	return result


static func _is_card(node: Node) -> bool:
	# 手牌、桌上的牌由 CardTable 管理,不算在酒客/牌桌的模型预算里
	var parent := node.get_parent()
	while parent != null:
		if parent is Card3D:
			return true
		parent = parent.get_parent()
	return false


static func _meshes(root: Node) -> Array:
	var meshes := []
	for node in root.find_children("*", "MeshInstance3D", true, false):
		meshes.append((node as MeshInstance3D).mesh)
	return meshes
