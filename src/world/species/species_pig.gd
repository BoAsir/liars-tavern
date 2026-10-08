extends RefCounted
# 猪「铁路司炉」:圆脸带腮肉、上翘圆角鼻盘、凹陷椭圆鼻孔、腮红;软三角耳往前下折;蓝白条纹司机帽;
# 牛仔背带工装裤(胸兜、铜扣)、红格衬衫卷袖、红领巾;厚底工靴;小螺旋尾;脸颊一抹煤灰。


const LOOK := {
	"id": "pig",
	"palette": {
		"fur": Color(0.76, 0.47, 0.45), "muzzle": Color(0.80, 0.55, 0.52), "dark": Color(0.45, 0.2, 0.2),
		"coat": Color(0.20, 0.30, 0.48), "accent": Color(0.70, 0.16, 0.14), "shirt": Color(0.62, 0.14, 0.12),
		"hat": Color(0.18, 0.26, 0.44), "cream": Color(0.78, 0.76, 0.7), "pants": Color(0.20, 0.30, 0.48),
		"snout": Color(0.80, 0.55, 0.52), "blush": Color(0.80, 0.42, 0.42), "soot": Color(0.22, 0.17, 0.16),
		"shoe": Color(0.22, 0.13, 0.08), "pad": Color(0.55, 0.3, 0.3), "nose": Color(0.42, 0.18, 0.2),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.17, 0.155, 0.165), "fur"],
			[Vector3(0.09, 0.05, -0.06), Vector3(0.08, 0.066, 0.07), "fur", "mirror"],      # 腮肉
			[Vector3(0.1, 0.08, -0.1), Vector3(0.035, 0.025, 0.02), "blush", "mirror"],     # 腮红
			[Vector3(-0.12, 0.06, -0.08), Vector3(0.03, 0.02, 0.02), "soot"],               # 左颊一抹煤灰
		],
		"blend": 0.04,
		"nose": {"pos": Vector3(0, 0.082, -0.178), "radii": Vector3(0.058, 0.046, 0.034), "color": "snout"},
		"mouth": {"kind": "smile", "pos": Vector3(0, 0.03, -0.165), "width": 0.06},
	},
	"eyes": {"pos": Vector3(0.068, 0.17, -0.135), "size": Vector3(0.034, 0.038, 0.017), "iris": Color(0.32, 0.22, 0.14),
		"pupil": 0, "lid_rest": 0.12, "lashes": true},
	"brows": {"pos": Vector3(0.068, 0.222, -0.145), "color": "dark"},
	"ears": {"kind": "floppy", "pivot": Vector3(0.12, 0.215, -0.02), "rot": Vector3(-35, 0, -42),
		"size": Vector3(0.05, 0.11, 0.012), "inner": "blush"},
	"hat": {"kind": "conductor", "pivot": Vector3(0, 0.25, 0.0), "rot": Vector3(-10, 0, -6), "radius": 0.13,
		"stripe_a": "hat", "stripe_b": "cream", "visor": "dark"},
	"neck": {"base": Vector3(0, 0.55, -0.02), "radius": 0.08, "color": "fur"},
	"body": {"build": "round", "coat": "shirt", "belly": "pants", "pants": "pants", "material": 1.0,
		"buttons": 0, "neckwear": "neckerchief", "neckwear_color": "accent", "collar": "shirt"},
	"arms": {"sleeve": "shirt", "cuff": "shirt", "forearm": "fur", "material": 6.0},
	"paws": {"color": "paw", "pads": "pad", "fingers": 3, "length": 0.026},
	"legs": {"pants": "pants", "foot": "boot", "shoe": "shoe"},
	"tail": {"path": [Vector3(0, 0.5, 0.25), Vector3(0.02, 0.53, 0.29), Vector3(-0.01, 0.56, 0.31), Vector3(-0.02, 0.53, 0.33),
		Vector3(0.01, 0.52, 0.34)], "radius": 0.014, "tip_radius": 0.008, "color": "fur", "sway_range": Vector2(0.2, 1.0)},
	"anim": {"look_pitch_min": -0.45, "blink_speed": 1.0},
}


static func extras(f: MeshForge, part: String, _look: Dictionary, pal: Dictionary) -> void:
	match part:
		"head":
			# 鼻孔:鼻盘正面两个深色椭圆凹坑
			PatronBuilder.paint(f, pal, "nose", 0.4, PatronBuilder.LEATHER)
			for side: float in [-1.0, 1.0]:
				f.sphere(1.0, 10, PatronBuilder.xf(Vector3(0.021 * side, 0.082, -0.211), Vector3.ZERO, Vector3(0.011, 0.016, 0.005)))
		"body":
			# 工装裤:胸兜 + 两条背带 + 铜扣
			PatronBuilder.paint(f, pal, "pants", 0.85, PatronBuilder.CLOTH)
			f.box(Vector3(0.16, 0.12, 0.02), PatronBuilder.xf(Vector3(0, 0.3, -0.17), Vector3(-8, 0, 0)))
			for side: float in [-1.0, 1.0]:
				f.loft(PackedVector3Array([Vector3(0.06 * side, 0.34, -0.165), Vector3(0.1 * side, 0.48, -0.1), Vector3(0.11 * side, 0.52, 0.02),
					Vector3(0.09 * side, 0.4, 0.15)]), PackedVector2Array([Vector2(0.006, 0.022), Vector2(0.006, 0.022), Vector2(0.006, 0.022),
					Vector2(0.006, 0.022)]), 6, Vector2i(1, 1), PatronBuilder.xf(), PackedColorArray(), Vector2(-1, -1), Vector3(0, 0, -1))
			PatronBuilder.paint(f, pal, "brass", 0.3, PatronBuilder.METAL, 1.0)
			for side: float in [-1.0, 1.0]:
				f.sphere(0.012, 8, PatronBuilder.xf(Vector3(0.065 * side, 0.345, -0.185)))
