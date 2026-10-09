class_name PartyCannon
extends Node3D
# 结算礼炮(规格 2026-10-09-winner-celebration):摆在桌沿上的一门玩具小炮——木头炮架、两只红轮子、
# 胖乎乎的粉彩条纹炮管(粉 / 薄荷 / 奶黄,金色炮口箍)斜指上方,炮尾一根亮着火星的引信。
# 原点在桌面上,炮口朝局部 −Z 往上 ELEVATION 度;一份合并网格(prop 材质),不投影(特效件)。
# pop_in:弹出来登场;fire:往后一坐、压扁再弹回(喷彩纸由 Celebration 在 muzzle_transform 处放)。

const ELEVATION := 72.0             # 炮管仰角(度)
const TRUNNION := Vector3(0, 0.085, 0.01)   # 炮管转轴(炮架顶上)
const MUZZLE := 0.16                # 转轴到炮口的距离(沿炮管)
const SCALE := 1.15
const POP_TIME := 0.45
const RECOIL := 0.05                # 开炮往后坐的距离(米,局部 +Z)

var _mesh: MeshInstance3D
var _rest := Transform3D.IDENTITY
var _recoil: Tween = null


func _ready() -> void:
	_mesh = MeshKit.add(self, mesh(), null)
	_mesh.name = "CannonMesh"
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.scale = Vector3.ONE * SCALE
	_rest = _mesh.transform


static func barrel_axis() -> Vector3:
	# 炮管方向(局部):朝 −Z、往上 ELEVATION 度
	var el := deg_to_rad(ELEVATION)
	return Vector3(0.0, sin(el), -cos(el))


func muzzle_transform() -> Transform3D:
	# 炮口(全局):原点在炮口中心,+Y 沿炮管往外(ConfettiFx 的喷射方向)
	var axis := barrel_axis()
	var local := Transform3D(Basis(Quaternion(Vector3.UP, axis)), (TRUNNION + axis * MUZZLE) * SCALE)
	return global_transform * local


func pop_in(delay := 0.0) -> void:
	# 从桌面上「啵」地弹出来
	scale = Vector3.ONE * 0.01
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_property(self, "scale", Vector3.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func fire() -> void:
	# 开炮:整门炮往后一坐、压扁,再弹回原位
	if _recoil != null and _recoil.is_valid():
		_recoil.kill()
	_mesh.transform = _rest
	var back := Transform3D(_rest.basis * Basis.from_scale(Vector3(1.12, 0.82, 1.12)), _rest.origin + Vector3(0, 0, RECOIL))
	_recoil = create_tween()
	_recoil.tween_property(_mesh, "transform", back, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_recoil.tween_property(_mesh, "transform", _rest, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


static func mesh() -> ArrayMesh:
	return MeshForge.cached("prop:party_cannon", recipe, {&"main": WorldMaterials.prop()})


static func recipe(f: MeshForge) -> void:
	# 炮架:圆角木块(两层叠出倒角感)
	f.paint(Color(0.62, 0.42, 0.26), 0.75)
	f.box(Vector3(0.1, 0.05, 0.13), MeshForge.xf(Vector3(0, 0.05, 0.01)))
	f.paint(Color(0.52, 0.34, 0.2), 0.8)
	f.box(Vector3(0.11, 0.012, 0.14), MeshForge.xf(Vector3(0, 0.024, 0.01)))
	# 轮子:红色胖轮 + 金色轮毂
	for side: float in [-1.0, 1.0]:
		f.paint(Color(0.78, 0.3, 0.3), 0.6)
		f.cylinder(0.042, 0.042, 0.022, 20, MeshForge.CAPS_BOTH, MeshForge.xf(Vector3(0.064 * side, 0.042, 0.02), Vector3(0, 0, 90)))
		f.paint(Color(0.86, 0.7, 0.36), 0.45, 0.6)
		f.sphere(0.016, 10, MeshForge.xf(Vector3(0.077 * side, 0.042, 0.02)))
	# 炮管:沿轴一段段条纹(局部 +Y 是炮管方向,再整体转到仰角)
	f.push(Transform3D(Basis(Quaternion(Vector3.UP, barrel_axis())), TRUNNION))
	f.paint(Color(0.86, 0.7, 0.36), 0.45, 0.6)
	f.sphere(0.03, 14, MeshForge.xf(Vector3(0, -0.075, 0)))   # 炮尾圆球
	var stripes := [[Color(1.0, 0.6, 0.7), 0.05], [Color(0.98, 0.94, 0.84), 0.022], [Color(0.55, 0.86, 0.76), 0.05],
		[Color(0.98, 0.94, 0.84), 0.022], [Color(1.0, 0.84, 0.42), 0.042]]
	var y := -0.06
	var r := 0.044
	for stripe in stripes:
		var h: float = stripe[1]
		var top_r := r - h * 0.08
		f.paint(stripe[0], 0.55)
		f.cylinder(top_r, r, h, 20, MeshForge.CAPS_NONE, MeshForge.xf(Vector3(0, y + h * 0.5, 0)))
		y += h
		r = top_r
	# 金色炮口箍(往外翻一点)+ 黑洞洞的炮口
	f.paint(Color(0.86, 0.7, 0.36), 0.45, 0.6)
	f.cylinder(r + 0.012, r + 0.004, 0.022, 20, MeshForge.CAPS_BOTTOM, MeshForge.xf(Vector3(0, y + 0.011, 0)))
	f.torus(r - 0.002, r + 0.013, 20, MeshForge.xf(Vector3(0, y + 0.022, 0)))
	f.paint(Color(0.12, 0.08, 0.1), 0.9)
	f.cylinder(r - 0.002, r - 0.002, 0.004, 16, MeshForge.CAPS_TOP, MeshForge.xf(Vector3(0, y + 0.016, 0)))
	# 炮尾上翘的引信,头上一点亮着的火星
	f.paint(Color(0.3, 0.22, 0.16), 0.9)
	f.tube(PackedVector3Array([Vector3(0, -0.06, 0.035), Vector3(0, -0.07, 0.06), Vector3(0, -0.055, 0.08)]), 0.005, 6)
	f.paint(Color(1.0, 0.75, 0.35), 0.4)
	f.glow = Vector2(1.0, 0.0)
	f.sphere(0.009, 8, MeshForge.xf(Vector3(0, -0.053, 0.083)))
	f.glow = Vector2.ZERO
	f.pop()
