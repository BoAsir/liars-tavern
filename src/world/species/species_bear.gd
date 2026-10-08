extends RefCounted
# 熊「酒馆老板」:宽扁头、短圆吻、圆三角鼻;圆杯耳在圆顶礼帽檐下;酒红丝绒背心、奶油衬衫卷袖加红袖箍、
# 深棕蝴蝶结、怀表链、大圆肚;格纹裤、光脚;左肩搭一条红条纹吧台毛巾。


const LOOK := {
	"id": "bear",
	"palette": {
		"fur": Color(0.36, 0.21, 0.11), "muzzle": Color(0.66, 0.50, 0.34), "dark": Color(0.12, 0.07, 0.04),
		"coat": Color(0.42, 0.11, 0.09), "accent": Color(0.30, 0.16, 0.08), "vest": Color(0.42, 0.11, 0.09),
		"shirt": Color(0.80, 0.74, 0.62), "hat": Color(0.1, 0.08, 0.07), "band": Color(0.42, 0.11, 0.09),
		"pants": Color(0.46, 0.36, 0.22), "armband": Color(0.62, 0.12, 0.1), "towel": Color(0.78, 0.74, 0.66),
		"stripe": Color(0.62, 0.12, 0.1), "pad": Color(0.2, 0.12, 0.08),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.18, 0.15, 0.165), "fur"],
			[Vector3(0.1, 0.06, -0.04), Vector3(0.075, 0.062, 0.075), "fur", "mirror"],    # 胖腮
			[Vector3(0, 0.065, -0.125), Vector3(0.085, 0.062, 0.072), "muzzle"],           # 短圆吻
		],
		"blend": 0.045,
		"nose": {"pos": Vector3(0, 0.092, -0.192), "radii": Vector3(0.03, 0.021, 0.02), "color": "nose"},
		"mouth": {"kind": "smile", "pos": Vector3(0, 0.04, -0.185), "width": 0.05},
	},
	"eyes": {"pos": Vector3(0.07, 0.162, -0.14), "size": Vector3(0.036, 0.04, 0.018), "iris": Color(0.32, 0.18, 0.08),
		"pupil": 0, "lid_rest": 0.15, "lashes": false},
	"brows": {"pos": Vector3(0.072, 0.214, -0.15), "color": "dark", "width": 0.06, "thickness": 0.013},
	"ears": {"kind": "round", "pivot": Vector3(0.14, 0.19, 0.01), "rot": Vector3(0, 0, -18),
		"size": Vector3(0.055, 0.052, 0.03), "inner": "muzzle"},
	"hat": {"kind": "bowler", "pivot": Vector3(0, 0.258, 0.01), "rot": Vector3(-6, 0, 4), "brim": 0.14, "crown_radius": 0.112, "band": "band"},
	"neck": {"base": Vector3(0, 0.55, -0.02), "radius": 0.08, "color": "fur"},
	"body": {"build": "big", "coat": "shirt", "belly": "vest", "pants": "pants", "vest": "vest", "shirt": "shirt",
		"buttons": 4, "neckwear": "bowtie", "neckwear_color": "accent", "chain": true, "collar": "shirt"},
	"arms": {"sleeve": "shirt", "cuff": "armband", "forearm": "fur"},
	"paws": {"color": "paw", "pads": "pad", "fingers": 4, "length": 0.026},
	"legs": {"pants": "pants", "foot": "bare", "foot_color": "paw", "material": 6.0},
	"tail": {"path": [Vector3(0, 0.5, 0.26), Vector3(0, 0.49, 0.3)], "radius": 0.045, "tip_radius": 0.035,
		"color": "fur", "sway_range": Vector2(0.0, 1.0)},
	"anim": {"look_pitch_min": -0.45, "blink_speed": 1.0},
}


static func extras(f: MeshForge, part: String, _look: Dictionary, pal: Dictionary) -> void:
	if part != "body":
		return
	# 左肩搭一条吧台毛巾:从后背翻过肩头垂到胸前,中间一道红条纹
	PatronBuilder.paint(f, pal, "towel", 0.9, PatronBuilder.CLOTH)
	var path := PackedVector3Array([Vector3(-0.15, 0.3, 0.14), Vector3(-0.16, 0.5, 0.06), Vector3(-0.15, 0.53, -0.04),
		Vector3(-0.14, 0.42, -0.15), Vector3(-0.13, 0.26, -0.17)])
	var radii := PackedVector2Array([Vector2(0.012, 0.05), Vector2(0.012, 0.052), Vector2(0.012, 0.052), Vector2(0.012, 0.05), Vector2(0.01, 0.048)])
	f.loft(path, radii, 8, Vector2i(1, 1), PatronBuilder.xf(), PackedColorArray(), Vector2(-1, -1), Vector3(1, 0, 0))
	PatronBuilder.paint(f, pal, "stripe", 0.9, PatronBuilder.CLOTH)
	f.loft(path.slice(2), PackedVector2Array([Vector2(0.0135, 0.014), Vector2(0.0135, 0.014), Vector2(0.0115, 0.013)]), 6,
		Vector2i(1, 1), PatronBuilder.xf(), PackedColorArray(), Vector2(-1, -1), Vector3(1, 0, 0))
