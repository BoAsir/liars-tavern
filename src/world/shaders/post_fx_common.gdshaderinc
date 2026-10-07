// 全屏后处理的公共部分:暗角、闪光染色、胶片颗粒。post_fx(读屏幕)与 post_fx_overlay(只叠加)共用。
uniform float vignette = 0.35;       // 0..1 暗角收紧程度
uniform float vignette_darkness = 0.75;
uniform vec4 flash_color : source_color = vec4(1.0, 0.12, 0.05, 0.0);
uniform float grain = 0.035;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// 画面保留的亮度比例:1 = 不压暗
float vignette_keep(vec2 uv) {
	vec2 d = uv - 0.5;
	float dist = length(d * vec2(1.0, 0.78));
	float radius = mix(0.95, 0.38, vignette);
	float vig = 1.0 - smoothstep(radius - 0.45, radius, dist);
	return mix(1.0 - vignette_darkness, 1.0, vig);
}

// 有正负的颗粒偏移量
float grain_offset(vec2 uv, float time) {
	return (hash(uv * 731.0 + fract(time) * 97.0) - 0.5) * grain;
}
