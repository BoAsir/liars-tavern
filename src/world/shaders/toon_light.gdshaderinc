// 柔和卡通光照(动森风格,2026-10-08 用户追加,见 docs/superpowers/specs/2026-10-08-cozy-toon-style-design.md):
// 替换引擎的直接光照模型;间接光、环境光、反射、SSAO 照旧。#include 本文件即定义 light()。
// - 漫反射:半兰伯特式 wrap 之后过一道 smoothstep,亮面与暗面之间是一条柔和过渡带而不是硬切;
//   暗面留 toon_shadow 的光(配合较亮的环境光,像软胶玩具,不会黑成一片)。
// - 高光:Blinn-Phong 过 smoothstep,是一小块边缘柔和的光斑;粗糙表面几乎没有,金属件按 albedo 染色。
// - 边光:掠射角的轮廓亮一圈(布料、皮毛);金属件没有。include 之前 #define TOON_NO_RIM 可关掉。
// - BACKLIGHT(薄片透光)与引擎内置一样按背光面加。
// 各参数是普通 uniform:每个 shader 可以在材质里调,也可以在 include 之前 #define 改默认值。
#ifndef TOON_WRAP
#define TOON_WRAP 0.4
#endif
#ifndef TOON_SHADOW
#define TOON_SHADOW 0.35
#endif
#ifndef TOON_RIM
#define TOON_RIM 0.25
#endif

uniform float toon_wrap : hint_range(0.0, 1.0) = TOON_WRAP;
uniform float toon_edge : hint_range(0.0, 1.0) = 0.45;
uniform float toon_soft : hint_range(0.01, 0.5) = 0.18;
uniform float toon_shadow : hint_range(0.0, 1.0) = TOON_SHADOW;
uniform float toon_spec : hint_range(0.0, 2.0) = 0.35;
uniform float toon_rim : hint_range(0.0, 1.0) = TOON_RIM;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float w = clamp((ndl + toon_wrap) / (1.0 + toon_wrap), 0.0, 1.0);
	float band = smoothstep(toon_edge - toon_soft, toon_edge + toon_soft, w);
	float shade = mix(toon_shadow, 1.0, band);
	vec3 light_in = LIGHT_COLOR * ATTENUATION / PI;
	DIFFUSE_LIGHT += light_in * shade;
	DIFFUSE_LIGHT += light_in * BACKLIGHT * max(-ndl, 0.0);
#ifndef TOON_NO_RIM
	float rim = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	rim = smoothstep(0.55, 0.8, rim) * (1.0 - METALLIC) * toon_rim;
	DIFFUSE_LIGHT += light_in * rim * (0.4 + 0.6 * band);
#endif
	float gloss = 1.0 - ROUGHNESS;
	vec3 h = normalize(VIEW + LIGHT);
	float sp = pow(max(dot(NORMAL, h), 0.0), mix(6.0, 96.0, gloss * gloss));
	sp = smoothstep(0.35, 0.65, sp) * gloss * gloss * band;
	vec3 spec_color = mix(vec3(0.04 + 0.08 * SPECULAR_AMOUNT), ALBEDO, METALLIC);
	SPECULAR_LIGHT += LIGHT_COLOR * ATTENUATION * spec_color * sp * toon_spec * 4.0;
}
