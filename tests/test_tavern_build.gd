extends GutTest
# 房间构建(无头 Tavern.new()):节点名、层与投影规则、共享网格、啤酒杯 MultiMesh、灯、贴花与雾、
# 墙饰离墙距离、镜头环绕路径的净空(按顶点核对,合并网格的包围盒太粗)。

# ④ 建的顶层节点(名字或前缀);牌桌、吊灯、烛台、酒客等不归这里管
const ROOM_NODES := ["Room", "Fireplace", "Bar", "Window", "WindowView", "Door", "DoorView", "Decor_", "WallProps_", "Clock",
	"Pendulum", "Piano", "PianoBench", "CoatRack", "Barrel", "Crate", "Clutter", "Rugs", "Sconce", "Decals"]

var _tavern: Tavern


func before_all():
	_tavern = Tavern.new()
	add_child(_tavern)


func after_all():
	_tavern.free()


func _room_roots() -> Array:
	return _tavern.get_children().filter(func(n: Node):
		for prefix in ROOM_NODES:
			if String(n.name).begins_with(prefix):
				return true
		return false)


func _room_geometry() -> Array:
	var out := []
	for root in _room_roots():
		if root is GeometryInstance3D:
			out.append(root)
		out.append_array(root.find_children("*", "GeometryInstance3D", true, false))
	return out


func _is_flame(g: GeometryInstance3D) -> bool:
	return g.material_override is ShaderMaterial and g.material_override.shader == WorldMaterials.FLAME_SHADER


