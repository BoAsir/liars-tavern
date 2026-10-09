// 酒标:纸色取顶点色 rgb(sRGB),外圈一道深色边框、里面一道细线框,上部一条色带,中间几行"字"(短横);
// 部件种子(CUSTOM1)决定色带颜色、有没有色带、字的排布,一排同款酒瓶的酒标也各不相同。
// UV.x 是绕瓶身的方向(0..1,只覆盖朝外的一段弧);CUSTOM0.y = 部件自身高度,alpha = 酒标高度(单位 0.2 米)。
shader_type spatial;
render_mode diffuse_burley;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform vec3 ink : source_color = vec3(0.07, 0.05, 0.045);
uniform vec3 band_red : source_color = vec3(0.5, 0.07, 0.05);
uniform vec3 band_blue : source_color = vec3(0.1, 0.14, 0.3);

varying float v;
varying float seed;
varying vec3 paper;

void vertex() {
	v = CUSTOM0.y / max(COLOR.a * 0.2, 0.001);
	seed = fract(CUSTOM1.x);
	paper = COLOR.rgb;
}

void fragment() {
	float u = UV.x;
	vec3 col = pow(paper, vec3(2.2));
	float edge = min(min(v, 1.0 - v), min(u, 1.0 - u) * 1.6);
	float border = 1.0 - smoothstep(0.04, 0.06, edge);
	float frame = smoothstep(0.09, 0.1, edge) * (1.0 - smoothstep(0.11, 0.125, edge));
	float band = step(0.62, v) * step(v, 0.8) * step(0.3, seed);
	col = mix(col, seed < 0.65 ? band_red : band_blue, band);
	float line = fract(v * 10.0);
	float row = step(0.22, v) * step(v, 0.52) * step(0.35, line) * step(line, 0.7);
	float word = step(0.42, value_noise(vec2(u * 26.0 + seed * 50.0, floor(v * 10.0))));
	col = mix(col, ink, clamp(max(border, frame) * 0.75 + row * word * 0.65, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.72;
	SPECULAR = 0.3;
}
