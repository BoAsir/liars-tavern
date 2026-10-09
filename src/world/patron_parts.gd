class_name PatronParts
# 酒客的网格库:物种外观表(PatronSpecies)→ 按物种缓存的合批网格,每个动画枢轴一份(MeshBatch.cached)。
# 网格只用一个字符串槽位(PatronSkin.SLOT),实例化时绑定到该酒客自己的材质:同物种的酒客共用网格,
# 各自褪色。开场(Tavern._ready)调用 prewarm() 把所有物种的网格建好,中途加入、复活时直接取用。
# 动画逻辑在 Patron 中;部件几何在 PatronHead / PatronFace / PatronEars / PatronTorso / PatronOutfit /
# PatronLimbs / PatronTails / PatronHats 中。


const SPECIES := PatronSpecies.ALL
const EXPRESSIONS := PatronFace.EXPRESSIONS

static var _chair: Array = []    # 椅子各部件 [网格, 变换, material_override, 表面材质数组, 投影设置]


static func species(index: int) -> Dictionary:
	return SPECIES[posmod(index, SPECIES.size())]


static func prewarm() -> void:
	# 开场时调用:提前建好各物种要用的网格(与椅子),中途加入、复活时不再现场拼装
	for i in SPECIES.size():
		meshes(i)
	chair_parts()


static func first_free_species(used: Array) -> int:
	# 新酒客取第一个没人用的物种,同桌不撞脸;物种全被占用(人数超过物种数)时才轮流重复
	for i in SPECIES.size():
		if not used.has(i):
			return i
	return posmod(used.size(), SPECIES.size())


static func meshes(index: int) -> Dictionary:
	# 某物种的全部网格:部件名 → ArrayMesh(同一物种只拼装一次)
	var spec := species(index)
	var key := "patron:%s:" % spec["id"]
	var shape := PatronHead.sculpt(spec)
	var out := {
		"torso": MeshBatch.cached(key + "torso", func(b: MeshBatch) -> void: _torso(b, spec)),
		"torso_detail": MeshBatch.cached(key + "torso_detail", func(b: MeshBatch) -> void:
			_add_all(b, PatronOutfit.build(spec, PatronTorso.new(spec)))),
		"neck": MeshBatch.cached(key + "neck", func(b: MeshBatch) -> void: _add(b, PatronLimbs.neck(spec))),
		"skull": MeshBatch.cached(key + "skull", func(b: MeshBatch) -> void: _add(b, PatronHead.skull(spec))),
		"head_detail": MeshBatch.cached(key + "head_detail", func(b: MeshBatch) -> void: _head_detail(b, spec, shape)),
		"eye": MeshBatch.cached(key + "eye", func(b: MeshBatch) -> void: PatronFace.build_eye(b, spec)),
		"x_eyes": MeshBatch.cached(key + "x_eyes", func(b: MeshBatch) -> void: _add(b, PatronFace.x_eyes(spec, shape))),
		"ear": MeshBatch.cached(key + "ear", func(b: MeshBatch) -> void: _add(b, PatronEars.ear(spec))),
		"hat": MeshBatch.cached(key + "hat", func(b: MeshBatch) -> void: _add(b, PatronHats.build(spec))),
		"legs": MeshBatch.cached(key + "legs", func(b: MeshBatch) -> void: _add(b, PatronLimbs.legs(spec))),
		"tail": MeshBatch.cached(key + "tail", func(b: MeshBatch) -> void: _add(b, PatronLimbs.tail(spec))),
	}
	var marks: Vector2 = PatronHead.markings(spec).call(PatronHead.dir(spec["eyes"]["yaw"], spec["eyes"]["pitch"]))
	for side in [-1.0, 1.0]:
		var suffix := "_r" if side > 0.0 else "_l"
		out["lid" + suffix] = MeshBatch.cached(key + "lid" + suffix, func(b: MeshBatch) -> void:
			_add(b, PatronFace.lid(spec, side, marks)))
		out["brow" + suffix] = MeshBatch.cached(key + "brow" + suffix, func(b: MeshBatch) -> void:
			_add(b, PatronFace.brow(spec, shape, side)))
		out["arm" + suffix] = MeshBatch.cached(key + "arm" + suffix, func(b: MeshBatch) -> void:
			_add(b, PatronLimbs.arm(spec, side)))
	for expression in EXPRESSIONS:
		out["mouth:" + expression] = MeshBatch.cached(key + "mouth:" + expression, func(b: MeshBatch) -> void:
			_add(b, PatronFace.mouth(spec, shape, expression)))
	return out


static func chair_parts() -> Array:
	# 椅子(ChairModel)只搭一次:记下每个网格节点相对椅子原点的变换与材质,各酒客按记录摆出共用同一批网格
	if _chair.is_empty():
		var template := Node3D.new()
		ChairModel.build(template)
		for node in template.find_children("*", "MeshInstance3D", true, false):
			var inst := node as MeshInstance3D
			var surfaces := []
			for i in inst.get_surface_override_material_count():
				surfaces.append(inst.get_surface_override_material(i))
			_chair.append([inst.mesh, _relative_xform(inst, template), inst.material_override, surfaces, inst.cast_shadow])
		template.free()
	return _chair


static func add_chair(parent: Node3D) -> void:
	for part in chair_parts():
		var inst := MeshInstance3D.new()
		inst.mesh = part[0]
		inst.transform = part[1]
		inst.material_override = part[2]
		for i in (part[3] as Array).size():
			inst.set_surface_override_material(i, part[3][i])
		inst.cast_shadow = part[4]
		parent.add_child(inst)


# —— 合批 ——

static func _torso(batch: MeshBatch, spec: Dictionary) -> void:
	# 外套 + 开口里的衬衫/马甲/裤腰 + 翻领、领圈、门襟滚边(都投影;小件在 torso_detail)
	var torso := PatronTorso.new(spec)
	var outfit: Dictionary = spec.get("outfit", {})
	var notch: bool = outfit.get("lapel", "shawl") == "notch"
	var vest: bool = outfit.get("vest", true)
	_add(batch, torso.jacket())
	_add(batch, torso.shirt(0.3 if vest else 0.05))
	_add(batch, torso.lap())
	if vest:
		_add(batch, torso.vest_half(-1.0))
		_add(batch, torso.vest_half(1.0))
	for side in [-1.0, 1.0]:
		_add(batch, torso.lapel(side, notch))
		_add_all(batch, torso.front_edges(side))
	_add(batch, torso.collar(notch))


static func _head_detail(batch: MeshBatch, spec: Dictionary, shape: Callable) -> void:
	# 头上的小件(不投影):鼻子、胡须、腮毛
	PatronHead.nose(spec, batch, shape)
	PatronHead.whiskers(spec, batch, shape)
	PatronHead.tufts(spec, batch, shape)


static func _add(batch: MeshBatch, arrays: Array) -> void:
	# 数组已在枢轴坐标里、顶点色已带槽位:原样并进唯一的槽位
	if not arrays.is_empty():
		batch.add_arrays(arrays, PatronSkin.SLOT)


static func _add_all(batch: MeshBatch, list: Array) -> void:
	for arrays in list:
		_add(batch, arrays)


static func _relative_xform(node: Node3D, root: Node3D) -> Transform3D:
	var xform := Transform3D.IDENTITY
	var current := node
	while current != root and current != null:
		xform = current.transform * xform
		current = current.get_parent() as Node3D
	return xform
