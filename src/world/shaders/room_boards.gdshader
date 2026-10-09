// 木板面(地板、天花板):错缝铺的长木板,每块板的颜色、木纹各不相同,带节疤、板缝、
// 板头与下方龙骨处的钉子、走动磨出的发亮发白区域。木板沿物体坐标 X 方向铺、沿 Z 方向一排排排列
// (合批时用部件坐标 CUSTOM0)。大面积着色器:每像素 4 次噪声,其余图案(年轮、节疤、钉子)是解析式。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform vec3 color_dark : source_color = vec3(0.28, 0.21, 0.165);
uniform vec3 color_light : source_color = vec3(0.52, 0.4, 0.3);
uniform float plank_width = 0.22;
uniform float plank_length = 2.1;
uniform float knot_chance = 0.3;
uniform float nail_radius = 0.0055;
uniform float end_nail_inset = 0.035;   // 板头钉离接缝的距离
uniform float joist_spacing = 0.6;      // 龙骨间距:每排钉子的位置(0 = 不钉)
uniform float wear = 0.6;
uniform float roughness_base = 0.72;
uniform float seam_darkness = 0.82;

varying vec2 board_pos;

void vertex() {
	vec3 p = CUSTOM1.x >= 2.0 ? CUSTOM0.xyz : VERTEX;
	board_pos = p.xz;
}

float nail_dot(vec2 d, float r, float aa) {
	return 1.0 - smoothstep(r - aa, r + aa, length(d));
}

void fragment() {
	float along = board_pos.x;
	float across = board_pos.y;
	float row = floor(across / plank_width);
	float shift = hash12(vec2(row, 3.7)) * plank_length;
	vec2 id = vec2(row, floor((along + shift) / plank_length));
	float rnd = hash12(id + 0.37);
	float rnd2 = hash12(id + 5.21);
	float fa = fract(across / plank_width);
	float fl = fract((along + shift) / plank_length);
	float side_d = min(fa, 1.0 - fa) * plank_width;
	float end_d = min(fl, 1.0 - fl) * plank_length;
	// 屏幕上一个像素对应的长度:板缝、钉子按它抗锯齿,远处自然淡出而不闪烁
	float px = max(fwidth(across) + fwidth(along), 1e-4);
	float seam = 1.0 - smoothstep(0.0012, 0.0012 + px, min(side_d, end_d));
	// 节疤:约三成木板有一个,周围的年轮绕着它弯
	float knot_at = (0.15 + 0.7 * hash12(id + 2.3)) * plank_length;
	vec2 kq = vec2((fl * plank_length - knot_at) / 0.045, (fa - 0.25 - 0.5 * rnd2) * plank_width / 0.02);
	float kd = length(kq);
	float has_knot = step(1.0 - knot_chance, hash12(id + 9.1));
	// 年轮:沿板长拉伸、被噪声扭曲的条纹
	float warp = value_noise(vec2(along * 0.6, across * 4.0) + rnd * 31.0);
	float phase = fa * 2.2 + warp * 1.4 + rnd * 5.0 + has_knot * 1.2 / (1.0 + kd * kd * 0.15);
	float rings = fract(phase * (2.0 + rnd * 2.0));
	rings = smoothstep(0.0, 0.6, rings) * (1.0 - smoothstep(0.6, 1.0, rings));
	float grain = value_noise(vec2(along * 1.5, across * 70.0 + rnd * 40.0)) * 0.65
		+ value_noise(vec2(along * 4.0, across * 160.0)) * 0.35;
	float t = clamp(rings * 0.3 + grain * 0.45 + (rnd - 0.5) * 0.4, 0.0, 1.0);
	vec3 col = mix(color_dark, color_light, t);
	col *= vec3(1.0 + (rnd2 - 0.5) * 0.16, 1.0, 1.0 - (rnd2 - 0.5) * 0.16);
	col = mix(col, color_dark * 0.55, has_knot * (1.0 - smoothstep(0.55, 1.0, kd)));
	// 走动磨损:大片发白发亮,板边缘磨圆而略暗
	float worn = smoothstep(0.35, 0.85, value_noise(board_pos * 0.45 + 3.0)) * wear;
	col *= 1.0 + worn * 0.22;
	col *= 0.84 + 0.16 * smoothstep(0.0, 0.012, min(side_d, end_d));
	col *= mix(1.0, 1.0 - seam_darkness, seam);
	// 钉子:板头两颗 + 每道龙骨处两颗
	float nail_aa = px * 0.7;
	float nail_x = abs(fa - 0.5) - 0.23;
	float nail = nail_dot(vec2(end_d - end_nail_inset, nail_x * plank_width), nail_radius, nail_aa);
	if (joist_spacing > 0.0) {
		float jd = (fract(along / joist_spacing) - 0.5) * joist_spacing;
		nail = max(nail, nail_dot(vec2(jd, nail_x * plank_width), nail_radius, nail_aa));
	}
	nail *= 1.0 - smoothstep(nail_radius * 0.6, nail_radius * 1.4, px);
	col = mix(col, vec3(0.045, 0.04, 0.035), nail);
	ALBEDO = col;
	METALLIC = nail * 0.6;
	ROUGHNESS = clamp(roughness_base + grain * 0.12 - worn * 0.2 + seam * 0.25 - nail * 0.3, 0.1, 1.0);
	SPECULAR = 0.45;
}
