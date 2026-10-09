class_name TavernDecor
# 散落的陈设:牌桌下的圆地毯、四个角落的酒桶堆 / 木箱粮袋 / 衣帽架、墙上的黑板、通缉令、油画、飞镖盘、
# 置物架、鱼标本、梁下晾的香草。全部合成两个缓存网格,每种材质一次绘制:
# Props 投影(立在地上的大件:酒桶、木箱、粮袋、扫帚、衣帽架),Detail 不投影(地毯与贴墙、悬挂的小件)。


static func build(tavern: Tavern) -> void:
	var decor := MeshKit.pivot(tavern, Vector3.ZERO, "Decor")
	MeshBatch.instance(decor, props_mesh(), {}, "Props")
	MeshBatch.instance(decor, detail_mesh(), {}, "Detail", false)


static func props_mesh() -> ArrayMesh:
	return MeshBatch.cached("decor:props", func(batch: MeshBatch) -> void: _fill(batch, MeshBatch.new()))


static func detail_mesh() -> ArrayMesh:
	return MeshBatch.cached("decor:detail", func(batch: MeshBatch) -> void: _fill(MeshBatch.new(), batch))


static func _fill(props: MeshBatch, detail: MeshBatch) -> void:
	# 同一件东西的大件与小件(酒桶与龙头、衣帽架与挎包)在同一处摆放代码里分别加进两批;
	# 拼其中一个网格时另一批直接丢弃(只在开场拼一次,多花的几毫秒换来摆放代码不拆散)
	DecorRug.add_to(detail)
	DecorBarrels.add_to(props, detail)
	DecorStorage.add_to(props)
	DecorFixtures.add_to(props, detail)
	DecorWalls.add_to(detail)
