extends RefCounted
# 狐狸「老千绅士」:窄额长尖吻、白颊连成围嘴;礼帽夹在两耳之间、藏青燕尾服、金锦缎背心、奶油领巾、怀表链;
# 蓬松大尾巴从左侧翻过座面垂下,尾尖白;帽带上插一张 A 牌。


const LOOK := {
	"id": "fox",
	"palette": {
		"fur": Color(0.80, 0.40, 0.14), "muzzle": Color(0.80, 0.74, 0.62), "dark": Color(0.18, 0.08, 0.04),
		"coat": Color(0.13, 0.17, 0.30), "accent": Color(0.70, 0.52, 0.22), "vest": Color(0.66, 0.48, 0.18),
		"shirt": Color(0.78, 0.74, 0.64), "hat": Color(0.1, 0.08, 0.08), "band": Color(0.62, 0.16, 0.14),
		"pants": Color(0.12, 0.15, 0.26), "shoe": Color(0.07, 0.06, 0.06), "pad": Color(0.22, 0.1, 0.08),
		"card": Color(0.78, 0.76, 0.7),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.165, 0.15, 0.16), "fur"],                  # 主颅骨,中心就是头心
			[Vector3(0, 0.13, 0.05), Vector3(0.14, 0.13, 0.12), "fur_back"],            # 后脑压暗一点
			[Vector3(0.085, 0.06, -0.045), Vector3(0.082, 0.062, 0.078), "muzzle", "mirror"],   # 白颊
			[Vector3(0, 0.072, -0.12), Vector3(0.062, 0.05, 0.075), "muzzle"],          # 吻根
		],
		"blend": 0.04,
		"snout": {"path": [Vector3(0, 0.082, -0.13), Vector3(0, 0.084, -0.2), Vector3(0, 0.086, -0.26)],
			"radii": [Vector2(0.05, 0.046), Vector2(0.034, 0.03), Vector2(0.02, 0.019)], "color": "muzzle"},
		"nose": {"pos": Vector3(0, 0.094, -0.276), "radii": Vector3(0.021, 0.017, 0.016), "color": "nose"},
		"mouth": {"kind": "smirk", "pos": Vector3(0, 0.058, -0.2), "width": 0.062},
	},
	"eyes": {"pos": Vector3(0.064, 0.168, -0.128), "size": Vector3(0.04, 0.046, 0.02), "iris": Color(0.80, 0.52, 0.12),
		"pupil": 0, "lid_rest": 0.18, "lashes": false},
	"brows": {"pos": Vector3(0.064, 0.224, -0.142), "color": "dark"},
	"ears": {"kind": "pointy", "pivot": Vector3(0.135, 0.21, 0.0), "rot": Vector3(0, 0, -28),
		"size": Vector3(0.05, 0.15, 0.02), "inner": "muzzle", "tip": "dark"},
	"hat": {"kind": "top", "pivot": Vector3(0, 0.255, -0.01), "rot": Vector3(-6, 0, 3), "crown": [0.082, 0.21], "brim": 0.118,
		"curl": 0.022, "band": "band"},
	"neck": {"base": Vector3(0, 0.55, -0.02), "radius": 0.075, "color": "fur"},
	"body": {"build": "slim", "coat": "coat", "belly": "coat", "pants": "pants", "shirt": "shirt", "vest": "vest",
		"lapels": true, "buttons": 3, "neckwear": "cravat", "neckwear_color": "shirt", "chain": true, "collar": "muzzle"},
	"arms": {"sleeve": "coat", "cuff": "shirt"},
	"paws": {"color": "dark", "pads": "pad", "fingers": 4, "length": 0.03},
	"legs": {"pants": "pants", "foot": "spats", "shoe": "shoe", "spats": "shirt"},
	"tail": {"path": [Vector3(-0.04, 0.5, 0.24), Vector3(-0.17, 0.55, 0.26), Vector3(-0.29, 0.5, 0.24), Vector3(-0.34, 0.38, 0.22),
		Vector3(-0.35, 0.24, 0.24), Vector3(-0.32, 0.12, 0.3)], "radius": 0.04, "tip_radius": 0.03, "bulge": 0.045,
		"color": "fur", "tip": "muzzle", "tip_from": 0.8, "sway_range": Vector2(0.45, 1.0)},
	"anim": {"look_pitch_min": -0.45, "blink_speed": 1.0},
}


static func extras(f: MeshForge, part: String, _look: Dictionary, pal: Dictionary) -> void:
	match part:
		"hat":
			# 帽带上插一张 A 牌(斜插在右侧)
			PatronBuilder.paint(f, pal, "card", 0.6, PatronBuilder.CLOTH)
			f.box(Vector3(0.004, 0.07, 0.048), PatronBuilder.xf(Vector3(0.086, 0.06, 0.02), Vector3(0, -10, -12)))
			PatronBuilder.paint(f, pal, "band", 0.5, PatronBuilder.CLOTH)
			f.box(Vector3(0.005, 0.016, 0.012), PatronBuilder.xf(Vector3(0.087, 0.07, 0.02), Vector3(0, -10, -12)))
		"body":
			# 燕尾:从后腰垂到座面两侧的两片
			PatronBuilder.paint(f, pal, "coat", 0.85, PatronBuilder.CLOTH)
			for side: float in [-1.0, 1.0]:
				f.loft(PackedVector3Array([Vector3(0.1 * side, 0.08, 0.1), Vector3(0.15 * side, -0.04, 0.13), Vector3(0.17 * side, -0.16, 0.12)]),
					PackedVector2Array([Vector2(0.015, 0.06), Vector2(0.012, 0.05), Vector2(0.006, 0.03)]), 8, Vector2i(1, 1))
		"head":
			# 腮边三簇毛
			PatronBuilder.paint(f, pal, "muzzle", 0.8, PatronBuilder.FUR)
			for side: float in [-1.0, 1.0]:
				for k in 3:
					var base := Vector3(0.14 * side, 0.05 + k * 0.022, -0.02)
					f.cylinder(0.0, 0.014, 0.04, 6, MeshForge.CAPS_BOTH, PatronBuilder.xf(base + Vector3(0.012 * side, 0, 0), Vector3(0, 0, -78 * side + k * 8 * side)))
