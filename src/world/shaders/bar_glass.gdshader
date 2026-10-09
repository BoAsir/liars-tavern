// 酒瓶、酒杯的玻璃:不透明的高光玻璃(比真透明便宜,一排排瓶子也不会糊成一片)。
// 顶点色 rgb = 玻璃色(sRGB),alpha = 液面高度(部件自身坐标的 y,单位 fill_unit 米,0 = 空瓶):
// 液面以下是酒,颜色更深更饱和;以上是空玻璃,偏灰偏淡;液面处一道亮线。
// 边缘按菲涅尔亮一圈(像光从玻璃边上透过来),整体镜面高光很强。没有噪声采样,很便宜。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform float liquid_shade = 0.62;
uniform float empty_shade = 0.3;
uniform float fill_unit = 0.5;
uniform float rim_glow = 0.22;

varying float part_y;
varying vec4 tint;

void vertex() {
	part_y = CUSTOM0.y;
	tint = COLOR;
}

void fragment() {
	vec3 color = pow(tint.rgb, vec3(2.2));
	float level = tint.a * fill_unit;
	float liquid = (1.0 - smoothstep(level - 0.002, level + 0.002, part_y)) * step(0.001, level);
	float meniscus = (1.0 - smoothstep(0.0, 0.005, abs(part_y - level))) * step(0.001, level);
	vec3 glass = mix(color, vec3(dot(color, vec3(0.333))), 0.4) * empty_shade;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(glass, color * liquid_shade, liquid);
	ROUGHNESS = 0.07;
	SPECULAR = 0.8;
	RIM = 0.3;
	RIM_TINT = 0.7;
	EMISSION = color * (fres * rim_glow + meniscus * 0.25);
}
