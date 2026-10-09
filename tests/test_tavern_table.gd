extends GutTest
# 牌桌一带:换桌面半径时桌面、包边、桌布(连同刺绣圈)跟着变、桌面高度不变,来回切换只换缓存好的网格;
# 出牌区上没有高出桌布的东西,桌沿(爪子搭的地方)不高;收起摆设时烛台连同烛光一起藏起来;
# 灯光节点名各不相同(性能探针按名字前缀找灯)。


const PLAY_AREA_CLEARANCE := 0.01   # 出牌区内最高只能高出桌面这么多(黄铜嵌线)
const EDGE_CLEARANCE := 0.025       # 桌沿(爪子搭的地方)最高只能高出桌面这么多
const EPS := 0.0005

var tavern: Tavern
var table: TavernTable


func before_each():
	tavern = Tavern.new()
	add_child_autofree(tavern)
	table = tavern.table


# —— 换桌面半径 ——

func test_both_table_sizes_are_built_at_startup():
	for r in [SeatLayout.TABLE_RADIUS, TavernTable.POKER_RADIUS]:
		assert_true(MeshBatch.is_cached("table_solid:%.3f" % r), "半径 %.2f 的桌面开场就建好" % r)
		assert_true(MeshBatch.is_cached("table_trim:%.3f" % r), "半径 %.2f 的桌布与黄铜件开场就建好" % r)


func test_radius_resizes_the_top_and_felt_but_keeps_the_height():
	for r in [TavernTable.POKER_RADIUS, SeatLayout.TABLE_RADIUS]:
		tavern.set_table_radius(r)
		var top := _aabb_of(_solid().mesh)
		assert_almost_eq(top.size.x / 2.0, r, 0.01, "桌面(含包边)半径跟着换成 %.2f" % r)
		var felt := _felt_aabb()
		assert_almost_eq(felt.size.x / 2.0, TableModel.felt_radius(r), EPS, "桌布半径")
		assert_almost_eq(felt.end.y, SeatLayout.TABLE_TOP + TableModel.FELT_LIFT, EPS, "桌布面高度不随半径变")


func test_felt_embroidery_scales_with_the_felt():
	tavern.set_table_radius(TavernTable.POKER_RADIUS)
	var mat := _felt_material()
	var k := TableModel.felt_radius(TavernTable.POKER_RADIUS) / TableModel.felt_radius(SeatLayout.TABLE_RADIUS)
	for param in TableModel.FELT_RINGS:
		assert_almost_eq(float(mat.get_shader_parameter(param)), TableModel.FELT_RINGS[param] * k, EPS,
			"刺绣圈 %s 按桌布半径等比放大" % param)


func test_switching_back_and_forth_reuses_cached_meshes():
	var solid := _solid().mesh
	var trim := _trim().mesh
	tavern.set_table_radius(TavernTable.POKER_RADIUS)
	var big_solid := _solid().mesh
	assert_ne(big_solid, solid, "大桌换了一套网格")
	tavern.set_table_radius(SeatLayout.TABLE_RADIUS)
	assert_same(_solid().mesh, solid, "换回来还是原来那份网格")
	assert_same(_trim().mesh, trim)
	tavern.set_table_radius(TavernTable.POKER_RADIUS)
	assert_same(_solid().mesh, big_solid, "再换大桌也不重新拼装")


func test_pedestal_stays_and_feet_spread_only_modestly():
	var pedestal := _surface_verts(_solid().mesh, TableModel.turned_wood())
	var reach := _feet_reach()
	tavern.set_table_radius(TavernTable.POKER_RADIUS)
	assert_eq(_surface_verts(_solid().mesh, TableModel.turned_wood()), pedestal, "中柱不随桌面半径变")
	var big_reach := _feet_reach()
	assert_gt(big_reach, reach, "大桌的桌脚撑开一点")
	assert_lt(big_reach, reach * 1.35, "只是稍微撑开")


# —— 桌面高度 ——

func test_nothing_on_the_play_area_rises_above_the_felt():
	for r in [SeatLayout.TABLE_RADIUS, TavernTable.POKER_RADIUS]:
		tavern.set_table_radius(r)
		var play_area: float = r - TableModel.FELT_INSET
		for mesh in [_solid().mesh, _trim().mesh]:
			assert_lte(_highest_within(mesh, 0.0, play_area), SeatLayout.TABLE_TOP + PLAY_AREA_CLEARANCE,
				"半径 %.2f:出牌区内没有高出桌面 1 厘米的东西" % r)


