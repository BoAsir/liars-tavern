// 卡牌正/背面:贴图圆角裁切 + 轻微自发光保证可读;实例参数控制每张牌的高亮光晕。
shader_type spatial;
render_mode diffuse_burley, cull_back;

uniform sampler2D card_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float self_illum = 0.08;
instance uniform vec4 glow_color : source_color = vec4(1.0, 0.82, 0.4, 1.0);
instance uniform float glow = 0.0;

void fragment() {
	vec4 tex = texture(card_texture, UV);
	if (tex.a < 0.5) {
		discard;
	}
	vec2 edge_dist = min(UV, 1.0 - UV);
	float edge = 1.0 - smoothstep(0.0, 0.14, min(edge_dist.x, edge_dist.y * 0.7));
	ALBEDO = tex.rgb;
	ROUGHNESS = 0.5;
	SPECULAR = 0.35;
	EMISSION = tex.rgb * self_illum + glow_color.rgb * glow * (0.04 + edge * 1.3);
}