func test_wall_and_floor_nodes_keep_their_names_and_shadow_rules():
	var room := _tavern.get_node("Room")
	var floor: MeshInstance3D = room.get_node("Floor")
	assert_eq(floor.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	assert_eq(floor.layers, MeshKit.LAYER_SCENERY, "地板在布景层(接地贴花投得上)")
	for prefix in ["WallBack", "WallFront", "WallLeft"]:
		for part in ["Wainscot", "Plaster"]:
			var inst: MeshInstance3D = room.get_node(prefix + part)
			assert_eq(inst.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, prefix + part)
		var rail: MeshInstance3D = room.get_node(prefix + "Rail")
		assert_eq(rail.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, prefix + "Rail")
		assert_eq(rail.layers, MeshKit.LAYER_WORLD, "线脚照常给室内灯投影")
	for i in 4:
		assert_not_null(room.get_node_or_null("WindowWall%dPlaster" % i), "窗墙第 %d 段" % i)


func test_scenery_never_casts_and_casters_live_on_world_or_moon_layers():
	for g: GeometryInstance3D in _room_geometry():
		if g.layers & MeshKit.LAYER_SCENERY:
			assert_eq(g.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s 是布景,不投影" % g.get_path())
		if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			assert_true(g.layers == MeshKit.LAYER_WORLD or g.layers == MeshKit.LAYER_MOON, "%s 投影物只在世界层或月光层" % g.get_path())


func test_only_the_window_group_is_on_the_moon_layer():
	var moon_parts := []
	for g in _tavern.find_children("*", "GeometryInstance3D", true, false):
		if g.layers & MeshKit.LAYER_MOON:
			moon_parts.append(g)
	assert_gt(moon_parts.size(), 6)
	var window := _tavern.get_node("Window")
	for g: GeometryInstance3D in moon_parts:
		var ok: bool = window.is_ancestor_of(g) or String(g.name).begins_with("WindowWall")
		assert_true(ok, "%s 不该在月光层" % g.get_path())
		assert_eq(g.layers, MeshKit.LAYER_MOON, g.name)
		assert_ne(g.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s 给月光投影" % g.name)
	for id in ["WindowView", "DoorView", "Door"]:
		var view: GeometryInstance3D = _tavern.get_node(id)
		assert_eq(view.layers & MeshKit.LAYER_MOON, 0, "%s 不在月光层" % id)
		assert_eq(view.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s 不投影" % id)


func test_heavy_pieces_cast_from_the_world_layer():
	for path in ["Fireplace/Stone", "Fireplace/Mantel", "Fireplace/Logs", "Bar/Body", "Bar/Stool0", "Barrel0", "BarrelHoops0", "Crate0"]:
		var g: GeometryInstance3D = _tavern.get_node(path)
		assert_eq(g.layers, MeshKit.LAYER_WORLD, path)
		assert_ne(g.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, path)


func test_decor_does_not_cast_and_sits_at_least_5mm_off_the_wall():
	for wall in ["back", "front", "left", "right"]:
		var inst: MeshInstance3D = _tavern.get_node("Decor_" + wall)
		assert_eq(inst.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		var n := RoomLayout.wall_normal(wall)
		var closest := INF
		for s in inst.mesh.get_surface_count():
			for v: Vector3 in inst.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p := inst.global_transform * v
				closest = minf(closest, p.dot(n) + RoomLayout.INNER)   # 离灰泥面的距离(朝屋里为正)
		assert_gte(closest, 0.0049, "%s 墙的墙饰离墙 ≥ 5 mm(最近 %.4f m)" % [wall, closest])


func test_repeated_props_share_one_mesh_each():
	var groups := {"Barrel": {}, "BarrelHoops": {}, "Crate": {}, "Stool": {}}
	for node in _tavern.find_children("*", "MeshInstance3D", true, false):
		var name := String(node.name)
		if name.begins_with("BarrelHoops"):
			groups["BarrelHoops"][node.mesh] = groups["BarrelHoops"].get(node.mesh, 0) + 1
		elif name.begins_with("Barrel"):
			groups["Barrel"][node.mesh] = groups["Barrel"].get(node.mesh, 0) + 1
		elif name.begins_with("Crate"):
			groups["Crate"][node.mesh] = groups["Crate"].get(node.mesh, 0) + 1
		elif name.begins_with("Stool") or name == "PianoBench":
			groups["Stool"][node.mesh] = groups["Stool"].get(node.mesh, 0) + 1
	assert_eq(groups["Barrel"].size(), 1, "木桶(含小酒桶)共用一份车削网格")
	assert_eq(groups["Barrel"].values()[0], 6)
	assert_eq(groups["BarrelHoops"].size(), 1, "桶箍共用一份网格")
	assert_eq(groups["Crate"].size(), 1)
	assert_eq(groups["Crate"].values()[0], 3)
	assert_eq(groups["Stool"].size(), 1, "吧凳与琴凳共用一份网格")
	assert_eq(groups["Stool"].values()[0], 5)
	var sconce_meshes := {}
	var sconces := _tavern.get_children().filter(func(n): return String(n.name).begins_with("Sconce"))
	assert_eq(sconces.size(), Tavern.SCONCES.size())
	for sconce in sconces:
		for m: MeshInstance3D in sconce.find_children("*", "MeshInstance3D", false, false):
			if not _is_flame(m):
				sconce_meshes[m.mesh] = true
	assert_eq(sconce_meshes.size(), 1, "7 盏壁灯共用一份网格")


func test_sconces_are_opaque_brass_candles_with_the_same_light():
	for sconce in _tavern.get_children().filter(func(n): return String(n.name).begins_with("Sconce")):
		var lights: Array = sconce.find_children("*", "OmniLight3D", false, false)
		assert_eq(lights.size(), 1)
		assert_almost_eq(lights[0].position.distance_to(Vector3(0, 0.05, -0.2)), 0.0, 1e-5, "壁灯的灯位不变")
		for m: MeshInstance3D in sconce.find_children("*", "MeshInstance3D", false, false):
			if m.material_override is BaseMaterial3D:
				assert_eq(m.material_override.transparency, BaseMaterial3D.TRANSPARENCY_DISABLED, "壁灯不再有半透明玻璃罩")


func test_mugs_are_one_multimesh_of_four_with_non_emissive_foam():
	var mugs: MultiMeshInstance3D = _tavern.get_node("Bar/BarTop/Mugs")
	assert_eq(mugs.multimesh.instance_count, 4)
	assert_eq(mugs.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	var mat := mugs.multimesh.mesh.surface_get_material(0)
	assert_eq(mat, WorldMaterials.prop(), "杯子(连泡沫)走道具顶点 PBR")
	assert_false(WorldMaterials.PROP_SHADER.code.contains("EMISSION"), "泡沫不发光")
	# 杯子位置与改造前一致(同一个随机数序列:先 53 个酒瓶,再 4 只杯子)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for shelf in 3:
		var z := -1.35
		while z < 1.35:
			rng.randf_range(Bottles.MIN_HEIGHT, Bottles.MAX_HEIGHT)
			rng.randi()
			z += rng.randf_range(0.1, 0.2)
	var layout := BarSet.shelf_layout()
	assert_eq(layout["bottles"].size(), 53)
	for i in 4:
		var expected := Vector3(1.05 + rng.randf_range(-0.15, 0.15), 1.11, -1.2 + i * 0.7 + rng.randf_range(-0.1, 0.1))
		assert_almost_eq(layout["mugs"][i].distance_to(expected), 0.0, 1e-5, "第 %d 只杯子" % i)


func test_lights_stay_within_budget_and_keep_their_parent_names():
	var lights := _tavern.find_children("*", "Light3D", true, false)
	assert_lte(lights.size(), 16)
	var shadowed := lights.filter(func(l: Light3D): return l.shadow_enabled)
	assert_eq(shadowed.size(), 3, "投影灯固定 3 盏")
	for l: Light3D in lights:
		var parent := String(l.get_parent().name)
		var ok := l == _tavern.get_node("Moon") or l.name == "TableRimLight" or _tavern.camera_rig.is_ancestor_of(l)
		for prefix in ["Fireplace", "LampPivot", "Sconce", "Candles", "Bar"]:
			ok = ok or parent.begins_with(prefix)
		assert_true(ok, "%s 的父节点名 %s" % [l.name, parent])
	var fire: Light3D = _tavern.get_node("Fireplace").find_children("*", "OmniLight3D", false, false)[0]
	assert_eq(fire.shadow_caster_mask, MeshKit.LAYER_WORLD)
	assert_almost_eq(fire.position.distance_to(Vector3(0, 0.5, 0.75)), 0.0, 1e-5, "壁炉灯位不变")
	assert_almost_eq(_tavern.get_node("Fireplace").position.distance_to(Vector3(-1.5, 0, -4.4)), 0.0, 1e-5)


func test_moonlight_comes_from_the_layout_constants():
	var moon: SpotLight3D = _tavern.get_node("Moon")
	assert_eq(moon.shadow_caster_mask, MeshKit.LAYER_MOON)
	assert_almost_eq(moon.global_position.distance_to(RoomLayout.MOON_POS), 0.0, 1e-4)
	var forward := -moon.global_basis.z
	assert_almost_eq(forward.angle_to(RoomLayout.MOON_TARGET - RoomLayout.MOON_POS), 0.0, 1e-3)
	assert_almost_eq(RoomLayout.MOON_POS.distance_to(Vector3(4.4, 1.775, -0.9) + Vector3(2.2, 1.5, 0.6)), 0.0, 1e-5, "与改造前的数值一致")


func test_decals_and_fog_volumes():
	var decals := _tavern.find_children("*", "Decal", true, false)
	assert_eq(decals.size(), 12)
	for d: Decal in decals:
		assert_eq(d.get_parent().name, &"Decals")
		assert_eq(d.cull_mask, MeshKit.LAYER_SCENERY, "贴花只投到布景层")
	var fogs := _tavern.find_children("*", "FogVolume", true, false)
	assert_eq(fogs.size(), 2)
	var names := fogs.map(func(f): return String(f.name))
	names.sort()
	assert_eq(names, ["HearthHaze", "SmokeLayer"])
	assert_not_null(_tavern.environment.adjustment_color_correction, "暖色 LUT")


func test_room_wood_presets_have_a_single_part_space_variant():
	for preset in ["wainscot", "ceiling", "floor", "beam", "log", "barrel"]:
		var both: bool = WorldMaterials._cache.has("wood:%s:true" % preset) and WorldMaterials._cache.has("wood:%s:false" % preset)
		assert_false(both, "木材预设 %s 不同时存在两种部件空间变体" % preset)


func test_room_mesh_budget():
	var meshes := _room_geometry().filter(func(g): return g is MeshInstance3D and not _is_flame(g))
	var resources := {}
	for m: MeshInstance3D in meshes:
		resources[m.mesh] = true
	assert_lte(meshes.size(), 80, "④ 的 MeshInstance3D(不含火焰片)")
	assert_lte(resources.size(), 60, "④ 的不同网格资源")


func _orbit_offenders(center: Vector2, r0: float, r1: float, y0: float, y1: float) -> Array:
	var out := []
	for g in _room_geometry():
		if not (g is MeshInstance3D) or g.mesh == null:
			continue
		var inst: MeshInstance3D = g
		for s in inst.mesh.get_surface_count():
			for v: Vector3 in inst.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]:
				var p := inst.global_transform * v
				var r := Vector2(p.x, p.z).distance_to(center)
				if r > r0 and r < r1 and p.y > y0 and p.y < y1:
					out.append("%s %s" % [inst.get_path(), p])
					break
	return out


func test_nothing_intrudes_into_the_camera_orbits():
	# 菜单环绕(中心 (0, −0.2)、r 3.3、y 2.05)、骗子结算环绕(r 2.4、y 1.85)、德州结算环绕(r 3.1、y 2.0)
	assert_eq(_orbit_offenders(Vector2(0, -0.2), 3.0, 3.6, 1.7, 2.4), [], "菜单环绕")
	assert_eq(_orbit_offenders(Vector2.ZERO, 2.2, 2.6, 1.6, 2.1), [], "骗子结算环绕")
	assert_eq(_orbit_offenders(Vector2.ZERO, 2.9, 3.3, 1.75, 2.25), [], "德州结算环绕")
