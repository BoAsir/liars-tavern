extends RefCounted
# 猫「独行枪手」:灰虎斑,额头 M 纹、白吻白胸、w 形嘴、胡须、粉三角鼻、竖瞳;三角耳从牛仔帽的耳洞穿出;
# 皮背心、浅蓝衬衫、青色方巾、枪带和右胯枪套;牛仔裤、尖头靴配马刺;细长虎斑尾从缝里穿出垂在椅后。


const LOOK := {
	"id": "cat",
	"palette": {
		"fur": Color(0.46, 0.47, 0.52), "muzzle": Color(0.80, 0.79, 0.77), "dark": Color(0.1, 0.1, 0.12),
		"coat": Color(0.48, 0.62, 0.72), "accent": Color(0.20, 0.52, 0.58), "stripe": Color(0.24, 0.24, 0.28),
		"vest": Color(0.36, 0.22, 0.12), "shirt": Color(0.48, 0.62, 0.72), "hat": Color(0.3, 0.2, 0.12),
		"band": Color(0.2, 0.52, 0.58), "pants": Color(0.18, 0.26, 0.4), "shoe": Color(0.3, 0.17, 0.09),
		"nose": Color(0.72, 0.42, 0.46), "pad": Color(0.6, 0.38, 0.42), "leather": Color(0.36, 0.22, 0.12),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.16, 0.145, 0.155), "fur"],
			[Vector3(0.04, 0.065, -0.12), Vector3(0.05, 0.04, 0.05), "muzzle", "mirror"],   # 白吻两瓣
			[Vector3(0, 0.035, -0.1), Vector3(0.05, 0.035, 0.05), "muzzle"],                # 下巴
			[Vector3(0, 0.235, -0.1), Vector3(0.012, 0.035, 0.02), "stripe"],               # 额头 M 纹中线
			[Vector3(0.035, 0.235, -0.1), Vector3(0.01, 0.03, 0.02), "stripe", "mirror"],
			[Vector3(0.13, 0.12, -0.05), Vector3(0.02, 0.012, 0.03), "stripe", "mirror"],   # 颊纹
		],
		"blend": 0.035,
		"nose": {"pos": Vector3(0, 0.092, -0.168), "radii": Vector3(0.016, 0.011, 0.01), "color": "nose"},
		"mouth": {"kind": "w", "pos": Vector3(0, 0.06, -0.165), "width": 0.05, "thickness": 0.0026},
		"whiskers": true, "whisker_color": "muzzle", "whisker_root": Vector3(0.05, 0.075, -0.155),
	},
	"eyes": {"pos": Vector3(0.062, 0.162, -0.13), "size": Vector3(0.042, 0.046, 0.02), "iris": Color(0.62, 0.68, 0.22),
		"pupil": 1, "lid_rest": 0.2, "lashes": false},
	"brows": {"pos": Vector3(0.064, 0.215, -0.14), "color": "stripe", "width": 0.05, "thickness": 0.009},
	"ears": {"kind": "cat", "pivot": Vector3(0.1, 0.25, 0.0), "rot": Vector3(0, 0, -14),
		"size": Vector3(0.058, 0.1, 0.02), "inner": "nose"},
	"hat": {"kind": "cowboy", "pivot": Vector3(0, 0.255, 0.01), "rot": Vector3(-6, 0, 6), "brim": 0.24, "band": "band"},
	"neck": {"base": Vector3(0, 0.55, -0.02), "radius": 0.072, "color": "fur"},
	"body": {"build": "slim", "coat": "shirt", "belly": "vest", "pants": "pants", "vest": "vest", "shirt": "muzzle",
		"buttons": 0, "neckwear": "bandana", "neckwear_color": "accent", "collar": "shirt"},
	"arms": {"sleeve": "shirt", "cuff": "shirt"},
	"paws": {"color": "fur", "pads": "pad", "fingers": 4, "length": 0.03},
	"legs": {"pants": "pants", "foot": "cowboy", "shoe": "shoe"},
	"tail": {"path": [Vector3(0, 0.5, 0.25), Vector3(0, 0.5, 0.34), Vector3(0, 0.48, 0.42), Vector3(0.01, 0.34, 0.46),
		Vector3(0.0, 0.2, 0.45), Vector3(-0.02, 0.12, 0.42), Vector3(-0.04, 0.14, 0.38)], "radius": 0.022, "tip_radius": 0.015,
		"color": "fur", "tip": "stripe", "tip_from": 0.85, "sway_range": Vector2(0.4, 1.0)},
	"anim": {"look_pitch_min": -0.45, "blink_speed": 1.0},
}


static func extras(f: MeshForge, part: String, _look: Dictionary, pal: Dictionary) -> void:
	match part:
		"hat":
			# 耳洞:耳朵穿过帽檐的地方缝一圈皮环(卡通惯例,看起来是故意开的洞)
			PatronBuilder.paint(f, pal, "leather", 0.6, PatronBuilder.LEATHER)
			for side: float in [-1.0, 1.0]:
				f.torus(0.028, 0.038, 14, PatronBuilder.xf(Vector3(0.1 * side, 0.004, -0.01), Vector3.ZERO, Vector3(1.0, 0.6, 1.4)))
		"legs":
			# 枪带与右胯枪套
			PatronBuilder.paint(f, pal, "leather", 0.6, PatronBuilder.LEATHER)
			f.torus(0.17, 0.2, 24, PatronBuilder.xf(Vector3(0, 0.52, 0.1), Vector3(14, 0, 0), Vector3(1.0, 0.6, 0.95)))
			f.box(Vector3(0.04, 0.12, 0.07), PatronBuilder.xf(Vector3(0.2, 0.44, 0.04), Vector3(0, 0, 8)))
			PatronBuilder.paint(f, pal, "brass", 0.3, PatronBuilder.METAL, 1.0)
			for k in 5:
				f.cylinder(0.006, 0.006, 0.02, 6, MeshForge.CAPS_BOTH, PatronBuilder.xf(Vector3(-0.16 + k * 0.03, 0.53, -0.05), Vector3(90, 0, 0)))
