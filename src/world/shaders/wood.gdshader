// 程序化木纹:年轮 + 纤维纹理,可选木板拼接(地板/护墙板)。纹理在物体空间计算,无需 UV。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform vec3 color_dark : source_color = vec3(0.16, 0.08, 0.04);
uniform vec3 color_light : source_color = vec3(0.42, 0.24, 0.12);
uniform float scale = 1.0;
uniform float ring_frequency = 9.0;
uniform float grain_strength = 0.35;
uniform int grain_axis = 0;      // 纤维方向:0=X 1=Y 2=Z
uniform int across_axis = 2;     // 木板排列方向
uniform float plank_width = 0.0; // >0 启用木板拼接
uniform float plank_length = 1.6;
uniform float roughness_base = 0.62;
uniform float varnish = 0.0;
uniform float wear = 0.0;
// 合并网格(MeshForge)里木纹按部件自己的局部坐标算:CUSTOM0.xyz = 部件原始顶点,w = 部件种子;
// 不合并的网格不开,和原来完全一样
uniform bool use_part_space = false;

varying vec3 obj_pos;
varying float part_seed;

void vertex() {
	obj_pos = (use_part_space ? CUSTOM0.xyz : VERTEX) * scale;
	part_seed = use_part_space ? CUSTOM0.w : 0.0;
}

float axis_component(vec3 v, int axis) {
	return axis == 0 ? v.x : (axis == 1 ? v.y : v.z);
}

void fragment() {
	float along = axis_component(obj_pos, grain_axis);
	float across = axis_component(obj_pos, across_axis);
	float depth = axis_component(obj_pos, 3 - grain_axis - across_axis);
	float plank_id = 0.0;
	float seam = 0.0;
	if (plank_width > 0.0) {
		float row = floor(across / plank_width);
		float offset = hash12(vec2(row, 3.7)) * plank_length;
		float segment = floor((along + offset) / plank_length);
		plank_id = row + segment * 57.0;
		float fa = fract(across / plank_width);
		float fl = fract((along + offset) / plank_length);
		float edge = min(min(fa, 1.0 - fa) * plank_width, min(fl, 1.0 - fl) * plank_length);
		seam = 1.0 - smoothstep(0.0, 0.005, edge);
	}
	float rnd = hash12(vec2(plank_id, 1.3) + part_seed * 31.7);
	float warp = fbm(vec2(along * 0.45, across * 1.6) + rnd * 10.0);
	vec2 ring_p = vec2(across + rnd * 13.0, depth * 0.6 + rnd * 7.0);
	float rings = fract(length(ring_p) * ring_frequency + warp * 1.1);
	rings = smoothstep(0.0, 0.75, rings) * (1.0 - smoothstep(0.75, 1.0, rings));
	float grain = fbm(vec2(along * 1.8, across * 80.0 + rnd * 20.0));
	float fibre = value_noise(vec2(along * 6.0, across * 400.0));
	float t = clamp(rings * 0.32 + grain * grain_strength + fibre * 0.15 + (rnd - 0.5) * 0.3, 0.0, 1.0);
	vec3 col = mix(color_dark, color_light, t);
	float blotch = fbm(vec2(along, across) * 1.7 + 4.0);
	col *= mix(1.0, 0.7 + 0.6 * blotch, wear);
	col *= mix(1.0, 0.2, seam);
	ALBEDO = col;
	ROUGHNESS = clamp(roughness_base - varnish * 0.45 + grain * 0.18 + seam * 0.3, 0.06, 1.0);
	SPECULAR = 0.45;
}
