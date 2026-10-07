// 全屏后处理(读屏幕):暗角(紧张时收紧)、去饱和、色差、闪光染色、胶片颗粒。
// 只在去饱和或色差生效时启用:读屏幕纹理要先整屏拷贝一次,4K 下约 2 毫秒。平时由 post_fx_overlay 代劳。
shader_type canvas_item;

#include "res://src/world/shaders/post_fx_common.gdshaderinc"

// 按 1:1 像素采样,不需要 mipmap(mipmap 过滤会让渲染器每帧额外生成一整条模糊链)
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float desaturate = 0.0;
uniform float aberration = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 col;
	if (aberration > 0.001) {
		vec2 off = (uv - 0.5) * aberration * 0.025;
		col = vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - off).b);
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(luma), desaturate);
	col *= vignette_keep(uv);
	col = mix(col, flash_color.rgb, flash_color.a);
	col += grain_offset(uv, TIME);
	COLOR = vec4(col, 1.0);
}
