extends RefCounted
# 猴子「酒馆跑堂」:圆头、桃色心形脸罩(两瓣绕眼、头顶留一撮棕色美人尖)、咧开的大笑嘴露一排牙;大圆侧耳配桃色内耳;
# 红色药盒帽带金箍、斜戴、颏带贴着脸颊绕到下巴;红色短门童夹克(立领、金穗边、肩章、双排 8 颗铜扣)、
# 黑裤金侧条只到小腿、下面露出毛腿;光脚长趾;长卷尾从座面与靠背之间的缝穿出、绕左后椅腿 1.5 圈、尾尖上卷。


const LOOK := {
	"id": "monkey",
	"gun_clearance": 0.234,   # 持枪净空(米,已含 Q 版头的放大):按举枪流程实测最小值(含抖耳)再留 ≥4 mm
	"palette": {
		"fur": Color(0.42, 0.26, 0.14), "muzzle": Color(0.80, 0.62, 0.48), "dark": Color(0.16, 0.09, 0.05),
		"fur_back": Color(0.34, 0.2, 0.1), "coat": Color(0.70, 0.12, 0.10), "accent": Color(0.82, 0.62, 0.25),
		"pants": Color(0.1, 0.09, 0.09), "face": Color(0.80, 0.62, 0.48), "nose": Color(0.35, 0.2, 0.15),
		"pad": Color(0.62, 0.45, 0.35), "mouth": Color(0.24, 0.07, 0.06), "tooth": Color(0.80, 0.78, 0.72),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.16, 0.15, 0.155), "fur"],
			[Vector3(0, 0.15, 0.05), Vector3(0.14, 0.12, 0.11), "fur_back"],                  # 后脑压暗
			[Vector3(0.047, 0.153, -0.116), Vector3(0.064, 0.07, 0.054), "face", "mirror"],   # 心形脸罩的两瓣(绕眼)
			[Vector3(0, 0.078, -0.122), Vector3(0.088, 0.062, 0.064), "face"],                # 口鼻
			[Vector3(0, 0.036, -0.11), Vector3(0.062, 0.036, 0.05), "face"],                  # 下巴 = 心尖
			[Vector3(0, 0.212, -0.118), Vector3(0.024, 0.03, 0.03), "fur"],                   # 两瓣之间的美人尖
		],
		"blend": 0.03,
		"nose": {"pos": Vector3(0, 0.112, -0.178), "radii": Vector3(0.017, 0.009, 0.008), "color": "nose"},
		"mouth": {"kind": "wide", "pos": Vector3(0, 0.068, -0.186), "width": 0.094, "thickness": 0.0036},
	},
	"eyes": {"pos": Vector3(0.05, 0.158, -0.158), "size": Vector3(0.036, 0.042, 0.018), "iris": Color(0.36, 0.22, 0.1),
		"pupil": 0, "lid_rest": 0.1, "lashes": false},
	"brows": {"pos": Vector3(0.052, 0.212, -0.163), "color": "dark", "width": 0.048},
	"ears": {"kind": "side_round", "pivot": Vector3(0.158, 0.13, 0.01), "rot": Vector3(0, -70, 0),
		"size": Vector3(0.066, 0.07, 0.022), "inner": "face"},
	"hat": {"kind": "pillbox", "pivot": Vector3(0.02, 0.255, 0.0), "rot": Vector3(-6, 0, -12), "radius": 0.07, "color": "coat",
		"chin_strap": false},
	"neck": {"base": Vector3(0, 0.55, -0.02), "radius": 0.068, "color": "fur"},
	"body": {"build": "slim", "coat": "coat", "belly": "coat", "pants": "pants", "buttons": 0, "neckwear": "none", "collar": "coat"},
	"arms": {"sleeve": "coat", "cuff": "accent"},
	"paws": {"color": "face", "pads": "pad", "fingers": 4, "length": 0.044},
	"legs": {"pants": "pants", "foot": "bare", "foot_color": "face"},
	# 尾根:从衣摆下穿过座面与靠背之间的缝,到座面后缘之后往下(绕椅腿的部分在 extras 里接上)。
	# 整条尾巴不摆(摆动权重 0、幅度 0):绕在椅腿上的部分不能跟着晃
	"tail": {"path": [Vector3(0, 0.5, 0.24), Vector3(-0.03, 0.5, 0.33), Vector3(-0.075, 0.497, 0.39), Vector3(-0.125, 0.46, 0.42),
		Vector3(-0.155, 0.42, 0.415)], "radius": 0.018, "tip_radius": 0.017, "color": "fur",
		"sway_range": Vector2(2.0, 3.0), "sway": 0.0},
	"anim": {"look_pitch_min": -0.45, "blink_speed": 1.0},
}

