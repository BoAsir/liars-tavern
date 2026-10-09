// 蜡烛的蜡:奶白蜡面,靠近火苗的一段透出暖光(火光透进蜡里)。
// 蜡烛部件以烛顶(烛芯根部)为原点向下建模,按部件坐标(CUSTOM0)的高度判断离火苗多远;
// 顶点色给每根蜡烛、烛芯染色(烛芯是黑的,不透光)。
shader_type spatial;
render_mode diffuse_burley;

uniform vec3 wax_color : source_color = vec3(0.92, 0.86, 0.72);
uniform vec3 glow_color : source_color = vec3(1.0, 0.56, 0.24);
uniform float glow_energy = 1.6;
uniform float glow_depth = 0.032;   // 从烛顶往下透光的深度(米)
uniform float ambient_glow = 0.04;  // 暗处蜡面也微微泛光,不会黑成一截

varying float below_top;

void vertex() {
	vec3 local = CUSTOM1.x >= 2.0 ? CUSTOM0.xyz : VERTEX;
	below_top = max(-local.y, 0.0);
}

void fragment() {
	float glow = 1.0 - smoothstep(0.0, glow_depth, below_top);
	vec3 base = wax_color * COLOR.rgb;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.0);
	ALBEDO = base;
	ROUGHNESS = 0.38;
	SPECULAR = 0.35;
	EMISSION = glow_color * COLOR.rgb * glow * glow * glow_energy + base * (ambient_glow + rim * 0.06);
}
