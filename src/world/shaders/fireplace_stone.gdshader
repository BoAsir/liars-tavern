// 壁炉石块:每块石头(合批部件,按 CUSTOM1 种子)有自己的色调(暖砂岩、冷灰、带青苔的褐)与明暗,
// 表面斑驳带细麻点,倒角处略亮(磨旧的棱);炉口拱顶上方被烟熏黑(从拱顶向上、向两侧柔和地淡开,
// 石面与倒角一起变暗),炉口内侧朝里的石面全黑;炉口前的炉床积着一层灰。
// 合批网格挂在壁炉根节点下、不再变换,模型坐标(VERTEX)就是壁炉本地坐标:原点在后墙内表面、壁炉正中的地面。
shader_type spatial;
render_mode diffuse_burley;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform vec3 color_warm : source_color = vec3(0.46, 0.38, 0.3);
uniform vec3 color_cool : source_color = vec3(0.33, 0.32, 0.31);
uniform vec3 color_moss : source_color = vec3(0.34, 0.32, 0.24);
uniform vec3 soot_color : source_color = vec3(0.028, 0.024, 0.022);
uniform vec3 ash_color : source_color = vec3(0.3, 0.29, 0.28);
uniform vec2 soot_center = vec2(0.0, 0.9);      // 熏黑最重的地方:拱顶(壁炉本地 x、y)
uniform vec2 soot_size = vec2(0.82, 0.6);       // 熏黑的范围:半宽、半高
uniform float soot_front = 0.5;                 // 只熏炉体正面(烟囱正面离墙更近,不受影响)
uniform float opening_half_width = 0.52;
uniform float spring_height = 0.66;
uniform vec4 ash_area = vec4(0.0, 0.64, 0.75, 0.3);   // 积灰:中心 x、z,半宽 x、半深 z

varying vec3 fp_pos;
varying vec3 fp_normal;
varying float stone_seed;

void vertex() {
	fp_pos = VERTEX;
	fp_normal = NORMAL;
	stone_seed = CUSTOM1.x >= 2.0 ? fract(CUSTOM1.x) : 0.0;
}

float soot_amount(vec3 n, float mottle) {
	// 拱顶上方的烟渍:柔和的椭圆,拱脚以下不熏
	vec2 d = (fp_pos.xy - soot_center) / soot_size;
	float plume = 1.0 - smoothstep(0.3, 1.0, length(d));
	plume *= smoothstep(spring_height - 0.2, spring_height + 0.05, fp_pos.y) * smoothstep(soot_front - 0.04, soot_front, fp_pos.z);
	// 炉口里侧:朝炉口中心的石面(侧壁朝里、拱石朝下)
	float inside = step(abs(fp_pos.x), opening_half_width + 0.03) * step(0.5, -n.x * sign(fp_pos.x));
	inside = max(inside, step(abs(fp_pos.x), opening_half_width + 0.25) * step(fp_normal.y, -0.5)
		* step(spring_height - 0.1, fp_pos.y));
	return clamp(max(plume * (0.75 + 0.35 * mottle), inside * 0.95), 0.0, 1.0);
}

void fragment() {
	// 纹理坐标取石面所在平面的两轴;种子错开每块石头的斑纹
	vec3 n = abs(fp_normal);
	vec2 p = n.x > 0.6 ? fp_pos.zy : (n.y > 0.6 ? fp_pos.xz : fp_pos.xy);
	p += vec2(stone_seed * 31.0, stone_seed * 17.0);
	float hue = hash12(vec2(stone_seed * 97.0, 1.7));
	float value = hash12(vec2(stone_seed * 53.0, 8.3));
	vec3 base = hue < 0.5 ? mix(color_cool, color_warm, hue * 2.0) : mix(color_warm, color_moss, hue * 2.0 - 1.0);
	base *= 0.8 + 0.36 * value;
	float mottle = value_noise(p * 4.0) * 0.6 + value_noise(p * 11.0) * 0.4;
	float pits = value_noise(p * 47.0);
	vec3 col = base * (0.82 + 0.3 * mottle) * (0.88 + 0.16 * smoothstep(0.3, 0.7, pits));
	// 磨旧的棱:法线偏离石面主方向的地方(倒角)略亮
	float edge = 1.0 - max(max(n.x, n.y), n.z);
	col *= 1.0 + edge * 0.45;
	col = mix(col, soot_color * (0.8 + 0.5 * mottle), soot_amount(fp_normal, mottle));
	// 积灰:炉口前炉床朝上的面,斑斑点点
	vec2 rel = abs(fp_pos.xz - ash_area.xy) / ash_area.zw;
	float ash = step(0.6, fp_normal.y) * (1.0 - smoothstep(0.5, 1.0, max(rel.x, rel.y)));
	col = mix(col, ash_color * (0.75 + 0.4 * mottle), clamp(ash * (0.2 + 0.9 * pits * mottle), 0.0, 0.75));
	ALBEDO = col;
	ROUGHNESS = 0.82 + pits * 0.12;
	SPECULAR = 0.3;
}
