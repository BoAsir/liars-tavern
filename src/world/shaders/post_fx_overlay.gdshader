// 全屏后处理(只叠加,不读屏幕):暗角、闪光染色、胶片颗粒。去饱和、色差为 0 时与 post_fx 一致(只有暗处的颗粒更淡)。
// 预乘混合:结果 = 本层颜色 + 画面 × (1 - 本层 alpha)。
shader_type canvas_item;
render_mode blend_premul_alpha;

#include "res://src/world/shaders/post_fx_common.gdshaderinc"

void fragment() {
	vec2 uv = SCREEN_UV;
	float g = grain_offset(uv, TIME);
	// 颗粒变暗的部分只能折进 alpha,按比例压暗:亮处(牌面)与原版一致,暗处更淡,不会在牌面上糊出噪点
	float keep = vignette_keep(uv) * (1.0 - flash_color.a) * (1.0 - max(-g, 0.0));
	COLOR = vec4(flash_color.rgb * flash_color.a + max(g, 0.0), 1.0 - keep);
}
