extends RefCounted
# 鳄鱼「亡命徒」:长圆吻分上下两段、两排圆钝牙加一颗金牙、头顶两个眼包、鼻孔包、颈背一排圆疙瘩;
# 没有耳朵,黑色平檐低冠帽向后推露出眼包;炭灰衬衫敞胸露米黄腹鳞、红色强盗方巾、交叉两条子弹带;
# 破边深色裤、光脚三爪;粗鳞尾从左侧翻过座面落地。


const LOOK := {
	"id": "crocodile",
	"palette": {
		"fur": Color(0.24, 0.46, 0.22), "muzzle": Color(0.30, 0.50, 0.26), "dark": Color(0.1, 0.16, 0.08),
		"coat": Color(0.22, 0.22, 0.24), "accent": Color(0.72, 0.16, 0.12), "belly": Color(0.76, 0.70, 0.45),
		"hat": Color(0.07, 0.07, 0.08), "band": Color(0.2, 0.2, 0.22), "pants": Color(0.16, 0.15, 0.14),
		"tooth": Color(0.80, 0.78, 0.7), "gold": Color(0.85, 0.65, 0.2), "leather": Color(0.3, 0.2, 0.12),
		"nose": Color(0.12, 0.2, 0.1), "pad": Color(0.2, 0.32, 0.18),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.15, 0.13, 0.155), "fur"],
			[Vector3(0.06, 0.215, -0.08), Vector3(0.045, 0.04, 0.045), "fur", "mirror"],   # 头顶眼包
		],
		"blend": 0.04,
		"material": 4.0,
		"snout": {"path": [Vector3(0, 0.07, -0.08), Vector3(0, 0.07, -0.2), Vector3(0, 0.068, -0.3), Vector3(0, 0.066, -0.36)],
			"radii": [Vector2(0.06, 0.1), Vector2(0.05, 0.085), Vector2(0.045, 0.072), Vector2(0.038, 0.062)], "color": "muzzle"},
		"mouth": {"kind": "smirk", "pos": Vector3(0, 0.05, -0.3), "width": 0.12, "thickness": 0.0035},
	},
	"eyes": {"pos": Vector3(0.06, 0.225, -0.11), "size": Vector3(0.032, 0.03, 0.016), "iris": Color(0.72, 0.62, 0.12),
		"pupil": 1, "lid_rest": 0.28, "lashes": false, "yaw": 18.0},
	"brows": {"pos": Vector3(0.06, 0.26, -0.11), "color": "dark", "width": 0.045, "thickness": 0.012},
	"ears": {"kind": "none"},
	"hat": {"kind": "flat", "pivot": Vector3(0, 0.25, 0.04), "rot": Vector3(12, 0, 2), "brim": 0.19, "band": "band"},
	"neck": {"base": Vector3(0, 0.55, -0.02), "radius": 0.08, "color": "fur"},
	"body": {"build": "stocky", "coat": "coat", "belly": "coat", "pants": "pants", "shirt": "belly",
		"buttons": 0, "neckwear": "bandana", "neckwear_color": "accent", "collar": "coat"},
	"arms": {"sleeve": "coat", "cuff": "coat"},
	"paws": {"color": "fur", "pads": "pad", "fingers": 3, "length": 0.03, "claws": "nose"},
	"legs": {"pants": "pants", "foot": "claws", "foot_color": "fur"},
	"tail": {"path": [Vector3(-0.04, 0.5, 0.24), Vector3(-0.18, 0.55, 0.25), Vector3(-0.3, 0.46, 0.24), Vector3(-0.34, 0.25, 0.28),
		Vector3(-0.34, 0.08, 0.36), Vector3(-0.32, 0.04, 0.52), Vector3(-0.26, 0.03, 0.66)], "radius": 0.07, "tip_radius": 0.012,
		"color": "fur", "material": 4.0, "sway_range": Vector2(0.15, 0.4)},
	"anim": {"look_pitch_min": -0.3, "blink_speed": 1.0, "neck_reach": 0.75},
}


static func extras(f: MeshForge, part: String, _look: Dictionary, pal: Dictionary) -> void:
	match part:
		"head":
			# 两排圆钝牙(一颗金牙)、吻尖鼻孔包、颈背一排圆疙瘩
			for side: float in [-1.0, 1.0]:
				for k in 6:
					var z := -0.13 - k * 0.04
					var gold: bool = side > 0.0 and k == 2
					PatronBuilder.paint(f, pal, "gold" if gold else "tooth", 0.3 if gold else 0.5, PatronBuilder.METAL if gold else PatronBuilder.SMOOTH, 1.0 if gold else 0.0)
					f.cylinder(0.0, 0.007, 0.016, 6, MeshForge.CAPS_BOTH, PatronBuilder.xf(Vector3(0.043 * side * (1.0 - k * 0.04), 0.05, z), Vector3(180, 0, 0)))
			PatronBuilder.paint(f, pal, "fur", 0.7, PatronBuilder.SCALE)
			for side: float in [-1.0, 1.0]:
				f.sphere(0.016, 8, PatronBuilder.xf(Vector3(0.018 * side, 0.106, -0.345)))
			for k in 4:
				f.sphere(0.016, 8, PatronBuilder.xf(Vector3(0, 0.24 - k * 0.04, 0.08 + k * 0.035)))
		"body":
			# 交叉两条子弹带:皮带 + 一排铜弹头
			for side: float in [-1.0, 1.0]:
				var path := PackedVector3Array([Vector3(0.15 * side, 0.5, -0.06), Vector3(0.0, 0.3, -0.19), Vector3(-0.14 * side, 0.07, -0.16)])
				PatronBuilder.paint(f, pal, "leather", 0.6, PatronBuilder.LEATHER)
				f.loft(path, PackedVector2Array([Vector2(0.01, 0.026), Vector2(0.01, 0.026), Vector2(0.01, 0.026)]), 6, Vector2i(1, 1),
					PatronBuilder.xf(), PackedColorArray(), Vector2(-1, -1), Vector3(0, 0, -1))
				PatronBuilder.paint(f, pal, "brass", 0.3, PatronBuilder.METAL, 1.0)
				for k in 7:
					var t := (k + 0.5) / 7.0
					var p := path[0].lerp(path[1], t * 2.0) if t < 0.5 else path[1].lerp(path[2], t * 2.0 - 1.0)
					f.cylinder(0.006, 0.006, 0.026, 6, MeshForge.CAPS_BOTH, PatronBuilder.xf(p + Vector3(0, 0, -0.012), Vector3(90, 0, 0)))
