// 牌桌下的圆形手织地毯:中心靛蓝八角星章 → 圆点内框 → 深茜红底上的细菱格与小星、一圈靛蓝锯齿 → 驼色宽边上一圈红蓝交替的阶梯菱形
// → 深色包边。颜色压得沉稳,不和桌上的绿呢、牌抢眼。另有手织地毯特有的横向色差条(abrash)、绒头细噪、椅子来回拖出的磨损浅环。
// 按部件坐标(CUSTOM0,地毯中心为原点)取极坐标;大面积着色器:每像素 4 次值噪声,其余为解析式。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform float radius = 2.45;
uniform vec3 field_color : source_color = vec3(0.3, 0.07, 0.055);
uniform vec3 field_dark : source_color = vec3(0.2, 0.045, 0.04);
uniform vec3 indigo : source_color = vec3(0.07, 0.085, 0.17);
uniform vec3 cream : source_color = vec3(0.56, 0.46, 0.33);
uniform vec3 ochre : source_color = vec3(0.52, 0.33, 0.13);
uniform vec3 binding : source_color = vec3(0.09, 0.055, 0.045);
uniform float motifs = 52.0;          // 宽边一圈的菱形个数
uniform float wear_ring = 0.62;       // 椅子磨损环(半径比例)

varying vec3 local_pos;

void vertex() {
	local_pos = CUSTOM1.x >= 2.0 ? CUSTOM0.xyz : VERTEX;
}

float band(float x, float a, float b, float aa) {
	return smoothstep(a - aa, a + aa, x) * (1.0 - smoothstep(b - aa, b + aa, x));
}

vec3 medallion(float rn, float angle, float aa) {
	// 八角星:半径随角度在两档之间折线变化,星外是一圈米黄描边
	float spoke = abs(fract(angle * 8.0 / 6.2831853) - 0.5) * 2.0;
	float star_r = mix(0.1, 0.2, spoke);
	vec3 col = mix(cream, indigo, smoothstep(star_r - aa, star_r + aa, rn));
	col = mix(col, ochre, band(rn, star_r - 0.012, star_r + 0.004, aa) * step(rn, 0.21));
	col = mix(col, field_color, band(rn, 0.03, 0.06, aa));
	return col;
}

vec3 field(vec2 p, float rn, float angle) {
	// 底纹:旋转 45° 的细菱格(深色细线,压得很低)+ 格心交替的小星与小点;靠外一圈靛蓝锯齿
	vec2 q = vec2(p.x + p.y, p.x - p.y) * 3.2;
	float aa_q = max(fwidth(q.x) + fwidth(q.y), 1e-4);
	vec2 g = abs(fract(q) - 0.5);
	float edge = 0.5 - max(g.x, g.y);
	float line = 1.0 - smoothstep(0.012, 0.012 + aa_q, edge);
	float star = 1.0 - smoothstep(0.1, 0.1 + aa_q, min(g.x * 2.5 + g.y * 0.5, g.y * 2.5 + g.x * 0.5));
	float alt = mod(floor(q.x) + floor(q.y), 2.0);
	vec3 col = mix(field_color, field_dark, 0.3 + 0.3 * sin(rn * 34.0));
	col = mix(col, indigo, line * 0.45);
	col = mix(col, mix(ochre, cream, alt) * 0.8, star * 0.75);
	// 锯齿带:每格一个尖,靛蓝压在底色上
	float zig = abs(fract(angle * 72.0 / 6.2831853) - 0.5) * 2.0;
	float zig_y = (rn - 0.775) / 0.035;
	float in_zig = step(abs(zig_y), 1.0) * step(zig_y, zig * 1.6 - 0.6);
	col = mix(col, indigo, in_zig * 0.85);
	return col;
}

vec3 border(float rn, float angle) {
	// 阶梯菱形:x、y 各自量化成台阶,每格一个,红蓝交替;格间的小三角用赭黄
	float t = angle * motifs / 6.2831853;
	float id = floor(t);
	float x = (fract(t) - 0.5) * 2.0;
	float y = (rn - 0.8975) / 0.0475;
	float d = floor(abs(x) * 5.0) / 5.0 + floor(abs(y) * 5.0) / 5.0;
	vec3 motif = mod(id, 2.0) < 1.0 ? field_color : indigo;
	vec3 col = cream;
	col = mix(col, motif, step(d, 0.8));
	col = mix(col, cream, step(d, 0.2));
	col = mix(col, ochre, step(1.2, d) * step(abs(y), 0.75) * 0.7);
	return col;
}

void fragment() {
	vec2 p = local_pos.xz;
	float r = length(p);
	float rn = r / radius;
	float aa = max(fwidth(rn), 1e-4);
	float angle = atan(p.y, p.x) + 3.14159265;
	vec3 col;
	if (rn < 0.235) {
		col = medallion(rn, angle, aa);
	} else if (rn < 0.83) {
		col = field(p, rn, angle);
	} else {
		col = border(rn, angle);
	}
	// 分隔线:内框圆点带、宽边内外两道细线、最外的包边
	// 圆点:按米计算点到点心的距离,点是圆的而不是被极坐标拉长的
	float ring_r = 0.265 * radius;
	float dot_t = fract(angle * 36.0 / 6.2831853) - 0.5;
	float dot_d = length(vec2(dot_t * 6.2831853 * ring_r / 36.0, r - ring_r));
	float aa_m = aa * radius;
	col = mix(col, indigo, band(rn, 0.235, 0.295, aa));
	col = mix(col, cream, 1.0 - smoothstep(0.022 - aa_m, 0.022 + aa_m, dot_d));
	col = mix(col, ochre, band(rn, 0.83, 0.845, aa) + band(rn, 0.945, 0.955, aa));
	col = mix(col, field_dark, band(rn, 0.845, 0.85, aa));
	col = mix(col, binding, smoothstep(0.965 - aa, 0.965 + aa, rn));
	// 手工染色的色差横条 + 绒头 + 磨损
	float abrash = value_noise(vec2(p.x * 0.4, p.y * 3.5) + 7.0);
	col *= 0.86 + abrash * 0.22;
	vec2 pile_p = p * 260.0;
	float pile_fade = 1.0 - smoothstep(0.4, 1.2, fwidth(pile_p.x) + fwidth(pile_p.y));
	float pile = (value_noise(pile_p) - 0.5) * pile_fade;
	col *= 1.0 + pile * 0.28;
	float patch_ = value_noise(p * 1.3 + 3.1);
	float worn = (1.0 - smoothstep(0.0, 0.16, abs(rn - wear_ring))) * smoothstep(0.35, 0.75, patch_);
	vec3 faded = mix(col, vec3(dot(col, vec3(0.3, 0.55, 0.15))) * 1.25 + 0.03, 0.5);
	col = mix(col, faded, worn * 0.6);
	ALBEDO = col;
	ROUGHNESS = 0.93 - worn * 0.08;
	SPECULAR = 0.25;
	// 绒面掠射时泛一点柔光
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO *= 1.0 + rim * 0.35;
}
