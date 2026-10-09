// 吊灯灯罩外壁的搪瓷:不导电的亮釉 + 一层清漆高光。
// 场景没有全局光照,灯罩外壁背着罩里的灯,只剩微弱的环境光,绿釉会黑成一团:
// 朝上的面补一点天花板、墙面反射回来的暖光,掠射角再补一圈釉面光泽,圆顶与裙边的形体才看得出来。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 enamel : source_color = vec3(0.1, 0.36, 0.25);
uniform vec3 bounce_tint : source_color = vec3(1.0, 0.84, 0.68);
uniform float bounce = 0.32;
uniform float sheen = 0.4;

void fragment() {
	vec3 world_normal = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	float up = clamp(world_normal.y * 0.5 + 0.5, 0.0, 1.0);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = enamel;
	ROUGHNESS = 0.28;
	SPECULAR = 0.6;
	CLEARCOAT = 1.0;
	CLEARCOAT_ROUGHNESS = 0.12;
	EMISSION = enamel * (bounce_tint * bounce * up + sheen * rim);
}
