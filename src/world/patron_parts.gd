class_name PatronParts
# 酒客部件:物种基本信息表(名字、主色,等待厅名单用)与各部件的共享网格。网格由 PatronBuilder 按物种外观
# (species/*.gd)生成,每个动画枢轴下一份,按「物种:部件」缓存、启动时后台预建。动画逻辑在 Patron 中。


const SPECIES := [
	{
		"id": "fox", "label": "狐狸",
		"fur": Color(0.80, 0.40, 0.14), "muzzle": Color(0.80, 0.74, 0.62), "dark": Color(0.18, 0.08, 0.04),
		"coat": Color(0.13, 0.17, 0.3), "accent": Color(0.82, 0.62, 0.25), "hat": "top", "ears": "pointy",
	},
	{
		"id": "bear", "label": "熊",
		"fur": Color(0.36, 0.21, 0.11), "muzzle": Color(0.66, 0.5, 0.34), "dark": Color(0.12, 0.07, 0.04),
		"coat": Color(0.42, 0.11, 0.09), "accent": Color(0.86, 0.76, 0.52), "hat": "bowler", "ears": "round",
	},
	{
		"id": "pig", "label": "猪",
		"fur": Color(0.76, 0.47, 0.45), "muzzle": Color(0.80, 0.55, 0.52), "dark": Color(0.45, 0.2, 0.2),
		"coat": Color(0.2, 0.3, 0.17), "accent": Color(0.85, 0.3, 0.22), "hat": "cap", "ears": "floppy",
	},
	{
		"id": "cat", "label": "猫",
		"fur": Color(0.46, 0.47, 0.52), "muzzle": Color(0.88, 0.87, 0.85), "dark": Color(0.1, 0.1, 0.12),
		"coat": Color(0.3, 0.22, 0.38), "accent": Color(0.42, 0.66, 0.72), "hat": "cowboy", "ears": "cat",
	},
	# 以下四种是子项目②新增:顺序与 Species.IDS 一致(下标随协议冻结);造型在 ②d 按物种配方重做
	{
		"id": "turtle", "label": "乌龟",
		"fur": Color(0.42, 0.55, 0.28), "muzzle": Color(0.76, 0.68, 0.42), "dark": Color(0.4, 0.33, 0.18),
		"coat": Color(0.55, 0.16, 0.12), "accent": Color(0.78, 0.62, 0.3), "hat": "bowler", "ears": "none",
	},
	{
		"id": "alpaca", "label": "羊驼",
		"fur": Color(0.78, 0.66, 0.5), "muzzle": Color(0.8, 0.74, 0.62), "dark": Color(0.35, 0.26, 0.18),
		"coat": Color(0.7, 0.16, 0.14), "accent": Color(0.25, 0.6, 0.58), "hat": "cap", "ears": "pointy",
	},
	{
		"id": "monkey", "label": "猴子",
		"fur": Color(0.42, 0.26, 0.14), "muzzle": Color(0.8, 0.62, 0.48), "dark": Color(0.16, 0.09, 0.05),
		"coat": Color(0.7, 0.12, 0.1), "accent": Color(0.82, 0.62, 0.25), "hat": "cap", "ears": "round",
	},
	{
		"id": "crocodile", "label": "鳄鱼",
		"fur": Color(0.24, 0.46, 0.22), "muzzle": Color(0.76, 0.7, 0.45), "dark": Color(0.1, 0.16, 0.08),
		"coat": Color(0.22, 0.22, 0.24), "accent": Color(0.72, 0.16, 0.12), "hat": "cowboy", "ears": "none",
	},
]


static func species(index: int) -> Dictionary:
	return SPECIES[posmod(index, SPECIES.size())]


static func first_free_species(used: Array) -> int:
	# 新酒客取第一个没人用的物种,同桌不撞脸;物种全被占用(人数超过物种数)时才轮流重复
	return Species.first_free(used)


# —— 调色板:部件键 → [sRGB 颜色, 粗糙度, 金属度] ——

