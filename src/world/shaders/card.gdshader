// 卡牌正/背面:贴图圆角裁切 + 轻微自发光保证可读;实例参数控制每张牌的高亮光晕。
shader_type spatial;
render_mode diffuse_burley, cull_back;

uniform sampler2D card_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float self_illum = 0.03;
// 牌面纸色压暗、哑光:平放在吊灯光圈下时不至于过曝成一片白,点数仍清楚
uniform float albedo_scale = 0.7;
uniform float ink_contrast = 1.35;   // >1 让油墨更深、纸面基本不变
instance uniform vec4 glow_color : source_color = vec4(1.0, 0.82, 0.4, 1.0);
instance uniform float glow = 0.0;

void fragment() {
	vec4 tex = texture(card_texture, UV);
	if (tex.a < 0.5) {
		discard;
	}
	vec2 edge_dist = min(UV, 1.0 - UV);
	float edge = 1.0 - smoothstep(0.0, 0.14, min(edge_dist.x, edge_dist.y * 0.7));
	ALBEDO = pow(tex.rgb, vec3(ink_contrast)) * albedo_scale;
	ROUGHNESS = 0.8;
	SPECULAR = 0.12;
	EMISSION = tex.rgb * self_illum + glow_color.rgb * glow * (0.04 + edge * 1.3);
}
