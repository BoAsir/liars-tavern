// 石砌/灰泥墙面:block_size > 0 时为错缝石块 + 灰缝,否则为带污渍的灰泥。
shader_type spatial;
render_mode diffuse_burley;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform vec3 color_a : source_color = vec3(0.32, 0.28, 0.24);
uniform vec3 color_b : source_color = vec3(0.20, 0.17, 0.15);
uniform vec3 mortar_color : source_color = vec3(0.12, 0.10, 0.09);
uniform float block_size = 0.0;
uniform float soot = 0.0;         // 自下而上的烟熏(壁炉口)
uniform float soot_height = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	// 墙面坐标:取世界坐标中变化最大的两轴
	vec3 n = abs(world_normal);
	vec2 p = n.x > 0.5 ? world_pos.zy : (n.z > 0.5 ? world_pos.xy : world_pos.xz);
	float stain = fbm(p * 1.3);
	float speck = value_noise(p * 90.0);
	vec3 col = mix(color_b, color_a, smoothstep(0.25, 0.75, stain));
	float mortar = 0.0;
	if (block_size > 0.0) {
		vec2 cell = vec2(block_size * 1.6, block_size);
		float row = floor(p.y / cell.y);
		vec2 q = vec2(p.x / cell.x + hash12(vec2(row, 1.0)) * 0.5, p.y / cell.y);
		vec2 id = floor(q);
		vec2 f = fract(q);
		vec2 jitter = (vec2(value_noise(p * 7.0), value_noise(p * 7.0 + 3.0)) - 0.5) * 0.08;
		vec2 e = min(f + jitter, 1.0 - f - jitter);
		mortar = 1.0 - smoothstep(0.02, 0.06, min(e.x * cell.x, e.y * cell.y) / block_size);
		col *= 0.75 + 0.5 * hash12(id + 5.0);
	}
	col *= 0.85 + speck * 0.3;
	col = mix(col, mortar_color, mortar);
	float soot_mask = soot * (1.0 - smoothstep(0.0, soot_height, p.y)) * (0.6 + 0.4 * stain);
	col = mix(col, vec3(0.02), clamp(soot_mask, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.9 - speck * 0.1;
	SPECULAR = 0.25;
}
