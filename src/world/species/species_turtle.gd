extends RefCounted
# 乌龟「老淘金客」:光秃圆头、短钝喙、厚眼睑、白色海象胡、黄铜圆眼镜;没有耳朵,软毡宽松帽;
# 橄榄棕背甲(盾片格纹)、米黄腹甲代替衬衫前襟、红黑格法兰绒袖、棕背带;卡其裤、补丁旧靴;小尖尾藏在甲缘下。


const LOOK := {
	"id": "turtle",
	"palette": {
		"fur": Color(0.42, 0.55, 0.28), "muzzle": Color(0.62, 0.66, 0.4), "dark": Color(0.2, 0.24, 0.12),
		"coat": Color(0.55, 0.16, 0.12), "accent": Color(0.4, 0.26, 0.14), "shell": Color(0.40, 0.33, 0.18),
		"plastron": Color(0.76, 0.68, 0.42), "hat": Color(0.36, 0.3, 0.22), "band": Color(0.24, 0.18, 0.12),
		"pants": Color(0.62, 0.55, 0.38), "shoe": Color(0.3, 0.2, 0.12), "mustache": Color(0.8, 0.79, 0.76),
		"nose": Color(0.22, 0.26, 0.14), "pad": Color(0.3, 0.38, 0.2),
	},
	"head": {
		"skull": [
			[Vector3(0, 0.12, 0), Vector3(0.155, 0.15, 0.16), "fur"],
			[Vector3(0, 0.07, -0.11), Vector3(0.09, 0.065, 0.075), "muzzle"],   # 短钝喙
		],
		"blend": 0.045,
		"mouth": {"kind": "line", "pos": Vector3(0, 0.035, -0.17), "width": 0.07},
	},
	"eyes": {"pos": Vector3(0.062, 0.165, -0.13), "size": Vector3(0.036, 0.04, 0.018), "iris": Color(0.42, 0.32, 0.12),
		"pupil": 0, "lid_rest": 0.38, "lashes": false},
	"brows": {"pos": Vector3(0.064, 0.215, -0.14), "color": "mustache", "width": 0.05, "thickness": 0.012},
	"ears": {"kind": "none"},
	"hat": {"kind": "slouch", "pivot": Vector3(0, 0.25, 0.01), "rot": Vector3(-4, 0, 3), "brim": 0.19, "band": "band"},
	"neck": {"base": Vector3(0, 0.55, -0.02), "radius": 0.07, "color": "fur"},
	"body": {"build": "stocky", "coat": "coat", "belly": "plastron", "pants": "pants", "shirt": "plastron",
		"buttons": 0, "neckwear": "none", "collar": "fur", "material": 6.0,
		"shapes": [[Vector3(0, 0.25, 0.08), Vector3(0.2, 0.25, 0.12), "shell"]]},
	"arms": {"sleeve": "coat", "cuff": "coat", "material": 6.0},
	"paws": {"color": "fur", "pads": "pad", "fingers": 3, "length": 0.026},
	"legs": {"pants": "pants", "foot": "boot", "shoe": "shoe"},
	"tail": {"path": [Vector3(0, 0.47, 0.25), Vector3(0, 0.45, 0.3)], "radius": 0.02, "tip_radius": 0.004,
		"color": "fur", "sway_range": Vector2(0.0, 1.0)},
	"anim": {"look_pitch_min": -0.45, "blink_speed": 0.62, "die_body_rot": Vector3(-0.05, 0.25, -0.85)},
}


static func extras(f: MeshForge, part: String, _look: Dictionary, pal: Dictionary) -> void:
	match part:
		"head":
			# 海象胡 + 黄铜圆眼镜
			PatronBuilder.paint(f, pal, "mustache", 0.9, PatronBuilder.FUR)
			f.blob(Vector3(0, 0.055, -0.17), [[Vector3(0.035, 0.05, -0.17), Vector3(0.04, 0.02, 0.025), pal["mustache"], "mirror"],
				[Vector3(0.06, 0.035, -0.16), Vector3(0.02, 0.025, 0.02), pal["mustache"], "mirror"]], 16, 8, 0.012)
			PatronBuilder.paint(f, pal, "brass", 0.3, PatronBuilder.METAL, 1.0)
			for side: float in [-1.0, 1.0]:
				f.torus(0.034, 0.039, 18, PatronBuilder.xf(Vector3(0.062 * side, 0.165, -0.152), Vector3(90, 0, 0)))
			f.tube(PackedVector3Array([Vector3(-0.026, 0.168, -0.155), Vector3(0, 0.174, -0.162), Vector3(0.026, 0.168, -0.155)]), 0.003, 5)
		"body":
			# 背甲上的盾片中心提亮一点、甲缘一圈;两条棕背带
			PatronBuilder.paint(f, pal, "shell", 0.6, PatronBuilder.SHELL)
			f.torus(0.17, 0.2, 28, PatronBuilder.xf(Vector3(0, 0.0, 0.06), Vector3(14, 0, 0), Vector3(1.05, 0.7, 0.95)))
			PatronBuilder.paint(f, pal, "accent", 0.7, PatronBuilder.LEATHER)
			for side: float in [-1.0, 1.0]:
				f.loft(PackedVector3Array([Vector3(0.07 * side, 0.08, -0.19), Vector3(0.09 * side, 0.32, -0.17), Vector3(0.1 * side, 0.5, -0.1)]),
					PackedVector2Array([Vector2(0.006, 0.02), Vector2(0.006, 0.02), Vector2(0.006, 0.02)]), 6, Vector2i(1, 1), PatronBuilder.xf(),
					PackedColorArray(), Vector2(-1, -1), Vector3(0, 0, -1))
