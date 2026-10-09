// 柴火:树皮(顺着木纹的深裂)、劈开的浅色木面、锯口的年轮。炉膛里的柴烧焦了:朝上的面蒙一层灰白的灰,
// 贴近炭床的一面裂纹里透出橙红的火光、亮度随时间起伏;炉膛外柴堆里的柴不烧。
// 顶点色 alpha 标记部位(FireplaceLogs):1 = 树皮,0.5 = 劈面,0 = 锯口;rgb 是部件染色。
// CUSTOM0 = 柴自身坐标(Z 为长轴,截面圆心在原点),模型坐标(VERTEX)= 壁炉本地坐标。
shader_type spatial;
render_mode diffuse_burley;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform vec3 bark_color : source_color = vec3(0.13, 0.085, 0.058);
uniform vec3 wood_color : source_color = vec3(0.52, 0.37, 0.23);
uniform vec3 char_color : source_color = vec3(0.028, 0.022, 0.019);
uniform vec3 ash_color : source_color = vec3(0.16, 0.15, 0.145);
uniform vec3 glow_color : source_color = vec3(1.0, 0.3, 0.05);
uniform vec4 fire_area = vec4(0.0, 0.28, 0.46, 0.28);  // 烧着的区域:中心 x、z,半宽 x、半深 z(壁炉本地)
uniform float glow_top = 0.38;     // 高于此处的柴面只剩焦黑,不再透火光
uniform float glow_energy = 1.8;

varying vec3 part_pos;
varying vec3 fp_pos;
varying vec3 fp_normal;
varying float part_kind;
varying float part_seed;

void vertex() {
	part_pos = CUSTOM0.xyz;
	fp_pos = VERTEX;
	fp_normal = NORMAL;
	part_kind = COLOR.a;
	part_seed = fract(CUSTOM1.x);
}

void fragment() {
	float radius = length(part_pos.xy);
	float around = atan(part_pos.y, part_pos.x);
	float fissure = value_noise(vec2(around * 4.0 + part_seed * 40.0, part_pos.z * 7.0));
	float fine = value_noise(vec2(around * 21.0 + part_pos.z * 3.0, part_pos.z * 38.0 + part_seed * 9.0));
	float ridges = smoothstep(0.35, 0.7, fissure);
	vec3 bark = bark_color * (0.35 + 0.85 * ridges) * (0.75 + 0.5 * fine);
	float rings = fract(radius * 70.0 + fine * 0.7);
	vec3 end_grain = wood_color * (0.72 + 0.28 * smoothstep(0.1, 0.6, rings)) * (0.75 + 0.25 * smoothstep(0.0, 0.03, radius));
	vec3 split = wood_color * (0.78 + 0.32 * fine) * (0.86 + 0.14 * fissure);
	vec3 col = part_kind > 0.75 ? bark : (part_kind > 0.25 ? split : end_grain);
	col *= COLOR.rgb;
	// 炉膛里:烧焦,朝上的面积着灰;贴近炭床的部分沿裂纹透出火光
	vec2 rel = abs(fp_pos.xz - fire_area.xy) / fire_area.zw;
	float in_fire = 1.0 - smoothstep(0.85, 1.0, max(rel.x, rel.y));
	vec3 burnt = mix(char_color * (0.7 + 0.6 * fine), ash_color * (0.6 + 0.5 * fine),
		smoothstep(0.35, 0.95, fp_normal.y) * (0.4 + 0.6 * ridges));
	col = mix(col, burnt, in_fire * 0.92);
	float low = 1.0 - smoothstep(0.15, glow_top, fp_pos.y);
	float cracks = smoothstep(0.8, 0.95, 1.0 - abs(fissure * 2.0 - 1.0));
	float pulse = 0.65 + 0.35 * value_noise(vec2(TIME * 0.9 + part_seed * 10.0, fp_pos.x * 4.0));
	ALBEDO = col;
	ROUGHNESS = 0.92;
	SPECULAR = 0.2;
	EMISSION = glow_color * glow_energy * in_fire * low * (0.06 + cracks) * pulse * (1.0 - 0.8 * max(fp_normal.y, 0.0))
		* (part_kind > 0.25 ? 1.0 : 0.25);   // 锯口的年轮不顺着树皮裂纹发光
}
