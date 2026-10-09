// 炭床:一块块暗色的炭(按部件坐标的蜂窝格,每格一块),炭块之间的缝里透出橙红的火光;
// 少数炭块整块烧得发红,另有几块蒙着灰白的炭灰。热区随一层很慢的值噪声游走,整体亮度起伏。
// 炭块本身是暗的,炉膛不会糊成一团亮光。只有炭床和几块散炭用它,面积小:9 次哈希 + 1 次值噪声。
// CUSTOM0 = 部件自身坐标(合批前的物体坐标)。
shader_type spatial;
render_mode diffuse_burley;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform vec3 coal_color : source_color = vec3(0.04, 0.032, 0.028);
uniform vec3 ash_color : source_color = vec3(0.36, 0.33, 0.3);
uniform vec3 glow_color : source_color = vec3(1.0, 0.26, 0.035);
uniform vec3 hot_color : source_color = vec3(1.0, 0.6, 0.22);
uniform float cell_scale = 22.0;
uniform float glow_energy = 3.0;
uniform vec2 bed_half = vec2(0.42, 0.2);   // 炭床的半宽、半深(FireplaceFire.BED_SIZE)

varying vec3 part_pos;

void vertex() {
	part_pos = CUSTOM0.xyz;
}

vec2 cell_jitter(vec2 c) {
	return vec2(hash12(c), hash12(c + vec2(17.3, 5.9))) * 0.8 + 0.1;
}

void fragment() {
	vec2 p = part_pos.xz * cell_scale + part_pos.y * 6.0;
	vec2 cell = floor(p);
	vec2 f = fract(p);
	float d1 = 8.0;
	float d2 = 8.0;
	vec2 nearest = cell;
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 o = vec2(float(i), float(j));
			vec2 r = o + cell_jitter(cell + o) - f;
			float d = dot(r, r);
			if (d < d1) {
				d2 = d1;
				d1 = d;
				nearest = cell + o;
			} else if (d < d2) {
				d2 = d;
			}
		}
	}
	float id = hash12(nearest + vec2(3.7, 9.1));
	float edge = sqrt(d2) - sqrt(d1);
	float drift = value_noise(p * 0.18 - vec2(TIME * 0.06, TIME * 0.04));
	float crack = 1.0 - smoothstep(0.03, 0.2, edge);
	float burning = smoothstep(0.72, 0.9, id) * (0.4 + 0.6 * drift);
	float ash = smoothstep(0.22, 0.05, id);
	// 炭床中间(柴底下)最热,往边上渐渐只剩暗炭与炭灰;散落在前沿的小炭块在部件坐标原点附近,同样算"中间"
	float rim = smoothstep(0.55, 1.0, length(part_pos.xz / bed_half));
	float heat = clamp(crack * (0.3 + 0.9 * drift) + burning * 0.55, 0.0, 1.0) * (1.0 - 0.75 * rim);
	ash = max(ash, rim * 0.6);
	vec3 coal = mix(coal_color * (0.7 + 0.6 * id), ash_color, ash * 0.7);
	ALBEDO = coal * (1.0 - crack * 0.6);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	EMISSION = mix(glow_color, hot_color, heat * heat) * heat * heat * glow_energy;
}
