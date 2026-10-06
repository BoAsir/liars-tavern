// 全屏后处理:暗角(紧张时收紧)、去饱和、色差、闪光染色、胶片颗粒。
shader_type canvas_item;

// 按 1:1 像素采样,不需要 mipmap(mipmap 过滤会让渲染器每帧额外生成一整条模糊链)
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette = 0.35;       // 0..1 暗角收紧程度
uniform float vignette_darkness = 0.75;
uniform float desaturate = 0.0;
uniform float aberration = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 0.12, 0.05, 0.0);
uniform float grain = 0.035;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - 0.5;
	vec3 col;
	if (aberration > 0.001) {
		vec2 off = d * aberration * 0.025;
		col = vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - off).b);
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), desaturate);
	float dist = length(d * vec2(1.0, 0.78));
	float radius = mix(0.95, 0.38, vignette);
	float vig = 1.0 - smoothstep(radius - 0.45, radius, dist);
	col *= mix(1.0 - vignette_darkness, 1.0, vig);
	col = mix(col, flash_color.rgb, flash_color.a);
	col += (hash(uv * 731.0 + fract(TIME) * 97.0) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
