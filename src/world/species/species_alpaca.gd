extends RefCounted
# 羊驼「披毯客」:小颅骨、长脸、前伸的吻和分开的上唇、头顶一大团卷毛、大眼长睫毛;香蕉耳从卷毛里竖起;
# 卷毛顶上一顶用颏绳戴着的迷你草帽;卷绒躯干、左肩斜披条纹毯、绿松石波洛领绳;绒腿、两趾软蹄;长脖子。


const LOOK := {
	"id": "alpaca",
	"palette": {
		"fur": Color(0.78, 0.66, 0.5), "muzzle": Color(0.80, 0.74, 0.62), "dark": Color(0.35, 0.26, 0.18),
		"coat": Color(0.76, 0.64, 0.48), "accent": Color(0.25, 0.6, 0.58), "blanket": Color(0.70, 0.16, 0.14),
		"mustard": Color(0.76, 0.58, 0.18), "teal": Color(0.2, 0.5, 0.52), "straw": Color(0.78, 0.66, 0.38),
		"band": Color(0.70, 0.16, 0.14), "pants": Color(0.74, 0.62, 0.46), "nose": Color(0.3, 0.2, 0.16),
		"hoof": Color(0.22, 0.16, 0.12), "pad": Color(0.4, 0.3, 0.22),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.13, 0.14, 0.135), "fur"],
			[Vector3(0, 0.25, 0.0), Vector3(0.12, 0.08, 0.12), "fur"],          # 头顶卷毛团
			[Vector3(0, 0.08, -0.1), Vector3(0.075, 0.08, 0.09), "muzzle"],     # 长脸
		],
		"blend": 0.045,
		"snout": {"path": [Vector3(0, 0.07, -0.12), Vector3(0, 0.06, -0.2), Vector3(0, 0.058, -0.255)],
			"radii": [Vector2(0.06, 0.06), Vector2(0.05, 0.052), Vector2(0.04, 0.044)], "color": "muzzle"},
		"nose": {"pos": Vector3(0, 0.085, -0.285), "radii": Vector3(0.022, 0.012, 0.01), "color": "nose"},
		"mouth": {"kind": "smile", "pos": Vector3(0, 0.04, -0.285), "width": 0.04},
	},
	"eyes": {"pos": Vector3(0.068, 0.15, -0.105), "size": Vector3(0.042, 0.046, 0.02), "iris": Color(0.24, 0.16, 0.1),
		"pupil": 2, "lid_rest": 0.15, "lashes": true, "yaw": 22.0},
	"brows": {"pos": Vector3(0.07, 0.2, -0.11), "color": "dark", "width": 0.045, "thickness": 0.008},
	"ears": {"kind": "banana", "pivot": Vector3(0.1, 0.27, 0.0), "rot": Vector3(0, 0, -12),
		"size": Vector3(0.028, 0.15, 0.016), "inner": "dark"},
	"hat": {"kind": "straw", "pivot": Vector3(0, 0.32, 0.0), "rot": Vector3(-6, 0, 0), "crown_radius": 0.05, "brim": 0.072,
		"band": "band", "strap": [Vector3(0.06, 0.0, 0.0), Vector3(0.11, -0.12, -0.04), Vector3(0.08, -0.27, -0.12), Vector3(0.0, -0.3, -0.15)]},
	"neck": {"base": Vector3(0, 0.44, -0.04), "radius": 0.07, "color": "fur"},
	"body": {"build": "round", "coat": "coat", "belly": "coat", "pants": "pants", "material": 8.0,
		"buttons": 0, "neckwear": "bolo", "neckwear_color": "accent", "collar": "fur"},
	"arms": {"sleeve": "coat", "cuff": "fur", "material": 8.0},
	"paws": {"color": "fur", "pads": "pad", "fingers": 2, "length": 0.03},
	"legs": {"pants": "pants", "foot": "hoof", "foot_color": "hoof", "material": 8.0},
	"tail": {"path": [Vector3(0, 0.5, 0.25), Vector3(0, 0.52, 0.31)], "radius": 0.04, "tip_radius": 0.03,
		"color": "fur", "sway_range": Vector2(0.0, 1.0)},
	"anim": {"look_pitch_min": -0.45, "blink_speed": 1.0},
}


static func extras(f: MeshForge, part: String, _look: Dictionary, pal: Dictionary) -> void:
	match part:
		"head":
			# 卷毛团上的一圈小卷;分开的上唇与两颗下门牙
			PatronBuilder.paint(f, pal, "fur", 0.9, PatronBuilder.KNIT)
			for k in 8:
				var a := TAU * k / 8.0
				f.sphere(0.035, 10, PatronBuilder.xf(Vector3(cos(a) * 0.085, 0.27 + sin(a * 2.0) * 0.01, sin(a) * 0.085)))
			PatronBuilder.paint(f, pal, "muzzle", 0.6, PatronBuilder.SMOOTH)
			f.box(Vector3(0.012, 0.014, 0.006), PatronBuilder.xf(Vector3(-0.007, 0.03, -0.28)))
			f.box(Vector3(0.012, 0.014, 0.006), PatronBuilder.xf(Vector3(0.007, 0.03, -0.28)))
		"body":
			# 左肩斜披的条纹毯:四色色带,下摆在右腰
			var colors := PackedColorArray()
			var path := PackedVector3Array()
			var radii := PackedVector2Array()
			var keys := ["blanket", "mustard", "teal", "muzzle", "blanket", "mustard", "teal", "blanket"]
			for i in 8:
				var t := i / 7.0
				path.append(Vector3(lerpf(-0.17, 0.12, t), lerpf(0.5, 0.05, t), -0.16 - sin(t * PI) * 0.035))
				radii.append(Vector2(0.018, 0.06))
				var c: Color = pal[keys[i]]
				colors.append(Color(c.r, c.g, c.b, 1.0))
			PatronBuilder.paint(f, pal, "blanket", 0.95, PatronBuilder.KNIT)
			f.loft(path, radii, 8, Vector2i(1, 1), PatronBuilder.xf(), colors, Vector2(-1, -1), Vector3(0, 0, -1))
