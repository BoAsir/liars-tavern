// 牌桌桌布:细密绒面噪声 + 边缘压暗 + 金线刺绣圆环 + 绒面逆光光泽。
shader_type spatial;

#include "res://src/world/shaders/noise.gdshaderinc"
// 柔和卡通光照(见 toon_light.gdshaderinc)
#define TOON_RIM 0.3
#define TOON_SHADOW_TINT vec3(0.86, 0.9, 1.0)
#include "res://src/world/shaders/toon_light.gdshaderinc"

uniform vec3 felt_color : source_color = vec3(0.04, 0.15, 0.095);
uniform vec3 felt_edge : source_color = vec3(0.012, 0.05, 0.035);
uniform vec3 thread_color : source_color = vec3(0.85, 0.62, 0.25);
uniform float radius = 0.8;
uniform float inner_ring = 0.28;
uniform float outer_ring = 0.70;

varying vec3 obj_pos;

float ring_line(float r, float at, float width) {
	return 1.0 - smoothstep(width * 0.5, width, abs(r - at));
}

void fragment() {
	vec2 p = obj_pos.xz;
	float r = length(p);
	float fuzz = fbm(p * 160.0) * 0.6 + value_noise(p * 950.0) * 0.4;
	float wear = fbm(p * 6.0);
	vec3 col = mix(felt_color, felt_edge, smoothstep(radius * 0.5, radius, r));
	col *= 0.78 + fuzz * 0.38;
	col *= 0.9 + wear * 0.2;
	// 刺绣:内圈两股虚线针脚、外圈一道实线、再外一圈菱形针脚。金线是哑光丝线,不再亮得像霓虹灯
	float angle = atan(p.y, p.x);
	float dash = step(0.35, fract(angle * 96.0 / 6.2831853));
	float thread = max(ring_line(r, inner_ring - 0.0045, 0.003), ring_line(r, inner_ring + 0.0045, 0.003)) * dash;
	thread = max(thread, ring_line(r, outer_ring, 0.007));
	float diamond = abs(r - (outer_ring + 0.022)) + abs(fract(angle * 48.0 / 6.2831853) - 0.5) * 0.02;
	thread = max(thread, 1.0 - smoothstep(0.0, 0.0035, diamond));
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(col + felt_color * rim * 0.8, thread_color, thread);
	ROUGHNESS = mix(0.95, 0.6, thread);
	METALLIC = thread * 0.35;
	SPECULAR = mix(0.15, 0.4, thread);
}

void vertex() {
	obj_pos = VERTEX;
}
