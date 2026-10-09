extends GutTest
# MeshForge:复刻的基础体与 Godot PrimitiveMesh 逐顶点一致(无头下 PrimitiveMesh 的数组在 CPU 上,可以直接比);
# 变换、法线、绕序、顶点布局、多 surface、缓存与后台预建。


func after_each():
	MeshForge.clear_cache()


func _forge(recipe: Callable) -> Array:
	return MeshForge.run(recipe)[&"main"]


func _assert_same_geometry(ours: Array, mesh: PrimitiveMesh, label: String) -> void:
	var ref := mesh.get_mesh_arrays()
	var v: PackedVector3Array = ours[Mesh.ARRAY_VERTEX]
	var rv: PackedVector3Array = ref[Mesh.ARRAY_VERTEX]
	assert_eq(v.size(), rv.size(), label + " 顶点数")
	assert_eq(ours[Mesh.ARRAY_INDEX], ref[Mesh.ARRAY_INDEX], label + " 索引")
	if v.size() != rv.size():
		return
	var max_pos := 0.0
	var max_normal := 0.0
	var n: PackedVector3Array = ours[Mesh.ARRAY_NORMAL]
	var rn: PackedVector3Array = ref[Mesh.ARRAY_NORMAL]
	for k in v.size():
		max_pos = maxf(max_pos, v[k].distance_to(rv[k]))
		max_normal = maxf(max_normal, n[k].distance_to(rn[k]))
	assert_lt(max_pos, 1e-5, label + " 位置")
	assert_lt(max_normal, 3e-4, label + " 法线")   # Godot 用 16 位八面体编码存法线,参考值本身有约 1e-4 的量化误差


func test_sphere_matches_godot():
	for args in [[0.17, 28], [0.012, 10], [0.2, 20]]:
		_assert_same_geometry(_forge(func(f): f.sphere(args[0], args[1])), MeshKit.sphere(args[0], args[1]), "sphere%s" % [args])


func test_hemisphere_matches_godot():
	for args in [[0.115, 24], [0.16, 24]]:
		_assert_same_geometry(_forge(func(f): f.hemisphere(args[0], args[1])), MeshKit.hemisphere(args[0], args[1]), "hemi%s" % [args])


func test_cylinder_matches_godot_for_every_cap_mode():
	for caps in [MeshKit.CAPS_NONE, MeshKit.CAPS_TOP, MeshKit.CAPS_BOTTOM, MeshKit.CAPS_BOTH]:
		_assert_same_geometry(_forge(func(f): f.cylinder(0.07, 0.36, 0.2, 48, caps)),
			MeshKit.cylinder(0.07, 0.36, 0.2, 48, caps), "cyl caps=%d" % caps)
	_assert_same_geometry(_forge(func(f): f.cylinder(0.0, 0.055, 0.15, 12)), MeshKit.cylinder(0.0, 0.055, 0.15, 12), "cone")


func test_capsule_matches_godot():
	for args in [[0.2, 0.62, 20], [0.055, 0.4, 20], [0.016, 0.1, 20]]:
		_assert_same_geometry(_forge(func(f): f.capsule(args[0], args[1], args[2])), MeshKit.capsule(args[0], args[1], args[2]), "capsule%s" % [args])


func test_box_matches_godot():
	for size in [Vector3(0.48, 0.05, 0.44), Vector3(0.026, 0.05, 0.075)]:
		_assert_same_geometry(_forge(func(f): f.box(size)), MeshKit.box(size), "box%s" % size)


func test_torus_matches_godot():
	for args in [[0.075, 0.1, 24], [0.0045, 0.0085, 16]]:
		_assert_same_geometry(_forge(func(f): f.torus(args[0], args[1], args[2])), MeshKit.torus(args[0], args[1], args[2]), "torus%s" % [args])


func test_prism_matches_godot():
	for size in [Vector3(0.05, 0.05, 0.02), Vector3(0.1, 0.11, 0.02)]:
		_assert_same_geometry(_forge(func(f): f.prism(size)), MeshKit.prism(size), "prism%s" % size)


func test_xf_matches_node3d_transform():
	var node := Node3D.new()
	node.position = Vector3(0.1, 0.2, 0.3)
	node.rotation_degrees = Vector3(-10, 25, 90)
	node.scale = Vector3(0.75, 1.15, 0.35)
	var t := MeshForge.xf(node.position, node.rotation_degrees, node.scale)
	assert_true(t.is_equal_approx(node.transform))
	node.free()


