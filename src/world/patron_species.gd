class_name PatronSpecies
# 酒客物种外观表(纯数据):加一个物种 = 加一条记录,建模代码按参数捏头型、选耳朵/口鼻/尾巴/帽子/服装。
# 必备键:id、label(中文名,等待厅名单按 fur 着色显示)、fur、muzzle、dark、coat、accent。
# 其余键(缺省时各建模器有默认值):
#   palette   额外颜色(PatronSkin.SLOT_NAMES 的槽位名 → Color),未给的按 fur/coat/accent 推导
#   patterns  布料图案:槽位名 → [图案名, 每米几条](PatronSkin.PATTERNS)
#   head      头型:radius 半径、scale 三轴比例、cheek 腮毛外扩、jowl 下颌赘肉、brow 眉骨、chin 下巴前突
#   snout     口鼻:length 前伸、spread 覆盖角(度)、taper 收细、pitch 下倾(度)、flat 端面压平(猪)
#   nose      鼻子:shape(oval/disc)、size、heart 上宽下窄、raise、sink
#   markings  毛色斑块(PatronHead.markings);stripes 虎斑
#   eyes      眼睛:yaw/pitch 位置(弧度,头心方向)、radius、iris 虹膜色、pupil(round/slit)、
#             open 平时上眼睑的开度(0 闭 ~ 1 全开)、lashes 外眼角睫毛根数
#   brows     眉毛:yaw/pitch 中心、span 长度(弧度)、width、height
#   mouth     嘴:kind(cat/bear/pig)、width、drop(嘴线在鼻下多远,口鼻局部角度,弧度)
#   ears      耳朵:kind(pointy/round/floppy/cat)、yaw/pitch 位置、height、width、tilt、lean、bend 耳尖往前折(弧度)、
#             tip 深色耳尖比例、inner(skin/muzzle)、tuft 耳内绒毛
#   whiskers  胡须;tufts 腮毛簇
#   body      身材:belly 肚子前凸、chest 胸肩宽、hips 臀宽
#   outfit    服装:lapel(shawl/notch)、vest、neckwear(bow/tie/bolo/cravat)、pocket_square、
#             watch_chain、flower、shoes(oxford/boot)
#   paws      爪子:kind(paw/hoof)、claws、dark 深色"袜子"
#   tail      尾巴:kind(bushy/slender/curl,空字典 = 没有/看不见)、side 垂在椅子哪一侧、length、radius、tip
#   hat       帽子:kind(top/bowler/cap/cowboy)、size、pos(头部坐标)、rot(度)


