// 布料:按 UV 织出经纬纹(粗麻布袋或细绒窗帘),顶点色为各部件的染色,绒面掠射时泛一层柔光,
// 低频噪声做旧(褪色与污渍)。双面渲染:窗帘褶皱的背面从侧面也看得到。
shader_type spatial;
render_mode diffuse_burley, cull_disabled;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform vec3 base_color : source_color = vec3(1.0);
uniform vec2 weave_density = vec2(160.0, 160.0);   // UV 每单位的纱线数
uniform float weave_strength = 0.25;
uniform float sheen = 0.0;          // 绒面柔光(天鹅绒窗帘)
uniform float grime = 0.2;          // 做旧程度
uniform float roughness_base = 0.9;

void fragment() {
	vec2 w = UV * weave_density;
	// 平纹:经纱与纬纱交替压在上面,两组正弦条纹相乘出一格格的"织点"
	float warp_thread = 0.5 + 0.5 * sin(w.x * 6.2831853);
	float weft_thread = 0.5 + 0.5 * sin(w.y * 6.2831853);
	float over = step(0.5, fract((floor(w.x) + floor(w.y)) * 0.5));
	float weave = mix(warp_thread, weft_thread, over);
	// 远处纱线细节小于一个像素时淡出,避免摩尔纹
	float fade = 1.0 - smoothstep(0.25, 0.6, max(fwidth(w.x), fwidth(w.y)));
	float dirt = value_noise(UV * 6.0 + COLOR.rg * 17.0);
	vec3 col = base_color * COLOR.rgb;
	col *= 1.0 - weave_strength * fade * (1.0 - weave);
	col *= 1.0 - grime * smoothstep(0.35, 0.9, dirt);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	ALBEDO = col * (1.0 + rim * sheen);
	ROUGHNESS = roughness_base;
	SPECULAR = 0.2;
}