func test_normals_stay_unit_and_follow_the_inverse_transpose():
	var t := MeshForge.xf(Vector3.ZERO, Vector3(0, 0, 30), Vector3(1, 3, 0.5))
	var arrays := _forge(func(f): f.sphere(0.1, 12, t))
	var ref := _forge(func(f): f.sphere(0.1, 12))
	var expected_basis := t.basis.inverse().transposed()
	for k in arrays[Mesh.ARRAY_NORMAL].size():
		var n: Vector3 = arrays[Mesh.ARRAY_NORMAL][k]
		assert_almost_eq(n.length(), 1.0, 1e-5)
		assert_lt(n.distance_to((expected_basis * ref[Mesh.ARRAY_NORMAL][k]).normalized()), 1e-5)


func _winding_sign(arrays: Array) -> float:
	# 三角形叉积与顶点法线同向的比例(+1 全同向,-1 全反向)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var total := 0.0
	var count := 0
	for k in range(0, idx.size(), 3):
		var face := (v[idx[k + 1]] - v[idx[k]]).cross(v[idx[k + 2]] - v[idx[k]])
		if face.length() < 1e-9:
			continue
		total += signf(face.dot(n[idx[k]] + n[idx[k + 1]] + n[idx[k + 2]]))
		count += 1
	return total / count


func test_mirroring_keeps_godots_winding():
	var godot_sign := _winding_sign(MeshKit.sphere(0.1, 12).get_mesh_arrays())
	assert_almost_eq(absf(godot_sign), 1.0, 0.01, "Godot 的基础体绕序一致")
	var mirrored := _forge(func(f): f.sphere(0.1, 12, MeshForge.xf(Vector3.ZERO, Vector3.ZERO, Vector3(-1, 1, 1))))
	assert_almost_eq(_winding_sign(mirrored), godot_sign, 0.01)


func test_lathe_winding_vertex_count_and_bounds():
	var profile := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.035, 0.0), Vector2(0.037, 0.15), Vector2(0.012, 0.2), Vector2(0.0, 0.2)])
	var arrays := _forge(func(f): f.lathe(profile, 16, PackedInt32Array([1, 3])))
	assert_eq(arrays[Mesh.ARRAY_VERTEX].size(), (profile.size() + 2) * 17, "折边处复制一圈顶点")
	assert_almost_eq(_winding_sign(arrays), _winding_sign(MeshKit.sphere(0.1, 12).get_mesh_arrays()), 0.01, "绕序与 Godot 基础体一致")
	var mesh := MeshForge.commit({&"main": arrays})
	var box := mesh.get_aabb()
	assert_almost_eq(box.size.y, 0.2, 1e-5)
	assert_almost_eq(box.size.x, 0.074, 0.002)
	for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		assert_almost_eq(n.length(), 1.0, 1e-5)


func test_vertex_layout_and_part_space():
	var built := MeshForge.run(func(f: MeshForge):
		f.paint(Color(0.8, 0.4, 0.1), 0.6, 0.0)
		f.box(Vector3(0.1, 0.1, 0.1))
		f.surface(&"wood")
		f.part_space = true
		f.seed = 2.0
		f.paint(Color(1, 1, 1), 0.7)
		f.box(Vector3(0.2, 0.2, 0.2), MeshForge.xf(Vector3(1, 0, 0))))
	var main: Array = built[&"main"]
	assert_eq(main[Mesh.ARRAY_COLOR][0], Color(0.8, 0.4, 0.1, 1.0), "COLOR = sRGB albedo + AO")
	assert_eq(main[Mesh.ARRAY_TEX_UV2][0], Vector2(0.6, 0.0), "UV2 = (roughness, metallic)")
	assert_null(main[Mesh.ARRAY_CUSTOM0], "没开 part_space 的 surface 不写 CUSTOM0")
	var wood: Array = built[&"wood"]
	var custom: PackedFloat32Array = wood[Mesh.ARRAY_CUSTOM0]
	var local: Vector3 = MeshKit.box(Vector3(0.2, 0.2, 0.2)).get_mesh_arrays()[Mesh.ARRAY_VERTEX][0]
	assert_almost_eq(Vector3(custom[0], custom[1], custom[2]).distance_to(local), 0.0, 1e-6, "CUSTOM0 存部件原始局部坐标")
	assert_eq(custom[3], 2.0, "w 是种子")
	assert_almost_eq(wood[Mesh.ARRAY_VERTEX][0].x, local.x + 1.0, 1e-6, "顶点位置按变换写入")
	var mesh := MeshForge.commit(built, {&"wood": StandardMaterial3D.new()})
	assert_eq(mesh.get_surface_count(), 2)
	assert_null(mesh.surface_get_material(0))
	assert_not_null(mesh.surface_get_material(1))
	assert_true(mesh.surface_get_format(1) & Mesh.ARRAY_FORMAT_CUSTOM0 != 0)


