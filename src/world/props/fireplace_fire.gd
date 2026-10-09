class_name FireplaceFire
# 炉膛里的火:一对铸铁柴架(前柱顶着黄铜球,后段一根横杠架柴)、架在上面的三根柴(后面一根对半劈开、
# 前面一根整木、上面斜搭一根四瓣柴;劈面都朝下,朝上露出的是烧焦的树皮)、柴下面隆起的炭床与散落的炭块。
# 都不投影(见 TavernFireplace)。坐标为壁炉本地。


const ANDIRON_X := 0.29
const ANDIRON_FRONT := 0.47
const ANDIRON_BACK := 0.13
const BAR_HEIGHT := 0.2              # 架柴横杠的高度(炉床面以上的绝对高度)
const BAR_RADIUS := 0.011
# 柴:[截面, 半径, 长度, 位置, 旋转(度), 种子]。生成时柴沿 Z 轴,转 90° 横躺
const LOGS := [
	["half", 0.075, 0.66, Vector3(0.0, 0.215, 0.19), Vector3(0, 90, 0), 11],
	["round", 0.066, 0.58, Vector3(0.03, 0.276, 0.4), Vector3(0, 85, 0), 12],
	["quarter", 0.085, 0.6, Vector3(-0.05, 0.32, 0.3), Vector3(-12, 58, 45), 13],
]
const BED_AT := Vector3(0, 0.12, 0.29)
const BED_SIZE := Vector3(0.42, 0.06, 0.2)   # 炭床隆起的半宽、高、半深
const COALS := 11
const SEED := 77


static func add_to(batch: MeshBatch) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for side in [-1.0, 1.0]:
		_andiron(batch, side * ANDIRON_X)
	var logs := FireplaceMaterials.logs()
	for spec in LOGS:
		batch.add_part(FireplaceLogs.log_arrays(spec[1], spec[2], spec[0], spec[5]), logs, spec[3], spec[4])
	_ember_bed(batch, rng)


static func _andiron(batch: MeshBatch, x: float) -> void:
	# 前柱是车出来的铁柱,脚下两只外撇的弯脚;横杠从前柱腰部伸向后壁,尾端弯下去着地
	var iron := WorldMaterials.iron()
	var floor_y := TavernFireplace.HEARTH_TOP
	var post := PackedVector2Array([Vector2(0, 0), Vector2(0.026, 0), Vector2(0.026, 0.012), Vector2(0.013, 0.03),
		Vector2(0.01, 0.12), Vector2(0.017, 0.14), Vector2(0.01, 0.16), Vector2(0.01, 0.225),
		Vector2(0.019, 0.24), Vector2(0.019, 0.24), Vector2(0, 0.248)])
	batch.add_part(MeshShapes.lathe(post, 10), iron, Vector3(x, floor_y, ANDIRON_FRONT))
	batch.add_part(MeshKit.sphere(0.024, 12), WorldMaterials.brass(), Vector3(x, floor_y + 0.268, ANDIRON_FRONT))
	var bar := PackedVector3Array([Vector3(x, BAR_HEIGHT, ANDIRON_FRONT), Vector3(x, BAR_HEIGHT + 0.004, 0.3),
		Vector3(x, BAR_HEIGHT, ANDIRON_BACK + 0.02), Vector3(x, BAR_HEIGHT - 0.03, ANDIRON_BACK),
		Vector3(x, floor_y + 0.004, ANDIRON_BACK - 0.01)])
	batch.add_part(MeshShapes.tube(bar, BAR_RADIUS, 6), iron)
	for side in [-1.0, 1.0]:
		var foot := PackedVector3Array([Vector3(x, floor_y + 0.03, ANDIRON_FRONT),
			Vector3(x + side * 0.04, floor_y + 0.02, ANDIRON_FRONT + 0.025),
			Vector3(x + side * 0.065, floor_y + 0.008, ANDIRON_FRONT + 0.035)])
		batch.add_part(MeshShapes.tube(foot, PackedFloat32Array([0.011, 0.009, 0.008]), 6), iron)


static func _ember_bed(batch: MeshBatch, rng: RandomNumberGenerator) -> void:
	# 炭床:压扁的球,表面按几组正弦起伏成一块块炭;前沿散落几块小炭
	var embers := FireplaceMaterials.embers()
	var bed := MeshShapes.deform(MeshKit.sphere(1.0, 20).get_mesh_arrays(), func(v: Vector3) -> Vector3:
		var lumps := 1.0 + 0.25 * sin(v.x * 9.0 + 1.3) * sin(v.z * 7.0 + 0.4) + 0.15 * sin(v.x * 17.0 + v.z * 13.0)
		return Vector3(v.x * BED_SIZE.x, maxf(v.y, -0.2) * BED_SIZE.y * lumps, v.z * BED_SIZE.z))
	batch.add_part(bed, embers, BED_AT)
	for i in COALS:
		var size := rng.randf_range(0.022, 0.038)
		var coal := MeshShapes.deform(MeshKit.sphere(size, 8).get_mesh_arrays(), func(v: Vector3) -> Vector3:
			return Vector3(v.x * 1.3, v.y * 0.7, v.z) * (1.0 + 0.2 * sin(v.x * 90.0 + v.z * 70.0)))
		var at := Vector3(rng.randf_range(-0.36, 0.36), BED_AT.y + size * 0.3, rng.randf_range(0.36, 0.47))
		batch.add_part(coal, embers, at, Vector3(0, rng.randf() * 360.0, 0))
