// 灯罩玻璃(壁灯的防风玻璃罩):几乎透明,掠射角处反光更浓(菲涅尔),火苗高度附近透出一圈暖光。
// 材质的 render_priority 设为 -1:先于火苗(加色混合)画,玻璃不会把罩里的火苗盖暗。只画朝外的一面。
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 tint : source_color = vec3(1.0, 0.93, 0.8);
uniform float base_alpha = 0.06;
uniform float edge_alpha = 0.5;
uniform vec3 glow_color : source_color = vec3(1.0, 0.62, 0.28);
uniform float glow_energy = 0.9;
uniform float glow_height = 0.03;   // 部件坐标里火苗的高度
uniform float glow_spread = 0.035;

varying float height;

void vertex() {
	vec3 local = CUSTOM1.x >= 2.0 ? CUSTOM0.xyz : VERTEX;
	height = local.y;
}

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	float d = (height - glow_height) / glow_spread;
	float glow = exp(-d * d);
	ALBEDO = tint * 0.5;
	ROUGHNESS = 0.06;
	SPECULAR = 0.75;
	EMISSION = glow_color * glow * glow_energy;
	ALPHA = clamp(mix(base_alpha, edge_alpha, fresnel) + glow * 0.12, 0.0, 1.0);
}