const ALL := [
	{
		"id": "fox", "label": "狐狸",
		"fur": Color(0.86, 0.4, 0.13), "muzzle": Color(0.96, 0.9, 0.8), "dark": Color(0.16, 0.07, 0.04),
		"coat": Color(0.13, 0.17, 0.3), "accent": Color(0.82, 0.62, 0.25),
		"palette": {
			"nose": Color(0.06, 0.04, 0.04), "iris": Color(0.98, 0.7, 0.18), "vest": Color(0.42, 0.09, 0.11),
			"trim": Color(0.1, 0.12, 0.22), "pad": Color(0.12, 0.08, 0.07), "hat": Color(0.07, 0.065, 0.075),
			"trousers": Color(0.1, 0.12, 0.21), "inner": Color(0.96, 0.9, 0.8),
		},
		"patterns": {"coat": ["pinstripe", 26.0], "trousers": ["pinstripe", 26.0], "vest": ["velvet", 0.0]},
		"head": {"radius": 0.158, "scale": Vector3(1.0, 0.93, 0.98), "cheek": 0.24, "brow": 0.05},
		"snout": {"length": 0.13, "spread": 44.0, "taper": 0.66, "pitch": 5.0},
		"nose": {"shape": "oval", "size": Vector3(0.0165, 0.0125, 0.013), "heart": 0.25, "raise": 0.002},
		"markings": [
			{"dir": Vector3(0, -0.45, -1), "size": 0.72, "soft": 0.12, "light": 1.0, "below": 0.02},
			{"dir": Vector3(0.85, -0.5, -0.45), "size": 0.42, "soft": 0.14, "light": 1.0, "mirror": true},
		],
		"eyes": {"yaw": 0.4, "pitch": 0.2, "radius": 0.031, "open": 0.84, "lashes": 0},
		"brows": {"yaw": 0.42, "pitch": 0.47, "span": 0.42, "width": 0.011, "height": 0.004},
		"mouth": {"kind": "cat", "width": 0.3, "drop": 0.3},
		"ears": {"kind": "pointy", "yaw": 0.62, "pitch": 1.0, "height": 0.13, "width": 0.07, "tilt": 18.0,
			"lean": -8.0, "tip": 0.4, "inner": "inner", "tuft": true},
		"tufts": {"count": 3, "yaw": 1.0, "pitch": -0.25, "step": 0.16, "length": 0.062, "width": 0.022},
		"body": {"belly": 0.0, "chest": 1.0},
		"outfit": {"lapel": "shawl", "vest": true, "neckwear": "bow", "pocket_square": true, "watch_chain": true,
			"shoes": "oxford"},
		"paws": {"kind": "paw", "dark": true},
		"tail": {"kind": "bushy", "side": 1.0, "length": 0.62, "radius": 0.084, "tip": 0.34},
		"hat": {"kind": "top", "size": 0.9, "pos": Vector3(0.012, 0.242, 0.012), "rot": Vector3(-8, 0, -11)},
	},
	{
		"id": "bear", "label": "熊",
		"fur": Color(0.36, 0.21, 0.11), "muzzle": Color(0.68, 0.52, 0.36), "dark": Color(0.12, 0.07, 0.04),
		"coat": Color(0.42, 0.11, 0.09), "accent": Color(0.86, 0.76, 0.52),
		"palette": {
			"nose": Color(0.07, 0.05, 0.05), "iris": Color(0.42, 0.24, 0.1), "vest": Color(0.62, 0.52, 0.36),
			"tie": Color(0.18, 0.24, 0.16), "pad": Color(0.16, 0.1, 0.08), "hat": Color(0.1, 0.075, 0.06),
			"trousers": Color(0.2, 0.15, 0.12), "claw": Color(0.86, 0.8, 0.68), "inner": Color(0.68, 0.52, 0.36),
		},
		"patterns": {"coat": ["tweed", 16.0], "vest": ["check", 18.0], "trousers": ["tweed", 16.0],
			"tie": ["stripes", 40.0]},
		"head": {"radius": 0.168, "scale": Vector3(1.04, 0.96, 1.0), "cheek": 0.05, "jowl": 0.02, "brow": 0.06,
			"chin": 0.02},
		"snout": {"length": 0.068, "spread": 46.0, "taper": 0.26, "pitch": 14.0},
		"nose": {"shape": "oval", "size": Vector3(0.034, 0.022, 0.02), "heart": 0.35, "raise": 0.006},
		"markings": [
			{"dir": Vector3(0, -0.26, -1), "size": 0.5, "soft": 0.1, "light": 1.0},
		],
		"eyes": {"yaw": 0.36, "pitch": 0.2, "radius": 0.026, "open": 0.9, "lashes": 0},
		"brows": {"yaw": 0.37, "pitch": 0.43, "span": 0.34, "width": 0.014, "height": 0.006},
		"mouth": {"kind": "bear", "width": 0.26, "drop": 0.36},
		"ears": {"kind": "round", "yaw": 0.75, "pitch": 0.9, "height": 0.066, "width": 0.096, "tilt": 12.0,
			"lean": -14.0, "tip": 0.0, "inner": "inner", "tuft": false},
		"body": {"belly": 0.05, "chest": 1.06},
		"outfit": {"lapel": "notch", "vest": true, "neckwear": "tie", "pocket_square": true, "watch_chain": true,
			"shoes": "oxford"},
		"paws": {"kind": "paw", "claws": true},
		"tail": {},
		"hat": {"kind": "bowler", "size": 0.95, "pos": Vector3(-0.008, 0.248, 0.008), "rot": Vector3(-6, 0, 9)},
	},
	{
		"id": "pig", "label": "猪",
		"fur": Color(0.86, 0.5, 0.47), "muzzle": Color(0.92, 0.58, 0.56), "dark": Color(0.46, 0.25, 0.22),
		"hide": "skin",
		"coat": Color(0.2, 0.3, 0.17), "accent": Color(0.85, 0.3, 0.22),
		"palette": {
			"nose": Color(0.9, 0.46, 0.5), "iris": Color(0.38, 0.6, 0.8), "vest": Color(0.78, 0.6, 0.26),
			"pad": Color(0.36, 0.24, 0.26), "hat": Color(0.4, 0.3, 0.2), "hat_band": Color(0.3, 0.22, 0.14),
			"trousers": Color(0.34, 0.27, 0.2), "skin": Color(0.95, 0.55, 0.55), "inner": Color(0.95, 0.5, 0.52),
			"claw": Color(0.42, 0.3, 0.3),
		},
		"patterns": {"coat": ["check", 14.0], "hat": ["tweed", 16.0], "trousers": ["tweed", 18.0]},
		"ink": Color(0.55, 0.42, 0.18),
		"head": {"radius": 0.168, "scale": Vector3(1.07, 0.94, 0.97), "cheek": 0.12, "jowl": 0.12, "brow": 0.03},
		"snout": {"length": 0.05, "spread": 36.0, "taper": 0.12, "pitch": 6.0, "flat": 1.0},
		"nose": {"shape": "disc", "size": Vector3(0.052, 0.042, 0.022)},
		"markings": [],
		"eyes": {"yaw": 0.43, "pitch": 0.24, "radius": 0.025, "open": 0.85, "lashes": 3},
		"brows": {"yaw": 0.44, "pitch": 0.47, "span": 0.3, "width": 0.009, "height": 0.004},
		"mouth": {"kind": "pig", "width": 0.34, "drop": 0.42},
		"ears": {"kind": "floppy", "yaw": 1.08, "pitch": 0.4, "height": 0.115, "width": 0.1, "tilt": 52.0,
			"lean": -20.0, "bend": -1.0, "tip": 0.0, "inner": "skin", "tuft": false},
		"body": {"belly": 0.06, "chest": 0.98},
		"outfit": {"lapel": "notch", "vest": true, "neckwear": "bow", "pocket_square": false, "watch_chain": false,
			"flower": true, "shoes": "oxford"},
		"paws": {"kind": "hoof"},
		"tail": {"kind": "curl", "side": -1.0, "length": 0.16, "radius": 0.012, "tip": 0.0},
		"hat": {"kind": "cap", "size": 1.0, "pos": Vector3(0.0, 0.225, 0.008), "rot": Vector3(-5, 0, -6)},
	},
	{
		"id": "cat", "label": "猫",
		"fur": Color(0.46, 0.47, 0.52), "muzzle": Color(0.9, 0.89, 0.87), "dark": Color(0.16, 0.16, 0.19),
		"coat": Color(0.3, 0.22, 0.38), "accent": Color(0.42, 0.66, 0.72),
		"palette": {
			"nose": Color(0.86, 0.5, 0.56), "iris": Color(0.55, 0.82, 0.3), "vest": Color(0.16, 0.3, 0.33),
			"trim": Color(0.2, 0.14, 0.26), "pad": Color(0.85, 0.5, 0.55), "hat": Color(0.14, 0.11, 0.1),
			"trousers": Color(0.16, 0.14, 0.17), "shoes": Color(0.3, 0.17, 0.09), "inner": Color(0.9, 0.6, 0.63),
			"stone": Color(0.25, 0.75, 0.75),
		},
		"patterns": {"coat": ["velvet", 0.0], "vest": ["stripes", 30.0]},
		"head": {"radius": 0.156, "scale": Vector3(1.08, 0.93, 0.98), "cheek": 0.22, "brow": 0.035},
		"snout": {"length": 0.03, "spread": 44.0, "taper": 0.3, "pitch": 12.0},
		"nose": {"shape": "oval", "size": Vector3(0.017, 0.012, 0.011), "heart": 0.5, "raise": 0.002},
		"markings": [
			{"dir": Vector3(0, -0.5, -1), "size": 0.55, "soft": 0.12, "light": 1.0, "below": -0.02},
		],
		"stripes": {"count": 9.0, "from": 0.3, "strength": 0.85},
		"eyes": {"yaw": 0.42, "pitch": 0.18, "radius": 0.032, "open": 0.84, "lashes": 0, "pupil": "slit"},
		"brows": {"yaw": 0.43, "pitch": 0.46, "span": 0.36, "width": 0.009, "height": 0.003},
		"mouth": {"kind": "cat", "width": 0.28, "drop": 0.32},
		"ears": {"kind": "cat", "yaw": 0.66, "pitch": 0.95, "height": 0.095, "width": 0.075, "tilt": 16.0,
			"lean": -4.0, "tip": 0.0, "inner": "inner", "tuft": true},
		"whiskers": {"count": 3, "yaw": 0.3, "pitch": -0.05, "fan": 0.22, "length": 0.095},
		"tufts": {"count": 2, "yaw": 1.05, "pitch": -0.22, "step": 0.18, "length": 0.05, "width": 0.014},
		"body": {"belly": 0.01, "chest": 0.98},
		"outfit": {"lapel": "shawl", "vest": true, "neckwear": "bolo", "pocket_square": false, "watch_chain": true,
			"shoes": "boot"},
		"paws": {"kind": "paw"},
		"tail": {"kind": "slender", "side": -1.0, "length": 0.7, "radius": 0.026, "tip": 0.0, "rings": 6},
		"hat": {"kind": "cowboy", "size": 0.86, "pos": Vector3(0.0, 0.242, 0.01), "rot": Vector3(-7, 0, 8)},
	},
]
