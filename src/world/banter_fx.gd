class_name BanterFx
extends Node3D
# 丢番茄与说话的世界表现(规格 2026-10-08 丢番茄与快捷语 §1、§5),挂在 TableWorld 下,等待厅和两种牌桌共用:
# - throw_tomato:丢的人有酒客、活着、手空着时右手蓄力一甩,番茄从手里出手;没有酒客(观战)时从吧台上方飞来。
#   番茄沿抛物线飞 FLIGHT_TIME 秒,落点按种子在目标头上偏一点(脸、左右腮、额头),各端种子一致所以落点一致。
#   命中:「啪叽」声、红色汁水(≤24 粒)、一块番茄泥贴在目标 Head 下约 6 秒后缩没;同一个头最多 MAX_SPLATS 块,最旧的先没;
#   被砸的人吓一跳加嫌弃抹脸,出局的不反应。
# - say:按物种合成的动物话从说话人头上的 3D 声源放出来(走 SFX 总线;voice_enabled 由界面按 Sfx.muted 设,
#   无头时为假、不出声但流程照走),头随音节点头;返回时间表,界面据此逐字显示气泡。
# 和 CardTable 一样不直接碰 Sfx 自动加载(tools/ 下的 -s 脚本编译时还没有自动加载):音效经 sfx 信号交给 main 播放。
# 网格走 MeshForge 缓存 + 道具共用材质,小件不投影;番茄、番茄泥、声源都是用到时才建,静止状态下不多一个网格。


const FLIGHT_TIME := 0.6
const ARC_BASE := 0.15          # 抛物线最高点比两端连线高出 ARC_BASE + ARC_PER_METER × 距离(米)
const ARC_PER_METER := 0.08
const SPIN := Vector3(11.0, 5.0, 2.0)   # 飞行中转几圈(弧度 / 整段)
const SPLAT_LIFE := 6.0         # 番茄泥从贴上到消失的总时长(秒)
const SPLAT_FADE := 0.9         # 最后这么久缩小、往下滑一点再消失(道具材质不透明:用缩小代替淡出)
const SPLAT_SLIDE := 0.035
const MAX_SPLATS := 3
const SPLAT_GROUP := &"tomato_splat"
const TOMATO_GROUP := &"tomato_flying"
const JUICE_AMOUNT := 22
const TOMATO_RADIUS := 0.05
const SPECTATOR_FROM := Vector3(-2.75, 1.5, -0.6)   # 观战者从吧台上方丢(TableWorld 坐标,吧台在 x≈-3.0..-3.7)
const HAND_HOLD := Vector3(0.0, 0.0, -0.04)          # 番茄在爪心前一点
# 落点:Head 局部方向(酒客面朝 -Z)与权重;方向带一点按种子的抖动
const HITS := [
	[Vector3(0.0, 0.28, -1.0), 0.5],     # 脸(眼睛那一带,长吻物种也落在颅骨上)
	[Vector3(-0.8, 0.05, -0.6), 0.15],   # 左腮
	[Vector3(0.8, 0.05, -0.6), 0.15],    # 右腮
	[Vector3(0.0, 0.75, -0.65), 0.2],    # 额头
]
const HIT_JITTER := 0.32
const SPLAT_SIZE := 1.7          # 番茄泥网格整体放大(动森式大头半宽约 0.33 米:泥要糊住半张脸才好笑)
const SPLAT_SINK := 0.006        # 番茄泥中心压进表面一点,扁片边缘才贴得住曲面
const VOICE_DB := -2.0
const VOICE_MAX_DB := 3.0
const VOICE_UNIT_SIZE := 6.0
const WARM_EVERY := 1.0          # 每隔这么久看一眼桌上有哪些酒客,把他们的 8 句预热好(静音时不预热)
const TOMATO_RED := Color(0.8, 0.16, 0.1)
const PULP_RED := Color(0.72, 0.12, 0.08)
const PULP_LIGHT := Color(0.88, 0.32, 0.2)
const SEED_YELLOW := Color(0.8, 0.7, 0.32)
const LEAF_GREEN := Color(0.26, 0.52, 0.2)