func test_push_pop_compose_transforms():
	var arrays := _forge(func(f: MeshForge):
		f.push(MeshForge.xf(Vector3(1, 0, 0)))
		f.push(MeshForge.xf(Vector3(0, 2, 0)))
		f.box(Vector3(0.1, 0.1, 0.1))
		f.pop()
		f.pop()
		f.box(Vector3(0.1, 0.1, 0.1)))
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	assert_almost_eq(v[0].x, 1.0 - 0.05, 1e-6)
	assert_almost_eq(v[0].y, 2.0 + 0.05, 1e-6)
	assert_almost_eq(v[v.size() - 1].y, -0.05, 1e-6, "pop 之后回到原坐标系")


func test_cached_returns_one_shared_mesh():
	var recipe := func(f: MeshForge): f.box(Vector3(0.3, 0.3, 0.3))
	var a := MeshForge.cached("test:box", recipe)
	assert_same(MeshForge.cached("test:box", recipe), a)
	MeshForge.clear_cache()
	assert_not_same(MeshForge.cached("test:box", recipe), a)


func test_prebuilt_on_worker_threads_matches_synchronous_build():
	var recipe := func(f: MeshForge):
		f.sphere(0.17, 28)
		f.capsule(0.2, 0.62, 20, MeshForge.xf(Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1, 1, 0.85)))
	MeshForge.prebuild([["test:a", recipe], ["test:b", recipe]])
	await MeshForge.wait_prebuilt(get_tree())
	assert_true(MeshForge.is_cached("test:a") and MeshForge.is_cached("test:b"))
	var sync := MeshForge.commit(MeshForge.run(recipe))
	var threaded: ArrayMesh = MeshForge.cached("test:a", recipe)
	assert_eq(threaded.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], sync.surface_get_arrays(0)[Mesh.ARRAY_VERTEX])


func test_game_code_never_reads_mesh_arrays_back():
	# 运行时读网格数组在 Metal 上要从 GPU 回读,每次约 1.2 ms;src 里一律不准用(tools/ 与 tests/ 不在此列)
	var offenders := []
	for path in _scripts("res://src"):
		var text := FileAccess.get_file_as_string(path)
		for banned in ["get_mesh_arrays(", "surface_get_arrays(", "get_faces("]:
			if text.contains(banned):
				offenders.append("%s: %s" % [path, banned])
	assert_eq(offenders, [])


func _scripts(dir: String) -> Array:
	var out := []
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			out.append(dir.path_join(file))
	for sub in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir.path_join(sub)))
	return out


func test_startup_prebuild_covers_every_mesh_patrons_and_revolvers_use():
	MeshForge.prebuild(PatronParts.forge_jobs() + Revolver3D.forge_jobs())
	await MeshForge.wait_prebuilt(get_tree())
	var keys := {}
	for job in PatronParts.forge_jobs() + Revolver3D.forge_jobs():
		keys[job[0]] = true
	for i in PatronParts.SPECIES.size():
		var spec := PatronParts.species(i)
		for part in PatronParts.recipes(spec):
			assert_true(keys.has(PatronParts.part_key(spec, part)), PatronParts.part_key(spec, part))
			assert_true(MeshForge.is_cached(PatronParts.part_key(spec, part)))
	assert_true(MeshForge.is_cached("chair"))
	assert_true(MeshForge.is_cached("revolver:body"))


# —— 子项目③ 的扩展:glow 通道、raw、extrude ——

