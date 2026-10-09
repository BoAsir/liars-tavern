class_name PatronSkin
# 酒客材质:槽位表 + 每名酒客一份着色器材质(src/world/shaders/patron.gdshader)。
# 网格按物种缓存共用(MeshBatch 的字符串槽位 SLOT),每个部件在顶点色里带上自己的槽位(tag()),
# 着色器按槽位从本酒客的调色板取颜色、选质感:一个动画枢轴只需一次绘制调用,不必按材质拆表面。
# 出局时只需补间这一份材质的 death 参数,一个人单独褪色。


const SHADER := preload("res://src/world/shaders/patron.gdshader")
const SLOT := "skin"        # MeshBatch 槽位名:实例化时绑定到该酒客的材质
const SLOTS := 32           # 与着色器的 SLOTS 一致
const FADE_TIME := 1.4

# 槽位(写进顶点色 alpha)
enum {
	FUR, MUZZLE, DARK, SKIN, NOSE, EYE, IRIS, MOUTH, TONGUE, TEETH, LASH, WHISKER, CLAW, PAD,
	COAT, TRIM, VEST, SHIRT, TIE, POCKET, BRASS, TROUSERS, SHOES, SOLE, HAT, HAT_BAND, STONE, LINING, INNER,
}
# 物种表 palette / patterns 里用的槽位名
const SLOT_NAMES := {
	"fur": FUR, "muzzle": MUZZLE, "dark": DARK, "skin": SKIN, "nose": NOSE, "eye": EYE, "iris": IRIS,
	"mouth": MOUTH, "tongue": TONGUE, "teeth": TEETH, "lash": LASH, "whisker": WHISKER, "claw": CLAW, "pad": PAD,
	"coat": COAT, "trim": TRIM, "vest": VEST, "shirt": SHIRT, "tie": TIE, "pocket": POCKET, "brass": BRASS,
	"trousers": TROUSERS, "shoes": SHOES, "sole": SOLE, "hat": HAT, "hat_band": HAT_BAND, "stone": STONE,
	"lining": LINING, "inner": INNER,
}
# 质感类型(与着色器的 K_* 一致)
enum { KIND_FUR, KIND_SKIN, KIND_GLOSS, KIND_EYE, KIND_IRIS, KIND_CLOTH, KIND_SATIN, KIND_METAL }
# 布料图案(与着色器的 P_* 一致)
const PATTERNS := {"plain": 0, "pinstripe": 1, "check": 2, "tweed": 3, "stripes": 4, "velvet": 5}
const PUPILS := {"round": 0, "slit": 1, "bar": 2}

# 槽位 → [质感, 粗糙度, 绒面光泽(边缘光)]
const SURFACES := {
	FUR: [KIND_FUR, 0.82, 0.3], MUZZLE: [KIND_FUR, 0.82, 0.3], DARK: [KIND_FUR, 0.8, 0.3],
	SKIN: [KIND_SKIN, 0.55, 0.15], NOSE: [KIND_GLOSS, 0.25, 0.0], EYE: [KIND_EYE, 0.12, 0.0],
	IRIS: [KIND_IRIS, 0.06, 0.0], MOUTH: [KIND_SKIN, 0.5, 0.0], TONGUE: [KIND_SKIN, 0.35, 0.0],
	TEETH: [KIND_GLOSS, 0.3, 0.0], LASH: [KIND_GLOSS, 0.5, 0.0], WHISKER: [KIND_GLOSS, 0.5, 0.0],
	CLAW: [KIND_GLOSS, 0.3, 0.0], PAD: [KIND_SKIN, 0.45, 0.1],
	COAT: [KIND_CLOTH, 0.84, 0.25], TRIM: [KIND_SATIN, 0.42, 0.3], VEST: [KIND_CLOTH, 0.78, 0.2],
	SHIRT: [KIND_CLOTH, 0.7, 0.12], TIE: [KIND_SATIN, 0.38, 0.35], POCKET: [KIND_SATIN, 0.4, 0.3],
	BRASS: [KIND_METAL, 0.3, 0.0], TROUSERS: [KIND_CLOTH, 0.85, 0.15], SHOES: [KIND_GLOSS, 0.3, 0.0],
	SOLE: [KIND_CLOTH, 0.9, 0.0], HAT: [KIND_CLOTH, 0.8, 0.25], HAT_BAND: [KIND_SATIN, 0.4, 0.3],
	STONE: [KIND_GLOSS, 0.1, 0.0], LINING: [KIND_SATIN, 0.45, 0.2], INNER: [KIND_FUR, 0.7, 0.2],
}
# 物种表没给时的通用颜色(sRGB)
const DEFAULT_COLORS := {
	EYE: Color(0.97, 0.95, 0.9), IRIS: Color(0.45, 0.3, 0.15), MOUTH: Color(0.26, 0.07, 0.08),
	TONGUE: Color(0.86, 0.38, 0.42), TEETH: Color(0.97, 0.95, 0.88), LASH: Color(0.05, 0.035, 0.03),
	WHISKER: Color(0.95, 0.93, 0.88), CLAW: Color(0.9, 0.86, 0.78), PAD: Color(0.22, 0.12, 0.12),
	SHIRT: Color(0.88, 0.86, 0.81), BRASS: Color(0.8, 0.58, 0.26), SHOES: Color(0.1, 0.06, 0.045),
	SOLE: Color(0.07, 0.045, 0.035), STONE: Color(0.75, 0.1, 0.14), LINING: Color(0.42, 0.08, 0.1),
	SKIN: Color(0.9, 0.62, 0.6),
}


