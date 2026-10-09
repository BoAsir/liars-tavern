// 牌桌软包边的皮革:细密皮纹、软包分格的压痕、拱顶两侧两道缝线、常被手肘蹭的拱顶磨出光泽。
// 用回转体的 UV:UV.x = 第几格(整数处是分格接缝,TableModel 按半径取整),UV.y = 沿包边剖面走过的米数。
// 每像素 4 次值噪声;缝线、接缝不足一个像素宽时按覆盖率淡出,远处不闪。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform vec3 leather_color : source_color = vec3(0.17, 0.05, 0.034);
uniform vec3 worn_color : source_color = vec3(0.3, 0.11, 0.06);
uniform vec3 thread_color : source_color = vec3(0.72, 0.56, 0.36);
uniform float panel_length = 0.12;      // 一格的长度(米),把 UV.x 换算成米
uniform float stitches_per_panel = 16.0;
uniform vec2 stitch_rows = vec2(0.03, 0.07);   // 两道缝线在剖面上的位置(UV.y)
uniform float stitch_width = 0.0011;    // 缝线半宽(米)
uniform float crown_at = 0.05;          // 拱顶在剖面上的位置(UV.y)
uniform float crown_width = 0.02;
uniform float seam_width = 0.045;       // 分格压痕的半宽(占一格的比例)
uniform float seam_tilt = 0.6;          // 压痕处法线往缝里倾的程度

varying vec3 tangent_view;

void vertex() {
	// 沿圆周的切向(观察空间):压痕处的法线沿它往缝里倾
	tangent_view = normalize((MODELVIEW_MATRIX * vec4(-VERTEX.z, 0.0, VERTEX.x, 0.0)).xyz);
}

float thin_line(float d, float half_width) {
	float fw = max(fwidth(d), 1e-6);
	float w = max(half_width, fw);
	return (1.0 - smoothstep(w - fw, w + fw, d)) * clamp(half_width / fw, 0.0, 1.0);
}

void fragment() {
	vec2 p = vec2(UV.x * panel_length, UV.y);
	// 皮纹:细密的颗粒,远处(一个像素里好几粒)淡成平均值
	float grain_lod = clamp(length(fwidth(p)) * 900.0 - 0.5, 0.0, 1.0);
	float pebble = mix(value_noise(p * 900.0) * 0.6 + value_noise(p * 2300.0 + 7.0) * 0.4, 0.5, grain_lod);
	float mottle = value_noise(p * vec2(14.0, 40.0)) * 0.7 + value_noise(p * vec2(41.0, 120.0)) * 0.3;
	// 分格压痕
	float u = fract(UV.x);
	float seam = 1.0 - smoothstep(0.0, seam_width + fwidth(UV.x), min(u, 1.0 - u));
	// 缝线:两道虚线,针脚在接缝处断开
	float stitch_u = UV.x * stitches_per_panel;
	float dash_u = fract(stitch_u);
	float dash = smoothstep(0.22, 0.3, dash_u) * (1.0 - smoothstep(0.88, 0.96, dash_u));
	dash = mix(dash, 0.62, clamp(fwidth(stitch_u) * 2.0 - 0.5, 0.0, 1.0));
	float rows = max(thin_line(abs(UV.y - stitch_rows.x), stitch_width),
		thin_line(abs(UV.y - stitch_rows.y), stitch_width));
	float thread = rows * dash * (1.0 - seam);
	// 拱顶磨亮:颜色浅一点、更光滑
	float crown = 1.0 - smoothstep(0.0, crown_width, abs(UV.y - crown_at));
	vec3 col = mix(leather_color, worn_color, clamp(crown * 0.5 + (mottle - 0.5) * 0.45, 0.0, 1.0));
	col *= 0.86 + pebble * 0.24;
	col *= 1.0 - seam * 0.55;
	ALBEDO = mix(col, thread_color, thread);
	ROUGHNESS = mix(clamp(0.52 - crown * 0.18 + pebble * 0.16, 0.2, 1.0), 0.78, thread);
	SPECULAR = 0.42;
	float side = u < 0.5 ? -1.0 : 1.0;
	NORMAL = normalize(NORMAL + tangent_view * side * seam * seam_tilt);
}