func test_glow_goes_into_uv_only_for_surfaces_that_use_it():
	var built := MeshForge.run(func(f: MeshForge):
		f.box(Vector3(0.1, 0.1, 0.1))
		f.surface(&"lamp")
		f.box(Vector3(0.1, 0.1, 0.1))
		f.glow = Vector2(1.0, 0.0)
		f.sphere(0.05, 8)
		var from := f.mark()
		f.glow = Vector2.ZERO
		f.cylinder(0.02, 0.02, 0.1, 8)
		f.paint_glow(from, func(_p: Vector3) -> Vector2: return Vector2(0.0, 0.35)))
	assert_eq(built.size(), 2, "两个 surface")
	assert_null(built[&"main"][Mesh.ARRAY_TEX_UV], "没设过 glow 的 surface 不写 UV")
	var uv: PackedVector2Array = built[&"lamp"][Mesh.ARRAY_TEX_UV]
	assert_eq(uv.size(), built[&"lamp"][Mesh.ARRAY_VERTEX].size())
	assert_eq(uv[0], Vector2.ZERO, "设 glow 之前的部件补 0")
	assert_eq(uv[24], Vector2(1.0, 0.0), "灯泡自发光")
	assert_eq(uv[uv.size() - 1], Vector2(0.0, 0.35), "paint_glow 改写 mark 之后的顶点")
	var mesh := MeshForge.commit(built)
	assert_eq(mesh.get_surface_count(), 2)
	assert_true(mesh.surface_get_format(1) & Mesh.ARRAY_FORMAT_TEX_UV != 0)


func test_palette_paint_sets_color_pbr_and_glow():
	var arrays := _forge(func(f: MeshForge):
		WorldMaterials.paint_prop(f, "wax")
		f.box(Vector3(0.1, 0.1, 0.1)))
	var wax: Array = WorldMaterials.PALETTE["wax"]
	assert_eq(arrays[Mesh.ARRAY_COLOR][0], Color(wax[0].r, wax[0].g, wax[0].b, 1.0), "COLOR 按色板的 sRGB 写入")
	assert_eq(arrays[Mesh.ARRAY_TEX_UV2][0], Vector2(wax[1], wax[2]))
	assert_eq(arrays[Mesh.ARRAY_TEX_UV][0], wax[3])
	for entry in WorldMaterials.PALETTE:
		var c: Color = WorldMaterials.PALETTE[entry][0]
		if entry != "bulb":
			assert_lte(maxf(c.r, maxf(c.g, c.b)), 0.8001, entry + " 的 albedo 不超过 0.8")


func test_raw_keeps_the_given_uvs():
	var arrays := _forge(func(f: MeshForge):
		f.raw(PackedVector3Array([Vector3.ZERO, Vector3(1, 0, 0), Vector3(0, 0, 1)]),
			PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP]),
			PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1)]), PackedInt32Array([0, 1, 2])))
	assert_eq(arrays[Mesh.ARRAY_TEX_UV][2], Vector2(0, 1))
	assert_eq(arrays[Mesh.ARRAY_INDEX], PackedInt32Array([0, 1, 2]))


func test_extrude_with_bevel_has_unit_normals_box_bounds_and_godot_winding():
	# 带凹角的 L 形轮廓(顺时针给出,自动转逆时针)
	var outline := PackedVector2Array([Vector2(0, 0), Vector2(0, 0.06), Vector2(0.02, 0.06), Vector2(0.02, 0.02),
		Vector2(0.05, 0.02), Vector2(0.05, 0)])
	var arrays := _forge(func(f): f.extrude(outline, 0.03, 0.003))
	for n: Vector3 in arrays[Mesh.ARRAY_NORMAL]:
		assert_almost_eq(n.length(), 1.0, 1e-4)
	var box := MeshForge.commit({&"main": arrays}).get_aabb()
	assert_almost_eq(box.position, Vector3(0, 0, -0.015), Vector3.ONE * 1e-5)
	assert_almost_eq(box.size, Vector3(0.05, 0.06, 0.03), Vector3.ONE * 1e-5, "AABB = 轮廓外框 × 深度")
	assert_almost_eq(_winding_sign(arrays), _winding_sign(MeshKit.sphere(0.1, 12).get_mesh_arrays()), 0.01, "绕序与 Godot 基础体一致")
	var open_front := _forge(func(f): f.extrude(outline, 0.03, 0.003, Transform3D.IDENTITY, Vector2i(1, 0)))
	assert_lt(open_front[Mesh.ARRAY_VERTEX].size(), arrays[Mesh.ARRAY_VERTEX].size(), "caps 可以不封 +Z 端")
