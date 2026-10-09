// 墙上的"画面":一个着色器画五种东西,按部件染色的 alpha 选(DecorMaterials.CANVAS_*):
//   0    风景油画:黄昏天空、落日、三层远山、湖面倒影,笔触扭曲 + 画布纹 + 发黄的旧清漆;
//   0.25 肖像油画:深色背景前一位穿西装、打领结的狐狸绅士;
//   0.5  通缉令:旧纸、"WANTED"、墨线画的嫌犯头像、"$500" 赏金、几行小字;
//   0.75 黑板:粉笔写的 "LIARS"、计分表、正字计数、黑桃与红心;
//   1    飞镖盘:20 格黑白相间、红绿双倍/三倍环、靶心(按部件坐标的极坐标画,盘半径 dart_radius)。
// 画面坐标是 UV(左上为原点、y 向下);部件种子(CUSTOM1)让同类的几张各不相同。每像素最多 3 次值噪声。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform float dart_radius = 0.225;

const float CHALK_ASPECT = 1.571;   // 黑板画面的宽高比(1.1 × 0.7 米)

// 5×5 点阵字形(每行 5 位,从上到下):W A N T E D $ 5 0 L I R S 1 2
const int GLYPHS[15] = int[](18405233, 15269425, 18667121, 32641156, 33061407, 32032318, 16398526, 33060926,
	15324974, 17318431, 32641183, 32045715, 16267326, 4591758, 31504927);
const int WORD_WANTED[6] = int[](0, 1, 2, 3, 4, 5);
const int WORD_LIARS[5] = int[](9, 10, 1, 11, 12);

varying vec3 local_pos;
varying float part_seed;

void vertex() {
	bool batched = CUSTOM1.x >= 2.0;
	local_pos = batched ? CUSTOM0.xyz : VERTEX;
	part_seed = batched ? fract(CUSTOM1.x) : 0.0;
}

float glyph_bit(int glyph, vec2 px) {
	// px:字形内的像素坐标(0..5),落在点阵外返回 0
	if (px.x < 0.0 || px.y < 0.0 || px.x >= 5.0 || px.y >= 5.0) {
		return 0.0;
	}
	int col = int(px.x);
	int row = int(px.y);
	return float((GLYPHS[glyph] >> ((4 - row) * 5 + (4 - col))) & 1);
}

float word(vec2 uv, vec2 origin, float pixel, int which) {
	// which:0 = WANTED,1 = LIARS,2 = $500(赏金,数字随种子)。字距 1 像素
	vec2 px = (uv - origin) / pixel;
	int i = int(floor(px.x / 6.0));
	vec2 local = vec2(px.x - float(i) * 6.0, px.y);
	if (which == 0 && i >= 0 && i < 6) {
		return glyph_bit(WORD_WANTED[i], local);
	}
	if (which == 1 && i >= 0 && i < 5) {
		return glyph_bit(WORD_LIARS[i], local);
	}
	if (which == 2 && i >= 0 && i < 4) {
		int lead = part_seed > 0.5 ? 13 : 7;
		int g = i == 0 ? 6 : (i == 1 ? lead : 8);
		return glyph_bit(g, local);
	}
	return 0.0;
}