# 尾巴绕左后椅腿:腿轴 (−0.20, z 0.32),离轴 0.055,1.5 圈,y 从 0.38 降到 0.12
const WRAP_AXIS := Vector2(-0.2, 0.32)
const WRAP_RADIUS := 0.055
const WRAP_TOP := 0.38
const WRAP_BOTTOM := 0.12
const WRAP_START := 1.05       # 起始角(弧度,x 轴起逆时针看 xz):从靠背后外侧接进来
const WRAP_TURNS := 1.5


static func extras(f: MeshForge, part: String, look: Dictionary, pal: Dictionary) -> void:
	match part:
		"head":
			_grin(f, pal)
		"hat":
			_strap(f, look, pal)
		"body":
			_jacket(f, PatronBuilder.body_shapes(look, pal), pal)
		"legs":
			_legs(f, pal)
			_tail(f, look, pal)


# —— 头:咧嘴笑、帽子颏带 ——

static func _grin(f: MeshForge, pal: Dictionary) -> void:
	# 嘴线下面一弯深色张开的嘴,上沿一排牙
	PatronBuilder.paint(f, pal, "mouth", 0.6, PatronBuilder.SMOOTH)
	f.sphere(1.0, 14, PatronBuilder.xf(Vector3(0, 0.057, -0.176), Vector3(-12, 0, 0), Vector3(0.036, 0.015, 0.012)))
	PatronBuilder.paint(f, pal, "tooth", 0.35, PatronBuilder.SMOOTH)
	f.sphere(1.0, 12, PatronBuilder.xf(Vector3(0, 0.0645, -0.184), Vector3(-12, 0, 0), Vector3(0.03, 0.0055, 0.006)))


