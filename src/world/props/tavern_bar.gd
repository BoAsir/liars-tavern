class_name TavernBar
# 吧台:左墙前的前吧台(BarCounter:嵌板柜身、圆鼻边厚台面、黄铜踏脚杆、酒头)、靠墙的背吧(BarBack:矮柜、酒桶、
# 三层酒架与檐口)、架上一排排酒瓶(BarBottles)、台面上的酒杯与木酒杯(BarGlassware)、柜前的高脚凳(BarStools),
# 以及吧台上方的暖光。这里只管根节点、各部件按材质合批与投影。
# 本地坐标:原点在左墙内表面、吧台正中的地面,+X 朝房间,+Z 沿墙(朝玩家座位一侧)。


const ORIGIN_Z := -0.6
const LIGHT_AT := Vector3(0.9, 2.5, 0)


static func build(tavern: Tavern) -> void:
	var x := -Tavern.ROOM_HALF + Tavern.WALL_THICKNESS / 2.0
	var bar := MeshKit.pivot(tavern, Vector3(x, 0, ORIGIN_Z), "Bar")
	# 柜身、酒架、酒桶、高脚凳投影:它们把吧台"压"在地板与墙上
	var body := MeshBatch.cached("bar:body", func(batch: MeshBatch) -> void:
		BarCounter.add_to(batch)
		BarBack.add_to(batch)
		BarStools.add_to(batch))
	MeshBatch.instance(bar, body, {}, "Body")
	# 酒瓶合成一个网格(玻璃、酒标、瓶帽、陶器四个表面);太小太多,投影只费不显
	var bottles := MeshBatch.cached("bar:bottles", func(batch: MeshBatch) -> void:
		BarBottles.add_to(batch))
	MeshBatch.instance(bar, bottles, {}, "Bottles", false)
	# 酒头、酒杯、挂着的木酒杯等小物件同样不投影
	var details := MeshBatch.cached("bar:details", func(batch: MeshBatch) -> void:
		BarCounter.add_taps(batch)
		BarStools.add_details(batch)
		BarGlassware.add_to(batch))
	MeshBatch.instance(bar, details, {}, "Details", false)
	_build_light(bar)


static func _build_light(bar: Node3D) -> void:
	# 参数由灯光调校会话维护,这里原样保留
	var light := OmniLight3D.new()
	light.position = LIGHT_AT
	light.light_color = Color(1.0, 0.7, 0.4)
	light.light_energy = 1.4
	light.omni_range = 3.8
	bar.add_child(light)
