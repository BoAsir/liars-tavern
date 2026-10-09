// 灰泥墙面:大片柔和的明暗斑驳 + 抹刀留下的弧形刮痕(略带光泽)+ 细砂点,墙顶一圈烛烟熏黄。
// 按世界坐标取纹理(合批后各段墙面纹理连续、互不重复);大面积着色器,每像素只取 5 次噪声。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform vec3 color_light : source_color = vec3(0.6, 0.52, 0.42);
uniform vec3 color_dark : source_color = vec3(0.47, 0.4, 0.32);
uniform vec3 soot_color : source_color = vec3(0.25, 0.2, 0.15);
uniform float soot_start = 2.55;   // 烟熏从这个高度开始往上加深
uniform float soot_end = 3.4;
uniform float soot_strength = 0.45;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float mottle(vec2 p) {
	// 三层分形(比 noise.gdshaderinc 的五层便宜):墙面大块的深浅
	return value_noise(p) * 0.55 + value_noise(p * 2.1 + 7.3) * 0.3 + value_noise(p * 4.3 + 1.7) * 0.15;
}

void fragment() {
	// 墙面坐标:取世界坐标中与法线垂直的两轴
	vec3 n = abs(world_normal);
	vec2 p = n.x > 0.5 ? world_pos.zy : (n.z > 0.5 ? world_pos.xy : world_pos.xz);
	float patches = mottle(p * 0.9);
	// 抹刀刮痕:斜向拉长的噪声,形成一道道略亮略光滑的弧面
	float trowel = value_noise(vec2(p.x * 2.2 + p.y * 1.4, p.y * 6.5 - p.x * 1.1));
	float speck = value_noise(p * 85.0);
	vec3 col = mix(color_dark, color_light, smoothstep(0.2, 0.8, patches));
	col *= 0.93 + trowel * 0.12;
	col *= 0.9 + speck * 0.18;
	float soot = smoothstep(soot_start, soot_end, world_pos.y) * soot_strength * (0.7 + 0.6 * patches);
	col = mix(col, soot_color, clamp(soot, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.92 - smoothstep(0.55, 0.9, trowel) * 0.25 - speck * 0.05;
	SPECULAR = 0.3;
}
