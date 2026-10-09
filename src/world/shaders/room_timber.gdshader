// 房间与陈设的木料(梁柱、护墙板、线脚、门、窗框、木桶、木箱……):顺纹拉长的年轮山形纹 + 纤维条纹 + 做旧斑驳。
// 合批网格按部件自身坐标(CUSTOM0)取纹理,部件种子(CUSTOM1)让每块木料的纹理、深浅各不相同。
// 顶点色 rgb = 部件染色(只能调暗:顶点色按 8 位存储,超过 1 会被截断),
// alpha = 顺纹方向(1 = 沿局部 Z,0.5 = 沿局部 Y,0 = 沿局部 X):部件按自然姿态建模,不必为了木纹转来转去。
// 大面积着色器:每像素 4 次值噪声,其余是解析式。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform vec3 color_dark : source_color = vec3(0.34, 0.24, 0.16);
uniform vec3 color_light : source_color = vec3(0.62, 0.46, 0.31);
uniform float ring_frequency = 11.0;
uniform float roughness_base = 0.66;
uniform float wear = 0.45;

varying vec3 obj_pos;
varying float part_seed;

void vertex() {
	bool batched = CUSTOM1.x >= 2.0;
	obj_pos = batched ? CUSTOM0.xyz : VERTEX;
	part_seed = batched ? fract(CUSTOM1.x) : 0.0;
}

void fragment() {
	// 换轴:q.z 顺纹,q.xy 是横截面
	vec3 q = COLOR.a > 0.75 ? obj_pos : (COLOR.a > 0.25 ? obj_pos.xzy : obj_pos.zyx);
	float rnd = hash12(vec2(part_seed * 91.7, 2.3));
	float along = q.z + rnd * 17.0;
	float across = q.x + q.y;
	// 年轮:以木料外侧一点为心的同心圆,切在板面上就是一道道拉长的山形纹;噪声把它扭弯
	vec2 heart = q.xy + vec2(0.3 + 0.4 * rnd, -0.25 - 0.3 * fract(rnd * 7.0));
	float warp = value_noise(vec2(along * 1.1, across * 4.0));
	float rings = fract(length(heart) * ring_frequency + warp * 0.9 + along * 0.04);
	rings = smoothstep(0.0, 0.65, rings) * (1.0 - smoothstep(0.65, 1.0, rings));
	float streak = value_noise(vec2(along * 3.0, (q.x - q.y) * 70.0 + rnd * 30.0));
	// 纤维细到不足一个像素时淡出,远处不闪
	vec2 fibre_p = vec2(along * 11.0, across * 380.0);
	float fibre_fade = 1.0 - smoothstep(0.3, 1.0, fwidth(fibre_p.y));
	float fibre = (value_noise(fibre_p) - 0.5) * fibre_fade + 0.5;
	float blotch = value_noise(vec2(along * 0.8, (q.x - q.y) * 2.5) + rnd * 9.0);
	float t = clamp(rings * 0.38 + streak * 0.32 + fibre * 0.14 + (rnd - 0.5) * 0.3, 0.0, 1.0);
	vec3 col = mix(color_dark, color_light, t) * COLOR.rgb;
	col *= mix(1.0, 0.72 + 0.56 * blotch, wear);
	ALBEDO = col;
	ROUGHNESS = clamp(roughness_base + streak * 0.15 - blotch * wear * 0.12, 0.2, 1.0);
	SPECULAR = 0.4;
}
