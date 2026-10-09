// 炉膛内衬:熏得发黑的耐火砖(错缝),炭床附近的砖面被烤得暗红发亮,亮度随时间缓慢起伏
// (火光在炉口外侧,照不到炉膛深处,靠自发光撑起"里面在烧"的感觉)。
// 模型坐标就是壁炉本地坐标(网格挂在壁炉根节点下)。
shader_type spatial;
render_mode diffuse_burley;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform vec3 brick_color : source_color = vec3(0.085, 0.055, 0.042);
uniform vec3 mortar_color : source_color = vec3(0.022, 0.019, 0.018);
uniform vec2 brick_size = vec2(0.19, 0.062);
uniform vec3 glow_color : source_color = vec3(1.0, 0.33, 0.07);
uniform vec3 glow_center = vec3(0.0, 0.16, 0.24);
uniform vec3 glow_radius = vec3(0.55, 0.42, 0.42);
uniform float glow_energy = 1.6;

varying vec3 fp_pos;
varying vec3 fp_normal;

void vertex() {
	fp_pos = VERTEX;
	fp_normal = NORMAL;
}

void fragment() {
	vec3 n = abs(fp_normal);
	vec2 p = n.x > 0.6 ? fp_pos.zy : (n.y > 0.6 ? fp_pos.xz : fp_pos.xy);
	vec2 q = p / brick_size;
	q.x += mod(floor(q.y), 2.0) * 0.5;
	vec2 f = fract(q);
	vec2 edge = min(f, 1.0 - f) * brick_size;
	float mortar = 1.0 - smoothstep(0.003, 0.008, min(edge.x, edge.y));
	float tone = hash12(floor(q));
	float grime = value_noise(p * 9.0);
	vec3 col = brick_color * (0.65 + 0.7 * tone) * (0.7 + 0.6 * grime);
	col = mix(col, mortar_color, mortar);
	float heat = clamp(1.0 - length((fp_pos - glow_center) / glow_radius), 0.0, 1.0);
	float flicker = 0.78 + 0.22 * value_noise(vec2(TIME * 1.3, 7.0));
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
	EMISSION = glow_color * heat * heat * glow_energy * flicker * (1.0 - mortar * 0.7) * (0.55 + 0.45 * tone);
}