signal splatted(target_pid: int)
signal sfx(sound: String)        # main 接到 Sfx.play

const VOICE_BUS := "SFX"         # = Sfx.BUS

var world: TableWorld
var voice_enabled := false       # 出不出声(界面按 Sfx.muted 设;静音、无头时为假,也不预热合成)
var _warmed := {}                # "物种:偏移档" -> true
var _warm_in := 0.0


func _init(p_world: TableWorld) -> void:
	world = p_world
	name = "BanterFx"


func _process(delta: float) -> void:
	AnimalVoice.poll()
	_warm_in -= delta
	if _warm_in > 0.0:
		return
	_warm_in = WARM_EVERY
	if not voice_enabled:
		return
	for pid in world.patrons:
		var key := "%d:%d" % [world.patrons[pid].species_index, AnimalVoice.bucket_for(pid)]
		if not _warmed.has(key):
			_warmed[key] = true
			AnimalVoice.prebuild(world.patrons[pid].species_index, AnimalVoice.bucket_for(pid))


# —— 丢番茄 ——

func throw_tomato(from_pid: int, target_pid: int, seed: int) -> void:
	# 目标没有酒客(已离场、还没登场)就不演;丢的人没有酒客(观战)从吧台方向丢
	var target: Patron = world.patrons.get(target_pid)
	if target == null or not is_instance_valid(target):
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var hit := hit_point(target, rng)
	var roll := rng.randf() * TAU
	var tomato := MeshKit.add(self, tomato_mesh(), null, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, MeshKit.SHADOW_OFF)
	tomato.name = "Tomato"
	tomato.add_to_group(TOMATO_GROUP)
	var thrower: Patron = world.patrons.get(from_pid)
	if thrower != null and not is_instance_valid(thrower):
		thrower = null
	sfx.emit("tomato_throw")
	if thrower != null and thrower.can_throw():
		# 蓄力时番茄握在右爪里,蓄力结束出手
		remove_child(tomato)
		thrower.right_hand.add_child(tomato)
		tomato.position = HAND_HOLD
		thrower.throw_at(target.head_position())
		await get_tree().create_timer(Patron.THROW_WINDUP).timeout
		if not is_instance_valid(tomato):
			return
		tomato.reparent(self, true)
	else:
		var from := thrower.right_hand.global_position if thrower != null else to_global(SPECTATOR_FROM)
		tomato.global_position = from
	_fly(tomato, target, target_pid, hit, roll)


func hit_point(target: Patron, rng: RandomNumberGenerator) -> Dictionary:
	# 按种子挑落点:{"local": Head 局部坐标的表面点, "normal": 外法线};贴在主颅骨椭球上
	var pick := rng.randf()
	var dir: Vector3 = HITS[0][0]
	var acc := 0.0
	for entry in HITS:
		acc += entry[1]
		if pick <= acc:
			dir = entry[0]
			break
	dir = (dir.normalized() + Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), 0.0) * HIT_JITTER).normalized()
	var ellipsoid := target.skull_ellipsoid()
	return surface_point(ellipsoid[0], ellipsoid[1], dir)


static func surface_point(center: Vector3, radii: Vector3, dir: Vector3) -> Dictionary:
	# 从椭球中心沿 dir 射出到表面的点与该点外法线
	var d := dir.normalized()
	var t := 1.0 / sqrt(pow(d.x / radii.x, 2.0) + pow(d.y / radii.y, 2.0) + pow(d.z / radii.z, 2.0))
	var p := center + d * t
	var n := ((p - center) / (radii * radii)).normalized()
	return {"local": p, "normal": n}


func _fly(tomato: Node3D, target: Patron, target_pid: int, hit: Dictionary, roll: float) -> void:
	# 终点每帧按目标的头重新算:头在晃、在探,番茄照样砸到同一处
	var start := tomato.global_position
	var arc := ARC_BASE + ARC_PER_METER * start.distance_to(target.head_position())
	var tween := tomato.create_tween()
	tween.tween_method(func(t: float) -> void:
		if not is_instance_valid(target):
			return
		var end: Vector3 = target.head.to_global(hit["local"])
		tomato.global_position = start.lerp(end, t) + Vector3.UP * arc * 4.0 * t * (1.0 - t)
		tomato.rotation = SPIN * t, 0.0, 1.0, FLIGHT_TIME)
	tween.tween_callback(func() -> void:
		tomato.queue_free()
		if is_instance_valid(target) and target.is_inside_tree():
			_impact(target, target_pid, hit, roll))


