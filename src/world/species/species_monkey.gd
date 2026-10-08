extends RefCounted
# 猴子「酒馆跑堂」:圆头、桃色心形脸罩、宽嘴笑;大圆侧耳;红色药盒帽带金箍和颏带、斜戴;
# 红色短门童夹克(金穗边、双排 8 颗铜扣)、黑裤金侧条;光脚长趾;长卷尾从缝里穿出、绕左后椅腿 1.5 圈。


const LOOK := {
	"id": "monkey",
	"palette": {
		"fur": Color(0.42, 0.26, 0.14), "muzzle": Color(0.80, 0.62, 0.48), "dark": Color(0.16, 0.09, 0.05),
		"coat": Color(0.70, 0.12, 0.10), "accent": Color(0.82, 0.62, 0.25), "pants": Color(0.1, 0.09, 0.09),
		"face": Color(0.80, 0.62, 0.48), "nose": Color(0.35, 0.2, 0.15), "pad": Color(0.62, 0.45, 0.35),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.16, 0.15, 0.155), "fur"],
			[Vector3(0.042, 0.15, -0.105), Vector3(0.062, 0.07, 0.06), "face", "mirror"],   # 心形脸罩两瓣
			[Vector3(0, 0.07, -0.12), Vector3(0.08, 0.06, 0.07), "face"],                    # 下半脸
		],
		"blend": 0.035,
		"nose": {"pos": Vector3(0, 0.1, -0.175), "radii": Vector3(0.016, 0.01, 0.01), "color": "nose"},
		"mouth": {"kind": "wide", "pos": Vector3(0, 0.055, -0.185), "width": 0.085, "thickness": 0.0036},
	},
	"eyes": {"pos": Vector3(0.055, 0.16, -0.14), "size": Vector3(0.036, 0.042, 0.018), "iris": Color(0.36, 0.22, 0.1),
		"pupil": 0, "lid_rest": 0.1, "lashes": false},
	"brows": {"pos": Vector3(0.058, 0.215, -0.145), "color": "dark", "width": 0.05},
	"ears": {"kind": "side_round", "pivot": Vector3(0.165, 0.13, 0.0), "rot": Vector3(0, -70, 0),
		"size": Vector3(0.05, 0.055, 0.02), "inner": "face"},
	"hat": {"kind": "pillbox", "pivot": Vector3(0.02, 0.255, 0.0), "rot": Vector3(-6, 0, -12), "radius": 0.07, "color": "coat",
		"strap": [Vector3(0.065, 0.0, 0.0), Vector3(0.1, -0.1, -0.03), Vector3(0.05, -0.2, -0.12), Vector3(0.0, -0.21, -0.13)]},
	"neck": {"base": Vector3(0, 0.55, -0.02), "radius": 0.068, "color": "fur"},
	"body": {"build": "slim", "coat": "coat", "belly": "coat", "pants": "pants", "buttons": 0, "neckwear": "none", "collar": "accent"},
	"arms": {"sleeve": "coat", "cuff": "accent"},
	"paws": {"color": "face", "pads": "pad", "fingers": 4, "length": 0.042},
	"legs": {"pants": "pants", "foot": "bare", "foot_color": "face"},
	"tail": {"path": [Vector3(0, 0.5, 0.25), Vector3(-0.04, 0.5, 0.36), Vector3(-0.12, 0.42, 0.42), Vector3(-0.2, 0.36, 0.38),
		Vector3(-0.255, 0.32, 0.32), Vector3(-0.2, 0.28, 0.265), Vector3(-0.145, 0.24, 0.32), Vector3(-0.2, 0.2, 0.375),
		Vector3(-0.255, 0.16, 0.32), Vector3(-0.2, 0.12, 0.265), Vector3(-0.15, 0.14, 0.28)],
		"radius": 0.018, "tip_radius": 0.012, "color": "fur", "sway_range": Vector2(0.1, 0.3)},
	"anim": {"look_pitch_min": -0.45, "blink_speed": 1.0},
}


static func extras(f: MeshForge, part: String, _look: Dictionary, pal: Dictionary) -> void:
	if part != "body":
		return
	# 门童夹克:双排 8 颗铜扣 + 金穗边下摆
	PatronBuilder.paint(f, pal, "brass", 0.3, PatronBuilder.METAL, 1.0)
	for k in 4:
		for side: float in [-1.0, 1.0]:
			f.sphere(0.011, 8, PatronBuilder.xf(Vector3(0.045 * side, 0.36 - k * 0.075, -0.168 + k * 0.004)))
	PatronBuilder.paint(f, pal, "accent", 0.5, PatronBuilder.CLOTH)
	f.torus(0.17, 0.19, 28, PatronBuilder.xf(Vector3(0, 0.05, -0.02), Vector3.ZERO, Vector3(1.0, 0.5, 0.95)))
