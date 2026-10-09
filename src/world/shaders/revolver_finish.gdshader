// 左轮枪的程序化表面:整把枪共用这一份材质,每个合批网格只有一个表面(= 一次绘制调用)。
// 顶点色 alpha 选表面工艺(RevolverModel.Finish,按 1/8 编码),rgb 为部件染色(白色 = 不变):
//   0 发蓝钢:枪管、转轮、退壳杆套筒——深蓝黑、光滑,带一点抛光不均;
//   1 渗碳淬火钢:机匣、击锤、扳机——钢灰底上淡淡的蓝紫云斑,偶见麦秆黄;
//   2 黄铜:扳机护圈、背带、准星、弹壳底缘、徽章;
//   3 抛光钢:螺丝、转轮轴、退壳杆头;
//   4 枪膛与槽缝:近黑、粗糙;
//   5 象牙:握把片——奶白带纵向细纹,边缘(片薄处)泛黄。
// 纹理按部件自身坐标(MeshBatch 的 CUSTOM0)取,部件种子(CUSTOM1)错开花纹。
// 酒馆没有反射探针,金属只剩直射高光、整体发黑:按反射方向叠一层假的环境反射(下方深色桌面、
// 水平方向烛光照亮的暖色墙、上方昏暗的房梁),走 EMISSION,亮度远低于泛光阈值,不会发光晕。
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

#include "res://src/world/shaders/noise.gdshaderinc"

const float FINISH_STEPS = 8.0;
const int BLUED = 0;
const int CASE = 1;
const int BRASS = 2;
const int BRIGHT = 3;
const int BORE = 4;
const int IVORY = 5;

uniform vec3 blued_color : source_color = vec3(0.22, 0.28, 0.42);
uniform float blued_roughness = 0.22;
// 渗碳淬火:底子是深灰钢,上面淡淡浮着蓝、紫、麦秆黄的云斑(风格化,只点到为止,不抢牌面和脸)
uniform vec3 case_steel : source_color = vec3(0.36, 0.37, 0.4);
uniform vec3 case_blue : source_color = vec3(0.22, 0.27, 0.4);
uniform vec3 case_purple : source_color = vec3(0.33, 0.27, 0.38);
uniform vec3 case_straw : source_color = vec3(0.62, 0.5, 0.32);
uniform float case_scale = 95.0;           // 云斑频率(每米):一块约 1 厘米
uniform float case_amount = 0.6;           // 云斑颜色盖过钢灰底的比例
uniform vec3 brass_color : source_color = vec3(0.86, 0.66, 0.32);
uniform vec3 bright_color : source_color = vec3(0.78, 0.78, 0.8);
uniform vec3 bore_color : source_color = vec3(0.025, 0.024, 0.026);
uniform vec3 ivory_color : source_color = vec3(0.8, 0.73, 0.58);
uniform vec3 ivory_patina : source_color = vec3(0.64, 0.5, 0.31);
uniform float panel_height = 0.0098;       // 握把片鼓起的高度(米,RevolverModel 会写入),边缘泛黄按它归一
// 假环境反射:桌面、墙、房梁的颜色,以及水平方向一条烛光亮带(枪管、转轮的圆柱面上那道横向高光)
uniform vec3 env_floor : source_color = vec3(0.09, 0.06, 0.04);
uniform vec3 env_wall : source_color = vec3(0.42, 0.28, 0.16);
uniform vec3 env_ceiling : source_color = vec3(0.12, 0.09, 0.07);
uniform vec3 env_band : source_color = vec3(0.95, 0.68, 0.38);
// 正上方的吊灯:桌上平放的枪从上往下看时,朝上的面映出一团暖光,发蓝钢才不至于一片死黑
uniform vec3 env_lamp : source_color = vec3(0.9, 0.62, 0.34);
uniform float env_strength = 0.75;

varying vec3 obj_pos;
varying float part_seed;

void vertex() {
	bool batched = CUSTOM1.x >= 2.0;
	obj_pos = batched ? CUSTOM0.xyz : VERTEX;
	part_seed = batched ? fract(CUSTOM1.x) : 0.0;
}

vec3 case_colors(vec3 p) {
	// 渗碳淬火的色斑:蓝 → 紫 → 偶尔一抹麦秆黄,整体压在钢灰底上;第二层噪声决定哪里颜色浓、哪里褪成钢灰
	float t = fbm3(p * case_scale);
	float strength = value_noise3(p * case_scale * 0.6 + 7.1);
	vec3 col = mix(case_blue, case_purple, smoothstep(0.38, 0.52, t));
	col = mix(col, case_straw, smoothstep(0.56, 0.68, t));
	return mix(case_steel, col, case_amount * smoothstep(0.2, 0.7, strength));
}

vec3 fake_env(vec3 dir, float rough) {
	float soft = 0.12 + rough * 0.6;
	vec3 col = mix(env_floor, env_wall, smoothstep(-0.3 - soft, 0.02, dir.y));
	col = mix(col, env_ceiling, smoothstep(0.2, 0.62 + soft, dir.y));
	float band = exp(-pow((dir.y - 0.1) / (0.07 + rough * 0.3), 2.0));
	float lamp = smoothstep(0.72 - rough * 0.4, 0.97, dir.y);
	return col + (env_band * band + env_lamp * lamp) * (1.0 - rough);
}

void fragment() {
	int finish = int(COLOR.a * FINISH_STEPS + 0.5);
	vec3 p = obj_pos + part_seed * 3.7;
	float wobble = value_noise3(p * 90.0);
	vec3 albedo;
	float metallic = 1.0;
	float rough;
	float env = 1.0;
	if (finish == CASE) {
		albedo = case_colors(p);
		metallic = 0.9;
		rough = 0.28 + wobble * 0.1;
	} else if (finish == BRASS) {
		albedo = brass_color * (0.86 + wobble * 0.22);
		rough = 0.24 + wobble * 0.14;
	} else if (finish == BRIGHT) {
		albedo = bright_color;
		rough = 0.18 + wobble * 0.08;
	} else if (finish == BORE) {
		// 枪膛、膛口、槽缝是凹进去的:几乎不反光、不吃假环境反射,读成黑洞而不是凸起
		albedo = bore_color;
		metallic = 0.0;
		rough = 0.9;
		env = 0.0;
		SPECULAR = 0.1;
	} else if (finish == IVORY) {
		// 纵向细纹沿握把片的长轴(部件坐标 y),片越薄(z 越小)越泛黄
		float grain = value_noise(vec2(p.x * 700.0, p.y * 45.0));
		float edge = 1.0 - smoothstep(0.0, panel_height * 0.7, obj_pos.z);
		albedo = mix(ivory_color, ivory_patina, clamp(edge * 0.75 + grain * 0.3, 0.0, 1.0));
		metallic = 0.0;
		rough = 0.42 + grain * 0.12;
	} else {
		// 发蓝钢:大块的轻微深浅不均,像手工抛光
		albedo = blued_color * (0.82 + wobble * 0.36);
		rough = blued_roughness + (wobble - 0.5) * 0.08;
	}
	ALBEDO = albedo * COLOR.rgb;
	METALLIC = metallic;
	ROUGHNESS = rough;
	vec3 reflected = (INV_VIEW_MATRIX * vec4(reflect(-VIEW, NORMAL), 0.0)).xyz;
	vec3 f0 = mix(vec3(0.04), ALBEDO, metallic);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	EMISSION = fake_env(reflected, rough) * mix(f0, vec3(1.0), fresnel) * env_strength * env;
}
