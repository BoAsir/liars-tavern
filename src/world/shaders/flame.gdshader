// 火焰公告板:绕 Y 轴朝向相机的四边形,噪声驱动的泪滴形火舌,加色混合配合辉光。
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform vec3 core_color : source_color = vec3(1.0, 0.92, 0.62);
uniform vec3 edge_color : source_color = vec3(1.0, 0.36, 0.06);
uniform float intensity = 3.0;
uniform float speed = 1.0;
uniform float seed = 0.0;
uniform float sway = 0.35;

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float t = TIME * speed + seed * 17.0;
	float n = fbm(vec2(uv.x * 3.0 + seed, uv.y * 2.2 - t * 2.4));
	float lean = (value_noise(vec2(t * 0.8, seed)) - 0.5) * sway * uv.y;
	float x = (uv.x - 0.5) * 2.0 + lean + (n - 0.5) * 0.3 * uv.y;
	float width = mix(0.62, 0.02, pow(uv.y, 0.9)) * (0.8 + 0.4 * n);
	float shape = 1.0 - smoothstep(width * 0.55, width, abs(x));
	shape *= smoothstep(0.0, 0.1, uv.y) * (1.0 - smoothstep(0.55, 0.95, uv.y + (n - 0.5) * 0.3));
	float core = (1.0 - smoothstep(0.0, width * 0.6, abs(x))) * (1.0 - smoothstep(0.05, 0.55, uv.y));
	vec3 col = mix(edge_color, core_color, clamp(core * 1.4, 0.0, 1.0));
	ALBEDO = col * intensity * shape;
	ALPHA = clamp(shape, 0.0, 1.0);
}