static func tag(slot: int, light := 0.0, dark := 0.0, shade := 1.0) -> Color:
	# 部件的顶点色:rgb = 明暗 / 往浅色混合 / 往深色混合,alpha = 槽位编号
	return Color(shade, light, dark, slot / 255.0)


static func palette_of(spec: Dictionary) -> Dictionary:
	# 槽位 → 颜色:物种表的必备五色 + palette 里的补充,其余按这几色推导
	var coat: Color = spec["coat"]
	var accent: Color = spec["accent"]
	var colors := DEFAULT_COLORS.duplicate()
	colors.merge({
		FUR: spec["fur"], MUZZLE: spec["muzzle"], DARK: spec["dark"], NOSE: spec["dark"].darkened(0.5),
		COAT: coat, TRIM: coat.darkened(0.25), VEST: coat.lightened(0.15), TIE: accent, POCKET: accent,
		TROUSERS: coat.darkened(0.35), HAT: spec["dark"].darkened(0.4), HAT_BAND: accent, INNER: spec["muzzle"],
	}, true)
	var extra: Dictionary = spec.get("palette", {})
	for name in extra:
		colors[SLOT_NAMES[name]] = extra[name]
	return colors


static func material(spec: Dictionary) -> ShaderMaterial:
	# 每名酒客一份(出局时单独褪色);着色器全体共用,首个酒客上桌后管线即已编译,之后新建材质不卡顿
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	var palette := palette_of(spec)
	var patterns: Dictionary = spec.get("patterns", {})
	var colors := PackedColorArray()
	var looks := PackedVector4Array()
	var kinds := PackedInt32Array()
	var bare: bool = spec.get("hide", "fur") == "skin"   # 猪:皮肤而不是毛皮(不画毛丝,带一点透光)
	for slot in SLOTS:
		colors.append(palette.get(slot, Color(0.5, 0.5, 0.5)))
		var surface: Array = SURFACES.get(slot, [KIND_CLOTH, 0.8, 0.0])
		var pattern: Array = ["plain", 0.0]
		for name in patterns:
			if SLOT_NAMES[name] == slot:
				pattern = patterns[name]
		looks.append(Vector4(surface[1], surface[2], PATTERNS[pattern[0]], pattern[1]))
		kinds.append(KIND_SKIN if bare and surface[0] == KIND_FUR else surface[0])
	mat.set_shader_parameter("palette", colors)
	mat.set_shader_parameter("look", looks)
	mat.set_shader_parameter("kinds", kinds)
	mat.set_shader_parameter("light_slot", MUZZLE)
	mat.set_shader_parameter("dark_slot", DARK)
	mat.set_shader_parameter("pupil_shape", PUPILS.get(spec.get("eyes", {}).get("pupil", "round"), 0))
	mat.set_shader_parameter("ink", spec.get("ink", (spec["coat"] as Color).darkened(0.65)))
	return mat


static func fade_out(tween: Tween, mat: ShaderMaterial) -> void:
	# 出局:全身褪成灰色(着色器按亮度混合,深浅层次仍在)。用 tween_method 直接设参数:
	# 无窗口(测试)时着色器不编译、材质上没有 shader_parameter/* 属性,tween_property 会报错
	tween.tween_method(func(v: float) -> void: mat.set_shader_parameter("death", v), 0.0, 1.0, FADE_TIME)