# 去过曝:近白的底色在烛光 + ACES 下会削顶发白。所有酒客颜色按最大通道等比压到 ALBEDO_CAP 以下(保持色相);
# 爪子在桌上离烛光最近,再压暗一档
const ALBEDO_CAP := 0.65
const EYE_WHITE := Color(0.65, 0.64, 0.62)   # = patron_eye.gdshader 的巩膜(约 0.66)
const PAW_SHADE := 0.8
const LAPEL_DARKEN := 0.35   # 翻领用压暗的外套色:浅色强调色做翻领会在胸前拼出一个突兀的「A」字
# 每个酒客的部件网格(左右手不对称,各一份;耳朵、眉毛、手臂左右共用)
const PARTS := ["body", "neck", "head", "eyes", "brow", "ear", "hat", "arm", "paw_l", "paw_r", "fist", "legs"]


static func look_of(spec: Dictionary) -> Dictionary:
	return SpeciesLooks.look(Species.index_of(spec["id"]))


static func palette(spec: Dictionary) -> Dictionary:
	# 物种调色板(sRGB,已封顶):部件键 → Color
	return SpeciesLooks.palette(look_of(spec))


static func capped(c: Color) -> Color:
	# 按最大通道等比缩放到 ALBEDO_CAP 以下,色相不变
	var peak := maxf(c.r, maxf(c.g, c.b))
	return c if peak <= ALBEDO_CAP else Color(c.r * ALBEDO_CAP / peak, c.g * ALBEDO_CAP / peak, c.b * ALBEDO_CAP / peak, c.a)


# —— 共享网格 ——

static func recipes(spec: Dictionary) -> Dictionary:
	# 部件名 → 配方;Patron 构建与启动预建共用这张表,缓存 key 只在 part_key 里拼
	var index := Species.index_of(spec["id"])
	var look := SpeciesLooks.look(index)
	var hooks := SpeciesLooks.script_of(index)
	var pal := SpeciesLooks.palette(look)
	return {
		"body": func(f): PatronBuilder.body(f, look, pal, hooks),
		"neck": func(f): PatronBuilder.neck(f, look, pal),
		"head": func(f): PatronHeadBuilder.head(f, look, pal, hooks),
		"eyes": func(f): PatronHeadBuilder.eyes(f, look),
		"brow": func(f): PatronHeadBuilder.brow(f, look, pal),
		"ear": func(f): PatronHeadBuilder.ear(f, look, pal),
		"hat": func(f): PatronHatBuilder.hat(f, look, pal, hooks),
		"arm": func(f): PatronBuilder.arm(f, look, pal, hooks),
		"paw_l": func(f): PatronBuilder.paw(f, look, pal, -1.0),
		"paw_r": func(f): PatronBuilder.paw(f, look, pal, 1.0),
		"fist": func(f): PatronBuilder.fist(f, look, pal),
		"legs": func(f): PatronBuilder.legs(f, look, pal, hooks),
	}


static func part_key(spec: Dictionary, part: String) -> String:
	return "patron:%s:%s" % [spec["id"], part]


static func part_material(part: String) -> Material:
	return WorldMaterials.patron_eye() if part == "eyes" else WorldMaterials.patron()


static func part_mesh(spec: Dictionary, part: String) -> ArrayMesh:
	# 酒客部件网格:按「物种:部件」缓存,所有酒客共用 WorldMaterials.patron()(眼睛用 patron_eye)
	return MeshForge.cached(part_key(spec, part), recipes(spec)[part], {&"main": part_material(part)})


static func chair_mesh() -> ArrayMesh:
	return ChairBuilder.mesh()


static func forge_jobs(first := -1) -> Array:
	# 启动时后台预建:所有物种的部件 + 椅子(材质在主线程先建好);first 指定的物种排最前面
	var jobs := [["chair", ChairBuilder.recipe, {&"main": WorldMaterials.wood("dark", true)}]]
	var order := range(SPECIES.size())
	if first >= 0 and first < SPECIES.size():
		order.erase(first)
		order.push_front(first)
	for i in order:
		var spec: Dictionary = SPECIES[i]
		var table := recipes(spec)
		for part in PARTS:
			jobs.append([part_key(spec, part), table[part], {&"main": part_material(part)}])
	return jobs
