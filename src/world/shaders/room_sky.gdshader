// 窗外夜空:深蓝渐变与地平线薄雾、带光晕的圆月、闪烁的星星、两层山丘、松树林剪影、
// 山坡上一户人家亮着暖色的窗。按视线方向计算(像天空盒一样无限远,不随窗外幕布的位置变化),
// 只在窗口露出的像素上运行;不受光照、不投影。
shader_type spatial;
render_mode unshaded, shadows_disabled;

#include "res://src/world/shaders/noise.gdshaderinc"

uniform vec3 zenith_color : source_color = vec3(0.01, 0.017, 0.05);
uniform vec3 horizon_color : source_color = vec3(0.06, 0.1, 0.19);
uniform vec3 mist_color : source_color = vec3(0.12, 0.17, 0.27);
uniform vec3 moon_color : source_color = vec3(1.0, 0.95, 0.82);
uniform vec3 far_hill_color : source_color = vec3(0.028, 0.045, 0.085);
uniform vec3 near_hill_color : source_color = vec3(0.008, 0.012, 0.025);
uniform vec3 cottage_light : source_color = vec3(1.0, 0.62, 0.25);
// 月亮方向:(方位角, 仰角),弧度。方位角从 +X(窗外正前方)朝 -Z 量,仰角从水平面往上
uniform vec2 moon_at = vec2(0.3, 0.135);
uniform float moon_radius = 0.042;
uniform float cottage_azimuth = 0.08;

float ridge(float az, float base, vec3 freq, vec3 amp, float seed) {
	return base + amp.x * sin(az * freq.x + seed) + amp.y * sin(az * freq.y + seed * 2.3)
		+ amp.z * sin(az * freq.z + seed * 4.1);
}

float pine_trees(float az, float el, float ground, float aa) {
	// 松树剪影:沿方位角一格一棵,高矮不一,偶尔空一格;树形是两层叠起的三角
	float cell_w = 0.016;
	float cell = floor(az / cell_w);
	float x = abs(fract(az / cell_w) - 0.5) * 2.0;
	float present = step(0.28, hash12(vec2(cell, 7.0)));
	float h = (0.018 + 0.03 * hash12(vec2(cell, 3.0))) * present;
	float y = (el - ground) / max(h, 1e-4);
	float layer = fract(y * 2.0);
	float half_w = (1.0 - y) * 0.55 + (1.0 - layer) * 0.18;
	float inside = step(0.0, y) * step(y, 1.0) * (1.0 - smoothstep(half_w - 0.08, half_w + 0.08, x));
	return inside * present;
}

void fragment() {
	vec3 dir = normalize((INV_VIEW_MATRIX * vec4(-VIEW, 0.0)).xyz);
	float az = atan(-dir.z, dir.x);
	float el = asin(clamp(dir.y, -1.0, 1.0));
	float aa = max(fwidth(az) + fwidth(el), 1e-5);
	vec3 col = mix(horizon_color, zenith_color, smoothstep(-0.02, 0.45, el));
	// 星星:方向空间的网格里随机撒点,靠近地平线与月亮时变淡;各自缓慢闪烁
	vec2 sky_uv = vec2(az, el) / 0.011;
	vec2 cell = floor(sky_uv);
	float h = hash12(cell);
	vec2 star_pos = cell + 0.2 + 0.6 * vec2(hash12(cell + 1.7), hash12(cell + 4.3));
	float star_d = length(sky_uv - star_pos) * 0.011;
	float twinkle = 0.65 + 0.35 * sin(TIME * (1.3 + 2.5 * h) + h * 50.0);
	float star = step(0.9, h) * (1.0 - smoothstep(0.0, 0.0012 + aa, star_d)) * twinkle * (0.5 + 4.0 * (h - 0.9));
	vec2 moon_d = vec2((az - moon_at.x) * cos(el), el - moon_at.y);
	float md = length(moon_d);
	star *= smoothstep(0.03, 0.12, el) * smoothstep(moon_radius * 2.5, moon_radius * 5.0, md);
	col += vec3(0.85, 0.9, 1.0) * star;
	// 月亮:光晕 + 圆盘 + 淡淡的月海
	col += moon_color * (exp(-md * 18.0) * 0.16 + exp(-md * 60.0) * 0.12);
	float disc = 1.0 - smoothstep(moon_radius - aa, moon_radius + aa, md);
	float maria = value_noise(moon_d * 70.0 + 3.0);
	col = mix(col, moon_color * (1.35 - smoothstep(0.45, 0.75, maria) * 0.3), disc);
	// 薄云:月亮附近被照亮的几缕
	float cloud = value_noise(vec2(az * 6.0, el * 22.0) + 11.0) * 0.6 + value_noise(vec2(az * 13.0, el * 40.0)) * 0.4;
	cloud = smoothstep(0.55, 0.8, cloud) * smoothstep(0.02, 0.1, el) * (1.0 - smoothstep(0.25, 0.45, el));
	col = mix(col, mix(horizon_color * 1.6, moon_color * 0.45, exp(-md * 8.0)), cloud * 0.55 * (1.0 - disc));
	// 地平线薄雾
	col = mix(col, mist_color, (1.0 - smoothstep(0.0, 0.07, el)) * 0.6);
	// 远山(雾里发蓝)、近处山坡 + 松林
	float far_ground = ridge(az, 0.035, vec3(7.0, 17.0, 41.0), vec3(0.016, 0.008, 0.003), 1.3);
	col = mix(col, far_hill_color, 1.0 - smoothstep(far_ground - aa, far_ground + aa, el));
	float near_ground = ridge(az, 0.006, vec3(4.0, 11.0, 29.0), vec3(0.018, 0.009, 0.004), 4.7);
	float near = max(1.0 - smoothstep(near_ground - aa, near_ground + aa, el), pine_trees(az, el, near_ground, aa));
	col = mix(col, near_hill_color, near);
	// 山坡上的小屋:屋身 + 尖顶 + 一扇亮着的窗
	vec2 hp = vec2((az - cottage_azimuth) / 0.012, (el - near_ground) / 0.012);
	float house = step(abs(hp.x), 0.9) * step(-0.2, hp.y) * step(hp.y, 1.0);
	house = max(house, step(1.0, hp.y) * step(hp.y, 1.0 + 1.0 - abs(hp.x)));
	col = mix(col, near_hill_color * 0.7, house);
	float lit = step(abs(hp.x - 0.25), 0.22) * step(abs(hp.y - 0.45), 0.2);
	col = mix(col, cottage_light * 1.6, lit);
	ALBEDO = col;
}
