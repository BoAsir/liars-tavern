// 酒客眼睛:两只眼一个网格,巩膜、虹膜、瞳孔、高光、上眼睑、出局的 × 全画在着色器里(不自发光)。
// 顶点 CUSTOM0 = (眼面坐标 u, v ∈ [-1, 1],左右 -1/1,0):构建器按眼睛正面投影写入。
// 眨眼、看向、表情、出局都是实例参数,所有酒客共用一份材质。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/vertex_pbr.gdshaderinc"

instance uniform vec4 look = vec4(0.0);            // 左眼 xy、右眼 zw 的瞳孔偏移(眼面坐标)
instance uniform float lid = 0.0;                  // 眨眼:0 睁开 → 1 闭上
instance uniform float lid_rest = 0.12;            // 物种默认眼睑(乌龟眼皮厚)
instance uniform float lid_tilt = 0.0;             // 表情:生气为正(眼睑内低外高),担心为负
instance uniform float dead = 0.0;                 // 出局:画 ×
instance uniform float fade = 0.0;                 // 出局褪灰(同 patron.gdshader)
instance uniform vec3 iris_color = vec3(0.45, 0.3, 0.12);   // sRGB,末尾统一转线性
instance uniform vec3 lid_color = vec3(0.5, 0.3, 0.15);
instance uniform float pupil_shape = 0.0;          // 0 圆、1 竖缝(猫、鳄鱼)、2 横椭圆(羊驼)
instance uniform float lashes = 0.0;

const vec3 SCLERA = vec3(0.66, 0.65, 0.62);   // 同 PatronParts.EYE_WHITE 档:烛光下不发白
const vec3 PUPIL = vec3(0.025, 0.022, 0.03);
const vec3 GREY = vec3(0.42);

varying vec3 eye;

void vertex() {
	eye = CUSTOM0.xyz;
}

float aa_step(float edge, float x) {
	float w = max(fwidth(x), 1e-4);
	return smoothstep(edge - w, edge + w, x);
}

void fragment() {
	vec2 uv = eye.xy;
	float side = eye.z;
	vec2 offset = side < 0.0 ? look.xy : look.zw;
	offset = clamp(offset, vec2(-0.35), vec2(0.35));
	vec2 q = uv - offset;
	// 瞳孔形状:竖缝把 x 拉宽,横椭圆把 y 拉宽
	vec2 pupil_scale = pupil_shape > 1.5 ? vec2(0.7, 1.8) : (pupil_shape > 0.5 ? vec2(3.2, 0.85) : vec2(1.0));
	float iris = 1.0 - aa_step(0.55, length(q));
	float pupil = 1.0 - aa_step(0.27, length(q * pupil_scale));
	float ring = aa_step(0.42, length(q)) * iris;
	vec3 col = SCLERA;
	vec3 iris_lin = iris_color * (1.0 - 0.35 * ring) * (0.85 + 0.15 * smoothstep(0.55, -0.2, q.y));
	col = mix(col, iris_lin, iris * (1.0 - dead));
	col = mix(col, PUPIL, pupil * (1.0 - dead));
	// 画上去的高光:左上一大一小两个点,跟着瞳孔走
	float spark = 1.0 - aa_step(0.13, length(q - vec2(-0.2, 0.24)));
	spark = max(spark, 1.0 - aa_step(0.06, length(q - vec2(0.18, -0.16))));
	col = mix(col, vec3(0.95), spark * iris * (1.0 - dead));
	// 出局:两条对角线画 ×
	float x_mark = min(abs(uv.x - uv.y), abs(uv.x + uv.y)) * 0.7071;
	col = mix(col, PUPIL, (1.0 - aa_step(0.09, x_mark)) * step(length(uv), 0.75) * dead);
	// 上眼睑:从上往下盖,lid_tilt 让内外眼角高低不同(side 区分左右,x 朝外为正)
	float cover = max(lid, lid_rest) + lid_tilt * (uv.x * side) * 0.6;
	float lid_edge = 1.0 - 2.0 * clamp(cover, 0.0, 1.0);
	float covered = aa_step(lid_edge, uv.y);
	float lash_line = (1.0 - aa_step(0.07, abs(uv.y - lid_edge))) * step(cover, 0.98);
	col = mix(col, lid_color, covered);
	col = mix(col, PUPIL, lash_line * mix(0.55, 1.0, lashes) * (1.0 - covered));
	float lum = dot(col, vec3(0.2126, 0.7152, 0.0722));
	col = mix(col, GREY * lum * 1.6, 0.85 * fade);
	ALBEDO = vp_srgb_to_linear(col);
	ROUGHNESS = mix(0.15, 0.7, covered);
	SPECULAR = mix(0.6, 0.3, covered);
}