func _impact(target: Patron, target_pid: int, hit: Dictionary, roll: float) -> void:
	var head := target.head
	var at: Vector3 = head.to_global(hit["local"])
	var normal: Vector3 = (head.global_basis * Vector3(hit["normal"])).normalized()
	sfx.emit("tomato_splat")
	Fx.juice_splash(world, at, normal, JUICE_AMOUNT)
	splat(target, hit["local"], hit["normal"], roll)
	target.hit_by_tomato(hit["local"])
	splatted.emit(target_pid)


func splat(target: Patron, local: Vector3, normal: Vector3, roll := 0.0) -> MeshInstance3D:
	# 番茄泥贴在 Head 下(跟着头晃、出局时跟着歪);同一个头最多 MAX_SPLATS 块,最旧的先摘掉
	var head := target.head
	var existing := splats_on(target)
	while existing.size() >= MAX_SPLATS:
		var oldest: Node = existing.pop_front()
		head.remove_child(oldest)
		oldest.queue_free()
	var blob := MeshKit.add(head, splat_mesh(), null, Vector3.ZERO, Vector3.ZERO, Vector3.ONE, MeshKit.SHADOW_OFF)
	blob.name = "TomatoSplat"
	blob.add_to_group(SPLAT_GROUP)
	var n := normal.normalized()
	var basis := Basis.looking_at(-n, Vector3.UP if absf(n.y) < 0.95 else Vector3.BACK) * Basis(Vector3.BACK, roll)
	blob.transform = Transform3D(basis, local - n * SPLAT_SINK)
	blob.scale = Vector3(0.3, 0.3, 0.3)
	var tween := blob.create_tween()
	tween.tween_property(blob, "scale", Vector3(1.2, 1.2, 0.7), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(blob, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_interval(SPLAT_LIFE - SPLAT_FADE - 0.31)
	tween.tween_property(blob, "scale", Vector3.ONE * 0.05, SPLAT_FADE).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(blob, "position", blob.position + Vector3.DOWN * SPLAT_SLIDE, SPLAT_FADE)
	tween.tween_callback(blob.queue_free)
	return blob


static func splats_on(target: Patron) -> Array:
	# 还贴在这个头上的番茄泥(按贴上的先后,最旧的在前;已在释放队列里的不算)
	return target.head.get_children().filter(func(n: Node) -> bool:
		return n.is_in_group(SPLAT_GROUP) and not n.is_queued_for_deletion())


func clear() -> void:
	# 拆台:还在飞的番茄一并收走(贴在头上的泥跟着酒客释放)
	for child in get_children():
		if child.is_in_group(TOMATO_GROUP):
			remove_child(child)
			child.queue_free()


# —— 说话 ——

func say(pid: int, phrase_id: int, fallback_species := 0) -> Dictionary:
	# 返回 AnimalVoice 的时间表(界面逐字显示气泡)。没有酒客的人(观战、迟到)声音从吧台方向来
	var patron: Patron = world.patrons.get(pid)
	if patron != null and not is_instance_valid(patron):
		patron = null
	var species := patron.species_index if patron != null else Species.sanitize(fallback_species)
	if species == Species.UNASSIGNED:
		species = 0
	var bucket := AnimalVoice.bucket_for(pid)
	var plan := AnimalVoice.phrase_layout(species, phrase_id, bucket)
	if patron != null:
		var times := PackedFloat32Array()
		for syl: Dictionary in plan["syllables"]:
			times.append(syl["t"])
		patron.talk(times)
	if voice_enabled:
		_voice_player(patron).stream = AnimalVoice.phrase_stream(species, phrase_id, bucket)
		_voice_player(patron).play()
	return plan


func _voice_player(patron: Patron) -> AudioStreamPlayer3D:
	# 每个酒客头上一个声源(第一次说话时建,跟着酒客释放);没有酒客的人共用吧台上方那一个
	var parent: Node3D = patron.head if patron != null else self
	var player: AudioStreamPlayer3D = parent.get_node_or_null("Voice")
	if player == null:
		player = AudioStreamPlayer3D.new()
		player.name = "Voice"
		player.bus = VOICE_BUS
		player.volume_db = VOICE_DB
		player.max_db = VOICE_MAX_DB
		player.unit_size = VOICE_UNIT_SIZE
		parent.add_child(player)
		if patron == null:
			player.position = SPECTATOR_FROM
		else:
			player.position = Vector3(0, 0.12, -0.1)
	return player


# —— 网格(MeshForge 缓存,道具共用材质)——

static func tomato_mesh() -> ArrayMesh:
	# 红色扁球 + 五片绿色萼片 + 一小截蒂;原点在球心
	return MeshForge.cached("banter:tomato", func(f: MeshForge):
		var r := TOMATO_RADIUS
		f.paint(TOMATO_RED, 0.32)
		f.sphere(r, 16, MeshForge.xf(Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 0.84, 1.0)))
		f.paint(LEAF_GREEN, 0.7)
		for k in 5:
			var a := TAU * k / 5.0
			f.sphere(r * 0.42, 8, MeshForge.xf(Vector3(cos(a) * r * 0.38, r * 0.8, sin(a) * r * 0.38),
				Vector3(0, -rad_to_deg(a), 0), Vector3(1.0, 0.18, 0.4)))
		f.cylinder(r * 0.09, r * 0.12, r * 0.4, 6, MeshForge.CAPS_TOP, MeshForge.xf(Vector3(0, r * 0.95, 0))),
		{&"main": WorldMaterials.prop()})


static func splat_mesh() -> ArrayMesh:
	# 砸扁的番茄泥:不规则的扁片(中间一坨加一圈大小不一的溅瓣),带亮一点的果肉块和几粒籽;
	# 局部 +Z 是外法线,厚度方向压扁,背面压进头里
	return MeshForge.cached("banter:splat", func(f: MeshForge):
		var shapes := [[Vector3(0, 0, 0), Vector3(0.062, 0.056, 0.02), PULP_RED]]
		var lobes := [[0.0, 0.07, 0.03], [1.3, 0.065, 0.024], [2.4, 0.075, 0.028], [3.5, 0.06, 0.02], [4.6, 0.072, 0.026],
			[5.5, 0.058, 0.018]]
		for lobe in lobes:
			var a: float = lobe[0]
			shapes.append([Vector3(cos(a), sin(a), 0.0) * lobe[1], Vector3(lobe[2], lobe[2] * 0.85, 0.012), PULP_RED])
		f.push(MeshForge.xf(Vector3.ZERO, Vector3.ZERO, Vector3(SPLAT_SIZE, SPLAT_SIZE, 1.0)))
		f.paint(PULP_RED, 0.22)
		f.blob(Vector3(0, 0, 0.001), shapes, 24, 10, 0.02)
		f.paint(PULP_LIGHT, 0.25)
		f.sphere(0.026, 10, MeshForge.xf(Vector3(0.012, 0.01, 0.014), Vector3.ZERO, Vector3(1.0, 0.8, 0.45)))
		f.sphere(0.018, 8, MeshForge.xf(Vector3(-0.03, -0.02, 0.01), Vector3.ZERO, Vector3(1.0, 0.7, 0.4)))
		f.paint(SEED_YELLOW, 0.4)
		for k in 6:
			var a := 0.7 + TAU * k / 6.0
			f.sphere(0.0055, 5, MeshForge.xf(Vector3(cos(a) * 0.03, sin(a) * 0.026, 0.02), Vector3(0, 0, rad_to_deg(a)),
				Vector3(1.0, 0.6, 0.5)))
		f.paint(TOMATO_RED, 0.3)   # 一片卷起来的番茄皮
		f.sphere(0.03, 10, MeshForge.xf(Vector3(-0.045, 0.035, 0.012), Vector3(0, 0, 30), Vector3(1.0, 0.55, 0.3)))
		f.pop(),
		{&"main": WorldMaterials.prop()})