func test_table_edge_stays_low_enough_for_resting_paws():
	for r in [SeatLayout.TABLE_RADIUS, TavernTable.POKER_RADIUS]:
		tavern.set_table_radius(r)
		for mesh in [_solid().mesh, _trim().mesh]:
			assert_lte(_highest_within(mesh, 0.0, r + 0.1), SeatLayout.TABLE_TOP + EDGE_CLEARANCE,
				"半径 %.2f:包边不会让搭在桌沿的爪子陷进去" % r)


# —— 摆设与灯光 ——

func test_hiding_the_decor_hides_the_candles_and_their_lights():
	var lights := _candle_lights()
	assert_eq(lights.size(), 5, "每支蜡烛一盏烛光")
	table.set_decor_visible(false)
	for light in lights:
		assert_false(light.is_visible_in_tree(), "收起摆设时烛光也灭了")
	table.set_decor_visible(true)
	for light in lights:
		assert_true(light.is_visible_in_tree(), "摆回来时烛光重新亮起")


func test_each_candle_light_sits_just_above_its_flame():
	for holder in _candle_holders():
		var flames: Array = holder.find_children("*", "MeshInstance3D", false, false).filter(
			func(m: MeshInstance3D): return m.mesh is QuadMesh)
		var lights: Array = holder.find_children("*", "OmniLight3D", false, false)
		assert_eq(flames.size(), lights.size(), "每簇火苗一盏灯")
		for i in lights.size():
			var offset: Vector3 = lights[i].position - flames[i].position
			assert_almost_eq(offset, Vector3(0, TableCandles.LIGHT_ABOVE_FLAME, 0), Vector3.ONE * EPS, "烛光在火苗正上方")


func test_light_holders_have_distinct_names_for_the_perf_probe():
	var holders := _candle_holders()
	assert_eq(holders.size(), TableCandles.SPOTS.size(), "每个烛台都能按 Candles 前缀找到")
	var lamp := table.get_node("LampPivot")
	assert_eq(lamp.find_children("*", "SpotLight3D", false, false).size(), 1, "吊灯的聚光灯挂在 LampPivot 下")
	assert_eq(lamp.find_children("*", "OmniLight3D", false, false).size(), 1, "吊灯的补光挂在 LampPivot 下")


func test_lamp_shade_casts_shadows_but_small_fittings_do_not():
	var lamp := table.get_node("LampPivot")
	assert_ne((lamp.get_node("Shade") as MeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq((lamp.get_node("Fittings") as MeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"链条、灯泡等细件不投影(灯泡包着聚光灯)")


# —— 工具 ——

func _solid() -> MeshInstance3D:
	return table.get_node("Table/Solid")


func _trim() -> MeshInstance3D:
	return table.get_node("Table/Trim")


func _felt_surface() -> int:
	var mesh := _trim().mesh
	for i in mesh.get_surface_count():
		var mat := mesh.surface_get_material(i)
		if mat is ShaderMaterial and (mat as ShaderMaterial).shader == WorldMaterials.FELT_SHADER:
			return i
	return -1


func _felt_material() -> ShaderMaterial:
	return _trim().mesh.surface_get_material(_felt_surface())


func _felt_aabb() -> AABB:
	var index := _felt_surface()
	assert_gte(index, 0, "桌布在细件网格里")
	return _aabb(_trim().mesh.surface_get_arrays(index)[Mesh.ARRAY_VERTEX])


func _aabb_of(mesh: Mesh) -> AABB:
	return mesh.get_aabb()


func _aabb(verts: PackedVector3Array) -> AABB:
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	return box


func _highest_within(mesh: Mesh, from_radius: float, to_radius: float) -> float:
	# 水平半径落在 [from, to) 内的顶点里最高的那个(只看桌面附近,不管吊灯)
	var highest := -INF
	for i in mesh.get_surface_count():
		for v in mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			var r := Vector2(v.x, v.z).length()
			if r >= from_radius and r < to_radius and v.y < SeatLayout.TABLE_TOP + 0.3:
				highest = maxf(highest, v.y)
	return highest


func _surface_verts(mesh: Mesh, material: Material) -> PackedVector3Array:
	for i in mesh.get_surface_count():
		if mesh.surface_get_material(i) == material:
			return mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
	return PackedVector3Array()


func _feet_reach() -> float:
	# 贴近地面的木件(桌脚)离中柱轴线最远的距离
	var reach := 0.0
	for v in _surface_verts(_solid().mesh, WorldMaterials.wood("table")):
		if v.y < 0.1:
			reach = maxf(reach, Vector2(v.x, v.z).length())
	return reach


func _candle_holders() -> Array:
	return table.get_children().filter(func(n: Node): return String(n.name).begins_with("Candles"))


func _candle_lights() -> Array:
	var lights := []
	for holder in _candle_holders():
		lights.append_array(holder.find_children("*", "OmniLight3D", false, false))
	return lights