static func _strap(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	# 药盒帽颏带:从帽箍两侧贴着脸颊(耳朵前面)绕到下巴底下;按头雕表面取点,再换到帽子局部
	var skull := PatronHeadBuilder.skull_shapes(look, pal)
	var hat: Dictionary = look["hat"]
	var to_hat := MeshForge.xf(hat["pivot"], hat["rot"]).affine_inverse()
	var from_hat := to_hat.affine_inverse()
	var dirs := [Vector3(0.9, 0.05, -0.42), Vector3(0.7, -0.5, -0.5), Vector3(0.32, -0.8, -0.52), Vector3(0.0, -0.84, -0.54)]
	PatronBuilder.paint(f, pal, "dark", 0.6, PatronBuilder.LEATHER)
	for side: float in [-1.0, 1.0]:
		var start := from_hat * Vector3(0.068 * side, 0.01, -0.012)
		var path := PackedVector3Array([to_hat * start])
		for d: Vector3 in dirs:
			var dd := Vector3(d.x * side, d.y, d.z)
			var p := MeshForge.blob_surface(PatronHeadBuilder.HEAD_CENTER, dd, skull, 0.03) + dd.normalized() * 0.004
			path.append(to_hat * p)
		f.tube(path, 0.0028, 5)


# —— 门童夹克 ——

static func _on_body(shapes: Array, from: Vector3, d: Vector3, lift: float) -> Vector3:
	var dn := d.normalized()
	return MeshForge.blob_surface(from, dn, shapes, PatronBuilder.BLOB_K) + dn * lift


static func _jacket(f: MeshForge, shapes: Array, pal: Dictionary) -> void:
	# 立领:红色矮领圈,上沿金边
	PatronBuilder.paint(f, pal, "coat", 0.8, PatronBuilder.CLOTH)
	f.lathe(PackedVector2Array([Vector2(0.088, 0.535), Vector2(0.083, 0.575), Vector2(0.079, 0.578)]), 20)
	PatronBuilder.paint(f, pal, "accent", 0.35, PatronBuilder.METAL, 0.8)
	var collar := PackedVector3Array()
	for k in 21:
		var a := TAU * k / 20.0
		collar.append(Vector3(sin(a) * 0.081, 0.577, cos(a) * 0.081 - 0.02))
	f.tube(collar, 0.0045, 5)
	# 金穗边:下摆一圈 + 前襟两道竖线(贴着躯干表面)
	var hem := PackedVector3Array()
	for k in 25:
		var a := TAU * k / 24.0
		hem.append(_on_body(shapes, Vector3(0, 0.075, -0.02), Vector3(sin(a), 0.0, cos(a)), 0.003))
	f.tube(hem, 0.0055, 5)
	for side: float in [-1.0, 1.0]:
		var line := PackedVector3Array()
		for k in 7:
			var y := lerpf(0.08, 0.5, k / 6.0)
			line.append(_on_body(shapes, Vector3(0, y, 0.0), Vector3(0.085 * side + (y - 0.3) * 0.12 * side, 0.0, -0.17), 0.003))
		f.tube(line, 0.0045, 5)
	# 肩章:肩头一片金色扁垫
	for side: float in [-1.0, 1.0]:
		var top := _on_body(shapes, PatronBuilder.BODY_CENTER, Vector3(0.48 * side, 0.85, -0.02), 0.0)
		f.sphere(1.0, 10, PatronBuilder.xf(top, Vector3(0, 0, -28 * side), Vector3(0.045, 0.012, 0.042)))
	# 双排 8 颗铜扣
	PatronBuilder.paint(f, pal, "brass", 0.3, PatronBuilder.METAL, 1.0)
	for k in 4:
		var y := 0.42 - k * 0.085
		for side: float in [-1.0, 1.0]:
			var p := _on_body(shapes, Vector3(0, y, 0.0), Vector3((0.05 - k * 0.003) * side, 0.0, -0.17), 0.004)
			f.sphere(0.011, 8, PatronBuilder.xf(p, Vector3.ZERO, Vector3(1, 1, 0.7)))


# —— 腿:金侧条、毛腿、长脚趾 ——

static func _legs(f: MeshForge, pal: Dictionary) -> void:
	for side: float in [-1.0, 1.0]:
		var x := 0.1 * side
		# 裤腿外侧的金条(沿腿放样路径,贴在侧面)
		var stripe := PackedVector3Array([Vector3(x + 0.079 * side, 0.475, 0.1), Vector3(x + 0.073 * side, 0.49, -0.02),
			Vector3(x * 1.0 + 0.061 * side, 0.49, -0.115), Vector3(x * 1.02 + 0.055 * side, 0.38, -0.155),
			Vector3(x * 1.035 + 0.051 * side, 0.25, -0.159)])
		var radii := PackedVector2Array()
		for i in stripe.size():
			radii.append(Vector2(0.0025, 0.0075))
		PatronBuilder.paint(f, pal, "accent", 0.45, PatronBuilder.CLOTH)
		f.loft(stripe, radii, 6, Vector2i(1, 1), Transform3D.IDENTITY, PackedColorArray(), Vector2(-1, -1), Vector3(side, 0, 0))
		# 裤脚卷边停在小腿,下面露出棕色毛腿
		PatronBuilder.paint(f, pal, "pants", 0.85, PatronBuilder.CLOTH)
		f.loft(PackedVector3Array([Vector3(x * 1.035, 0.262, -0.159), Vector3(x * 1.035, 0.236, -0.159)]),
			PackedVector2Array([Vector2(0.058, 0.058), Vector2(0.058, 0.058)]), 12)
		PatronBuilder.paint(f, pal, "fur", 0.8, PatronBuilder.FUR)
		f.loft(PackedVector3Array([Vector3(x * 1.035, 0.24, -0.159), Vector3(x * 1.04, 0.15, -0.158), Vector3(x * 1.04, 0.06, -0.162)]),
			PackedVector2Array([Vector2(0.052, 0.052), Vector2(0.05, 0.05), Vector2(0.05, 0.05)]), 12)
		# 长脚趾:四根往前伸、微微下勾,大脚趾朝内岔开
		PatronBuilder.paint(f, pal, "face", 0.75, PatronBuilder.FUR)
		var at := Vector3(x * 1.04, 0.0, -0.17)
		for k in 4:
			var tx := (k - 1.5) * 0.022
			var root := at + Vector3(tx, 0.03, -0.075)
			f.loft(PackedVector3Array([root, root + Vector3(tx * 0.15, 0.002, -0.03), root + Vector3(tx * 0.25, -0.01, -0.052),
				root + Vector3(tx * 0.27, -0.016, -0.06)]),
				PackedVector2Array([Vector2(0.012, 0.012), Vector2(0.0105, 0.0105), Vector2(0.009, 0.009), Vector2(0.004, 0.004)]), 7)
		var thumb := at + Vector3(-0.045 * side, 0.028, -0.04)
		f.loft(PackedVector3Array([thumb, thumb + Vector3(-0.016 * side, -0.005, -0.026), thumb + Vector3(-0.021 * side, -0.008, -0.036)]),
			PackedVector2Array([Vector2(0.014, 0.014), Vector2(0.011, 0.011), Vector2(0.005, 0.005)]), 7)


# —— 尾巴:绕椅腿的螺旋 + 上卷的尾尖 ——

static func _tail(f: MeshForge, look: Dictionary, pal: Dictionary) -> void:
	var root: Array = look["tail"]["path"]
	var path := PackedVector3Array([root[root.size() - 2], root[root.size() - 1]])
	var steps := 24
	var end_angle := WRAP_START + WRAP_TURNS * TAU
	for i in steps + 1:
		var t := float(i) / steps
		var a := lerpf(WRAP_START, end_angle, t)
		path.append(Vector3(WRAP_AXIS.x + cos(a) * WRAP_RADIUS, lerpf(WRAP_TOP, WRAP_BOTTOM, t), WRAP_AXIS.y + sin(a) * WRAP_RADIUS))
	# 尾尖:离开椅腿往外,再向上卷一个小圈
	var last := path[path.size() - 1]
	var out := Vector3(cos(end_angle), 0, sin(end_angle))
	var tangent := Vector3(-sin(end_angle), 0, cos(end_angle))
	var curl_center := last + out * 0.012 + Vector3(0, 0.024, 0)
	for i in 8:
		var a := lerpf(-PI / 3.0, PI * 1.15, i / 7.0)
		var r := lerpf(0.024, 0.013, i / 7.0)
		path.append(curl_center + tangent * cos(a) * r + Vector3(0, sin(a) * r, 0))
	var radii := PackedVector2Array()
	for i in path.size():
		var t := float(i) / (path.size() - 1)
		radii.append(Vector2.ONE * lerpf(0.017, 0.009, smoothstep(0.55, 1.0, t)))
	PatronBuilder.paint(f, pal, "fur", 0.75, PatronBuilder.FUR)
	f.loft(path, radii, 10, Vector2i(0, 1))
