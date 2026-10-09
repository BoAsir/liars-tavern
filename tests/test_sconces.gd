extends GutTest
# 壁灯:所有壁灯的木、铜、蜡、玻璃合成两个不投影的网格;每盏壁灯仍有自己的火苗与灯光,
# 挂在各不相同、以 Sconce 开头的节点下(性能探针按名字前缀找灯),灯光参数不变。


const LIGHT_ENERGY := 1.0
const LIGHT_RANGE := 4.6
const CHIMNEY_REACH := 0.06

var tavern: Tavern


func before_each():
	tavern = Tavern.new()
	add_child_autofree(tavern)


func test_every_sconce_keeps_its_own_flame_and_light():
	var roots := _sconce_roots()
	assert_eq(roots.size(), TavernSconces.SCONCES.size(), "每盏壁灯一个 Sconce 节点(名字不重复)")
	for root in roots:
		var lights: Array = root.find_children("*", "OmniLight3D", false, false)
		assert_eq(lights.size(), 1, "%s 下一盏灯" % root.name)
		assert_almost_eq((lights[0] as OmniLight3D).light_energy, LIGHT_ENERGY, 0.2, "灯光亮度不变(含闪烁浮动)")
		assert_almost_eq((lights[0] as OmniLight3D).omni_range, LIGHT_RANGE, 0.0001, "灯光范围不变")
		var flames: Array = root.find_children("*", "MeshInstance3D", false, false)
		assert_eq(flames.size(), 1, "%s 下一簇火苗" % root.name)


func test_sconce_geometry_is_merged_and_casts_no_shadows():
	var merged := tavern.get_node("Sconces").find_children("*", "MeshInstance3D", false, false)
	assert_eq(merged.size(), 2, "所有壁灯的几何只有两个网格:木铜蜡 + 玻璃")
	for inst in merged:
		assert_eq((inst as MeshInstance3D).cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"%s 不投影" % inst.name)


func test_glass_is_drawn_before_the_flames():
	var glass := tavern.get_node("Sconces/Glass") as MeshInstance3D
	var mat := glass.mesh.surface_get_material(0)
	assert_lt(mat.render_priority, 0, "玻璃先画,加色的火苗叠在上面不被盖暗")


func test_each_flame_sits_inside_its_glass_chimney():
	# 每簇火苗四周一圈都有玻璃罩的顶点(罩子跟着各自的壁灯摆,火苗在罩子中轴上)
	var glass: PackedVector3Array = (tavern.get_node("Sconces/Glass") as MeshInstance3D).mesh.surface_get_arrays(0)[
		Mesh.ARRAY_VERTEX]
	for root in _sconce_roots():
		var flame: Vector3 = (root.find_children("*", "MeshInstance3D", false, false)[0] as MeshInstance3D).global_position
		var around := 0
		for v in glass:
			var d := v - flame
			if Vector2(d.x, d.z).length() < CHIMNEY_REACH and absf(d.y) < CHIMNEY_REACH:
				around += 1
		assert_gt(around, 0, "%s 的火苗罩在玻璃罩里" % root.name)
		var offset: Vector3 = root.to_local(flame) - Vector3(0, SconceModel.FLAME_POS.y, SconceModel.AXIS_Z)
		assert_almost_eq(offset, Vector3.ZERO, Vector3.ONE * 0.001, "火苗在玻璃罩中轴上")


# —— 工具 ——

func _sconce_roots() -> Array:
	return tavern.get_node("Sconces").get_children().filter(
		func(n: Node): return n is Node3D and not n is MeshInstance3D and String(n.name).begins_with("Sconce"))