float sd_box(vec2 p, vec2 half_size) {
	vec2 d = abs(p) - half_size;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sd_triangle_up(vec2 p, float size) {
	// 尖朝上的三角形(y 向下的画面坐标):尖在 p.y = -size,底边在 p.y = 1.5 size
	p.x = abs(p.x);
	return max(p.x * 0.87 - p.y * 0.5, p.y - size) - size * 0.5;
}

float sd_wedge(vec2 p, float base, float half_w, float apex) {
	// 左右对称的三角形:底边在 y = base(半宽 half_w),尖在 (0, apex);尖可朝上也可朝下(y 朝上的坐标)
	p.x = abs(p.x);
	float h = apex - base;
	vec2 n = normalize(vec2(abs(h), sign(h) * half_w));
	return max(dot(p - vec2(0.0, apex), n), sign(h) * (base - p.y));
}

float fill(float d, float aa) {
	return 1.0 - smoothstep(-aa, aa, d);
}

// —— 风景 ——

vec3 landscape(vec2 uv, float aa) {
	float stroke = value_noise(uv * vec2(9.0, 26.0) + part_seed * 40.0);
	vec2 p = uv + (stroke - 0.5) * 0.012;
	float horizon = 0.62;
	// 种子换构图:落日左右挪、山脊错开、松树换到另一边
	vec2 sun = vec2(0.68 - 0.4 * part_seed, 0.5);
	float phase = part_seed * 5.0;
	float tree_x = part_seed > 0.5 ? 0.8 : 0.2;
	vec3 sky = mix(vec3(1.0, 0.62, 0.3), vec3(0.16, 0.3, 0.52), smoothstep(horizon - 0.05, 0.02, p.y));
	sky = mix(sky, vec3(0.85, 0.42, 0.42), (1.0 - abs(p.y - 0.3) / 0.12) * step(abs(p.y - 0.3), 0.12) * 0.35);
	sky = mix(sky, vec3(1.0, 0.86, 0.55), exp(-length((p - sun) * vec2(1.0, 1.6)) * 7.0) * 0.8);
	vec3 col = sky;
	col = mix(col, vec3(1.0, 0.93, 0.7), fill(length(p - sun) - 0.055, aa));
	float far_ridge = 0.5 + 0.05 * sin(p.x * 9.0 + 1.0 + phase) + 0.025 * sin(p.x * 23.0 + phase);
	col = mix(col, vec3(0.45, 0.42, 0.5), fill(far_ridge - p.y, aa));
	float mid_ridge = 0.56 + 0.06 * sin(p.x * 6.0 + 3.0 - phase) + 0.02 * sin(p.x * 19.0 + 1.0);
	col = mix(col, vec3(0.24, 0.27, 0.25), fill(mid_ridge - p.y, aa));
	// 湖面:倒映天空,越近越暗;一道落日的反光
	float lake = fill(horizon - p.y, aa);
	vec3 water = mix(vec3(0.62, 0.5, 0.36), vec3(0.12, 0.16, 0.2), smoothstep(horizon, 0.86, p.y));
	water += vec3(0.5, 0.35, 0.15) * (1.0 - smoothstep(0.0, 0.03, abs(p.x - sun.x))) * stroke;
	col = mix(col, water, lake);
	// 近处的岸与一棵松树
	float shore = 0.82 + 0.05 * sin(p.x * 5.0 + 0.5);
	col = mix(col, vec3(0.1, 0.12, 0.07), fill(shore - p.y, aa));
	// 松树:y 朝上的局部坐标,两层树冠 + 树干
	vec2 t = vec2(p.x - tree_x, 0.84 - p.y);
	float tree = min(sd_wedge(t, 0.04, 0.075, 0.26), sd_wedge(t, 0.14, 0.055, 0.34));
	tree = min(tree, sd_box(t - vec2(0.0, 0.03), vec2(0.01, 0.04)));
	col = mix(col, vec3(0.06, 0.09, 0.05), fill(tree, aa));
	return col * (0.92 + stroke * 0.16);
}

// —— 肖像 ——

vec3 portrait(vec2 uv, float aa) {
	vec2 p = uv - vec2(0.5, 0.5);
	vec3 col = mix(vec3(0.22, 0.14, 0.08), vec3(0.06, 0.04, 0.03), smoothstep(0.1, 0.6, length(p * vec2(1.3, 1.0))));
	// 西装肩膀、白衬衫领口、红领结
	vec2 s = p - vec2(0.0, 0.42);
	float shoulders = length(s * vec2(1.0, 1.8)) - 0.36;
	col = mix(col, vec3(0.1, 0.12, 0.16), fill(shoulders, aa));
	float shirt = max(abs(s.x) * 1.6 + s.y + 0.08, -s.y - 0.3);
	col = mix(col, vec3(0.86, 0.82, 0.74), fill(shirt * 0.5, aa));
	vec2 b = p - vec2(0.0, 0.2);
	float bow = max(abs(b.y) - abs(b.x) * 0.6 - 0.008, abs(b.x) - 0.06);
	col = mix(col, vec3(0.6, 0.08, 0.06), fill(bow, aa));
	// 狐狸头:橙色脸 + 白腮 + 两只尖耳 + 黑鼻尖与眼睛
	vec2 h = p - vec2(0.0, -0.04);
	float head = length(h * vec2(1.0, 1.15)) - 0.17;
	float ear_l = sd_triangle_up(h - vec2(-0.12, -0.15), 0.07);
	float ear_r = sd_triangle_up(h - vec2(0.12, -0.15), 0.07);
	vec3 fur = vec3(0.82, 0.42, 0.14);
	col = mix(col, fur * 0.8, fill(min(ear_l, ear_r), aa));
	col = mix(col, fur, fill(head, aa));
	float cheeks = length((h - vec2(0.0, 0.08)) * vec2(0.8, 1.6)) - 0.13;
	col = mix(col, vec3(0.92, 0.88, 0.8), fill(max(cheeks, head), aa));
	col = mix(col, vec3(0.04), fill(length(h - vec2(0.0, 0.07)) - 0.022, aa));
	col = mix(col, vec3(0.04), fill(length(vec2(abs(h.x) - 0.065, h.y + 0.02)) - 0.016, aa));
	return col;
}

// —— 通缉令 ——

vec3 poster(vec2 uv, float aa) {
	float stain = value_noise(uv * vec2(5.0, 7.0) + part_seed * 30.0);
	vec3 paper = mix(vec3(0.78, 0.68, 0.48), vec3(0.6, 0.48, 0.3), smoothstep(0.4, 0.9, stain));
	float edge = min(min(uv.x, 1.0 - uv.x), min(uv.y, 1.0 - uv.y));
	paper *= 0.7 + 0.3 * smoothstep(0.0, 0.08, edge + (stain - 0.5) * 0.04);
	vec3 ink = vec3(0.12, 0.08, 0.05);
	vec3 col = paper;
	col = mix(col, ink, word(uv, vec2(0.09, 0.07), 0.0235, 0));
	// 头像框与墨线画的嫌犯:圆脸 + 随种子换的耳朵(猫耳 / 熊耳 / 兔耳)
	vec2 f = uv - vec2(0.5, 0.43);
	float frame = abs(sd_box(f, vec2(0.3, 0.2))) - 0.006;
	col = mix(col, ink, fill(frame, aa));
	vec2 h = f - vec2(0.0, 0.03);
	float face = length(h) - 0.1;
	float ears;
	if (part_seed < 0.33) {
		ears = min(sd_triangle_up(h - vec2(-0.07, -0.1), 0.035), sd_triangle_up(h - vec2(0.07, -0.1), 0.035));
	} else if (part_seed < 0.66) {
		ears = min(length(h - vec2(-0.08, -0.08)), length(h - vec2(0.08, -0.08))) - 0.035;
	} else {
		ears = min(length((h - vec2(-0.04, -0.15)) * vec2(2.5, 0.8)), length((h - vec2(0.04, -0.15)) * vec2(2.5, 0.8))) - 0.06;
	}
	float head = min(face, ears);
	col = mix(col, ink * 2.2 + paper * 0.3, fill(head, aa) * 0.55);
	col = mix(col, ink, fill(abs(head) - 0.004, aa));
	col = mix(col, ink, fill(length(vec2(abs(h.x) - 0.035, h.y + 0.01)) - 0.009, aa));
	col = mix(col, ink, word(uv, vec2(0.21, 0.69), 0.03, 2));
	// 几行小字:一格格墨点,行尾长短不一
	vec2 line_p = vec2(uv.x, (uv.y - 0.86) / 0.035);
	float line_id = floor(line_p.y);
	float words = step(0.35, value_noise(vec2(uv.x * 40.0, line_id * 7.0 + part_seed * 9.0)));
	float in_line = step(0.0, line_p.y) * step(line_p.y, 2.0) * step(abs(fract(line_p.y) - 0.5), 0.2);
	float line_len = 0.6 + 0.3 * hash12(vec2(line_id, part_seed * 13.0));
	col = mix(col, ink, in_line * words * step(0.12, uv.x) * step(uv.x, 0.12 + line_len * 0.76) * 0.8);
	return col;
}

// —— 黑板 ——

float score_table(vec2 uv, float aa) {
	// 计分表:表头横线 + 栏间竖线;每栏一串计数划痕,每五划一组(第五划斜着划过前四划)
	float marks = fill(abs(uv.y - 0.3) - 0.004, aa) * step(0.06, uv.x) * step(uv.x, 0.62);
	for (int c = 0; c < 4; c++) {
		float x0 = 0.08 + float(c) * 0.14;
		if (c > 0) {
			marks = max(marks, fill(abs(uv.x - x0 + 0.02) - 0.003, aa) * step(0.24, uv.y) * step(uv.y, 0.88));
		}
		float tallies = floor(hash12(vec2(float(c), 5.0)) * 8.0) + 2.0;
		for (int k = 0; k < 10; k++) {
			if (float(k) >= tallies) {
				break;
			}
			float group = floor(float(k) / 5.0);
			float in_group = mod(float(k), 5.0);
			vec2 at = vec2(x0 + 0.015 + in_group * 0.018, 0.4 + group * 0.14);
			float stroke = in_group < 4.0 ? abs(uv.x - at.x + (uv.y - at.y) * 0.08) - 0.003
				: abs((uv.x - (x0 + 0.05)) * 0.6 + (uv.y - at.y) * 0.8) - 0.003;
			marks = max(marks, fill(stroke, aa) * step(abs(uv.y - at.y), 0.05));
		}
	}
	return marks;
}

vec3 chalkboard(vec2 uv, float aa) {
	float smudge = value_noise(uv * vec2(6.0, 4.0) + 2.0);
	vec3 col = vec3(0.07, 0.09, 0.08) * (0.85 + smudge * 0.5);
	vec3 chalk = vec3(0.82, 0.82, 0.76);
	float grain = 0.6 + 0.4 * value_noise(uv * 240.0);
	float marks = word(uv, vec2(0.08, 0.08), 0.03, 1);
	marks = max(marks, score_table(uv, aa));
	// 右侧画一个黑桃、一个红心(红心用暖色粉笔)。黑板是横长的:换成以板高为单位、y 朝上的坐标,图形不被拉扁
	vec2 sp = (uv - vec2(0.8, 0.36)) * vec2(CHALK_ASPECT, -1.0);
	float spade = min(length(vec2(abs(sp.x) - 0.04, sp.y + 0.02)) - 0.045, sd_wedge(sp, -0.02, 0.083, 0.095));
	spade = min(spade, sd_wedge(sp, -0.12, 0.035, -0.04));
	marks = max(marks, fill(abs(spade) - 0.004, aa));
	vec2 hp = (uv - vec2(0.8, 0.72)) * vec2(CHALK_ASPECT, -1.0);
	float heart = min(length(vec2(abs(hp.x) - 0.04, hp.y - 0.02)) - 0.045, sd_wedge(hp, 0.02, 0.083, -0.095));
	col = mix(col, chalk, marks * grain * 0.85);
	col = mix(col, vec3(0.85, 0.42, 0.38), fill(abs(heart) - 0.004, aa) * grain * 0.85);
	return col;
}

// —— 飞镖盘 ——

vec3 dartboard(vec2 p) {
	float r = length(p) / dart_radius;
	float aa = max(fwidth(r), 1e-4) * 1.5;
	float angle = atan(p.y, p.x) / 6.2831853 * 20.0 + 0.5;
	float seg = mod(floor(angle), 2.0);
	vec3 black = vec3(0.04, 0.04, 0.04);
	vec3 sisal = vec3(0.82, 0.74, 0.56);
	vec3 col = mix(sisal, black, seg);
	float ring_double = smoothstep(0.71 - aa, 0.71 + aa, r) * (1.0 - smoothstep(0.755 - aa, 0.755 + aa, r));
	float ring_triple = smoothstep(0.44 - aa, 0.44 + aa, r) * (1.0 - smoothstep(0.48 - aa, 0.48 + aa, r));
	col = mix(col, mix(vec3(0.62, 0.08, 0.06), vec3(0.05, 0.35, 0.14), seg), max(ring_double, ring_triple));
	col = mix(col, vec3(0.05, 0.35, 0.14), 1.0 - smoothstep(0.07 - aa, 0.07 + aa, r));
	col = mix(col, vec3(0.62, 0.08, 0.06), 1.0 - smoothstep(0.03 - aa, 0.03 + aa, r));
	// 数字圈:黑底上一圈米白的刻度
	float tick = step(abs(fract(angle) - 0.5), 0.12) * step(0.84, r) * step(r, 0.9);
	col = mix(col, black * 1.4, smoothstep(0.755 - aa, 0.755 + aa, r));
	col = mix(col, sisal * 0.9, tick);
	// 金属分隔丝:按米算到格线的距离,线宽不随半径变粗
	float wire_d = abs(fract(angle + 0.5) - 0.5) * 6.2831853 * length(p) / 20.0;
	float wire_aa = max(fwidth(wire_d), 1e-5);
	float wire = 1.0 - smoothstep(0.0007 - wire_aa, 0.0007 + wire_aa, wire_d);
	col = mix(col, vec3(0.6), wire * step(0.07, r) * step(r, 0.755) * 0.7);
	return col;
}

void fragment() {
	float mode = COLOR.a;
	vec2 uv = UV;
	float aa = max(fwidth(uv.x) + fwidth(uv.y), 1e-4) * 0.75;
	vec3 col;
	float rough = 0.6;
	if (mode < 0.125) {
		col = landscape(uv, aa);
	} else if (mode < 0.375) {
		col = portrait(uv, aa);
	} else if (mode < 0.625) {
		col = poster(uv, aa);
		rough = 0.9;
	} else if (mode < 0.875) {
		col = chalkboard(uv, aa);
		rough = 0.95;
	} else {
		col = dartboard(local_pos.xz);
		rough = 0.85;
	}
	if (mode < 0.375) {
		// 油画:画布纹 + 发黄的旧清漆,四边略暗
		vec2 weave_p = uv * 380.0;
		float weave_fade = 1.0 - smoothstep(0.3, 0.9, fwidth(weave_p.x) + fwidth(weave_p.y));
		col *= 1.0 + (value_noise(weave_p) - 0.5) * 0.12 * weave_fade;
		col *= vec3(1.0, 0.94, 0.8);
		vec2 v = abs(uv - 0.5) * 2.0;
		col *= 1.0 - 0.3 * pow(max(v.x, v.y), 4.0);
		rough = 0.35;
	}
	ALBEDO = col * COLOR.rgb;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
